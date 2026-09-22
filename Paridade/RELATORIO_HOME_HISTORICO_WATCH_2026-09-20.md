# Home, historico e Watch - retomada de 20/09/2026

## Escopo

Biblioteca de desenvolvimento 1.0.15 e equivalente Android. Producao 1.0.14 preservada, sem publicacao e sem importacao do Rizzardo. Nenhum aplicativo pessoal foi removido. Complementa `RELATORIO_BACKUP_SINCRONIZACAO_2026-09-20.md`; resultados anteriores nao foram apagados.

Evidencias desta rodada: `Paridade/evidencias/2026-09-20-retomada`.

## Correcoes realizadas

### Home e controles iOS

- Titulos e metadados dos cartoes passaram a permitir quebra de linha. Em tamanhos de acessibilidade, os cabecalhos dos cartoes usam disposicao vertical. O resumo continua sendo um resumo, sem alterar texto integral ou PDF.
- A area de rolagem foi limitada ao espaco disponivel. A conferencia visual mostrou os textos acima do menu inferior, sem o efeito de texto ampliado atras da barra. Desativado o efeito de borda somente nessa Home no iOS 26 ou superior.
- O gesto administrativo de oito toques foi movido do cabecalho inteiro para o titulo, separado da engrenagem. O controle manteve a aparencia circular, com area de toque minima de 44 pontos. Nao foi removida sua protecao administrativa.
- A repeticao de abrir Configuracoes e voltar falhou uma vez antes desse ajuste e passou depois, incluindo tres ciclos na mesma execucao. Essa repeticao bem-sucedida nao prova ausencia de qualquer falha intermitente.

### Historico por obra nas duas plataformas

- Android antes usava a ordem das datas marcadas como lidas para montar os recentes do breviario; agora registra visitas reais, inclusive ao avancar e retroceder. Abrir uma data antiga a torna recente sem marca-la automaticamente como lida.
- Livros Android antes substituiam todo o historico da obra a cada visita e limitavam o conjunto global. Agora guardam cinco referencias distintas por obra e exibem ate tres por obra. O registro acompanha a pagina efetivamente aberta, inclusive apos busca e navegacao interna.
- Preservados registros legados existentes de livros, favoritos e progresso. A versao antiga nao armazenava a ordem real das visitas diarias, portanto essa ordem nao pode ser reconstruida retroativamente; o novo historico diario comeca nas novas visitas.
- iOS ja mantinha cinco referencias por obra e exibia tres, mas a Home tentava carregar os recentes dos livros RAG pelo caminho JSON. Corrigido o carregamento de obras baixadas pelo catalogo RAG.
- A consulta iOS seleciona somente as paginas recentes e suas notas no SQLite, com parametros vinculados e isolamento por obra. Lista vazia/invalidos nao provocam carga integral. O caminho JSON continua preservando edicoes e midias existentes.
- A ordem dos grupos e a composicao visual ainda seguem cada plataforma; nao foi certificada equivalencia visual integral nem desempenho do historico com todas as obras.

## Testes executados

| Validacao | Resultado | Evidencia |
| --- | --- | --- |
| Android unitarios | 31 aprovados, zero falhas | `android-final-build.log` e XML em `app/build/test-results/testDebugUnitTest` |
| Android interface/integridade final | Runner informa 30 casos: 29 aprovados, 1 Gemini ignorado sem opt-in/credencial; zero falhas; 32,544 s | `android-final-regression.log` |
| iOS dados/regras final, incluindo recentes RAG | 48 casos: 47 aprovados, 1 Gemini ignorado; zero falhas | `ios-unit-rag-recents.log` |
| iOS interface completa, antes da ultima correcao da engrenagem | 19 casos: 14 aprovados, 5 casos reprovados, 10 ocorrencias de falha | `ios-ui-regression-final.log` |
| iOS repeticao dirigida apos ajuste da engrenagem | 6 casos: 2 navegacoes aprovadas; 4 auditorias de acessibilidade reprovadas, 10 ocorrencias de contraste | `ios-navigation-contrast-recheck.log` |
| Compilacao Watch atual | Aprovada, assinada com perfil de desenvolvimento existente | `watch-build.log` |
| Verificacao estrutural | Zero falhas/alertas; fontes compartilhadas identicas | `paridade-estrutura.log` |
| Verificacao para liberacao | Reprovacao esperada por auditoria funcional pendente | `paridade-liberacao.log` |

O teste iOS novo cria pacote temporario com duas obras e quatro paginas por obra: verifica selecao de tres referencias, ordem recente reconstruida, texto completo, notas, duplicatas, referencias invalidas e isolamento entre obras. Nao modifica o acervo pessoal. Os novos testes Android cobrem retencao por obra, ordem das visitas, preservacao de progresso e cliques reais em anterior/proxima.

A primeira rodada Android foi impedida por `System UI isn't responding`. O teste de janela ativa detectou o dialogo externo. O emulador foi reiniciado usando GPU do computador; a repeticao completa passou. O emulador foi encerrado ao terminar. Nenhum teste foi desativado para contornar esse problema.

## Acessibilidade ainda aberta

As auditorias completas de Home, Home apos rolar, Busca e Dossie continuam apontando contraste. Algumas capturas mostram texto visualmente legivel e outras envolvem elementos nas bordas/menu inferior. A divergencia entre captura visual e auditoria automatica nao foi esclarecida, portanto nao se classifica como falso positivo nem como corrigida.

Capturas e descricoes preservadas em `ios-final-attachments` e `ios-recheck-attachments`. Nenhum alerta foi filtrado e nenhum teste de acessibilidade foi desabilitado. `continueAfterFailure` nos testes Home apenas coleta todas as falhas. VoiceOver/TalkBack, fontes maximas e toda a matriz de aparelhos ainda nao foram certificados.

## Watch fisico e desbloqueio

- Xcode aceitou duas instalacoes da compilacao de desenvolvimento no Series 8. As tentativas de abertura retornaram bloqueio; entre elas, uma consulta nao encontrou o aplicativo, levando a nova instalacao.
- Apos a informacao de desbloqueio, a ultima tentativa de abertura expirou apos 20 segundos (`watch-launch-latest.json`). Consultas de processos e bloqueio tambem expiraram.
- O dispositivo aparece como disponivel/pareado, mas isso nao comprova canal de execucao funcional. Nao foi possivel confirmar o aplicativo aberto nem concluir leitura, notificacao, marcacao de lido e sincronizacao offline/reconexao no Watch real.
- O Device Hub informa que o compartilhamento de tela requer watchOS 27; esse Watch esta em 26.6. Nao houve atualizacao de sistema, novo pareamento ou mudanca de certificados/perfis para contornar a limitacao.
- Nenhuma reinstalacao ou apagamento do iPhone pessoal nesta rodada. As alteracoes de Home/historico foram validadas no simulador; nao foram declaradas instaladas no iPhone.

Proximo passo fisico: abrir Biblioteca diretamente no Watch, no pulso e desbloqueado, e confirmar a tela apresentada. Se ainda nao houver canal de desenvolvimento, revisar a conexao pelo Xcode sem desparear nem apagar dados.

## Pendencias e bloqueio de liberacao

1. Acessibilidade acima e validacao visual nas duas plataformas.
2. Restauracao iCloud/Google real em conta/aparelho de teste, conflitos e documentos. O teste anterior Android foi de transporte local, nao de nuvem Google.
3. Gemini com credencial exclusiva de teste no armazenamento seguro. Nenhuma chave exposta no historico foi utilizada.
4. Watch/Wear, notificacoes com abertura a frio, progresso bidirecional e retorno de conexao em aparelhos reais.
5. Busca/indices, regras de colecoes/trilhas, exportacoes/PDF, importacao complexa, tela cheia/destaques e desempenho do acervo completo fisico continuam com as lacunas ja descritas no contrato. A auditoria de codigo desta rodada confirmou que as recomendacoes de estudo ainda usam coberturas diferentes de fontes; nao foram declaradas equiparadas.

`functionalAudit.status` permanece `pending`, com os dez bloqueios comuns preservados. Compatibilidade estrutural nao e equivalencia funcional. Nenhuma publicacao foi realizada.
