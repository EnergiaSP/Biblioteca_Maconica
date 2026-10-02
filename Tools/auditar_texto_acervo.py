#!/usr/bin/env python3
"""Deep audit of the text of every work: defects the page quality rule (qualidade_referencia.py) does not see.

Per page it counts:
- interleaved columns: many one-letter "words" ("q u u e m é d um"), two columns read across;
- table read column by column: runs of short lines in capitals (terms) apart from their meanings;
- split words: a piece that is almost never a word alone, followed by the rest, together a common word
  ("mui tas"); or a prefix followed by a piece that is never a word alone ("re movido");
- digits inside words ("pr6pria", "1n1c1aticos");
- repeated lines: the same long line twice or more on the page;
- empty pages between pages with text.
A page with any defect above its threshold is flagged; a work is listed by its share of flagged pages.
The two breviaries embedded in the apps are audited too (each reading is a page).

    python3 Tools/auditar_texto_acervo.py --pacotes DIR --relatorio Paridade/auditoria_texto_acervo_v1.json
"""
import argparse
import collections
import glob
import json
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BREVIARIES = {"breviario_kennyo_ismail": ROOT / "BibliotecaMaconica_Dev/Resources/breviario.json",
              "breviario_rizzardo_da_camino": ROOT / "BibliotecaMaconica_Dev/Resources/breviario_rizzardo.json"}
SINGLE_OK = set("aeoéàôóuy") | set("AEOÉÀÔÓUY")  # one-letter Portuguese/Spanish words
PREFIXES = {"re", "des", "in", "com", "con", "pre", "pro", "sub", "sobre", "inter", "trans", "ex", "dis"}


def words(text: str):
    return re.findall(r"[A-Za-zÀ-ÿ0-9]+", text)


def audit_page(text: str, vocabulary: dict) -> dict:
    tokens = words(text)
    letters = [t for t in tokens if t.isalpha()]
    result = {}
    if len(letters) >= 40:
        singles = sum(1 for t in letters if len(t) == 1 and t not in SINGLE_OK)
        result["colunasIntercaladas"] = round(singles / len(letters), 3)
        joined = 0
        for a, b in zip(letters, letters[1:]):
            la, lb = a.lower(), b.lower()
            whole = vocabulary.get(la + lb, 0) >= 10
            if whole and len(la) >= 2 and len(lb) >= 2 and (
                    (la not in PREFIXES and vocabulary.get(la, 0) < 3) or (la in PREFIXES and vocabulary.get(lb, 0) < 3)):
                joined += 1
        result["palavrasPartidas"] = joined
        result["digitosEmPalavras"] = sum(1 for t in tokens if re.search(r"[A-Za-zÀ-ÿ][0-9]+[A-Za-zÀ-ÿ]", t)
                                          and not re.fullmatch(r"[A-Za-z]{0,3}[0-9]+[A-Za-z]{0,2}", t))
    lines = [l.strip() for l in text.split("\n") if l.strip()]
    caps_run = best = 0
    for line in lines:
        alpha = [c for c in line if c.isalpha()]
        if alpha and len(line) <= 40 and sum(c.isupper() for c in alpha) >= 0.9 * len(alpha):
            caps_run += 1
            best = max(best, caps_run)
        else:
            caps_run = 0
    result["termosEmBloco"] = best
    long_lines = [l for l in lines if len(l) >= 30]
    result["linhasRepetidas"] = sum(n - 1 for n in collections.Counter(long_lines).values() if n > 1)
    return result


THRESHOLDS = {"colunasIntercaladas": 0.12, "palavrasPartidas": 6, "digitosEmPalavras": 3, "termosEmBloco": 6,
              "linhasRepetidas": 3}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pacotes", type=Path, required=True)
    parser.add_argument("--relatorio", type=Path, required=True)
    args = parser.parse_args()
    works = collections.defaultdict(list)
    for path in sorted(glob.glob(str(args.pacotes / "**/*.sqlite"), recursive=True)):
        con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        for work, number, text in con.execute("SELECT obra_id, numero_original, texto_integral FROM rag_paginas ORDER BY obra_id, numero_original"):
            works[work].append((number, text or ""))
        con.close()
    for work, path in BREVIARIES.items():
        for i, item in enumerate(json.loads(path.read_text(encoding="utf-8"))["itens"], start=1):
            works[work].append((item["data"], "\n".join([item["titulo"], item["texto"], item.get("rodape") or ""])))
    counts = collections.Counter(w.lower() for pages in works.values() for _, t in pages for w in words(t) if w.isalpha())
    vocabulary = dict(counts)  # how often each word appears in the whole collection
    report = {}
    for work, pages in works.items():
        flagged, kinds, examples = 0, collections.Counter(), []
        texts = [t for _, t in pages]
        first = next((i for i, t in enumerate(texts) if len(t.strip()) > 50), 0)
        last = max((i for i, t in enumerate(texts) if len(t.strip()) > 50), default=0)
        empty_inside = sum(1 for t in texts[first:last + 1] if len(t.strip()) <= 20)
        for number, text in pages:
            found = [k for k, v in audit_page(text, vocabulary).items() if v >= THRESHOLDS[k]]
            if found:
                flagged += 1
                kinds.update(found)
                if len(examples) < 3:
                    examples.append({"pagina": number, "defeitos": found, "inicio": re.sub(r"\s+", " ", text)[:160]})
        report[work] = {"paginas": len(pages), "sinalizadas": flagged, "vaziasNoMeio": empty_inside,
                        "proporcao": round(flagged / max(1, len(pages)), 3), "defeitos": dict(kinds), "exemplos": examples}
    ordered = dict(sorted(report.items(), key=lambda kv: -kv[1]["proporcao"]))
    args.relatorio.write_text(json.dumps({"descricao": __doc__.strip().split("\n")[0], "limites": THRESHOLDS,
                                          "obras": ordered}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for work, entry in list(ordered.items())[:60]:
        print(f"{entry['proporcao']:.2f} {entry['sinalizadas']:4}/{entry['paginas']:<5} vazias {entry['vaziasNoMeio']:3} {work[:60]:60} {entry['defeitos']}")
    print(f"obras com 10% ou mais das páginas sinalizadas: {sum(1 for e in ordered.values() if e['proporcao'] >= 0.1)}")


if __name__ == "__main__":
    main()
