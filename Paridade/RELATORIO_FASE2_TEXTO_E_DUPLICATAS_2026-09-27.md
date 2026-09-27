# Fase 2: titulos separados do texto e obras duplicadas

Periodo: 27/09/2026. Desenvolvimento iOS/Android 1.0.15. Commits `dc6389a` e `59427f6`.

## Decisao

A Fase 2 foi feita sem regenerar nem republicar os pacotes RAG. Os dois problemas que ela resolvia (titulo de capitulo colado ao texto pelo OCR e o mesmo livro importado duas vezes) foram tratados na leitura, com regras comuns e testadas contra a referencia em Python. A correcao de palavras partidas (relatorio `RELATORIO_PALAVRAS_QUEBRADAS_2026-09-27.md`) e a primeira mudanca que exige republicar os pacotes.

## O que mudou

- Titulos colados: "10ª INSTRUÇÃO ESCADA DE JACÓ VM Degrau é definido..." passa a ser separado em titulo e texto durante a analise do dossie. Regra em `Tools/dossie_referencia.py` (`split_heading`), reproduzida por iOS `DossieEstudoAnalise.separarTitulo` e Android `DossierAnalysis.splitHeading`; os casos `titulos` de `Paridade/casos_dossie_v1.json` fixam o resultado.
- Duplicatas: `Tools/marcar_duplicatas_catalogo.py` calcula uma impressao digital de cada uma das 321 obras (ate 3000 palavras, chaves de 60 palavras, minimo de 20) e grava `duplicataDe` no catalogo dos dois apps. 13 duplicatas marcadas; lista em `Paridade/duplicatas_catalogo_v1.json`.
- Busca, colecoes tematicas e dossie desconsideram a copia quando o original esta instalado. Se so a copia estiver instalada, ela continua valendo.
- Android: a busca de notas passou a aplicar as exclusoes no codigo, porque o SQLite embutido recusava `MATCH` com muitas condicoes.

## Evidencias

| Verificacao | Resultado |
| --- | --- |
| Casos de referencia do dossie, inclusive `titulos` (iOS e Android) | Aprovados |
| Acervo real: colecoes, busca e dossie comparados entre iOS e Android | 0 diferencas nas tres comparacoes |
| Gate `Tools/verificar_paridade.sh` | Aprovado (apos `59427f6`) |

## Limitacoes conhecidas

- O par "100 Instrucoes de Aprendiz" nao e pego pela impressao digital (edicoes com paginacao diferente); o dossie o descarta em tempo de analise, pelas frases repetidas.
- A separacao de titulo e feita na analise do dossie; a leitura da pagina continua mostrando o texto como foi importado.
