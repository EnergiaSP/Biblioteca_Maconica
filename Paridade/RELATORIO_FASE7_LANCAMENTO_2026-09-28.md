# Fase 7: preparacao do lancamento 1.0.16

Periodo: 28/09/2026. Branch `fase7/lancamento`. A publicacao nas lojas foi adiada pelo responsavel para depois da Fase 14; o pacote assinado (AAB) e o arquivo do iOS ficam para o fim.

## Feito

- Versao 1.0.16 em todos os alvos: iOS, widget e Apple Watch (`MARKETING_VERSION`); Android e Wear OS (`versionCode 16`).
- Verificacao automatica no GitHub (`.github/workflows/verificacao.yml`), em cada PR e na `main`: gate de paridade e, no Android, testes unitarios e compilacao do app e do Wear OS. O iOS continua verificado localmente (precisa de runner macOS com Xcode 26).
- Rascunho dos textos das lojas: `Paridade/PUBLICACAO_LOJAS.md` (atualizar com as fases seguintes antes de enviar).

## Validacao das partes que nao tinham sido validadas

### Relogios

Problema encontrado: as leituras do Breviario de Rizzardo apareciam como "Leitura indisponivel" nos dois relogios.

- Apple Watch: o pacote do relogio nao levava `breviario_rizzardo.json`; incluido nos recursos do alvo.
- Wear OS: `loadWearReading` so abria `breviario.json`; agora abre o arquivo da obra pedida.
- A auditoria profunda passou a exigir os dois breviarios nos relogios.

Conferido: pacote do Wear OS com `assets/breviario.json` e `assets/breviario_rizzardo.json`; app do relogio compilado com os dois arquivos. Nao ha emulador de Wear OS nesta maquina; a validacao do Wear OS e de compilacao e conteudo.

### Widget do Android

Validado no emulador (Android 16): o widget aparece na lista de widgets, e colocado na tela inicial mostra data, titulo e trecho do dia.

Problemas encontrados e corrigidos:

- Leitura do dia diferente do iOS. O Android ordenava os itens pelo identificador da obra, e `breviario_rizzardo...` vem antes de `breviario_seculo_xxi`; por isso o widget, a tela inicial e a notificacao de reserva mostravam Rizzardo como leitura principal, e o iOS mostra Kennyo (Seculo XXI). Agora a leitura do dia segue a ordem dos breviarios integrados, como no iOS. A ordem de `itens` (busca e colecoes) nao mudou.
- Widget em branco depois de atualizar o app: o launcher mostrava o layout inicial vazio ate a proxima atualizacao periodica (ate 30 min). O widget agora se redesenha ao receber `MY_PACKAGE_REPLACED`. Conferido reinstalando o app no emulador.
- Novo teste `WidgetRenderTest` (3 testes): o provedor e oferecido aos launchers; o widget mostra data, titulo, trecho e acao de toque nos tamanhos compacto (250x110, o padrao), medio e grande; e a leitura do dia segue a ordem do iOS.

Diferenca que permanece: o widget do iOS mostra as duas leituras do dia; o do Android, so a principal.

### iPad

Suite de interface completa no iPad (A16, iPadOS 26.5). Na primeira execucao: 11 aprovados e 21 reprovacoes. A maior parte vinha do proprio teste, escrito para o iPhone; tres eram problemas reais do app.

Problemas reais corrigidos:

- Texto da leitura sem tamanho de texto do sistema (iOS, iPhone e iPad): a leitura usava um tamanho fixo em pontos, tirado do ajuste do app, e ignorava o tamanho de texto do iOS. No Android o texto e definido em `sp` e acompanha o sistema. Agora o tamanho do app e a base e cresce com o do sistema (`UIFontMetrics`), na leitura e nos campos de texto justificado.
- Colecoes no iPad: em 3 colunas de 230 pt os titulos das leituras eram quebrados ou cortados ("PARAMEN-TOS", "A ESCRAVI-DAO"; auditoria "texto cortado"). A coluna minima passou a 320 pt: 2 colunas no iPad em retrato, 3 em paisagem, 1 no iPhone.
- Topicos das colecoes: no iOS ficavam num carrossel horizontal e os ultimos ficavam escondidos alem da borda do cartao. Agora quebram linha como no Android (`FlowRow`), e nas duas plataformas a fileira e um unico elemento de acessibilidade, "Topicos: Honra, Prudencia, ...". Contraste medido nos pixels: 8,0:1.

Ajustes no teste (auditoria de acessibilidade), sem afrouxar o que e do app:

- No iPad a barra de abas fica no topo; a area visivel era calculada como se ela estivesse embaixo.
- Os rotulos da barra de abas do sistema no iPad nao crescem com o tamanho de texto (componente da Apple; todo o conteudo do app cresce). A auditoria os relata sem elemento; e tolerado no maximo um aviso por aba, so quando a barra esta no topo.
- Todo aviso sobre um elemento identificado e medido de novo, com o elemento inteiro a vista (na tela e dentro do seu carrossel), e reprova se repetir. Elementos atras da barra, cortados pela borda ou alem da borda de um carrossel eram medidos contra outros pixels.
- Botao "Buscar" desativado (busca vazia): a auditoria acusava contraste, mas os pixels medem 9,23:1, e a WCAG 1.4.3 nao exige contraste de controles inativos. Tolerado so para elemento desativado.
- O servico de auditoria as vezes estoura o tempo (codigos -56 e 1000); uma nova tentativa e feita, e se estourar de novo os tipos de verificacao rodam um a um. O tratador de avisos ficou enxuto: cada leitura de propriedade de um elemento e uma consulta ao app e conta no tempo da auditoria.
- Colecoes no iPad: a verificacao de tamanho de texto da auditoria acusava textos que crescem normalmente (um elemento diferente a cada execucao) e estourava o tempo nessa grade. Ali ela foi substituida por medicao direta (`testCollectionTextGrowsWithTextSize`, nas duas telas): no maior tamanho o titulo do cartao e o da leitura crescem 2,5x ou mais ("A Justica": 18 para 58,5 pt) e a fileira de topicos 2x ou mais (55 para 129 pt; cabem mais chips por linha na coluna larga). No iPhone a auditoria continua com todas as verificacoes.

| Suite de interface | Resultado |
| --- | --- |
| iOS unitarios (iPhone 17, simulador) | 81 executados, 0 falhas (1 ignorado) |
| iPhone 17 (simulador) | 33 de 33 aprovados (1 opcional ignorado) |
| iPad (A16) | 32 de 33 aprovados (1 opcional ignorado). A auditoria de Colecoes passa sozinha (18,8 s, nenhum aviso); na suite completa o servico de auditoria da Apple estourou o tempo |

### Android

| Verificacao no emulador | Resultado |
| --- | --- |
| `WidgetRenderTest` | 3/3 |
| `NavigationFlowTest` | 19/19 |
| `DataIntegrityTest` | 40/40 |
| Gate `Tools/verificar_paridade.sh` | 0 falhas |

## Pendencias

- Wear OS: validado so por compilacao e conteudo (sem emulador de relogio nesta maquina).
- Widget do Android: o toque abre o app, mas no emulador o app estava na tela de ativacao; a abertura da leitura pelo toque nao foi vista (o caminho de abertura por data e obra e o mesmo da notificacao, coberto por teste).
- Capturas de tela reais para as lojas, texto final das lojas, AAB assinado e arquivo do iOS: ficam para depois da Fase 14, antes da publicacao.
