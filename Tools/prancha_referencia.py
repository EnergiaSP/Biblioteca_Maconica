#!/usr/bin/env python3
"""Reference implementation of the prancha built from a dossier (Fase 11), shared by iOS and Android.

The prancha uses only the excerpts the dossier already cites, with ABNT citations and references
(`Paridade/prancha_v1.json`). The native apps must reproduce these results exactly;
`Paridade/casos_prancha_v1.json` holds the golden cases, built on the dossier cases.

    python3 Tools/prancha_referencia.py --atualizar   # regenerate expected outputs
    python3 Tools/prancha_referencia.py --check       # verify cases are up to date
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dossie_referencia import collapse, fold, nfc  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "Paridade/prancha_v1.json"
DOSSIER_CASES = ROOT / "Paridade/casos_dossie_v1.json"
CASES = ROOT / "Paridade/casos_prancha_v1.json"

# Bibliographic data for the works of the dossier cases, covering every form of the rule.
TEST_WORKS = {
    "dic": {"titulo": "Dicionário de Teste", "autor": "Basilio Thomé de Freitas Junior", "ano": "1999",
            "editora": "Editora Maçônica", "local": "São Paulo"},
    "instrucoes": {"titulo": "Instruções de Teste", "autor": "Rizzardo da Camino", "ano": "", "editora": "", "local": ""},
    "copia": {"titulo": "Cópia das Instruções", "autor": "Rizzardo da Camino", "ano": "", "editora": "Madras", "local": ""},
    "breviario_x": {"titulo": "Breviário de Teste", "autor": "Michael Howard e Nigel Jackson", "ano": "2010",
                    "editora": "", "local": "Londrina"},
    "livro2": {"titulo": "O Livro Divergente", "autor": "", "ano": "", "editora": "", "local": ""},
    "obra_com_ruido": {"titulo": "Boletim com ruído de OCR", "autor": "Voltaire", "ano": "1890", "editora": "", "local": ""},
    "ruido": {"titulo": "A maçonaria em ruído", "autor": "Ferry, Luc", "ano": "", "editora": "", "local": ""},
}


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def fill(template: str, **values) -> str:
    for key, value in values.items():
        template = template.replace("{" + key + "}", str(value))
    return template


def authors(name: str, rule: dict) -> list:
    """(surname, given names) of each author."""
    parts = [name.strip()]
    for separator in rule["separadoresAutores"]:
        parts = [piece.strip() for part in parts for piece in part.split(separator)]
    result = []
    for part in (p for p in parts if p):
        if "," in part:
            surname, _, given = part.partition(",")
            result.append((surname.strip(), given.strip()))
            continue
        words = part.split()
        size = 2 if len(words) >= 3 and words[-1].lower() in rule["sufixos"] else 1
        result.append((" ".join(words[-size:]), " ".join(words[:-size])))
    return result


def spoken(name: str, rule: dict) -> str:
    """Authors in natural order ("Luc Ferry"), joined by commas and " e "."""
    return join_list([f"{g} {s}".strip() for s, g in authors(name, rule)], rule)


def excerpt(text: str) -> str:
    return text.rstrip(" ;,:")


def title_entry(title: str, rule: dict) -> str:
    """Title as the entry of a work without author: first word (and a leading article) in capitals."""
    words = title.split()
    size = 2 if len(words) >= 2 and words[0].lower() in rule["artigos"] else 1
    return " ".join([w.upper() for w in words[:size]] + words[size:])


def reference(work: dict, rule: dict) -> str:
    place, publisher = work.get("local", "").strip(), work.get("editora", "").strip()
    if not place and not publisher:
        imprint = rule["semLocalEditora"]
    else:
        imprint = f"{place or rule['semLocal']}: {publisher or rule['semEditora']}"
    year = work.get("ano", "").strip() or rule["semAno"]
    title = work["titulo"].strip()
    names = authors(work.get("autor", ""), rule)
    if names:
        entry = "; ".join(f"{s.upper()}, {g}" if g else s.upper() for s, g in names)
        return f"{entry}{'' if entry.endswith('.') else '.'} {title}. {imprint}, {year}."
    return f"{title_entry(title, rule)}. {imprint}, {year}."


def citation(work: dict, source: dict, rule: dict) -> str:
    names = authors(work.get("autor", ""), rule)
    if names:
        who = "; ".join(s.upper() for s, _ in names)
    else:
        words = title_entry(work["titulo"].strip(), rule).split()
        size = 2 if len(words) >= 2 and words[0].lower() in rule["artigos"] else 1
        who = " ".join(words[:size]) + "..."
    year = work.get("ano", "").strip() or rule["semAno"]
    return f"({who}, {year}, p. {source['pagina']})"


def join_list(items: list, rule: dict) -> str:
    if len(items) <= 1:
        return "".join(items)
    return ", ".join(items[:-1]) + rule["textos"]["ultimoSeparador"] + items[-1]


def build(term: str, sources: list, analysis: dict, works: dict, rule: dict) -> dict:
    by_id = {source["id"]: source for source in sources}
    texts = rule["textos"]
    topic = " ".join(collapse(nfc(term)))

    def work_of(source_id: str) -> dict:
        source = by_id[source_id]
        work = dict(works.get(source["obraId"]) or {})
        work.setdefault("titulo", source["tituloObra"])
        if not work.get("titulo", "").strip():
            work["titulo"] = source["tituloObra"]
        return work

    def cite(item: dict) -> str:
        return citation(work_of(item["fonte"]), by_id[item["fonte"]], rule)

    def quoted(item: dict) -> str:
        return fill(texts["trecho"], trecho=excerpt(item["texto"]), citacao=cite(item))

    cited = analysis["definicoes"] + analysis["resumo"] + analysis["divergencias"]
    unique, seen = [], set()
    for item in cited:
        if (item["texto"], item["fonte"]) not in seen:
            seen.add((item["texto"], item["fonte"]))
            unique.append(item)

    # Side by side: every cited excerpt grouped by author (or by work when the author is unknown).
    groups = {}
    for item in unique:
        work = work_of(item["fonte"])
        known = work.get("autor", "").strip()
        who = spoken(known, rule) if known else fill(texts["semAutor"], obra=work["titulo"])
        group = groups.setdefault(fold(who), {"quem": who, "obras": [], "trechos": [], "_resumo": [],
                                              "_varios": len(authors(known, rule)) > 1})
        if work["titulo"] not in group["obras"]:
            group["obras"].append(work["titulo"])
        group["trechos"].append(quoted(item))
        if item in analysis["resumo"]:
            group["_resumo"].append(quoted(item))
    ordered = sorted(groups.items(), key=lambda kv: (-len(kv[1]["trechos"]), kv[0]))
    comparison = [{k: v for k, v in group.items() if not k.startswith("_")} for _, group in ordered]

    works_cited = []
    for item in unique:
        obra = by_id[item["fonte"]]["obraId"]
        if obra not in works_cited:
            works_cited.append(obra)

    introduction = [fill(texts["abertura"], n=len(works_cited), tema=topic) if unique else fill(texts["semTrechos"], tema=topic)]
    introduction += [fill(texts["definicao"], obra=work_of(item["fonte"])["titulo"], trecho=excerpt(item["texto"]), citacao=cite(item))
                     for item in analysis["definicoes"]]
    development = [fill(texts["autoresAfirmam" if group["_varios"] else "autorAfirma"], quem=group["quem"],
                        trechos="; ".join(group["_resumo"]))
                   for _, group in ordered if group["_resumo"]]
    divergences = [fill(texts["divergencia"], obra=work_of(item["fonte"])["titulo"], trecho=excerpt(item["texto"]), citacao=cite(item))
                   for item in analysis["divergencias"]]
    terms = [term["forma"] for term in analysis["termosAssociados"][:rule["limiteTermosConclusao"]]]
    conclusion = ([fill(texts["conclusaoTermos"], tema=topic, termos=join_list(terms, rule))] if terms else []) + [texts["conclusaoPendente"]]
    references = sorted({reference(work_of(next(i["fonte"] for i in unique if by_id[i["fonte"]]["obraId"] == obra)), rule)
                         for obra in works_cited}, key=lambda entry: (fold(entry), entry))

    names = rule["secoes"]
    sections = [{"titulo": names["introducao"], "paragrafos": introduction},
                {"titulo": names["desenvolvimento"], "paragrafos": development}]
    if divergences:
        sections.append({"titulo": names["divergencias"], "paragrafos": divergences})
    sections += [{"titulo": names["conclusao"], "paragrafos": conclusion},
                 {"titulo": names["referencias"], "paragrafos": references}]
    sections = [s for s in sections if s["paragrafos"]]
    title = fill(texts["titulo"], tema=topic)
    text = "\n\n".join([title] + [s["titulo"] + "\n\n" + "\n\n".join(s["paragrafos"]) for s in sections]) + "\n"
    return {"titulo": title, "secoes": sections, "comparacao": comparison, "referencias": references, "texto": text}


def build_cases(rule: dict) -> dict:
    cases = []
    for case in load(DOSSIER_CASES)["casos"]:
        analysis = case["esperado"]
        cases.append({"id": case["id"], "termo": case["termo"], "fontes": case["fontes"],
                      "dossie": {k: analysis[k] for k in ("definicoes", "resumo", "divergencias", "termosAssociados")},
                      "esperado": build(case["termo"], case["fontes"], analysis, TEST_WORKS, rule)})
    references = [{"obra": work, "referencia": reference(work, rule)} for work in [
        *TEST_WORKS.values(),
        {"titulo": "As 7 Palavras", "autor": "", "ano": "", "editora": "", "local": ""},
        {"titulo": "Os Princípios das Leis Maçônicas", "autor": "Albert G. Mackey", "ano": "2005", "editora": "Trolha", "local": ""},
    ]]
    return {"schemaVersion": 1,
            "descricao": "Casos de referencia da prancha (Paridade/prancha_v1.json), gerados por "
                         "Tools/prancha_referencia.py --atualizar sobre os casos do dossie. iOS e Android devem reproduzir cada resultado.",
            "obras": TEST_WORKS, "casos": cases, "referencias": references}


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--atualizar", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = build_cases(load(CONFIG))
    if args.atualizar:
        CASES.write_text(json.dumps(expected, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("Casos da prancha atualizados.")
    elif not CASES.exists() or load(CASES) != expected:
        raise SystemExit("Casos da prancha desatualizados em relacao a implementacao de referencia.")
    else:
        print("Casos da prancha: verificados.")


if __name__ == "__main__":
    main()
