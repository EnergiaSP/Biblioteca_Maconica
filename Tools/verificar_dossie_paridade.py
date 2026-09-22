#!/usr/bin/env python3
"""Compare native dossier fixtures without treating layout equality as proven."""
import argparse
import json
import re
import unicodedata
from pathlib import Path

from pypdf import PdfReader


def compact(text):
    return re.sub(r"\s+", "", unicodedata.normalize("NFKC", text))


def inspect(path, source_count):
    pdf = PdfReader(path)
    pages = [compact(page.extract_text() or "") for page in pdf.pages]
    content = "".join(pages)
    errors = []
    for index in range(1, source_count + 1):
        for marker in (f"FIMFONTE{index}FIM", f"NOTAFONTE{index}FIM"):
            if content.count(marker) != 1:
                errors.append(f"{marker}: absent or repeated")
        if f"[F{index}]" not in content:
            errors.append(f"Source F{index}: citation missing")
    for marker in ("Autor:José", "Assunto:Ética", "ANALISEINTEGRALFIM"):
        if marker not in content:
            errors.append(f"{marker}: missing")
    if not pages or f"{source_count}referência" not in pages[0]:
        errors.append("Source count missing from cover")
    for number, (page, text) in enumerate(zip(pdf.pages, pages), 1):
        if abs(float(page.mediabox.width) - 595) > 1 or abs(float(page.mediabox.height) - 842) > 1:
            errors.append(f"Page {number}: unexpected page dimensions")
        if "BibliotecaMaçônica" not in text:
            errors.append(f"Page {number}: library heading missing")
    return {"file": str(path.resolve()), "pages": len(pages), "sources": source_count,
            "errors": errors, "passed": not errors}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ios", type=Path, required=True)
    parser.add_argument("--android", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    count = json.loads((root / "Paridade/casos_comuns_v1.json").read_text())["dossier"]["sourceCount"]
    report = {platform: inspect(path, count) for platform, path in (("ios", args.ios), ("android", args.android))}
    report["scope"] = "Synthetic fixture: every full-source end marker, footnote, citation, filter and header. Visual review is separate; not all export combinations."
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    for platform in ("ios", "android"):
        print(platform, report[platform])
    return int(any(not report[platform]["passed"] for platform in ("ios", "android")))


if __name__ == "__main__":
    raise SystemExit(main())
