# Auditoria comparativa: dossies, indices, notas e estudos

Data: 21/09/2026. Plataformas: iOS e Android, desenvolvimento 1.0.15.

## Decisao

**Paridade estrutural aprovada; equivalencia operacional integral ainda nao aprovada.**
As correcoes abaixo foram implementadas. Existe uma falha intermitente de carregamento das trilhas Android em execucao conjunta e continuam pendencias de cobertura e de ambiente. Nao ha fundamento para declarar todos os fluxos equivalentes ou livres de travamentos.

Nenhuma publicacao, upload, importacao do Rizzardo, troca de conta, apagamento ou reinstalacao de aplicativo pessoal foi realizada nesta rodada. A versao publicada 1.0.14 permanece preservada. Instalacoes e testes Android desta rodada ocorreram apenas no emulador.

Evidencias: `Paridade/evidencias/2026-09-21-dossie`. Este documento complementa os relatorios anteriores, nao transforma suas falhas em aprovacoes.

## Metodo

1. Inspecao dos caminhos reais de busca, hidratacao das notas, selecao de estudos, geracao de prompts, navegacao e exportacao.
2. Casos comuns versionados, executados pelos motores nativos, incluindo duas obras que compartilham pagina/data e resultados que ultrapassam os antigos limites de exibicao.
3. Comparacao diferencial de sete secoes dos planos produzidos por cada plataforma, nao apenas comparacao dos nomes de funcoes.
4. PDFs gerados pelos aplicativos com 30 fontes extensas, marcadores exclusivos no fim de cada fonte e em cada nota, e analise opcional com citacao F30.
5. Extracao dos PDFs, validacao A4, renderizacao e inspecao visual de capa, corpo e pagina final.
6. Testes de interface: mudar tema/escopo, gerar novamente, rolar ate resultados, abrir leitura de livro importado, expandir colecao, navegar trilhas e alternar abas.
7. Compilacoes Debug e Release e verificacao estrutural. O bloqueio funcional para publicacao permanece ativo.

## Falhas corrigidas

### Fontes e notas dos dossies

- iOS exportava somente parte dos resultados/trechos e mantinha caminhos distintos para texto compartilhado e PDF. Agora ambos usam a montagem integral das fontes recuperadas, sem o corte de 24 fontes, com identificadores F1...Fn, obra, referencia, titulo, texto e rodape. A analise opcional tambem e incluida.
- Android passa a preservar o rodape nos resultados de busca, no texto do dossie e nos insumos documentais da IA. O texto de uma fonte nao e reduzido ao resumo visivel do cartao.
- As notas de pacotes com multiplas obras sao consultadas por obra e pagina, impedindo a mistura de notas de livros diferentes com o mesmo numero de pagina.
- A hidratacao das notas acontece somente depois da classificacao/paginacao final. Evita carregar rodapes de todos os candidatos descartados em centenas de pacotes.
- iOS deixou de criar um arquivo PDF temporario com nome fixo. Arquivos concorrentes recebem identificadores diferentes; a tela bloqueia toques repetidos durante a geracao.
- Android preserva quebras estruturadas de titulos e notas na exportacao em vez de trata-las como quebras artificiais de OCR. As notas continuam em linhas consecutivas.

### Tema, escopo e navegacao

- Mudancas de tema, area, obra ou escopo invalidam o dossie e sua analise anterior. Consultas em andamento sao canceladas. Resultados antigos nao devem ficar associados a uma nova pergunta.
- O iOS ganhou selecao explicita de obra no escopo de obra do dossie. O Android oferece area e obra, e registra esse escopo na exportacao.
- Foram removidos cortes silenciosos de dez resultados do dossie e quatro ocorrencias remissivas no iOS. Isso nao significa que todos os livros possuem indice editorial importado.
- O indice Android da obra diaria integrada agora oferece todas as leituras/paginas e filtro sem sensibilidade a acentos. Os links preservam a obra e o rodape ao abrir a leitura.

### Planos e desempenho

- Android ganhou termos relacionados e limites da base no dossie, e alinhou roteiro, perguntas, mapa conceitual, revisao espacada e cruzamentos ao iOS.
- Os termos relacionados usam o texto completo recuperado, com desempate deterministico, em vez de depender do trecho resumido apresentado na interface.
- O plano Android foi extraido para `DossierStudyPlan.kt`; o acabamento PDF, para `DossierPdfExport.kt`. O limite estrutural de tamanho das telas continua atendido.
- Nas duas plataformas, a montagem inicial das colecoes/trilhas normaliza cada texto uma vez por carregamento, reutilizando-o nas regras. No Android a antiga implementacao repetia essa preparacao para cada colecao/trilha; o mesmo ocorria na montagem final do cache iOS.
- Testes de selecao com lotes, ordem invertida, datas iguais entre obras e normalizacao pre-calculada verificam que a otimizacao nao altera os resultados esperados.

### PDF do dossie

- Android ganhou capa especifica com tema, escopo, nome configurado, data, simbolo e folhas, aproveitando o estilo premium existente.
- Cabecalho, marca-d'agua, numeracao e rodape agora acompanham o corpo do dossie Android.
- A verificacao diferencial exige capa identificada, 30 fontes, 30 notas, analise final e as sete secoes de estudo iguais. Nao exige que o texto seja inventado ou reescrito para igualar metricas tipograficas.

## Resultados observados

| Verificacao | Resultado | Evidencia |
| --- | --- | --- |
| iOS regressao final de dados/regras | 51 casos: 50 aprovados, 1 Gemini nao executado, zero falhas; 19,907 s | `ios-studies-final.log` |
| iOS invalidacao do dossie pela interface | Aprovada, 31,273 s; seletor corrigido para o campo real | `ios-ui-dossier-retry.log` |
| iOS destinos/alternancia de abas | Dois aprovados nesta rodada | `ios-ui.log` |
| Android testes unitarios | 31 aprovados, zero falhas/ignorados | XML do Gradle e `android-optimized-build.log` |
| Android regressao conjunta inicial | 38 casos, duas falhas, um Gemini nao executado; nao aprovada | `android-regression-final.log` |
| Android apos correcoes, dados e fluxos dirigidos | 27 casos, uma falha de trilhas, um Gemini nao executado; nao aprovada como conjunto | `android-corrected-flows.log` |
| Android dossie: mudar tema, regenerar e mudar area | Aprovado na repeticao, incluindo rolagem ate resultados e invalidacao | `android-corrected-flows.log` |
| Android colecao expandida e livro importado -> pagina correta | Aprovados na repeticao | `android-corrected-flows.log` |
| Android trilhas executadas isoladamente | Aprovado, 35,375 s, sem ampliar o limite de espera de 20 s | `android-study-isolated.log` |
| Planos nativos e PDFs | Sete secoes iguais; 30 fontes/notas completas, analise e capa presentes; zero erros de conteudo na fixture | `comparacao-dossies.json` |
| Compilacao Android | Debug, testes e Release aprovados | `android-optimized-build.log`, `android-release-final.log` |
| Compilacao iOS Release | Aprovada novamente depois da ultima otimizacao de estudos | `ios-release-final.log`, `ios-release-studies-final.log` |
| Contrato estrutural | Zero falhas e zero alertas, fontes compartilhadas identicas | `structural-final.log` |
| Bloqueio de publicacao | Reprovado por pendencias funcionais, intencionalmente mantido | `release-gate-final.log` |

Um codigo de saida zero do comando de instrumentacao Android nao significa teste aprovado: o runner pode retornar zero com `FAILURES`. Os totais acima foram lidos no resultado dos testes. Os casos Gemini ignorados nao contam como aprovacao.

### Falha intermitente de trilhas

O carregamento da lista nao ficou disponivel em 20 segundos nas execucoes conjuntas. A mesma verificacao passou isoladamente. A otimizacao removeu trabalho repetido e manteve resultados, mas nao eliminou a falha conjunta. Sua causa final permanece em investigacao, e esse caso deve continuar bloqueando a aprovacao completa.

O ambiente Android apresentou anteriormente incompatibilidade de snapshot/renderizador e dialogo de System UI sem resposta. Foi reiniciado sem snapshot com renderizador suportado, sem apagar dados do app. As falhas posteriores de trilhas nao foram descartadas como simples problema do ambiente: ainda precisam de repeticao conjunta estavel e medicao de carregamento a frio.

### Comparacao visual

PDF iOS: 23 paginas. PDF Android com capa premium: 22 paginas. A diferenca de paginacao foi registrada, nao ocultada. As paginas Android 1, 4 e 22 e o corpo/final iOS foram renderizados e inspecionados. Nao foi observado corte de texto nas paginas examinadas. Permanecem diferencas de metricas de fontes, quebras, acabamento dos simbolos e hierarquia tipografica; nao declarar identidade visual integral.

Marcadores de integridade toleram somente espacos introduzidos pela extracao PDF entre glifos, nunca substituicao de letras ou numeros. A verificacao de marcadores nao substitui auditoria de todo o texto de todos os PDFs.

## Pendencias concretas que impedem concluir ambas operacionalmente

| Grupo | O que falta comprovar ou corrigir |
| --- | --- |
| Busca e indices | Cobertura global de indices editoriais/remissivos e termos exclusivos de rodapes nos pacotes FTS, alem de filtros comuns por obra/area/autor. Trazer rodapes junto do resultado nao os torna automaticamente pesquisaveis. |
| Estudos | Resolver/reproduzir a falha conjunta de carregamento das trilhas e validar colecoes/trilhas em todo o acervo nas duas plataformas. As sete secoes do dossie comparadas ja coincidem na fixture. |
| Leitura/destaques | Matriz completa de selecao, persistencia, reabertura e exportacao de destaques em ambos os leitores, com tamanhos de tela e fonte extremos. |
| Exportacoes | Comparacao visual de todos os tipos/intervalos, notas sobrescritas, limites entre paginas e comentarios. As amostras aprovadas nao fecham todo esse grupo. |
| Importacao | Auditoria de PDFs complexos e degradados do acervo, incluindo todas as imagens/posicoes/notas. Os testes sinteticos aprovados cobrem apenas casos delimitados. |
| Restauracao real | Conta e aparelho de teste para reinstalacao, sincronizacao, conflitos, troca de dispositivo e recuperacao; nao usar dados pessoais em teste destrutivo. |
| IA real | Credencial exclusiva no armazenamento seguro e autorizacao de execucao do teste. Chaves expostas no historico nao foram usadas. Avaliar apoio documental real, citacoes e ausencia de evidencia. |
| Relogios/notificacoes/widgets | Fluxos completos Apple Watch e Wear OS, reconexao, abertura a frio e notificacao em aparelhos. Teste de notificacao no emulador nao comprova entrega nos relogios. |
| Desempenho | Medicoes repetidas de carregamento a frio, memoria, busca/estudos e navegacao com acervo completo em aparelhos fisicos iOS e Android. |
| Acessibilidade | Resolver dez apontamentos de contraste das cinco auditorias iOS anteriores e executar VoiceOver/TalkBack, foco, areas de toque e matriz responsiva. Nao foram marcados como falsos positivos sem comprovacao. |

## Continuidade do contrato

Os casos de dossie foram acrescentados ao arquivo canonico e sincronizados nos dois aplicativos. O comparador `Tools/comparar_dossies_exportados.py` usa artefatos efetivamente produzidos pelos testes nativos. Alteracoes futuras nesses fluxos devem executar novamente as duas suites e o comparador.

A existencia dos mesmos modulos, versoes ou arquivos compartilhados nao certifica paridade operacional. O contrato permanece `pending` ate os casos criticos serem aprovados sem divergencias comuns abertas.
