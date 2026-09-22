# Auditoria comparativa de 18/09/2026

## Conclusão

**Paridade estrutural confirmada; paridade funcional total não confirmada. Não é uma autorização de publicação.**

Escopo: projeto iOS `BibliotecaMaconica_Dev` e Android `projetos/BreviarioMaconicoAndroid`, versão 1.0.15. A versão preservada 1.0.14 e os registros das lojas não foram alterados. Nenhum upload foi realizado.

Esta rodada encontrou defeitos que haviam passado pela compilação e pelos verificadores anteriores. A presença de nomes de funcionalidades nos arquivos não comprova equivalência. Este relatório substitui as conclusões anteriores de paridade integral.

## Falhas corrigidas

| Prioridade | Falha e efeito | Correção e evidência |
|---|---|---|
| P1 | Android usava SQLite do sistema, sem FTS5. Busca e importação podiam falhar em execução. | Reproduzido `no such module: fts5` no Android 16. Adotado AndroidX SQLite Bundled 2.6.2 em um adaptador pequeno, usado tanto pelo catálogo como pelo importador. Testes reais de FTS, arquivo persistido, leitura somente e OCR passaram após a correção. |
| P1 | Dados legados por data podiam vazar para outra obra com a mesma data no Android. | Comentários, reflexões, edições, favoritos, lidos e destaques legados agora pertencem somente ao breviário original. Testada migração sem perda do original e isolamento da segunda obra. |
| P1 | Exceções ao consultar busca, dossiê e abrir obra Android podiam encerrar o aplicativo. | Consultas executadas fora da interface retornam falha recuperável; cancelamento de navegação é preservado. Tratamento estendido ao índice geral com opção de tentar novamente. |
| P1 | Download Android apagava a obra antiga antes de uma renomeação cujo resultado era ignorado. | Arquivo temporário exclusivo, limite de tamanho, checksum, tempos máximos de conexão/leitura e substituição atômica. Teste confirmou que download incompleto não remove a versão instalada. |
| P2 | Exportação PDF Android trabalhava na linha da interface e usava nomes fixos. | Renderização em segundo plano vinculada à Activity, proteção contra toques repetidos, tratamento de falha e nomes exclusivos. O layout PDF ainda possui diferenças descritas abaixo. |
| P2 | Edição iOS perdia a referência `paginaMidia`. | Preservado vínculo com a imagem original ao editar. Teste de regressão passou. |
| P2 | Consultas Android com hífen, aspas e operadores podiam gerar sintaxe FTS inválida. | Tokenização literal compatível com a regra iOS. Testadas aspas, pontuação, acentos e palavras que coincidem com operadores. |
| P2 | Passo SQLite iOS podia retornar dados parciais silenciosamente ao encontrar erro. | Agora só aceita conclusão `SQLITE_DONE`, propagando erro de execução. Consultas reais e filtro de obra testados. |
| P2 | Barra de leitura Android excedia a largura disponível. | Mantido botão voltar; demais ferramentas em faixa rolável horizontal. Teste abre edição a partir dos controles finais e volta à Home. |
| P2 | Bypass destinado a testes podia ser acionado na distribuição. | Argumento iOS limitado a DEBUG; extra Android limitado a aplicativo debuggable. Não foi alterado o mecanismo de ativação solicitado pelo proprietário. |
| P2 | Backup iOS podia criar nova versão sem mudança e republicar conteúdo recebido da nuvem. | Comparação de conteúdo elimina gravações redundantes; recebimento preserva timestamp remoto e dados exclusivos do aparelho no arquivo local. O cache só registra a gravação remota recebida após sucesso local. Teste da regra de comparação passou. Sincronização real entre contas/aparelhos continua pendente. |
| P2 | Datas inválidas eram transformadas em rótulos incompletos no Android. | Datas fora da faixa e referências de página são preservadas. Testes equivalentes iOS/Android passaram. |
| P2 | Um endereço de fonte oficial sem texto recuperado era considerado base documental pelo modelo iOS. | Contexto só considera trechos ou notas não vazios. Teste com URL sem documento passou; isso não substitui validação factual da resposta da IA. |
| P2 | Gate anterior declarava paridade funcional baseado em verificações textuais. | Mensagem corrigida, pendências registradas no contrato e opção `--release` bloqueada enquanto a auditoria funcional não for encerrada. |

Resíduos: removida definição iOS não utilizada do breviário Rizzardo. O bloqueio de importação dessa obra continua nos dois catálogos; outras obras do autor e o conteúdo compartilhado não foram removidos. Não houve limpeza destrutiva de arquivos históricos, PDFs ou dados pessoais.

## Testes desta rodada

| Camada | Resultado |
|---|---|
| XCTest iOS | 17 testes, zero falhas. Navegação, ativação, datas, parágrafos, notas, persistência, edição com imagem, SQLite, contexto documental e PDF. |
| Testes unitários Android | 17 testes, zero falhas. Regras de navegação, ativação, formatação, métricas e tratamento de falhas/cancelamento. O isolamento por obra é exercitado na suíte em dispositivo abaixo. |
| Android 16 emulado | 14 testes, zero falhas: 8 fluxos de interface e 6 de integridade. Inclui importação de PDF de uma página, reconhecimento de texto e nota 578, imagem local, indexação e busca. |
| Navegação iPhone 17 / iOS 26.5 | 7 testes, zero falhas. Ida/volta de leitura e configurações, abas, busca, alternância repetida e segundo plano. |
| Navegação iPad Air 11 / iPadOS 26.5 | Os mesmos 7 fluxos passaram, zero falhas. O seletor dos testes foi adaptado à barra flutuante nativa do iPad, sem modificar a interface do app. |
| Compilação Release iOS, widget e watchOS | Bem-sucedida após o último ajuste de backup, para destino iOS físico genérico, sem assinatura. Não substitui validação de provisionamento, Archive ou envio às lojas. Dois avisos de metadados AppIntents sem dependência correspondente, sem erro de compilação. |
| Compilação de distribuição Android e Wear OS | Compilação final bem-sucedida; sem publicação. Inclui o último ajuste do tratamento de índice. APK Android passou também pela verificação de alinhamento de 16 KB; segmentos arm64 das bibliotecas SQLite, ML Kit e Graphics Path conferidos. |
| Lint Android | Zero erros e 19 avisos. Avisos majoritariamente de dependências mais novas, recurso por versão de API e ícone duplicado. Não foram suprimidos para simular ausência de dívida técnica. |
| Validador estrutural | Zero falhas. Conteúdos compartilhados idênticos e versões 1.0.15 alinhadas. |
| Gate `--release` | Bloqueia corretamente enquanto houver diferenças funcionais. Falha esperada, não erro do build. |

Os testes de PDF iOS extraem texto do documento gerado, verificando final da leitura, rodapé, mês por extenso e início do comentário em página posterior. Não constituem comparação visual integral de todos os PDFs.

A primeira execução no iPad detectou seletores que só reconheciam a barra inferior do iPhone. Após ajuste, o resultado oficial XCTest confirmou 7/7. Uma tentativa restrita também não conseguiu acessar o serviço de simuladores; não foi contada como falha do produto. O resumo oficial está em `Paridade/evidencias/2026-09-18/ipad-ui-resumo.json`.

O XCUITest do iPad registrou seis avisos internos de inversão de prioridade entre threads, sem reprovar os fluxos. A origem ainda não foi atribuída ao app ou à infraestrutura de automação. A análise de desempenho com Instruments em aparelho físico permanece necessária; não se declara ausência de avisos de execução.

## Comparação funcional e pendências

| Área | Comparação e trabalho restante |
|---|---|
| Conteúdo comum | `breviario.json` e `rag_catalogo.json` são idênticos. 365 leituras; catálogo bruto declara 315 pacotes/321 obras. Contagem não significa que todos os pacotes foram baixados ou reprocessados nesta auditoria. Rizzardo permanece filtrado na oferta efetiva. |
| Busca estruturada | iOS oferece escopo por obra, área e app, complementando o RAG com conteúdo integrado. Android expõe área/acervo baixado; o parâmetro de obra existe na camada de dados, mas não tem a mesma seleção na tela. A ordenação Android também precisa ser equiparada ao ranking usado no iOS. |
| Índices | Android usa frequência de palavras e limite de 2.500 parágrafos por pacote; isso não equivale ao índice editorial/remissivo e pode omitir o final de obras longas. Uniformizar sem varrer o acervo inteiro na interface. |
| Leitura em tela cheia | iOS abre apresentação dedicada. No Android, o estado atual modifica espaçamento interno, sem retirar toda a navegação. Não são equivalentes. |
| Marcadores | Android possui entrada manual de trecho; iOS possui integração com seleção/apresentação do texto. Exigem critérios comuns para seleção, destaque, posição e exportação. |
| Exportação textual | iOS possui conversão específica de chamadas de rodapé para sobrescrito. Android compartilha o corpo textual sem essa mesma transformação. Não confundir números comuns com notas. |
| PDF | Android possui títulos/sumário desenhados em linha única, podendo ultrapassar a margem em títulos longos. Notas e ornamentação também precisam de comparação visual com o iOS. A exportação semanal Android usa as primeiras sete leituras, não um intervalo ancorado na data selecionada. |
| Coleções e trilhas | Há recursos nos dois sistemas, mas catálogos de temas, critérios de associação e limites de resultados diferem. Android contém trilhas e grupos fixos. Necessária especificação comum versionada dos estudos. |
| Importação local OCR | Teste Android de uma página passou. Ainda há heurística de rodapé em 82% da altura quando não encontra linha e imagem JPEG com qualidade 82; o original PDF não é preservado pelo mesmo fluxo. Não se pode afirmar fidelidade integral, sem perdas, entre importadores ou em todos os documentos. |
| Memória e acervo completo | Leitores carregam listas de páginas; Android ainda prepara conteúdo integrado na inicialização e normaliza dados repetidamente em alguns filtros. Faltam medições de memória, travamento prolongado e latência com todo o catálogo, especialmente em dispositivos modestos. |
| Backup e reinstalação | iCloud e Auto Backup não são sincronização entre plataformas. Android inclui preferências, não os arquivos locais de obras importadas; iOS usa snapshots e ainda realiza parte da gravação na linha principal. Testes de conflito, exclusão, conta indisponível e restauração após reinstalação são obrigatórios em aparelhos próprios de teste. |
| IA e RAG | Há recuperação textual FTS; não foi encontrada implementação de embeddings/busca vetorial nos módulos executáveis auditados. Prompts restritivos não garantem ausência de invenções. Fontes cadastradas pelo usuário não têm comprovação automática de oficialidade. Exigir trechos verificáveis, rastreabilidade de citações e avaliações de recusa; uma URL sozinha não basta. |
| Relógios, widgets e notificações | Módulos nativos presentes. Compilar não comprova sincronização, entrega em segundo plano ou abertura a frio a partir do widget. Faltam ensaios em iPhone/Watch e Android/Wear pareados, incluindo permissões negadas e economia de bateria. |
| Acessibilidade e adaptação | Testes atuais cobrem navegação e a faixa de controles Android. Falta matriz completa de fontes ampliadas, paisagem, leitor de tela, tablets Android e dispositivos antigos. |
| Modularização e resíduos | A divisão em serviços e controladores melhorou, mas ainda há arquivos com responsabilidades amplas: `ExportComponents.swift` (728 linhas), `LibraryComponents.swift` (687), `HomeView.swift` (647) e `ExportSupport.kt` (534). Tamanho não prova defeito ou lentidão; a extração de regras testáveis e a análise de uso continuam necessárias. Os limites de linhas do validador não certificam modularização completa nem ausência de código morto. |

## Ordem para encerrar a paridade

1. Uniformizar escopos/resultados de busca, cobertura dos índices e regras das trilhas com casos comuns versionados.
2. Equiparar tela cheia, seleção de destaques, intervalos de exportação, notas sobrescritas e layout PDF, com comparação visual.
3. Padronizar importação fiel, preservando original, posições, imagens e notas; testar PDFs complexos, grandes e corrompidos.
4. Validar backup/restauração e conflitos em aparelhos e contas de teste; não prometer recuperação garantida por apenas habilitar o backup.
5. Medir acervo completo e inicialização; reduzir carregamentos repetidos, paginar consultas e mover I/O restante para fora da interface.
6. Testar widgets, relógios, notificações, acessibilidade e IA real. Aprovar apenas após todos os casos críticos, sem divergências comuns abertas.

Mudanças futuras podem ser feitas no mesmo ciclo de trabalho nas duas plataformas, mas são duas bases nativas distintas. Não há propagação automática de uma alteração Swift para Kotlin. O contrato deve exigir duas implementações e duas validações, não apenas a mesma versão numérica.

## Evidências e reprodução

- `Tools/verificar_paridade.sh`: conteúdo, versões e estrutura.
- `Tools/verificar_paridade.sh --release`: bloqueio de liberação com diferenças abertas.
- `BibliotecaMaconica_Dev/Tests/BreviarioMaconicoXXITests.swift`: testes iOS.
- `BibliotecaMaconica_Dev/UITests/BibliotecaMaconicaUITests.swift`: fluxos de interface iOS.
- `projetos/BreviarioMaconicoAndroid/app/src/androidTest`: testes Android em dispositivo.
- `projetos/BreviarioMaconicoAndroid/app/src/test`: testes unitários Android.
- `BibliotecaMaconica_Dev/DerivedDataDeepAudit/Logs/Test`: resultados XCTest.
- `BibliotecaMaconica_Dev/DerivedDataDeepAuditUI/Logs/Test`: resultados XCUITest.
- `projetos/BreviarioMaconicoAndroid/app/build/reports`: testes e lint.
- `Paridade/evidencias/2026-09-18`: cópias dos registros desta rodada, incluindo reprodução original da falha FTS5 e execução posterior corrigida.

O motor AndroidX foi escolhido a partir da [documentação oficial do SQLite AndroidX](https://developer.android.com/jetpack/androidx/releases/sqlite) e do [BundledSQLiteDriver](https://developer.android.com/reference/kotlin/androidx/sqlite/driver/bundled/BundledSQLiteDriver). A falta de FTS5 no motor do sistema foi comprovada no teste anterior à correção, não inferida somente da documentação.

Limites: não foram enviados pedidos reais de IA nem credenciais a serviços, não foram auditadas visualmente todas as páginas do acervo e não foram reinstalados aplicativos em aparelhos pessoais. O iPhone físico foi consultado e estava indisponível. Não se declara ausência absoluta de falhas, nem prontidão irrestrita para produção.
