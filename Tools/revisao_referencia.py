#!/usr/bin/env python3
"""Reference implementation of active review (flashcards and quiz) shared by iOS and Android.

Cards come from a dossier: its cloze questions and its definitions, always with the source. The
native apps must reproduce these results exactly; `Paridade/casos_revisao_v1.json` holds the golden
cases, built from the dossier cases of `Paridade/casos_dossie_v1.json`.

    python3 Tools/revisao_referencia.py --atualizar   # regenerate expected outputs
    python3 Tools/revisao_referencia.py --check       # verify cases are up to date
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path

import dossie_referencia as dossier

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "Paridade/revisao_ativa_v1.json"
CASES = ROOT / "Paridade/casos_revisao_v1.json"
DOSSIER_CASES = ROOT / "Paridade/casos_dossie_v1.json"
SEP = "\u001f"


def load_config() -> dict:
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def cite(source: dict) -> str:
    return f"{source['tituloObra']}, {dossier.reference(source)}"


def topic(term: str) -> str:
    return " ".join(dossier.collapse(dossier.nfc(term)))


def card(kind: str, front: str, back: str, source: str) -> dict:
    return {"id": sha(SEP.join([kind, front, back, source]))[:16], "tipo": kind,
            "frente": front, "verso": back, "fonte": source, "alternativas": []}


def options(card_id: str, answer: str, related: list, config: dict) -> list:
    """The answer and the first associated forms that differ from it, in a fixed shuffled order."""
    limits = config["limites"]
    chosen, seen = [answer], [dossier.fold(answer)]
    for form in related:
        if len(chosen) == limits["alternativas"]:
            break
        # "degrau" and "degraus" are the same answer: a form that starts the other is left out.
        folded = dossier.fold(form)
        if not any(folded.startswith(other) or other.startswith(folded) for other in seen):
            seen.append(folded)
            chosen.append(form)
    if len(chosen) < limits["alternativasMinimas"]:
        return []
    return sorted(chosen, key=lambda option: sha(card_id + SEP + option))


def generate(term: str, analysis: dict, sources: list, config: dict) -> list:
    by_id = {source["id"]: source for source in sources}
    labels = config["rotulos"]
    cards = []
    for item in analysis["definicoes"]:
        cards.append(card("definicao", labels["definicao"].replace("{tema}", topic(term)), item["texto"],
                          cite(by_id[item["fonte"]])))
    related = [item["forma"] for item in analysis["termosAssociados"]]
    for item in analysis["perguntas"]:
        entry = card("lacuna", item["pergunta"], item["resposta"], cite(by_id[item["fonte"]]))
        entry["alternativas"] = options(entry["id"], item["resposta"], related, config)
        cards.append(entry)
    return cards


def day(text: str) -> datetime.date:
    return datetime.date.fromisoformat(text)


def new_state(today: str) -> dict:
    return {"caixa": 0, "vencimento": today, "acertos": 0, "erros": 0}


def answer(state: dict, grade: str, today: str, config: dict) -> dict:
    """errei: back to box 0; dificil: same box; acertei: one box up. Due today + interval of the box."""
    last = len(config["intervalos"]) - 1
    box = {"errei": 0, "dificil": state["caixa"], "acertei": min(state["caixa"] + 1, last)}[grade]
    return {"caixa": box,
            "vencimento": (day(today) + datetime.timedelta(days=config["intervalos"][box])).isoformat(),
            "acertos": state["acertos"] + (1 if grade == "acertei" else 0),
            "erros": state["erros"] + (1 if grade == "errei" else 0)}


def session(cards: list, today: str, config: dict) -> list:
    """Ids of the cards due until today: by due date, then creation date, then id; up to the limit."""
    due = [c for c in cards if c["vencimento"] <= today]
    due.sort(key=lambda c: (c["vencimento"], c["criadoEm"], c["id"]))
    return [c["id"] for c in due[:config["limites"]["cartoesPorSessao"]]]


def build_cases(config: dict) -> dict:
    dossier_cases = json.loads(DOSSIER_CASES.read_text(encoding="utf-8"))["casos"]
    generation = []
    for case in dossier_cases:
        analysis = {key: case["esperado"][key] for key in ("definicoes", "perguntas", "termosAssociados")}
        sources = [{key: source[key] for key in ("id", "tituloObra", "pagina") } | ({"data": source["data"]} if source.get("data") else {})
                   for source in case["fontes"]]
        generation.append({"id": case["id"], "tema": case["termo"], "analise": analysis, "fontes": sources,
                           "esperado": generate(case["termo"], analysis, sources, config)})
    schedule = []
    for name, start, steps in [
        ("acertos seguidos ate a ultima caixa", "2026-10-01",
         [("acertei", "2026-10-01"), ("acertei", "2026-10-04"), ("acertei", "2026-10-11"), ("acertei", "2026-10-27"),
          ("acertei", "2026-12-01"), ("acertei", "2027-01-05")]),
        ("erro volta a primeira caixa", "2026-10-01",
         [("acertei", "2026-10-01"), ("acertei", "2026-10-04"), ("errei", "2026-10-11"), ("dificil", "2026-10-12"),
          ("acertei", "2026-10-13")]),
        ("dificil na caixa zero", "2026-10-01", [("dificil", "2026-10-01"), ("dificil", "2026-10-02")]),
        ("virada de ano e ano bissexto", "2027-12-20",
         [("acertei", "2027-12-20"), ("acertei", "2027-12-23"), ("acertei", "2027-12-30"), ("acertei", "2028-01-15")]),
    ]:
        state = new_state(start)
        states = []
        for grade, today in steps:
            state = answer(state, grade, today, config)
            states.append(state)
        schedule.append({"nome": name, "criadoEm": start, "respostas": [list(step) for step in steps], "esperado": states})
    cards = [
        {"id": "c3", "criadoEm": "2026-10-02", "vencimento": "2026-10-05"},
        {"id": "a1", "criadoEm": "2026-10-01", "vencimento": "2026-10-05"},
        {"id": "b2", "criadoEm": "2026-10-01", "vencimento": "2026-10-03"},
        {"id": "d4", "criadoEm": "2026-10-01", "vencimento": "2026-10-06"},
        {"id": "a0", "criadoEm": "2026-10-01", "vencimento": "2026-10-05"},
    ]
    sessions = [{"nome": name, "cartoes": cards, "hoje": today, "esperado": session(cards, today, config)}
                for name, today in [("vencidos ate hoje", "2026-10-05"), ("nenhum vencido", "2026-10-02")]]
    return {"schemaVersion": 1,
            "descricao": "Casos de referencia da revisao ativa (Paridade/revisao_ativa_v1.json), gerados por "
                         "Tools/revisao_referencia.py --atualizar a partir dos casos do dossie. iOS e Android devem "
                         "reproduzir cada resultado.",
            "geracao": generation, "agenda": schedule, "sessoes": sessions}


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
        print("Casos da revisao ativa atualizados.")
    elif current != expected:
        raise SystemExit("Casos da revisao ativa desatualizados em relacao a implementacao de referencia.")
    else:
        print("Casos da revisao ativa: verificados.")


if __name__ == "__main__":
    main()
