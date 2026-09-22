# Estudos, desempenho e acessibilidade - 21/09/2026

## Escopo e decisao

Biblioteca de desenvolvimento 1.0.15 em iOS e Android. A versao publicada 1.0.14 foi preservada. Nao houve publicacao, upload, importacao do Rizzardo, mudanca de conta ou apagamento de aparelhos pessoais.

**Status: equivalencia funcional integral ainda pendente.** Compilacoes, testes locais e verificacao estrutural nao substituem os testes reais de nuvem, IA, relogios e acessibilidade. Os dez bloqueios comuns do contrato continuam abertos.

Evidencias: `Paridade/evidencias/2026-09-21-validacao`.

## Correcoes comuns de estudos

- iOS consultava as obras JSON e a obra aberta, deixando outras obras RAG fora das colecoes. Android recomendava livros pelo titulo/autor, mas selecionava as leituras das trilhas apenas no breviario. Ambos agora consultam tambem titulo de pagina, texto integral e notas dos livros locais do catalogo RAG.
- A leitura dos bancos ocorre em lotes de ate 100 paginas, fora da interface, com verificacao de cancelamento. As notas sao consultadas somente para as paginas do lote e isoladas por obra. Nao sao carregadas imagens para classificar temas.
- Os resultados respeitam as mesmas regras versionadas: ate 24 referencias por colecao e 18 por trilha, ordenacao por obra/pagina/referencia e deduplicacao pela chave composta. Ha nove colecoes e sete trilhas.
- A normalizacao de maiusculas/acentos e feita uma vez por lote; as palavras dos temas sao preparadas uma vez. O seletor dispensa comparacoes que nao podem modificar os primeiros resultados. No iOS, a comparacao literal sobre texto ja normalizado evita a busca generica dispendiosa identificada pelo perfil de CPU.
- Essas transformacoes sao apenas para consulta. O texto original, as notas, as imagens e os PDFs nao foram reescritos.
- Android abre a pagina encontrada no leitor de livros, em vez de encaminhar referencias Pn ao leitor diario ou abrir sempre a primeira pagina. Os resultados identificam a obra e a pagina. No iOS, as referencias RAG exibem tambem o nome da obra nas colecoes/trilhas.
- Falha na consulta de um livro RAG gera aviso, sem impedir o carregamento dos demais. Obras ainda nao baixadas nao sao tratadas como erro.
- Corrigida a identidade do historico de reflexoes iOS para obra + referencia, evitando colisao de identificadores numericos entre obras. A ordenacao de paginas ausentes considera zero antes de desempatar pela referencia, como no Android.

Esta rodada nao certifica ainda todos os fluxos de colecoes: edicoes/importacoes especificas de cada plataforma, historicos de reflexoes de todas as obras, equivalencia visual, persistencia de trilhas e a matriz de telas continuam sujeitos a validacao. A presenca de uma pagina numa colecao por palavra-chave nao e uma conclusao academica por IA.

## Testes e medidas

| Validacao | Resultado | Evidencia |
| --- | --- | --- |
| iOS dados/regras, ultima regressao | 50 casos: 49 aprovados, 1 Gemini ignorado por falta de opt-in/credencial, zero falhas | `ios-unit-regression.log` |
| Android unitarios e compilacao | 31 aprovados; APK e pacote de testes compilados, repetidos apos ampliar a area de toque | `android-build-touch.log`, XML em `app/build/test-results/testDebugUnitTest` |
| Android interface e integridade, ultima regressao | Runner informa 33 casos: 32 aprovados, 1 Gemini ignorado; zero falhas; 42,167 s | `android-ui-bounded.log` |
| Android PDF -> colecao -> pagina | Aprovado na regressao e novamente apos o ajuste de toque, 1 caso em 9,988 s | `android-ui-bounded.log` e `android-collections-touch.log` |
| iOS interface completa | 20 casos: 15 aprovados, 5 reprovados, 11 ocorrencias de contraste | `ios-ui-final.log` e `ios-ui-final-attachments` |
| iOS repeticao dirigida sem afastamento experimental | 7 casos: 2 aprovados, 5 reprovados; inclui falha de toque nas colecoes corrigida posteriormente | `ios-ui-recheck.log` |
| iOS colecoes, ultima compilacao | Maior fonte + abertura da leitura correta aprovadas; auditoria completa reprovada por contraste no titulo Simbolos | `ios-collections-final.log`, `ios-collections-final-attachments` |
| Estrutura e arquivos compartilhados | Zero falhas/alertas, fontes compartilhadas identicas | `paridade-estrutura-final.log` |

O caso comum `studySelection` foi adicionado ao arquivo versionado e sincronizado nas duas plataformas. Testa correspondencia no corpo, titulo, rodape e termos de indice; obras com a mesma data; ordem invertida; duplicatas; tamanhos de lote 1, 2, 3 e 8; limite zero e preservacao das notas. Testes de banco cobrem pagina correta, isolamento por obra, lotes pequenos e interrupcao.

O teste Android de interface cria um PDF sintetico de duas paginas, importa pelo OCR real, verifica o texto extraido, encontra a obra na colecao e confirma que a pagina 2 foi aberta. A primeira tentativa aguardava uma colecao fora da area renderizada; a obra sintetica foi ajustada para corresponder a primeira colecao, sem alterar os criterios de busca de producao. Arquivos e historico criados pelo teste sao limpos ao final.

### Acervo completo no simulador iOS

- 314 pacotes, 69.711 paginas percorridas, lote maximo de 100 paginas.
- Estudos: primeira medicao concluida em 5,885 s; repeticao final em aproximadamente 6,888 s. Todos os grupos respeitaram os limites 24/18.
- Busca `maconaria` (com acento no teste): 4,790 s, 120 resultados; frase `grande loja`: 2,050 s, 120 resultados; `etica virtude` (com acento no teste): 0,773 s, 78 resultados.
- Indice da maior obra, 2.678 paginas: aproximadamente 69,6 ms.
- Relatorios: `medicao-estudos-ios.json` e `medicao-acervo-ios.json`.

As duas primeiras medicoes de estudos foram interrompidas apos identificacao do gargalo. Nao sao testes aprovados nem uma referencia numerica final para calcular ganho percentual. Os perfis `estudos-perfil-cpu.txt` e `estudos-perfil-normalizado.txt` apontam o custo na comparacao de strings. A medicao final percorreu todas as paginas, sem omitir obras para reduzir o tempo.

Estas medidas sao de simulador em compilacao de desenvolvimento. Nao equivalem a certificacao de bateria, memoria, inicializacao ou desempenho do acervo completo em iPhone/Android fisicos. O emulador Android foi encerrado apos os testes.

## Acessibilidade e navegacao

- Botoes da Home receberam agrupamento e descricoes para leitura diaria, busca, expansao/recolhimento das areas e ultimas leituras. As acoes e o conteudo visual foram preservados.
- Busca e Dossie passaram na rodada dirigida de quatro auditorias, mas voltaram a falhar na suite completa. Home e Home apos rolagem continuam com apontamentos. Nao se deve considerar um resultado isolado como aprovacao definitiva.
- Algumas capturas de elemento mostram o menu inferior em vez do elemento de texto esperado; outras mostram texto branco sobre preto. A origem dessa divergencia ainda nao foi comprovada. Nenhum alerta foi filtrado ou teste desabilitado.
- Um experimento de afastamento de 1 ponto da barra inferior nao resolveu e foi removido. A suite completa registrada inclui esse experimento; a repeticao dirigida na compilacao final esta em `ios-ui-recheck.log`.
- Na suite completa passaram navegacao entre abas, voltas repetidas, busca -> leitura -> Home, tela cheia, ida/volta de configuracoes, temas, agendamento do teste de notificacao e auditorias de Leitura e Configuracoes. Colecoes tambem passou naquela execucao, mas o teste ainda nao aguardava as leituras carregadas. Esse resultado nao certifica o conteudo final da tela.
- O teste de Colecoes agora espera o botao de expansao antes da auditoria. Isso revelou area de toque pequena, limitacoes de fonte e um icone com descricao tecnica. Foram corrigidos o botao de expansao e as linhas de leitura (minimo 44 pontos no iOS e 48 dp no Android); datas e etiquetas usam fontes adaptativas mais legiveis; textos podem crescer verticalmente. Em tamanhos de acessibilidade, as colecoes usam uma coluna e as linhas empilham data/titulo. O icone decorativo nao e mais anunciado separadamente do titulo da colecao.
- Adicionado teste real de interface no maior tamanho de fonte: confirma aumento efetivo da altura do titulo, limites laterais, rolagem e abertura de Adonhiram em 03 de janeiro. Passou duas vezes, incluindo a ultima compilacao. A captura foi inspecionada. Esse teste nao substitui a auditoria completa ou VoiceOver manual.
- A ultima auditoria das colecoes nao repetiu os erros de toque/fonte/descricao, mas apontou contraste em Simbolos, proximo ao menu inferior. As capturas estao preservadas; nao se concluiu que o alerta e falso. O teste nao foi filtrado, desabilitado ou marcado como aprovado. A suite completa ainda precisa ser repetida depois de resolver os alertas restantes.
- O executor tambem registrou avisos internos de inversao de prioridade durante a automacao. Sua atribuicao ao app ou ao ambiente de testes exige investigacao; nao houve conclusao de ausencia de lentidao em todos os fluxos.

## Validacoes externas ainda pendentes

1. **Watch fisico:** aparece como disponivel/pareado, enquanto o iPhone aparece conectado; nova abertura expirou em 20 segundos (`watch-launch.log`/JSON). A consulta final manteve esse estado. Nao foi possivel concluir marcacao, sincronizacao, notificacao e reconexao no relogio real. Nao houve nova reinstalacao, alteracao de perfil ou despareamento nesta rodada.
2. **Nuvem real:** falta aparelho/conta de teste iCloud e Google para restauracao apos reinstalacao, conflitos e documentos. Nao foi apagada a instalacao pessoal. Testes locais de merge/backup nao comprovam recuperacao em nuvem.
3. **IA real:** falta credencial exclusiva configurada no campo seguro. A chave antiga exposta no historico nao foi usada. O teste Gemini ignorado nao conta como aprovado.
4. **Android/Wear fisicos:** nao estavam disponiveis para certificacao. Notificacoes e progresso exigem cenarios reais, incluindo offline/reconexao e abertura a frio.
5. **Acessibilidade completa e comparacao final:** faltam resolver/reproduzir os alertas iOS, VoiceOver/TalkBack, fontes extremas, aparelhos de tamanhos diferentes e a equivalencia visual das exportacoes. Continuam tambem as lacunas de indices, destaques, importacoes complexas e restauracao documentadas no contrato.

Foram solicitadas confirmacao da tela no Watch, credencial de teste no app e disponibilidade de conta/aparelho descartavel para restauracao. Sem essas condicoes, nao se declara encerramento integral nem liberacao para publicar.

## Fechamento desta rodada

As correcoes descritas foram salvas. Os processos de compilacao/testes iniciados nesta rodada foram encerrados e seus resultados registrados. O verificador estrutural passou; o verificador de liberacao permanece reprovado intencionalmente enquanto houver lacunas funcionais e validacoes externas pendentes. Nenhum aplicativo foi enviado para as lojas.
