#!/usr/bin/env python3
"""Reference of the search variants shared by iOS and Android (Fase 13): spelling groups and the
optional singular and plural. Also writes the dossier variants (estudo_dossie_v1.json "variantes")
from the same groups. The native apps must reproduce `Paridade/casos_variantes_v1.json` exactly.

    python3 Tools/variantes_referencia.py --atualizar   # regenerate cases and dossier variants
    python3 Tools/variantes_referencia.py --check       # verify both are up to date
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RULE = ROOT / "Paridade/variantes_busca_v1.json"
DOSSIER = ROOT / "Paridade/estudo_dossie_v1.json"
CASES = ROOT / "Paridade/casos_variantes_v1.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def spelling(rule: dict) -> dict:
    """Each word of a group maps to the other words of the group, in the group's order."""
    result = {}
    for group in rule["grupos"]:
        for word in group:
            result.setdefault(word, [])
            result[word] += [other for other in group if other != word and other not in result[word]]
    return result


def inflections(word: str, rule: dict) -> list:
    if len(word) < rule["minimoLetras"] or word in rule["semFlexao"]:
        return []
    for item in rule["singularPlural"]:
        if word.endswith(item["final"]):
            stem = word[: len(word) - len(item["final"])]
            return [stem + form for form in item["formas"]]
    return []


def expand(words: list, rule: dict, plural: bool) -> dict:
    """Alternatives of each searched word, as the apps pass them to the index query."""
    groups = spelling(rule)
    result = {}
    for word in words:
        options = list(groups.get(word, []))
        if plural:
            for base in [word] + list(options):
                options += inflections(base, rule)
        unique = []
        for option in options:
            if option != word and option not in unique:
                unique.append(option)
        if unique:
            result[word] = unique[: rule["maximoPorPalavra"]]
    return result


def build_cases(rule: dict) -> dict:
    queries = [["loja"], ["lojas"], ["irmao"], ["irmaos"], ["macom"], ["macons"], ["simbolo"], ["jaco"], ["escada", "jaco"],
               ["templario"], ["luz"], ["luzes"], ["mestre"], ["ritual"], ["rituais"], ["cabala"], ["pedra", "bruta"], ["dos"], ["virtude"]]
    return {"schemaVersion": 1,
            "descricao": "Casos de referencia das variantes da busca (Paridade/variantes_busca_v1.json), gerados por "
                         "Tools/variantes_referencia.py --atualizar. iOS e Android devem reproduzir cada resultado.",
            "casos": [{"palavras": words, "singularPlural": plural, "esperado": expand(words, rule, plural)}
                      for words in queries for plural in (False, True)]}


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--atualizar", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rule = load(RULE)
    cases = build_cases(rule)
    dossier = load(DOSSIER)
    variants = spelling(rule)
    if args.atualizar:
        CASES.write_text(json.dumps(cases, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        dossier["variantes"] = variants
        DOSSIER.write_text(json.dumps(dossier, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("Variantes da busca atualizadas.")
    elif not CASES.exists() or load(CASES) != cases or dossier.get("variantes") != variants:
        raise SystemExit("Variantes da busca desatualizadas: rode Tools/variantes_referencia.py --atualizar.")
    else:
        print("Variantes da busca: verificadas.")


if __name__ == "__main__":
    main()
