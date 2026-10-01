#!/usr/bin/env python3
"""Footnotes of the Kennyo Ismail breviary read again from a new OCR of the original PDF.

The text of the readings is good; their footnotes came from a poor OCR ("Cbristian Rasicrucianism",
"Enäightenment", "Artigo e Aceito"). Each reading is one page of the PDF (field `pagina`); the notes are the
lines from the first note number of the reading to the end, and the page number closes them, as in the file.
Note numbers are consecutive, so a number the OCR cut short is completed from the sequence ("8" after
367 is 368). Neither reading is right everywhere ("Enlightenment" only in the new one, "Brasileiras" only
in the old), so the two are merged word by word: where they differ, the word more common in the whole
collection stays (numbers: the longer one); a word only in the old footer is never dropped. The merge
replaces the old footer only when both are the same notes (at least 80% alike).

    python3 Tools/refazer_rodape_kennyo.py --ocr paginas.json --relatorio Paridade/ocr_rodape_kennyo_v1.json [--gravar]
"""
import argparse
import difflib
import json
import re
import unicodedata
from pathlib import Path

import qualidade_referencia as quality

ROOT = Path(__file__).resolve().parents[1]
TARGETS = [ROOT / "BibliotecaMaconica_Dev/Resources/breviario.json",
           ROOT / "projetos/BreviarioMaconicoAndroid/app/src/main/assets/breviario.json"]
RANK = {"curta": 0, "ilegivel": 1, "ruidosa": 2, "legivel": 3}


def fold(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", text.lower()) if unicodedata.category(c) != "Mn")


def note_numbers(footer: str) -> list:
    """The note numbers of a footer, as a consecutive run from the first to the last one (the old OCR also
    cut some numbers: "367 ... 68 ... 69 ... 372")."""
    found = [int(n) for n in re.findall(r"(?:^|\s)(\d{1,4})\s+[A-ZÀ-Ý]", footer)]
    if not found:
        return []
    first, last = found[0], found[-1]
    return list(range(first, last + 1)) if 0 < last - first < 30 else [first]


def new_footer(page: str, expected: list) -> str:
    lines = [l.strip() for l in page.split("\n")]
    first = str(expected[0])
    start = next((i for i, l in enumerate(lines)
                  if re.match(r"^\d{1,4}\s+\S", l) and first.endswith(l.split()[0]) and i > len(lines) // 3), None)
    if start is None:
        return ""
    notes, page_number, index = [], "", 0
    for line in lines[start:]:
        if not line:
            continue
        if re.fullmatch(r"\d{1,4}", line):
            page_number = line
            continue
        match = re.match(r"^(\d{1,4})\s+(\S.*)$", line)
        following = next((k for k in range(index, len(expected)) if match and str(expected[k]).endswith(match.group(1))), None)
        if following is not None:
            notes.append(f"{expected[following]} {match.group(2)}")  # the number completed from the sequence
            index = following + 1
        elif notes:
            if notes[-1].endswith("-") and notes[-1][-2:-1].isalpha():
                notes[-1] = notes[-1][:-1] + line  # word split at the end of the line
            elif notes[-1].endswith("-"):
                notes[-1] += line  # a range of pages ("162-164") keeps its hyphen
            else:
                notes[-1] = f"{notes[-1]} {line}"
    if not notes or index != len(expected):
        return ""  # the last note not reached: keep the old footer
    return " ".join(notes + ([page_number] if page_number else []))


def merge(old: str, new: str, counts: dict, notes: list = ()) -> str:
    """Word-by-word merge of two readings of the same footer."""
    a, b = old.split(), new.split()
    notes_set = {str(n) for n in notes}
    key = lambda w: re.sub(r"[^a-z0-9]", "", fold(w))

    def score(w):
        k = key(w)
        return (len(k) * 1000, 0) if k.isdigit() else (counts.get(k, 0), -abs(len(w) - len(k)))

    def pick(x, y):
        """The new word only when the old one is clearly an OCR error: a web address never changes; a word
        the collection knows (3 or more times) is kept; the new one must be known and must not just lose
        letters of the old ("Coil's" -> "Coil'"); a number made only of digits is kept, except a note number
        from the sequence; digits mixed with OCR noise ("1S6", "*19") give way to the clean number."""
        kx, ky = key(x), key(y)
        if any(m in x.lower() for m in ("http", "www", "/", "@")) or not ky or (ky in kx and len(ky) < len(kx)):
            return x
        if ky.isdigit():
            if y.strip(".,;:") in notes_set and kx.isdigit() and ky.endswith(kx):
                return y
            return y if not kx.isdigit() and len(ky) == len(kx) else x
        return y if counts.get(kx, 0) < 3 and counts.get(ky, 0) >= 3 else x

    out = []
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, [key(w) for w in a], [key(w) for w in b], autojunk=False).get_opcodes():
        if op == "equal":
            out += a[i1:i2]  # same letters: the old (digital) form keeps its accents and punctuation
        elif op == "replace" and i2 - i1 == j2 - j1:
            out += [pick(x, y) for x, y in zip(a[i1:i2], b[j1:j2])]
        elif op == "replace":
            known = lambda ws: all(counts.get(key(w), 0) >= 3 or key(w).isdigit() for w in ws)
            olds = a[i1:i2]
            if any(m in " ".join(olds).lower() for m in ("http", "www", "/")) or not known(b[j1:j2]) or known(olds):
                out += olds  # kept unless the new words are all known and the old ones are not
            else:
                out += b[j1:j2]
        elif op == "delete":
            out += a[i1:i2]  # only in the old footer: kept
        elif op == "insert" and all(counts.get(key(w), 0) >= 3 or key(w).isdigit() for w in b[j1:j2]):
            out += b[j1:j2]  # only in the new footer: words the collection knows
    return " ".join(out)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ocr", type=Path, required=True)
    parser.add_argument("--relatorio", type=Path, required=True)
    parser.add_argument("--gravar", action="store_true")
    args = parser.parse_args()
    config = quality.load_config()
    import aplicar_ocr_refeito
    counts = dict(aplicar_ocr_refeito.word_counts())
    for target in (TARGETS[0], ROOT / "BibliotecaMaconica_Dev/Resources/breviario_rizzardo.json"):
        for item in json.loads(target.read_text(encoding="utf-8"))["itens"]:
            for w in (item.get("rodape") or "").split() + item["texto"].split():
                k = re.sub(r"[^a-z0-9]", "", fold(w))
                counts[k] = counts.get(k, 0) + 1
    pages = {p["pagina"]: p["texto"] for p in json.loads(args.ocr.read_text(encoding="utf-8"))["paginas"]}
    original = TARGETS[0].read_text(encoding="utf-8")
    data = json.loads(original)
    changed, kept = [], []
    for item in data["itens"]:
        old = item.get("rodape") or ""
        expected = note_numbers(old)
        if not expected or item.get("pagina") not in pages:
            continue
        new = new_footer(pages[item["pagina"]], expected)
        if new and len(re.findall(r"(?:^|\s)\d{1,4}\s+[A-ZÀ-Ý]", new)) < len(re.findall(r"(?:^|\s)\d{1,4}\s+[A-ZÀ-Ý]", old)):
            new = ""  # fewer notes than before: keep the old footer
        if not new:
            kept.append({"data": item["data"], "motivo": "notas não encontradas por inteiro no OCR"})
            continue
        alike = difflib.SequenceMatcher(None, fold(old), fold(new), autojunk=False).ratio()
        if alike < 0.8:
            kept.append({"data": item["data"], "motivo": f"semelhança {alike:.2f}"})
            continue
        new = merge(old, new, counts, expected)
        if RANK[quality.rate_page(new, config)["nivel"]] < RANK[quality.rate_page(old, config)["nivel"]]:
            kept.append({"data": item["data"], "motivo": "qualidade pior"})
            continue
        if new != old:
            changed.append({"data": item["data"], "antes": old, "depois": new})
            item["rodape"] = new
    args.relatorio.write_text(json.dumps({
        "descricao": "Notas de rodapé do Breviário de Kennyo Ismail relidas de novo OCR do PDF original "
                     "(Tools/refazer_rodape_kennyo.py).", "trocadas": len(changed), "mantidas": kept,
        "notas": changed}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Rodapés trocados: {len(changed)}; mantidos: {len(kept)}")
    if args.gravar:
        content = json.dumps(data, ensure_ascii=False, indent=2 if original.startswith("{\n  ") else None)
        content += "\n" if original.endswith("\n") else ""
        for target in TARGETS:
            target.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
