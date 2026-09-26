# Fase 0: regra comum de estudos e ambiente Android

Periodo: 26/09/2026. Desenvolvimento iOS/Android 1.0.15.

## Regra comum de colecoes e trilhas (itens 6 e 7 da analise)

- Correspondencia por palavra inteira, sem acento e sem diferenca de maiusculas: "lei" nao encontra "leitura", "rito" nao encontra "espirito", "luz" nao encontra "produz". Expressoes como "grande loja" exigem as palavras em sequencia.
- Ordenacao por relevancia: primeiro o numero de palavras-chave distintas encontradas, depois o total de ocorrencias; empate por obra, pagina e data. Antes, a ordem era obra/pagina, e as colecoes ficavam com as primeiras paginas da obra de menor identificador.
- Contrato: `regras_estudo_v1.json` (`matching` e `ranking`) e novos casos em `casos_comuns_v1.json` (`word_boundary`, `phrase_keyword`, `plural_is_distinct`, `punctuation_boundary` e item de relevancia na selecao).

### Motor provisorio

Nesta etapa a pontuacao le o texto de cada pagina. No acervo completo do simulador (69.711 paginas, compilacao de desenvolvimento) a selecao das 16 regras levou 75,9 s, contra cerca de 6 a 7 s da versao anterior, que interrompia a analise ao preencher cada colecao. Esse motor sera substituido na Fase 1 pela pontuacao direta no indice FTS5 (`fts5vocab`), que calcula exatamente a mesma regra; em consulta direta ao acervo pelo Mac, as 16 regras foram pontuadas por inteiro em 1,88 s. Esta etapa nao deve ser liberada sem a Fase 1.

## Ambiente Android

Instalado em `.tools/android/` (ignorado pelo git), nas versoes que `build-apk.sh` espera: Temurin 17.0.20.1+1, Gradle 8.10.2, Android SDK (plataforma 36, build-tools 35.0.0, platform-tools). Downloads verificados por checksum; licencas do SDK aceitas com autorizacao do responsavel. Sem emulador nesta etapa.

## Testes

| Execucao | Resultado |
| --- | --- |
| Android unitarios (`:app:testDebugUnitTest`) | 34 executados, 0 falhas. Inclui os 3 novos testes do historico de navegacao. Primeira execucao dos commits `ab1725c` e `d3448e5`. |
| Android instrumentados | Compilam (`:app:compileDebugAndroidTestKotlin`). Nao executados: sem emulador. |
| iOS unitarios | 67 executados, 0 falhas, incluindo selecao compartilhada e o acervo completo (75,9 s). |
| `fts5vocab` no iOS | Confirmado no SQLite do sistema (`testSystemSQLiteSupportsIndexOnlyTermCounts`). |
| `fts5vocab` no Android | SQLite embutido (`sqlite-bundled` 2.6.2) compilado com FTS5 e o modulo `fts5vocab`, verificado na biblioteca nativa arm64. Teste instrumentado `bundledSQLiteSupportsIndexOnlyTermCounts` criado; execucao depende do emulador. |
