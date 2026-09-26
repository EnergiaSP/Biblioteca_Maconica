# Navegacao de retorno e preservacao de anotacoes

Periodo: 26/09/2026. Desenvolvimento iOS/Android 1.0.15.

## Limites

Rodada dirigida aos cinco problemas criticos de usabilidade encontrados na analise de 26/09/2026 (perda de anotacoes e navegacao). Qualidade das colecoes, trilhas, busca e dossie, fluidez e o gate de paridade ficam para as proximas rodadas. Nenhum upload ou publicacao foi realizado.

## Requisito comum

1. Uma leitura aberta a partir do Dossie, Colecoes, Busca, Indices ou Inicio volta, pelo botao Voltar, para a tela que a abriu, com o estado dessa tela preservado.
2. O botao/gesto Voltar do sistema nunca fecha o app enquanto houver tela anterior dentro dele.
3. Comentario e reflexao digitados e nao salvos sao gravados na leitura correta ao trocar de leitura, voltar, mudar de aba ou (iOS) sair do app.
4. Os campos de comentario, reflexao e marcadores sempre pertencem a leitura exibida, inclusive quando a leitura vem de outra obra.
5. Gestos de arrastar nao levam ao Inicio nem trocam de pagina sem intencao.

## Implementacao

### iOS

- `AppNavigationController` registra a aba de origem da leitura (`readingReturnTab`) e `closeReading()` retorna a ela. Trocar de aba manualmente esquece a origem.
- O botao Voltar e o gesto nativo de borda (reativado por `GestoVoltarPelaBorda`) passam pelo mesmo retorno.
- Removidos os gestos globais de arrastar para a direita (ia ao Inicio) e, na leitura, de arrastar para os lados (ia ao Inicio ou avancava o dia). Eles competiam com a selecao de texto dos marcadores e com a digitacao. Os botoes Dia anterior/Proximo dia permanecem. Na tela cheia, arrastar apenas fecha a tela cheia.
- Correcao de perda de dados: ao abrir uma leitura de outra obra, a obra era recarregada e os campos ficavam vazios, sem nova carga ao terminar; salvar apagava o comentario existente. Os editores agora ficam vinculados a uma leitura (`itemEstadoLeitura`) por `sincronizarEstadoLeitura`, que recarrega apos o fim do carregamento da obra.
- `salvarRascunhosLeitura` grava comentario e reflexao alterados ao trocar de leitura, trocar de aba, trocar de obra e quando o app deixa de estar ativo.
- Os campos de reflexao e comentario ganharam nome acessivel (VoiceOver) e identificadores de teste. O cartao do dossie passou a ser um conteiner acessivel, preservando a identificacao de cada fonte.

### Android

- `AppNavigationController` passou a manter historico de telas; `back()` volta a tela anterior e, sem historico, ao Inicio. Revisitar uma tela ja presente corta o historico em vez de cresce-lo.
- `BackHandler` intercepta o Voltar do sistema; antes, qualquer Voltar fechava o app.
- A barra superior ganhou seta Voltar (o icone Inicio continua nas acoes). As setas das telas de leitura voltam a origem, com rotulo `Voltar`.
- Busca estruturada e Dossie guardam termo, filtros, resultados, status e analise em `LibraryStudySession`, mantida pelo app. Voltar de um resultado nao refaz a consulta nem limpa a obra escolhida.
- A leitura grava comentario e reflexao nao salvos ao sair dela (`onPersistDrafts`).
- O Android nao tinha o problema 4: o estado do leitor ja era indexado pela leitura.

## Testes

| Execucao | Resultado |
| --- | --- |
| iOS unitarios (`BreviarioMaconicoXXITests`, iPhone 17, iOS 27) | 66 executados, 0 falhas (1 a 3 ignorados conforme a execucao). Inclui 2 novos testes de retorno a origem. |
| iOS interface, suite completa (28 casos) | 13 aprovados, 15 reprovados. 11 reprovacoes sao auditorias de acessibilidade (contraste; uma por tempo esgotado) ja pendentes nos relatorios anteriores. |
| iOS interface, comparacao com o codigo original (`dfe9cca`) | `testCollectionsAtLargestDynamicTypeOpenTheCorrectReading`, `testNotificationTestDoesNotInvokeAdjacentCancelAction` e `testSearchReadingAfterDailyReadingAndRepeatedHomeReturns` reprovam tambem sem estas mudancas, nas mesmas linhas (item "Adonhiram" nao alcancavel, aviso de teste de notificacao ausente, resultado "O numero Dois" nao encontrado). Nao sao regressoes, mas impedem que esses testes verifiquem o novo retorno. |
| iOS interface, novos casos | `testReadingOpenedFromDossierReturnsToTheDossier` aprovado: Voltar retorna ao Dossie com as fontes preservadas. `testUnsavedCommentIsKeptWhenChangingReading` aprovado: comentario nao salvo permanece apos Proximo dia e Dia anterior. Dossie (2 casos), leitura diaria e tela cheia reexecutados e aprovados. |
| Android unitarios | Nao executados: este Mac nao tem JDK nem Android SDK. Adicionados 3 testes do historico em `AppNavigationControllerTest`. |
| Android instrumentados | Nao executados pelo mesmo motivo. Rotulos atualizados em `NavigationFlowTest`. |

## Pendencias

- Compilar e rodar os testes Android antes de considerar a paridade desta rodada concluida.
- No Android, rascunhos ainda nao sao gravados se o sistema encerrar o app em segundo plano sem sair da leitura.
- O gate `Tools/verificar_paridade.sh` ja falhava antes desta rodada: a auditoria ainda proibe o Breviario de Rizzardo, adicionado no commit `dfe9cca`.
