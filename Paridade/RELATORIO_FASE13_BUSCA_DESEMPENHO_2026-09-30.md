# Fase 13 — Busca e desempenho

Data: 2026-09-30. Branch `fase13/busca-desempenho` (sobre a Fase 12).

## Variantes e singular/plural (iOS e Android)

- **Regra comum** `Paridade/variantes_busca_v1.json`, com referência `Tools/variantes_referencia.py` e 38 casos em `casos_variantes_v1.json`.
- **Dicionário de grafias:** passou de 3 para 25 grupos. Exemplos:
  - Jacó/Jacob, Hiram/Hirão, Salomão/Salomon, Boaz/Booz, Jakin/Jaquim/Jachin, Tubalcaim;
  - grafias antigas: symbolo, philosophia, egypto, theologia, mystica;
  - Cabala/Kabbalah e as outras formas.
  - O dossiê usa o mesmo dicionário: `estudo_dossie_v1.json` "variantes" agora é gerado daqui. Os casos do dossiê e da IA continuam idênticos.
- **"Singular e plural juntos"**, na tela de Busca, ligado por padrão e guardado no aparelho:
  - "loja" encontra "lojas", "irmão" encontra "irmãos", "ritual" encontra "rituais", "luz" encontra "luzes";
  - preposições como "dos" e "pelos" ficam de fora;
  - no máximo 6 alternativas por palavra.
- **No acervo real (Android):** "malhete" passa de 218 para 256 resultados e "acácia" de 219 para 232 com a opção ligada.

## Desempenho no Android

Medido no emulador (Android 16, 4 núcleos), com o acervo v4 completo (314 pacotes):

| Situação | Antes | Depois |
|---|---|---|
| Coleções, pontuação do acervo ao abrir o app de novo | 9,1 s | 0,23 s (cache em disco) |
| Primeira busca depois de instalar ou atualizar (índice de notas refeito) | cerca de 4,6 s a mais | preparado em segundo plano na abertura |
| Busca "maçonaria" (7.046 blocos) | 2,0 s | sem mudança |
| Busca "grande loja" | 1,7 s | sem mudança |

- **Coleções:** a pontuação das páginas fica em `colecoes_pontuacao_v1.json`, válida enquanto regras, limites, obras e tamanhos dos arquivos forem os mesmos. O resultado é idêntico ao recalculado.
- **Índice de notas de rodapé:** é atualizado em segundo plano logo após o índice dos breviários, e não mais na primeira busca.
- **Busca de termos comuns:** a medição mostrou que o tempo está na consulta com junções e na contagem de ocorrências de milhares de blocos, que definem a ordem dos resultados igual nas duas plataformas. Mudar isso exige cuidado para não alterar a ordem; fica para uma medição no aparelho físico (moto g84).
  - Neste emulador de 4 núcleos, a consulta em paralelo foi mais lenta que em sequência. O paralelismo foi escolhido pelo desempenho no moto g84, por isso não foi alterado sem medir no aparelho.
- **Depois de reiniciar o aparelho**, a primeira montagem de dossiê ainda passa de 20 s no emulador: os 857 MB do acervo precisam ser lidos do disco. No aparelho físico o armazenamento é mais rápido; confirmar lá.

## Verificação

- Casos de variantes reproduzidos pelo iOS e pelo Android.
- iOS: 94 testes unitários, 3 pulados e 0 falhas.
- Android: variantes (2 testes, incluindo o acervo real), integridade (40 testes) e navegação (24 de 24).
- Numa execução anterior da suíte de navegação, o processo de teste caiu uma vez no teste das trilhas por grau ("performMeasureAndLayout called during measure layout", do Compose). Não se repetiu: o teste isolado passou três vezes seguidas e a suíte completa, depois, passou inteira.
- O preparo do índice de notas começa 8 s depois da abertura e pula, só pelo tamanho e pela data dos arquivos, os pacotes já preparados. Sem isso, a primeira execução da suíte teve quatro esperas de dossiê acima de 20 s.
- Verificação de paridade: 0 falhas.
