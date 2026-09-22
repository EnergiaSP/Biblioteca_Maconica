#!/usr/bin/env python3
"""Compare real exports from the shared native dossier fixture, not source markers."""
import argparse
import json
import re
from pathlib import Path

from pypdf import PdfReader


def compare(folder: Path) -> dict:
    expected = json.loads((Path(__file__).resolve().parents[1] / "Paridade/casos_comuns_v1.json").read_text())["dossier"]
    plans = {platform: json.loads((folder / f"paridade-dossie-plano-{platform}.json").read_text())
             for platform in ("ios", "android")}
    fields = {"roadmap", "questions", "conceptMap", "spacedReview", "crossReferences", "relatedTerms", "limits"}
    errors = []
    if any(set(plan) != fields for plan in plans.values()):
        errors.append("Unexpected or missing study-plan sections")
    for field in sorted(fields):
        if plans["ios"].get(field) != plans["android"].get(field):
            errors.append(f"Different study-plan section: {field}")
    if any(plan.get("spacedReview") != expected["review"] for plan in plans.values()):
        errors.append("Study review differs from the versioned fixture")
    documents = {}
    for platform in plans:
        pdf = PdfReader(folder / f"paridade-dossie-{platform}.pdf")
        text = "\n".join(page.extract_text() or "" for page in pdf.pages)
        # PDF engines may insert extraction spaces between glyph runs or at page breaks.
        normalized = re.sub(r"\s+", "", text)
        cover = re.sub(r"\s+", "", pdf.pages[0].extract_text() or "") if pdf.pages else ""
        for label in ("BibliotecaMaçônica", "DossiêdeEstudo", expected["topic"]):
            if label not in cover:
                errors.append(f"{platform}: missing dossier cover field {label}")
        for index in range(1, expected["sourceCount"] + 1):
            for marker in (f"[F{index}]", f"FIMFONTE{index}FIM", f"NOTAFONTE{index}FIM"):
                if marker not in normalized:
                    errors.append(f"{platform}: missing {marker}")
        if "ANALISEINTEGRALFIM" not in normalized:
            errors.append(f"{platform}: missing optional analysis")
        if not pdf.pages or any(abs(float(p.mediabox.width) - 595) > 1 or
                                abs(float(p.mediabox.height) - 842) > 1 for p in pdf.pages):
            errors.append(f"{platform}: invalid A4 page dimensions")
        documents[platform] = {"pages": len(pdf.pages), "characters": len(text)}
    return {"fixtureSources": expected["sourceCount"], "planSections": len(fields),
            "documents": documents, "errors": errors,
            "scope": "Documentary content and study rules only; visual and full-platform parity require separate validation."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", type=Path)
    args = parser.parse_args()
    result = compare(args.folder)
    output = json.dumps(result, ensure_ascii=False, indent=2)
    (args.folder / "comparacao-dossies.json").write_text(output + "\n")
    print(output)
    raise SystemExit(bool(result["errors"]))
