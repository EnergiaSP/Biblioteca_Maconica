#!/usr/bin/env python3
"""Marks works whose content repeats another work (the same book imported twice) in the RAG catalog.

Reads the downloaded packages (read-only) and writes `duplicataDe` into the catalog bundled with both apps.
Two works are the same book when their fingerprints match (shared rule of Tools/dossie_referencia.py),
or when at least 90% of the pages of one are found, identical, in the other: the same file read by
different OCR runs, another scan of the same edition, or an excerpt of a complete work. The
packages themselves are not changed, so nothing needs to be republished.

    python3 Tools/marcar_duplicatas_catalogo.py <pasta RAGPackages> [--check]
"""
import argparse
import hashlib
import json
import re
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
# Share of the pages of a work found identical in another for it to be a copy, and the pages that count:
# with at least this many letters and digits (title pages and blank pages repeat in different books).
PAGES_SHARED = 0.9
PAGE_MIN_CHARS = 300


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
                hashes = {hashlib.sha1(text.encode()).hexdigest() for text in
                          (re.sub(r"\W+", "", (page or "").lower()) for page in pages) if len(text) >= PAGE_MIN_CHARS}
                result[work["id"]] = {"digital": fingerprint(pages, limit), "paginas": len(pages), "titulo": work["titulo"],
                                      "hashes": hashes}
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("packages", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    limit = json.loads(CONFIG.read_text())["limites"]["tokensImpressaoDigital"]
    catalog = json.loads(CATALOGS[0].read_text())
    works = fingerprints(args.packages, catalog, limit)
    # Union of the works that are the same book, by fingerprint or by shared pages.
    parent = {work_id: work_id for work_id in works}

    def root(work_id):
        while parent[work_id] != work_id:
            parent[work_id] = parent[parent[work_id]]
            work_id = parent[work_id]
        return work_id

    by_print = {}
    for work_id, info in works.items():
        by_print.setdefault(info["digital"], []).append(work_id)
    for members in by_print.values():
        for member in members[1:]:
            parent[root(member)] = root(members[0])
    owners = {}
    for work_id, info in works.items():
        for page in info["hashes"]:
            owners.setdefault(page, set()).add(work_id)
    for work_id, info in works.items():
        if len(info["hashes"]) < 5:
            continue
        shared = {}
        for page in info["hashes"]:
            for other in owners[page] - {work_id}:
                shared[other] = shared.get(other, 0) + 1
        for other, count in shared.items():
            if count >= PAGES_SHARED * len(info["hashes"]):
                parent[root(work_id)] = root(other)
    groups = {}
    for work_id in works:
        groups.setdefault(root(work_id), []).append(work_id)
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
