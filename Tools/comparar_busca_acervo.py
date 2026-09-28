#!/usr/bin/env python3
"""Compare the ordered search results recorded by the iOS and Android corpus benchmarks."""
import argparse
import json
from pathlib import Path


def compare(folder: Path) -> dict:
    reports = {platform: json.loads((folder / f"medicao-acervo-{platform}.json").read_text())
               for platform in ("ios", "android")}
    ios, android = (reports[p].get("topResults", {}) for p in ("ios", "android"))
    errors = []
    if not ios or set(ios) != set(android):
        errors.append("Different or missing queries between iOS and Android")
    for query in sorted(set(ios) & set(android)):
        if not ios[query]:
            errors.append(f"{query}: no results")
        if ios[query] != android[query]:
            first = next((i for i, (a, b) in enumerate(zip(ios[query], android[query])) if a != b),
                         min(len(ios[query]), len(android[query])))
            errors.append(f"{query}: results differ from position {first + 1}")
    return {"queries": {q: len(ios.get(q, [])) for q in sorted(ios)}, "errors": errors,
            "scope": "Books area search order only; not UI, notes hydration or physical devices."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", type=Path)
    result = compare(parser.parse_args().folder)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(bool(result["errors"]))
