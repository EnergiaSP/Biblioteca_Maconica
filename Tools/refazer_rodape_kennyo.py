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
# 02/04 was transcribed from a photo of the printed page: page 94 of the PDF repeats page 93.
EXCLUDED = {"02/04"}


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


NOTE_START = re.compile(r"^(\d{1,4}|\*)\s+[A-ZÀ-Ý\"“]")


def subsequence(short: str, full: str) -> bool:
    """The digits the OCR kept appear in order in the full number ("14" in 174, "68" in 368)."""
    it = iter(full)
    return bool(short) and all(c in it for c in short)


def new_footer(page: str, anchor):
    """Notes at the bottom of the page and their numbers. The note block is the last run of lines starting
    with a number (or "*") in the lower two thirds; numbers are consecutive, so each is assigned from the
    sequence when the digits the OCR read fit it (a missing or "*" number is the gap of the sequence)."""
    lines = [l.strip() for l in page.split("\n")]
    starts = [i for i, l in enumerate(lines) if i > len(lines) // 3 and NOTE_START.match(l)]
    if not starts:
        return "", []
    page_number = next((l for l in reversed(lines) if re.fullmatch(r"\d{1,4}", l)), "")
    read = [lines[i].split()[0] for i in starts]
    # The first number of the run: from the old footer when it has one, else the first number read.
    candidates = ([anchor - k for k in range(len(starts))] if anchor else []) + \
                 [int(r) - k for k, r in enumerate(read) if r.isdigit()]
    base = next((b for b in candidates if b > 0 and all(r == "*" or subsequence(r, str(b + k)) for k, r in enumerate(read))), None)
    if base is None:
        return "", []
    notes = []
    for k, (i, end) in enumerate(zip(starts, starts[1:] + [len(lines)])):
        text = re.sub(r"^(\d{1,4}|\*)\s+", "", lines[i])
        for line in lines[i + 1:end]:
            if not line or line == page_number:
                continue
            if text.endswith("-") and text[-2:-1].isalpha():
                text = text[:-1] + line  # word split at the end of the line
            elif text.endswith("-"):
                text += line  # a range of pages ("162-164") keeps its hyphen
            else:
                text = f"{text} {line}"
        notes.append(f"{base + k} {text}")
    return " ".join(notes + ([page_number] if page_number else [])), list(range(base, base + len(starts)))


# Letters the OCR confuses in the italic notes of this book: "h" read as "b" ("Tbe", "bttps"), "cl" as "d"
# ("Encydopedia"), "rn" as "m", "ç" as "g" ("Magonaria").
CONFUSIONS = [("b", "h"), ("d", "cl"), ("m", "rn"), ("g", "ç"), ("o", "c")]


def fix_ocr(word: str, counts: dict) -> str:
    """An unknown word becomes a common one when a single known confusion explains it, and only one does;
    a web address only gets its scheme fixed ("bttps://")."""
    if re.match(r"^bttps?://", word):
        return "h" + word[1:]
    if any(m in word for m in ("://", "www.", "/")):
        return word
    core = re.sub(r"^[^\wÀ-ÿ]+|[^\wÀ-ÿ]+$", "", word)
    prefix, suffix = word[:word.find(core)] if core else "", word[word.find(core) + len(core):] if core else ""
    key = lambda w: re.sub(r"[^a-z0-9]", "", fold(w))
    if not core or counts.get(key(core), 0) >= 3:
        return word
    options = set()
    for wrong, right in CONFUSIONS:
        for i in range(len(core)):
            if core[i:i + len(wrong)] == wrong:
                option = core[:i] + right + core[i + len(wrong):]
                if counts.get(key(option), 0) >= 5:
                    options.add(option)
    # No guessing by resemblance: it turned the medieval title "Confissom" into "Confissao".
    return prefix + options.pop() + suffix if len(options) == 1 else word


def merge(old: str, new: str, counts: dict, notes: list = ()) -> str:
    """Word-by-word merge of two readings of the same footer."""
    a, b = old.split(), new.split()
    notes_set = {str(n) for n in notes}
    key = lambda w: re.sub(r"[^a-z0-9]", "", fold(w)) or w  # a sign alone ("&", "*") is compared as itself

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
        elif op == "insert":
            known = sum(counts.get(key(w), 0) >= 3 or key(w).isdigit() for w in b[j1:j2])
            if known == j2 - j1 or (j2 - j1 >= 4 and known >= 0.6 * (j2 - j1)):
                # Only in the new footer (a note the old one lost): mostly known words, OCR confusions fixed.
                out += [fix_ocr(w, counts) for w in b[j1:j2]]
    return " ".join(out)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ocr", type=Path, action="append", required=True,
                        help="one or more OCR files, tried in order (a sharper one first)")
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
    readings = [{p["pagina"]: p["texto"] for p in json.loads(path.read_text(encoding="utf-8"))["paginas"]} for path in args.ocr]
    pages = {n for r in readings for n in r}
    original = TARGETS[0].read_text(encoding="utf-8")
    data = json.loads(original)
    changed, kept = [], []
    for item in data["itens"]:
        old = item.get("rodape") or ""
        if item["data"] in EXCLUDED or not old.strip() or item.get("pagina") not in pages:
            continue
        found = note_numbers(old)
        old_starts = len(re.findall(r"(?:^|\s)(?:\d{1,4}|\*)\s+[A-ZÀ-Ý\"“]", old))
        new, expected = "", []
        for reading in readings:
            if item["pagina"] in reading:
                new, expected = new_footer(reading[item["pagina"]], found[0] if found else None)
                if new and len(expected) >= old_starts:
                    break
        if not new or len(expected) < old_starts:
            kept.append({"data": item["data"], "motivo": "notas não encontradas por inteiro no OCR"})
            continue
        # The old footer must be inside the new one (it may have lost notes, never the other way round).
        old_words, new_words = fold(old).split(), fold(new).split()
        matched = sum(b.size for b in difflib.SequenceMatcher(None, old_words, new_words, autojunk=False).get_matching_blocks())
        if matched < 0.75 * len(old_words):
            kept.append({"data": item["data"], "motivo": f"rodapé antigo pouco contido no novo ({matched}/{len(old_words)})"})
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
