#!/usr/bin/env python3
"""Replaces the readings of the Rizzardo breviary with a new OCR of the original PDF.

The OCR comes from BibliotecaMaconica_Dev/Tools/refazer_ocr_obra.swift (one JSON with the text of each
page). Each reading is found by its date at the top of the page ("16 de janeiro") and runs until
the next reading. A reading is replaced only when the new title matches the current one, the new
text is not worse by the shared quality rule (Tools/qualidade_referencia.py) and its length is
close to the current one, unless the current text is broken (an OCR "~", or noisy or unreadable).
The title is taken from the new OCR as well (the current one has joined words and "~").
The text keeps the format of the file: one paragraph, words split at the end of a line joined.

    python3 Tools/refazer_breviario_rizzardo.py --ocr paginas.json --relatorio Paridade/ocr_breviario_rizzardo_v1.json [--gravar]
"""
import argparse
import difflib
import json
import re
import unicodedata
from pathlib import Path

import qualidade_referencia as quality

ROOT = Path(__file__).resolve().parents[1]
TARGETS = [ROOT / "BibliotecaMaconica_Dev/Resources/breviario_rizzardo.json",
           ROOT / "projetos/BreviarioMaconicoAndroid/app/src/main/assets/breviario_rizzardo.json"]
MONTHS = ["janeiro", "fevereiro", "marco", "abril", "maio", "junho", "julho", "agosto", "setembro",
          "outubro", "novembro", "dezembro"]
RANK = {"curta": 0, "ilegivel": 1, "ruidosa": 2, "legivel": 3}
# Readings whose date line the OCR merged with the month heading of the book.
KNOWN_PAGES = {"01/02": 48}


def fold(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", text.lower()) if unicodedata.category(c) != "Mn")


def date_of(line: str):
    match = re.match(r"^\s*([0-9liIo|]{1,2})\s*[º°ª]?\s*de\s*([a-z]+)\s*$", fold(line).strip())
    if not match or match.group(2) not in MONTHS:
        return None
    day = match.group(1).translate(str.maketrans("liI|o", "11110"))
    if not day.isdigit() or not 1 <= int(day) <= 31:
        return None
    return f"{int(day):02d}/{MONTHS.index(match.group(2)) + 1:02d}"


def first_pages(pages: list) -> dict:
    start = dict()
    for page in pages:
        for line in page["texto"].split("\n")[:4]:
            date = date_of(line)
            if date:
                start[date] = page["pagina"]
                break
    for date, number in KNOWN_PAGES.items():
        start.setdefault(date, number)
    return start


def upper(line: str) -> bool:
    letters_only = [c for c in line if c.isalpha()]
    return bool(letters_only) and sum(c.isupper() for c in letters_only) >= 0.8 * len(letters_only)


def reading(pages: dict, first: int, last: int):
    """Title and text of the reading on pages first..last (the next reading starts after last)."""
    lines = []
    for number in range(first, last + 1):
        for line in pages.get(number, "").split("\n"):
            clean = line.strip()
            if re.fullmatch(r"[-–—\s]*\d{1,3}[-–—\s]*", clean) or re.fullmatch(r"[-–—•.·]+", clean) \
                    or fold(clean) == "breviario maconico":
                continue  # page number, running head, stray mark
            lines.append(clean)
    # Date line, then the title up to the first blank line.
    while lines and not lines[0]:
        lines.pop(0)
    if lines:
        lines.pop(0)
    while lines and not lines[0]:
        lines.pop(0)
    # The title is in capitals; the OCR does not always leave a blank line before the text.
    title = []
    while lines and lines[0] and upper(lines[0]):
        title.append(lines.pop(0))
    text = ""
    for line in lines:
        if not line:
            continue
        if text.endswith("-") and line[:1].islower() and text[-2:-1].isalpha():
            text = text[:-1] + line
        else:
            text = f"{text} {line}" if text else line
    text = re.sub(r"\s+", " ", text).strip()
    return " ".join(title).strip(), text


def letters(text: str) -> str:
    return re.sub(r"[^a-z]", "", fold(text))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ocr", type=Path, required=True)
    parser.add_argument("--relatorio", type=Path, required=True)
    parser.add_argument("--gravar", action="store_true")
    args = parser.parse_args()
    config = quality.load_config()
    pages_list = json.loads(args.ocr.read_text(encoding="utf-8"))["paginas"]
    pages = {page["pagina"]: page["texto"] for page in pages_list}
    start = first_pages(pages_list)
    order = sorted(start.items(), key=lambda item: item[1])
    end = {date: (order[i + 1][1] - 1 if i + 1 < len(order) else max(pages)) for i, (date, _) in enumerate(order)}
    data = json.loads(TARGETS[0].read_text(encoding="utf-8"))
    replaced, kept = [], []
    for item in data["itens"]:
        date = item["data"]
        if date not in start:
            kept.append({"data": date, "motivo": "data não encontrada no OCR"})
            continue
        title, text = reading(pages, start[date], max(start[date], end[date]))
        old = item["texto"] or ""
        old_level = quality.rate_page(old, config)["nivel"]
        new_level = quality.rate_page(text, config)["nivel"]
        broken = "~" in old or old_level in ("ruidosa", "ilegivel")
        same_title = difflib.SequenceMatcher(None, letters(title), letters(item["titulo"])).ratio() >= 0.75
        ratio = len(letters(text)) / max(1, len(letters(old)))
        reason = None
        if not same_title:
            reason = f"título diferente: {title!r}"
        elif RANK[new_level] < RANK[old_level]:
            reason = f"qualidade pior ({old_level} -> {new_level})"
        elif not broken and not 0.85 <= ratio <= 1.2:
            reason = f"tamanho diferente ({ratio:.2f})"
        if reason:
            kept.append({"data": date, "motivo": reason})
            continue
        # The title is read again too ("OAR" -> "O AR", "AORAÇA ~ O" -> "A ORAÇÃO").
        new_title = title if title and title != item["titulo"] else None
        if text != old or new_title:
            replaced.append({"data": date, "titulo": item["titulo"], "tituloNovo": new_title, "antes": old_level,
                             "depois": new_level, "tinhaTil": "~" in old, "inicioAntes": old[:120], "inicioDepois": text[:120]})
            item["texto"] = text
            item["titulo"] = title
    args.relatorio.write_text(json.dumps({
        "descricao": "Leituras do Breviário de Rizzardo refeitas com novo OCR do PDF original "
                     "(Tools/refazer_breviario_rizzardo.py). Mantidas: título, qualidade ou tamanho não conferem.",
        "trocadas": len(replaced), "mantidas": kept, "leituras": replaced}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    remaining = sum(("~" in (i.get(f) or "")) for i in data["itens"] for f in ("titulo", "texto", "rodape"))
    print(f"Trocadas: {len(replaced)}; mantidas: {len(kept)}; campos ainda com ~: {remaining}")
    if args.gravar:
        content = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        for target in TARGETS:
            target.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
