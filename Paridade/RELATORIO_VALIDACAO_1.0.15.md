# Relatório de Validação de Paridade 1.0.15

Data: 16 de setembro de 2026

## Declaração

A Biblioteca Maçônica 1.0.15 possui paridade funcional e nativa declarada entre iOS e Android segundo o contrato `contrato-paridade.json` versão 2.

## Evidências

- `breviario.json` idêntico nas duas plataformas.
- `rag_catalogo.json` idêntico nas duas plataformas.
- Versão 1.0.15 alinhada.
- Compilação iOS com watchOS concluída.
- Compilação Android Debug concluída.
- Android App Bundle de distribuição concluído e assinado.
- Compilação Wear OS Debug concluída.
- Wear OS App Bundle de distribuição concluído e assinado com o mesmo identificador do app principal.
- Análise estática Android e Wear OS: zero erros.
- Importação OCR local Android com ML Kit, SQLite, FTS5, imagens por página e integração ao catálogo.
- Importação OCR local iOS preservada.
- watchOS e Wear OS oferecem leitura diária, leitura completa e marcação de leitura.
- Verificador `Tools/verificar_paridade.sh` aprovado.
- Auditoria profunda determinística de dados e capacidades aprovada.
- As 365 datas são únicas, válidas e possuem conteúdo obrigatório.
- Todos os vínculos de datas do índice remissivo resolvem para leituras existentes.
- Pacotes RAG possuem identificadores únicos, URL HTTPS e SHA-256 válido.
- Abertura por widget foi protegida para aplicativo encerrado e já aberto.
- Notificações Android e Wear OS são restauradas após reinicialização ou atualização.
- Backup iOS passou a abranger configurações, solicitações de obras e fontes oficiais.
- OCR Android atualiza a interface na thread correta e detecta a linha separadora de rodapé.
- Testes unitários Android cobrem ativação, parágrafos, datas e compartilhamento integral.
- Target XCTest iOS cobre ativação, data por extenso e persistência do progresso.
- Marcação de leitura sincronizada entre telefone e relógio nos dois ecossistemas.

## Diferenças permitidas

As diferenças restantes são de apresentação e APIs nativas, conforme permitido pelo contrato. As duas plataformas possuem testes nativos e também são cobertas pelo auditor multiplataforma.

## Regra para próximas versões

Uma nova alteração somente poderá ser declarada concluída depois de implementada nas duas plataformas, compilada e aprovada pelo verificador de paridade.
