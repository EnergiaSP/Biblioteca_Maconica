# Colecoes, trilhas, backup e pacote Watch - 21/09/2026

## Escopo e decisao

Biblioteca de desenvolvimento 1.0.15, iOS e Android. A versao publicada 1.0.14 e os originais foram preservados. Nao houve publicacao, upload, importacao do Rizzardo, troca de conta ou desinstalacao em aparelho pessoal.

**Equivalencia funcional integral pendente.** Os dez bloqueios do contrato continuam abertos. Esta rodada amplia a cobertura, mas nao certifica recuperacao real em nuvem, IA real, relogios, acessibilidade completa ou ausencia de falhas em todo o acervo.

Evidencias: `Paridade/evidencias/2026-09-21-continuacao`. Complementa `RELATORIO_ESTUDOS_ACESSIBILIDADE_2026-09-21.md`.

## Correcoes realizadas

### Estudos e navegacao

- Android passa a apresentar subtitulo, descricao integral e topicos das colecoes, e subtitulo/instrucao das trilhas, vindos do mesmo JSON canonico do iOS. Nao foram reescritos conteudos das obras.
- Colecoes Android mostram inicialmente tres leituras, com expansao para todas as selecionadas e recolhimento. Linhas e expansao possuem area minima de 48 dp e identificadores estaveis; datas diarias sao exibidas por extenso.
- A apresentacao da colecao foi isolada em `StudyCollectionCard.kt`. As listas usam chaves por colecao/trilha para manter a identidade durante atualizacoes.
- No iOS, trilhas deixam de gerar um UUID novo em cada reconstrucao: usam o identificador canonico. Testes com duas reconstrucoes conferem identidade e metadados.
- As etiquetas iOS de instrucao/duracao empilham em tamanhos de acessibilidade e permitem multiplas linhas. Fontes pequenas foram ampliadas e tornadas adaptativas. A captura revelou recorte de letras pela capsula; o fundo agora e um retangulo de cantos de 8 pontos sem recortar o texto.
- No Android, a barra inferior tem semantica de aba, estado selecionado e area minima de 48 dp. Acima de escala de fonte 1,3, exibe icones sem rotulos visuais truncados; os nomes completos continuam nas descricoes acessiveis. A aparencia na escala normal foi preservada.
- O teste Android de livro importado passou a rolar ate o resultado, confirmar que esta visivel e tocar fisicamente na linha. Confere a abertura da pagina 2, nao apenas a presenca de um leitor. A falha inicial com fonte 200% foi da interacao fora da area visivel e permanece documentada.

### iCloud Documents

- Os tres targets declaravam `CloudDocuments`, mas nao a lista `com.apple.developer.ubiquity-container-identifiers`. O backup do app usa `url(forUbiquityContainerIdentifier: nil)`. A lista ausente foi adicionada com o conteiner ja utilizado, sem criar outro conteiner ou mudar a conta.
- A verificacao estrutural agora interpreta os plists e rejeita lista ausente, vazia, malformada ou nao pertencente aos conteineres configurados. Oito testes cobrem casos validos e invalidos, inclusive CloudKit sem Documents.
- A configuracao foi conferida no binario de desenvolvimento assinado. Isso corrige a configuracao, mas **nao comprova upload, download, conflitos ou restauracao apos reinstalacao**. O caminho de documentos e relevante para volumes que ultrapassam a cota do armazenamento chave-valor.
- Referencia primaria: [Configuracao dos servicos iCloud, Apple](https://developer.apple.com/documentation/xcode/configuring-icloud-services). A Apple distingue as permissoes de Documents, CloudKit e chave-valor. Nao foi usado um backup pessoal para teste destrutivo.

### Inclusao do Watch

- A inspecao do produto revelou que o Watch era compilado separadamente, mas nao estava dentro do app iOS. O filtro `iphoneos` na dependencia e na copia foi corrigido para `ios`.
- O target Watch tambem habilita `watchsimulator`. A primeira tentativa de incorporacao no simulador expunha um binario de watchOS fisico; a configuracao final compila a variante correta e passou novamente.
- Debug para aparelho e Release agora incluem `Watch/BreviarioWatch.app`. O verificador estrutural rejeita o filtro incorreto antigo.
- A assinatura incremental inicial nao selou o Watch recem-acrescentado. A compilacao limpa de desenvolvimento terminou com sucesso e a verificacao profunda/estrita da assinatura passou (`ios-clean-signing-final.log`, `ios-clean-signature-validation.log`). A dependencia de compilacao corrigida ordena a construcao/incorporacao antes do pacote principal. A compilacao anterior nao e considerada evidencia suficiente de integridade.

## Testes desta rodada

| Validacao | Resultado | Evidencia |
| --- | --- | --- |
| Android unitarios | 31 aprovados, zero falhas | `android-paths-final-build.log` e XML do Gradle |
| Android integridade e interface | 35 casos: 34 executados/aprovados, 1 Gemini nao executado por falta de opt-in/credencial; 119,209 s | `android-regression-complete.log` |
| Android fonte 200% | Quatro aprovados: abas, trilhas, expansao de colecoes, PDF importado -> pagina correta; 75,435 s | `android-font2-complete.log` |
| iOS dados/regras | 50 casos: 49 aprovados e 1 Gemini ignorado; zero falhas; 19,98 s | `ios-unit-final.log` |
| iOS interface dirigida | Cinco aprovados: colecoes em fonte maxima, trilhas em fonte maxima, tela cheia, abas, busca -> leitura -> Home | `ios-ui-studies-final.log` |
| iOS etiqueta apos correcao visual | Um aprovado, 109,066 s; captura inspecionada sem corte da etiqueta | `ios-badge-final.log`, `ios-badge-attachments` |
| iOS navegacao apos incorporar Watch | Dois aprovados: destinos das abas e alternancia rapida; 62,209 s | `ios-embedded-navigation-final.log` |
| Permissoes iCloud | Oito testes aprovados | `icloud-entitlements-test.log` |
| iOS compilacao de pacote | Aparelho Debug, simulador e Release passaram com Watch incorporado | `ios-watch-embed-final.log`, `ios-simulator-watch-final.log`, `ios-release-watch-final.log` |
| Assinatura final de desenvolvimento | Compilacao limpa e verificacao profunda/estrita aprovadas | `ios-clean-signing-final.log`, `ios-clean-signature-validation.log` |
| Auditorias completas de acessibilidade iOS 27 | Cinco reprovadas, dez ocorrencias de contraste | `ios27-accessibility.log`, `ios27-attachments` |
| PDFs comuns | Ambos com 12 paginas A4 e zero erros na verificacao de conteudo | `verificacao-pdfs.json` |

A passagem de 35 casos do runner Android nao significa 35 testes reais aprovados: o caso Gemini depende de credencial e nao foi executado. Uma tentativa anterior de regressao Android foi interrompida pelo encerramento prematuro do emulador; nao foi contabilizada como sucesso e foi repetida integralmente. Uma chamada iOS com seletor incorreto executou zero testes (`ios-embedded-smoke-final.log`); tambem nao conta como aprovacao. A repeticao usa os nomes reais da suite.

### Comparacao dos PDFs

Os arquivos desta rodada foram regenerados pelos testes e conferidos por extracao estruturada e renderizacao. As paginas 1, 2, 11 e 12 de cada plataforma foram inspecionadas visualmente. A fixture contem 45 paragrafos, data comum, quantidade numerica, chamadas de notas 578/579, as notas e comentario pessoal.

- Conteudo esperado completo, 12 paginas em ambas as plataformas, A4 595 x 842 pontos.
- Data por extenso, capa no singular e indicacao de comentario salvo presentes.
- Notas em linhas consecutivas na pagina 11; comentario integral inicia na pagina 12.
- Chamadas de nota sobrescritas; data comum e numero 1234 preservados. Nao foram substituidos numeros indiscriminadamente.
- Sem corte observado nas oito paginas renderizadas. Permanecem diferencas de metricas de fontes, quebra de linhas, peso das notas e acabamento da capa. Nao declarar identidade visual, nem cobertura de todos os intervalos e tipos de exportacao, a partir desta fixture.

### Acessibilidade e desempenho

As cinco auditorias de contraste voltaram a falhar em iOS 27, nao apenas em 26.5: Home, Home apos rolagem, Busca, Dossie e Colecoes. Alguns recortes mostram a barra nativa sobre o elemento, enquanto outros exibem pares de cores com contraste calculado de 13,47:1 e 14,87:1. Sao indicios para investigar o auditor, nao prova de que todos os alertas sejam falsos. Nenhum teste foi filtrado, desabilitado ou marcado como aprovado.

A [orientacao da Apple sobre auditorias de acessibilidade](https://developer.apple.com/videos/play/wwdc2023/10035/) reconhece que apontamentos precisam de investigacao; a automacao nao substitui VoiceOver manual. Ainda faltam VoiceOver/TalkBack e matriz completa de tamanhos, temas e aparelhos.

Na regressao iOS, o seletor de estudos percorreu 314 pacotes e 69.711 paginas em aproximadamente 6,985 s. E medicao de simulador, nao certificacao de memoria, bateria ou desempenho em aparelhos fisicos. O Android com fonte ampliada teve as capturas de colecao, trilha e pagina 2 inspecionadas. A fonte do emulador foi restaurada para 1,0 e o emulador foi encerrado depois dos testes.

## Aparelhos e impedimentos reais

- **iPhone:** conectado/desbloqueado; a atualizacao de desenvolvimento foi instalada sem desinstalar. O comando de abertura foi aceito. A captura seguinte mostrou outro aplicativo em uso, por isso foi descartada e as interacoes foram interrompidas. Nao e evidencia visual da abertura da Biblioteca nem de ausencia de crash. A instalacao ocorreu antes da recompilacao limpa da assinatura; o pacote limpo final nao foi reaplicado depois da interrupcao das interacoes.
- **Watch:** o comando de abertura foi aceito nesta rodada, mas consulta de processo e captura expiraram. Nao foi comprovado o fluxo completo no relogio, nem a entrega automatica da nova versao incorporada ao telefone. Nao houve despareamento, reset ou mudanca de conta.
- **Nuvem:** falta conta/aparelho de teste para reinstalacao, download de documentos, recuperacao e conflitos. Nao apagar a instalacao pessoal para tentar encerrar o teste.
- **Gemini:** falta credencial exclusiva no campo seguro e opt-in de teste. A chave exposta anteriormente no historico nao foi usada. Os testes ignorados nao contam como aprovacao.
- **Android/Wear fisicos:** indisponiveis para a matriz real de sincronizacao, notificacoes, reconexao, desempenho e acessibilidade.

## O que ainda impede a conclusao integral

Os dez grupos do contrato continuam abertos: busca/indices, leitura/destaques, regras e fluxos de estudos, exportacoes, fidelidade de importacoes complexas, restauracao real, widgets/relogios/notificacoes, IA fundamentada, desempenho em aparelhos e acessibilidade. Algumas verificacoes desses grupos passaram, mas nenhuma amostra isolada autoriza fechar a matriz inteira.

A verificacao estrutural final passou com zero falhas e zero alertas; arquivos compartilhados identicos, versao 1.0.15 nas duas plataformas. A verificacao `--release` retornou falha exclusivamente pelo bloqueio funcional pendente. A aprovacao para publicacao nao foi dada. Novas alteracoes comuns devem continuar implementadas e testadas nos dois sistemas.

Os processos de testes e compilacao desta rodada terminaram. Nenhum processo de publicacao foi iniciado. Os resultados reprovados e as tentativas interrompidas foram preservados para auditoria, sem serem confundidos com as repeticoes aprovadas.
