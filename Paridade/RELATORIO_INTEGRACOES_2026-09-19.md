# Integracoes reais e acessibilidade: 19/09/2026

## Decisao

Liberacao bloqueada; equivalencia funcional completa nao declarada. Trabalhos limitados a BibliotecaMaconica_Dev, projeto Android e testes/relatorios de paridade. Versao 1.0.15; nenhuma publicacao. A copia preservada 1.0.14 nao foi alterada.

## Correcoes implementadas

- watchOS: registro antecipado do delegado de notificacoes e tratamento de toque/acao Abrir leitura. A leitura e recuperada pela data e obra do aviso, inclusive quando aberto em outro dia. Obra/data desconhecida nao e substituida silenciosamente pela leitura atual. Identificador da obra incluido no aviso.
- Android: teste de notificacao so confirma agendamento quando a permissao e o canal permitem. A concessao inicial da permissao agora executa a acao pendente. Botoes de notificacoes podem quebrar linha em largura pequena.
- Android e Wear OS: notificacoes incluem Abrir leitura, data/obra e identidade especifica no PendingIntent. No Wear, o toque abre o texto completo; pedido invalido apresenta indisponibilidade em vez de outra leitura. Carregamento inicial retirado da interface, cancelando pedido anterior e tratando erro de arquivo.
- iOS: autor da leitura sem limite fixo de duas linhas; campos de pesquisa menores e multilineares; descricoes/valores acessiveis nos controles de tamanho, espacamento e voz. Cores secundarias opacas por tema.
- O experimento que removia o efeito da borda inferior de rolagem nao resolveu os alertas e foi retirado. Nao foram ignorados tipos de auditoria para obter aprovacao.

## Evidencias

Pasta: `Paridade/evidencias/2026-09-19-integracoes`.

| Validacao | Resultado e alcance |
| --- | --- |
| XCTest iOS | 35 casos: 34 passaram, 1 pulado por ausencia de credencial Gemini explicitamente habilitada. Zero falhas. Inclui regressao de notificacao por data/obra e acervo completo instalado no simulador. `ios-unit.log`. |
| Android unitario | 21 casos, zero falhas. Compilacao Debug de app, testes e Wear OS aprovada. `android-build.log`, `android-build-final.log`. |
| Android instrumentado inicial | 28 casos: 26 aprovacoes, 1 pulado (Gemini), 1 falha de preparacao: corpus ausente no emulador. A exigencia de 314 pacotes foi mantida. `android-instrumentados.log`. |
| Notificacao Android | O teste confirmou a existencia da notificacao no NotificationManager do sistema, corpo e acao Abrir leitura. Nao prova toque real, entrega com aparelho bloqueado, Doze ou horario exato. |
| IA HTTP real | Requisicao sintetica sem chave real recebeu HTTP 400/API_KEY_INVALID. `gemini-chave-invalida.json`. Nao representa sucesso da IA no app, credencial valida, limite gratuito ou ausencia de alucinacoes. |
| Assinatura e instalacao | Build Debug iPhone/widget/watchOS assinado e instalado no iPhone sem desinstalar. Atualizado novamente com o estado final, incluindo a API atual WKApplicationDelegateAdaptor no Watch, sem avisos de API obsoleta nessa compilacao. Assinatura validada e entitlements de iCloud/App Group presentes. Isso nao comprova restauracao em nuvem. `build-iphone-watch-final.log`, `assinatura-final.log`, `instalacao-iphone-final.log`. |
| Contrato estrutural | Zero falhas e alertas. Conteudo compartilhado identico. `contrato-estrutural.log`. Nao equivale a paridade funcional. |

**Android final:** repostos somente os pacotes referenciados pelo catalogo e repetidos os mesmos 28 casos: 27 aprovados, 1 pulado (Gemini), zero falhas. `android-instrumentados-final.log`. A verificacao de notificacao afirma corpo, ContentIntent e acao Abrir leitura presentes no sistema. O emulador foi encerrado apos o teste.

**Medicoes de acervo no emulador Android:** 314 pacotes; consultas em 4.075 ms (maconaria, 120 ocorrencias), 1.032 ms (frase grande loja, 120) e 572 ms (etica virtude, 78). Indice da obra de 2.678 paginas: 530 ms. Sao amostras individuais, nao p95 ou certificacao de aparelho fisico. `medicao-acervo-android.json`.

**Bloqueio de liberacao exercitado:** `verificar_paridade.sh --release` retornou falha explicita por auditoria funcional pendente. Nenhuma pendencia foi removida para liberar a versao. `gate-liberacao.log`.

## Acessibilidade

Seis auditorias completas foram adicionadas, sem filtro de falhas: Home, busca, configuracoes, leitura, colecoes e dossie.

A primeira rodada detectou corte do autor. A rodada focada aprovou a leitura e detectou corte do campo de busca. Depois do ajuste do campo, a rodada completa registrou leitura aprovada e cinco telas reprovadas por contraste. Capturas e descricoes preservadas em `a11y-inicial` e `a11y-segunda`; logs `acessibilidade-ios.log`, `acessibilidade-corrigida-ios.log` e `acessibilidade-segunda-ios.log`.

Ha ocorrencias em subtitulos de busca/colecoes/dossie e em regioes proximas da barra inferior. As capturas isoladas nao permitem descartar esses alertas como falsos positivos. Nao se consideram resolvidos. A ultima rodada ocorreu antes de retirar o experimento da borda de rolagem; acessibilidade completa continua pendente no estado final. Faltam VoiceOver/TalkBack, contraste nos tres temas, rolagem integral e fontes grandes em toda a matriz, incluindo relogios.

A coleta auxiliar `simctl diagnose` ficou parada apos a suite de interface terminar. Foi encerrada isoladamente, preservando falhas e resultado. A suite unitaria aguardou a abertura do simulador, mas terminou com `TEST SUCCEEDED`; a amostra de processo foi preservada durante a investigacao. Nao se atribui essa espera a um travamento do app sem evidencia.

## Aparelhos e seguranca dos dados

Os quatro registros abaixo descrevem a primeira rodada. O estado atualizado dos aparelhos esta na secao "Segunda rodada fisica", ao final deste documento.

- iPhone 15 Pro Max reconhecido, com Modo Desenvolvedor habilitado. Atualizacao realizada sobre a instalacao existente. Preferencias copiadas localmente antes da instalacao; nenhuma exclusao de dados pessoais.
- A abertura automatica final foi recusada explicitamente com `Locked`, conforme `abertura-iphone-final.log`. Isso e diferente de falha de instalacao. Nao houve teste funcional completo no aparelho.
- Apple Watch Series 8 reconhecido, mas as consultas posteriores a confirmacao do usuario ainda informaram Modo Desenvolvedor desativado. Nao houve instalacao direta nem aprovacao funcional do Watch.
- Nenhum Android fisico ou Wear OS foi identificado. A notificacao instrumentada foi exercitada exclusivamente no emulador API 36.

## Pendencias criticas

1. **Nuvem real:** identificar contas de teste e um destino descartavel. Validar copia remota confirmada, restauracao apos reinstalacao nesse destino, conflitos entre dois aparelhos, exclusoes, falta de rede e troca de conta. Nao desinstalar o app pessoal para esse ensaio. Os testes anteriores com transporte local Android nao sao evidencia de nuvem.
2. **Cobertura do backup:** iOS ainda usa snapshots globais, sem resolucao por registro/exclusao; Android protege preferencias, mas nao todo arquivo importado localmente. Continuam pendentes cobertura de obras pessoais e I/O no backup iOS. Nao prometer recuperacao garantida ou sincronizacao iOS/Android.
3. **IA:** indicar onde foi configurada uma chave Gemini de teste, sem publica-la na conversa. Os dois testes reais de resposta fundamentada e recusa foram preparados com fontes sinteticas e opt-in; sem chave, sao pulados e nao aprovados. Ampliar depois para quota, rede, cancelamento e sustentacao de cada afirmacao. Nenhuma chave antiga do historico foi reutilizada.
4. **Relogios:** concluir Modo Desenvolvedor no Watch e manter o iPhone desbloqueado. Validar notificacao local/espelhada, toque com app encerrado, sincronizacao de lido offline e reconexao. App Group nao transporta dados entre iPhone e Watch; obras adicionais ainda precisam de transporte explicito. Contexto de progresso Apple guarda somente a ultima alteracao pendente; nao comprova entrega de multiplas alteracoes offline. No Wear, validar dispositivo real, notificacao e sincronizacao com Android.
5. **Notificacoes:** agendamento aceito nao e entrega garantida. Alarmes Android/Wear sao inexatos; o botao de teste em 5s nao foi certificado sob Doze/aparelho bloqueado. Watch agenda janela finita e exige renovacao. Testar reinicio, fuso/data, permissao negada, canal desativado e mudanca de dia.
6. **Acessibilidade:** resolver/diagnosticar os cinco alertas sem suprimi-los, repetir a suite no estado final e realizar testes com leitores de tela nos aparelhos.

## Protocolo para continuar sem expor credenciais

Usar exclusivamente contas e conteudo sintetico de teste. Informar o aparelho/ambiente em que a chave esta configurada, nunca o valor. Executar o teste iOS com `RUN_LIVE_GEMINI_TESTS=1` no ambiente do processo de teste e o Android com argumento de instrumentacao `liveGemini=true`, somente depois de confirmar a credencial destinada a testes. Falta de chave deve continuar sendo registrada como teste pulado.

Para nuvem, preparar comentario, favorito, destaque e configuracao sinteticos, confirmar a copia remota e restaurar em outro destino de teste. Comparar conteudo e identidade por obra, sem usar instalacao pessoal como ambiente destrutivo. A aprovacao exige evidencias do retorno dos dados, nao apenas entitlement, login de conta ou configuracao de backup habilitada.

Referencias oficiais: [auditoria de acessibilidade Apple](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app), [notificacoes no watchOS](https://developer.apple.com/documentation/watchos-apps/enabling-and-receiving-notifications), [testes de backup Android](https://developer.android.com/identity/data/testingbackup).

## Segunda rodada fisica: 19/09, 10h08 a 11h15

Esta rodada substitui os bloqueios iniciais de iPhone bloqueado e Modo Desenvolvedor do Watch desativado. Nenhuma publicacao, desinstalacao ou exclusao de dados pessoais foi realizada. As alteracoes permanecem na versao de desenvolvimento 1.0.15; a copia 1.0.14 foi preservada.

### Apple Developer e Watch

- Com autorizacao explicita, o Apple Watch Series 8 foi cadastrado na equipe Apple Developer. Foi criado apenas o perfil de desenvolvimento `Biblioteca Watch Desenvolvimento Renato 20260919`, usando o certificado de desenvolvimento existente e incluindo o Watch. Nenhum certificado de distribuicao foi alterado.
- Modo Desenvolvedor habilitado e perfil incorporado contendo o dispositivo foram confirmados. O build watchOS com esse perfil foi aprovado.
- Instalacao real no Watch concluida: `fisicos/watch-instalacao-reconectado.log`. Isso supera a falha anterior por dispositivo ausente no perfil.
- Duas tentativas de abrir o app pelo Mac falharam por desconexao/tunel de rede, depois da instalacao. `watch-abertura.log` e `watch-abertura-segunda.log`. Abertura, entrega de avisos, toque e sincronizacao reais do Watch ainda nao aprovados. Foi solicitada abertura direta no relogio; sem resposta registrada ate esta atualizacao.

### Falhas reproduzidas e correcoes

1. **Leitura preta apos voltar para Home:** reproduzida no iPhone 15 Pro Max/iOS 27 ao abrir uma leitura, voltar para Home e abrir um resultado da busca. A pilha de leitura agora recebe uma nova identidade somente ao sair de uma leitura aberta para Home, evitando reutilizar o destino obsoleto. A tentativa anterior de adiar a selecao ate `onAppear` nao resolveu e foi removida. A correcao final foi validada no aparelho com os resultados de 02/02 e 04/05 e em tres ciclos automatizados. Capturas `iphone-busca-tela-preta.png` e `iphone-busca-corrigida.png`.
2. **Acoes vizinhas nas Configuracoes:** o estilo automatico de botoes dentro da mesma linha de Form podia disparar salvar/cancelar ao tocar no teste. O conteudo dos grupos agora usa estilo explicito borderless, preservando os botoes com estilo proprio. Teste real mostrou a confirmacao correta; regressao automatizada confirmou que enviar o teste nao desliga a opcao de notificacao diaria.
3. **Notificacao com app encerrado:** no estado anterior, tocar no aviso iniciava o app, mas deixava a Home em vez da leitura. O destino agora fica retido em um roteador ate a interface recebe-lo; URLs pendentes sao reavaliadas quando o carregamento termina. O consumo ocorre apos a atualizacao publicada, nao durante `willSet`.
4. **Falha introduzida e corrigida durante o ensaio:** uma implementacao intermediaria com delegado assincrono provocou SIGABRT no iPhone ao concluir a notificacao fora da fila principal, durante a restauracao da cena por UIKit. Esse caminho foi substituido pelo callback de conclusao explicitamente executado na fila principal. O build final foi aprovado e instalado no iPhone; ainda falta repetir o toque fisico com app encerrado nessa ultima compilacao, pois o Mac bloqueou a tela. Nao se considera o caso aprovado apenas por compilar.

### Resultados finais desta rodada

| Caso | Resultado |
| --- | --- |
| iOS unitario final | 37 casos executados: 36 aprovados, 1 pulado por ausencia de credencial Gemini de teste, zero falhas; 10,87 s. `fisicos/ios-unit-final.log`. |
| Interface final | Tres casos aprovados, zero falhas: notificacao sem cancelamento vizinho, entradas/saidas repetidas de Configuracoes e busca apos leitura/retornos repetidos para Home; 88,68 s. `fisicos/regressoes-validacao-final.log`. |
| Notificacao real com app em segundo plano | Entregue no iPhone, toque abriu a leitura de 19/09, Maçonaria na Bulgária. Captura somente da tela do app: `fisicos/iphone-leitura-via-notificacao.png`. Nao equivale a teste com processo encerrado. |
| Notificacao real com processo encerrado | Falha anterior reproduzida; correcao final compilada/instalada, reteste fisico pendente por bloqueio da tela do Mac. |
| Navegacao real | Resultados da busca abrem o texto correto depois de voltar da leitura para Home. A tela preta nao se repetiu nos ciclos realizados. |
| Watch | Cadastro, perfil, assinatura e instalacao aprovados; abertura funcional e integracoes pendentes por conexao instavel. |

O teste inicial de Configuracoes teve uma falha de memoria no simulador. Ela nao se repetiu no build de pasta limpa e nos ciclos finais; uma execucao bem-sucedida nao prova eliminacao universal. Foi criado um esquema compartilhado de testes de interface para tornar a execucao reproduzivel.

Duas falhas posteriores eram do preparo do teste: toque no contêiner do Toggle em vez do interruptor filho, e espera por um alerta inexistente que ultrapassava os 2,8 segundos da confirmacao. Os alvos e a espera foram corrigidos, mantendo as assercoes de estado e sucesso. A captura da hierarquia confirmou a causa; nao foram relaxados os criterios. Coletas auxiliares `simctl diagnose` paradas apos os testes foram encerradas isoladamente, preservando os resultados.

### O que continua bloqueando a aprovacao completa

- Repetir a notificacao de abertura a frio no iPhone depois de desbloquear o Mac.
- Confirmar abertura e fluxos no Watch, incluindo notificacao local/espelhada e progresso offline.
- Executar restauracao real em contas/destinos de teste, IA com credencial valida e acessibilidade completa. As pendencias anteriores de backup, transporte entre dispositivos, Android/Wear fisicos e contraste continuam abertas.
- Contrato estrutural nao substitui equivalencia funcional. A liberacao permanece bloqueada.

## Retomada fisica apos 11h17

- Apple Watch reconectado, Modo Desenvolvedor habilitado. O comando de abertura do app terminou com sucesso (`fisicos/watch-abertura-retomada.log`), e uma consulta posterior confirmou o processo `BreviarioWatch` ativo (`watch-processo-retomada.log`). Isso comprova abertura/execucao, nao funcionamento integral da leitura ou entrega de notificacoes.
- A captura do Watch foi obtida em 396 x 484 pixels, mas esta totalmente preta. Nao serve como evidencia visual de leitura. A consulta posterior de logs de falha do Watch excedeu 15 segundos; nao e possivel afirmar ausencia de falhas nesse aparelho a partir dessa consulta.
- No iPhone, foi enviado outro aviso de teste e encerrado somente o processo principal da Biblioteca. Antes de um toque controlado no aviso, a tela mudou para Ajustes e depois a captura ficou totalmente preta. A consulta chamada `iphone-antes-toque-frio-final.log` mostrou um novo processo principal ativo: portanto, esse ensaio NAO comprova abertura a frio controlada e nao foi aprovado.
- O iPhone continuou acessivel para consulta. O unico relatorio de falha retornado foi o ja conhecido de 11h04, da implementacao intermediaria; nao apareceu novo relatorio nesta consulta (`iphone-falhas-retomada.log`). Ausencia de novo relatorio nao substitui o teste funcional.
- Foi solicitado ao usuario manter as telas dos dois aparelhos acesas e o iPhone sem uso por dois minutos. Os testes de toque, leitura visivel no Watch e sincronizacao permanecem pendentes ate haver acesso visual verificavel. Nenhuma alteracao adicional no codigo, desinstalacao ou publicacao foi realizada nesta retomada.
