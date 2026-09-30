#!/usr/bin/env python3
"""Reference implementation of the text-quality rule shared by iOS and Android.

A page (or a sentence) is rated by the share of suspicious words left by OCR: letters from other
scripts, letters mixed with digits or symbols, stray single letters, scrambled case and long words
without vowels. Masonic abbreviations ("M.:I.:", "Ir.•"), ordinals, numbers and roman numerals are
normal. The native apps must reproduce these results exactly; `Paridade/casos_qualidade_v1.json`
holds the golden cases.

    python3 Tools/qualidade_referencia.py --atualizar   # regenerate expected outputs
    python3 Tools/qualidade_referencia.py --check       # verify cases are up to date
"""
import argparse
import json
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "Paridade/qualidade_texto_v1.json"
CASES = ROOT / "Paridade/casos_qualidade_v1.json"


def load_config() -> dict:
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def category(char: str) -> str:
    return unicodedata.category(char)


def is_letter(char: str) -> bool:
    return category(char)[0] == "L"


def is_alnum(char: str) -> bool:
    return category(char)[0] in ("L", "N")


def is_separator(char: str) -> bool:
    return char in "\t\n\u000b\f\r" or category(char) in ("Zs", "Zl", "Zp")


def in_ranges(char: str, ranges: list) -> bool:
    code = ord(char)
    return any(start <= code <= end for start, end in ranges)


def is_expected_script(char: str, config: dict) -> bool:
    code = ord(char)
    return any(start <= code <= end for start, end in config["escritasEsperadas"])


def tokens(text: str) -> list:
    result, current = [], []
    for char in unicodedata.normalize("NFC", text):
        if is_separator(char):
            if current:
                result.append("".join(current))
                current = []
        else:
            current.append(char)
    if current:
        result.append("".join(current))
    return result


def strip_chars(text: str, chars: str) -> str:
    start, end = 0, len(text)
    while start < end and text[start] in chars:
        start += 1
    while end > start and text[end - 1] in chars:
        end -= 1
    return text[start:end]


def is_masonic(text: str, marks: str) -> bool:
    """Groups of letters followed by abbreviation marks ("M.:I.:", "Ir.•", "Loj.'."), optionally
    ending in letters; at least one group of marks."""
    index, groups = 0, 0
    while index < len(text):
        letters = index
        while index < len(text) and is_letter(text[index]):
            index += 1
        if index == letters:
            return False
        marks_start = index
        while index < len(text) and text[index] in marks:
            index += 1
        if index == marks_start:
            return index == len(text) and groups > 0
        groups += 1
    return groups > 0


def is_ordinal(text: str, config: dict) -> bool:
    """Digits (groups separated by "." or ","), optional ".", an ordinal mark, optional "."."""
    marks = config["marcasOrdinais"]
    body = text[:-1] if text.endswith(".") else text
    if not body or body[-1] not in marks:
        return False
    body = body[:-1]
    if body.endswith("."):
        body = body[:-1]
    if not body or not all(category(c) == "Nd" or c in ".," for c in body):
        return False
    return category(body[0]) == "Nd" and category(body[-1]) == "Nd"


def digit_between_letters(text: str) -> bool:
    """A digit with letters on both sides ("c0m", "M4ALANNiXA"); verse or note numbers glued at the
    start or end of a word ("15ele", "gnoses116") are normal."""
    seen_letter = False
    digit_after_letter = False
    for char in text:
        if is_letter(char):
            if digit_after_letter:
                return True
            seen_letter = True
        elif category(char) == "Nd" and seen_letter:
            digit_after_letter = True
    return False


def classify(token: str, config: dict):
    """None: ignored (punctuation only); "normal"; or the reason it is suspicious."""
    text = strip_chars(token, config["bordas"])
    if not any(is_alnum(c) for c in text):
        return None
    if any(text.lower().startswith(prefix) for prefix in config["prefixosEndereco"]):
        return "normal"
    if is_masonic(text, config["marcasAbreviacao"]):
        return "normal"
    if is_ordinal(text, config):
        return "normal"
    abbreviated = text.endswith(".")
    text = text.rstrip(".")
    if not text:
        return None
    if all(category(c) == "Nd" or c in config["sinaisNumericos"] for c in text):
        return "normal"
    # Roman numerals: upper case of any length ("I", "XVIII") or lower case with two or more
    # letters ("xiv"); a lone lower-case "l", "d" or "c" is a stray OCR letter.
    if all(c in config["algarismosRomanos"] for c in text) and \
            (all(category(c) == "Lu" for c in text) or len(text) >= 2):
        return "normal"
    letters = [c for c in text if is_letter(c)]
    others = [c for c in text if not is_alnum(c) and c not in config["sinaisInternos"]]
    if any(not is_expected_script(c, config) for c in letters):
        return "escrita"
    if digit_between_letters(text):
        return "misto"
    if letters and others:
        return "simbolo"
    if len(letters) == 1 and not abbreviated and not (len(text) == 1 and text in config["palavrasDeUmaLetra"]):
        return "solta"
    if len(text) >= 3 and any(category(a) == "Ll" and category(b) == "Lu" for a, b in zip(text, text[1:])):
        return "caixa"
    if len(letters) >= config["limites"]["letrasSemVogal"] and all(in_ranges(c, config["faixasLatinas"]) for c in letters) \
            and not any(c in config["vogais"] for c in letters) and not all(category(c) == "Lu" for c in letters):
        return "semVogal"
    return "normal"


def rate(text: str, config: dict, minimum: int) -> dict:
    counted, suspicious, reasons = 0, 0, {}
    for token in tokens(text):
        result = classify(token, config)
        if result is None:
            continue
        counted += 1
        if result != "normal":
            suspicious += 1
            reasons[result] = reasons.get(result, 0) + 1
    limits = config["limites"]
    if counted < minimum:
        level = "curta"
    elif suspicious * 100 >= counted * limits["ilegivelPercentual"]:
        level = "ilegivel"
    elif suspicious * 100 >= counted * limits["ruidosaPercentual"]:
        level = "ruidosa"
    else:
        level = "legivel"
    return {"palavras": counted, "suspeitas": suspicious, "nivel": level,
            "motivos": dict(sorted(reasons.items()))}


def rate_page(text: str, config: dict) -> dict:
    return rate(text, config, config["limites"]["palavrasMinimasPagina"])


def rate_sentence(text: str, config: dict) -> dict:
    return rate(text, config, config["limites"]["palavrasMinimasFrase"])


def work_level(rated: int, noisy: int, unreadable: int, config: dict) -> str:
    """Quality of a whole work from its rated pages (short pages are not rated)."""
    limits = config["limites"]
    if rated == 0:
        return "semAvaliacao"
    readable = rated - noisy - unreadable
    if readable * 100 >= rated * limits["obraBoaPercentual"]:
        return "boa"
    if readable * 100 >= rated * limits["obraRegularPercentual"]:
        return "regular"
    return "baixa"


def run_case(case: dict, config: dict) -> dict:
    kind = case["tipo"]
    if kind == "token":
        return {"classe": classify(case["texto"], config)}
    if kind == "pagina":
        return rate_page(case["texto"], config)
    if kind == "frase":
        return rate_sentence(case["texto"], config)
    if kind == "obra":
        return {"nivel": work_level(case["avaliadas"], case["ruidosas"], case["ilegiveis"], config)}
    raise ValueError(kind)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--atualizar", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    config = load_config()
    data = json.loads(CASES.read_text(encoding="utf-8"))
    changed = False
    for case in data["casos"]:
        result = run_case(case, config)
        if case.get("esperado") != result:
            changed = True
            if args.atualizar:
                case["esperado"] = result
            else:
                print(f"Caso divergente: {case['nome']}: {case.get('esperado')} != {result}")
    if args.atualizar and changed:
        CASES.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Casos atualizados: {CASES.relative_to(ROOT)}")
    if args.check and changed:
        raise SystemExit(1)
    if not changed:
        print(f"Casos de qualidade conferidos: {len(data['casos'])}")


if __name__ == "__main__":
    main()
