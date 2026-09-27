#!/usr/bin/env python3
"""Compare the real-corpus dossier recorded by the iOS and Android tests, section by section."""
import argparse
import json
from pathlib import Path


def compare(folder: Path) -> dict:
    ios, android = (json.loads((folder / f"dossie-acervo-{p}.json").read_text()) for p in ("ios", "android"))
    keys = sorted((set(ios) | set(android)) - {"milissegundosAnalise"})
    errors = [f"{key}: iOS and Android differ" for key in keys if ios.get(key) != android.get(key)]
    return {"sections": len(keys), "sources": len(ios.get("fontesIds", [])), "errors": errors,
            "milliseconds": {"ios": ios.get("milissegundosAnalise"), "android": android.get("milissegundosAnalise")}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", type=Path)
    result = compare(parser.parse_args().folder)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(bool(result["errors"]))
