# Palavras partidas pela importacao e pelo OCR

Periodo: 27/09/2026. Desenvolvimento iOS/Android 1.0.15.

## Problema

Palavras apareciam partidas nos breviarios e no acervo, por tres causas:

| Tipo | Exemplo | Causa |
| --- | --- | --- |
| hifen | "tam- bém", "coraça- o", "na- o" | hifenizacao de fim de linha: o importador junta as linhas com espaco |
| ligadura | "difi cilmente", "signifi cando", "Sefi rot" | a ligadura "fi"/"fl" do PDF virou um corte na palavra |
| espaco | "Maço naria", "constran gimentos", "exis tência" | texto justificado: o extrator inseriu espaco no meio da palavra |

Compostos e enclises partidos na linha ("tornando- se", "Grão- Mestre", "latino- americanos") perdiam a uniao e ficavam com um espaco depois do hifen.

## Solucao

`Tools/corrigir_palavras_quebradas.py` usa o proprio acervo (315 pacotes e os dois breviarios, cerca de 300 mil formas) como dicionario. Nenhuma palavra e inventada: a forma corrigida precisa existir inteira em outros pontos dos textos.

- hifen: junta quando a palavra inteira existe; mantem o hifen quando o composto existe no acervo ("tornou-se", "Grão-Mestre") ou quando e enclise depois de forma verbal ("acumulá-la", "fixarem-se"). Recusa a juncao quando o pedaco final e uma palavra comum muito mais frequente que o resultado ("ter- ao", "com- que": colunas emendadas pelo OCR) e quando mudaria acentos do texto.
- til partido: "coraça- o" e "expressa- o" viram "coração" e "expressão".
- ligadura e espaco: so junta pedacos que, sozinhos, sao raros frente a palavra inteira; a grafia exata prevalece quando e palavra propria.
- enderecos e compostos longos ("história-de- la-masoneria") mantem o hifen.
- quebras encadeadas ("GENERAL- KYCH- PHA") sao resolvidas em passadas sucessivas.
- um caso com fragmentos demais ("ab e rta, fra nca") foi revisado e registrado como correcao manual na ferramenta.

A ferramenta e idempotente: rodada de novo sobre os breviarios corrigidos, encontra 0 pendencias.

## Breviarios (aplicado)

144 correcoes, listadas uma a uma em `Paridade/palavras_quebradas_v1.json` (arquivo, data, campo, original e corrigido):

| Breviario | Correcoes |
| --- | --- |
| Breviario Maconico (Kennyo Ismail) | 87 compostos e enclises com hifen restaurado |
| Breviario de Rizzardo da Camino | 46 por espaco, 5 por ligadura, 4 por hifen/til, 1 composto no titulo ("BOM-II"), 1 manual |

Somente os campos `titulo`, `texto` e `rodape` mudaram; o indice remissivo esta intacto. As copias do Android (`app/src/main/assets`) sao identicas as do iOS.

Casos citados: "pois difi cilmente se pode" (25/02) agora "pois dificilmente se pode"; "signifi cando" (25/11 e 04/12), "constran gimentos" (13/03), "coraça- o" e "expressa- o" (27/03), "na- o" (29/12).

## Acervo RAG (preparado, nao publicado)

A mesma regra encontra 54.214 correcoes nos 315 pacotes: 38.743 por hifen, 13.442 compostos e enclises, 1.246 ligaduras e 783 espacos. Resumo e formas mais frequentes em `Paridade/palavras_quebradas_acervo_v1.json`. Obras com mais correcoes: Zohar (2.842), As Linguagens da Experiencia Religiosa (2.654), Antiguos Ritos Misticos (2.588).

Com `--corrigir-pacotes SAIDA` a ferramenta grava copias corrigidas (paginas, paragrafos, notas e indice FTS). Validacao das copias: 315 pacotes com `integrity_check` e verificacao do FTS aprovados e as mesmas contagens de obras, paginas, paragrafos, notas e blocos FTS.

Os apps so recebem essa correcao quando os pacotes forem republicados no R2 e o catalogo (`sha256`, `tamanhoBytes`) for atualizado nos dois apps. Isso depende de autorizacao explicita e das credenciais (`r2.env`), por isso ficou pendente.

## Evidencias

| Verificacao | Resultado |
| --- | --- |
| iOS unitarios, inclui `testBreviaryReadingsHaveNoWordsSplitByOCR` | 76, 0 falhas |
| Android `DataIntegrityTest` (inclui `breviaryReadingsHaveNoWordsSplitByOcr`), `NavigationFlowTest`, `FullCatalogBenchmarkTest` | 36, 17 e 3, 0 falhas |
| Android unitarios | Aprovados |
| Gate `Tools/verificar_paridade.sh` | Aprovado |

## Como manter

Depois de reimportar um breviario ou gerar pacotes novos, rodar:

```
python3 Tools/corrigir_palavras_quebradas.py --pacotes <pasta RAGPackages> --aplicar-breviarios
python3 Tools/corrigir_palavras_quebradas.py --pacotes <pasta RAGPackages> --corrigir-pacotes <saida>
```

A causa de origem continua nos importadores (`importar_biblioteca_rag_lote.swift` junta linhas com espaco; `importar_breviario_rizzardo.py` recebe o texto justificado do PDF); a ferramenta e o passo de limpeza depois deles.
