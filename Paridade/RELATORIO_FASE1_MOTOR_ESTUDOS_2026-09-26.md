# Fase 1 (parte 1): colecoes e trilhas pontuadas pelo indice

Periodo: 26/09/2026. Desenvolvimento iOS/Android 1.0.15.

## Requisito comum

Colecoes e trilhas consideram todas as paginas do acervo baixado, sem interromper a analise, com a regra de `regras_estudo_v1.json`: palavra inteira, depois numero de palavras-chave distintas e total de ocorrencias; empate por obra e pagina. Os dois apps devem escolher as mesmas paginas na mesma ordem.

## Implementacao

- iOS `Services/BibliotecaEstudoIndice.swift` e Android `data/StudyIndex.kt`, mesmo algoritmo:
  1. `fts5vocab` (instancias) conta cada palavra-chave por bloco do indice, sem ler o texto das paginas.
  2. Expressoes ("grande loja") contadas por posicoes consecutivas no mesmo bloco.
  3. Blocos ligados a obra/pagina uma unica vez pela tabela de conteudo do indice; indices sem obra/pagina (importador de PDF Android e formato legado) usam `bloco_id` -> `rag_paragrafos`, como a busca. Pacote sem `bloco_id` e reportado como falha.
  4. Notas de rodape (fora do indice) contadas em memoria.
  5. Cada pagina visitada uma vez, somando para todas as regras; cada regra guarda so as melhores.
  6. Pacotes pontuados em paralelo, combinados na ordem do catalogo (resultado independe do agendamento das threads).
- As paginas do acervo entram nas colecoes com a pontuacao do indice, sem recontagem pelo texto, garantindo o mesmo resultado nas duas plataformas. Leituras dos breviarios (JSON) continuam pontuadas em memoria pela mesma regra (`ContadorPalavras` / `KeywordCounter`).
- `Tools/comparar_estudos_acervo.py` aceita o motor `fts5vocab` (sem lotes de leitura) e exige o mesmo motor nas duas plataformas.

## Desempenho (acervo de auditoria: 314 pacotes, 69.711 paginas, 16 regras, sem cortes)

| Versao | Ambiente | Tempo |
| --- | --- | --- |
| Anterior (interrompia a analise ao preencher cada colecao) | simulador iOS, desenvolvimento | ~6,9 s |
| Motor provisorio lendo texto (commit `4d9d177`) | simulador iOS, desenvolvimento | 75,9 s |
| Motor pelo indice | simulador iOS, desenvolvimento | 1,4 a 1,6 s |
| Motor pelo indice | simulador iOS, otimizado (`-O`) | 1,1 s |
| Motor pelo indice | emulador Android 36 (arm64, GPU por software), desenvolvimento | 5,9 s |

Medicoes em simulador/emulador; aparelhos fisicos ainda nao medidos (Fase 6).

## Paridade no acervo completo

`comparar_estudos_acervo.py` sobre `medicao-estudos-ios.json` e `medicao-estudos-android.json` (pasta local `Paridade/evidencias/2026-09-26-fase1`, ignorada pelo git): **0 erros**. As 16 regras escolheram as mesmas paginas, na mesma ordem, nas duas plataformas.

## Testes

| Execucao | Resultado |
| --- | --- |
| iOS unitarios | 68 executados, 1 ignorado, 0 falhas. Novos: `testIndexStudyScoringMatchesSharedRule` (motor = regra em memoria, com expressoes, notas, pagina em dois blocos e fronteira de palavra). |
| Android unitarios | 34 executados, 0 falhas. |
| Android `DataIntegrityTest` (emulador) | 31 executados, 1 ignorado, 0 falhas. Novos: `indexStudyScoringMatchesSharedRule` nos dois formatos de indice e `bundledSQLiteSupportsIndexOnlyTermCounts`. `globalRemissiveIndexRespectsAreaWorkAndOriginalReferences` corrigido: supunha um unico breviario e comparava entradas so pelo numero, que se repete entre obras. |
| Android `NavigationFlowTest` (emulador) | 17 executados; 14 aprovados na primeira rodada. `collectionOpensTheMatchingPageOfAnImportedBook` dependia da ordem antiga por obra; o livro de teste passou a tratar do tema e o teste aprovou. `searchAndHomeRemainAvailableInEveryTheme` e `structuredSearchOpensFromHome` reprovam tambem no codigo original (`dfe9cca`): nao sao regressoes. |
| Android `FullCatalogBenchmarkTest` (acervo copiado para o emulador) | Aprovado, 5,9 s. |
| Gate `verificar_paridade.sh` | Aprovado. |

## Pendente na Fase 1

- Busca e dossie: remover os metadados da obra do texto comparado (item 8) e ordenacao unica entre acervo e breviarios (item 9).
- Cache das colecoes por versao do acervo, sem recalcular a cada abertura da aba (item 13).
- Reexecutar os testes de interface iOS de colecoes e busca apos a ordenacao unica.
- Investigar os dois testes Android de busca que ja falhavam.
