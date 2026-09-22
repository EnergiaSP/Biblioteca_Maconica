# Busca, estudos, IA e importacao: continuacao de 18/09/2026

## Decisao

Liberacao bloqueada. Esta rodada amplia a implementacao e as evidencias; nao declara equivalencia funcional completa. Versao de desenvolvimento 1.0.15, sem publicacao e sem alterar a copia preservada 1.0.14.

## Correcoes

- Busca nas duas plataformas com paginas de 50 ocorrencias, deteccao de pagina seguinte e cancelamento de consulta substituida. Identidade por obra/bloco, preservando texto igual em posicoes distintas. Ordenacao deterministica para empates.
- iOS: exclusao das edicoes locais antes do limite SQL, filtro efetivo por obra e seletor na busca. Trabalho de leitura e mesclagem fora da interface. Android: debounce, consulta cancelavel entre pacotes e IDs estaveis dos blocos.
- Inspecao do estado iOS encontrou indicadores de busca/dossie que podiam permanecer ativos ao substituir a operacao. O iniciador da nova consulta agora limpa os indicadores da operacao cancelada.
- Estudos: casos compartilhados para acentos, palavras vazias e correspondencia; isolamento de leituras de obras com a mesma data. iOS expoe todas as leituras selecionadas e etapas da trilha, sem os antigos cortes de apresentacao. Android prepara a selecao e carrega os metadados fora da interface, uma vez por abertura, considerando textos editados.
- IA: modelos alinhados para Gemini 2.5 Flash Lite e Flash; chave em cabecalho HTTP. Todas as partes publicas da resposta sao preservadas, sem incluir blocos internos de raciocinio. Respostas interrompidas deixam de ser aceitas como completas; removido o teto Android de 1.800 tokens de saida.
- Dossie: referencias [F1] etc. precisam existir no conjunto recuperado. Resposta antiga nao pode substituir um dossie diferente. A exportacao textual iOS inclui todas as referencias recuperadas, nao somente as primeiras doze.
- PDF iOS: indice de exportacao pagina titulos longos e referencia de pagina original, evitando caixas de altura fixa. As notas permanecem separadas e o comentario inicia pagina propria.
- Importacao iOS: os testes revelaram inversao de orientacao das imagens. Renderizacao e entrada do OCR agora compartilham a transformacao correta de coordenadas, origem, escala e rotacao do PDF. Falhas de OCR, pagina ou escrita propagam erro e nao publicam sucesso incompleto.
- Importacao Android: verifica sucesso da codificacao da imagem e sincroniza sua gravacao antes de publicar a obra.
- Android 15/API 35 ou superior: prefere a camada textual nativa quando disponivel. Quando o motor fornece texto sem geometria, localiza as linhas no proprio PDF, preservando seus caracteres e separando as notas pela linha divisoria. Paginas sem texto e sistemas anteriores continuam no OCR. Essa mudanca resolveu na amostra a juncao indevida de palavra e numero; nao equivale a validar todo OCR externo ou a ordem de todos os paragrafos. [API oficial de texto e posicoes](https://developer.android.com/reference/android/graphics/pdf/content/PdfPageTextContent).

## Evidencias desta rodada

- iOS: 33 testes passaram, incluindo consulta ao acervo instalado, 138 blocos paginados sem perdas, rotacoes 0/90/180/270 comparadas com PDFKit, PDF digitalizado com corpo e nota, documento de 40 paginas com duas colunas de marcadores e exportacao de tres dias com titulos longos. O teste de duas colunas verifica presenca dos marcadores, nao toda a ordem editorial de um documento complexo.
- A verificacao de orientacao falhou inicialmente. Os logs das falhas e da correcao permanecem preservados; o teste nao teve sua tolerancia relaxada.
- Contrato estrutural: passou. Nao e certificacao funcional.
- Interface Apple: 9/9 no iPhone e 9/9 no iPad, incluindo descricoes e areas de toque na Home/busca, abrir/voltar repetido, tela cheia, configuracoes e troca rapida de abas. No iPad, a coleta auxiliar `simctl diagnose` ficou aguardando apos os testes; foi encerrada isoladamente, preservando o resultado final `TEST SUCCEEDED`. Amostra de pilha preservada, sem atribuir esse problema ao aplicativo.
- Compilacao Release iOS/widget/watchOS concluida localmente, sem assinatura ou upload.
- Depois do ultimo ajuste dos indicadores de busca/dossie, repetidos os 33 testes iOS, dois fluxos de interface (abas e busca) e a compilacao Release: todos aprovados. O cenario temporal exato de cancelar um dossie durante uma consulta longa ainda merece um caso de regressao dedicado.
- Android: a primeira rodada de 26 testes teve uma falha de fidelidade na amostra em paisagem. Mantida a exigencia de texto exato; a correcao de texto nativo e posicionamento passou nos dois ensaios focados. A extracao nativa inicialmente deixou as notas no corpo porque o motor retornou texto sem posicoes; resolvido localizando cada ocorrencia no proprio PDF. Nenhuma expectativa de notas ou texto foi removida para aprovar os testes.
- Android final: 21 testes unitarios e 26 instrumentados passaram. A amostra digitalizada afirma explicitamente `textSource=ocr`; a nativa afirma `textSource=pdfTextLayer`. Compilacoes Debug/Release do app e Release Wear bem-sucedidas, sem upload.
- Fontes Android a 200%: tres fluxos adicionais passaram (abas, ferramentas de leitura em largura estreita e abertura da busca). Fonte restaurada a 100% e emulador encerrado. Nao e teste completo de TalkBack ou contraste.
- PDFs nativos atuais: ambos com 12 paginas e zero falhas na verificacao automatica dos 45 paragrafos, numeros/datas, notas e comentario posterior. Inspecao visual das paginas de notas e comentario nao revelou cortes; continuam diferentes as fontes, quebras e posicoes verticais. Nao sao PDFs visualmente identicos.

## Restauracao efetivamente exercitada

Ensaio pelo Backup Manager do Android API 36, exclusivamente no emulador e com transporte local, sem conta Google/nuvem. Criado arquivo novo de preferencias sinteticas, realizado backup, removido somente esse arquivo e solicitado restore. `restoreFinished: 0`; comparacao byte a byte identica ao XML original, incluindo acentos. O arquivo sintetico foi removido ao final, e transporte/configuracao de backup anteriores foram restaurados.

A primeira tentativa de backup foi recusada enquanto o app estava parado a forca. Depois da abertura normal e envio para segundo plano, o backup foi aceito. Isso e evidencia concreta de que `allowBackup=true` isoladamente nao garante uma copia disponivel.

O restore tambem confirmou que `files/RAGPackages` nao retorna pelas regras atuais, que cobrem preferencias. A copia do corpus de auditoria foi reposta a partir dos originais locais para permitir os demais testes. Obras baixadas precisam de novo download; obras importadas localmente e seus arquivos continuam como pendencia de recuperacao. Nao houve desinstalacao de aparelho pessoal, teste de conta real, sincronizacao entre plataformas ou teste de conflitos entre aparelhos.

## Medicao iOS

Acervo ativo de 314 pacotes no simulador, mantendo a exclusao de Rizzardo: primeira consulta "maconaria" em 4.166 ms; frase "grande loja" em 1.751 ms; "etica virtude" em 593 ms; indice da maior obra, com 2.678 paginas, em 70 ms. Contagens: 120, 120 e 78. Nao representa certificacao em aparelho fisico nem latencia total da interface. A abertura repetida dos bancos continua candidata a otimizacao.

Android, corpus reposto depois do restore: 314 pacotes; consultas em 4.256, 976 e 553 ms, respectivamente; mesmas contagens de 120, 120 e 78, sem afirmar identidade de todo o resultado. Indice da obra de 2.678 paginas em 503 ms. Medicoes de uma execucao por consulta, nao p95, teste de partida fria controlada ou classificacao entre plataformas.

## Limites e pendencias reais

1. Busca: comparar resultados exatos e cobertura de notas/metadados/importacoes; normalizar ranking entre bancos separados e eliminar trabalho repetido nas paginas subsequentes. A UI paginada nao transforma a consulta em indice unificado.
2. Estudos: regras comuns nao garantem membros comuns para todas as obras RAG. Android ainda sugere livros por titulo/autor, e a selecao iOS de colecoes usa edicoes locais. Falta cobertura equivalente por conteudo e escopo em ambas as plataformas.
3. Exportacao: ampliar comparacao visual de multiplos dias, destaques, livros e dossies. Fontes nativas e quebras de linha continuam diferentes.
4. Importacao: corpus real compartilhado com rotacoes, colunas, imagens intercaladas, PDFs protegidos e parcialmente danificados. A preservacao do original nao comprova OCR perfeito. A geometria de blocos ainda nao e equivalente em todos os caminhos.
5. Restauracao: iCloud usa snapshots globais, sem resolucao por registro/exclusao; Android Auto Backup protege preferencias, mas nao todas as obras locais importadas. Permanecem I/O no fluxo de backup iOS e necessidade de ensaio com contas e aparelhos descartaveis. Nao ha recuperacao garantida nem sincronizacao entre iOS e Android.
6. IA: o teste de IDs de citacao e sintatico. Ainda falta provar que cada afirmacao esta sustentada pelo trecho, executar casos reais de recusa, quota, chave e rede com credencial de teste e avaliar recuperacao semantica. Nenhuma chave antiga do historico foi reutilizada.
7. Dispositivos: iPhone fisico detectado, mas a consulta falhou com dispositivo bloqueado (CoreDevice 10003). Nao houve reinstalacao nem exclusao de dados pessoais. Integracoes com Watch/Wear, widgets encerrados e notificacoes reais continuam pendentes.
8. Acessibilidade: auditoria automatica parcial nao substitui VoiceOver/TalkBack, fontes grandes, contraste e navegacao em toda a matriz de aparelhos.

Documentacao primaria consultada para o protocolo de IA: [generateContent](https://ai.google.dev/api/generate-content) e [ciclo de vida dos modelos Gemini](https://ai.google.dev/gemini-api/docs/deprecations). Aceitar somente `finishReason=STOP` e verificar referencias reduz respostas incompletas, mas nao demonstra ausencia de alucinacoes.

Evidencias: `Paridade/evidencias/2026-09-18-continuacao`. Relatorio anterior preservado em `Paridade/RELATORIO_CONTINUACAO_2026-09-18.md`. O contrato continua com `functionalAudit.status=pending`.

Logs principais: `ios-unit-state-final.log`, `iphone-ui.log`, `ipad-ui.log`, `iphone-query-state-final.log`, `ios-release-final.log`, `android-build-final.log`, `android-instrumentacao-final.log`, `android-fontes-200.log`, `android-backup-local-active.log`, `android-restore-local.log` e `comparacao-pdf.json`. As tentativas anteriores permanecem para rastreabilidade. O XML de restauracao foi comparado com `Paridade/fixtures/backup-probe.xml` por igualdade byte a byte.
