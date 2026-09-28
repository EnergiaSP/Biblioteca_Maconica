# Fase 6 (parte 1): validacao em aparelhos fisicos

Periodo: 28/09/2026. Desenvolvimento iOS/Android 1.0.15 (branch `fase5/fluidez`).

## Aparelhos

| Plataforma | Aparelho | Situacao do app |
| --- | --- | --- |
| Android | motorola moto g84 5G, Android 15 (API 35) | Sem o app antes; instalada a versao de desenvolvimento e os testes. Nenhuma configuracao do aparelho foi alterada pelo processo ("Permanecer ativo" foi ligado pelo responsavel). |
| iOS | iPhone 15 Pro Max | Ja tinha a versao de desenvolvimento ("Privado", identificador proprio, separada do app publicado); atualizada por cima. Antes dos testes, os dados do app (backup de dados do usuario e preferencias) foram copiados para o Mac. |

## Android (moto g84)

| Verificacao | Resultado |
| --- | --- |
| `DataIntegrityTest` | 40/40 (o teste de pacote desatualizado passou a funcionar tambem sem acervo instalado) |
| `NavigationFlowTest` | 19/19 (com a tela mantida ativa; antes, a tela apagava em 60 s no meio da suite) |
| Download do acervo v3 pela tela Acervo (`AcervoUpdateFlowTest`) | Aprovado em 315 s pelo Wi-Fi; 314/314 pacotes visiveis identicos a v3 |
| `FullCatalogBenchmarkTest` com o acervo completo | 3/3 |
| Paridade com o iOS no acervo real (colecoes, 4 buscas, dossie) | 0 diferencas |

Tempos no aparelho (acervo completo, 314 pacotes):

| Operacao | moto g84 | iOS (simulador no Mac, referencia) |
| --- | --- | --- |
| Colecoes e trilhas, 16 regras sobre 69.711 paginas (primeira montagem; depois vem do cache) | 6,0 s | 0,6 s |
| Busca "maçonaria" (termo presente em quase todo o acervo) | 3,8 s | - |
| Busca "grande loja" | 1,8 s | - |
| Busca "ética virtude" | 1,7 s | - |
| Dossie "Escada de Jacó" (analise) | 1,3 s | 0,6 s |

## iOS (iPhone 15 Pro Max)

| Verificacao | Resultado |
| --- | --- |
| Testes unitarios | 81 executados, 0 falhas; 4 ignorados por dependerem do acervo instalado (o app no iPhone nao tem acervo baixado) |
| Suite de interface completa | Todos os 32 testes aprovados, somando tres execucoes (a primeira parou quando o aparelho bloqueou); detalhes abaixo |

Reprovacoes no iPhone e o que foi feito:

- Colecoes, Inicio e Busca: avisos em elementos atras da barra de abas, mais alta no Pro Max (932 pt), inclusive de tamanho de fonte, nao so de contraste. A verificacao "trazer a vista e auditar de novo" passou a valer para qualquer tipo de aviso.
- Busca: a auditoria acusou a tecla "Buscar" do teclado do sistema, que abre no aparelho fisico (no simulador o teclado fica oculto). O teste fecha o teclado antes de auditar.
- Configuracoes: a auditoria usava a chamada direta, sem diagnostico; passou a usar o mesmo auditor dos outros testes.
- Inicio: "texto cortado" no nome da obra do cartao da leitura do dia ("o texto pode ser cortado em tamanhos maiores de fonte"). Confirmado no simulador no maior tamanho de acessibilidade: a data ocupava a linha e o nome da obra ficava numa coluna estreita, uma silaba por linha. Corrigido: nos tamanhos de acessibilidade o nome da obra e a data ficam um abaixo do outro. O Android ja fazia assim (conferido no emulador com fonte 2x).
- Voltar da leitura para a Busca: passou na nova execucao no iPhone; a falha anterior era tempo de resposta do aparelho.

Segunda execucao no iPhone dos 5 testes: Busca, Configuracoes e Voltar para a Busca aprovados. Colecoes e Inicio levaram aos ajustes abaixo, feitos depois:

- A faixa opaca acima da barra de abas e maior na tela do Pro Max: a margem da area visivel passou de 16 para 32 pt; o topo (barra de status com a Dynamic Island) tambem passou a contar como area coberta.
- Quando o servico de auditoria da Apple estoura o tempo ("Audit failed to complete in time") ao repetir a verificacao de um elemento, a verificacao e repetida uma vez; qualquer aviso relatado continua reprovando.

Terceira execucao no iPhone, com os ajustes: Colecoes, Inicio e os 3 testes que nao tinham rodado na primeira vez (trilha de estudo em fonte maxima, busca por tema com retorno, comentario nao salvo ao trocar de leitura) aprovados. Somando as execucoes, todos os 32 testes de interface passam no iPhone 15 Pro Max; o 33o (atualizacao do acervo) e opcional e nao foi executado no aparelho. No simulador, a suite completa passa sem falhas (33 testes, 1 opcional ignorado).

## Desempenho da busca no Android (medido no moto g84)

Medicao por etapas da busca "maçonaria" (314 pacotes, 6.975 trechos encontrados): consulta ao indice 0,25 s, contagem de ocorrencias 0,21 s, notas 0,48 s, mas a busca completa levava 4,2 s. O gargalo era a pontuacao dos breviarios locais: a cada busca o app montava do zero um indice em memoria com as 730 leituras (cerca de 2,5 s), o mesmo problema corrigido no iOS no item 14.

- `LocalTextIndex`: o indice dos breviarios e montado uma vez (1,6 s) e reaproveitado; o app o monta em segundo plano ao abrir. Mesma consulta, mesma contagem e mesma ordem de antes.
- O processamento paralelo dos pacotes foi mantido: medido no aparelho, e mais rapido que o sequencial (2,1 s contra 2,9 s).

| Busca no moto g84 | Antes | Depois |
| --- | --- | --- |
| "maçonaria" | 3,85 s | 2,39 s |
| "grande loja" | 1,78 s | 1,87 s |
| "ética virtude" | 1,73 s | 1,47 s |

## Pendencias

- Desempenho: a busca de termos muito frequentes ainda leva cerca de 2 s num Android intermediario; o restante e consulta, contagem e notas distribuidos pelos 314 pacotes.
- Assinatura Android: `keystore.properties` nao esta no projeto; sem ele nao ha AAB assinado para a Play Store.
- Numero de versao: continua 1.0.15 nas duas plataformas; subir antes de enviar as lojas.
- Publicacao nas lojas: depende das contas do responsavel.
