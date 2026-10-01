#!/usr/bin/env python3
"""Checks the store texts of Paridade/PUBLICACAO_LOJAS.md against each field's character limit.

Each field sits between "<!-- campo: NOME | limite: N -->" and "<!-- fim -->".

    python3 Tools/verificar_textos_lojas.py
"""
import re
import sys
from pathlib import Path

TEXTS = Path(__file__).resolve().parents[1] / "Paridade/PUBLICACAO_LOJAS.md"
FIELD = re.compile(r"<!-- campo: (\w+) \| limite: (\d+) -->\n(.*?)\n<!-- fim -->", re.S)


def main() -> None:
    fields = FIELD.findall(TEXTS.read_text(encoding="utf-8"))
    if not fields:
        sys.exit("Nenhum campo encontrado nos textos das lojas.")
    failures = 0
    for name, limit, text in fields:
        size = len(text.strip())
        status = "ok" if 0 < size <= int(limit) else "EXCEDE"
        failures += status != "ok"
        print(f"{name:22} {size:5} / {limit:>4}  {status}")
    if failures:
        sys.exit(f"{failures} campo(s) fora do limite.")
    print("Textos das lojas dentro dos limites.")


if __name__ == "__main__":
    main()
