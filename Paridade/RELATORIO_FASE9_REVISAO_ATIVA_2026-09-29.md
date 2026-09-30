# Fase 9: revisao ativa (cartoes, quiz e revisao espacada)

Periodo: 29/09/2026. Branch `fase9/revisao-ativa`.

## Principio

Nada e inventado: os cartoes saem do dossie, que ja extrai do acervo as definicoes e as perguntas de lacuna, sempre com a fonte. O cartao guarda a citacao ("Obra, p. N" ou a data da leitura) para o leitor conferir no original.

## Regra comum

`Paridade/revisao_ativa_v1.json`, referencia `Tools/revisao_referencia.py` e casos `Paridade/casos_revisao_v1.json`, gerados a partir dos casos do dossie. Reproduzidos igualmente por iOS (`Services/RevisaoAtiva.swift`) e Android (`data/ActiveReview.kt`).

- Cartoes: definicao ("O que é {tema}?", verso com a frase definidora) e lacuna (a pergunta do dossie com "_____", verso com a resposta). Id: SHA-256 de tipo, frente, verso e fonte (16 hexadecimais), o mesmo nas duas plataformas.
- Quiz (so lacunas): a resposta e ate 3 termos associados do proprio dossie, sem repetir a resposta nem variacoes dela ("degrau" e "degraus" contam como a mesma); ordem fixa pelo SHA-256, a mesma nas duas plataformas. Com menos de 3 alternativas o cartao fica so no modo de resposta aberta.
- Revisao espacada por caixas: cartao novo vence no dia em que foi criado; "Errei" volta a primeira caixa, "Difícil" mantem, "Acertei" sobe uma; vencimento = hoje + 1, 3, 7, 16 ou 35 dias.
- Sessao do dia: cartoes vencidos, pelo vencimento, criacao e id, ate 20.

Casos: geracao sobre o dossie "Escada de Jacó" dos casos do dossie (6 cartoes, inclusive a fonte com ruido de OCR) e sem fontes (nenhum cartao); agenda com acertos ate a ultima caixa, erro, "Difícil" na primeira caixa, virada de ano e ano bissexto; sessoes com ordem e sem cartoes vencidos.

## Nos apps (iOS e Android)

- Os cartoes sao gerados junto com o dossie (onde as fontes estao a mao) e guardados quando o dossie e salvo; a mensagem informa quantos foram criados. Reabrir um dossie salvo acrescenta os que faltam (os existentes mantem o progresso); excluir o dossie remove os cartoes dele.
- Aba Dossie, logo abaixo do formulario (montar o dossie continua sendo a primeira acao): "Revisão ativa", "N cartão(ões) para revisar hoje" e "Revisar agora". No topo, o resumo empurrava "Montar dossiê" para baixo da barra de abas e a auditoria de acessibilidade acusava texto parcialmente coberto.
- Sessao: frente; "Mostrar resposta" mostra o verso e a fonte; "Errei", "Difícil", "Acertei" (lado a lado quando cabem, um abaixo do outro nos tamanhos grandes de texto). Nas lacunas, "Múltipla escolha" mostra as alternativas; a escolha mostra "Correto." ou "A resposta é: ...", a fonte e "Próximo" (acerto conta como "Acertei", erro como "Errei").
- Armazenamento local: iOS `UserDefaults` (`cartoesRevisaoV1`), Android `SharedPreferences` (`cartoes_revisao`), como os dossies salvos. No Android entram no backup automatico; no iOS estao no backup do aparelho, mas ainda nao no backup do app pelo iCloud (`UserDataPersistenceService`), como tambem os dossies salvos: fica para a Fase 10.
- Contrato de paridade: regra e casos como fontes identicas; capacidade `active_review_flashcards_quiz`.

## Evidencias

| Verificacao | Resultado |
| --- | --- |
| Casos de referencia (iOS `testActiveReviewMatchesReferenceCases`, Android `ActiveReviewTest`) | Identicos a referencia |
| Fluxo salvar dossie, revisar e marcar (iOS `testSavedDossierCreatesReviewCardsAndSessionGradesThem`, Android `savedDossierCreatesReviewCardsAndSessionGradesThem`) | Aprovados |
| iOS unitarios | 83, 0 falhas |
| iOS interface (iPhone 17), suite completa | 34 de 35 (1 opcional ignorado): a auditoria do Dossie acusou o resumo no topo; corrigido |
| iOS interface, depois do ajuste: os 6 testes do Dossie (inclusive a auditoria de acessibilidade) | Aprovados |
| Android `NavigationFlowTest`, `DataIntegrityTest`, `ActiveReviewTest`, `TextQualityTest` | 21, 40, 1 e 1, 0 falhas |
| Gate `Tools/verificar_paridade.sh` | 0 falhas |

## Limites conhecidos

- Os cartoes nao sao sincronizados entre aparelhos (Fase 10, que depende da decisao sobre sincronizacao).
- Nao ha lembrete proprio de cartoes vencidos; os lembretes de revisao dos dossies salvos continuam.
- Os cartoes de lacuna dependem das perguntas que o dossie encontra; temas com poucas fontes geram poucos cartoes.
