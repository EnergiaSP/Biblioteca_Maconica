# Continuação da auditoria de paridade, 18/09/2026

## Decisão

**Liberação bloqueada. Houve avanço de implementação e testes, mas a equivalência funcional completa ainda não está comprovada.**

Escopo exclusivo: BibliotecaMaconica_Dev e projetos/BreviarioMaconicoAndroid, versão 1.0.15. Nenhuma publicação, alteração de identificador ou modificação da versão preservada 1.0.14 foi realizada. Os ensaios com dados sintéticos ocorreram em simuladores/emulador, sem apagar dados de aparelhos pessoais.

Este documento atualiza as pendências do relatório inicial de 18/09, sem apagar seu histórico de falhas. Não usar o resultado estrutural como autorização para distribuir.

## Implementação realizada

### Busca, índices e estudos

- Regras compartilhadas e versionadas: nove coleções, sete trilhas, palavras-chave, etapas e limites. Uma fonte canônica alimenta as duas plataformas, com verificação de identidade dos arquivos.
- Casos comuns de pesquisa e sobrescrito executados nas duas plataformas: frases entre aspas, ordem, combinação de palavras, acentos, pontuação, limites de palavras e números não relacionados a notas.
- Android agora permite escolher obra na pesquisa, além de área/acervo. Consultas dos pacotes usam ranking FTS e filtros efetivos de obra/área.
- Corrigido no iOS o filtro de obra dentro de um pacote com múltiplas obras. Identidade de resultado por bloco separada da identidade da página de navegação.
- Resultados do breviário integrado não se duplicam com a cópia RAG. Removidos limites arbitrários de vínculos no índice remissivo iOS.
- Índice de páginas por obra com metadados, busca e apresentação incremental. Android não apresenta frequência de palavras como se fosse índice remissivo editorial.
- Mantida a exclusão do breviário Rizzardo nas duas plataformas. Há 315 pacotes físicos auditados, mas 314 pacotes disponíveis segundo essa regra.

### Leitura, exportações e importação

- Android: tela cheia remove a navegação; seleção nativa de trecho permite destacar na leitura diária e nos livros. Controles da leitura de livros passam a caber em faixa horizontal.
- Android: exportação por obra, semana ancorada na data, mês, intervalo inclusivo e seleção alternada. Chamadas de notas convertidas para sobrescrito sem transformar datas e números de outros valores nos casos testados.
- PDF Android: quebra nativa de linhas, justificação, títulos que podem ocupar várias linhas, continuação de páginas, capa ornamental e comentário separado. Renderização permanece fora da interface.
- Comparação visual identificou título do comentário maior no Android: ajustado para os mesmos 13 pontos do iOS. Metadados da capa e rodapé passam a usar cinza escuro. A capa considera comentários legados e usa singular/plural conforme a quantidade de dias, com caso de regressão específico.
- PDF iOS: removido corte fixo de títulos extensos; reservado espaço para o início das notas. Nome do usuário, antes ignorado na capa, passa a ser renderizado.
- Limpeza de 117 importações não utilizadas no módulo Android de exportação. Isso não equivale a afirmar que todo o projeto esteja livre de código obsoleto.
- Android OCR: cópia integral do PDF original, geometria da página em arquivo auxiliar, transação no banco, publicação atômica e limpeza de importações inválidas. Removida classificação automática de rodapé apenas pela posição nos 82% inferiores.
- iOS OCR: arquivos inválidos são rejeitados; reimportação preserva o original e a mídia da versão anterior; limite de resolução evita multiplicação acidental por escala Retina. Falhas na geração de mídia deixam de ser silenciosamente ignoradas.
- Dossiê IA recebe os trechos recuperados, não apenas títulos/referências. Prompts exigem identificação de fontes e tratam documentos como dados, não instruções. Isso ainda não valida factualmente a resposta produzida.

### Retorno da leitura

Uma execução de interface falhou ao voltar da leitura diária para o início. O caminho de retorno programático mantinha a pilha da leitura aberta ao trocar somente a aba. Foi alterado para usar a limpeza centralizada de navegação e só então limpar os dados da tela. A abertura de resultados de busca também usa o fluxo comum de leitura. O teste foi ampliado para três ciclos consecutivos de abrir/voltar. Revalidação registrada abaixo.

## Evidências obtidas

| Verificação | Situação |
|---|---|
| Integridade local do acervo | 315 arquivos; SHA-256 e SQLite quick_check sem falhas; 69.884 páginas e 69.371 parágrafos. Não é auditoria visual de todas as páginas nem prova de precisão de OCR. |
| Regras iOS | 27 testes passaram, incluindo catálogo completo, PDF com título extenso, 80 notas, isolamento por obra, original preservado, fonte sem documento e casos compartilhados. |
| Android unitário | 21 testes passaram na compilação atual. |
| Android instrumentado | 22/22 na última compilação: integridade, navegação, OCR sintético, PDF extenso, capa com comentários legados/singular/plural e medição do catálogo completo. |
| Interface iPhone | Primeira rodada: 7/8; falha de retorno registrada e ajuste aplicado. Revalidação: 8/8, incluindo três ciclos consecutivos de abrir/voltar da leitura. |
| Interface iPad | 8/8 na compilação atual, incluindo retorno da leitura, tela cheia, configurações e busca. |
| Distribuição Android/Wear | Compilação local Release bem-sucedida, sem upload. |
| Distribuição iOS/widget/watchOS | Compilação local Release bem-sucedida, sem assinatura nem upload. Não equivale a teste de integração em relógio físico. |
| PDFs nativos | Amostra atual de 12 páginas em cada sistema, sem falhas na verificação automática de conteúdo. Inspeção visual de capa, início, notas e comentário realizada; imagens preservadas em pdf-visual. |
| Contrato estrutural | Sem falhas; regras e casos compartilhados incluídos expressamente no contrato. Gate funcional continua bloqueado. |

Os logs de tentativas malsucedidas permanecem nas evidências. Uma falha inicial do benchmark Android era a expectativa incorreta de 315 pacotes ativos; o teste foi corrigido para 314, mantendo a exclusão solicitada. Um erro de ordem dos argumentos no novo teste Swift foi corrigido antes da execução aprovada.

Na última comparação visual, os dois PDFs apresentam notas em linhas consecutivas e comentário na página seguinte, sem cortes aparentes nas páginas inspecionadas. Persistem diferenças de fonte nativa, quebras de linha, espaçamento e ornamentos. Igual número de páginas e conteúdo aprovado não significa identidade visual nem validação de todos os tipos de exportação. As compilações Release passaram novamente após a última alteração visual do Android.

## Desempenho medido

Ambiente: iPhone 17/iOS 26.5 simulado e Android API 36 emulado, no mesmo Mac. Não comparar as velocidades como classificação dos sistemas: são ambientes virtuais diferentes e houve aquecimento dos caches.

| Consulta | iOS | Android |
|---|---:|---:|
| maçonaria, primeira consulta da execução | 4.061 ms | 4.260 ms |
| frase grande loja | 1.812 ms | 1.140 ms |
| ética virtude | 611 ms | 578 ms |
| Índice de 2.678 páginas | 67 ms | 708 ms |

Os três casos retornaram respectivamente 120, 120 e 78 ocorrências em cada motor. Contagens iguais não comprovam ordem ou conteúdo idêntico de todos os resultados. O teste Android também verificou continuidade de paginação. O teste iOS usou o serviço do catálogo; não mede todo o tempo de digitação, composição da interface ou mesclagem do repositório.

Os valores Android acima vêm de medicao-acervo-android-final.json, após a última correção visual; outras execuções estão preservadas para evidenciar a variação. Não houve benchmark estatístico com séries de partidas frias nem aprovação de desempenho em aparelhos físicos.

## Pendências para equivalência real

1. Busca: paginação completa nas duas telas, empate/ranking entre bancos separados, matriz comum de resultados exatos e inclusão equivalente de metadados, notas e obras importadas localmente. As telas ainda impõem limites de apresentação; não declarar cobertura ilimitada.
2. Estudos: os catálogos de regras são compartilhados, mas a associação de páginas de livros, o escopo entre obras e os critérios de coleção/trilha ainda precisam usar as mesmas fontes e casos. Definições iguais não garantem membros iguais.
3. Exportação: ampliar comparação visual para múltiplos dias, livros, destaques e dossiês. Nem todos os renderizadores Android usam o novo estilo. Seleção de destaque repetido ainda necessita identidade por intervalo, não somente pelo texto.
4. Importação: corpus comum de PDFs multicoluna, rotacionados, com imagens intercaladas, protegidos, grandes e parcialmente corrompidos. Preservar o PDF original não prova que o texto extraído está completo. Geometria/OCR e apresentação de imagens ainda não são equivalentes em todos os caminhos.
5. Backup: implementar e validar resolução de conflitos/exclusões por registro, reduzir I/O restante na interface e testar restauração real. Android Auto Backup não cobre todos os arquivos locais importados; iCloud atual usa snapshots. Não há sincronização iOS/Android nem recuperação garantida.
6. IA: validação de IDs de citação e suficiência de evidência, avaliações factuais/recusa, modelos reais e erros de quota/chave. Não há certificação de fontes por somente cadastrar uma URL. Embeddings/busca vetorial não foram comprovados pelos testes desta rodada.
7. Desempenho: reduzir abertura repetida de bancos, medir primeira apresentação, memória, consultas concorrentes, cancelamento e leitura longa em aparelhos modestos. Quatro segundos de primeira busca no emulador ainda justificam otimização.
8. Integrações: testes reais de widget com app encerrado, notificações/permissões, iPhone/Watch e Android/Wear pareados, bateria reduzida e reconexão.
9. Acessibilidade: matriz de VoiceOver/TalkBack, fontes ampliadas, rotação, iPad e tablet Android, foco/ordem e dimensões dos controles. Os fluxos automatizados atuais não cobrem integralmente essa matriz.

O iPhone e o Apple Watch do proprietário foram detectados como pareados nesta retomada. Não foram identificados Android/Wear físicos nem contas descartáveis autorizadas para testes de reinstalação e conflitos. Disponibilidade do aparelho não comprova que esteja preparado para testes destrutivos; nenhum dado pessoal foi removido.

## Reprodução

- Validação estrutural: `Tools/verificar_paridade.sh`.
- Bloqueio de liberação: `Tools/verificar_paridade.sh --release`; deve falhar enquanto houver pendências.
- Regras canônicas: `Paridade/regras_estudo_v1.json` e `Paridade/casos_comuns_v1.json`; sincronização por `Tools/sincronizar_regras_estudo.py`.
- Integridade dos pacotes: `Tools/medir_acervo_local.py`.
- PDFs: testes nativos geram a mesma amostra; `Tools/verificar_pdf_paridade.py` confere 45 parágrafos, números/data preservados, notas, comentário em página posterior, nome e papel A4. Requer pypdf. Inspeção visual continua obrigatória.
- Benchmark iOS: copiar o catálogo e RAGPackages para Documents do app no simulador de auditoria; sem o corpus, o teste informa explicitamente que foi ignorado.
- Benchmark Android: copiar RAGPackages para files/RAGPackages do app de teste; executar a instrumentação manualmente para não perder os PDFs ao desinstalar no final da suíte Gradle.
- Evidências: `Paridade/evidencias/2026-09-18`, resultados XCTest em DerivedDataDeepAudit/Logs/Test e DerivedDataDeepAuditUI/Logs/Test, relatórios Android em app/build/reports.
- Última rodada Android: `android-build-visual-final.log`, `android-instrumentacao-visual-final.log`; navegação Apple: `iphone-ui-corrigido.log` e `ipad-ui-corrigido.log`. O log inicial de interface continua disponível para rastrear a falha corrigida.

**Próxima prioridade:** fechar paginação e resultados exatos de busca/estudos e ampliar os testes de importação em casos compartilhados. A restauração, IA e integrações externas continuam exigindo validações adicionais, inclusive aparelhos e contas de teste. Nenhuma pendência acima foi marcada como concluída apenas para permitir a liberação.
