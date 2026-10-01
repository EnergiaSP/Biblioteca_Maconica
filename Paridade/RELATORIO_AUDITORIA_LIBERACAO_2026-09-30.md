# Auditoria de liberação — versão 1.0.16

Data: 2026-09-30. Revisa os dez grupos de pendências abertos em 2026-09-22 (`RELATORIO_FILTROS_ACESSIBILIDADE_2026-09-22.md`) depois das Fases 7 a 14.

Resultado:
- **Seis grupos fechados** com testes automáticos nas duas plataformas.
- **Quatro grupos dependem de aparelhos ou contas do responsável.** Ficam em `functionalAudit.deviceChecks` e aparecem como alerta em `auditar_paridade_profunda.py --release`. Devem ser feitos antes de enviar o build às lojas.

## Fechados

### full_screen_reading_and_highlights
- **iOS:**
  - `testFullscreenReadingCanCloseWithoutLosingNavigation`;
  - `testNativeHighlightSelectionWorksInFullscreen`;
  - `testHighlightSelectionKeepsNativeMenuAndSavesOnlyItsPage`;
  - `testHighlightChangesNotifyOnlyTheirWorkAndPage`.
- **Android:**
  - `fullscreenRemovesNavigationAndCanExit`;
  - `highlightsStayWithTheirOriginalWorkAndPage`.
- **Fase 10:** marcadores e anotações também nas páginas das obras do Acervo no Android; os dois apps levam essas anotações no caderno portátil (casos `casos_caderno_v1.json`).

### search_scopes_and_index_coverage
- Busca no acervo completo por área, obra e página: `installedCorpusSupportsGlobalAreaWorkAndPageQueries`.
- Índice remissivo por escopo:
  - `globalRemissiveIndexFiltersAreaAndReportsEmptyScope`;
  - `globalRemissiveIndexRespectsAreaWorkAndOriginalReferences`.
- Escopo do dossiê: `dossierInvalidatesPreviousSourcesWhenTopicOrScopeChanges` (Android) e equivalentes do iOS.
- Os primeiros resultados de quatro buscas no acervo v4 são comparados resultado a resultado entre iOS e Android: 0 diferenças (Fase 8).
- **Fase 13:** variantes de grafia e singular/plural com casos comuns (`casos_variantes_v1.json`), conferidas no acervo real.

### study_paths_and_thematic_collection_rules
- Regras das coleções e trilhas com casos comuns (`casos_comuns_v1.json`: study e studySelection), reproduzidos pelas duas plataformas.
- **iOS:**
  - `testCollectionsAtLargestDynamicTypeOpenTheCorrectReading`;
  - `testCollectionTextGrowsWithTextSize`.
- **Android:**
  - `collectionsShowDetailsAndExpandWithoutLosingReadings`;
  - `collectionOpensTheMatchingPageOfAnImportedBook`;
  - `localBreviaryCollectionsAreRecordedForParity`.
- **Fases 12 e 14:** trilhas por grau (`casos_trilhas_v1.json`) e áudio em sequência de coleções e trilhas, com teste de interface nos dois apps.

### export_formatting_and_selection
- **iOS:**
  - `testMultiDayPDFKeepsLongIndexEntriesAndEveryReading`;
  - `testLongPDFTitleAndSequentialFootnotesAreNotTruncated`;
  - `testDossierExportsEveryFullSourceNoteAndOptionalAnalysis`.
- **Android:**
  - `exportFixtureKeepsLongTextNotesAndSeparateCommentPages`;
  - `longPDFTitleAndSequentialNotesRemainSearchable`;
  - `dossierExportsEveryFullSourceNoteAndOptionalAnalysis`.
- **Fases 10 e 11:** exportação do caderno (arquivo lido pelos dois apps) e da prancha (texto com referências ABNT, casos `casos_prancha_v1.json`).

### local_pdf_fidelity_and_original_preservation
- PDF corrompido é recusado sem publicar obra parcial: `testCorruptPDFIsRejectedInsteadOfEmptySuccess` e `corruptPDFDoesNotPublishPartialWork`.
- Títulos longos e notas sequenciais preservados: os testes de PDF longo acima.
- O original nunca é modificado: os índices de notas são feitos numa cópia em cache, lida só do original aberto como somente leitura (`NotesSearchIndex`).
- Qualidade do texto avaliada e avisada nas páginas com ruído: casos `casos_qualidade_v1.json` nas duas plataformas (Fase 8).

### accessibility_and_responsive_device_matrix
- **iOS:**
  - auditoria `performAccessibilityAudit` nas telas principais no iPhone e no iPad (Fases 7 a 9);
  - Trilhas por grau e Caderno de estudo (Fase 14);
  - textos com o maior tamanho de letra do sistema.
- **Android:** `AccessibilityAuditTest` (Fase 14) com o Accessibility Test Framework do Google em sete telas. Rótulos, áreas de toque, contraste sobre captura de tela e texto falado repetido; erros e avisos falham o teste.
- **Telas cobertas:** iPhone e iPad (simuladores), telefone Android (emulador).
- **Ainda não verificado:** em aparelhos físicos com leitor de tela ligado. Fica junto da verificação de desempenho nos aparelhos.

## Verificar nos aparelhos antes de enviar

| Grupo | O que fazer | Por que não foi automatizado |
|---|---|---|
| automatic_restore_on_real_devices | Reinstalar o app num iPhone e num Android reais com cópia de segurança e conferir que anotações, dossiês, cartões e progresso voltam. | A restauração do sistema só acontece em aparelho físico com conta. A mesclagem da cópia de segurança tem testes (`testBackupMergesIndependentOfflineEdits` e outros). |
| watch_widget_notifications_end_to_end | Com iPhone + Apple Watch e Android + Wear OS pareados: leitura marcada, cartões de revisão e notas entre celular e relógio, widget e notificações. | Não há relógio pareado nos simuladores desta máquina. Mensagens, widget e notificações têm testes isolados (`testWidgetLoadsBothPermanentBreviariesForTheDay`, `notificationIsActuallyPostedWithReadingAction`, exemplos de `relogio_revisao_v1.json`). |
| grounded_ai_citations_and_retrieval_evaluation | Gerar uma interpretação com uma chave real do Gemini e conferir que cada frase cita um trecho do dossiê. | Precisa da chave do responsável. O filtro de citações tem casos comuns (`casos_ia_v1.json`). |
| performance_full_catalog_real_devices | No moto g84 e num iPhone com o acervo completo: busca de termo comum, primeira montagem das coleções e primeiro dossiê depois de reiniciar. | As medições disponíveis são de emulador (Fase 13): busca de cerca de 2 s; coleções 0,23 s com cache. |

## Situação

- `functionalAudit.status`: verified, sem `openGaps`.
- `auditar_paridade_profunda.py --release`: 0 falhas e 4 alertas (os itens acima).
