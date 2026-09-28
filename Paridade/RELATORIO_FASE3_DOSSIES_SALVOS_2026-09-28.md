# Fase 3 (conclusao): dossies salvos, lembretes de revisao e mapa

Periodo: 28/09/2026. Desenvolvimento iOS/Android 1.0.15. Complementa `RELATORIO_FASE3_DOSSIE_SEM_IA_2026-09-27.md`.

## Dossie salvo

- Guarda a pergunta, nao a resposta: tema, area, obra, filtros de autor e assunto, data em que foi salvo e revisoes concluidas. Ao abrir, o dossie e refeito com o acervo instalado (cerca de 1 s), entao nunca mostra texto desatualizado (por exemplo, o texto partido corrigido na v2).
- As datas de revisao contam a partir do dia em que foi salvo, com o calendario comum de `estudo_dossie_v1.json` (0, 1, 3, 7 e 21 dias). Cada revisao tem situacao Feita, Atrasada, Hoje ou Proxima e pode ser marcada como feita.
- Salvar o mesmo estudo de novo (mesmo tema e escopo, sem diferenca de maiusculas ou espacos) substitui o anterior em vez de duplicar.
- Na tela do dossie: botao "Salvar", cartao "Dossies salvos" (abrir e excluir, com a proxima revisao de cada um) e cartao "Revisoes deste dossie".
- Armazenamento no aparelho: iOS `UserDefaults` (`dossiesSalvosV1`), Android `SharedPreferences` (`dossies_salvos`). Mesmos campos nas duas plataformas.
- iOS: mudar tema, escopo ou filtros so invalida o dossie quando a pergunta muda de fato. Antes, reabrir um dossie salvo disparava a invalidacao dos campos e apagaria o resultado.

## Lembretes

- Uma notificacao por revisao pendente, no horario comum `lembreteRevisao` (09:00, novo campo de `estudo_dossie_v1.json`). Revisao concluida nao e agendada. Ao marcar ou desmarcar, os lembretes do dossie sao refeitos; ao excluir, sao cancelados.
- Tocar na notificacao abre o dossie salvo (`breviario://dossie?id=`). Se ele foi excluido, o app avisa "Este dossie salvo foi excluido."
- Android: canal proprio "Revisao de dossies", receptor que ignora revisao concluida ou dossie excluido depois do agendamento, e reagendamento apos reiniciar o aparelho ou atualizar o app.

## Mapa do tema

Desenho com o tema no centro e ate 8 termos associados ao redor, em sentido horario a partir do topo, com o numero de ocorrencias. Tudo vem da analise das fontes (os mesmos termos da secao de termos associados). Tem descricao para leitor de tela.

## Organizacao

- Android: a tela do dossie saiu de `LibrarySearchUi.kt` (limite de 600 linhas) para `DossierScreen.kt`; novos `data/SavedDossiers.kt`, `DossierReminders.kt` e `DossierSavedUi.kt`. A auditoria de paridade passou a conferir `DossierScreen.kt`.
- iOS: novos `Services/DossieSalvo.swift` e `Views/DossieSalvoViews.swift`.

## Evidencias

| Verificacao | Resultado |
| --- | --- |
| Regra de revisao, com o mesmo caso nas duas plataformas (iOS `testSavedDossierReviewsFollowSharedSchedule`, Android `savedDossierReviewsFollowSharedSchedule`) | Aprovados |
| Lembretes: agendamento das revisoes pendentes, horario, link para o dossie (iOS `testSavedDossierRemindersOpenTheDossier`; Android `savedDossierRemindersAreScheduledAndPosted`, com notificacao real e o receptor ignorando revisao concluida) | Aprovados |
| Interface: salvar, marcar revisao, trocar de tema, reabrir, excluir (iOS `testSavedDossierKeepsReviewsReopensAndCanBeDeleted`; Android `savedDossierKeepsReviewsReopensFromNotificationAndCanBeDeleted`, que reabre pela notificacao com o app fechado) | Aprovados |
| iOS unitarios | 79, 0 falhas |
| Android `DataIntegrityTest`, `NavigationFlowTest`, `FullCatalogBenchmarkTest` | 39, 18 e 3, 0 falhas |
| iOS suite de interface completa (32 testes) | 5 falhas, todas auditorias de contraste ja conhecidas (Fase 5); nenhuma regressao |
| Mapa: capturas dos dois apps para o tema "virtude" | Mesmos termos e contagens (homem 217, deus 151, amor 149, poder 123...) |
| Gate `Tools/verificar_paridade.sh` | 0 falhas |

## Observacao de ambiente

O simulador de testes tem duas versoes do app instaladas (a de desenvolvimento e uma anterior), e as duas registram o esquema `breviario://`. Por isso o teste de interface do iOS nao abre o link da notificacao pelo sistema: o roteamento e verificado no teste unitario. A versao anterior nao foi desinstalada.

Os testes de interface do iOS pressupoem o app sem acervo baixado na pasta de instalacao. A validacao da v2 (27-28/09) tinha preenchido essa pasta no simulador, o que mudou busca e colecoes e derrubou 3 testes. Depois de devolver a pasta ao estado anterior (vazia), os 3 passaram.
