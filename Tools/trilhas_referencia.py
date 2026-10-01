#!/usr/bin/env python3
"""Study tracks by degree (Fase 12): Aprendiz, Companheiro and Mestre, shared by iOS and Android.

`Paridade/trilhas_grau_base.json` holds the tracks written by hand (topics of each degree). This tool
adds the suggested works of each degree, found by title and subjects in the catalog, and writes
`Paridade/trilhas_grau_v1.json`. It also holds the reference of the progress rule; the native apps
must reproduce `Paridade/casos_trilhas_v1.json` exactly.

    python3 Tools/trilhas_referencia.py --atualizar   # regenerate the rule and the cases
    python3 Tools/trilhas_referencia.py --check       # verify both are up to date
"""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dossie_referencia import fold  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "Paridade/trilhas_grau_base.json"
CATALOG = ROOT / "BibliotecaMaconica_Dev/Resources/rag_catalogo.json"
RULE = ROOT / "Paridade/trilhas_grau_v1.json"
CASES = ROOT / "Paridade/casos_trilhas_v1.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def build_rule() -> dict:
    base = load(BASE)
    catalog = load(CATALOG)
    works = [(w["id"], w["titulo"], " ".join([w["titulo"], *w.get("assuntos", [])]))
             for package in catalog["pacotes"] for w in package["obras"] if not w.get("duplicataDe")]
    rule = dict(base)
    rule["graus"] = []
    for degree in base["graus"]:
        pattern = re.compile(degree["padraoObras"])
        extras = set(degree.get("obrasExtras", []))
        suggested = sorted((wid for wid, _, text in works if pattern.search(fold(text)) or wid in extras),
                           key=lambda wid: (fold(next(t for i, t, _ in works if i == wid)), wid))
        rule["graus"].append({**{k: v for k, v in degree.items() if k not in ("padraoObras", "obrasExtras")}, "obrasSugeridas": suggested})
    return rule


def study_key(topic: str) -> str:
    return " ".join(fold(topic).split())


def progress(rule: dict, saved_topics: list, marked: list) -> list:
    """Per degree: studied steps (a saved dossier on the topic or marked by hand), next step and milestone."""
    saved = {study_key(topic) for topic in saved_topics}
    result = []
    for degree in rule["graus"]:
        steps = degree["etapas"]
        done = [s["id"] for s in steps if s["id"] in marked or study_key(s["tema"]) in saved]
        total = len(steps)
        milestone = ""
        for item in rule["marcos"]:
            if len(done) >= max(1, -(-total * item["percentual"] // 100)):
                milestone = item["rotulo"]
        following = next((s["id"] for s in steps if s["id"] not in done), None)
        result.append({"grau": degree["id"], "concluidas": done, "total": total,
                       "percentual": len(done) * 100 // total if total else 0, "marco": milestone, "proxima": following})
    return result


def build_cases(rule: dict) -> dict:
    first = rule["graus"][0]["etapas"]
    last = rule["graus"][2]["etapas"]
    scenarios = [
        ("nada estudado", [], []),
        ("um dossie salvo conta a etapa", [first[0]["tema"].upper() + "  "], []),
        ("metade por dossies e marcas", [s["tema"] for s in first[: len(first) // 2]], [first[len(first) // 2]["id"]]),
        ("trilha concluida", [s["tema"] for s in first], []),
        ("marca de outro grau", [], [last[0]["id"], "etapa_inexistente"]),
        ("tema parecido nao conta", [first[0]["tema"] + " e outros"], []),
    ]
    return {"schemaVersion": 1,
            "descricao": "Casos de referencia das trilhas por grau (Paridade/trilhas_grau_v1.json), gerados por "
                         "Tools/trilhas_referencia.py --atualizar. iOS e Android devem reproduzir cada resultado.",
            "casos": [{"nome": name, "temasSalvos": saved, "marcadas": marked, "esperado": progress(rule, saved, marked)}
                      for name, saved, marked in scenarios]}


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--atualizar", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rule = build_rule()
    cases = build_cases(rule)
    if args.atualizar:
        RULE.write_text(json.dumps(rule, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        CASES.write_text(json.dumps(cases, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("Trilhas por grau atualizadas.")
    elif not RULE.exists() or load(RULE) != rule or not CASES.exists() or load(CASES) != cases:
        raise SystemExit("Trilhas por grau desatualizadas: rode Tools/trilhas_referencia.py --atualizar.")
    else:
        print("Trilhas por grau: verificadas.")


if __name__ == "__main__":
    main()
