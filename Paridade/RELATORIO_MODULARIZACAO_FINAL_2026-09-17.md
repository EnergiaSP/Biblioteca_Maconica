# Modularização final e proteção de paridade - 17/09/2026

## Objetivo

Separar responsabilidades extensas, facilitar alterações futuras e impedir que a evolução de uma plataforma deixe a outra funcionalmente diferente.

## iOS

- Home separada em apresentação, progresso de leitura, leituras recentes e ações de navegação, preferências, busca e solicitações.
- Biblioteca separada em catálogo offline, leitura, busca, referências e estudos.
- Leitura separada em apresentação justificada, editor, detalhes e navegação.
- Configurações separadas das ações de ciclo do app e do conteúdo premium.
- Importação separada em fluxo principal, índice remissivo, normalização OCR e construção de títulos/índices.
- Persistência, catálogo e busca do acervo separados do estado central do `BreviarioStore`.
- PDF separado em coordenação, layout visual e renderização de texto.

## Android

- Entrada do app, Home, leitor, configurações, estudos e exportação isolados em módulos próprios.
- Biblioteca separada em catálogo, leitor, busca, referências e IA.
- Navegação e métricas de leitura mantidas fora das telas.
- Camada de dados, OCR, catálogo e preferências preservadas como módulos independentes.

## Proteções permanentes

- O contrato automático exige todos os módulos estruturais nas duas plataformas.
- Fontes compartilhadas continuam verificadas por hash.
- Versões, backup, deep links, notificações, widget, relógios e OCR continuam auditados.
- Arquivos acima dos limites arquiteturais agora interrompem a auditoria.
- Operações inseguras e trabalho pesado na interface continuam bloqueados.

## Validação final

- iOS: 10 testes unitários, 0 falhas.
- iOS: 6 fluxos reais de interface, 0 falhas.
- Android: testes unitários e análises estáticas aprovados.
- Android: builds Debug e Release do app e Wear OS aprovados.
- Android: 6 fluxos reais de interface, 0 falhas.
- Auditoria profunda de paridade: 0 falhas e 0 alertas.
- Versão e conteúdo compartilhado permaneceram inalterados.

## Conclusão

A modularização necessária para o estado atual foi concluída. Não há módulo obrigatório pendente nem diferença funcional aberta entre iOS e Android. Novas funcionalidades ainda exigirão manutenção normal, mas o contrato e os limites automáticos passam a impedir que o código volte a se concentrar ou que a paridade seja declarada sem validação.
