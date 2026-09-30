#!/usr/bin/env python3
"""Check a collection corrected by Tools/remover_texto_duplicado.py against the original.

* every package passes SQLite and FTS5 integrity checks;
* sample searches find the same pages before and after (only the doubled counts go down);
* every removed line has an equivalent kept on the same page, or was one half of a line written
  twice; the lines that fail this check are listed for review.

    python3 Tools/verificar_texto_duplicado.py --antes DIR --depois DIR
"""
import argparse
import difflib
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import remover_texto_duplicado as dedup  # noqa: E402

BUSCAS = ['"escada de jacó"', '"grande loja"', "acácia", "maçonaria", '"pedra bruta"', "hiram"]


def pacotes(pasta: Path) -> list:
    return sorted(list(pasta.glob("*.sqlite")) + list(pasta.glob("*/*.sqlite")))


def integridade(pasta: Path) -> list:
    erros = []
    for caminho in pacotes(pasta):
        con = sqlite3.connect(caminho)
        if con.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            erros.append(f"sqlite: {caminho.name}")
        try:
            con.execute("INSERT INTO rag_fts(rag_fts) VALUES('integrity-check')")
        except sqlite3.DatabaseError as erro:
            erros.append(f"fts: {caminho.name}: {erro}")
        con.close()
    return erros


def buscas(pasta: Path) -> dict:
    resultado = {}
    for termo in BUSCAS:
        paginas, ocorrencias = set(), 0
        for caminho in pacotes(pasta):
            con = sqlite3.connect(f"file:{caminho}?mode=ro", uri=True)
            for bloco, texto in con.execute("SELECT bloco_id, texto FROM rag_fts WHERE rag_fts MATCH ?", (termo,)):
                paginas.add((caminho.name, bloco))
                ocorrencias += texto.lower().count(termo.strip('"').lower())
            con.close()
        resultado[termo] = (paginas, ocorrencias)
    return resultado


def linhas_sem_equivalente(antes: Path, depois: Path, limite: int = 60):
    total, sem, exemplos = 0, 0, []
    for caminho in pacotes(antes):
        outro = depois / caminho.relative_to(antes)
        a = dict(sqlite3.connect(f"file:{caminho}?mode=ro", uri=True).execute("SELECT id, texto_integral FROM rag_paginas"))
        b = dict(sqlite3.connect(f"file:{outro}?mode=ro", uri=True).execute("SELECT id, texto_integral FROM rag_paginas"))
        for pagina, texto in a.items():
            if b[pagina] == texto:
                continue
            mantidas = [dedup.normalizar(l) for l in b[pagina].split("\n") if dedup.normalizar(l)]
            conjunto = set(mantidas)
            for linha in difflib.ndiff(texto.split("\n"), b[pagina].split("\n")):
                if not linha.startswith("- ") or not dedup.normalizar(linha[2:]):
                    continue
                total += 1
                normal = dedup.normalizar(linha[2:])
                if normal in conjunto or any(dedup.parecidas(normal, m) for m in mantidas):
                    continue
                partes = dedup.metades(linha[2:])
                if partes and any(dedup.normalizar(p) in conjunto for p in partes):
                    continue
                sem += 1
                if len(exemplos) < limite:
                    exemplos.append({"pacote": caminho.name, "pagina": pagina, "linha": linha[2:][:200]})
    return total, sem, exemplos


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--antes", type=Path, required=True)
    parser.add_argument("--depois", type=Path, required=True)
    args = parser.parse_args()
    erros = integridade(args.depois)
    antes, depois = buscas(args.antes), buscas(args.depois)
    comparacao = {termo: {"paginasAntes": len(antes[termo][0]), "paginasDepois": len(depois[termo][0]),
                          "ocorrenciasAntes": antes[termo][1], "ocorrenciasDepois": depois[termo][1],
                          "paginasPerdidas": len(antes[termo][0] - depois[termo][0])} for termo in BUSCAS}
    total, sem, exemplos = linhas_sem_equivalente(args.antes, args.depois)
    print(json.dumps({"errosDeIntegridade": erros, "buscas": comparacao,
                      "linhasRemovidas": total, "semEquivalente": sem, "exemplos": exemplos}, ensure_ascii=False, indent=2))
    if erros or any(c["paginasPerdidas"] for c in comparacao.values()):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
