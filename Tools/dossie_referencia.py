#!/usr/bin/env python3
"""Reference implementation of the AI-free study dossier shared by iOS and Android.

Every output is extracted from the given sources, always with its source id. The native apps
must reproduce these results exactly; `Paridade/casos_dossie_v1.json` holds the golden cases.

    python3 Tools/dossie_referencia.py --atualizar   # regenerate expected outputs
    python3 Tools/dossie_referencia.py --check       # verify cases are up to date
"""
import argparse
import datetime
import hashlib
import json
import re
import unicodedata
from pathlib import Path

import qualidade_referencia as quality  # noqa: E402  (same folder)

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "Paridade/estudo_dossie_v1.json"
CASES = ROOT / "Paridade/casos_dossie_v1.json"
DATA = re.compile(r"^\d{2}/\d{2}$")


def nfc(text: str) -> str:
    return unicodedata.normalize("NFC", text)


def is_token_char(char: str) -> bool:
    return unicodedata.category(char)[0] in ("L", "N")


def spans(text: str):
    """Runs of letters and digits (Unicode L* and N*) with their positions."""
    result, start = [], None
    for index, char in enumerate(text):
        if is_token_char(char):
            if start is None:
                start = index
        elif start is not None:
            result.append((start, index))
            start = None
    if start is not None:
        result.append((start, len(text)))
    return result


def fingerprint(pages: list, limit: int) -> str:
    """Identity of a work's content: normalized words of its first pages, independent of layout."""
    tokens = []
    for page in pages:
        tokens.extend(words(clean(page))[2])
        if len(tokens) >= limit:
            break
    return hashlib.sha256(" ".join(tokens[:limit]).encode("utf-8")).hexdigest()


def is_number(word: str) -> bool:
    return all(unicodedata.category(char) == "Nd" for char in word)


def fold(word: str) -> str:
    decomposed = unicodedata.normalize("NFD", word.lower())
    return "".join(char for char in decomposed if unicodedata.category(char) != "Mn")


def words(text: str):
    """Original words, lowercase words (with accents) and normalized words, index-aligned."""
    original = [text[a:b] for a, b in spans(text)]
    lower = [word.lower() for word in original]
    return original, lower, [fold(word) for word in original]


def collapse(text: str) -> list:
    return text.split()


def clean(text: str) -> str:
    """Collapses whitespace and removes OCR repetition: a run of 1 to 20 words repeated at once."""
    items, output, index = collapse(nfc(text)), [], 0
    while index < len(items):
        for size in range(20, 0, -1):
            if index + 2 * size <= len(items) and items[index:index + size] == items[index + size:index + 2 * size]:
                output.extend(items[index:index + size])
                index += 2 * size
                break
        else:
            output.append(items[index])
            index += 1
    return " ".join(output)


def split_heading(text: str) -> tuple:
    """Separates a heading glued by OCR to the start of a page: the leading words with no lowercase
    letter ("49 10ª INSTRUÇÃO ESCADA DE JACÓ VM Degrau é..."). Page numbers at the very start are
    dropped from the heading; a final single capital letter belongs to the body ("... JACÓ A escada").
    Returns (heading, body) of an already cleaned text; heading is "" when there is none."""
    items = text.split(" ") if text else []
    prefix = []
    for word in items:
        # Only the Unicode lowercase category: "ª" and "º" (10ª, Nº) are not lowercase words.
        if any(unicodedata.category(char) == "Ll" for char in word):
            break
        prefix.append(word)
    if not prefix or len(prefix) == len(items) or len(prefix) > 20:
        return "", text
    body = items[len(prefix):]
    while prefix and sum(1 for char in prefix[-1] if unicodedata.category(char)[0] == "L") == 1 \
            and all(unicodedata.category(char)[0] != "N" for char in prefix[-1]):
        body.insert(0, prefix.pop())
    while prefix and all(unicodedata.category(char) == "Nd" for char in prefix[0]):
        prefix.pop(0)
    if not any(sum(1 for char in word if unicodedata.category(char) == "Lu") >= 2 for word in prefix):
        return "", text
    return " ".join(prefix), " ".join(body)


def sentences(text: str) -> list:
    """Cuts after '.', '!', '?' or ';' followed by a space; `text` is already collapsed."""
    result, start = [], 0
    for index, char in enumerate(text):
        if char in ".!?;" and index + 1 < len(text) and text[index + 1] == " ":
            result.append(text[start:index + 1].strip())
            start = index + 2
    result.append(text[start:].strip())
    return [trimmed for trimmed in (trim_noise(sentence) for sentence in result) if trimmed]


def trim_noise(sentence: str) -> str:
    """Drops OCR noise before the first real word: a word starting with a letter that has two or more
    letters, or a single letter followed by a space and another word ("A virtude", "A Fé")."""
    found = spans(sentence)
    for index, (start, end) in enumerate(found):
        word = sentence[start:end]
        if unicodedata.category(word[0])[0] != "L":
            continue
        letters = sum(1 for char in word if unicodedata.category(char)[0] == "L")
        following = found[index + 1][0] if index + 1 < len(found) else None
        single_ok = (letters == 1 and end < len(sentence) and sentence[end] == " " and following == end + 1
                     and unicodedata.category(sentence[following])[0] == "L")
        if letters >= 2 or single_ok:
            return sentence[start:].strip()
    return ""


def term_tokens(term: str, variants: dict) -> list:
    return [{token} | set(variants.get(token, [])) for token in words(nfc(term))[2]]


def occurrences(tokens: list, term: list) -> list:
    if not term:
        return []
    return [index for index in range(len(tokens) - len(term) + 1)
            if all(tokens[index + k] in term[k] for k in range(len(term)))]


def reference(source: dict) -> str:
    data = source.get("data") or ""
    return data if DATA.match(data) else f"p. {source['pagina']}"


def analyze(term: str, sources: list, config: dict, today: str) -> dict:
    limits = config["limites"]
    term_alts = term_tokens(term, config["variantes"])
    term_words = set().union(*term_alts) if term_alts else set()
    # Defining verbs describe the term instead of being associated with it.
    stop = set(config["palavrasVazias"]) | {fold(verb) for verb in config["verbosDefinicao"]}
    defining = set(config["verbosDefinicao"])
    divergence = set(config["marcadoresDivergencia"])

    # Sources whose text repeats an earlier one (the same book imported twice) are ignored.
    distinct, keys, duplicates = [], set(), 0
    for source in sources:
        tokens = words(clean(source.get("texto", "")))[2]
        key = " ".join(tokens[:limits["tokensChaveDuplicata"]]) if len(tokens) >= limits["tokensMinimosDuplicata"] else None
        if key is not None and key in keys:
            duplicates += 1
            continue
        if key is not None:
            keys.add(key)
        distinct.append(source)
    sources = distinct

    # Sentences with OCR noise are not quoted as statements (Paridade/qualidade_texto_v1.json).
    quality_config = quality.load_config()
    noisy = 0
    candidates = []
    occurrence_by_source = []
    starts_with_term = []
    associated, associated_works, associated_forms = {}, {}, {}
    for position, source in enumerate(sources):
        heading, text = split_heading(clean(source.get("texto", "")))
        notes = clean(source.get("rodape", ""))
        _, lower_tokens, tokens = words(text)
        found = occurrences(tokens, term_alts)
        in_heading = len(occurrences(words(heading)[2], term_alts))
        occurrence_by_source.append(len(found) + len(occurrences(words(notes)[2], term_alts)) + in_heading)
        starts_with_term.append(in_heading > 0 or any(index < limits["inicioCapitulo"] for index in found))
        for index in found:
            positions = list(range(max(0, index - limits["janelaAssociacao"]), index)) + \
                list(range(index + len(term_alts), min(len(tokens), index + len(term_alts) + limits["janelaAssociacao"])))
            for at in positions:
                word = tokens[at]
                if len(word) < limits["tamanhoMinimoTermoAssociado"] or word in stop or word in term_words or is_number(word):
                    continue
                associated[word] = associated.get(word, 0) + 1
                associated_works.setdefault(word, set()).add(source["obraId"])
                forms = associated_forms.setdefault(word, {})
                forms[lower_tokens[at]] = forms.get(lower_tokens[at], 0) + 1
        for order, sentence in enumerate(sentences(text)):
            _, lower, normalized = words(sentence)
            if not occurrences(normalized, term_alts):
                continue
            if not limits["tamanhoMinimoFrase"] <= len(sentence) <= limits["tamanhoMaximoFrase"]:
                continue
            if quality.rate_sentence(sentence, quality_config)["nivel"] in ("ruidosa", "ilegivel"):
                noisy += 1
                continue
            has_definition = any(word in defining for word in lower)
            score = (3 if has_definition else 0) + (2 if source["area"] == "dicionariosMaconicos" else 0) + \
                (1 if source["area"] != "bibliotecaMaconica" else 0)
            candidates.append({"score": score, "source": position, "order": order, "texto": sentence,
                               "definicao": has_definition, "divergente": any(word in divergence for word in lower),
                               "chave": " ".join(normalized)[:120]})

    unique, seen = [], set()
    for candidate in sorted(candidates, key=lambda c: (-c["score"], c["source"], c["order"])):
        if candidate["chave"] not in seen:
            seen.add(candidate["chave"])
            unique.append(candidate)

    def pick(pool, limit, excluded=()):
        chosen, works = [], set()
        for candidate in pool:
            work = sources[candidate["source"]]["obraId"]
            if (candidate["source"], candidate["order"]) in excluded or work in works:
                continue
            chosen.append(candidate)
            works.add(work)
            if len(chosen) == limit:
                break
        return chosen

    definitions = pick([c for c in unique if c["definicao"] and sources[c["source"]]["area"] == "dicionariosMaconicos"],
                       limits["definicoes"])
    summary = pick(unique, limits["resumo"], {(c["source"], c["order"]) for c in definitions})
    divergences = pick([c for c in unique if c["divergente"]], limits["divergencias"])

    def excerpt(candidate):
        return {"texto": candidate["texto"], "fonte": sources[candidate["source"]]["id"]}

    by_area = {}
    for source in sources:
        by_area[source["area"]] = by_area.get(source["area"], 0) + 1
    works = {}
    for position, source in enumerate(sources):
        entry = works.setdefault(source["obraId"], {"obraId": source["obraId"], "titulo": source["tituloObra"],
                                                    "ocorrencias": 0, "fontes": 0, "primeira": position})
        entry["ocorrencias"] += occurrence_by_source[position]
        entry["fontes"] += 1
    central = sorted(works.values(), key=lambda w: (-w["ocorrencias"], -w["fontes"], w["obraId"]))[:limits["obrasCentrais"]]
    dedicated, dedicated_works = [], set()
    for position, source in enumerate(sources):
        if starts_with_term[position] and source["obraId"] not in dedicated_works and len(dedicated) < limits["capitulosDedicados"]:
            dedicated.append(source["id"])
            dedicated_works.add(source["obraId"])
    related = sorted(associated.items(), key=lambda item: (-item[1], item[0]))[:limits["termosAssociados"]]
    # Shown in its most frequent written form ("maçom", not "macom"); ties keep the smallest form.
    related_terms = [{"termo": word, "forma": sorted(associated_forms[word].items(), key=lambda f: (-f[1], f[0]))[0][0],
                      "ocorrencias": count, "obras": len(associated_works[word])} for word, count in related]

    questions = []
    for candidate in summary:
        if len(questions) == limits["perguntas"]:
            break
        sentence = candidate["texto"]
        normalized = words(sentence)[2]
        for item in related_terms:
            if item["termo"] in normalized:
                start, end = spans(sentence)[normalized.index(item["termo"])]
                questions.append({"pergunta": sentence[:start] + "_____" + sentence[end:],
                                  "resposta": sentence[start:end], "fonte": sources[candidate["source"]]["id"]})
                break

    def cite(position):
        source = sources[position]
        return f"{source['tituloObra']}, {reference(source)}"

    roadmap = []
    if definitions:
        roadmap.append({"etapa": "Definição", "texto": f"Comece pela definição em {cite(definitions[0]['source'])}."})
    else:
        roadmap.append({"etapa": "Definição", "texto": "Nenhum dicionário do acervo define o termo; comece pela fonte central."})
    if central:
        first = central[0]
        start = next((sources.index(s) for s in sources if s["id"] in dedicated and s["obraId"] == first["obraId"]), first["primeira"])
        roadmap.append({"etapa": "Fonte central", "texto": f"Leia {first['titulo']} ({first['ocorrencias']} ocorrências), a partir de {reference(sources[start])}."})
    breviaries = [position for position, source in enumerate(sources) if source["area"] == "breviarios"][:3]
    if breviaries:
        roadmap.append({"etapa": "Breviários", "texto": "Leia nos breviários: " + "; ".join(cite(p) for p in breviaries) + "."})
    if len(central) > 1:
        roadmap.append({"etapa": "Aprofundamento", "texto": "Aprofunde em: " + "; ".join(w["titulo"] for w in central[1:4]) + "."})
    if len(divergences) > 1:
        roadmap.append({"etapa": "Comparação", "texto": f"Compare {cite(divergences[0]['source'])} com {cite(divergences[1]['source'])}."})
    elif len(central) > 1:
        roadmap.append({"etapa": "Comparação", "texto": f"Compare como {central[0]['titulo']} e {central[1]['titulo']} tratam o tema."})
    roadmap.append({"etapa": "Síntese", "texto": "Escreva uma síntese citando a obra e a página de cada trecho usado."})

    day = datetime.date.fromisoformat(today)
    review = [{"data": (day + datetime.timedelta(days=step["dias"])).isoformat(), "tarefa": step["tarefa"]}
              for step in config["revisao"]]

    return {
        "definicoes": [excerpt(c) for c in definitions],
        "resumo": [excerpt(c) for c in summary],
        "divergencias": [excerpt(c) for c in divergences],
        "metricas": {"fontes": len(sources), "obras": len(works), "ocorrencias": sum(occurrence_by_source), "duplicadas": duplicates,
                     "frasesComRuido": noisy,
                     "porArea": [[area, count] for area, count in sorted(by_area.items(), key=lambda i: (-i[1], i[0]))]},
        "obrasCentrais": [{k: w[k] for k in ("obraId", "titulo", "ocorrencias", "fontes")} for w in central],
        "capitulosDedicados": dedicated,
        "termosAssociados": related_terms,
        "perguntas": questions,
        "roteiro": roadmap,
        "revisao": review,
    }


def display(term: str, result: dict, sources: list, config: dict) -> dict:
    """Lines shown on screen and in exports, identical on both platforms."""
    by_id = {source["id"]: source for source in sources}

    def cite(source_id: str) -> str:
        source = by_id[source_id]
        return f"{source['tituloObra']}, {reference(source)}"

    def excerpts(items):
        return [f"{item['texto']} — {cite(item['fonte'])}" for item in items]

    metrics = result["metricas"]
    areas = ", ".join(f"{config['areas'].get(area, area)} ({count})" for area, count in metrics["porArea"])
    topic = " ".join(collapse(nfc(term)))
    return {
        "definicoes": excerpts(result["definicoes"]),
        "resumo": excerpts(result["resumo"]),
        "divergencias": excerpts(result["divergencias"]),
        "metricas": [f"{metrics['fontes']} fonte(s) em {metrics['obras']} obra(s); {metrics['ocorrencias']} ocorrência(s) do tema."]
                    + ([f"Áreas: {areas}."] if areas else [])
                    + ([f"{metrics['duplicadas']} fonte(s) com texto repetido de outra obra desconsiderada(s)."] if metrics["duplicadas"] else [])
                    + ([f"{metrics['frasesComRuido']} frase(s) com ruído de digitalização desconsiderada(s)."] if metrics["frasesComRuido"] else []),
        "obrasCentrais": [f"{work['titulo']}: {work['ocorrencias']} ocorrência(s) em {work['fontes']} fonte(s)" for work in result["obrasCentrais"]],
        "capitulosDedicados": [cite(source_id) for source_id in result["capitulosDedicados"]],
        "mapa": [f"{topic} → {item['forma']} ({item['ocorrencias']} ocorrência(s), {item['obras']} obra(s))" for item in result["termosAssociados"]],
        "perguntas": [f"{item['pergunta']} (Resposta: {item['resposta']} — {cite(item['fonte'])})" for item in result["perguntas"]],
        "roteiro": [f"{step['etapa']}: {step['texto']}" for step in result["roteiro"]],
        "revisao": [f"{datetime.date.fromisoformat(item['data']).strftime('%d/%m/%Y')}: {item['tarefa']}" for item in result["revisao"]],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--atualizar", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    config = json.loads(CONFIG.read_text())
    cases = json.loads(CASES.read_text())
    changed = []
    for case in cases["casos"]:
        result = analyze(case["termo"], case["fontes"], config, case["hoje"])
        result["exibicao"] = display(case["termo"], result, case["fontes"], config)
        if case.get("esperado") != result:
            changed.append(case["id"])
            case["esperado"] = result
    for case in cases.get("titulos", []):
        result = list(split_heading(clean(case["texto"])))
        if case.get("esperado") != result:
            changed.append(case["id"])
            case["esperado"] = result
    if args.atualizar:
        CASES.write_text(json.dumps(cases, ensure_ascii=False, indent=2) + "\n")
        print("Casos do dossie atualizados:", ", ".join(changed) or "nenhuma mudanca")
    elif changed:
        raise SystemExit("Casos do dossie desatualizados: " + ", ".join(changed))
    else:
        print("Casos do dossie: verificados.")


if __name__ == "__main__":
    main()
