#!/usr/bin/env python3
"""Read-only integrity/FTS benchmark. Desktop timings are not mobile benchmarks."""
import hashlib
import json
import sqlite3
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / "BibliotecaMaconica_Dev/Resources/rag_catalogo.json").read_text())
packages = root / "BibliotecaMaconica_Dev/ImportacaoLivrosPDF_OCR/_relatorios/RAGPackages"
output = root / "Paridade/evidencias/2026-09-18/medicao-acervo-local.json"
results = []
queries = ['"maçonaria"', '"grande loja"', '"ética" AND "virtude"']
start = time.perf_counter()
for package in catalog["pacotes"]:
    path = packages / package["arquivo"]
    result = {"package": package["arquivo"], "exists": path.is_file()}
    if not path.is_file():
        results.append(result)
        continue
    try:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        result["sha256Matches"] = digest.hexdigest() == package["sha256"]
        with sqlite3.connect(path.as_uri() + "?mode=ro", uri=True) as db:
            result["quickCheck"] = db.execute("PRAGMA quick_check").fetchone()[0]
            result["pages"] = db.execute("SELECT count(*) FROM rag_paginas").fetchone()[0]
            result["paragraphs"] = db.execute("SELECT count(*) FROM rag_paragrafos").fetchone()[0]
            result["timings"] = []
            for query in queries:
                tick = time.perf_counter()
                hits = db.execute("SELECT bloco_id FROM rag_fts WHERE rag_fts MATCH ? ORDER BY bm25(rag_fts) LIMIT 120", (query,)).fetchall()
                result["timings"].append({"query": query, "seconds": time.perf_counter() - tick, "hits": len(hits)})
    except Exception as error:
        result["error"] = str(error)
    results.append(result)
    print(f'{len(results)}/{len(catalog["pacotes"])} {package["arquivo"]}', flush=True)
report = {"platform": "desktop-local-readonly", "mobileValidated": False,
          "elapsedSeconds": time.perf_counter() - start, "packages": results}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2, ensure_ascii=False))
print(output)
raise SystemExit(int(any(not r["exists"] or r.get("error") or not r.get("sha256Matches") or r.get("quickCheck") != "ok" for r in results)))
