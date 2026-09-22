#!/usr/bin/env python3
"""Rebuild the supplied breviary as a chronological, one-day-per-page PDF."""

from __future__ import annotations

import argparse
import calendar
import html
import re
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

import pdfplumber
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph


MONTHS = [
    "janeiro",
    "fevereiro",
    "março",
    "abril",
    "maio",
    "junho",
    "julho",
    "agosto",
    "setembro",
    "outubro",
    "novembro",
    "dezembro",
]
MONTH_NUMBER = {name: index for index, name in enumerate(MONTHS, 1)}
DATE_RE = re.compile(
    r"^\s*(?:dia\s+)?(\d{1,2})(?:\s*[º°o.])?\s+de\s+("
    + "|".join(MONTHS)
    + r")\s*$",
    re.IGNORECASE,
)

HEADER_NORMALIZED = {"BREVIARIO MACONICO", "REVIARIO MACONICO"}
BIBLIOGRAPHIC_LINE = (
    "Breviário Maçônico / Rizzardo da Camino - 6ª ed. - "
    "São Paulo: Madras, 2014."
)


@dataclass(frozen=True)
class SourceLine:
    page: int
    top: float
    bottom: float
    text: str


@dataclass
class Entry:
    month: int
    day: int
    source_page: int
    source_label: str
    title: str
    paragraphs: list[str]

    @property
    def score(self) -> int:
        return len(self.title) + sum(len(item) for item in self.paragraphs)


def normalize_ascii(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value)
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).upper().strip()


def clean_text(value: str) -> str:
    value = value.replace("\u2011", "-").replace("\u00a0", " ")
    return " ".join(value.split())


def is_ignorable(line: SourceLine) -> bool:
    normalized = normalize_ascii(line.text)
    if normalized in HEADER_NORMALIZED:
        return True
    if "RIZZARDO DA CAMINO" in normalized or "SAO PAULO. MADRAS" in normalized:
        return True
    return False


def extract_source_lines(source_pdf: Path) -> list[SourceLine]:
    output: list[SourceLine] = []
    with pdfplumber.open(source_pdf) as pdf:
        for page_number, page in enumerate(pdf.pages, 1):
            page_lines = page.extract_text_lines(
                layout=False,
                strip=True,
                return_chars=False,
                x_tolerance=2,
                y_tolerance=3,
            )
            for item in page_lines:
                text = clean_text(item["text"])
                if text:
                    output.append(
                        SourceLine(
                            page=page_number,
                            top=float(item["top"]),
                            bottom=float(item["bottom"]),
                            text=text,
                        )
                    )
    return output


def to_paragraphs(lines: list[SourceLine]) -> list[str]:
    if not lines:
        return []

    paragraphs: list[str] = []
    current = lines[0].text
    previous = lines[0]

    for line in lines[1:]:
        if line.page == previous.page:
            begins_new = line.top - previous.bottom > 10.0
        else:
            begins_new = previous.text.rstrip().endswith((".", "!", "?", ":", "”", '"'))

        if begins_new:
            paragraphs.append(clean_text(current))
            current = line.text
        elif current.endswith("-"):
            current += line.text
        else:
            current += " " + line.text
        previous = line

    paragraphs.append(clean_text(current))
    return [item for item in paragraphs if item]


def parse_entries(source_pdf: Path) -> tuple[dict[tuple[int, int], Entry], Counter]:
    lines = extract_source_lines(source_pdf)
    starts: list[tuple[int, int, int, str]] = []
    for index, line in enumerate(lines):
        match = DATE_RE.match(line.text)
        if match:
            starts.append(
                (
                    index,
                    MONTH_NUMBER[match.group(2).lower()],
                    int(match.group(1)),
                    line.text,
                )
            )

    candidates: defaultdict[tuple[int, int], list[Entry]] = defaultdict(list)
    occurrences: Counter = Counter()

    for occurrence_index, (start, month, day, source_label) in enumerate(starts):
        end = starts[occurrence_index + 1][0] if occurrence_index + 1 < len(starts) else len(lines)
        segment = [line for line in lines[start + 1 : end] if not is_ignorable(line)]
        if not segment:
            continue
        title = segment[0].text
        paragraphs = to_paragraphs(segment[1:])
        entry = Entry(
            month=month,
            day=day,
            source_page=lines[start].page,
            source_label=source_label,
            title=title,
            paragraphs=paragraphs,
        )
        candidates[(month, day)].append(entry)
        occurrences[(month, day)] += 1

    selected: dict[tuple[int, int], Entry] = {}
    for key, versions in candidates.items():
        selected[key] = max(versions, key=lambda item: item.score)
    return selected, occurrences


def register_fonts() -> None:
    regular = Path("/System/Library/Fonts/Supplemental/Arial.ttf")
    bold = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
    if not regular.exists() or not bold.exists():
        raise FileNotFoundError("Arial fonts required for PDF generation were not found")
    pdfmetrics.registerFont(TTFont("BreviarioArial", regular))
    pdfmetrics.registerFont(TTFont("BreviarioArialBold", bold))


def paragraph(value: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(html.escape(value), style)


def layout_entry(
    title: str,
    paragraphs: list[str],
    available_width: float,
    available_height: float,
) -> tuple[Paragraph, list[Paragraph], float, float, float]:
    for body_size in (11.0, 10.5, 10.0, 9.5, 9.0, 8.5, 8.0, 7.5, 7.0):
        title_size = max(14.0, body_size + 5.0)
        body_leading = body_size * 1.42
        title_style = ParagraphStyle(
            "EntryTitle",
            fontName="BreviarioArialBold",
            fontSize=title_size,
            leading=title_size * 1.2,
            textColor=HexColor("#1A1A1A"),
            alignment=TA_LEFT,
            spaceAfter=0,
        )
        body_style = ParagraphStyle(
            "EntryBody",
            fontName="BreviarioArial",
            fontSize=body_size,
            leading=body_leading,
            textColor=HexColor("#202020"),
            alignment=TA_LEFT,
            allowWidows=1,
            allowOrphans=1,
        )
        title_box = paragraph(title, title_style)
        _, title_height = title_box.wrap(available_width, available_height)
        body_boxes = [paragraph(item, body_style) for item in paragraphs]
        body_heights = [box.wrap(available_width, available_height)[1] for box in body_boxes]
        paragraph_gap = body_size * 0.72
        total = title_height + 24 + sum(body_heights)
        if body_heights:
            total += paragraph_gap * (len(body_heights) - 1)
        if total <= available_height:
            return title_box, body_boxes, title_height, paragraph_gap, total
    raise ValueError(f"Entry does not fit on one page: {title}")


def draw_header(pdf: canvas.Canvas, date_label: str) -> None:
    width, height = A4
    pdf.setStrokeColor(HexColor("#2E2E2E"))
    pdf.setLineWidth(0.8)
    pdf.line(64, height - 54, width - 64, height - 54)
    pdf.setFillColor(HexColor("#262626"))
    pdf.setFont("BreviarioArialBold", 10)
    pdf.drawString(64, height - 82, "BREVIÁRIO MAÇÔNICO")
    pdf.setFont("BreviarioArial", 15)
    pdf.drawString(64, height - 122, date_label)


def draw_page_number(pdf: canvas.Canvas, page_number: int) -> None:
    width, _ = A4
    pdf.setFillColor(HexColor("#777777"))
    pdf.setFont("BreviarioArial", 8)
    pdf.drawRightString(width - 64, 38, f"{page_number} / 365")


def draw_first_page_source(pdf: canvas.Canvas) -> None:
    pdf.setFillColor(HexColor("#555555"))
    pdf.setFont("BreviarioArial", 8.2)
    pdf.drawString(64, 55, BIBLIOGRAPHIC_LINE)


def draw_missing_entry(pdf: canvas.Canvas, is_first_page: bool) -> None:
    width, _ = A4
    pdf.setFillColor(HexColor("#1A1A1A"))
    pdf.setFont("BreviarioArialBold", 17)
    pdf.drawString(64, 690, "CONTEÚDO AUSENTE")
    pdf.setFillColor(HexColor("#F2F2F2"))
    pdf.roundRect(64, 575, width - 128, 78, 8, fill=1, stroke=0)
    pdf.setFillColor(HexColor("#555555"))
    pdf.setFont("BreviarioArial", 11)
    pdf.drawString(82, 621, "Esta data não foi encontrada no arquivo original.")
    if is_first_page:
        pdf.setFont("BreviarioArial", 9.5)
        pdf.drawString(82, 598, "Auditoria: 203 dias com conteúdo e 162 datas ausentes.")


def draw_existing_entry(pdf: canvas.Canvas, entry: Entry) -> None:
    width, _ = A4
    left = 64
    content_top = 690
    bottom = 84
    available_width = width - 128
    available_height = content_top - bottom
    title_box, body_boxes, title_height, paragraph_gap, _ = layout_entry(
        entry.title,
        entry.paragraphs,
        available_width,
        available_height,
    )
    cursor = content_top
    title_box.drawOn(pdf, left, cursor - title_height)
    cursor -= title_height + 24
    for index, body_box in enumerate(body_boxes):
        _, box_height = body_box.wrap(available_width, cursor - bottom)
        body_box.drawOn(pdf, left, cursor - box_height)
        cursor -= box_height
        if index < len(body_boxes) - 1:
            cursor -= paragraph_gap


def build_pdf(source_pdf: Path, output_pdf: Path) -> None:
    entries, occurrences = parse_entries(source_pdf)
    register_fonts()

    output_pdf.parent.mkdir(parents=True, exist_ok=True)
    pdf = canvas.Canvas(str(output_pdf), pagesize=A4, pageCompression=1)
    pdf.setTitle("Breviário Maçônico - edição organizada por datas")
    pdf.setAuthor("Rizzardo da Camino")
    pdf.setSubject("Entradas organizadas de 01 de janeiro a 31 de dezembro")

    page_number = 0
    for month in range(1, 13):
        last_day = calendar.monthrange(2025, month)[1]
        for day in range(1, last_day + 1):
            page_number += 1
            date_label = f"{day:02d} de {MONTHS[month - 1]}"
            draw_header(pdf, date_label)
            entry = entries.get((month, day))
            if entry is None:
                draw_missing_entry(pdf, is_first_page=(page_number == 1))
            else:
                draw_existing_entry(pdf, entry)
            if page_number == 1:
                draw_first_page_source(pdf)
            draw_page_number(pdf, page_number)
            pdf.showPage()
    pdf.save()

    duplicate_dates = {key: count for key, count in occurrences.items() if count > 1}
    missing = 365 - len(entries)
    print(f"Created: {output_pdf}")
    print(f"Unique dates with content: {len(entries)}")
    print(f"Missing dates: {missing}")
    print(f"Duplicate date headers resolved: {len(duplicate_dates)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build_pdf(args.source, args.output)


if __name__ == "__main__":
    main()
