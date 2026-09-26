#!/usr/bin/env python3
"""Extrai as 365 leituras do Breviário de Rizzardo da Camino para o app."""

from __future__ import annotations

import argparse
import calendar
import json
import re
import unicodedata
from datetime import date, timedelta
from pathlib import Path

import pdfplumber


OBRA_ID = "breviario_rizzardo_da_camino"
AUTHOR = "Rizzardo da Camino"
FIRST_READING_PAGE = 17
READING_COUNT = 365
FALLBACK_TITLES_BY_PRINTED_PAGE = {34: "Akasha"}


def clean(value: str) -> str:
    value = value.replace("\u00ad", "").replace("\u2011", "-").replace("\u00a0", " ")
    return " ".join(value.split())


def normalized(value: str) -> str:
    return "".join(
        char for char in unicodedata.normalize("NFKD", value)
        if not unicodedata.combining(char)
    ).casefold()


def is_noise(value: str) -> bool:
    compact = re.sub(r"[^A-Za-zÀ-ÿ]", "", value)
    return not compact or len(compact) == 1


def join_body(lines: list[dict]) -> str:
    paragraphs: list[str] = []
    current = ""
    previous_bottom: float | None = None

    for line in lines:
        text = clean(line["text"])
        if not text or re.fullmatch(r"[-–—]?\s*\d{1,4}\s*[-–—]?", text):
            continue

        starts_paragraph = previous_bottom is not None and float(line["top"]) - previous_bottom > 5.5
        if starts_paragraph and current:
            paragraphs.append(current)
            current = text
        elif current.endswith("-") and text[:1].islower():
            current = current[:-1] + text
        elif current:
            current += " " + text
        else:
            current = text
        previous_bottom = float(line["bottom"])

    if current:
        paragraphs.append(current)
    return "\n\n".join(paragraphs)


def extract_entry(page, index: int) -> dict:
    lines = page.extract_text_lines(layout=False, strip=True, return_chars=True)
    dated = date(2025, 1, 1) + timedelta(days=index)

    title_lines: list[dict] = []
    for line in lines:
        top = float(line["top"])
        if not 125 <= top <= 235:
            continue
        sizes = [float(char.get("size", 0)) for char in line.get("chars", []) if char.get("text", "").strip()]
        if sizes and max(sizes) >= 23 and not is_noise(line["text"]):
            title_lines.append(line)

    printed_page = index + 20
    if title_lines:
        title = clean(" ".join(line["text"] for line in title_lines))
        title = re.sub(r"^[^A-Za-zÀ-ÿ]+", "", title).strip(" .,-")
        body_start = max(float(line["bottom"]) for line in title_lines) + 8
    else:
        title = FALLBACK_TITLES_BY_PRINTED_PAGE.get(printed_page, "")
        if not title:
            raise ValueError(f"Título não encontrado na página PDF {FIRST_READING_PAGE + index}")
        body_start = 190
    body_lines = [
        line for line in lines
        if float(line["top"]) >= body_start and float(line["bottom"]) <= page.height - 42
    ]
    body = join_body(body_lines)
    if len(body) < 40:
        raise ValueError(f"Texto insuficiente na página PDF {FIRST_READING_PAGE + index}")

    return {
        "id": index + 1,
        "data": dated.strftime("%d/%m"),
        "titulo": title,
        "frase": "",
        "texto": body,
        "rodape": "",
        "autor": AUTHOR,
        "pagina": printed_page,
        "obraID": OBRA_ID,
    }


def build(source: Path) -> dict:
    with pdfplumber.open(source) as pdf:
        expected_pages = FIRST_READING_PAGE + READING_COUNT - 1
        if len(pdf.pages) < expected_pages:
            raise ValueError(f"PDF incompleto: {len(pdf.pages)} páginas; esperadas ao menos {expected_pages}")
        items = [extract_entry(pdf.pages[FIRST_READING_PAGE - 1 + index], index) for index in range(READING_COUNT)]

    index_entries = [
        {"id": index + 1, "termo": item["titulo"], "paginas": [item["pagina"]], "datas": [item["data"]]}
        for index, item in enumerate(sorted(items, key=lambda item: normalized(item["titulo"])))
    ]
    return {"indiceRemissivo": index_entries, "itens": items}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("outputs", nargs="+", type=Path)
    args = parser.parse_args()

    data = build(args.source)
    payload = json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    for output in args.outputs:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(payload, encoding="utf-8")

    dates = {item["data"] for item in data["itens"]}
    assert len(data["itens"]) == READING_COUNT
    assert len(dates) == READING_COUNT
    assert all(date(2025, month, day).day == day for month in range(1, 13) for day in range(1, calendar.monthrange(2025, month)[1]))
    print(f"{READING_COUNT} leituras gravadas em {len(args.outputs)} arquivo(s).")


if __name__ == "__main__":
    main()
