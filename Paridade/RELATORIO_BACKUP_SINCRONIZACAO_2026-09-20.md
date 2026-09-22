# Backup, sincronizacao e regressao - 20/09/2026

## Escopo e criterio de conclusao

Trabalho restrito a Biblioteca em desenvolvimento, versao 1.0.15, e seu equivalente Android. Nenhuma publicacao, remocao de app pessoal, alteracao da versao de producao 1.0.14 ou importacao do breviario Rizzardo nesta rodada. Os resultados anteriores permanecem em `RELATORIO_INTEGRACOES_2026-09-20.md`; este documento atualiza os pontos abaixo sem transformar validacoes parciais em aprovacao integral.

Evidencias: `Paridade/evidencias/2026-09-20-integracoes`.

## Implementado

### Progresso entre telefone e relogio

- Um registro por obra e data; fila local persistente para edicoes feitas sem conexao. A confirmacao de uma entrega antiga nao remove uma edicao mais nova.
- Eventos repetidos ou anteriores sao rejeitados. Empates usam identificador deterministico. Mensagens legadas continuam aceitas quando nao substituem uma versao posterior.
- iOS/watchOS usam transferencia de informacoes em segundo plano e mensagem imediata quando disponivel. Android/Wear usam um DataItem por obra/data e mensagem imediata como complemento.
- Android e Wear compilam o mesmo modulo de transporte; iOS e Watch compilam a mesma implementacao Swift. Os dois motores consomem os mesmos nove casos versionados de `fixtures/progress_sync_v1.tsv`, incluindo versao negativa e limite de inteiro. A validacao ocorre na entrada e tambem no motor interno.
- Watch e Wear exibem as notas de rodape disponiveis no snapshot e atualizam a leitura ao retornar ao primeiro plano. Wear observa alteracoes de progresso recebidas.

Limites: a compilacao e os testes de ordenacao nao comprovam entrega real apos perda de conexao. A regra e ultima versao por timestamp com desempate, nao garantia sob qualquer desvio de relogio. O App Group nao transmite arquivos do iPhone para o Watch; a distribuicao de snapshots de multiplas obras entre aparelhos ainda requer validacao/fechamento proprio.

### Backup iOS

- Envelope v3 com versao por registro e marcadores de exclusao; favoritos e lidos sao combinados por membro, preservando alteracoes independentes.
- Migracao de backups legados, preservacao de campos de versoes futuras e rejeicao de envelope v3 incompleto ou de versao futura.
- Busca do container, coordenacao de arquivos e gravacao executadas em filas de trabalho. Captura novas edicoes locais antes de aplicar um retorno da nuvem.
- Guarda copia local anterior a uma restauracao e isola backup local ilegivel antes de substitui-lo. Nao sobrescreve backup remoto cuja versao/formato nao consegue ler.
- O limite preventivo de KVS considera os outros valores ja presentes, inclusive o backup v2 preservado. Conteudo maior depende do arquivo iCloud.

Limites: conflitos no mesmo comentario usam ultima versao, nao fusao do texto; historico local ainda nao possui tela de recuperacao nem politica de retencao. A carga local inicial ainda le um arquivo de forma sincrona. Importacoes PDF/imagens nao estao garantidas por esse backup de preferencias. Conta, quota, troca de usuario, reinstalacao e entrega real do iCloud continuam pendentes de teste descartavel. Nao se promete recuperacao garantida.

### Contraste e interface

- Fundos de leitura/app usam a primeira cor ja existente do tema em superficie solida. Paletas, textos das obras e PDF nao foram substituidos.
- Botoes desativados de Busca/Dossie receberam cores explicitas para continuar legiveis, sem permitir a acao quando faltam dados.
- Android agora fornece o tema Material correspondente aos controles e ajusta os icones das barras do sistema para claro/sepia ou escuro.
- A conferencia visual identificou titulo e engrenagem duplicados na Home Android. O cabecalho geral foi retirado somente da Home, que ja possui seu proprio cabecalho; o titulo agora divide a largura com a engrenagem. O teste exige uma unica ocorrencia de ambos.
- Cinco auditorias completas iOS passaram isoladamente: Busca, Dossie, Colecoes, Configuracoes e Leitura. Home ainda acusa contraste em conteudo proximo ao menu inferior. As tentativas de espaco fixo, remover efeito de borda e carregamento lazy nao resolveram e foram retiradas.

Nenhum alerta foi filtrado e nenhum teste de acessibilidade foi desativado. Estes resultados nao certificam VoiceOver/TalkBack nem toda a matriz de tamanhos/temas.

## Resultados desta rodada

- iOS: 47 testes executados; 46 aprovados, 1 ignorado por falta de credencial/opt-in Gemini, zero falhas. Repetido apos a validacao de versoes invalidas: `ios-unit-versoes-invalidas.log`.
- Android: 27 testes unitarios aprovados e builds Debug de app, instrumentacao e Wear aprovados. Verificacao final apos ajuste do cabecalho: `android-home-unica-build.log`.
- Regressao completa de interface iOS: 18 casos, 17 aprovados e 1 reprovado por contraste na Home; 340,868 segundos. `ios-ui-final-backup-sync.log`. Busca nos tres temas, voltar, retorno do segundo plano, abas rapidas, tela cheia e teste de notificacao passaram. A ocorrencia intermitente anterior da busca nao se repetiu; a causa anterior ainda nao foi comprovada. Capturas finais em `ui-final-backup-sync`.
- Acervo iOS no simulador: 314 pacotes; buscas medidas em 3.719 ms, 1.677 ms e 496 ms; indice da maior obra (2.678 paginas) em 58 ms. `medicao-acervo-ios-final.json`. Nao sao medidas de aparelho fisico nem garantia de busca instantanea.
- Restauracao Android pelo transporte local do sistema: aprovadas criacao e verificacao dos dados de teste, com desinstalacao/reinstalacao apenas no emulador `emulator-5554` (hardware `ranchu`). O log registra `restoreAtInstall` e `Restore complete`; nao foi executado comando manual de restauracao nem copiado arquivo de backup de volta. Comentario, reflexao, lido, favorito, texto editado, nota, tema e fonte foram recuperados; a leitura da chave ficticia retornou vazia. Evidencias `android-backup-*.log`. Isso nao equivale a restauracao Google em nuvem. O backup do emulador foi devolvido ao estado desativado original, com transporte e opcoes temporarias restaurados.
- Verificacao reforcada da restauracao passou novamente: exige ausencia do payload criptografado em `secure_secrets`, nao apenas falha ao decifrar uma chave restaurada. `android-backup-verificacao-reforcada.log`.
- A primeira regressao Android apos reinstalacao foi invalidada por dialogo `System UI isn't responding`. Eventos identificam falhas na inicializacao de `com.android.systemui` e `com.google.android.gms.persistent`, nao da Biblioteca; captura preservada em `android-pos-restauracao-tela.png`. As protecoes do teste detectaram a janela externa; nao foram retiradas. Apos tocar em Aguardar e confirmar a janela normal, a rodada final terminou em 52,132 segundos: 28 casos informados pelo runner, 27 aprovados (10 de navegacao e 17 de integridade) e 1 ignorado por falta de opt-in/credencial Gemini. `android-regressao-final-backup-sync.log`. Capturas finais dos tres temas em `android-final-*.png`; escuro e sepia conferidos sem dialogo sobreposto, sem corte lateral e com icones das barras do sistema legiveis.
- Watch fisico: listado como pareado, mas consulta efetiva expirou apos 15 segundos. `watch-conexao-final.log`. Nenhum pareamento, certificado ou perfil foi alterado nesta rodada.

## Bloqueios e pendencias

1. Concluir Home e acessibilidade integral com fontes ampliadas, leitor de tela e matriz de aparelhos.
2. Restauracao em contas/destinos descartaveis reais iCloud/Google, incluindo conflitos, exclusoes e documentos locais. Solicitado destino de teste; nao usar a instalacao pessoal como teste destrutivo.
3. Gemini com chave exclusiva de teste inserida no armazenamento seguro e autorizacao para chamadas. Nenhuma chave exposta no historico foi utilizada. Testes locais de citacoes nao certificam fundamentacao de respostas reais.
4. Watch/Wear: instalacao/conexao funcional, notificacao com abertura a frio, leitura e progresso offline/reconexao em ambas as direcoes.
5. Desempenho do acervo completo em aparelhos fisicos e as demais lacunas comuns preservadas no contrato: busca/indices, trilhas/colecoes, destaques/tela cheia, exportacoes e PDFs complexos.

O contrato distingue compatibilidade estrutural de equivalencia funcional. `functionalAudit.status` permanece `pending`; os dez bloqueios comuns nao foram removidos. A liberacao continua bloqueada.

Verificacao de encerramento: estrutura sem falhas ou alertas, conteudo compartilhado identico e versao 1.0.15 nas duas plataformas (`paridade-encerramento.log`). O modo de liberacao retorna falha esperada por auditoria funcional pendente (`bloqueio-encerramento.log`). Isso nao substitui os testes pendentes. Nenhuma nova instalacao foi feita no iPhone/Watch pessoal nesta rodada.
