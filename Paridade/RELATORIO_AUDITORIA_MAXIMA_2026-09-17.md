# Auditoria máxima de estabilidade e paridade - 17/09/2026

## Abrangência

- Navegação principal, busca, configurações, retomada do segundo plano e recriação de tela.
- Trocas rápidas e repetidas entre Home, Coleções, Dossiê, Acervo e Recursos avançados.
- Testes unitários de navegação, ativação, formatação, notas, métricas e persistência.
- Builds limpos Debug e Release, análise estática, compactação e validação dos pacotes.
- App principal, widget, watchOS e Wear OS.
- Persistência, backup, App Group, iCloud, Auto Backup, deep links e notificações.
- Busca por bloqueios da interface, operações forçadas, segredos, APIs obsoletas e resíduos.
- Comparação determinística de fontes, catálogo RAG, versão e capacidades críticas.

## Correções implantadas

- A imagem da página original no iOS deixou de ser decodificada na montagem da interface.
- A decodificação agora ocorre em tarefa utilitária, com miniatura limitada a 2048 pixels.
- Foram acrescentados testes de retomada após segundo plano e retornos repetidos entre
  Configurações e Home no iOS.
- Foram acrescentados testes equivalentes de recriação da Activity e retornos repetidos no Android.
- O contrato automático agora rejeita decodificação síncrona de imagem na tela, bloqueios explícitos
  da thread principal, operações forçadas e configurações inseguras de banco.
- O contrato passou a validar App Group e restauração iCloud no app, widget e watchOS.
- Foram removidos o cache Release temporário da auditoria, caches Python e metadados `.DS_Store`;
  fontes, bancos, PDFs, Archives e pacotes de distribuição foram preservados.

## Resultados verificados

- iOS: 10 testes unitários aprovados.
- iOS: 6 fluxos completos de interface aprovados, sem falhas.
- iOS Release: análise do target de produção aprovada.
- Android: testes unitários, Lint Debug e Lint Vital Release aprovados.
- Android: builds Debug e Release do app e do Wear OS aprovados.
- Android: 6 fluxos instrumentados de interface aprovados, sem falhas.
- Conteúdo do breviário e catálogo RAG idênticos entre as plataformas.
- Versões de produto alinhadas em 1.0.15.
- Contrato final de paridade: 0 falhas e 0 alertas.

## Observações técnicas

- A compactação Release Android completa levou cerca de 31 minutos após limpeza total. O tempo
  pertence ao R8/ML Kit no ambiente de desenvolvimento e não representa tempo de abertura do app.
- O simulador iOS avisou sobre KVS quando os testes foram executados sem assinatura. Os três
  entitlements de produção contêm o identificador KVS e o App Group esperados.
- A análise Release por esquema inclui indevidamente o target XCTest, que usa `@testable` e não é
  compilável sem `ENABLE_TESTABILITY`. A análise correta do target de produção foi aprovada.
- Arquivos-fonte extensos ainda existem, porém os controladores de navegação e métricas já estão
  separados. A modularização deve continuar de forma incremental para não criar regressões.
