#!/usr/bin/env python3
"""Synchronize the versioned study definitions used by both native apps."""
import argparse
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / "Paridade/regras_estudo_v1.json"
destinations = [root / "BibliotecaMaconica_Dev/Resources/regras_estudo_v1.json",
                root / "projetos/BreviarioMaconicoAndroid/app/src/main/assets/regras_estudo_v1.json"]
parser = argparse.ArgumentParser()
parser.add_argument("--check", action="store_true")
args = parser.parse_args()
data = json.loads(source.read_text())
assert data["schemaVersion"] == 1
for group in ("colecoes", "trilhas"):
    assert len({item["id"] for item in data[group]}) == len(data[group])
    assert all(item["palavrasChave"] for item in data[group])
for destination in destinations:
    if args.check:
        assert destination.read_bytes() == source.read_bytes(), str(destination)
    else:
        destination.write_bytes(source.read_bytes())
print("Regras de estudo compartilhadas: verificadas." if args.check else "Regras sincronizadas.")
fixtures = root / "Paridade/casos_comuns_v1.json"
assert json.loads(fixtures.read_text())["schemaVersion"] == 1
for folder in (dest.parent for dest in destinations):
    target = folder / fixtures.name
    if args.check:
        assert target.read_bytes() == fixtures.read_bytes(), str(target)
    else:
        target.write_bytes(fixtures.read_bytes())
print("Casos comuns versionados: verificados." if args.check else "Casos comuns sincronizados.")
