# Fase 3: dossie de estudo sem IA

Periodo: 27/09/2026. Desenvolvimento iOS/Android 1.0.15. A Fase 2 (regenerar e republicar os pacotes) permanece pendente por decisao do responsavel.

## Principio

Tudo que o dossie apresenta e extraido dos textos do acervo, sempre com a fonte (obra e pagina ou data). Nao ha geracao de texto. A IA continua opcional e posterior, recebendo apenas as fontes selecionadas.

## Arquitetura de confiabilidade

1. `Paridade/estudo_dossie_v1.json`: regras comuns (limites, variantes de grafia, palavras vazias, verbos de definicao, marcadores de contraste, revisao, nomes das areas). Sincronizado para os dois apps por `Tools/sincronizar_regras_estudo.py`.
2. `Tools/dossie_referencia.py`: implementacao de referencia que define exatamente o resultado e gera `Paridade/casos_dossie_v1.json` (casos de teste com o resultado esperado, inclusive o texto exibido). O gate `verificar_paridade.sh` confere que os casos estao atualizados.
3. Motores nativos que reproduzem a referencia: iOS `Services/DossieEstudoAnalise.swift`, Android `data/DossierAnalysis.kt`. Tokenizacao por ponto de codigo Unicode (letras e digitos, NFC), mesma limpeza, mesmas ordenacoes e mesmos textos.

## O que o dossie entrega

- Definicao (frases de dicionarios com verbo de definicao), resumo extrativo (ate 6 frases, uma por obra), pontos a comparar (frases com contraste: "erroneamente", "porém", "contudo"...).
- Metricas (fontes, obras, ocorrencias, areas, fontes duplicadas desconsideradas), obras centrais e capitulos dedicados ao tema.
- Termos associados (janela de 40 palavras em torno do tema, sem palavras vazias nem verbos de definicao), exibidos na forma escrita mais frequente ("maçom").
- Perguntas de lacuna tiradas das frases do resumo, com resposta e fonte.
- Roteiro montado com as fontes (definicao, fonte central, breviarios, aprofundamento, comparacao, sintese) e revisao com datas (hoje, 1, 3, 7 e 21 dias).
- Limpeza do OCR: espacos, repeticoes imediatas de 1 a 20 palavras e ruido antes da primeira palavra da frase. Fontes com texto repetido de outra obra (mesmo livro importado duas vezes) sao desconsideradas.
- Variantes de grafia (Jacó/Jacob, Hiram/Hirão, Salomão/Salomon) na busca do dossie, que trata o tema como expressao. A Busca comum nao muda.
- O dossie analisa ate 300 fontes e exibe as 30 primeiras; texto compartilhado e PDF incluem as secoes novas nas duas plataformas.

## Evidencias

| Verificacao | Resultado |
| --- | --- |
| Casos de referencia (iOS `testDossierAnalysisMatchesReferenceCases`, Android `dossierAnalysisMatchesReferenceCases`) | Aprovados; os dois apps reproduzem o resultado e o texto exibido |
| Acervo real, "Escada de Jacó" na area de livros (`Tools/comparar_dossie_acervo.py`) | 12 secoes identicas entre iOS e Android; 69 fontes analisadas em 34 obras, 8 duplicadas desconsideradas; analise em 0,69 s (iOS) e 0,46 s (Android) |
| iOS unitarios | 75, 0 falhas |
| Android unitarios e instrumentados (`DataIntegrityTest` + `NavigationFlowTest`) | 34 e 52, 0 falhas |
| Interface: dossie mostra a analise (iOS `testDossierShowsTheAnalysisExtractedFromSources`, Android `dossierInvalidatesPreviousSourcesWhenTopicOrScopeChanges`) | Aprovados |

## Limitacoes conhecidas

- Titulos de capitulo colados ao texto pelo OCR ainda aparecem em algumas frases ("INSTRUÇÃO ESCADA DE JACÓ VM Degrau é definido..."); a Fase 2 (texto limpo e titulos detectados nos pacotes) resolve.
- O resumo e extrativo: pode reunir afirmacoes que divergem entre autores. Por isso cada frase traz a fonte e os pontos a comparar sao destacados.

## Pendente na Fase 3

- Dossies salvos (reabrir, excluir).
- Lembretes da revisao espacada pelo servico de notificacoes.
- Mapa desenhado (hoje apresentado como lista de relacoes com contagens).
