#!/usr/bin/env python3
import json
import hashlib
import os
import shutil
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path.cwd()
REPORTS = ROOT / "ImportacaoLivrosPDF_OCR" / "_relatorios"
SOURCE_DB = REPORTS / "biblioteca-rag-preimport.sqlite"
OUTPUT_DIR = REPORTS / "RAGPackages"
RESOURCE_CATALOG = ROOT / "Resources" / "rag_catalogo.json"
REPORT_JSON = REPORTS / "rag_pacotes_relatorio.json"
REPORT_MD = REPORTS / "rag_pacotes_relatorio.md"
REMOTE_BASE_URL = os.environ.get("RAG_REMOTE_BASE_URL", "").rstrip("/")

AREAS = [
    ("breviarios", "Breviários"),
    ("dicionariosMaconicos", "Dicionários Maçônicos"),
    ("judiciarioMaconico", "Judiciário Maçônico"),
    ("bibliotecaMaconica", "Biblioteca Maçônica"),
]

BIBLIOTECA_AREA = "bibliotecaMaconica"


def connect(path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(path)
    con.execute("PRAGMA foreign_keys = ON")
    con.execute("PRAGMA journal_mode = DELETE")
    con.execute("PRAGMA synchronous = NORMAL")
    return con


def create_schema(con: sqlite3.Connection) -> None:
    con.executescript(
        """
        CREATE TABLE rag_obras (
            id TEXT PRIMARY KEY,
            area TEXT NOT NULL,
            tipo TEXT NOT NULL,
            titulo TEXT NOT NULL,
            autor TEXT,
            origem TEXT,
            edicao TEXT,
            assuntos_json TEXT NOT NULL,
            data_importacao REAL NOT NULL
        );

        CREATE TABLE rag_paginas (
            id TEXT PRIMARY KEY,
            obra_id TEXT NOT NULL REFERENCES rag_obras(id) ON DELETE CASCADE,
            numero_original INTEGER NOT NULL,
            titulo TEXT,
            texto_integral TEXT NOT NULL,
            largura REAL NOT NULL,
            altura REAL NOT NULL,
            UNIQUE(obra_id, numero_original)
        );

        CREATE TABLE rag_paragrafos (
            id TEXT PRIMARY KEY,
            obra_id TEXT NOT NULL REFERENCES rag_obras(id) ON DELETE CASCADE,
            pagina INTEGER NOT NULL,
            ordem INTEGER NOT NULL,
            texto TEXT NOT NULL,
            capitulo TEXT,
            secao TEXT,
            temas_json TEXT NOT NULL,
            palavras_chave_json TEXT NOT NULL
        );

        CREATE TABLE rag_notas (
            id TEXT PRIMARY KEY,
            obra_id TEXT NOT NULL REFERENCES rag_obras(id) ON DELETE CASCADE,
            pagina INTEGER NOT NULL,
            numero TEXT NOT NULL,
            texto TEXT NOT NULL
        );

        CREATE TABLE rag_imagens (
            id TEXT PRIMARY KEY,
            obra_id TEXT NOT NULL REFERENCES rag_obras(id) ON DELETE CASCADE,
            pagina INTEGER NOT NULL,
            caminho_relativo TEXT NOT NULL,
            largura REAL NOT NULL,
            altura REAL NOT NULL,
            descricao_ocr TEXT
        );

        CREATE VIRTUAL TABLE rag_fts USING fts5(
            bloco_id UNINDEXED,
            obra_id UNINDEXED,
            titulo_obra,
            area UNINDEXED,
            pagina UNINDEXED,
            texto,
            tokenize = 'unicode61 remove_diacritics 2'
        );

        CREATE INDEX idx_rag_paginas_obra ON rag_paginas(obra_id, numero_original);
        CREATE INDEX idx_rag_paragrafos_obra_pagina ON rag_paragrafos(obra_id, pagina);
        CREATE INDEX idx_rag_notas_obra_pagina ON rag_notas(obra_id, pagina);
        """
    )


def remove_database_files(path: Path) -> None:
    if path.exists():
        path.unlink()
    for suffix in ("-wal", "-shm", "-journal"):
        stale = Path(str(path) + suffix)
        if stale.exists():
            stale.unlink()


def table_count(con: sqlite3.Connection, table: str) -> int:
    return con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def area_stats(con: sqlite3.Connection, area: str) -> dict:
    query = """
    SELECT
        COUNT(*) AS obras,
        COALESCE((SELECT COUNT(*) FROM rag_paginas p JOIN rag_obras o ON o.id = p.obra_id WHERE o.area = ?), 0),
        COALESCE((SELECT COUNT(*) FROM rag_paragrafos p JOIN rag_obras o ON o.id = p.obra_id WHERE o.area = ?), 0),
        COALESCE((SELECT COUNT(*) FROM rag_notas n JOIN rag_obras o ON o.id = n.obra_id WHERE o.area = ?), 0),
        COALESCE((SELECT COUNT(*) FROM rag_imagens i JOIN rag_obras o ON o.id = i.obra_id WHERE o.area = ?), 0),
        COALESCE((SELECT COUNT(*) FROM rag_fts WHERE area = ?), 0)
    FROM rag_obras
    WHERE area = ?
    """
    row = con.execute(query, (area, area, area, area, area, area)).fetchone()
    return {
        "obras": row[0],
        "paginas": row[1],
        "paragrafos": row[2],
        "notas": row[3],
        "imagens": row[4],
        "blocosFTS": row[5],
    }


def package_summary(target: sqlite3.Connection, destination: Path, filename: str, area: str, title: str, nivel: str) -> dict:
    obras = [
        {
            "id": row[0],
            "titulo": row[1],
            "autor": row[2],
            "tipo": row[3],
            "paginas": row[4],
            "paragrafos": row[5],
            "notas": row[6],
            "assuntos": json.loads(row[7] or "[]"),
        }
        for row in target.execute(
            """
            SELECT
                o.id,
                o.titulo,
                o.autor,
                o.tipo,
                (SELECT COUNT(*) FROM rag_paginas p WHERE p.obra_id = o.id),
                (SELECT COUNT(*) FROM rag_paragrafos p WHERE p.obra_id = o.id),
                (SELECT COUNT(*) FROM rag_notas n WHERE n.obra_id = o.id),
                o.assuntos_json
            FROM rag_obras o
            ORDER BY o.titulo COLLATE NOCASE
            """
        )
    ]
    stats = {
        "obras": table_count(target, "rag_obras"),
        "paginas": table_count(target, "rag_paginas"),
        "paragrafos": table_count(target, "rag_paragrafos"),
        "notas": table_count(target, "rag_notas"),
        "imagens": table_count(target, "rag_imagens"),
        "blocosFTS": table_count(target, "rag_fts"),
    }

    return {
        "area": area,
        "titulo": title,
        "arquivo": filename,
        "url": f"{REMOTE_BASE_URL}/{filename}" if REMOTE_BASE_URL else None,
        "sha256": sha256_file(destination),
        "nivel": nivel,
        "tamanhoBytes": destination.stat().st_size,
        "estatisticas": stats,
        "obras": obras,
    }


def build_package(source: sqlite3.Connection, area: str, title: str) -> dict:
    filename = f"rag_{area}.sqlite"
    destination = OUTPUT_DIR / filename
    remove_database_files(destination)

    target = connect(destination)
    create_schema(target)
    target.execute("ATTACH DATABASE ? AS origem", (str(SOURCE_DB),))
    target.execute(
        """
        INSERT INTO rag_obras
        SELECT * FROM origem.rag_obras
        WHERE area = ?
        """,
        (area,),
    )
    target.execute(
        """
        INSERT INTO rag_paginas
        SELECT p.* FROM origem.rag_paginas p
        JOIN origem.rag_obras o ON o.id = p.obra_id
        WHERE o.area = ?
        """,
        (area,),
    )
    target.execute(
        """
        INSERT INTO rag_paragrafos
        SELECT p.* FROM origem.rag_paragrafos p
        JOIN origem.rag_obras o ON o.id = p.obra_id
        WHERE o.area = ?
        """,
        (area,),
    )
    target.execute(
        """
        INSERT INTO rag_notas
        SELECT n.* FROM origem.rag_notas n
        JOIN origem.rag_obras o ON o.id = n.obra_id
        WHERE o.area = ?
        """,
        (area,),
    )
    target.execute(
        """
        INSERT INTO rag_imagens
        SELECT i.* FROM origem.rag_imagens i
        JOIN origem.rag_obras o ON o.id = i.obra_id
        WHERE o.area = ?
        """,
        (area,),
    )
    target.execute(
        """
        INSERT INTO rag_fts (bloco_id, obra_id, titulo_obra, area, pagina, texto)
        SELECT bloco_id, obra_id, titulo_obra, area, pagina, texto
        FROM origem.rag_fts
        WHERE area = ?
        """,
        (area,),
    )
    target.commit()
    target.execute("DETACH DATABASE origem")
    target.commit()
    target.execute("VACUUM")
    target.execute("PRAGMA optimize")

    summary = package_summary(target, destination, filename, area, title, "area")
    target.close()
    return summary


def build_work_package(area: str, title: str, obra_id: str, obra_title: str) -> dict:
    safe_id = "".join(ch if ch.isalnum() or ch in ("-", "_") else "_" for ch in obra_id)
    relative_filename = f"{area}/rag_{safe_id}.sqlite"
    destination = OUTPUT_DIR / relative_filename
    destination.parent.mkdir(parents=True, exist_ok=True)
    remove_database_files(destination)

    target = connect(destination)
    create_schema(target)
    target.execute("ATTACH DATABASE ? AS origem", (str(SOURCE_DB),))
    target.execute(
        """
        INSERT INTO rag_obras
        SELECT * FROM origem.rag_obras
        WHERE id = ?
        """,
        (obra_id,),
    )
    target.execute(
        """
        INSERT INTO rag_paginas
        SELECT * FROM origem.rag_paginas
        WHERE obra_id = ?
        """,
        (obra_id,),
    )
    target.execute(
        """
        INSERT INTO rag_paragrafos
        SELECT * FROM origem.rag_paragrafos
        WHERE obra_id = ?
        """,
        (obra_id,),
    )
    target.execute(
        """
        INSERT INTO rag_notas
        SELECT * FROM origem.rag_notas
        WHERE obra_id = ?
        """,
        (obra_id,),
    )
    target.execute(
        """
        INSERT INTO rag_imagens
        SELECT * FROM origem.rag_imagens
        WHERE obra_id = ?
        """,
        (obra_id,),
    )
    target.execute(
        """
        INSERT INTO rag_fts (bloco_id, obra_id, titulo_obra, area, pagina, texto)
        SELECT bloco_id, obra_id, titulo_obra, area, pagina, texto
        FROM origem.rag_fts
        WHERE obra_id = ?
        """,
        (obra_id,),
    )
    target.commit()
    target.execute("DETACH DATABASE origem")
    target.commit()
    target.execute("VACUUM")
    target.execute("PRAGMA optimize")

    summary = package_summary(target, destination, relative_filename, area, obra_title, "obra")
    target.close()
    return summary


def build_biblioteca_packages(source: sqlite3.Connection, area: str, title: str) -> list[dict]:
    rows = source.execute(
        """
        SELECT id, titulo
        FROM rag_obras
        WHERE area = ?
        ORDER BY titulo COLLATE NOCASE
        """,
        (area,),
    ).fetchall()

    packages = []
    total = len(rows)
    for index, (obra_id, obra_title) in enumerate(rows, start=1):
        print(f"Gerando obra {index}/{total}: {obra_title}", flush=True)
        packages.append(build_work_package(area, title, obra_id, obra_title))
    return packages


def main() -> None:
    if not SOURCE_DB.exists():
        raise SystemExit(f"Banco origem nao encontrado: {SOURCE_DB}")

    if OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    source = connect(SOURCE_DB)
    packages = []
    filtro_areas = set()
    if "--area" in sys.argv:
        indice = sys.argv.index("--area")
        if indice + 1 < len(sys.argv):
            filtro_areas.add(sys.argv[indice + 1])

    for area, title in AREAS:
        if filtro_areas and area not in filtro_areas:
            continue
        stats = area_stats(source, area)
        if stats["obras"] == 0:
            continue
        if area == BIBLIOTECA_AREA:
            print(f"Gerando pacotes por obra em {title}: {stats['obras']} obra(s)")
            packages.extend(build_biblioteca_packages(source, area, title))
        else:
            print(f"Gerando pacote {title}: {stats['obras']} obra(s)")
            packages.append(build_package(source, area, title))
    source.close()

    catalog = {
        "versaoFormato": 1,
        "geradoEm": datetime.now(timezone.utc).isoformat(),
        "origem": str(SOURCE_DB),
        "baseURL": REMOTE_BASE_URL or None,
        "estrategia": "catalogo_leve_com_pacotes_por_area_e_biblioteca_por_obra",
        "pacotes": packages,
        "totais": {
            "pacotes": len(packages),
            "obras": sum(p["estatisticas"]["obras"] for p in packages),
            "paginas": sum(p["estatisticas"]["paginas"] for p in packages),
            "paragrafos": sum(p["estatisticas"]["paragrafos"] for p in packages),
            "notas": sum(p["estatisticas"]["notas"] for p in packages),
            "blocosFTS": sum(p["estatisticas"]["blocosFTS"] for p in packages),
            "tamanhoBytes": sum(p["tamanhoBytes"] for p in packages),
        },
    }

    REPORT_JSON.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")
    RESOURCE_CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")

    lines = [
        "# Pacotes RAG da Biblioteca",
        "",
        f"Gerado em: {catalog['geradoEm']}",
        f"Pacotes: {catalog['totais']['pacotes']}",
        f"Obras: {catalog['totais']['obras']}",
        f"Páginas: {catalog['totais']['paginas']}",
        f"Blocos pesquisáveis: {catalog['totais']['blocosFTS']}",
        f"Notas: {catalog['totais']['notas']}",
        f"Tamanho total: {catalog['totais']['tamanhoBytes'] / 1024 / 1024:.1f} MB",
        "",
        "## Pacotes",
    ]
    for package in packages:
        stats = package["estatisticas"]
        lines.append(
            f"- {package['titulo']}: {stats['obras']} obras, {stats['paginas']} páginas, "
            f"{stats['blocosFTS']} blocos, {stats['notas']} notas, "
            f"{package['tamanhoBytes'] / 1024 / 1024:.1f} MB"
        )
    REPORT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Catalogo: {RESOURCE_CATALOG}")
    print(f"Relatorio: {REPORT_MD}")


if __name__ == "__main__":
    main()
