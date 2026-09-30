#!/usr/bin/env python3
"""Bibliographic data of each work for ABNT references (Fase 11), shared by iOS and Android.

The catalog keeps only the title; most titles carry the author after a dash ("Título - Autor").
This tool separates them once, with the corrections of `Paridade/obras_referencias_manual.json`
(author, title, year, publisher and place filled by hand), and writes
`Paridade/obras_referencias_v1.json`, which both apps read as is.

    python3 Tools/referencias_obras.py --atualizar   # regenerate from the catalog
    python3 Tools/referencias_obras.py --check       # verify it is up to date
    python3 Tools/referencias_obras.py --listar      # print title and author of every work
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "BibliotecaMaconica_Dev/Resources/rag_catalogo.json"
MANUAL = ROOT / "Paridade/obras_referencias_manual.json"
OUTPUT = ROOT / "Paridade/obras_referencias_v1.json"

# Words that make the part after the dash a subtitle, a volume or a publisher, not a person.
NOT_AUTHOR = {
    "a", "o", "as", "os", "um", "uma", "do", "da", "dos", "das", "de", "e", "em", "no", "na", "para", "por",
    "vol", "volume", "versão", "versao", "síntese", "sintese", "editora", "curso", "capitulos", "capítulos",
    "série", "serie", "biblioteca", "manuscrito", "sociedades", "illuminati", "rito", "livro", "tomo", "parte",
    "edição", "edicao", "ed", "diplomados", "mm", "sca", "mores", "castigat", "cosmo", "comitê", "comite",
    "estudos", "introdução", "introducao", "resumo", "apostila", "revista", "boletim", "ritual", "grau",
}
PARTICLES = {"da", "de", "do", "das", "dos", "e", "del", "van", "von", "la", "le", "di"}
SUFFIXES = {"filho", "neto", "júnior", "junior", "jr", "sobrinho"}


def tidy(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("_", " ")).strip(" -–")


def is_person(part: str) -> bool:
    if "," in part:
        surname, _, given = part.partition(",")
        return bool(surname.strip()) and bool(given.strip()) and not re.search(r"\d", part)
    words = part.split()
    if not 1 <= len(words) <= 6 or re.search(r"\d", part):
        return False
    if words[0].lower() in NOT_AUTHOR or any(w.lower().strip(".") in NOT_AUTHOR - PARTICLES for w in words):
        return False
    return all(w[0].isupper() or w.lower() in PARTICLES for w in words)


def split_title(raw: str):
    """(title, author) from "Título - Autor"; author is "" when the last part is not a person."""
    text = raw.replace("_-_", " - ")
    if "-" in text and " " not in text.replace("_", " ").strip():
        text = text.replace("-", " ")  # "Corpus-Hermeticum-..." uses hyphens for spaces
    parts = [p for p in re.split(r"\s+[-–]\s+", text) if p.strip()]
    if len(parts) >= 2:
        author = re.sub(r"-\d+$", "", tidy(parts[-1])).replace("-", " ")
        if is_person(author):
            return tidy(" - ".join(parts[:-1])), author
    return tidy(text), ""


def build() -> dict:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    manual = json.loads(MANUAL.read_text(encoding="utf-8"))["obras"] if MANUAL.exists() else {}
    works = {}
    for package in catalog["pacotes"]:
        for work in package["obras"]:
            title, author = split_title(work["titulo"])
            entry = {"titulo": title, "autor": work.get("autor") or author, "ano": "", "editora": "", "local": ""}
            entry.update({k: v for k, v in manual.get(work["id"], {}).items() if k in entry})
            works[work["id"]] = entry
    for work_id, fields in manual.items():
        works.setdefault(work_id, {"titulo": "", "autor": "", "ano": "", "editora": "", "local": ""}).update(
            {k: v for k, v in fields.items() if k in ("titulo", "autor", "ano", "editora", "local")})
    return {"schemaVersion": 1,
            "descricao": "Dados bibliograficos das obras para as referencias ABNT, gerados por "
                         "Tools/referencias_obras.py a partir do catalogo e de obras_referencias_manual.json. "
                         "Campo vazio: nao informado.",
            "obras": dict(sorted(works.items()))}


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--atualizar", action="store_true")
    group.add_argument("--check", action="store_true")
    group.add_argument("--listar", action="store_true")
    args = parser.parse_args()
    expected = build()
    if args.listar:
        for work_id, entry in expected["obras"].items():
            print(f"{entry['autor'] or '—':32} | {entry['titulo']}  [{work_id}]")
    elif args.atualizar:
        OUTPUT.write_text(json.dumps(expected, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Referencias das obras atualizadas: {len(expected['obras'])} obra(s).")
    elif not OUTPUT.exists() or json.loads(OUTPUT.read_text(encoding="utf-8")) != expected:
        raise SystemExit("Referencias das obras desatualizadas: rode Tools/referencias_obras.py --atualizar.")
    else:
        print("Referencias das obras: verificadas.")


if __name__ == "__main__":
    main()
