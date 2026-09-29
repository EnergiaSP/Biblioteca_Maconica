# Fase 8: confianca nas fontes e qualidade do texto (parte sem os PDFs originais)

Periodo: 28 e 29/09/2026. Branch `fase8/fontes-ocr`. Refazer o OCR das obras piores depende dos PDFs originais e fica para quando eles estiverem disponiveis.

## 1. Camada de texto duplicada (acervo v4)

Problema encontrado: em cerca de 40 mil paginas de 160 obras, cada linha aparecia duas vezes seguidas. Os PDFs tinham duas camadas de texto (a original e a do OCR) e a importacao guardou as duas; as copias diferem em detalhes ("Ia"/"la", aspas retas e curvas, "SenHor"/"SENHOR") e as vezes a linha vinha repetida em si mesma. Em algumas obras a segunda camada tem as letras espacadas ("o u p erd ê-lo e m m a us").

Consequencias: a busca contava as ocorrencias em dobro nessas paginas (e as favorecia na ordem), o dossie e o texto enviado a IA repetiam trechos, e a leitura ficava cansativa.

Correcao (`Tools/remover_texto_duplicado.py`), sem inventar texto:

- pares de linhas seguidas iguais ou quase iguais (90% de semelhanca, os mesmos numeros; linhas curtas so podem diferir em pontuacao), linhas formadas por duas metades iguais e a camada de letras espacadas (as mesmas letras sem os espacos);
- a pagina so e alterada quando as repeticoes cobrem ao menos metade das linhas: repeticoes isoladas (refroes, tabelas) ficam;
- de cada par fica a versao que contem as palavras da outra (nada se perde quando as camadas quebram a linha em pontos diferentes); se nenhuma contem a outra, a de menos defeitos: palavras suspeitas pela regra de qualidade, ligaduras tipograficas, letras separadas por kerning ("M açonaria"), palavras raras no acervo;
- paragrafos e indice de busca sao refeitos a partir das linhas mantidas;
- depois, uma nova passada da correcao de palavras partidas junta as hifenizacoes trazidas pela camada mantida ("Gran- de Loja").

Verificacao (`Tools/verificar_texto_duplicado.py`, v3 contra v4):

| Verificacao | Resultado |
| --- | --- |
| Paginas corrigidas | 40.224 de 69.884 |
| Linhas repetidas removidas | 1.115.252; todas com equivalente mantida na mesma pagina (0 sem equivalente) |
| Integridade SQLite e FTS5 dos 315 pacotes | 0 erros |
| Buscas: "escada de jacó", "grande loja", "acácia", "maçonaria", "pedra bruta", "hiram" | Mesmas paginas da v3; ocorrencias sem o dobro (ex.: "maçonaria" 24.557 para 17.594 em 9.534 paginas) |
| Tamanho do acervo | 1,0 GB para 853 MB |

Durante a revisao foram corrigidos na propria ferramenta: a escolha da versao "SenHor"/aspas retas no lugar da original; a versao separada por kerning ("M açonaria": palavras que so ficavam separadas cairam de 1.473 para 496, medidas na geracao anterior da v4 com a mesma regra); uma frase legitima com metades parecidas ("Psallite Deo nostro, psallite: psallite Regi nostro, psallite.") que a comparacao sem espacos cortava; e o corte de linhas repetidas coladas sem espaco ("...Lojas.com a localizacao..."), que podia levar uma palavra da emenda.

A nova passada de palavras partidas sobre a v4 fez 290 correcoes (`Paridade/palavras_quebradas_acervo_v4.json`) e 2 no Breviario de Rizzardo ("espiritu alidade", "asso ciados").

## 2. Qualidade do texto (regra comum)

Regra `Paridade/qualidade_texto_v1.json`, referencia `Tools/qualidade_referencia.py` e 65 casos (`Paridade/casos_qualidade_v1.json`) reproduzidos igualmente por iOS (`Services/QualidadeTexto.swift`) e Android (`data/TextQuality.kt`). Cada palavra e normal ou suspeita (escrita inesperada, digito entre letras, simbolo, letra solta, caixa embaralhada, sem vogal); a pagina e legivel, com ruido (8% ou mais de palavras suspeitas) ou ilegivel (20% ou mais).

Calibrada no acervo real: numeros de versiculo e de nota colados a palavra ("15ele", "gnoses116"), grego e hebraico legitimos, enderecos e abreviacoes maconicas antigas (".*.", ".-.") deixaram de contar como ruido.

Acervo v4: 66.422 paginas avaliadas, 522 com ruido e 596 ilegiveis. Obras: 291 com texto bom, 21 regulares e 9 com muito ruido (entre elas Voltaire, Dicionario Filosofico, com a fonte do PDF corrompida; Regulador do REAA de 1858; Maconaria Revelada; Boletim do GOB de 1890). Relatorio: `Paridade/qualidade_acervo_v1.json`.

Uso nos apps (iOS e Android):

- Leitura: pagina do acervo com ruido ou ilegivel mostra "Esta página tem ruído de digitalização. Confira o trecho no original." ou "O texto desta página saiu com muitos erros de digitalização. Confira no original.". Leituras dos breviarios (texto curado) nao sao avaliadas.
- Dossie: frase com ruido nao e citada como afirmacao (definicao, resumo, divergencia, pergunta) e as metricas informam quantas foram desconsideradas. Referencia e casos do dossie atualizados; no dossie real "Escada de Jacó" as duas plataformas descartaram as mesmas 3 frases.
- Acervo: cada pacote mostra "Texto bom", "Texto com algum ruído" ou "Texto com muito ruído", calculado da contagem gravada no catalogo (`Tools/avaliar_qualidade_acervo.py`).
- Contrato de paridade: regra e casos como fontes identicas nas duas plataformas; capacidade `text_quality_notice`.

## Paridade sobre o acervo v4

Acervo v4 instalado no simulador do iPhone e no emulador Android (sem apagar as obras importadas pelo usuario no emulador). Evidencias locais em `Paridade/evidencias/2026-09-29-v4`:

| Comparacao | Resultado |
| --- | --- |
| Colecoes (`comparar_estudos_acervo.py`), 16 regras, 69.711 paginas | 0 diferencas |
| Busca (`comparar_busca_acervo.py`): "escada de jacó" 71, "grande loja" 120, "maçonaria" 120, "ética virtude" 75 | 0 diferencas |
| Dossie "Escada de Jacó" (`comparar_dossie_acervo.py`), 13 secoes, 77 fontes | 0 diferencas |
| iOS unitarios | 82, 0 falhas |
| Android `DataIntegrityTest`, `TextQualityTest`, `FullCatalogBenchmarkTest` | 40, 1 e 3, 0 falhas |
| iOS interface (iPhone 17, simulador) | 34 de 34 (1 opcional ignorado), inclusive o novo `testOfflineCollectionShowsTextQuality` |
| Android `NavigationFlowTest` | 20 de 20, inclusive o novo `acervoShowsTextQualityOfEachWork` |
| Gate `Tools/verificar_paridade.sh` | 0 falhas |

Rotulo no Acervo: pacote de uma obra mostra o nivel dela; pacote com varias obras nomeia so as que tem ruido ("Texto com muito ruído: Voltaire Dicionário Filosófico..."), para que um dicionario ruim nao marque os outros cinco do mesmo pacote. Os testes procuram o "Boletim GOB 1890".

## Publicacao da v4

Publicada em 29/09/2026 com `BibliotecaMaconica_Dev/Tools/publicar_rag_r2_wrangler.sh` em `biblioteca-maconica/rag/v4`: 315 pacotes, cada um conferido pela URL publica (ETag = MD5) e o manifest por ultimo. Conferencia independente: manifest com 315 pacotes e `baseURL` v4; amostra baixada com o SHA-256 do catalogo; v3 continua publicada, e v1 e v2 tambem, para as versoes do app ja instaladas.

## Pendente

- Refazer o OCR das 9 obras com muito ruido e das 21 regulares: depende dos PDFs originais.
- Cerca de 500 palavras continuam so separadas por kerning ("M açonaria"), em paginas onde a versao original tambem tinha o defeito (medido na geracao anterior da v4).
