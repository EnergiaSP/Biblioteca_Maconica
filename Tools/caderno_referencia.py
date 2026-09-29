#!/usr/bin/env python3
"""Reference implementation of the portable study notebook shared by iOS and Android.

The same file moves between the two apps (export, import, and the sync options). Importing merges
the notebook into the local one without losing anything. The native apps must reproduce these
results exactly; `Paridade/casos_caderno_v1.json` holds the golden cases.

    python3 Tools/caderno_referencia.py --atualizar   # regenerate expected outputs
    python3 Tools/caderno_referencia.py --check       # verify cases are up to date
"""
import argparse
import copy
import datetime
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "Paridade/caderno_v1.json"
CASES = ROOT / "Paridade/casos_caderno_v1.json"


def load_config() -> dict:
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def empty(config: dict) -> dict:
    return {"formato": config["formato"], "versao": config["versao"], "leituras": [], "dossies": [], "cartoes": []}


def study_key(dossier: dict) -> str:
    return "|".join((dossier.get(field) or "").strip().lower() for field in ("tema", "area", "obraId", "autor", "assunto"))


def has_content(reading: dict) -> bool:
    return bool(reading["comentario"].strip() or reading["reflexao"].strip() or reading["favorita"] or reading["lida"]
                or reading["destaques"] or reading["edicao"])


def canonical(notebook: dict, config: dict) -> dict:
    """Stable order and only the known fields, so both apps write the same file."""
    readings = []
    for reading in notebook.get("leituras", []):
        entry = {"obraId": reading["obraId"], "data": reading["data"],
                 "comentario": reading.get("comentario") or "", "reflexao": reading.get("reflexao") or "",
                 "favorita": bool(reading.get("favorita")), "lida": bool(reading.get("lida")),
                 "destaques": sorted(({"id": h["id"], "texto": h["texto"], "criadoEm": int(h["criadoEm"])}
                                      for h in reading.get("destaques", [])), key=lambda h: (h["criadoEm"], h["texto"])),
                 "edicao": ({field: reading["edicao"].get(field) or "" for field in ("titulo", "frase", "texto", "rodape", "autor")}
                            if reading.get("edicao") else None)}
        if has_content(entry):
            readings.append(entry)
    readings.sort(key=lambda r: (r["obraId"], r["data"]))
    dossiers = sorted(({"id": d["id"], "tema": d["tema"], "area": d.get("area"), "obraId": d.get("obraId"),
                        "autor": d.get("autor") or "", "assunto": d.get("assunto") or "", "criadoEm": d["criadoEm"],
                        "revisoesConcluidas": sorted(set(d.get("revisoesConcluidas", [])))}
                       for d in notebook.get("dossies", [])), key=lambda d: (d["criadoEm"], d["tema"], d["id"]))
    cards = sorted(({"cartao": {k: c["cartao"][k] for k in ("id", "tipo", "frente", "verso", "fonte", "alternativas")},
                     "dossieId": c["dossieId"], "tema": c["tema"], "criadoEm": c["criadoEm"],
                     "estado": {k: c["estado"][k] for k in ("caixa", "vencimento", "acertos", "erros")}}
                    for c in notebook.get("cartoes", [])), key=lambda c: c["cartao"]["id"])
    return {"formato": config["formato"], "versao": config["versao"], "leituras": readings, "dossies": dossiers, "cartoes": cards}


def valid(notebook: dict, config: dict) -> bool:
    return notebook.get("formato") == config["formato"] and isinstance(notebook.get("versao"), int) \
        and notebook["versao"] <= config["versao"]


def merge_text(local: str, imported: str, today: str, config: dict) -> str:
    a, b = local.strip(), imported.strip()
    if not b or a == b or b in a:
        return local if a else imported if b else ""
    if not a or a in b:
        return imported
    day = datetime.date.fromisoformat(today).strftime("%d/%m/%Y")
    return f"{a}\n\n{config['marcadorImportacao'].replace('{data}', day)}\n{b}"


def merge(local: dict, imported: dict, today: str, config: dict) -> dict:
    local, imported = canonical(local, config), canonical(imported, config)
    readings = {(r["obraId"], r["data"]): copy.deepcopy(r) for r in local["leituras"]}
    for reading in imported["leituras"]:
        key = (reading["obraId"], reading["data"])
        if key not in readings:
            readings[key] = copy.deepcopy(reading)
            continue
        mine = readings[key]
        mine["comentario"] = merge_text(mine["comentario"], reading["comentario"], today, config)
        mine["reflexao"] = merge_text(mine["reflexao"], reading["reflexao"], today, config)
        mine["favorita"] = mine["favorita"] or reading["favorita"]
        mine["lida"] = mine["lida"] or reading["lida"]
        texts = {h["texto"].strip() for h in mine["destaques"]}
        for highlight in reading["destaques"]:
            if highlight["texto"].strip() not in texts:
                texts.add(highlight["texto"].strip())
                mine["destaques"].append(copy.deepcopy(highlight))
        mine["edicao"] = mine["edicao"] or reading["edicao"]

    dossiers = {study_key(d): copy.deepcopy(d) for d in local["dossies"]}
    remap = {}
    for dossier in imported["dossies"]:
        key = study_key(dossier)
        if key in dossiers:
            mine = dossiers[key]
            remap[dossier["id"]] = mine["id"]
            mine["criadoEm"] = min(mine["criadoEm"], dossier["criadoEm"])
            mine["revisoesConcluidas"] = sorted(set(mine["revisoesConcluidas"]) | set(dossier["revisoesConcluidas"]))
        else:
            dossiers[key] = copy.deepcopy(dossier)

    cards = {c["cartao"]["id"]: copy.deepcopy(c) for c in local["cartoes"]}
    for card in imported["cartoes"]:
        entry = copy.deepcopy(card)
        entry["dossieId"] = remap.get(entry["dossieId"], entry["dossieId"])
        key = entry["cartao"]["id"]
        if key not in cards:
            cards[key] = entry
            continue
        mine = cards[key]
        created = min(mine["criadoEm"], entry["criadoEm"])
        answers = lambda c: c["estado"]["acertos"] + c["estado"]["erros"]
        if answers(entry) > answers(mine):
            cards[key] = entry
        cards[key]["criadoEm"] = created

    return canonical({"leituras": list(readings.values()), "dossies": list(dossiers.values()),
                      "cartoes": list(cards.values())}, config)


def reading(obra, data, **fields):
    base = {"obraId": obra, "data": data, "comentario": "", "reflexao": "", "favorita": False, "lida": False,
            "destaques": [], "edicao": None}
    base.update(fields)
    return base


def build_cases(config: dict) -> dict:
    card = lambda cid, dossier, box, right, wrong, created="2026-10-01": {
        "cartao": {"id": cid, "tipo": "lacuna", "frente": "A Fé representa o primeiro _____ da escada de Jacó.",
                   "verso": "degrau", "fonte": "Breviário, 03/07", "alternativas": ["caridade", "degrau", "esperança"]},
        "dossieId": dossier, "tema": "escada de jacó", "criadoEm": created,
        "estado": {"caixa": box, "vencimento": "2026-10-05", "acertos": right, "erros": wrong}}
    dossier = lambda did, created, reviews: {"id": did, "tema": "Escada de Jacó", "area": None, "obraId": None,
                                               "autor": "", "assunto": "", "criadoEm": created,
                                               "revisoesConcluidas": reviews}
    k = "breviario_seculo_xxi"
    r = "breviario_rizzardo_da_camino"
    local = {"leituras": [
        reading(k, "03/07", comentario="A fé é o primeiro degrau.", favorita=True,
                destaques=[{"id": "a1", "texto": "primeiro degrau", "criadoEm": 1000}]),
        reading(k, "04/07", comentario="Esperança e perseverança.", reflexao="Estudar o painel."),
        reading(r, "12/08", lida=True, edicao={"titulo": "Título local", "texto": "Texto local", "rodape": ""}),
        reading(r, "13/08"),
    ], "dossies": [dossier("local-1", "2026-10-02", [0])], "cartoes": [card("c1", "local-1", 1, 1, 0), card("c2", "local-1", 0, 0, 0)]}
    imported = {"leituras": [
        reading(k, "03/07", comentario="A fé é o primeiro degrau.", lida=True,
                destaques=[{"id": "b1", "texto": "primeiro degrau ", "criadoEm": 900},
                           {"id": "b2", "texto": "sabedoria do espírito", "criadoEm": 1100}]),
        reading(k, "04/07", comentario="Esperança e perseverança no estudo.", reflexao="Rever os símbolos."),
        reading(r, "12/08", favorita=True, edicao={"titulo": "Título importado", "texto": "Texto importado", "rodape": "n"}),
        reading(r, "20/08", comentario="Nova anotação do outro aparelho."),
    ], "dossies": [dossier("outro-9", "2026-09-30", [3]), {**dossier("outro-7", "2026-10-03", []), "tema": "Acácia"}],
       "cartoes": [card("c1", "outro-9", 0, 1, 1, "2026-09-30"), card("c2", "outro-9", 2, 2, 0), card("c3", "outro-7", 0, 0, 0)]}
    cases = [
        ("importar em aparelho vazio", {"leituras": [], "dossies": [], "cartoes": []}, imported),
        ("mesclar com o caderno local", local, imported),
        ("importar o proprio caderno nao muda nada", local, local),
        ("arquivo vazio nao muda nada", local, {"leituras": [], "dossies": [], "cartoes": []}),
    ]
    merges = [{"nome": name, "hoje": "2026-10-10", "local": canonical(a, config), "importado": canonical(b, config),
               "esperado": merge(a, b, "2026-10-10", config)} for name, a, b in cases]
    validity = [{"nome": name, "caderno": value, "valido": valid(value, config)} for name, value in [
        ("caderno da versao 1", {"formato": config["formato"], "versao": 1}),
        ("versao futura", {"formato": config["formato"], "versao": 2}),
        ("outro formato", {"formato": "backup", "versao": 1}),
        ("sem versao", {"formato": config["formato"]}),
    ]]
    return {"schemaVersion": 1,
            "descricao": "Casos de referencia do caderno portatil (Paridade/caderno_v1.json), gerados por "
                         "Tools/caderno_referencia.py --atualizar. iOS e Android devem reproduzir cada mesclagem.",
            "mesclagens": merges, "validacao": validity}


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--atualizar", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = build_cases(load_config())
    current = json.loads(CASES.read_text(encoding="utf-8")) if CASES.exists() else None
    if args.atualizar:
        CASES.write_text(json.dumps(expected, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("Casos do caderno atualizados.")
    elif current != expected:
        raise SystemExit("Casos do caderno desatualizados em relacao a implementacao de referencia.")
    else:
        print("Casos do caderno: verificados.")


if __name__ == "__main__":
    main()
