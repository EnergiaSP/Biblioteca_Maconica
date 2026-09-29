#!/usr/bin/env python3
"""Remove a camada de texto duplicada das páginas do acervo RAG.

Em muitas obras o PDF tinha duas camadas de texto (a original e a do OCR) e a
importação guardou as duas: cada linha aparece duas vezes seguidas, às vezes com
pequenas diferenças ("Ia"/"la", aspas retas/curvas), ou a linha vem repetida em
si mesma ("De 10.000 a.C. De 10.000 a.C."). Isso dobra as ocorrências na busca,
repete trechos no dossiê e no texto enviado à IA.

Regras (nenhum texto é inventado; só uma das duas cópias é descartada):

* par      - duas linhas seguidas iguais ou quase iguais (ver `parecidas`);
* metade   - uma linha formada por duas metades iguais ou quase iguais;
* a página só é alterada quando essas repetições cobrem ao menos metade das
  linhas: repetições isoladas (refrões, tabelas) ficam intactas;
* de cada par fica a versão com menos palavras raras no acervo e menos
  símbolos soltos; empate: a primeira;
* parágrafos e índice FTS são refeitos a partir das linhas mantidas quando o
  texto deles corresponde exatamente a linhas da página; o que não corresponde
  fica como está e é contado no relatório.

Uso:
  remover_texto_duplicado.py --pacotes DIR                 # só relatório
  remover_texto_duplicado.py --pacotes DIR --gravar SAIDA  # cópias corrigidas
"""

from __future__ import annotations

import argparse
import collections
import difflib
import json
import re
import shutil
import sqlite3
import unicodedata
from pathlib import Path

import qualidade_referencia as qualidade  # noqa: E402  (same folder)

RAIZ = Path(__file__).resolve().parents[1]
QUALIDADE = qualidade.load_config()
RELATORIO = RAIZ / "Paridade/texto_duplicado_acervo_v1.json"

COBERTURA_MINIMA = 0.5
SEMELHANCA_MINIMA = 0.9
LINHA_CURTA = 30
FREQUENCIA_COMUM = 3

TROCAS = str.maketrans({
    "“": '"', "”": '"', "„": '"', "«": '"', "»": '"',
    "‘": "'", "’": "'", "´": "'", "`": "'",
    "–": "-", "—": "-", "°": "º",
})
PALAVRA = re.compile(r"[^\W\d_]+")
TIPOGRAFIA = set(".,;:!?-'\"()ªº“”‘’«»—–…")
DIGITOS = re.compile(r"\d+")


def dobrar(palavra: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", palavra.lower()) if unicodedata.category(c) != "Mn")


def normalizar(linha: str) -> str:
    linha = unicodedata.normalize("NFKC", linha).translate(TROCAS)
    return re.sub(r"\s+", " ", linha).strip()


def so_letras_e_digitos(linha: str) -> str:
    return "".join(c for c in linha.lower() if c.isalnum())


def parecidas(a: str, b: str) -> bool:
    """Duas versões da mesma linha: mesmos números e texto igual ou quase igual."""
    if not a or not b:
        return False
    if a == b:
        return True
    if DIGITOS.findall(a) != DIGITOS.findall(b):
        return False
    if max(len(a), len(b)) < LINHA_CURTA:
        # Linhas curtas (títulos, células de tabela) só diferem em pontuação.
        return so_letras_e_digitos(a) == so_letras_e_digitos(b)
    if min(len(a), len(b)) / max(len(a), len(b)) < SEMELHANCA_MINIMA:
        return False
    return difflib.SequenceMatcher(None, a, b, autojunk=False).ratio() >= SEMELHANCA_MINIMA


def metades(linha: str):
    """(primeira, segunda) quando a linha é a mesma frase escrita duas vezes."""
    meio = len(linha) // 2
    for deslocamento in range(0, max(4, len(linha) // 10)):
        for corte in (meio - deslocamento, meio + deslocamento):
            if 0 < corte < len(linha) and linha[corte] == " ":
                a, b = linha[:corte].strip(), linha[corte + 1:].strip()
                if len(a) >= 8 and parecidas(normalizar(a), normalizar(b)):
                    return a, b
    return None


class Vocabulario:
    def __init__(self) -> None:
        self.contagem: collections.Counter = collections.Counter()

    def adicionar(self, texto: str) -> None:
        self.contagem.update(p.lower() for p in PALAVRA.findall(texto))

    def custo(self, linha: str) -> tuple[int, int]:
        """Defeitos da versão: palavras suspeitas pela regra de qualidade ("V ocê", "SenHor", "c0m"),
        ligaduras tipográficas que a busca não encontra ("ﬁm") e palavras raras no acervo; depois,
        sinais soltos. Aspas curvas, travessões e reticências são tipografia da camada original."""
        palavras = PALAVRA.findall(linha)
        raras = sum(1 for p in palavras if self.contagem[p.lower()] < FREQUENCIA_COMUM)
        suspeitas = qualidade.rate(linha, QUALIDADE, 0)["suspeitas"]
        ligaduras = sum(1 for c in linha if unicodedata.normalize("NFKC", c) != c and c not in TIPOGRAFIA)
        sinais = sum(1 for c in linha if not (c.isalnum() or c.isspace() or c in TIPOGRAFIA))
        return raras + suspeitas + ligaduras, sinais


def palavras_dobradas(linha: str) -> tuple[set[str], str | None]:
    """Palavras sem acento e em minúsculas; a última, se a linha termina em hífen, é um pedaço."""
    palavras = [dobrar(p) for p in PALAVRA.findall(linha)]
    pedaco = palavras[-1] if palavras and linha.rstrip().endswith("-") else None
    return set(palavras) - ({pedaco} if pedaco else set()), pedaco


def contem(a: str, b: str) -> bool:
    """Todas as palavras de b estão em a (o pedaço final de b pode ser o início de uma palavra de a)."""
    pa, _ = palavras_dobradas(a)
    pb, pedaco = palavras_dobradas(b)
    return pb <= pa and (pedaco is None or any(p.startswith(pedaco) for p in pa))


def melhor(vocab: Vocabulario, a: str, b: str) -> int:
    """Versão mantida: a que contém as palavras da outra (nada se perde quando as camadas quebram a
    linha em pontos diferentes); se as duas se contêm ou nenhuma contém a outra, a de menor custo."""
    a_contem, b_contem = contem(a, b), contem(b, a)
    if a_contem and not b_contem:
        return 0
    if b_contem and not a_contem:
        return 1
    return 0 if vocab.custo(a) <= vocab.custo(b) else 1


def deduplicar(texto: str, vocab: Vocabulario):
    """Uma decisão por linha original (texto mantido ou None) e estatísticas da página."""
    linhas = texto.split("\n")
    normais = [normalizar(l) for l in linhas]
    cheias = sum(1 for n in normais if n)
    decisao: list[str | None] = list(linhas)
    pares = 0
    linhas_metade = 0
    i = 0
    while i < len(linhas):
        if not normais[i]:
            i += 1
            continue
        j = i + 1
        while j < len(linhas) and not normais[j]:
            j += 1
        if j < len(linhas) and parecidas(normais[i], normais[j]):
            if melhor(vocab, linhas[i].strip(), linhas[j].strip()) == 0:
                decisao[j] = None
            else:
                decisao[i] = None
            pares += 1
            i = j + 1
            continue
        partes = metades(linhas[i].strip())
        if partes:
            decisao[i] = partes[melhor(vocab, *partes)]
            linhas_metade += 1
        i += 1
    cobertura = (2 * pares + linhas_metade) / cheias if cheias else 0.0
    return decisao, {"pares": pares, "metades": linhas_metade, "linhas": cheias, "cobertura": cobertura}


def texto_mantido(decisao: list[str | None]) -> str:
    return "\n".join(l for l in decisao if l is not None)


def juntar(texto: str) -> str:
    return re.sub(r"\s+", " ", texto).strip()


def remapear(linhas: list[str], decisao: list[str | None], trecho: str) -> str | None:
    """Novo texto de um parágrafo que corresponde a linhas inteiras da página original."""
    unido = juntar("\n".join(linhas))
    alvo = juntar(trecho)
    inicio = unido.find(alvo)
    if not alvo or inicio < 0 or unido.find(alvo, inicio + 1) >= 0:
        return None
    fim = inicio + len(alvo)
    # Posição de cada linha no texto unido; o trecho precisa começar e terminar em
    # limites de linha para ser refeito com as linhas mantidas.
    cursor = 0
    dentro: list[int] = []
    for k, linha in enumerate(linhas):
        pedaco = juntar(linha)
        if not pedaco:
            continue
        achado = unido.find(pedaco, cursor)
        if achado < 0:
            return None
        cursor = achado + len(pedaco)
        if achado >= inicio and cursor <= fim:
            if not dentro and achado != inicio:
                return None
            dentro.append(k)
            ultimo_fim = cursor
    if not dentro or ultimo_fim != fim:
        return None
    return juntar(" ".join(decisao[k] for k in dentro if decisao[k] is not None))


def pacotes(diretorio: Path) -> list[Path]:
    return sorted(list(diretorio.glob("*.sqlite")) + list(diretorio.glob("*/*.sqlite")))


def montar_vocabulario(diretorio: Path) -> Vocabulario:
    vocab = Vocabulario()
    for caminho in pacotes(diretorio):
        con = sqlite3.connect(f"file:{caminho}?mode=ro", uri=True)
        for (texto,) in con.execute("SELECT texto_integral FROM rag_paginas"):
            vocab.adicionar(texto or "")
        con.close()
    return vocab


def processar(origem: Path, vocab: Vocabulario, saida: Path | None) -> dict:
    obras: dict = collections.defaultdict(lambda: collections.Counter())
    totais = collections.Counter()
    exemplos: list = []
    for caminho in pacotes(origem):
        destino = None
        if saida:
            destino = saida / caminho.relative_to(origem)
            destino.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(caminho, destino)
        con = sqlite3.connect(destino or f"file:{caminho}?mode=ro", uri=destino is None)
        paginas = {}
        for pid, obra, numero, texto in con.execute(
                "SELECT id, obra_id, numero_original, texto_integral FROM rag_paginas"):
            totais["paginas"] += 1
            decisao, info = deduplicar(texto or "", vocab)
            if info["cobertura"] < COBERTURA_MINIMA or info["pares"] + info["metades"] == 0:
                continue
            linhas = (texto or "").split("\n")
            paginas[(obra, numero)] = (linhas, decisao)
            totais["paginas_corrigidas"] += 1
            totais["linhas_removidas"] += info["pares"] + info["metades"]
            obras[obra]["paginas"] += 1
            obras[obra]["linhas_removidas"] += info["pares"] + info["metades"]
            if len(exemplos) < 60 and (totais["paginas_corrigidas"] % 600 == 1):
                exemplos.append({"obra": obra, "pagina": numero,
                                 "antes": texto[:400], "depois": texto_mantido(decisao)[:400]})
            if destino:
                con.execute("UPDATE rag_paginas SET texto_integral = ? WHERE id = ?", (texto_mantido(decisao), pid))
        novos_paragrafos = {}
        for rid, obra, pagina, texto in con.execute("SELECT id, obra_id, pagina, texto FROM rag_paragrafos"):
            if (obra, pagina) not in paginas:
                continue
            linhas, decisao = paginas[(obra, pagina)]
            novo = remapear(linhas, decisao, texto or "")
            if novo is None:
                totais["paragrafos_sem_correspondencia"] += 1
                continue
            totais["paragrafos_corrigidos"] += 1
            novos_paragrafos[rid] = (texto, novo)
        if destino:
            with con:
                for rid, (_, novo) in novos_paragrafos.items():
                    con.execute("UPDATE rag_paragrafos SET texto = ? WHERE id = ?", (novo, rid))
                colunas = [linha[1] for linha in con.execute("PRAGMA table_info(rag_fts)")]
                if "texto" in colunas and "bloco_id" in colunas:
                    for rowid, bloco, texto in list(con.execute("SELECT rowid, bloco_id, texto FROM rag_fts")):
                        if bloco not in novos_paragrafos:
                            continue
                        antigo, novo = novos_paragrafos[bloco]
                        if texto != antigo:
                            totais["fts_sem_correspondencia"] += 1
                            continue
                        valores = dict(zip(colunas, con.execute(
                            f"SELECT {', '.join(colunas)} FROM rag_fts WHERE rowid = ?", (rowid,)).fetchone()))
                        valores["texto"] = novo
                        con.execute("DELETE FROM rag_fts WHERE rowid = ?", (rowid,))
                        con.execute(
                            f"INSERT INTO rag_fts(rowid, {', '.join(colunas)}) VALUES (?, {', '.join('?' for _ in colunas)})",
                            (rowid, *[valores[c] for c in colunas]))
                        totais["fts_corrigidos"] += 1
            con.execute("VACUUM")
        con.close()
    return {
        "totais": dict(totais),
        "obras": {o: dict(c) for o, c in sorted(obras.items(), key=lambda x: -x[1]["linhas_removidas"])},
        "exemplos": exemplos,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--pacotes", type=Path, required=True, help="pasta RAGPackages de origem")
    parser.add_argument("--gravar", type=Path, metavar="SAIDA", help="grava cópias corrigidas em SAIDA")
    args = parser.parse_args()
    vocab = montar_vocabulario(args.pacotes)
    resultado = processar(args.pacotes, vocab, args.gravar)
    dados = {
        "schemaVersion": 1,
        "descricao": "Camada de texto duplicada removida das páginas do acervo RAG; de cada par fica uma das versões originais.",
        "regras": {"coberturaMinima": COBERTURA_MINIMA, "semelhancaMinima": SEMELHANCA_MINIMA,
                   "linhaCurta": LINHA_CURTA, "frequenciaComum": FREQUENCIA_COMUM},
        **resultado,
    }
    RELATORIO.write_text(json.dumps(dados, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(resultado["totais"], ensure_ascii=False))
    print(f"Relatório: {RELATORIO.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
