# Preparação da publicação — versão 1.0.16

Data: 2026-10-01. Itens 4, 5, 7, 11 e 12 da lista de pendências.

## 4. Textos das lojas
- `PUBLICACAO_LOJAS.md` tem os campos da App Store e do Google Play: nome, subtítulo, descrição curta e longa, novidades e palavras-chave.
- Também traz privacidade, categorias e a lista de capturas.
- `Tools/verificar_textos_lojas.py` confere os limites de cada campo. Todos estão dentro: descrição 2335/4000, novidades do Google Play 385/500, palavras-chave 96/100.

## 5. Capturas
Geradas em `Publicacao/capturas/` (fora do git), oito telas por aparelho:
1. início;
2. leitura;
3. coleções;
4. dossiê;
5. prancha;
6. trilhas;
7. caderno;
8. acervo.

| Aparelho | Tamanho | Como gerar |
|---|---|---|
| iPhone 6,9" | 1320x2868 | `bash Tools/gerar_capturas_lojas.sh` (`testStoreScreenshots`) |
| iPad 13" | 2064x2752 | `bash Tools/gerar_capturas_lojas.sh` (`testStoreScreenshots`) |
| Android | 1080x2400 | `bash Tools/gerar_capturas_android.sh` (`StoreScreenshotsTest`, barra de status em modo demonstração) |
| Apple Watch | 416x496 | à mão |
| Wear OS | 454x454 | à mão (redondo, com margem nova para telas redondas) |

## 7. Auditoria de liberação
- Ver `RELATORIO_AUDITORIA_LIBERACAO_2026-09-30.md`.
- Seis grupos foram fechados com testes; quatro ficam como verificação em aparelho (`deviceChecks`).
- `auditar_paridade_profunda.py --release` dá 0 falhas e 4 alertas.

## 11. Referências ABNT
- As fichas catalográficas das primeiras páginas foram lidas e revisadas uma a uma, junto com as linhas de direitos autorais das edições.
  - Citações de outros livros foram descartadas.
  - Resultado em `obras_referencias_manual.json`.
- Os títulos vindos de nomes de arquivo recuperam os acentos ("Maconaria" → "Maçonaria", "Historia" → "História").
  - A grafia acentuada só é usada quando é pelo menos 90% dos usos da palavra nos breviários.
  - Os autores mantêm a grafia original.
- Autores colados ao título por hífen foram separados à mão (por exemplo, "mistérios-Jorge Adoum").
- O catálogo foi normalizado em NFC: 168 títulos estavam decompostos (NFD), o que quebrava comparações de texto.

| De 322 obras | Antes | Agora |
|---|---|---|
| Autor | 130 | 162 |
| Ano | 0 | 49 |
| Editora | 1 | 41 |
| Local | 0 | 33 |

Sem ficha catalográfica no PDF, ano, editora e local continuam `[s. d.]` e `[S. l.: s. n.]`. Completar exige a edição impressa ou a consulta ao catálogo da editora.

## 12. Trilhas por grau
- **Companheiro** ganhou 8 obras: geometria sagrada, quadrivium, trivium, números e Pitágoras.
- **Mestre** ganhou mais 4 obras: Lavagnini, Câmara do Meio, Templo de Salomão e lendas da Maçonaria inglesa.
- **Total por grau:** Aprendiz 10 etapas e 11 obras; Companheiro 9 etapas e 8 obras; Mestre 8 etapas e 5 obras.
- As trilhas e o caderno mostram o título limpo da referência com o autor (por exemplo, "Aprendizado Maçônico — Rizzardo da Camino"), no lugar do nome do arquivo. Isso vale para iOS e Android.
- Teste Android `suggestedWorksHaveCatalogTitles`: toda obra sugerida tem título.
- O dossiê, a prancha e o prompt da IA citam as obras da mesma forma ("Dicionário Maçônico Completo, p. 6").
  - Antes saía o nome do arquivo guardado no pacote ("Dicionario Maconico Completo").
  - A troca é feita na montagem das fontes, nas duas plataformas. Os pacotes do R2 não mudam.

## Também
- **Breviário de Rizzardo:** 54 tis deixados pela digitalização corrigidos de forma conservadora (`Tools/corrigir_til_rizzardo.py`, relatório `correcao_til_rizzardo_v1.json`). Depois, o OCR novo do PDF original refez as 362 leituras e eliminou todos os "~" (ver `RELATORIO_OCR_2026-10-01.md`).
- **Wear OS:** margem proporcional nas telas redondas.
