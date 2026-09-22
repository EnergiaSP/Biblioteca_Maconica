# Integracoes reais e acessibilidade: 20/09/2026

## Decisao

Liberacao bloqueada; equivalencia funcional completa nao declarada. Esta rodada complementa `RELATORIO_INTEGRACOES_2026-09-19.md` e substitui apenas o estado dos casos explicitamente retestados abaixo. Nenhuma publicacao, desinstalacao em aparelho pessoal ou exclusao de dados pessoais. O executor Android instalou/removeu pacotes temporarios apenas no emulador de testes. Versao de desenvolvimento 1.0.15; copia preservada 1.0.14 intocada.

## Notificacao com app encerrado: aprovada no iPhone

Dispositivo: iPhone 15 Pro Max, iOS 27. Data observada na interface: 20/09.

1. Na Biblioteca instalada, enviado o teste de notificacao em cinco segundos. A notificacao diaria pessoal permaneceu desativada, com horario 08:00 preservado.
2. Encerrado somente o processo principal da Biblioteca (PID 2179), sem desinstalar.
3. Antes do toque, a consulta retornou `outcome: success` e `runningProcesses: []` para o executavel principal. Portanto, o caso nao e apenas retorno do segundo plano.
4. Na Central de Notificacoes, tocado o aviso `20/09 - O Martinismo`.
5. Apos a abertura, apareceu a leitura correta: `Leitura: 20 de setembro`, `O Martinismo`, pagina 265, autor Kennyo Ismail. A consulta confirmou o novo processo principal, PID 2223.
6. O botao Voltar retornou para Home. Nao houve tela preta, reabertura continua ou fechamento nesse percurso.
7. A consulta posterior de falhas listou somente o relatorio antigo e retirado de 19/09, 11h04, da implementacao intermediaria ja substituida. Nenhum novo relatorio foi listado nessa consulta; isso nao prova ausencia universal de falhas.

Evidencias em `evidencias/2026-09-20-integracoes`: `iphone-antes-notificacao.json`, `iphone-processos-antes-toque.log`, `iphone-depois-notificacao.json`, `iphone-notificacao-app-fechado.png`, `falhas-iphone-antes.log` e `falhas-iphone-depois.log`. A imagem salva mostra apenas a leitura no app, nao notificacoes pessoais.

Alcance: uma abertura a frio controlada, com aparelho desbloqueado. Nao certifica ainda notificacao espelhada no Watch, entrega com aparelho bloqueado, reinicio, troca de fuso ou toda a matriz de notificacoes.

## Apple Watch

O cadastro e o perfil de desenvolvimento criados em 19/09 permanecem validos. A consulta de 20/09 retornou estado `disconnected`, pareamento `paired`, Modo Desenvolvedor habilitado e ultima conexao registrada em 19/09, 11h23. A consulta terminou com aviso de informacoes incompletas: codigo de saida zero nao e prova de conexao funcional.

A tentativa de captura foi recusada por falha de conexao Bluetooth/RemotePairing. Nao foi alterado ou apagado o pareamento para contornar o problema. Necessario reconectar o iPhone companheiro ao Mac e manter o Watch acordado/desbloqueado para retomar leitura visivel, notificacoes e sincronizacao.

Na retomada, a lista de dispositivos mostrou `available (paired)`, mas a comunicacao efetiva continuou falhando. A tentativa de abertura retornou aplicativo nao instalado (LaunchServices -10814); a consulta posterior dos apps expirou, portanto nao foi possivel confirmar independentemente esse estado. Tentada instalacao do app de desenvolvimento ja assinado, sem desinstalar: falha de conexao/tunel RemotePairing 1001. A assinatura local passou na verificacao, mas nao houve instalacao bem-sucedida nesta retomada. Logs: `watch-abertura-nova-tentativa.log`, `watch-apps-retomada.log`, `watch-reinstalacao.log`. Nenhum perfil ou certificado foi modificado nesta rodada.

## Acessibilidade

A suite completa do estado final anterior executou seis casos no simulador iPhone 17 / iOS 26.5: leitura aprovada; Home, busca, configuracoes, colecoes e dossie reprovados por contraste. Zero filtros ou supressoes de problemas. Log: `evidencias/2026-09-20-integracoes/acessibilidade-inicial.log`; descricoes e capturas em `a11y-inicial`.

O relatorio da Apple identifica os elementos, mas nao informa uma relacao numerica de contraste nos anexos. As imagens isoladas nao permitem descartar os problemas. Uma coleta auxiliar `simctl diagnose` foi encerrada somente apos os seis testes terminarem, preservando o resultado reprovado.

Tres comparacoes focadas em Colecoes mantiveram o mesmo alerta no subtitulo: fundo-base explicito com a cor existente do tema, aplicacao da mesma cor por `foregroundColor` e uso da cor principal (branca no tema escuro). A ultima captura confirma o texto branco sobre o fundo escuro, mas nao demonstra que todos os alertas sejam falsos positivos. As tres tentativas foram retiradas; nenhuma mudanca experimental de cor/fundo ficou no codigo. Logs: `a11y-fundo-explicito.log`, `a11y-cor-texto-explicita.log`, `a11y-contraste-principal.log`; capturas da ultima comparacao em `a11y-contraste-principal`.

Apos retirar as tentativas, o build final e dois testes de regressao passaram, zero falhas, 56,83 segundos: auditoria completa da tela de leitura e abertura de resultados de busca apos leitura diaria/retorno a Home, repetida em tres ciclos. Log `regressao-final.log`. Isso preserva as correcoes de navegacao sem afirmar que os cinco alertas de outras telas foram corrigidos. Nao houve nova instalacao no aparelho fisico: nele permaneceu a compilacao validada na abertura a frio.

## Retomada: isolamento e correcoes de contraste

Controles temporarios, somente Debug/simulador, compararam a mesma frase e fonte. SwiftUI Text e UILabel sobre preto solido passaram. SwiftUI Text sobre o gradiente do tema falhou, inclusive quando o gradiente foi desenhado por CAGradientLayer. SwiftUI Text sobre a primeira cor solida do tema passou; UILabel transparente sobre o gradiente tambem passou. Logs: `a11y-controles-isolados.log`, `a11y-controle-gradiente.log`, `a11y-controle-gradiente-nativo.log`, `a11y-controle-isolamento-final.log`.

Uma ponte UILabel temporaria removeu o alerta de dois subtitulos, mas o auditor passou a apontar outros elementos (texto vazio de busca e botao desativado de dossie). Houve ainda uma espera expirada na navegacao de Colecoes nessa tentativa. Na rodada final, a navegacao de Colecoes voltou a passar e o alerta de contraste permaneceu. A ponte e todas as telas/classes de diagnostico foram retiradas; nao ha contorno da ativacao adicional nem filtros de auditoria no produto. Esses experimentos indicam interferencia da representacao SwiftUI/gradiente na deteccao, mas nao autorizam descartar os cinco alertas como falsos positivos.

Tambem foram encontradas falhas de cor independentes desses alertas e corrigidas nas duas plataformas:

- iOS: contadores e numeros em preto sobre destaque preto no sepia foram trocados por fundo claro proprio para indicadores, com texto preto. A mesma regra cobre busca, indice, colecoes e trilhas. Indicadores de leitura concluida e selecao de exportacao usam verde especifico para cada tema; o texto de selecao usa a cor principal.
- Android: o destaque usado como texto pequeno no claro/sepia foi escurecido, e os estados de sucesso receberam verdes adequados ao fundo. A mensagem de confirmacao usa fundo claro de indicador com texto preto. Nao foram alterados os textos das obras, PDFs ou os fundos principais dos temas.
- Busca/dossie: os textos de orientacao dos campos agora usam a cor secundaria explicita em ambas as plataformas. No Android, os filtros de area passaram de texto preto sem fundo selecionado para FilterChip com estado acessivel de selecao e fundo de destaque legivel; o teste verifica selecionar Breviarios e retornar a Todo acervo em cada tema.
- Testes de luminancia sRGB exigem contraste minimo 4,5:1 nos papeis de texto avaliados, nas extremidades dos fundos, paineis e indicadores. No iOS, tambem e avaliada uma superficie de selecao translucida. Eles nao abrangem todos os controles nativos, estados desativados, efeitos de rolagem ou toda a acessibilidade.

Referencia de metodo: [W3C, Understanding Contrast (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). O criterio usa as cores nominais; amostras de pixels suavizados de letras nao substituem essa medicao.

## Resultados da retomada

- iOS: 38 testes unitarios executados, 37 aprovados, 1 ignorado explicitamente por falta de credencial/opt-in Gemini, zero falhas. Inclui a verificacao local do catalogo com 314 pacotes no simulador. Log `ios-paleta-validada.log`.
- Android: 22 testes unitarios, zero falhas/erros/ignorados; APK Debug compilado. Log `android-paleta-validada.log`. Esse build nao foi publicado.
- Interface iOS: rodada de 10 testes com 4 aprovados e 6 falhas. Cinco sao os alertas de contraste ja descritos. A sexta era um seletor incorreto do novo teste: buscava `Voltar` na busca, enquanto essa tela possui retorno `Mais`. O teste foi corrigido para tocar no botao real da barra, verificar Recursos avancados e retornar por Inicio. Reteste aprovado nos tres temas, 46,496 segundos. Portanto, o estado dos 10 casos distintos e 5 aprovados e 5 pendentes; nao e uma suite integralmente aprovada. Logs `ios-ui-temas-final.log` e `ios-ui-temas-retorno.log`.
- Capturas da busca nos tres temas em `ui-tres-temas/manifest.json`; claro e sepia conferidos visualmente, sem corte lateral e com contador preto legivel. A captura nao certifica fontes ampliadas, VoiceOver nem todos os estados da tela.
- As mudancas de contraste desta retomada foram testadas no simulador. O iPhone pessoal continua com a compilacao anterior validada no teste de notificacao a frio.

### Verificacao visual e fortalecimento dos testes Android

A primeira suite de navegacao retornou 10 aprovados (`android-ui-temas-final.log`), mas a coleta visual posterior revelou um dialogo `System UI isn't responding` cobrindo o app. O evento `am_anr` registra `com.android.systemui` com falha ao concluir a inicializacao as 18h35, nao o processo da Biblioteca (`android-anr-eventos.log`). Isso invalida usar apenas aquele resultado como comprovacao visual. As capturas originais foram preservadas como `android-busca-*-anr.png`.

O teste foi fortalecido: agora exige que a janela nativa ativa pertenca ao app no inicio/final de cada caso e antes de registrar as imagens, alem das assercoes Compose. O controle com o dialogo presente falhou como esperado na preparacao e encerramento do mesmo caso (`android-janela-controle.log`). Apos tocar em Aguardar no proprio emulador, sem apagar dados, a repeticao dos 10 casos passou (`android-ui-janela-final.log`).

Depois da correcao adicional dos campos/filtros, a compilacao e os 22 testes unitarios passaram novamente (`android-busca-contraste-build.log`). A suite final reforcada passou nos 10 casos, 74,205 segundos (`android-busca-navegacao-final.log`). Capturas finais em `android-busca-escuro.png`, `android-busca-claro.png` e `android-busca-sepia.png`, sem o dialogo sobreposto. Escuro e sepia conferidos visualmente: filtro selecionado visivel e campo legivel. Isso nao substitui uma auditoria completa TalkBack, controles desativados, barras do sistema ou fontes ampliadas. O emulador criado para a rodada foi encerrado normalmente.

### Ultima verificacao iOS

Apos explicitar as cores dos campos, a rodada de tres casos executou busca nos tres temas com sucesso (56,983 segundos), dossie reprovado por contraste e uma falha ao abrir a busca em cinco segundos no caso de auditoria. A hierarquia capturada ainda mostrava Home selecionada. Esse ultimo resultado e uma ocorrencia intermitente de navegacao/teste ainda sem causa confirmada; nao foi escondido aumentando o prazo ou repetindo o toque automaticamente. Log `ios-busca-contraste-final.log`, capturas e hierarquia em `ui-busca-contraste-final`.

As imagens finais dos tres temas mostram o texto de orientacao da busca com a cor secundaria corrigida. Permanecem os cinco casos de auditoria completa nao aprovados e a investigacao da ocorrencia intermitente. Nao foi declarada paridade visual completa, nem estabilidade irrestrita.

Repeticao isolada, depois de encerrar o emulador Android: a busca abriu nas tres tentativas; cada uma chegou ao auditor e falhou somente por contraste. Nao houve novo timeout de navegacao nessa repeticao (`ios-busca-repeticao-isolada.log`). Sao tres auditorias reprovadas, nao tres testes integralmente aprovados. O resultado nao comprova a causa nem encerra a ocorrencia intermitente anterior.

## Contrato entre plataformas

Verificacao estrutural repetida: zero falhas e zero alertas, versao 1.0.15 e conteudo compartilhado identico. Log `paridade-estrutural.log`. O teste do bloqueio de liberacao retornou a falha esperada por auditoria funcional pendente (`bloqueio-liberacao.log`). Nenhum criterio foi relaxado e nenhuma lacuna funcional foi retirada do contrato.

Na retomada, a mesma verificacao estrutural passou (`paridade-pos-contraste.log`) e o bloqueio de liberacao voltou a falhar pelo motivo esperado (`bloqueio-pos-contraste.log`). Cadastros, licencas e versoes de distribuicao nao foram alterados.

Verificacao estrutural final, apos as correcoes de campos/filtros e o fortalecimento dos testes: zero falhas e zero alertas (`paridade-final-retomada.log`). O estado funcional continua `pending`, com todas as lacunas comuns anteriores preservadas.

## Pendencias mantidas

- Diagnosticar/corrigir contraste e concluir VoiceOver/TalkBack, tres temas, fontes grandes e rolagem integral. Auditoria automatizada de uma tela nao substitui toda a navegacao acessivel.
- Watch e Wear: notificacao real, abertura pela acao e sincronizacao offline/reconexao. Cadastro, assinatura e instalacao nao equivalem a validacao funcional.
- Restauracao real em nuvem, em contas e destinos descartaveis de teste, incluindo conflitos e obras locais. Nao usar a instalacao pessoal como teste destrutivo.
- IA com credencial valida destinada a testes, incluindo fundamentacao, recusa, quota e falhas de rede. Nenhuma chave antiga da conversa foi reutilizada.
- Demais lacunas do contrato de paridade e do relatorio de 19/09 continuam abertas. O sucesso no iPhone nao aprova automaticamente Android, Wear ou sincronizacao entre plataformas.
