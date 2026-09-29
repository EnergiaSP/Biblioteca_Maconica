#!/usr/bin/env python3
"""Rate the text quality of every work of the RAG collection and record it in the app catalogs.

Each page is rated with the shared rule (`Tools/qualidade_referencia.py`); each work entry of
`rag_catalogo.json` (iOS and Android copies) gets `qualidadeTexto` with the number of rated pages
and how many are noisy or unreadable. The apps derive the work level ("boa", "regular", "baixa")
with the same rule. A summary goes to `Paridade/qualidade_acervo_v1.json`.

    python3 Tools/avaliar_qualidade_acervo.py --pacotes DIR
"""
import argparse
import collections
import json
import sqlite3
from pathlib import Path

import qualidade_referencia as quality

ROOT = Path(__file__).resolve().parents[1]
CATALOGS = [ROOT / "BibliotecaMaconica_Dev/Resources/rag_catalogo.json",
            ROOT / "projetos/BreviarioMaconicoAndroid/app/src/main/assets/rag_catalogo.json"]
REPORT = ROOT / "Paridade/qualidade_acervo_v1.json"


def rate_packages(folder: Path, config: dict) -> dict:
    works = collections.defaultdict(lambda: {"avaliadas": 0, "ruidosas": 0, "ilegiveis": 0})
    reasons = collections.Counter()
    for path in sorted(list(folder.glob("*.sqlite")) + list(folder.glob("*/*.sqlite"))):
        con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        for work, text in con.execute("SELECT obra_id, texto_integral FROM rag_paginas"):
            result = quality.rate_page(text or "", config)
            if result["nivel"] == "curta":
                continue
            entry = works[work]
            entry["avaliadas"] += 1
            if result["nivel"] == "ruidosa":
                entry["ruidosas"] += 1
            elif result["nivel"] == "ilegivel":
                entry["ilegiveis"] += 1
            reasons.update(result["motivos"])
        con.close()
    return {"obras": dict(works), "motivos": dict(reasons.most_common())}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pacotes", type=Path, required=True)
    args = parser.parse_args()
    config = quality.load_config()
    rated = rate_packages(args.pacotes, config)
    works = rated["obras"]
    levels = collections.Counter()
    for catalog in CATALOGS:
        data = json.loads(catalog.read_text(encoding="utf-8"))
        for package in data["pacotes"]:
            for work in package.get("obras", []):
                entry = works.get(work["id"], {"avaliadas": 0, "ruidosas": 0, "ilegiveis": 0})
                work["qualidadeTexto"] = entry
        catalog.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for work, entry in works.items():
        levels[quality.work_level(entry["avaliadas"], entry["ruidosas"], entry["ilegiveis"], config)] += 1
    totals = {key: sum(entry[key] for entry in works.values()) for key in ("avaliadas", "ruidosas", "ilegiveis")}
    worst = sorted(works.items(), key=lambda item: -(item[1]["ruidosas"] + item[1]["ilegiveis"]) / max(1, item[1]["avaliadas"]))
    REPORT.write_text(json.dumps({
        "schemaVersion": 1,
        "descricao": "Qualidade do texto do acervo RAG pela regra Paridade/qualidade_texto_v1.json.",
        "paginas": totals,
        "obrasPorNivel": dict(sorted(levels.items())),
        "motivos": rated["motivos"],
        "obrasComMaisRuido": [{"obra": work, **entry,
                               "nivel": quality.work_level(entry["avaliadas"], entry["ruidosas"], entry["ilegiveis"], config)}
                              for work, entry in worst[:40]],
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"paginas": totals, "obrasPorNivel": dict(levels)}, ensure_ascii=False))
    print(f"Relatório: {REPORT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
