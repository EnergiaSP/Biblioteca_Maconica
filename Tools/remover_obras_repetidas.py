#!/usr/bin/env python3
"""Removes from the collection the works whose content is already in another, keeping the most complete.

Each work is reduced to the 8-word passages of its text (a sample of one in four, by hash). A work
whose passages are at least 90% inside another work is a copy of it: the same book imported twice,
another scan or OCR of the same edition, or a part of a complete work. In each group of copies the
most complete one stays (most passages; sizes within 3% are a tie, since OCR runs differ a little);
ties keep the work used by the degree tracks, then one with an author in the references, then the best
text quality, then the smallest id. Works that share less
than 90% keep both, since each one has its own content.

Removed works leave the catalog of both apps: a work package is dropped; a work inside an area package
is deleted from that package, which is rebuilt into --novos (to be published under a new version folder
with Tools/atualizar_catalogo_pacotes.py). The apps then delete the files that left the catalog.

    python3 Tools/remover_obras_repetidas.py --pacotes DIR [--novos DIR --gravar]
"""
import argparse
import collections
import glob
import hashlib
import json
import re
import shutil
import sqlite3
import unicodedata
from pathlib import Path

import qualidade_referencia as quality

ROOT = Path(__file__).resolve().parents[1]
CATALOGS = [ROOT / "BibliotecaMaconica_Dev/Resources/rag_catalogo.json",
            ROOT / "projetos/BreviarioMaconicoAndroid/app/src/main/assets/rag_catalogo.json"]
TRACKS = ROOT / "Paridade/trilhas_grau_v1.json"
REFERENCES = ROOT / "Paridade/obras_referencias_v1.json"
REPORT = ROOT / "Paridade/obras_removidas_v1.json"
CONTAINED = 0.9


def fold(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", text.lower()) if unicodedata.category(c) != "Mn")


def passages(text: str) -> set:
    words = re.findall(r"[a-z0-9]+", fold(text))
    result = set()
    for i in range(max(0, len(words) - 8)):
        digest = hashlib.md5(" ".join(words[i:i + 8]).encode()).digest()
        if digest[0] % 4 == 0:
            result.add(digest[:8])
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pacotes", type=Path, required=True)
    parser.add_argument("--novos", type=Path)
    parser.add_argument("--gravar", action="store_true")
    args = parser.parse_args()
    catalog = json.loads(CATALOGS[0].read_text(encoding="utf-8"))
    package_of = {w["id"]: p for p in catalog["pacotes"] for w in p["obras"]}
    config = quality.load_config()
    texts, bad_pages = {}, {}
    for path in sorted(glob.glob(str(args.pacotes / "**/*.sqlite"), recursive=True)):
        con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        for work, text in con.execute("SELECT obra_id, texto_integral FROM rag_paginas ORDER BY obra_id, numero_original"):
            if work not in package_of:
                continue
            texts.setdefault(work, []).append(text or "")
        con.close()
    sets = {work: passages(" ".join(pages)) for work, pages in texts.items()}
    for work, pages in texts.items():
        bad_pages[work] = sum(quality.rate_page(p, config)["nivel"] in ("ruidosa", "ilegivel") for p in pages)
    index = collections.defaultdict(set)
    for work, items in sets.items():
        for item in items:
            index[item].add(work)
    shared = collections.Counter()
    for owners in index.values():
        if 1 < len(owners) < 6:
            ordered = sorted(owners)
            for i in range(len(ordered)):
                for j in range(i + 1, len(ordered)):
                    shared[(ordered[i], ordered[j])] += 1
    tracks = {w for g in json.loads(TRACKS.read_text())["graus"] for w in g.get("obrasSugeridas", [])}
    references = json.loads(REFERENCES.read_text())["obras"]

    def priority(work, largest):
        return (len(sets[work]) < 0.97 * largest, work not in tracks, not references.get(work, {}).get("autor"),
                bad_pages[work], -len(sets[work]), work)

    parent = {work: work for work in sets}

    def root(work):
        while parent[work] != work:
            parent[work] = parent[parent[work]]
            work = parent[work]
        return work

    pairs = []
    for (a, b), count in shared.items():
        a_in_b, b_in_a = count / max(1, len(sets[a])), count / max(1, len(sets[b]))
        if max(a_in_b, b_in_a) >= CONTAINED:
            pairs.append({"a": a, "b": b, "a_em_b": round(a_in_b, 3), "b_em_a": round(b_in_a, 3)})
            parent[root(a)] = root(b)
    groups = collections.defaultdict(list)
    for work in sets:
        groups[root(work)].append(work)
    removed, report = {}, []
    for members in groups.values():
        if len(members) < 2:
            continue
        largest = max(len(sets[m]) for m in members)
        kept = sorted(members, key=lambda m: priority(m, largest))[0]
        for member in members:
            if member != kept:
                removed[member] = kept
        report.append({"mantida": kept, "passagensMantida": len(sets[kept]),
                       "removidas": [{"id": m, "passagens": len(sets[m]), "paginasRuins": bad_pages[m]}
                                     for m in sorted(members) if m != kept]})
    report.sort(key=lambda g: g["mantida"])
    for group in report:
        print(f"MANTER {group['mantida']} ({group['passagensMantida']})")
        for item in group["removidas"]:
            print(f"   remover {item['id']} ({item['passagens']}) [{package_of[item['id']]['arquivo']}]")
    print(f"{len(removed)} obra(s) a remover em {len(report)} grupo(s)")
    if not args.gravar:
        return
    # Area packages lose the removed works; work packages leave the catalog.
    rebuilt = set()
    for work in removed:
        package = package_of[work]
        if len(package["obras"]) > 1:
            target = args.novos / package["arquivo"]
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(args.pacotes / package["arquivo"], target)
            con = sqlite3.connect(target)
            for table in ("rag_fts", "rag_paragrafos", "rag_notas", "rag_imagens", "rag_paginas", "rag_obras"):
                column = "id" if table == "rag_obras" else "obra_id"
                con.execute(f"DELETE FROM {table} WHERE {column} = ?", (work,))
            con.commit()
            con.execute("VACUUM")
            con.close()
            rebuilt.add(package["arquivo"])
    for path in CATALOGS:
        data = json.loads(path.read_text(encoding="utf-8"))
        packages = []
        for package in data["pacotes"]:
            package["obras"] = [w for w in package["obras"] if w["id"] not in removed]
            if package["obras"]:
                packages.append(package)
        data["pacotes"] = packages
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    REPORT.write_text(json.dumps({
        "schemaVersion": 1,
        "descricao": "Obras removidas do acervo por terem o conteúdo em outra mais completa "
                     "(Tools/remover_obras_repetidas.py: 90% ou mais das passagens de 8 palavras na outra).",
        "grupos": report, "pares": sorted(pairs, key=lambda p: (p["a"], p["b"])),
        "pacotesRefeitos": sorted(rebuilt)}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Pacotes de área refeitos: {sorted(rebuilt)}")


if __name__ == "__main__":
    main()
