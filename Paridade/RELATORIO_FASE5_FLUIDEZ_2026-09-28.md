# Fase 5: fluidez, mensagens e acessibilidade

Periodo: 28/09/2026. Desenvolvimento iOS/Android 1.0.15. Itens 12 a 17 da analise inicial, mais o contraste das auditorias de acessibilidade do iOS.

## Itens

| Item | Situacao | O que mudou |
| --- | --- | --- |
| 12. Tela principal do iOS com cerca de 120 estados; cada tecla num comentario redesenhava todas as abas | Resolvido | Comentario e reflexao passaram a um objeto `@Observable` (`RascunhoLeitura`) observado so pelos editores e pelos itens "com comentario" do menu de compartilhar. Salvar, rascunhos e compartilhamento leem o valor mais recente direto do objeto. Na leitura continua, atalho "Ir para comentario e reflexao" no topo (os campos ficam depois da obra inteira). |
| 13. Colecoes recalculadas ao abrir a aba | Ja resolvido na Fase 1 | iOS recalcula so se o conteudo mudou; Android usa `StudyContentCache`. |
| 14. Busca relia do disco as obras locais a cada pausa | Resolvido no iOS | `BuscaLocalCache`: cada obra local e indexada uma vez por versao do arquivo (caminho, data e tamanho). Pausas de digitacao e "Carregar mais" nao decodificam o JSON nem reconstroem o indice. A pontuacao continua a mesma (os testes existentes de pontuacao local passam pelo mesmo indice). O Android ja mantem as leituras em memoria (`BreviarioRepository`). |
| 15. Return nos campos de Busca e Dossie | Resolvido nas duas plataformas | iOS: Return nao quebra linha; na Busca fecha o teclado e busca, no Dossie gera o dossie, nos filtros fecha o teclado. Os campos continuam quebrando a linha visualmente em fontes grandes. Android: acao de teclado "buscar" na Busca e no Dossie, "concluir" nos filtros. |
| 16. Mensagens de sucesso em vermelho | Resolvido no iOS | Regra unica `AvisoApp` (progresso, erro, alerta, sucesso), usada pelo aviso global e pela mensagem da tela de leitura, que era sempre vermelha. Duracao proporcional ao texto (sucesso 4 a 8 s, alerta 6 a 10 s, erro 8 a 12 s; antes tudo 2,8 s), progresso fica ate ser substituido, e o VoiceOver anuncia a mensagem. Fundos com contraste de 4,5:1 ou mais para o texto branco. O Android usa `Toast` e texto de status neutros, sem cor por tipo. |
| 17. Busca e Dossie compartilhavam termo, escopo e filtros no iOS; Dossie em dois lugares | Resolvido | O Dossie tem estado e tarefa proprios (como ja era no Android); a Busca nao desliga mais o indicador do Dossie ao digitar; o Dossie nao aparece mais em "Mais", so na aba propria. |

## Acessibilidade: contraste

As 5 auditorias de contraste do iOS reprovavam elementos que, sem excecao, estavam atras da barra de abas flutuante (vidro do iOS 26) ou cortados na borda superior: a auditoria mede o contraste pelo recorte de tela da posicao do elemento, onde o texto nao aparece.

- App: borda de rolagem rigida (`scrollEdgeEffectStyle(.hard)`, iOS 26), fundo opaco atras das barras em telas de muito texto.
- Teste: um elemento reprovado que esta coberto pela barra ou cortado e trazido para a area visivel, e o contraste dele e auditado de novo; reprovar ali e falha real. Nada e ignorado sem essa verificacao.

## Palavras partidas: novas passadas e acervo v3

A captura da tela inicial mostrou "signi ficando" (Rizzardo, 28/09): a ligadura "fi" tambem pode abrir o segundo pedaco. A regra passou a cobrir esse caso. Com o acervo ja corrigido como dicionario, novas passadas encontraram mais 38 quebras reais nos breviarios ("conhe cimentos", "lin guagem", "Bene ficente", "represen tacao"...), ate nao restar nenhuma. Historico em `Paridade/palavras_quebradas_v1.json`: 182 correcoes, com a passada de cada uma.

Acervo RAG v3: mais 455 correcoes sobre a v2 (duas passadas; na terceira restaram 2 ocorrencias e o processo foi encerrado). Base conferida (os 315 pacotes da v2 identicos ao catalogo), 0 problemas de integridade, mesmas contagens de obras, paginas, paragrafos, notas e blocos FTS. Publicada em `rag/v3`; `v1` e `v2` continuam publicadas para as versoes do app que apontam para elas.

## Evidencias

| Verificacao | Resultado |
| --- | --- |
| iOS unitarios (inclui `testAppMessagesHaveTheirKindAndTime`) | 81, 0 falhas |
| Android `DataIntegrityTest`, `NavigationFlowTest` (inclui `keyboardActionBuildsTheDossier`), `FullCatalogBenchmarkTest` | 40, 19 e 3, 0 falhas |
| iOS interface: 5 auditorias de contraste que falhavam | Aprovadas (Colecoes exigiu trazer um item de carrossel horizontal a vista) |
| iOS interface, suite completa (antes da correcao do carrossel) | 31 aprovados, 1 ignorado; as 2 falhas eram as auditorias de contraste corrigidas depois |
| Contraste dos fundos das mensagens com texto branco | progresso 11,3:1; erro 6,8:1; alerta 6,2:1; sucesso 6,6:1 (o laranja anterior tinha 4,4:1) |
| Gate `Tools/verificar_paridade.sh` | 0 falhas |
