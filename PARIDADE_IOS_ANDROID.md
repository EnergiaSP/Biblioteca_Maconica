# Paridade iOS e Android

O contrato normativo e verificável está em `Paridade/CONTRATO_DE_PARIDADE.md` e `Paridade/contrato-paridade.json`.

Execute `Tools/verificar_paridade.sh` antes de considerar uma alteração comum concluída.

Este documento registra o ponto de controle para manter a Biblioteca Maconica pareada entre iOS e Android.

## Regra de manutencao

Toda alteracao funcional nova deve ser aplicada e validada nas duas plataformas antes de ser considerada concluida.

## Modulos pareados

- Tela inicial Biblioteca Maconica com leitura diaria, busca rapida e ultimas leituras.
- Areas principais: Breviarios, Dicionarios maconicos, Judiciario maconico e Biblioteca maconica.
- Busca estruturada por termo, frase, obra, area e acervo.
- Acervo RAG com catalogo local, download individual e download de todas as obras.
- Leitura de obras em modo continuo responsivo.
- Breviarios com favoritos, nao lidos, comentarios e estatisticas por obra.
- Edicao de texto diario com restauracao do texto original.
- Marcadores/destaques da leitura, remocao e exportacao em PDF.
- Comentarios por leitura.
- Reflexao pessoal separada do comentario e historico de reflexoes.
- Trilhas de estudo estruturadas, perguntas de fixacao, mapa conceitual e revisao espacada.
- Exportacao de leitura, comentarios, dossie e marcadores.
- IA opcional com Gemini, fontes oficiais cadastradas e resposta salva em comentario quando aplicavel.
- Configuracoes de tema, leitura, voz, notificacao e chave Gemini.
- Persistencia local de dados do usuario por identificador da obra.
- Chave Gemini protegida pelo Keychain no iOS e Android Keystore no Android, fora do backup.
- Notificacoes preparadas para selecao de multiplos breviarios.
- Suporte a imagens vinculadas aos pacotes RAG quando os arquivos de midia estiverem disponiveis no aparelho.

## Equivalentes nativos concluídos

- iOS possui widget/watchOS; Android possui widget e aplicativo Wear OS com leitura diária, leitura completa e marcação de lido.
- iOS e Android possuem importação OCR local. No Android, o PDF é processado no aparelho, gera banco SQLite/FTS e preserva uma imagem fiel de cada página.

## Declaração atual

A versão 1.0.15 possui paridade funcional e nativa declarada. Não existem módulos comuns ou equivalentes nativos registrados como planejados.

## Checklist antes de publicar

- Compilar iOS em Debug e Archive.
- Compilar Android APK e AAB.
- Conferir que o catalogo RAG e os pacotes publicados sao os mesmos.
- Testar abertura de obra baixada, busca, leitura continua, PDF, IA opcional e persistencia de favoritos/comentarios/marcadores.
- Repetir qualquer ajuste de interface nas duas plataformas.
