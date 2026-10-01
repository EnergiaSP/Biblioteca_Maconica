# OCR refeito: acervo e Breviário de Rizzardo

Data: 2026-10-01. Os PDFs originais vieram de `iCloud Drive/Maçonaria /Biblioteca /`.

## Por que o texto estava ruim
- **Resolução baixa.** O conversor antigo (`converter_pdfs_para_ocr.swift`) reduzia as páginas a 1200 px antes do reconhecimento.
- **Camada de texto ruim preservada.** PDFs que já tinham camada de texto eram mantidos, mesmo quando ela era ruim. Exemplo: o Voltaire tinha 451 de 451 páginas ilegíveis.

## Como foi refeito
1. **Reconhecimento:** `BibliotecaMaconica_Dev/Tools/refazer_ocr_obra.swift`.
   - Usa o Vision (preciso, com correção de idioma), em páginas de 3000 px.
   - Ignora a camada de texto antiga.
   - Monta os parágrafos pelo espaçamento e junta palavras partidas no fim da linha.
2. **Aplicação ao pacote:** `Tools/aplicar_ocr_refeito.py`.
   - Página a página, só troca o texto quando o novo é melhor pela regra comum de qualidade (`qualidade_referencia.py`). O texto antigo é mantido quando o novo não é melhor.
   - Os blocos de busca continuam um por página, como no resto do acervo. Os ids não mudam.
3. **Catálogo:** `Tools/atualizar_catalogo_pacotes.py`.
   - Os 30 pacotes refeitos apontam para `rag/v5/` no R2.
   - Os pacotes em uso (`rag/v4/`) não são sobrescritos.
   - Os arquivos antigos ficam em `_relatorios/RAGPackages_substituidos/`.

## Resultado nas 30 obras (3540 páginas)

| Páginas | Antes | Depois |
|---|---|---|
| Legíveis | 2291 | 3149 |
| Ruidosas | 369 | 50 |
| Ilegíveis | 567 | 37 |

| Obras do acervo (321) | Antes | Depois |
|---|---|---|
| Boa | 291 | 313 |
| Regular | 21 | 7 |
| Baixa | 9 | 1 |

Na tabela por obra, "Ruins" soma páginas ruidosas e ilegíveis.

| Obra | Nível antes | Páginas | Trocadas | Ruins antes | Ruins depois |
|---|---|---|---|---|---|
| voltaire_dicionario_filosofico_ridendo_castigat_mores | baixa | 459 | 450 | 451 | 3 |
| regulador_do_reaa_grande_oriente_do_passeio_1858 | baixa | 60 | 56 | 54 | 0 |
| mestre_cerimonias_jun_09 | baixa | 33 | 33 | 26 | 0 |
| macons_que_leem | baixa | 29 | 29 | 23 | 0 |
| a_abobada_celeste_de_um_templo_maconico_do_reaa_v1 | baixa | 65 | 36 | 26 | 22 |
| os_segredos_da_mente_milionaria | baixa | 112 | 111 | 42 | 0 |
| a_tradicao_hermetica_julius_evola | baixa | 129 | 129 | 39 | 0 |
| maconaria_revelada_os_segredos_do_aprendiz_macom | baixa | 341 | 336 | 103 | 1 |
| boletim_gob_1890 | baixa | 33 | 33 | 10 | 0 |
| a_mais_antiga_ata_maconica | regular | 5 | 4 | 1 | 0 |
| fibonacci_serie_de_fibonacci_e_o_numero_de_ouro | regular | 87 | 30 | 15 | 15 |
| combate_ao_clericalismo | regular | 38 | 3 | 4 | 3 |
| constituicao_da_confederacao_maconaria_portugueza | regular | 44 | 36 | 5 | 0 |
| historia_nat_geo_ramses_ii | regular | 60 | 58 | 8 | 0 |
| a_maconaria_em_portugal | regular | 152 | 150 | 17 | 4 |
| painel_do_grau_de_aprendiz_completo_booz | regular | 34 | 32 | 3 | 2 |
| a_geometria_sagrada | regular | 59 | 46 | 5 | 5 |
| pistis_sophia_traducao_do_texto_original | regular | 182 | 182 | 17 | 3 |
| o_nome_de_deus_adonai_roberto_aguilar_silva | regular | 12 | 8 | 1 | 1 |
| diccionario_breve_de_la_masoneria_biblioteca_freemasonry | regular | 88 | 84 | 7 | 2 |
| mecanica_quantica_resumo_de_conceitos | regular | 108 | 104 | 9 | 1 |
| origens_da_maconaria_basilio_thome_de_freitas_junior | regular | 12 | 11 | 1 | 1 |
| escolas_do_pensamento_maconico_bondarik | regular | 110 | 77 | 3 | 2 |
| geometria_sagrada | regular | 59 | 47 | 3 | 4 |
| fernando_pessoa_e_a_maconaria_roberto_aguilar_silva | regular | 17 | 17 | 1 | 0 |
| cores_na_maconaria | regular | 17 | 17 | 1 | 0 |
| as_chaves_de_salomao | regular | 454 | 351 | 23 | 6 |
| as_claviculas_salomao_mathers | regular | 454 | 351 | 23 | 6 |
| sistema_golden_dawn_2_0 | regular | 113 | 106 | 6 | 4 |
| maconaria_e_simbologia | regular | 174 | 169 | 9 | 2 |

O que sobra:
- **A Abóbada Celeste:** 22 páginas são mapas e figuras, sem texto corrido.
- **Fibonacci:** 15 páginas são de fórmulas e tabelas.

## Breviário de Rizzardo
- `Tools/refazer_breviario_rizzardo.py` localiza cada leitura no novo OCR pela data e troca o texto e o título quando o título confere.
- Resultado: 362 leituras refeitas, sem nenhum "~" restante (eram 115).
- Leituras com as colunas embaralhadas, como 13/01 e 02/03, voltaram a ser legíveis.
- 160 títulos foram corrigidos (por exemplo, "OAR" → "O AR" e "DIMENSA ~ O" → "DIMENSÃO").
- Relatório: `ocr_breviario_rizzardo_v1.json`.

## Obras repetidas no acervo
`Tools/marcar_duplicatas_catalogo.py` agora também marca como cópia a obra que tem 90% das páginas iguais em outra. São 17 cópias (eram 13), escondidas da busca, do dossiê e das trilhas:
- "100 Instruções de Aprendiz";
- "Geometria Sagrada" (mesmo arquivo, reconhecido de novo);
- "O Livro Ilustrado dos Símbolos II (trecho)";
- duas versões de "A Vida de Jacques DeMolay".

## Concluído depois
- **R2:** os 30 pacotes refeitos foram publicados em `rag/v5/` no bucket `biblioteca-maconica` (`publicar_rag_r2_wrangler.sh`), cada um conferido pelo ETag. Os 285 de `rag/v4/` já estavam publicados e não mudaram. Três pacotes baixados da URL pública foram conferidos pelo SHA-256 do catálogo.
- **Breviário de Kennyo Ismail, 02/04:** a leitura "Stolkin" (p. 98, com as notas 363 a 366) foi transcrita da foto da página impressa, com o OCR do Vision conferido contra a imagem. Ela substitui o aviso de "texto duplicado no PDF OCR".
