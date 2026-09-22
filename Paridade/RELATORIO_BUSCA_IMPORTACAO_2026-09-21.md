# Auditoria comparativa: busca, leitura, sincronizacao e exportacao

Data: 21/09/2026. Desenvolvimento iOS/Android 1.0.15.

## Escopo e conclusao

Esta rodada continua a auditoria de dossies e indices. Nao declara equivalencia operacional integral, nao publica aplicativos e nao modifica a versao preservada 1.0.14. O contrato continua bloqueando a liberacao enquanto existirem casos criticos pendentes.

## Correcoes implementadas

1. **Indice obsoleto na reimportacao iOS:** a substituicao de uma obra remove os registros FTS anteriores na mesma transacao. Uma migracao reconstrui apenas o indice derivado do banco local existente, uma unica vez. Pacotes baixados continuam somente leitura. Falhas de abertura/configuracao fecham a conexao corretamente.
2. **Busca em notas nas duas plataformas:** termos que aparecem somente nas notas passam a ser recuperados por FTS5, com obra, area, pagina original e identidade propria. O cache auxiliar e reconstruivel, fica fora do backup e nao altera o PDF nem o pacote original. A invalidacao considera tamanho, modificacao, identidade do arquivo e WAL. Notas e paragrafos sao ordenados juntos antes da paginacao.
3. **Falhas de busca no iOS:** erros de pacote/consulta/notas deixam de virar resultados vazios silenciosos. Busca e dossie apresentam erro; cancelamentos nao publicam resultados de consultas abandonadas. Android ja propagava essas falhas.
4. **Carregamento das colecoes Android:** a interface deixa de aguardar a leitura de todo o acervo. Publica primeiro as regras e referencias disponiveis e atualiza por obra, com progresso explicito e cancelamento. Mapas/listas publicados sao copias, evitando mutacao concorrente da interface. Isso nao significa que toda a analise do acervo terminou quando a primeira tela aparece.
5. **Indice remissivo Android:** consulta global e por area das referencias editoriais disponiveis, alem da consulta por obra. Referencias preservam a obra e a data; areas sem indice retornam ausencia explicita. Nao sao fabricados indices para livros que nao possuem metadados editoriais importados.
6. **Identificacao de obras:** novos cadastros recebem identificadores unicos e nomes internos limitados. Duas obras homonimas nao devem substituir uma a outra acidentalmente. Titulos completos e identificadores antigos persistidos permanecem intactos.
7. **Historico de reflexoes Android:** o titulo da obra deixa de ser sempre o do breviario integrado; passa a respeitar o mapa de obras, com fallback para a propria leitura.
8. **Executor de regressao Android:** compila app e testes juntos, instala ambos somente em emulador, registra SHA-256 e reprova em caso de falha/crash do runner, mesmo quando o comando devolve codigo zero.
9. **Atualizacoes encadeadas de progresso:** a sincronizacao iPhone/Watch e Android/Wear persiste a versao recebida antes de notificar observadores, fora do bloqueio do estado. No iOS, um observador que envia nova alteracao podia bloquear ao tentar adquirir novamente NSLock; no Android, a gravacao do estado anterior podia sobrescrever a alteracao criada pelo observador. Foram adicionados testes equivalentes de recepcao seguida de nova marcacao. Isso valida a regra local, nao a entrega real entre aparelhos.
10. **Destaques por pagina no iOS:** o leitor continuo deixava todas as paginas usarem os marcadores da leitura inicialmente aberta e seu painel de salvamento. Cada bloco agora carrega seus proprios marcadores, recebe atualizacoes filtradas por obra/referencia e oferece a acao nativa `Destacar`, inclusive em tela cheia. A busca visual de trechos passa a ser literal, como no Android, sem destacar variantes de acento/caixa que nao foram selecionadas. Acoes atrasadas de uma visualizacao desmontada sao descartadas. O painel manual permanece vinculado a pagina selecionada.
11. **Imagens originais na leitura iOS:** a tela cheia passa a oferecer o mesmo acesso a pagina original do leitor normal. A expansao deixa de ser global: cada pagina possui seu proprio estado, evitando abrir/carregar todas as imagens ao expandir uma. O carregamento limpa a imagem anterior e nao publica o resultado de uma tarefa cancelada ao trocar de URL.
12. **Autoria e cabecalho dos livros iOS:** leituras de outras obras deixam de exibir o cabecalho fixo do breviario; livros sem autor cadastrado nao recebem automaticamente o autor do breviario ao decodificar registros ou exibir a leitura. O comportamento legado da obra original foi preservado.
13. **Recursos e analise estatica Android:** as referencias das constantes de justificacao foram alinhadas as anotacoes atuais do SDK. Isso corrige quatro erros do verificador, nao comprova que havia falha visual em execucao. O icone de abertura usa um alias da imagem identica (1.103.804 bytes de copia eliminada), os icones adaptativos estao na pasta base compativel com o minimo API 26 e as dimensoes de celulas do widget foram isoladas em `xml-v31`. A compilacao Release de Android e Wear e o lint terminaram sem erros. Nao houve upload.
14. **Posicao inicial da leitura continua iOS:** o leitor normal e a tela cheia passam a iniciar no item escolhido, preservando todas as paginas seguintes e suas notas. Antes, o helper retornava a obra desde a primeira pagina, diferentemente do Android. A regra foi isolada e testada com entradas fora de ordem, outra obra com a mesma referencia, pagina inicial e selecao ausente do lote.
15. **Introducao repetida no iOS:** a captura do teste real mostrou o resumo repetido em negrito antes do texto integral. A regra antiga so escondia prefixos repetidos maiores que 320 caracteres. Agora prefixos redundantes tambem sao ocultados quando curtos. O corpo original permanece intacto, citacoes distintas continuam aparecendo e o resumo da Home mantem sua regra anterior. Os registros do recurso compartilhado nao foram editados.
16. **Area de toque da leitura diaria:** uma repeticao do teste de tela cheia ficou na Home depois do toque, sem encerramento do app. A caixa passou a declarar sua superficie retangular inteira como area clicavel. A regressao verifica centro, borda esquerda e direita, com retorno a Home entre as tentativas. Os tres toques e o teste independente de destaque em tela cheia passaram. Isso elimina a dependencia dos espacos internos do rotulo; uma unica repeticao nao certifica todos os cenarios de navegacao.
17. **Autoria documental em exportacao/IA:** o fallback legado do autor foi limitado a obra original tambem na copia, exportacao de texto, preparo de contexto para IA, editor e snapshot. PDFs sem autor documental nao recebem autor inventado nos metadados; exportacoes com varios autores preservam a lista sem repeticao. O cabecalho original do breviario permanece igual. Livros sem autoria cadastrada permanecem sem autoria; documentos ja exportados nao foram reescritos.

## Testes direcionados apos as correcoes

A pedido do usuario, os casos ja aprovados nao foram auditados novamente sem necessidade. A continuacao concentrou-se nos novos defeitos e nos fluxos afetados.

| Caso | Resultado | Evidencia |
| --- | --- | --- |
| iOS sincronizacao/regras antes dos ultimos ajustes de leitura | 55 casos, 1 Gemini ignorado, zero falhas | `ios-sync-regression.log` |
| iOS autoria e selecao de destaques por pagina | 3 novos testes aprovados, zero falhas | `ios-reading-targeted.log` |
| iOS inicio da leitura continua | 1 teste aprovado, zero falhas | `ios-continuous-start.log` |
| iOS introducao sem repeticao e resumo da Home preservado | 1 teste aprovado, verificando todas as leituras integradas e uma citacao distinta | `ios-reading-intro-final.log` |
| iOS acao nativa de destacar, confirmacao visivel e acessibilidade da leitura | 2 testes reais de interface aprovados, zero falhas | `ios-highlight-ui-final.log`, `ios-highlight-final-attachments` |
| iOS caixa diaria e captura final do leitor corrigido | 2 testes de interface aprovados; centro e bordas clicaveis, texto sem introducao duplicada, destaque e confirmacao visivel | `ios-reading-card-final.log`, `ios-reading-corrected-attachments` |
| iOS autoria em compartilhamento, contexto IA, texto exportado e metadados PDF | 1 teste aprovado, cobrindo autor ausente, vazio, espacos, documentado, original legado e varios autores | `ios-documentary-authorship.log` |
| Android sincronizacao, destaques, PDF e leitura/tela cheia | 7 testes direcionados aprovados, zero falhas, 20,469 s | `android-targeted/instrumentation.log` |
| Android testes unitarios ao compilar os binarios correspondentes | 31 aprovados | `android-targeted/build.log` e XML do Gradle |
| Android/Wear Release + lint | Compilacao aprovada, zero erros; 11 avisos no app e 4 no Wear na execucao registrada | `android-release-lint-corrected.log` |
| iOS Release apos todas as correcoes de leitura/autoria | Compilacao aprovada, sem assinatura ou publicacao; aviso de extracao AppIntents sem dependencia desse framework | `ios-release-corrected.log` |
| Contrato estrutural apos os ultimos ajustes | Zero falhas e zero alertas; conteudo, regras e casos comuns identicos | `contrato-apos-leitura.log` |

Os avisos incluem atualizacoes de dependencias, constantes numericas introduzidas em API mais recente (a inspecao do bytecode confirmou `iconst_1` na chamada de justificacao, sem carregamento da classe nova), flags de navegacao Wear e uma pasta de recursos vazia, removida posteriormente. Dependencias nao foram atualizadas indiscriminadamente durante a correcao. A primeira compilacao incremental apos mover os icones falhou por cache de recursos; a compilacao limpa passou. O tempo de 11 minutos da compilacao limpa nao e tempo de abertura do app.

## Metodo e evidencias

- Casos comuns versionados executados tambem contra notas: acentos, expressao exata, ordem, limites de palavra, pontuacao e multiplos termos.
- Testes de cache atualizado, exclusao por obra, filtro por area, 137 notas e preservacao binaria do original.
- Reimportacao repetida, simulacao de indice legado corrompido, migracao idempotente e pacote somente leitura.
- Injecao de falha no indice FTS para verificar erro, em vez de apresentar uma pesquisa incompleta como concluida.
- Identificadores para cem obras de mesmo titulo e titulos extensos.
- Navegacao real de trilhas, colecoes, indice global, dossie, leitura, configuracoes e mudanca de tema.

Evidencias desta rodada: `Paridade/evidencias/2026-09-21-auditoria-final`.

## Comparacao de todo o acervo

O teste nativo de cada plataforma percorreu **69.711 paginas**, em lotes de no maximo 100, dos **314 pacotes**. As **16 regras** (9 colecoes e 7 trilhas) produziram as mesmas referencias de obra/pagina, na mesma ordem. O comparador `Tools/comparar_estudos_acervo.py` rejeita referencias ausentes, duplicadas, invalidas, acervo parcial e ordem divergente. Cinco testes negativos/positivos do proprio comparador passaram.

Essa equivalencia e do seletor sobre o acervo de auditoria. Nao certifica todos os estados da interface, anotacoes editadas, cobertura editorial ou qualidade pedagogica. As regras continuam limitadas a 24 referencias por colecao e 18 por trilha; isso nao e uma lista exaustiva de todo o conteudo relacionado.

Mediacoes Android no emulador API 36: buscas globais em 3,892 s, 1,152 s e 0,677 s; indice da maior obra, com 2.678 paginas, em 0,482 s. A varredura de estudos levou aproximadamente 9,27 s no simulador iOS e 29,27 s no emulador Android. Esses ambientes nao sao comparaveis como aparelhos fisicos e os tempos nao representam garantias de desempenho em producao.

## Interface e acessibilidade

No iOS, os 23 casos de interface concluiram: **17 aprovados e 6 reprovados**, com **12 ocorrencias de contraste** em Home, Home apos rolagem, Colecoes, Dossie e Busca. Navegacao repetida, tela cheia, troca de temas, maior tamanho de fonte, leitura e configuracoes passaram nos casos executados. Nao foram adicionadas excecoes para suprimir falhas da auditoria.

Alguns recortes anexados pela auditoria mostram a barra inferior em vez do texto identificado, enquanto outros apontam textos secundarios. Isso exige investigacao adicional; nao prova que todas as ocorrencias sejam falsas. O contrato continua bloqueando a aprovacao integral.

Na continuacao, o executor passou a registrar elemento, rotulo, identificador, posicao e disponibilidade ao toque, sem aceitar/suprimir alertas. A falha `Toque para expandir` estava em y=827,02...842,69 numa tela de 874 pontos, sob a barra inferior; `Simbolos` estava em y=807,98...828,32, tambem sem disponibilidade ao toque. A analise de dois recortes anteriores mediu contraste entre cores dominantes de **13,465:1** (texto secundario/fundo) e **14,871:1** (numero preto/amarelo). Esses dados explicam por que nao se deve simplesmente trocar cores ou aprovar a tela com base na falha isolada. Sao evidencias limitadas a esses recortes, nao uma certificacao de todas as fontes/temas, VoiceOver ou TalkBack. Arquivos: `ios-accessibility-diagnostic.log`, `contraste-recortes.json`.

A rodada diagnostica dirigida terminou com **9 testes: 5 aprovados, 4 reprovados**. As quatro falhas foram de contraste (Home, Home apos rolagem, Colecoes e o caso isolado de contraste). Busca e Dossie passaram nessa repeticao, mas isso nao apaga suas falhas anteriores. Na Home apos rolagem, a falha apontou `Buscar na biblioteca` visivel/disponivel ao toque, portanto **nem todos os alertas podem ser atribuidos a sobreposicao pela barra inferior**. Nenhuma excecao foi adicionada ao auditor. A selecao nativa de texto em tela cheia e a auditoria da leitura passaram novamente apos mover a confirmacao de salvamento para a parte visivel da tela.

## Ocorrencias do ambiente

A primeira instrumentacao Android encontrou um aplicativo antigo instalado com testes novos. Seus resultados foram invalidados e preservados no log; nao representam regressao da compilacao atual. A repeticao com binarios correspondentes confirmou a espera de 20 segundos na tela de trilhas. O diagnostico mostrou indicador de carregamento, nao encerramento do processo.

A execucao concorrente de compiladores e simuladores pressionou a memoria do Mac de 8 GB. A primeira tentativa de interface iOS foi interrompida antes de iniciar casos, e o ambiente foi reiniciado sem apagar dados. Tempos dessa tentativa nao servem como medicao de desempenho do app.

O runtime de simulacao iOS 26.5 tambem registrou uma classe de acessibilidade Apple (`UIAccessibilityLoaderWebShared`) duplicada entre WebCore e WebKit. E um aviso do ambiente, nao evidencia de codigo duplicado do aplicativo nem prova da origem dos alertas de contraste. Nenhum framework do sistema foi removido ou modificado para contornar o aviso.

Na regressao Android com acervo completo, o exemplo "AAA Documento de teste" ficava fora dos primeiros resultados da colecao, ordenados por identificador. O teste foi corrigido para "000 Documento de teste" e passou a verificar que o exemplo precede o acervo. O limite e a ordenacao de producao foram preservados; nenhuma obra do acervo foi removida para fazer o teste passar.

## Pendencias que nao podem ser consideradas aprovadas

- Cobertura editorial/remissiva de todas as obras e filtros comuns por autor/assunto.
- Matriz completa de destaques, exportacoes e fidelidade de PDFs complexos.
- Auditorias completas de acessibilidade e avaliacao VoiceOver/TalkBack.
- Restauracao real, conflitos e troca de aparelho com conta de teste, sem apagar dados pessoais.
- Gemini real com credencial exclusiva e segura; chaves expostas no historico nao devem ser usadas.
- Fluxos completos watchOS/Wear OS/widgets/notificacoes em aparelhos e desempenho com acervo completo em dispositivos fisicos.

As correcoes e os testes desta rodada reduzem diferencas concretas. Nao eliminam por declaracao as pendencias dos relatorios anteriores. Ha pendencias de produto/cobertura e validacoes externas; nao se trata somente de fornecer uma chave de IA ou conectar um aparelho.

## Fechamento desta rodada

As 17 correcoes acima foram implementadas. Os seis novos testes unitarios direcionados de leitura/autoria no iOS passaram; a ultima execucao de interface passou em dois casos (toques em toda a caixa diaria e destaque em tela cheia). A captura final confirma ausencia da introducao duplicada e confirmacao visivel. A primeira falha de toque permanece registrada em `ios-reading-visual-final.log`; nao foi apagada nem ignorada pelo executor.

Android manteve sete casos direcionados e 31 unitarios aprovados, alem da compilacao Release de app e Wear. O iOS Release final inclui os ultimos ajustes de autoria, editor, compartilhamento e metadados. O contrato permanece `pending`, com seus dez grupos de validacao abertos: verificacao estrutural nao e declaracao de equivalencia funcional. Nenhuma publicacao, alteracao da versao preservada 1.0.14, reinstalacao destrutiva ou uso de credenciais expostas foi realizado nesta rodada.
