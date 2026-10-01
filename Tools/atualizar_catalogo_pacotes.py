#!/usr/bin/env python3
"""Points the RAG catalog of both apps at rebuilt packages (a redone OCR, for instance).

Each package of --novos replaces the one with the same path in the local collection (the old file
is kept in --guardar) and its catalog entry gets the new address (--base-url, a new version folder
in R2, so the files in use are never overwritten), SHA-256, size and counts. Packages that did not
change keep their entries. The new files must be uploaded to --base-url before an app with this
catalog is released: the apps check each download against the SHA-256 of the catalog.

    python3 Tools/atualizar_catalogo_pacotes.py --novos DIR --base-url https://.../rag/v5 [--gravar]
"""
import argparse
import hashlib
import json
import shutil
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOGS = [ROOT / "BibliotecaMaconica_Dev/Resources/rag_catalogo.json",
            ROOT / "projetos/BreviarioMaconicoAndroid/app/src/main/assets/rag_catalogo.json"]
PACKAGES = ROOT / "BibliotecaMaconica_Dev/ImportacaoLivrosPDF_OCR/_relatorios/RAGPackages"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def counts(path: Path) -> dict:
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    count = lambda table: con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    result = {"obras": count("rag_obras"), "paginas": count("rag_paginas"), "paragrafos": count("rag_paragrafos"),
              "notas": count("rag_notas"), "imagens": count("rag_imagens"), "blocosFTS": count("rag_fts")}
    con.close()
    return result


def recount(catalog: dict) -> None:
    """Totals of the catalog from its packages (works may have left it)."""
    totals = catalog.setdefault("totais", {})
    stats = [p.get("estatisticas", {}) for p in catalog["pacotes"]]
    for key in ("blocosFTS", "notas", "paginas", "paragrafos"):
        if key in totals:
            totals[key] = sum(s.get(key, 0) for s in stats)
    totals["obras"] = sum(len(p["obras"]) for p in catalog["pacotes"])
    totals["pacotes"] = len(catalog["pacotes"])
    totals["tamanhoBytes"] = sum(p["tamanhoBytes"] for p in catalog["pacotes"])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--novos", type=Path, required=True)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--guardar", type=Path, default=PACKAGES.parent / "RAGPackages_substituidos")
    parser.add_argument("--gravar", action="store_true")
    args = parser.parse_args()
    base = args.base_url.rstrip("/")
    new_files = {str(p.relative_to(args.novos)): p for p in sorted(args.novos.rglob("*.sqlite"))}
    catalog = json.loads(CATALOGS[0].read_text(encoding="utf-8"))
    changed = []
    for package in catalog["pacotes"]:
        source = new_files.get(package["arquivo"])
        if not source:
            continue
        stats = counts(source)
        for key, value in stats.items():
            if key in package.get("estatisticas", {}):
                package["estatisticas"][key] = value
        package.update({"url": f"{base}/{package['arquivo']}", "sha256": sha256(source), "tamanhoBytes": source.stat().st_size})
        changed.append(package["arquivo"])
    missing = sorted(set(new_files) - set(changed))
    if missing:
        raise SystemExit(f"Pacotes fora do catálogo: {missing}")
    print(f"{len(changed)} pacote(s) apontados para {base}")
    if not args.gravar:
        return
    for name in changed:
        current, backup = PACKAGES / name, args.guardar / name
        backup.parent.mkdir(parents=True, exist_ok=True)
        if current.exists() and not backup.exists():
            shutil.copy2(current, backup)
        shutil.copy2(new_files[name], current)
    recount(catalog)
    text = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    for path in CATALOGS:
        path.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
