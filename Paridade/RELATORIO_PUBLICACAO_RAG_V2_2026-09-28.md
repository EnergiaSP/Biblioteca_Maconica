# Publicacao do acervo RAG v2 (texto corrigido)

Periodo: 27 e 28/09/2026. Desenvolvimento iOS/Android 1.0.15.

## O que foi publicado

- Bucket `biblioteca-maconica`, prefixo `rag/v2`: 315 pacotes (1.082 MB) com as 54.214 correcoes de palavras partidas (`RELATORIO_PALAVRAS_QUEBRADAS_2026-09-27.md`) e o `manifest.json`.
- Base: os pacotes publicados em `rag/v1`, conferidos antes (315 de 315 identicos ao catalogo v1).
- `rag/v1` continua publicado e intacto: as versoes ja instaladas do app conferem o SHA-256 do catalogo embutido e continuam baixando a v1 sem erro.
- Envio: `BibliotecaMaconica_Dev/Tools/publicar_rag_r2_wrangler.sh`, com o login do wrangler. Cada pacote foi conferido pela URL publica (ETag = MD5) e o manifest foi enviado por ultimo. Conferencia independente depois do envio: amostra da v2 com SHA-256 correto, manifest com 315 pacotes e `baseURL` v2, v1 com o SHA original.

## Atualizacao nos apps

- O catalogo embutido nos dois apps aponta para `rag/v2`.
- Pacote instalado de catalogo anterior aparece como "Atualizacao disponivel", com botao de atualizar; "baixar todas" (Android, por area) e "Baixar todo o acervo" (iOS) tambem atualizam. Regra comum: `<pacote>.sha256` gravado ao instalar; registro ausente ou diferente do catalogo = desatualizado.
- iOS baixa em arquivo temporario e so substitui depois de validar tamanho e SHA-256, como o Android.
- Android: chips de area com identificador (`acervo.area.<area>`) e texto legivel quando selecionado (antes, preto sobre fundo escuro).

## Validacao ponta a ponta

Simulador iOS e emulador Android preparados como usuario com a v1 instalada (315 pacotes, sem registro de versao) e atualizados pela propria interface:

| Verificacao | iOS | Android |
| --- | --- | --- |
| Teste de interface de atualizacao (opcional, baixa o acervo inteiro) | `testOutdatedPackagesAreUpdatedFromOfflineCollection`: aprovado, 243 s | `AcervoUpdateFlowTest`: aprovado, 137 s |
| Pacotes instalados identicos a v2 (SHA-256) | 314 de 314 visiveis | 314 de 314 visiveis |

O pacote `rag_breviario_maconico_rizzardo_da_camino` fica oculto nos dois apps (o breviario de Rizzardo e integrado pelo JSON ja corrigido), por isso nao e baixado.

Para rodar os testes de atualizacao: iOS `TEST_RUNNER_ATUALIZAR_ACERVO=1 xcodebuild test ... -only-testing:BibliotecaMaconicaUITests/BibliotecaMaconicaUITests/testOutdatedPackagesAreUpdatedFromOfflineCollection`; Android `am instrument -e atualizarAcervo true -e class com.renatocamargo.breviariomaconico.AcervoUpdateFlowTest ...`.

## Paridade sobre o texto corrigido

Relatorios gravados pelos testes das duas plataformas com o acervo v2 (pasta local `Paridade/evidencias/2026-09-28-v2`, ignorada pelo git):

| Comparacao | Resultado |
| --- | --- |
| Colecoes (`comparar_estudos_acervo.py`), 16 regras, 69.711 paginas | 0 diferencas |
| Busca (`comparar_busca_acervo.py`): "escada de jacó" 71, "grande loja" 120, maçonaria 120, ética virtude 75 | 0 diferencas |
| Dossie "Escada de Jacó" (`comparar_dossie_acervo.py`), 12 secoes | 0 diferencas; 77 fontes (eram 69 com o texto partido) |
| iOS unitarios | 77, 0 falhas |
| Android `DataIntegrityTest`, `FullCatalogBenchmarkTest`, `NavigationFlowTest` | 37, 3 e 17, 0 falhas |
| Gate `Tools/verificar_paridade.sh` | 0 falhas |

## Pendente

- Os usuarios recebem a v2 quando a proxima versao do app (com o catalogo v2) for publicada nas lojas.
- Validacao em aparelho fisico (Fase 6).
