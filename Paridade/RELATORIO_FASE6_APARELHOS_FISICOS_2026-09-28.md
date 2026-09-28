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
| Suite de interface completa | 29 executados antes de o aparelho bloquear: 24 aprovados, 5 reprovados (abaixo); os 3 ultimos nao rodaram |

Reprovacoes no iPhone e o que foi feito:

- Colecoes, Inicio e Busca: avisos em elementos atras da barra de abas, mais alta no Pro Max (932 pt), inclusive de tamanho de fonte, nao so de contraste. A verificacao "trazer a vista e auditar de novo" passou a valer para qualquer tipo de aviso.
- Busca: a auditoria acusou a tecla "Buscar" do teclado do sistema, que abre no aparelho fisico (no simulador o teclado fica oculto). O teste fecha o teclado antes de auditar.
- Configuracoes: a auditoria usava a chamada direta, sem diagnostico; passou a usar o mesmo auditor dos outros testes.
- Inicio: "texto cortado" no titulo "Breviário Maçônico - Kennyo Ismail" do cartao da leitura do dia; o codigo permite quebra de linha e a captura mostra o texto inteiro. Precisa de nova execucao no aparelho com o diagnostico.
- Voltar da leitura para a Busca: reprovou no aparelho e passa no simulador; precisa de nova execucao para separar tempo de resposta de defeito.

As quatro auditorias ajustadas passam no simulador. A nova execucao no iPhone ficou pendente: o aparelho ficou indisponivel para o Xcode no meio do trabalho.

## Pendencias

- Desempenho no Android intermediario: a busca de termos muito frequentes leva cerca de 4 s porque a relevancia conta cada ocorrencia em todos os trechos encontrados. Otimizar sem mudar a ordem dos resultados (por exemplo, contagem por trecho pre-calculada no pacote, ou limite de candidatos com o mesmo criterio nas duas plataformas).
- Assinatura Android: `keystore.properties` nao esta no projeto; sem ele nao ha AAB assinado para a Play Store.
- Numero de versao: continua 1.0.15 nas duas plataformas; subir antes de enviar as lojas.
- Publicacao nas lojas: depende das contas do responsavel.
