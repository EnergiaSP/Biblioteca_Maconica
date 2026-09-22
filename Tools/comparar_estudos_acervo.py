#!/usr/bin/env python3
"""Compare native study selection reports produced from the installed audit corpus."""
import argparse
import json
from pathlib import Path


def compare(folder: Path) -> dict:
    reports = {platform: json.loads((folder / f"medicao-estudos-{platform}.json").read_text())
               for platform in ("ios", "android")}
    rules = json.loads((Path(__file__).resolve().parents[1] / "Paridade/regras_estudo_v1.json").read_text())
    expected = [rule["id"] for rule in rules["colecoes"] + rules["trilhas"]]
    limits = [rules["collectionLimit"]] * len(rules["colecoes"]) + [rules["pathLimit"]] * len(rules["trilhas"])
    errors = []
    for platform, report in reports.items():
        if report.get("ruleIDs") != expected:
            errors.append(f"{platform}: different or missing rule identifiers")
        rows = report.get("selectedPages", [])
        if len(rows) != len(expected):
            errors.append(f"{platform}: incomplete study selection")
        for index, row in enumerate(rows[:len(limits)]):
            if not row or len(row) != len(set(row)) or len(row) > limits[index]:
                errors.append(f"{platform}: empty, repeated or oversized selection at rule {index}")
            if any(not page.rsplit(":", 1)[-1].isdigit() or int(page.rsplit(":", 1)[-1]) <= 0 for page in row):
                errors.append(f"{platform}: invalid page reference at rule {index}")
        if report.get("resultsPerRule") != list(map(len, rows)):
            errors.append(f"{platform}: counts differ from actual selections")
        if report.get("pages") != 69711 or not 0 < report.get("maxBatch", 0) <= 100:
            errors.append(f"{platform}: incomplete audit corpus or unbounded batch")
    if reports["ios"].get("selectedPages") != reports["android"].get("selectedPages"):
        errors.append("Different selected pages or ordering between iOS and Android")
    return {"rules": len(expected), "pages": reports["ios"].get("pages"), "errors": errors,
            "milliseconds": {platform: report["milliseconds"] for platform, report in reports.items()},
            "scope": "Native corpus selection only, not full UI, edited-reading or physical-device parity."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", type=Path)
    folder = parser.parse_args().folder
    result = compare(folder)
    output = json.dumps(result, ensure_ascii=False, indent=2)
    (folder / "comparacao-estudos-acervo.json").write_text(output + "\n")
    print(output)
    raise SystemExit(bool(result["errors"]))
