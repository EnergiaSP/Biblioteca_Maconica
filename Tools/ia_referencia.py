#!/usr/bin/env python3
"""Reference implementation of the AI-assisted interpretation of a dossier, shared by iOS and Android.

The AI receives only the excerpts shown in the dossier, numbered [F1], [F2]... From its answer only
sentences with a valid citation are kept; a literal quotation must exist in a cited excerpt. The
native apps must reproduce these results exactly; `Paridade/casos_ia_v1.json` holds the golden cases.

    python3 Tools/ia_referencia.py --atualizar   # regenerate expected outputs
    python3 Tools/ia_referencia.py --check       # verify cases are up to date
"""
import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dossie_referencia import clean, fold, nfc, occurrences, reference, spans, term_tokens, words  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "Paridade/ia_assistida_v1.json"
STUDY = ROOT / "Paridade/estudo_dossie_v1.json"
CASES = ROOT / "Paridade/casos_ia_v1.json"
CITATION = re.compile(r"\[F([0-9]+)\]")
BULLET = re.compile(r"^([-*•]|[0-9]+[.)]) ")
QUOTE = re.compile(r"“([^”]*)”|\"([^\"]*)\"")


def excerpt(text: str, term: list, limit: int) -> str:
    """Window of the cleaned text around the first occurrence of the topic, cut at word limits."""
    cleaned = clean(text)
    if len(cleaned) <= limit:
        return cleaned
    found = spans(cleaned)
    folded = [fold(cleaned[a:b]) for a, b in found]
    hits = occurrences(folded, term)
    center = found[hits[0]][0] if hits else 0
    start = max(0, center - limit // 3)
    if start > 0:
        start = next((a for a, _ in found if a >= start), start)
    end = start + limit
    if end >= len(cleaned):
        end = len(cleaned)
    else:
        end = max((b for _, b in found if b <= end and b > start), default=end)
    body = cleaned[start:end].strip()
    return ("… " if start > 0 else "") + body + (" …" if end < len(cleaned) else "")


def shorten(text: str, limit: int) -> str:
    cleaned = clean(text)
    if len(cleaned) <= limit:
        return cleaned
    cut = cleaned.rfind(" ", 0, limit + 1)
    return cleaned[:cut if cut > 0 else limit] + " …"


def source_line(index: int, source: dict, study: dict) -> str:
    area = study["areas"].get(source["area"], source["area"])
    return f"[F{index}] {source['tituloObra']}, {reference(source)} ({area})"


def prompt(term: str, sources: list, official: list, config: dict, study: dict) -> str:
    limits = config["limites"]
    tokens = term_tokens(term, study["variantes"])
    lines = list(config["instrucoes"])
    lines += ["", "Organize a resposta nestes blocos, nesta ordem, cada um com o título em uma linha própria:"]
    lines += [f"{index}. {title}" for index, title in enumerate(config["blocos"], start=1)]
    lines += ["", f"TEMA: {clean(term)}", "", "FONTES OFICIAIS CADASTRADAS (somente referência):"]
    lines += [f"- {o['titulo']} | {o['origem']} | {o['url']} | {o['observacao']}" for o in official] \
        or [config["rotulos"]["semFontesOficiais"]]
    lines += ["", "TRECHOS DO DOSSIÊ:"]
    for index, source in enumerate(sources, start=1):
        lines.append(source_line(index, source, study))
        lines.append(excerpt(source.get("texto", ""), tokens, limits["caracteresTrecho"]))
        if clean(source.get("rodape", "")):
            lines.append("Notas de rodapé: " + shorten(source["rodape"], limits["caracteresRodape"]))
        lines.append("")
    return "\n".join(lines).rstrip("\n")


def normalized(text: str) -> str:
    return " ".join(words(clean(text))[2])


def heading(line: str, config: dict):
    """A line is a heading only when it is one of the requested block titles (with number, # or **)."""
    text = line.lstrip("#").strip().strip("*").strip()
    text = BULLET.sub("", text).rstrip(":").strip().strip("*").strip()
    for title in config["blocos"]:
        if fold(clean(text)) == fold(title):
            return title
    return None


def cut_points(body: str) -> list:
    """Sentence ends: '.', '!' or '?' followed by a space, not after a word of one or two letters
    ("p.", "Sr."); citations right after the end belong to that sentence."""
    points, index = [], 0
    while index < len(body):
        char = body[index]
        if char in ".!?" and index + 1 < len(body) and body[index + 1] == " ":
            word_start = index
            while word_start > 0 and unicodedata.category(body[word_start - 1])[0] == "L":
                word_start -= 1
            letters = index - word_start
            if char != "." or letters == 0 or letters >= 3:
                end = index + 1
                match = re.compile(r"(?: ?\[F[0-9]+\])+\.?").match(body, end)
                if match and (match.end() == len(body) or body[match.end()] == " "):
                    end = match.end()
                points.append(end)
                index = end
                continue
        index += 1
    return points


def sentences(body: str) -> list:
    result, start = [], 0
    for end in cut_points(body):
        result.append(body[start:end].strip())
        start = end
    result.append(body[start:].strip())
    return [sentence for sentence in result if sentence]


def quotes_ok(sentence: str, ids: list, sources: list, config: dict) -> bool:
    cited = [" " + normalized(sources[i - 1].get("texto", "") + " " + sources[i - 1].get("rodape", "")) + " " for i in ids]
    for match in QUOTE.finditer(sentence):
        quoted = match.group(1) if match.group(1) is not None else match.group(2)
        if len(clean(quoted)) < config["limites"]["citacaoLiteralMinima"]:
            continue
        needle = " " + normalized(quoted) + " "
        if not any(needle in text for text in cited):
            return False
    return True


def filter_answer(answer: str, sources: list, config: dict) -> dict:
    sections, current, kept, removed, cited = [], None, 0, 0, set()
    for raw in nfc(answer).replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        line = clean(raw.replace("**", ""))
        if not line:
            continue
        title = heading(line, config)
        if title is not None:
            current = [title, []]
            sections.append(current)
            continue
        bullet = BULLET.match(line)
        prefix = (bullet.group(1) + " ") if bullet else ""
        accepted = []
        for sentence in sentences(line[bullet.end():] if bullet else line):
            ids = [int(value) for value in CITATION.findall(sentence)]
            if ids and all(1 <= i <= len(sources) for i in ids) and quotes_ok(sentence, ids, sources, config):
                accepted.append(sentence)
                cited.update(ids)
            else:
                removed += 1
        if accepted:
            kept += len(accepted)
            if current is None:
                current = [None, []]
                sections.append(current)
            current[1].append(prefix + " ".join(accepted))
    blocks = [((title + "\n") if title else "") + "\n".join(lines) for title, lines in sections if lines]
    return {"texto": "\n\n".join(blocks), "frasesMantidas": kept, "frasesRemovidas": removed, "fontesCitadas": sorted(cited)}


def display(result: dict, sources: list, config: dict, study: dict) -> str:
    """Text shown on screen and in exports; empty when nothing could be kept."""
    labels = config["rotulos"]
    if not result["frasesMantidas"]:
        return ""
    lines = [labels["titulo"], labels["aviso"]]
    if result["frasesRemovidas"]:
        lines.append(labels["removidas"].replace("{n}", str(result["frasesRemovidas"])))
    lines += ["", result["texto"], "", labels["fontesCitadas"] + ":"]
    lines += [source_line(i, sources[i - 1], study) for i in result["fontesCitadas"]]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--atualizar", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    config = json.loads(CONFIG.read_text())
    study = json.loads(STUDY.read_text())
    cases = json.loads(CASES.read_text())
    changed = []
    for case in cases["prompts"]:
        result = prompt(case["termo"], case["fontes"], case.get("fontesOficiais", []), config, study)
        if case.get("esperado") != result:
            changed.append(case["id"])
            case["esperado"] = result
    for case in cases["respostas"]:
        sources = cases["fontes"][case["fontes"]]
        result = filter_answer(case["resposta"], sources, config)
        result["exibicao"] = display(result, sources, config, study)
        if case.get("esperado") != result:
            changed.append(case["id"])
            case["esperado"] = result
    if args.atualizar:
        CASES.write_text(json.dumps(cases, ensure_ascii=False, indent=2) + "\n")
        print("Casos da IA atualizados:", ", ".join(changed) or "nenhuma mudanca")
    elif changed:
        raise SystemExit("Casos da IA desatualizados: " + ", ".join(changed))
    else:
        print("Casos da IA: verificados.")


if __name__ == "__main__":
    main()
