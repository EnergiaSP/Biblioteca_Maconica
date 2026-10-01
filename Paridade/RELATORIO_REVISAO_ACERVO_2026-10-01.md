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
