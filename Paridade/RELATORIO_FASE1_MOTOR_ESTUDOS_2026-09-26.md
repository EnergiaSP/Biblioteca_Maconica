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

# Fase 1 (parte 2): busca e dossie

## Problemas encontrados

- A busca nos pacotes usava `rag_fts MATCH ?` sem limitar a coluna; o indice tambem guarda o titulo da obra, entao "maconaria" trazia todas as paginas dos livros com a palavra no titulo. Nos breviarios do iOS, titulo, autor, area e assuntos da obra entravam no texto de cada leitura ("filosofia" trazia as 365 leituras de cada breviario). O autor de cada leitura dos breviarios e o autor da obra (365 de 365).
- A ordem misturava bm25 de indices diferentes: cada pacote e um indice separado, e bm25 depende das estatisticas de cada indice (termos presentes em mais da metade dos textos recebem peso quase nulo). Os breviarios recebiam 0 e ficavam sempre depois do acervo.

## Regra comum de busca

- Correspondencia: as mesmas palavras/frases de antes (`consultaFTSSegura`), apenas na coluna `texto`. Breviarios: titulo, frase, texto, notas, data e termos do indice remissivo; sem os dados da obra (ficam no filtro de metadados). O Android passou a considerar a "frase" (19 leituras do Kennyo).
- Relevancia: total de ocorrencias das palavras/frases buscadas no trecho (pacotes: contado no indice com `fts5vocab`; notas e breviarios: `ContadorPalavras`/`KeywordCounter`). `ranking` guarda o negativo da contagem; desempate por obra, pagina e bloco/data.
- Todas as correspondencias sao pontuadas antes da paginacao; o texto e carregado apenas para os resultados exibidos. Pacotes pesquisados em paralelo nas duas plataformas.

## Desempenho da busca (acervo completo, desenvolvimento)

| Busca | iOS antes | iOS agora | Android agora |
| --- | --- | --- | --- |
| maconaria | 4,79 s | 1,66 s | 5,67 s (inclui criar o cache de notas) |
| "grande loja" | 2,05 s | 0,56 s | 0,52 s |
| etica virtude | 0,77 s | 0,51 s | 0,38 s |

## Paridade da busca

Nova ferramenta `Tools/comparar_busca_acervo.py`: os dois testes do acervo gravam os 120 primeiros resultados de quatro buscas na area Biblioteca. Resultado: **0 erros**; mesmos resultados, na mesma ordem (120, 120, 75 e 71 resultados). Colecoes reavaliadas com o codigo final: 0 erros (iOS 0,78 s; Android 2,17 s).

## Testes adicionais

- iOS: `testLibrarySearchMatchesReadingTextNotWorkMetadata` ("filosofia" = 20 leituras e "etica" = 4 no breviario do Kennyo, antes 365) e `testLocalTextsUseTheSameFTSQueryAsPackages`. Suite unitaria: 70 testes, 0 falhas.
- Android: `librarySearchMatchesReadingTextNotWorkMetadata` e `localTextsUseTheSameFtsQueryAsPackages`. `DataIntegrityTest` + `FullCatalogBenchmarkTest` com o acervo no emulador: 35 testes, 0 falhas.
- Correcao durante a rodada: conexoes somente leitura do iOS usam `PRAGMA query_only`, que tambem bloqueava a tabela temporaria de contagem; a protecao e suspensa apenas para cria-la (o arquivo continua aberto com `SQLITE_OPEN_READONLY`).

## Pendente na Fase 1

- Cache das colecoes por versao do acervo, sem recalcular a cada abertura da aba (item 13).
- Reexecutar os testes de interface iOS de colecoes e busca apos a ordenacao unica.
- Investigar os dois testes Android de busca que ja falhavam.

# Fase 1 (parte 3): cache das colecoes e paridade dos breviarios

## Cache (item 13)

- iOS: reabrir a aba Colecoes reaproveita o ultimo resultado enquanto obras ativas, arquivos baixados (nome e tamanho), obra aberta e texto das leituras carregadas nao mudam (`chaveConteudoPremium`). Salvar ou autosalvar uma reflexao continua recalculando.
- Android: `StudyContentCache` mantido pelo app, com a mesma impressao digital; o historico de reflexoes e sempre recalculado (e barato).

## Paridade das colecoes com os breviarios

Novo teste nas duas plataformas grava as leituras escolhidas por regra considerando so os dois breviarios (`estudos-locais-*.json`), comparadas por `comparar_estudos_acervo.py`. A primeira comparacao encontrou 6 regras diferentes. Causas:

1. Android usava os termos do indice remissivo apenas do breviario do Kennyo; passou a usar os de ambos, como o iOS (`localStudySelection`, agora uma funcao testavel usada pela tela).
2. **Defeito do iOS, anterior a esta rodada:** ao carregar um breviario, `vincularIndice` recalculava as datas de cada termo pela pagina impressa. No Rizzardo, as 365 entradas ficavam deslocadas em seis dias ("TOLERANCIA", leitura 07/07, ia para 03/07); no Kennyo, 14 entradas perdiam a data. Tocar num termo do indice remissivo abria a leitura errada ou nenhuma. Agora as datas gravadas no JSON prevalecem quando correspondem a leituras existentes; a pagina so e usada para entradas sem data (importacao de PDF). Testes: `testIntegratedBreviaryIndexKeepsRecordedDates`, `testIndexWithoutRecordedDatesIsLinkedByPrintedPage`.

Depois das correcoes: 0 diferencas.

## Testes Android que ja falhavam

`searchAndHomeRemainAvailableInEveryTheme` e `structuredSearchOpensFromHome` falhavam desde a inclusao do segundo breviario: o cartao "Buscar na biblioteca" ficou abaixo da area visivel e a lista so compoe o que esta visivel. A lista da Home ganhou a marca `home.list` e os testes rolam ate o cartao.

## Estado dos testes

| Execucao | Resultado |
| --- | --- |
| iOS unitarios | 73 executados, 1 ignorado, 0 falhas |
| Android unitarios | 34, 0 falhas |
| Android `DataIntegrityTest` + `NavigationFlowTest` (emulador) | 51 executados; depois da correcao dos dois testes de busca, `NavigationFlowTest` 17 de 17 |
| Paridade: colecoes no acervo, colecoes dos breviarios e busca | 0 diferencas |
| Gate | aprovado |

## Testes de interface iOS (suite completa, final da Fase 1)

29 executados: 24 aprovados, 5 reprovados. Os 5 sao auditorias de contraste de acessibilidade (`testContrastIndependentOfOtherAudits`, `testFullAccessibilityCollections`, `testFullAccessibilityHome`, `testFullAccessibilityHomeAfterScrolling`, `testFullAccessibilitySearch`), pendencia antiga prevista para a Fase 5. Todos os testes funcionais aprovados, inclusive notificacao, busca, colecoes com fonte maxima, dossie e rascunhos.

Ajustes de testes que dependiam da ordem antiga, sem afrouxar a verificacao:
- `testSearchReadingAfterDailyReadingAndRepeatedHomeReturns`: a lista de resultados e preguicosa e ordenada por relevancia; o teste rola ate "O numero Dois" (nos testes de interface o app nao tem o acervo baixado, so os breviarios). Continua exigindo que Voltar retorne a Busca tres vezes.
- `testCollectionsAtLargestDynamicTypeOpenTheCorrectReading`: usa a primeira leitura da colecao Virtudes pela regra comum ("DEGRAU", 11 de abril) no lugar de "Adonhiram", que so entrava pela ordem antiga; continua exigindo a leitura correta e o retorno as Colecoes.
- `testReadingOpenedFromDossierReturnsToTheDossier` falhou uma vez numa execucao em grupo e passou nas tres seguintes (isolado, em grupo e na suite completa); acompanhar.

## Pendente, levado para as proximas fases

- Variantes de termos (Jaco/Jacob) em lista curada comum: passa para a Fase 3, junto do dossie, onde o termo pesquisado e expandido.
- Android: gravar rascunhos se o sistema encerrar o app em segundo plano com a leitura aberta.
- Medicoes em aparelhos fisicos (Fase 6).

