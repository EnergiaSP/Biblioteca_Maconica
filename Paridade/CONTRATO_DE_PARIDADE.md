# Contrato de Paridade iOS e Android

## Regra principal

Toda funcionalidade comum da Biblioteca Maçônica deve ser implementada, testada e validada nas duas plataformas antes de ser considerada concluída.

Uma alteração não está finalizada quando:

- existe somente no iOS ou somente no Android;
- apresenta o mesmo nome, mas comportamento, conteúdo ou persistência diferentes;
- altera um arquivo compartilhado sem sincronizar sua cópia na outra plataforma;
- perde dados existentes durante atualização ou migração;
- funciona apenas em uma dimensão de tela específica.

## Fonte única de conteúdo

`breviario.json` e `rag_catalogo.json` são fontes compartilhadas e devem ser binariamente idênticas nas duas plataformas. O verificador de paridade bloqueia a validação quando houver divergência.

## Equivalência funcional

As interfaces podem seguir os padrões nativos de cada sistema, mas devem oferecer o mesmo resultado ao usuário: conteúdo integral, busca, leitura, comentários, reflexões, marcadores, IA opcional, exportação, notificações, backup e restauração.

## Diferenças nativas permitidas

- iCloud no iOS e Android Auto Backup no Android são mecanismos nativos distintos. Periodicidade, limites, conta e restauração devem ser testados separadamente; não representam sincronização entre iOS e Android.
- Apple Watch e Wear OS podem ter interfaces próprias, mas devem abrir a leitura correta, marcar como lida e apresentar o conteúdo diário.
- A importação OCR usa os motores nativos de cada plataforma. Em ambas, a obra resultante deve entrar no acervo, busca e índices, preservando páginas e imagens.
- A aparência dos controles pode ser nativa, desde que hierarquia, disponibilidade e comportamento sejam equivalentes.

## Segurança e dados

- Chaves de API nunca podem ficar em texto simples ou em backup de nuvem.
- Comentários, reflexões, favoritos, leituras concluídas, destaques, edições e configurações devem sobreviver às atualizações.
- Toda mudança de formato persistido deve incluir migração compatível com versões anteriores.

## Processo obrigatório para novas alterações

1. Atualizar o contrato quando houver uma nova capacidade comum.
2. Implementar a regra no iOS e Android no mesmo ciclo de trabalho.
3. Sincronizar e validar os arquivos compartilhados.
4. Compilar as duas plataformas.
5. Executar testes de navegação, persistência e exportação.
6. Registrar diferenças nativas justificadas.

## Limites de modularidade

- Telas iOS: no máximo 750 linhas por arquivo.
- Serviços e renderização PDF iOS: no máximo 900 linhas por arquivo.
- Interface e camada de dados Android: no máximo 600 linhas por arquivo.
- Navegação, persistência, busca, importação, renderização e apresentação devem permanecer em módulos próprios.
- O verificador automático trata a ultrapassagem desses limites como falha de paridade, não como simples aviso.
- Novas funcionalidades comuns devem nascer em módulos equivalentes nas duas plataformas e receber testes do fluxo afetado.

Para conteúdo, execute `Tools/sincronizar_recursos_compartilhados.sh`. O iOS é a origem canônica atual dos dois arquivos compartilhados e o script atualiza o Android e valida os hashes imediatamente.

## Critério de conclusão

A paridade somente é declarada quando o verificador automático passa e não existem diferenças funcionais comuns abertas.

## Estado da versão 1.0.15

A auditoria de 18/09/2026 reabriu a validação funcional. O gate estrutural verifica conteúdo compartilhado e presença de componentes, mas não prova o comportamento de backup, deep links, notificações, widgets ou OCR. Não declarar paridade total enquanto houver diferenças funcionais ou testes críticos pendentes no relatório mais recente.

A retomada de 20/09/2026 está registrada em `RELATORIO_HOME_HISTORICO_WATCH_2026-09-20.md`: histórico corrigido por obra, recuperação de páginas recentes RAG, regressão Android aprovada e pendências explícitas de acessibilidade iOS e execução no Watch físico. A liberação permanece bloqueada; o relatório diferencia testes aprovados, testes ignorados e validações não realizadas.

A rodada de 21/09/2026 está em `RELATORIO_ESTUDOS_ACESSIBILIDADE_2026-09-21.md`: inclusão de texto/notas dos livros RAG nas coleções e trilhas em ambas as plataformas, seleção limitada por lotes, caso comum versionado e medição de 69.711 páginas. Acessibilidade, nuvem, IA e relógios reais permanecem pendentes. Não houve declaração de equivalência funcional integral nem publicação.

A continuação está em `RELATORIO_COLECOES_TRILHAS_2026-09-21.md`: metadados completos de estudos no Android, identidade estável das trilhas no iOS, navegação com fonte ampliada, comparação dos PDFs e correções de permissões iCloud Documents e incorporação do Watch. Os dez bloqueios funcionais permanecem abertos; os testes ignorados, interrompidos ou sem casos executados não contam como aprovação.

Cada alteração deve registrar: requisito comum, implementação em ambas as plataformas, teste de regressão executado, resultado e limitações. Um marcador no código ou uma compilação bem-sucedida não substitui esse teste.

Diferenças visuais próprias dos sistemas permanecem permitidas. A marcação de leitura é sincronizada entre telefone e relógio por WatchConnectivity no ecossistema Apple e pelo Wearable Data Layer persistente no Android/Wear OS. Consultas pesadas de busca, índices e dossiês devem ocorrer fora da linha principal da interface nas duas plataformas.

A interface, a leitura, a busca, as configurações, o acervo, os estudos, a importação, a persistência e a geração de PDF estão modularizados. O gate automático também fiscaliza a presença dos módulos e seus limites de tamanho, reduzindo o risco de futuras alterações quebrarem a paridade.
