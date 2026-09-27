#!/usr/bin/env python3
"""Marks works whose content repeats another work (the same book imported twice) in the RAG catalog.

Reads the downloaded packages (read-only), computes each work's fingerprint with the shared rule of
Tools/dossie_referencia.py and writes `duplicataDe` into the catalog bundled with both apps. The
packages themselves are not changed, so nothing needs to be republished.

    python3 Tools/marcar_duplicatas_catalogo.py <pasta RAGPackages> [--check]
"""
import argparse
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dossie_referencia import fingerprint  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CATALOGS = [ROOT / "BibliotecaMaconica_Dev/Resources/rag_catalogo.json",
            ROOT / "projetos/BreviarioMaconicoAndroid/app/src/main/assets/rag_catalogo.json"]
CONFIG = ROOT / "Paridade/estudo_dossie_v1.json"
REPORT = ROOT / "Paridade/duplicatas_catalogo_v1.json"


def fingerprints(packages: Path, catalog: dict, limit: int) -> dict:
    result = {}
    for package in catalog["pacotes"]:
        path = packages / package["arquivo"]
        if not path.exists():
            raise SystemExit(f"Pacote ausente: {path}")
        with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as connection:
            for work in package["obras"]:
                pages = [row[0] for row in connection.execute(
                    "SELECT texto_integral FROM rag_paginas WHERE obra_id = ? ORDER BY numero_original", (work["id"],))]
                result[work["id"]] = {"digital": fingerprint(pages, limit), "paginas": len(pages), "titulo": work["titulo"]}
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("packages", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    limit = json.loads(CONFIG.read_text())["limites"]["tokensImpressaoDigital"]
    catalog = json.loads(CATALOGS[0].read_text())
    works = fingerprints(args.packages, catalog, limit)
    groups = {}
    for work_id, info in works.items():
        groups.setdefault(info["digital"], []).append(work_id)
    duplicate_of = {}
    for members in groups.values():
        if len(members) < 2:
            continue
        # The copy with most pages is kept; ties keep the smallest id, so the choice is stable.
        canonical = sorted(members, key=lambda w: (-works[w]["paginas"], w))[0]
        for member in members:
            if member != canonical:
                duplicate_of[member] = canonical
    for package in catalog["pacotes"]:
        for work in package["obras"]:
            if work["id"] in duplicate_of:
                work["duplicataDe"] = duplicate_of[work["id"]]
            else:
                work.pop("duplicataDe", None)
    text = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    report = {"obras": len(works), "duplicadas": len(duplicate_of),
              "grupos": [{"mantida": {"id": canonical, "titulo": works[canonical]["titulo"], "paginas": works[canonical]["paginas"]},
                          "duplicadas": [{"id": member, "titulo": works[member]["titulo"], "paginas": works[member]["paginas"]}
                                         for member in sorted(m for m, c in duplicate_of.items() if c == canonical)]}
                         for canonical in sorted(set(duplicate_of.values()))]}
    if args.check:
        current = [json.loads(path.read_text()) for path in CATALOGS]
        if any(c != catalog for c in current):
            raise SystemExit("Catalogo desatualizado em relacao as duplicatas calculadas.")
        print("Duplicatas do catalogo: verificadas.")
        return
    for path in CATALOGS:
        path.write_text(text)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ("obras", "duplicadas")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
