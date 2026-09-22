# Auditoria profunda de estabilidade e paridade - 17/09/2026

## Escopo

- Navegação real por Home, Coleções, Dossiê, Acervo, Mais, Configurações e Busca.
- Troca rápida e repetida entre as cinco áreas principais.
- Testes unitários de navegação, ativação, formatação e métricas de leitura.
- Análise estática, builds de iOS, widget, watchOS, Android e Wear OS.
- Revisão de persistência, segredos, rede, operações de arquivo e banco de dados.
- Comparação funcional e estrutural entre iOS e Android.

## Correções realizadas

- A abertura de livros no Android deixou de consultar o banco na thread da interface.
- Imagens dos livros no Android agora são carregadas fora da interface e redimensionadas
  durante a decodificação, limitando o pico de memória sem alterar o arquivo original.
- Dois erros de indentação ambígua apontados pelo Android Lint foram eliminados.
- Foi acrescentado teste de estresse com três ciclos rápidos completos de navegação nas
  duas plataformas.
- O contrato automático passou a exigir os carregamentos assíncronos e os novos testes.
- Foram removidos 66 diretórios antigos de cache de compilação. Archives, PDFs, bancos,
  mídias de publicação e dados do projeto foram preservados.

## Resultado

- Xcode Analyze: aprovado.
- iOS: testes unitários aprovados.
- iOS: quatro fluxos de interface executados; o fluxo que oscilou durante tarefas pesadas
  simultâneas foi repetido isoladamente e aprovado.
- Android: testes unitários, Lint, build do app e build do Wear OS aprovados.
- Android: quatro fluxos instrumentados de interface aprovados no simulador, incluindo
  três ciclos rápidos completos entre as áreas principais.
- Contrato automático de paridade: 0 falhas e 0 alertas; conteúdo compartilhado idêntico
  e capacidades críticas presentes nas duas plataformas.
- Nenhuma chave de API em texto aberto foi encontrada no código de produção.
- Nenhum `try!`, conversão forçada ou bloqueio explícito da thread principal foi encontrado
  no código de produção iOS.

## Observações controladas

- Avisos de versões mais recentes das bibliotecas Android são informativos. Foi mantido o
  conjunto já validado para evitar uma atualização ampla e arriscada nesta auditoria.
- URLs HTTP encontradas pertencem ao conteúdo bibliográfico importado, não a endpoints
  internos usados pelo aplicativo.
- A versão 1.0.14 e os arquivos de distribuição preservados não foram alterados.
