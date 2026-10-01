#!/usr/bin/env python3
"""Conservative repair of the "~" left by OCR in place of a letter in the Rizzardo breviary.

A word with "~" is changed only when exactly one letter (accented letters included) turns it into a
word of the reference vocabulary: the two breviaries and the other installed works of Rizzardo da Camino,
counting only words seen at least twice. Ambiguous or unknown words stay as they are and go to the
report; the full repair needs the original PDF (OCR redo).

    python3 Tools/corrigir_til_rizzardo.py --relatorio Paridade/correcao_til_rizzardo_v1.json --gravar
"""
import argparse
import collections
import glob
import json
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGETS = [ROOT / "BibliotecaMaconica_Dev/Resources/breviario_rizzardo.json",
           ROOT / "projetos/BreviarioMaconicoAndroid/app/src/main/assets/breviario_rizzardo.json"]
KENNYO = ROOT / "BibliotecaMaconica_Dev/Resources/breviario.json"
PACKAGES = ROOT / "BibliotecaMaconica_Dev/ImportacaoLivrosPDF_OCR/_relatorios/RAGPackages"
LETTERS = "abcdefghijklmnopqrstuvwxyzáàâãéêíóôõúç"
WORD = re.compile(r"[A-Za-zÀ-ÿ]*~[A-Za-zÀ-ÿ]*")


def vocabulary(texts):
    counts = collections.Counter(w.lower() for t in texts for w in re.findall(r"[A-Za-zÀ-ÿ]{2,}", t))
    return {w for w, n in counts.items() if n >= 2}


def reference_texts(rizzardo: dict):
    texts = [i.get(c) or "" for i in rizzardo["itens"] for c in ("titulo", "texto", "rodape")]
    texts += [i.get(c) or "" for i in json.loads(KENNYO.read_text(encoding="utf-8"))["itens"] for c in ("titulo", "texto")]
    for file in glob.glob(str(PACKAGES / "**/*rizzardo*.sqlite"), recursive=True) + glob.glob(str(PACKAGES / "**/*camino*.sqlite"), recursive=True):
        db = sqlite3.connect(f"file:{file}?mode=ro", uri=True)
        texts += [t for (t,) in db.execute("select texto_integral from rag_paginas")]
    return texts


def repair(word: str, vocab: set):
    """The single fitting word, or None."""
    # At least four letters besides the "~": shorter words give too many readings (as~, roo~).
    if word.count("~") != 1 or len(word) - 1 < 4:
        return None
    options = {word.replace("~", letter) for letter in LETTERS}
    fitting = [o for o in options if o.lower() in vocab]
    if len(fitting) != 1:
        return None
    return fitting[0] if word[0] != "~" or not word[1:2].isupper() else fitting[0].capitalize()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--relatorio", required=True)
    parser.add_argument("--gravar", action="store_true")
    args = parser.parse_args()
    data = json.loads(TARGETS[0].read_text(encoding="utf-8"))
    vocab = vocabulary(reference_texts(data))
    fixed, kept = [], []
    for item in data["itens"]:
        for field in ("titulo", "texto", "rodape"):
            text = item.get(field)
            if not text or "~" not in text:
                continue

            def substitute(match):
                word = match.group(0)
                new = repair(word, vocab)
                (fixed if new else kept).append({"data": item["data"], "campo": field, "palavra": word, "correcao": new})
                return new or word

            item[field] = WORD.sub(substitute, text)
    Path(args.relatorio).write_text(json.dumps({
        "descricao": "Correcao do til deixado pela digitalizacao no Breviario de Rizzardo (Tools/corrigir_til_rizzardo.py). "
                     "Corrigidas: so quando uma unica letra forma palavra conhecida. Mantidas: ambiguas ou desconhecidas, "
                     "a corrigir com o PDF original.",
        "corrigidas": fixed, "mantidas": kept}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Corrigidas: {len(fixed)}; mantidas: {len(kept)}")
    if args.gravar:
        content = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        original = TARGETS[0].read_text(encoding="utf-8")
        # Keeps the file's own formatting when nothing changed.
        if content != original:
            for target in TARGETS:
                target.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
