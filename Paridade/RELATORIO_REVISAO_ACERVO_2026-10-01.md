# Revisão profunda do acervo

Data: 2026-10-01. Branch `revisao/acervo-profunda`.

## Obras repetidas
`Tools/remover_obras_repetidas.py` compara o texto das obras em trechos de 8 palavras.
- Uma obra com 90% ou mais do seu texto dentro de outra é cópia: o mesmo livro importado duas vezes, outra digitalização ou OCR da mesma edição, ou um trecho de uma obra completa.
- Fica a mais completa.
- Diferença de tamanho de até 3% conta como empate. No empate, fica a obra usada nas trilhas, depois a que tem autor nas referências, depois a de melhor texto.
- Obras que têm conteúdo próprio relevante continuam as duas. Exemplos: "Sinopse do Grau de Aprendiz" (82% contido) e "Mitologia para quem tem pressa" (82%).

Resultado: **25 obras removidas** em 24 grupos (lista em `obras_removidas_v1.json`).

| Acervo | Antes | Depois |
|---|---|---|
| Obras | 321 | 296 |
| Tamanho | 1,05 GB | 783 MB |

Removidas do catálogo dos dois apps. Os pacotes que já estavam no aparelho são apagados pelo próprio app ao abrir: iOS `BibliotecaOfflinePackageService.removerPacotesForaDoCatalogo`, Android `PackageCleanup.kt`, com testes iguais. As obras importadas pelo usuário nunca são tocadas.

## Download repetido
- **Como funciona:** os dois apps gravam cada pacote num caminho fixo. O arquivo novo só substitui o antigo depois de conferido o SHA-256, e a troca é atômica (iOS `replaceItemAt`, Android `rename`). A busca abre cada pacote de um único lugar.
- **Teste novo** nas duas plataformas (`testDownloadingTheSamePackageTwiceKeepsOneCopy` e `PackageDownloadTest`): baixa o mesmo pacote duas vezes e confere que continua um arquivo com seu marcador, sem sobra de download, e com as mesmas páginas e resultados de busca.
- **Importação de PDF:** o mesmo arquivo não vira uma segunda obra (SHA-256, PR #14).

## Dicionário Maçônico Completo
- **O problema:** o PDF é uma tabela "Palavra | Significado". A leitura antiga pegava a página coluna por coluna, então os termos ficavam separados das definições e cada página começava com o cabeçalho "Palavras Palavra Significado".
- **A correção:** `extrair_tabela_dicionario.swift` remonta cada verbete pela posição de cada linha na camada de texto do próprio PDF. É o texto original, sem OCR, inclusive com os erros de digitação do autor.
- **Resultado:** 1859 verbetes no formato "TERMO — significado".
- **Outros dicionários:** o Maçônico-1, o de Símbolos Esotéricos, o Cultural da Bíblia e o Breve de la Masonería já estavam em texto corrido, sem correção necessária.

## Auditoria do texto
`Tools/auditar_texto_acervo.py` (relatório `auditoria_texto_acervo_v1.json`) procura defeitos que a regra de qualidade não vê:
- linhas repetidas;
- colunas intercaladas;
- tabela lida por coluna;
- palavras partidas;
- dígitos dentro de palavras.

Ela também audita os dois breviários.

### Cópias da camada de texto
- **O problema:** 55 obras tinham partes da página com duas camadas de texto, como "Havia quatro volumes… Havia quatro volumes…".
- **A correção:** `reextrair_camada_texto.swift` relê a camada do PDF pela posição e descarta a linha desenhada duas vezes no mesmo lugar.
- **A trava:** a página só é trocada quando a cópia some e **nenhuma palavra real do texto antigo desaparece**. Só lixo de OCR pode sumir: palavras vistas menos de 3 vezes no acervo, ou número de página dobrado.
- **Resultado:** 1726 páginas trocadas, e as linhas repetidas caíram de 1225 para 55.

### OCR novo
- **O Livro Ilustrado dos Símbolos e Os Povos da Bíblia:** OCR refeito a partir do PDF.
  - No "Livro Ilustrado", textos claros sobre fundo ilustrado ainda perdem a primeira letra de algumas linhas, como "ontato" em vez de "contato". Testei resolução maior e mais contraste, sem melhora. Para ficar perfeito, só com transcrição manual.
- **O que fica sinalizado na auditoria** (12 obras) é falso alarme: mapas, diagramas, fórmulas e páginas de notas e índice, com letras soltas como "p." e "n.º".

## Breviários
- **Kennyo Ismail, corpo:** as 365 leituras estão legíveis.
- **Kennyo Ismail, rodapés:** `Tools/refazer_rodape_kennyo.py` funde, palavra por palavra, o rodapé antigo com o de um OCR novo do PDF.
  - Onde as duas versões diferem, a palavra nova só entra quando a antiga não existe no acervo e a nova existe (3 ou mais vezes).
  - Endereços de internet, números só com dígitos e palavras que só perderiam letras ficam como estavam.
  - Os números das notas são completados pela sequência ("68" depois de 367 vira "368").
  - Resultado: 88 rodapés corrigidos (por exemplo, "Enäightenment" → "Enlightenment", "Artigo e Aceito" → "Antigo e Aceito", "Frecmasomry" → "Freemasonry") e 81 mantidos. Relatório: `ocr_rodape_kennyo_v1.json`.
- **Rizzardo da Camino:** já refeito com OCR novo (`RELATORIO_OCR_2026-10-01.md`); nenhum defeito na auditoria.

## Referências ABNT
Fichas catalográficas lidas por inteiro, guardando só o que está explícito nelas.

| Das 297 obras | Antes | Agora |
|---|---|---|
| Ano | 49 | 81 |
| Editora | 41 | 95 |
| Local | 33 | 84 |

As demais obras não têm ficha no PDF.

## Relógios
- **Wear OS:** botões no dourado do app (#C8A34B) com texto preto, no lugar do roxo padrão. Os botões lado a lado não partem mais as palavras.
- **Apple Watch:** mesmo estilo.

## Publicação
- **R2:** 67 pacotes refeitos estão em `rag/v6/` e precisam ser enviados ao R2 antes de lançar o app com este catálogo (`publicar_rag_r2_wrangler.sh`).
- **Pacotes removidos:** os pacotes das 25 obras removidas continuam no R2 (`rag/v4` e `rag/v5`). Apagá-los libera espaço, mas versões antigas do app ainda podem pedi-los. Aguarda decisão.

## Segunda rodada (pendências)

### Rodapés do Breviário de Kennyo
- **Leitura do bloco de notas:** a sequência agora vem da própria página do OCR novo, ancorada no primeiro número do rodapé antigo. Aceita "*" e números truncados ("14" em 174) quando a sequência confirma.
- **OCR em 6000 px:** feito só nas páginas em que as notas não tinham sido encontradas.
- **Resultado:** 76 rodapés corrigidos ou completados, entre eles **44 notas inteiras que o rodapé antigo tinha perdido**. Exemplos: a 228 (Docetismo), a 962 (Grotto e Shriner) e a 98 de 24/01.
- **Notas recuperadas:** corrijo só confusões típicas de letra do OCR ("Tbe" → "The", "bttps://" → "https://"). Sem palpites por semelhança, que trocariam o título medieval "Confissom".
- **Continuam como estavam:** 67 rodapés, porque nem o OCR em 6000 px leu todas as notas da página. A nota 370 é ilegível na própria digitalização.
- **02/04:** fica sempre de fora, porque foi transcrita da foto da página impressa.
- Relatório: `ocr_rodape_kennyo_v2.json`.

### O Livro Ilustrado dos Símbolos
- **Correção manual:** 64 linhas lidas na imagem da página e corrigidas, como "contato", "Mercúrio", "floresceram" e "elmo" (o OCR tinha lido "elino").
- **Deixadas como estão**, por não haver leitura segura: 4 linhas (estação/oração, "…lhões", "vermelh…" e apresentados/representados).
- **Limite:** o começo de algumas linhas está desbotado na digitalização. Testei resolução maior, contraste e remoção da sombra da dobra, e nenhum ajudou. O livro inteiro ainda tem outras linhas assim, que só uma conferência página a página resolve.
- O pacote vai para `rag/v7/`.

### Referências ABNT
- Das 216 obras sem ano, 16 têm ISBN no texto. Só 2 ISBNs são da própria obra e estão nas bases públicas (Open Library): "Sócrates em 90 Minutos" (1998) e "O Conhecimento de Deus" (2005). Os outros são de livros citados na bibliografia.
- Agora são 83 obras com ano.
- As demais exigiriam identificar a edição exata de cada PDF. Atribuir o ano de outra edição seria uma referência errada.

### Teste do iOS
- **Execução:** a suíte rodou 6 vezes seguidas sem falha.
- **Causa provável:** a falha registrada antes foi "unexpected", isto é, erro lançado e não verificação reprovada. O único teste que lança erro de forma imprevisível é o de download repetido, quando a rede oscila na segunda descida.
- **Correção:** cada descida agora tenta duas vezes e, sem rede, o teste é pulado em vez de falhar, nas duas plataformas.

## Terceira rodada: O Livro Ilustrado dos Símbolos, conferido página a página

- **Escopo:** as 129 páginas foram comparadas uma a uma com a imagem da página, da capa ao índice remissivo e à contracapa.
- **Correções:** 1.691 ao todo.
  - Nas páginas em que o OCR misturava colunas, legendas e quadros "VEJA TAMBÉM", o texto foi reescrito inteiro na ordem de leitura.
  - Nas demais, foram corrigidos acentos, palavras cortadas e letras trocadas.
- **Fidelidade:** a grafia é a do original (1997-2001), por exemplo "idéia", "freqüência" e "jóia".
- **Ícone:** o dedo indicador dos quadros "VEJA TAMBÉM" virou "→".
- **Ordem das colunas:** a OCR por blocos (`BibliotecaMaconica_Dev/Tools/ocr_por_blocos.swift`) junta as linhas de cada coluna antes de ordenar a página. Foi a base da conferência.
- **Página 109 (Maçonaria):** revisada com cuidado especial. As palavras cortadas na dobra do livro foram completadas pelo contexto da própria página: "Ferramentas", "cidadãos", "Escada de Jacó", "Ashlar" e "Piso xadrez".
- **Ilegível na digitalização:** no índice, "paraíso 36, 42, 4" está cortado no próprio impresso e ficou como está.
- **Rodapé:** o livro não tem notas. A única "nota" antiga era um pedaço da orelha e saiu.
- **Aplicação:** `Tools/aplicar_ocr_refeito.py` ganhou o critério `manual`.
  - O texto conferido à mão substitui o antigo em toda página que mudou.
  - Linhas como "5 Resultante de dois..." não são mais separadas como rodapé quando a página não tinha notas.
- **Pacote:** `rag/v7/bibliotecaMaconica/rag_o_livro_ilustrado_dos_simbolos_completo.sqlite`, sha256 `5f033724…ee4`, com 128 páginas trocadas.
- **ABNT:** a referência já constava em `obras_referencias_manual.json` (Miranda Bruce-Mitford, São Paulo: Publifolha, 2001).

### Testes
- **iOS:** 98 testes, 0 falhas.
- **Android:** 35 testes unitários, 0 falhas.
- **Android no emulador:** suíte instrumentada completa. Três falhas antigas, anteriores a esta rodada, foram corrigidas:
  - **Contagem de pacotes:** `FullCatalogBenchmarkTest` (Android) e o teste equivalente do iOS esperavam 314 pacotes. Depois da remoção das obras repetidas, o catálogo tem 291, e a política de produto tira o Breviário de Rizzardo: o esperado agora é 290.
  - **Botões repetidos:** a auditoria de acessibilidade achou dois botões "Leitura" com o mesmo texto falado quando há duas leituras diárias. Cada botão agora é lido como "Leitura: <obra>".
  - **Contraste em item cortado:** a mesma auditoria media o contraste de um texto cortado na borda da rolagem (13 px visíveis), que mistura texto e fundo. Itens visíveis em menos de uma linha (24 dp) ficam fora da conta de contraste; o mesmo texto é medido quando aparece inteiro.
- **Dados do app:** feito backup no emulador antes da instalação, com `adb install -r`. Nada foi desinstalado.
