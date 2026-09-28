#!/usr/bin/env python3
"""Detecta e corrige palavras partidas pela importação/OCR.

Três tipos de quebra são tratados, sempre usando o próprio acervo como
dicionário (nenhuma palavra é inventada: a forma corrigida precisa existir,
inteira, em outros pontos dos textos):

* hifen    - hifenização de fim de linha que virou "tam- bém";
             compostos e ênclises ("tornou- se") mantêm o hífen: "tornou-se";
* ligadura - a ligadura "fi"/"fl" separou a palavra: "signifi cando";
* espaco   - o OCR inseriu um espaço no meio: "constran gimentos".

Uso:
  corrigir_palavras_quebradas.py --pacotes DIR            # só relatório
  corrigir_palavras_quebradas.py --pacotes DIR --aplicar-breviarios
  corrigir_palavras_quebradas.py --pacotes DIR --corrigir-pacotes SAIDA

--corrigir-pacotes grava cópias corrigidas dos pacotes RAG em SAIDA (texto das
páginas, parágrafos, notas e índice FTS); a publicação no R2 é um passo à parte.
"""

from __future__ import annotations

import argparse
import collections
import json
import re
import shutil
import sqlite3
import unicodedata
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
BREVIARIOS = [
    RAIZ / "BibliotecaMaconica_Dev/Resources/breviario.json",
    RAIZ / "BibliotecaMaconica_Dev/Resources/breviario_rizzardo.json",
]
COPIAS_ANDROID = RAIZ / "projetos/BreviarioMaconicoAndroid/app/src/main/assets"
RELATORIO = RAIZ / "Paridade/palavras_quebradas_v1.json"
RELATORIO_ACERVO = RAIZ / "Paridade/palavras_quebradas_acervo_v1.json"
CAMPOS_BREVIARIO = ("titulo", "frase", "texto", "rodape")

# Quebras com fragmentos demais para regra automática, revisadas uma a uma.
MANUAIS = [
    ("breviario_rizzardo.json", "17/11", "texto", "ab e rta, fra nca", "aberta, franca"),
]

PALAVRA = re.compile(r"[^\W\d_]+")
ENCLISES = {
    "se", "lo", "la", "los", "las", "lhe", "lhes", "me", "te", "nos", "vos",
    "no", "na", "nas", "o", "a", "os", "as",
}
MINIMO_JUNCAO = 2
MINIMO_ESPACO = 3
MAXIMO_FRAGMENTO = 2


def dobrar(valor: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", valor.lower())
        if unicodedata.category(c) != "Mn"
    )


def acentos(valor: str) -> set[str]:
    return {
        c for c in unicodedata.normalize("NFD", valor.lower())
        if unicodedata.category(c) == "Mn"
    }


def pares(texto: str):
    """Pares de palavras vizinhas separadas por espaço ou por "-" + espaço."""
    anterior = None
    for atual in PALAVRA.finditer(texto):
        if anterior is not None:
            meio = texto[anterior.end():atual.start()]
            if meio and meio.strip() == "" and "\n\n" not in meio:
                yield anterior, atual, False
            elif meio.startswith("-") and len(meio) > 1 and meio[1:].strip() == "" and "\n\n" not in meio:
                yield anterior, atual, True
        anterior = atual


class Vocabulario:
    def __init__(self) -> None:
        self.palavras: collections.Counter[str] = collections.Counter()
        self.compostos: collections.Counter[str] = collections.Counter()

    def adicionar(self, texto: str) -> None:
        for m in re.finditer(r"[^\W\d_]+(?:-[^\W\d_]+)*", texto):
            partes = m.group(0).lower().split("-")
            for parte in partes:
                self.palavras[parte] += 1
            for i in range(len(partes) - 1):
                self.compostos[partes[i] + "-" + partes[i + 1]] += 1

    def preparar(self) -> None:
        self.melhor: dict[str, str] = {}
        for palavra, n in self.palavras.items():
            chave = dobrar(palavra)
            atual = self.melhor.get(chave)
            if atual is None or n > self.palavras[atual] or (n == self.palavras[atual] and palavra < atual):
                self.melhor[chave] = palavra

    def forma(self, palavra: str) -> tuple[str | None, int]:
        melhor = self.melhor.get(dobrar(palavra))
        return (melhor, self.palavras[melhor]) if melhor else (None, 0)


def til_partido(a: str, b: str, juncao: str) -> bool:
    """OCR que separou o til de "ão": "coraça- o", "expressa- o"."""
    return b == "o" and a.lower().endswith("a") and juncao.endswith("ão")


def enclise(vocab: Vocabulario, a: str, b: str) -> bool:
    """Pronome átono depois de forma verbal: "acumulá- la", "fixarem- se"."""
    base = a.lower()
    if b not in ENCLISES or vocab.palavras[base] < 3:
        return False
    if b in ("lo", "la", "los", "las"):
        return base.endswith(("á", "ê", "ô", "í", "é"))
    return base.endswith(("m", "ndo", "ou", "eu", "iu", "ar", "er", "ir", "ôr"))


def caixa(original: str, forma: str) -> str:
    if original.isupper() and len(original) > 1:
        return forma.upper()
    if original[:1].isupper():
        return forma[:1].upper() + forma[1:]
    return forma


def decidir(vocab: Vocabulario, a: str, b: str, hifen: bool):
    """Retorna (tipo, substituto) ou None quando não há correção segura."""
    if not b[:1].islower():
        # "Grão- Mestre": só volta a ser composto se ele existe no acervo.
        if hifen and vocab.compostos[f"{a}-{b}".lower()]:
            return "hifen-composto", f"{a}-{b}"
        return None
    juncao, n_juncao = vocab.forma(a + b)
    exata = (a + b).lower()
    # A grafia exata vale quando é palavra própria ("franca" x "frança"),
    # não quando é só o erro de OCR sem acento ("coraçao", "nao").
    n_exata = vocab.palavras[exata]
    if n_exata >= MINIMO_JUNCAO and (not hifen or n_exata * 20 >= n_juncao):
        juncao, n_juncao = exata, vocab.palavras[exata]
    if hifen:
        composto = f"{a}-{b}".lower()
        n_composto = vocab.compostos[composto]
        if n_composto and n_composto >= n_juncao:
            return "hifen-composto", f"{a}-{b}"
        if (
            juncao and n_juncao >= MINIMO_JUNCAO and len(a) >= 2
            # "ter- ao" não vira "terao": o pedaço final seria uma palavra
            # comum muito mais frequente que a junção (colunas emendadas).
            and (vocab.palavras[b] <= 100 * n_juncao or til_partido(a, b, juncao))
            and acentos(a + b) <= acentos(juncao)
        ):
            return "hifen", caixa(a, juncao)
        if enclise(vocab, a, b):
            # "exter- no" é "externo", não ênclise.
            if juncao and n_juncao >= MINIMO_JUNCAO and acentos(a + b) <= acentos(juncao):
                return "hifen", caixa(a, juncao)
            return "hifen-composto", f"{a}-{b}"
        return None
    if not juncao or n_juncao < MINIMO_ESPACO:
        return None
    if len(a) < 2 or len(b) < 2:
        return None
    n_a, n_b = vocab.palavras[a.lower()], vocab.palavras[b.lower()]
    ligadura = (a.lower().endswith(("fi", "fl", "ff")) and len(a) >= 3) or (
        # A ligadura também pode abrir o segundo pedaço: "signi ficando".
        b.lower().startswith(("fi", "fl", "ff")) and len(a) >= 3)
    if ligadura:
        # Pedaços de ligadura ("signifi") se repetem no acervo justamente por
        # causa da quebra; basta serem menos comuns que a palavra inteira.
        # Quando a ligadura abre o segundo pedaço, ele pode ser palavra real
        # ("signi ficando"): só o primeiro precisa ser fragmento.
        if n_a >= n_juncao or (n_b >= n_juncao and not b.lower().startswith(("fi", "fl", "ff"))):
            return None
    else:
        # Os dois pedaços precisam ser fragmentos (raros sozinhos); caso
        # contrário "de la" ou "a o" seriam colados indevidamente.
        limite = max(MAXIMO_FRAGMENTO, n_juncao // 50)
        if n_a > limite or n_b > limite:
            return None
    # Sem trocar acentos que o texto trazia ("nè sì" não vira "nesi").
    if not acentos(a + b) <= acentos(juncao):
        return None
    tipo = "ligadura" if ligadura else "espaco"
    return tipo, caixa(a, juncao)


def corrigir(texto: str, vocab: Vocabulario, achados: list | None = None, onde=None) -> str:
    # Repete porque quebras encadeadas ("GENERAL- KYCH- PHA") se sobrepõem.
    for _ in range(4):
        novo = corrigir_uma_vez(texto, vocab, achados, onde)
        if novo == texto:
            break
        texto = novo
    return texto


def corrigir_uma_vez(texto: str, vocab: Vocabulario, achados: list | None, onde) -> str:
    if not texto:
        return texto
    saida = []
    cursor = 0
    ultimo_fim = -1
    for a, b, hifen in list(pares(texto)):
        if a.start() < ultimo_fim:
            continue
        antes = texto[a.start() - 1:a.start()]
        depois = texto[b.end():b.end() + 1]
        if hifen and (antes in "-/" and antes or depois in "-/" and depois):
            # Dentro de endereço ou composto maior ("história-de- la-masoneria").
            decisao = ("hifen-composto", f"{a.group(0)}-{b.group(0)}")
        else:
            decisao = decidir(vocab, a.group(0), b.group(0), hifen)
        if not decisao:
            continue
        tipo, novo = decisao
        saida.append(texto[cursor:a.start()])
        saida.append(novo)
        cursor = ultimo_fim = b.end()
        if achados is not None:
            achados.append({
                "tipo": tipo,
                "original": re.sub(r"\s+", " ", texto[a.start():b.end()]),
                "corrigido": novo,
                **(onde or {}),
            })
    saida.append(texto[cursor:])
    return "".join(saida)


def pacotes(diretorio: Path) -> list[Path]:
    return sorted(list(diretorio.glob("*.sqlite")) + list(diretorio.glob("*/*.sqlite")))


def montar_vocabulario(diretorio: Path) -> Vocabulario:
    vocab = Vocabulario()
    for caminho in pacotes(diretorio):
        con = sqlite3.connect(f"file:{caminho}?mode=ro", uri=True)
        for (texto,) in con.execute("SELECT texto_integral FROM rag_paginas"):
            vocab.adicionar(texto or "")
        con.close()
    for arquivo in BREVIARIOS:
        for item in json.loads(arquivo.read_text(encoding="utf-8"))["itens"]:
            for campo in CAMPOS_BREVIARIO:
                vocab.adicionar(str(item.get(campo) or ""))
    vocab.preparar()
    return vocab


def corrigir_breviarios(vocab: Vocabulario, aplicar: bool) -> list:
    achados: list = []
    for arquivo in BREVIARIOS:
        bruto = arquivo.read_text(encoding="utf-8")
        dados = json.loads(bruto)
        for item in dados["itens"]:
            for campo in CAMPOS_BREVIARIO:
                valor = item.get(campo)
                if isinstance(valor, str):
                    onde = {"arquivo": arquivo.name, "data": item.get("data"), "id": item.get("id"), "campo": campo}
                    for arq, data, cmp, original, novo in MANUAIS:
                        if (arq, data, cmp) == (arquivo.name, item.get("data"), campo) and original in valor:
                            valor = valor.replace(original, novo)
                            achados.append({"tipo": "manual", "original": original, "corrigido": novo, **onde})
                    item[campo] = corrigir(valor, vocab, achados, onde)
        if aplicar:
            indentacao = 2 if bruto.lstrip().startswith("{\n") else None
            texto = json.dumps(dados, ensure_ascii=False, indent=indentacao)
            if bruto.endswith("\n"):
                texto += "\n"
            arquivo.write_text(texto, encoding="utf-8")
            shutil.copyfile(arquivo, COPIAS_ANDROID / arquivo.name)
    return achados


def corrigir_pacotes(origem: Path, vocab: Vocabulario, saida: Path | None) -> list:
    achados: list = []
    for caminho in pacotes(origem):
        destino = None
        if saida:
            destino = saida / caminho.relative_to(origem)
            destino.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(caminho, destino)
        con = sqlite3.connect(destino or f"file:{caminho}?mode=ro", uri=destino is None)
        pacote = caminho.relative_to(origem).as_posix()
        mudancas = []
        for pid, obra, pagina, texto in con.execute("SELECT id, obra_id, numero_original, texto_integral FROM rag_paginas"):
            novo = corrigir(texto or "", vocab, achados, {"pacote": pacote, "obra": obra, "pagina": pagina})
            if novo != texto:
                mudancas.append(("rag_paginas", "texto_integral", pid, novo))
        if destino:
            for tabela, coluna in (("rag_paragrafos", "texto"), ("rag_notas", "texto")):
                for rid, texto in con.execute(f"SELECT id, {coluna} FROM {tabela}"):
                    novo = corrigir(texto or "", vocab)
                    if novo != texto:
                        mudancas.append((tabela, coluna, rid, novo))
            with con:
                for tabela, coluna, rid, novo in mudancas:
                    con.execute(f"UPDATE {tabela} SET {coluna} = ? WHERE id = ?", (novo, rid))
                reindexar_fts(con, vocab)
            con.execute("VACUUM")
        con.close()
    return achados


def reindexar_fts(con: sqlite3.Connection, vocab: Vocabulario) -> None:
    colunas = [linha[1] for linha in con.execute("PRAGMA table_info(rag_fts)")]
    if "texto" not in colunas:
        return
    linhas = list(con.execute("SELECT rowid, texto FROM rag_fts"))
    for rowid, texto in linhas:
        novo = corrigir(texto or "", vocab)
        if novo != texto:
            valores = dict(zip(colunas, con.execute(f"SELECT {', '.join(colunas)} FROM rag_fts WHERE rowid = ?", (rowid,)).fetchone()))
            valores["texto"] = novo
            con.execute("DELETE FROM rag_fts WHERE rowid = ?", (rowid,))
            con.execute(
                f"INSERT INTO rag_fts(rowid, {', '.join(colunas)}) VALUES (?, {', '.join('?' for _ in colunas)})",
                (rowid, *[valores[c] for c in colunas]),
            )


def resumo(achados: list, chave_local: str) -> dict:
    por_tipo = collections.Counter(a["tipo"] for a in achados)
    formas = collections.Counter((a["tipo"], a["original"], a["corrigido"]) for a in achados)
    locais = collections.Counter(a.get(chave_local) for a in achados)
    return {
        "ocorrencias": len(achados),
        "porTipo": dict(sorted(por_tipo.items())),
        "porOrigem": dict(sorted(locais.items(), key=lambda x: -x[1])[:40]),
        "formasMaisFrequentes": [
            {"tipo": t, "original": o, "corrigido": c, "vezes": n}
            for (t, o, c), n in formas.most_common(200)
        ],
        "espacoELigadura": [
            {"tipo": t, "original": o, "corrigido": c, "vezes": n}
            for (t, o, c), n in formas.most_common() if t in ("espaco", "ligadura")
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--pacotes", type=Path, required=True, help="pasta RAGPackages usada como dicionário")
    parser.add_argument("--aplicar-breviarios", action="store_true")
    parser.add_argument("--corrigir-pacotes", type=Path, metavar="SAIDA")
    args = parser.parse_args()

    vocab = montar_vocabulario(args.pacotes)
    breviarios = corrigir_breviarios(vocab, args.aplicar_breviarios)
    acervo = corrigir_pacotes(args.pacotes, vocab, args.corrigir_pacotes)
    descricao = "Palavras partidas na importação/OCR. A forma corrigida sempre existe inteira em outro ponto do acervo."
    if args.aplicar_breviarios:
        # Each run adds its corrections to the history; earlier passes stay recorded.
        anteriores = json.loads(RELATORIO.read_text(encoding="utf-8"))["breviarios"]["correcoes"] if RELATORIO.exists() else []
        passada = max((c.get("passada", 1) for c in anteriores), default=0) + 1
        historico = anteriores + [{**c, "passada": passada} for c in breviarios]
        gravar(RELATORIO, {"schemaVersion": 1, "descricao": descricao, "breviarios": {"correcoes": historico}})
    gravar(RELATORIO_ACERVO, {"schemaVersion": 1, "descricao": descricao, "acervoRAG": resumo(acervo, "obra")})
    print(f"Breviários: {len(breviarios)} correções{' aplicadas' if args.aplicar_breviarios else ' pendentes'}")
    for a in breviarios:
        print(f"  {a['arquivo']} {a['data']} {a['campo']}: {a['original']!r} -> {a['corrigido']!r} ({a['tipo']})")
    print(f"Acervo RAG: {len(acervo)} correções {dict(collections.Counter(a['tipo'] for a in acervo))}")


def gravar(caminho: Path, dados: dict) -> None:
    caminho.write_text(json.dumps(dados, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Relatório: {caminho.relative_to(RAIZ)}")

if __name__ == "__main__":
    main()
