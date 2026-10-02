#!/usr/bin/env python3
"""Applies a redone OCR (BibliotecaMaconica_Dev/Tools/refazer_ocr_obra.swift) to the package of one work.

Each page keeps its old text unless the new one is better by the shared quality rule
(`Tools/qualidade_referencia.py`): a better level, or the same level without losing text.
The chosen text is split as the batch importer does (`importar_biblioteca_rag_lote.swift`):
footnotes from the last lines and one search block per page; the blocks, notes and search
index of the page are rebuilt with the same ids. The work row, the page ids and the facsimile
rows stay as they are.

    python3 Tools/aplicar_ocr_refeito.py --pacote rag_obra.sqlite --ocr paginas.json --saida novo.sqlite [--obra ID]
"""
import argparse
import json
import re
import shutil
import sqlite3
from pathlib import Path

import auditar_texto_acervo as audit
import qualidade_referencia as quality

RANK = {"curta": 0, "ilegivel": 1, "ruidosa": 2, "legivel": 3}


def normalize(text: str) -> str:
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    return "\n".join(re.sub(r"\s+$", "", line) for line in lines).strip()


def split_footnotes(text: str):
    lines = text.split("\n")
    if len(lines) <= 4:
        return text, ""
    separators = [i for i, line in enumerate(lines)
                  if len(line.strip()) >= 8 and all(ch in "-_—―" for ch in line.strip())]
    if separators:
        i = separators[-1]
        return "\n".join(lines[:i]).strip(), "\n".join(lines[i + 1:]).strip()
    start = len(lines) - min(10, len(lines))
    for i in range(start, len(lines)):
        if re.match(r"^\d{1,4}\s+\S", lines[i].strip()):
            return "\n".join(lines[:i]).strip(), "\n".join(lines[i:]).strip()
    return text, ""


def paragraphs(text: str) -> list:
    out, current = [], []

    def close():
        joined = re.sub(r"\s+", " ", " ".join(current)).strip()
        if joined:
            out.append(joined)
        current.clear()

    for line in text.split("\n"):
        line = line.strip()
        if not line:
            close()
        else:
            current.append(line)
    close()
    return out


def notes(footer: str) -> list:
    out, number, lines = [], None, []

    def close():
        if number is None:
            return
        joined = re.sub(r"\s+", " ", " ".join(lines)).strip()
        if joined:
            out.append((number, joined))

    for line in footer.split("\n"):
        clean = line.strip()
        match = re.match(r"^\d{1,4}\b", clean)
        if match:
            close()
            number = match.group(0)
            lines = [clean[match.end():].strip()]
        elif clean:
            lines.append(clean)
    close()
    return out


def letters(text: str) -> int:
    return sum(ch.isalpha() for ch in text)


_WORD_COUNTS = None


def word_counts() -> dict:
    """How often each word appears in the whole local collection (computed once)."""
    global _WORD_COUNTS
    if _WORD_COUNTS is None:
        import collections, glob
        counts = collections.Counter()
        packages = Path(__file__).resolve().parents[1] / "BibliotecaMaconica_Dev/ImportacaoLivrosPDF_OCR/_relatorios/RAGPackages"
        for path in glob.glob(str(packages / "**/*.sqlite"), recursive=True):
            con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
            for (text,) in con.execute("SELECT texto_integral FROM rag_paginas"):
                counts.update(re.findall(r"[a-z0-9]{3,}", quality_fold(text or "")))
            con.close()
        _WORD_COUNTS = counts
    return _WORD_COUNTS


def keeps_words(old: str, new: str) -> bool:
    """Every real word of the old page is still somewhere in the new one (a hyphen-split piece counts
    inside the joined word); only OCR noise may go: words seen fewer than 3 times in the collection."""
    running = re.sub(r"[^a-z0-9]", "", quality_fold(new))
    counts = word_counts()
    def doubled_number(w):  # a page number read twice ("1010", "131131")
        return w.isdigit() and len(w) % 2 == 0 and w[:len(w) // 2] == w[len(w) // 2:]
    return all(w in running or counts.get(w, 0) < 3 or doubled_number(w)
               for w in set(re.findall(r"[a-z0-9]{3,}", quality_fold(old))))


def quality_fold(text: str) -> str:
    import unicodedata
    return "".join(c for c in unicodedata.normalize("NFD", text.lower()) if unicodedata.category(c) != "Mn")


def defects(text: str) -> float:
    """Copies the page quality rule does not see (Tools/auditar_texto_acervo.py): repeated lines, interleaved columns."""
    found = audit.audit_page(text, {})
    return found.get("linhasRepetidas", 0) + 100 * found.get("colunasIntercaladas", 0)


def better(old: str, new: str, config: dict, criterion: str = "qualidade") -> bool:
    if criterion == "copias" and not keeps_words(old, new):
        return False  # a re-read text layer may never drop a real word of the page
    old_level = quality.rate_page(old, config)["nivel"]
    new_level = quality.rate_page(new, config)["nivel"]
    if RANK[new_level] != RANK[old_level]:
        return RANK[new_level] > RANK[old_level]
    if criterion == "copias":
        # Only pages that lose the second copy of their text (or interleaved columns) change, and only when
        # no word of the old text is missing from the new one (a layer may hold labels the other lacks).
        return bool(new.strip()) and defects(new) < defects(old) and keeps_words(old, new)
    return letters(new) >= 0.8 * letters(old) and new.strip() != ""


def apply(package: Path, ocr: Path, output: Path, work: str = "", criterion: str = "qualidade") -> dict:
    config = quality.load_config()
    pages = {p["pagina"]: normalize(p["texto"]) for p in json.loads(ocr.read_text(encoding="utf-8"))["paginas"]}
    if output != package:
        shutil.copyfile(package, output)
    con = sqlite3.connect(output)
    # Area packages hold several works: the work is chosen by id (the only one in a work package).
    work_id, title, area, topics = con.execute("SELECT id, titulo, area, assuntos_json FROM rag_obras WHERE id = ? OR ? = ''",
                                               (work, work)).fetchone()
    summary = {"obra": work_id, "paginas": 0, "trocadas": 0, "mantidas": 0, "antes": {}, "depois": {}}
    rows = con.execute("SELECT id, numero_original, texto_integral FROM rag_paginas WHERE obra_id = ? ORDER BY numero_original",
                       (work_id,)).fetchall()
    for page_id, number, old in rows:
        old = old or ""
        new = pages.get(number, "")
        summary["paginas"] += 1
        old_level = quality.rate_page(old, config)["nivel"]
        summary["antes"][old_level] = summary["antes"].get(old_level, 0) + 1
        if not better(old, new, config, criterion):
            summary["mantidas"] += 1
            summary["depois"][old_level] = summary["depois"].get(old_level, 0) + 1
            continue
        summary["trocadas"] += 1
        new_level = quality.rate_page(new, config)["nivel"]
        summary["depois"][new_level] = summary["depois"].get(new_level, 0) + 1
        main, footer = split_footnotes(new)
        con.execute("UPDATE rag_paginas SET texto_integral = ? WHERE id = ?", (new, page_id))
        con.execute("DELETE FROM rag_fts WHERE obra_id = ? AND pagina = ?", (work_id, number))
        con.execute("DELETE FROM rag_paragrafos WHERE obra_id = ? AND pagina = ?", (work_id, number))
        con.execute("DELETE FROM rag_notas WHERE obra_id = ? AND pagina = ?", (work_id, number))
        # One search block per page, as in the rest of the collection (the batch importer reads PDF text
        # without blank lines); the page text keeps its paragraph breaks for reading.
        for order, block in enumerate(paragraphs(re.sub(r"\n\s*\n", "\n", main)), start=1):
            block_id = f"{work_id}-p{number}-b{order}"
            con.execute("INSERT INTO rag_paragrafos (id, obra_id, pagina, ordem, texto, capitulo, secao, temas_json, palavras_chave_json) "
                        "VALUES (?, ?, ?, ?, ?, NULL, NULL, ?, ?)", (block_id, work_id, number, order, block, topics, topics))
            con.execute("INSERT INTO rag_fts (bloco_id, obra_id, titulo_obra, area, pagina, texto) VALUES (?, ?, ?, ?, ?, ?)",
                        (block_id, work_id, title, area, number, block))
        for index, (note_number, text) in enumerate(notes(footer), start=1):
            con.execute("INSERT INTO rag_notas (id, obra_id, pagina, numero, texto) VALUES (?, ?, ?, ?, ?)",
                        (f"{work_id}-p{number}-nota-{note_number}-{index}", work_id, number, note_number, text))
    con.commit()
    con.execute("VACUUM")
    con.close()
    return summary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pacote", type=Path, required=True)
    parser.add_argument("--ocr", type=Path, required=True)
    parser.add_argument("--saida", type=Path, required=True)
    parser.add_argument("--obra", default="", help="id of the work, needed in an area package")
    parser.add_argument("--criterio", choices=["qualidade", "copias"], default="qualidade",
                        help="copias: only a page that loses the repeated copy of its text changes (fewer letters expected)")
    args = parser.parse_args()
    print(json.dumps(apply(args.pacote, args.ocr, args.saida, args.obra, args.criterio), ensure_ascii=False))


if __name__ == "__main__":
    main()
