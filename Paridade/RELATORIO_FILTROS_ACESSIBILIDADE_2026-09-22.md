# Continuacao direcionada: filtros, indices, dossies e acessibilidade

Periodo: 21 e 22/09/2026. Desenvolvimento iOS/Android 1.0.15.

## Limites

Continua o `RELATORIO_BUSCA_IMPORTACAO_2026-09-21.md`, sem repetir a auditoria dos modulos ja aprovados. A versao preservada 1.0.14 nao foi modificada. Nenhum upload, publicacao, troca de conta pessoal ou desinstalacao destrutiva foi realizado. Compatibilidade estrutural nao significa equivalencia funcional integral.

## Correcoes implementadas

1. **Filtros comuns por autor e assunto:** os dois apps usam dez casos versionados, incluindo acentos, limites de palavra, expressao ordenada, pontuacao e combinacao dos filtros. O filtro e aplicado antes do limite/paginacao e tambem abrange notas de rodape. Autor nao e procurado indevidamente no assunto, nem assunto no autor.
2. **Identificacao dos resultados iOS:** resultados estruturados passam a carregar autor, assuntos e tipo da obra presentes no banco, em vez de perder esses metadados. Erros de leitura nao sao convertidos silenciosamente em resultados vazios.
3. **Isolamento das obras Android:** um teste com duas obras no mesmo banco revelou resultados da obra excluida pelo filtro. A consulta agora identifica as obras autorizadas por arquivo antes de consultar o indice e as notas. Bancos compartilhados nao sao consultados repetidamente. A juncao considera a obra quando o FTS possui essa coluna; o formato legado com apenas identificador de bloco continua suportado.
4. **Busca e dossie:** campos de autor e assunto nas duas interfaces; alteracao do filtro invalida resultados e analise anteriores. O escopo filtrado acompanha a exportacao em texto e PDF. A IA continua opcional.
5. **Indice remissivo iOS:** escolha explicita da obra sem trocar a leitura ativa. Area/obra inexistente nao retorna o indice de outra obra. O cache considera o catalogo e descarta respostas de solicitacoes antigas. Nao foram inventados indices editoriais para obras que nao os possuem.
6. **Importacao Android:** assuntos opcionais sao normalizados e preservados no manifesto e no banco, permitindo busca filtrada nas novas obras. O teste de PDF paisagem com colunas e ilustracoes verifica original preservado e consulta por assunto. Nao houve reimportacao em massa do acervo.
7. **Exportacao de dossie:** o cabecalho das paginas e `Biblioteca Maconica` (com acentos na interface) nas duas plataformas. O cabecalho tradicional das exportacoes do breviario foi preservado. A verificacao usa 30 fontes completas, notas, citacoes, filtros e analise opcional, com marcadores de fim para detectar supressao.
8. **Acessibilidade iOS:** o nome acessivel da busca na Home agora coincide com seu texto visivel. Os novos filtros de autor/assunto usam campos que crescem em ate tres linhas, nomes acessiveis explicitos e rotulos permanentes que podem quebrar linha. A inspecao visual revelou abreviacao no placeholder apesar da aprovacao automatica inicial; por isso os rotulos passaram para fora dos campos, e o teste agora exige posicao inteiramente visivel entre as barras. Um contorno identifica tambem o campo vazio. A mudanca do filtro do dossie e o teste reforcado da maior fonte passaram; a auditoria completa de busca voltou a apontar outro elemento, `Resultados`, sem aprovar integralmente a tela.

## Evidencias e execucoes

Pasta: `Paridade/evidencias/2026-09-21-filtros-acessibilidade`.

| Execucao | Resultado observado |
| --- | --- |
| `ios-targeted.log` | Tres testes aprovados: filtros/metadados, obra explicita no indice e dossie integral com filtros. |
| `ios-final.log` | Dois testes aprovados: PDF apos ajuste de cabecalho e consultas com os 314 pacotes. |
| `ios-ui.log` | Quatro testes executados: invalidacao do dossie aprovada; tres auditorias reprovadas (Home, Colecoes e novo campo autor). |
| `ios-ui-final.log` | Binarios compilaram, mas o runner perdeu conexao com o IDE antes de iniciar os casos. Nao equivale a aprovacao nem demonstra crash do app. |
| `ios-ui-retry.log` | Apos reiniciar o simulador, tres casos passaram em 94,178 s. A inspecao visual posterior encontrou placeholders abreviados e motivou rotulos permanentes e teste mais exigente. |
| `ios-ui-labels.log` | Dossie e teste reforcado de maior fonte aprovados. Auditoria completa reprovada por contraste de `Resultados`, em y=865,67...886, sob a barra inferior e sem disponibilidade ao toque. |
| `ios-ui-bordered.log` | Verificacao final aprovada com maior fonte, rotulos completos e campos com contorno; capturas em `ios-ui-bordered-attachments`. |
| `android-targeted/instrumentation.log` | Preserva a falha inicial do filtro (100 resultados em vez de 60), posteriormente corrigida. |
| `android-corrected/instrumentation.log` | Tres casos aprovados apos corrigir a exclusao de obras que compartilham banco. |
| `android-final/instrumentation.log` | Tres casos aprovados, incluindo FTS legado, filtros/paginacao e dossie filtrado. Anterior ao ultimo ajuste do cabecalho PDF. |
| `android-import/instrumentation.log` | Importacao complexa com assuntos, tres paginas e original preservado aprovada. |
| `android-final-verification/instrumentation.log` | Tres testes finais aprovados em 41,994 s: PDF, mudanca do filtro do dossie na interface e consultas com acervo completo. |
| `comparacao-dossie.json` | Os dois PDFs preservaram uma ocorrencia de cada um dos 30 marcadores finais de fonte e nota, citacoes, filtros, analise e cabecalho em todas as paginas A4. |

O Gradle executou 31 testes unitarios na compilacao dos binarios Android dessas rodadas. A aprovacao anterior das compilacoes Release nao deve ser confundida com verificacao Release destas novas alteracoes.

## Desempenho

O simulador iOS consultou os 314 pacotes, mantendo o Rizzardo excluido. As buscas globais levaram 11,70 s, 5,11 s e 2,48 s; o indice da maior obra, com 2.678 paginas, levou 0,136 s. O caso inteiro levou 28,596 s. Esses tempos nao sao de inicializacao do app nem de aparelho fisico. A primeira consulta de 11,70 s ainda merece otimizacao/medicao controlada; passar no limite tecnico de 15 s do teste nao a transforma em uma experiencia instantanea. A preparacao do simulador teve pausas muito maiores e nao deve ser contabilizada como tempo de busca.

No emulador Android com os mesmos 314 pacotes, as consultas levaram 8,487 s, 3,302 s e 1,713 s. O indice de 2.678 paginas levou 0,840 s. Ambos retornaram 120, 120 e 78 resultados, respectivamente. Igualdade de contagem nao prova igualdade de todos os resultados/ordem. As medicoes foram feitas em ambientes diferentes e nao estabelecem qual plataforma e mais rapida em producao.

## Comparacao visual do dossie

Foram renderizadas e inspecionadas capa e primeira pagina interna dos PDFs finais. Cabecalho, margens, filtros e texto estavam legiveis nas capturas. Os documentos preservaram os marcadores testados, mas **nao sao visualmente identicos**: o iOS produziu 23 paginas e o Android 22; a hierarquia de titulos, ordem de algumas secoes, fontes e espacamento ainda diferem. A exportacao integral foi verificada para a amostra, nao a equivalencia grafica completa. Arquivos `dossie-ios-final.pdf`, `dossie-android-final.pdf` e capturas com o mesmo prefixo.

## Pendencias reais

- **Acessibilidade:** permanecem falhas de contraste registradas em Home, Colecoes e Busca. As ocorrencias desta rodada estavam sob a barra inferior e sem disponibilidade ao toque; isso nao explica nem elimina todas as falhas anteriores. Nenhuma falha foi suprimida e VoiceOver/TalkBack completo nao foi certificado. Os rotulos completos e os filtros passaram no teste reforcado de maior fonte, sem generalizar essa aprovacao para toda a tela.
- **Indices e exportacoes:** a cobertura editorial das demais obras, a busca rapida de termos do indice global no iOS e a matriz completa de layouts/selecoes ainda nao estao integralmente equiparadas. O teste sintetico de 30 fontes nao certifica todas as combinacoes.
- **Restauracao real:** faltam conta e aparelho de teste identificados para restauracao apos reinstalacao e conflitos entre dispositivos. Habilitar iCloud/Auto Backup e passar em testes locais nao garante recuperacao. Dados pessoais nao serao apagados como parte da verificacao.
- **IA real:** falta confirmar uma credencial exclusiva de teste no armazenamento seguro do app. Nenhuma chave exposta no historico foi reutilizada. Testes locais de citacao nao provam qualidade de resposta de um provedor real.
- **Relogios/notificacoes/widgets:** a leitura de estado do Apple Watch retornou pareado, modo desenvolvedor habilitado e canal desconectado (`watch-connection.log`). A conferencia final em 22/09 confirmou Watch indisponivel e iPhone pareado/disponivel (`devices-final.log`). Nao houve teste completo de entrega real. Tambem falta aparelho Wear OS disponivel para os cenarios equivalentes.
- **Desempenho fisico:** falta medir abertura, busca, leitura, memoria e troca de telas com o acervo completo nos aparelhos-alvo. Resultados de simuladores nao sao certificacao de producao.

O contrato permanece pendente. As melhorias acima corrigem diferencas concretas; nao autorizam declarar os dois sistemas completamente iguais ou prontos para liberacao.

## Fechamento

Verificacao estrutural final: zero erros e zero alertas, versoes e recursos comuns identicos (`estrutura-final.log`). A verificacao de liberacao reprovou corretamente porque a auditoria funcional segue pendente (`liberacao-bloqueada.log`). Os dez grupos de pendencias do contrato foram preservados. Nenhuma publicacao foi realizada.
