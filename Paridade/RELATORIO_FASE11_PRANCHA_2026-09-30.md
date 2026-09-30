# Fase 11 — Produção de trabalhos: prancha com referências ABNT

Data: 2026-09-30. Branch `fase11/prancha` (sobre a Fase 10).

## Entregue (iOS e Android)

- **Prancha montada a partir do dossiê** (`Paridade/prancha_v1.json`, referência `Tools/prancha_referencia.py`). Usa apenas os trechos que o dossiê já cita:
  - **Introdução:** abertura e definições.
  - **Desenvolvimento:** um parágrafo por autor, com os trechos do resumo.
  - **Pontos divergentes.**
  - **Conclusão:** os três primeiros termos associados e o espaço para a conclusão do leitor.
  - **Referências.**
- **Citações no texto** no formato "(SOBRENOME, ano, p. N)"; sem autor, primeira palavra do título (com o artigo) seguida de reticências.
- **Referências ABNT** (NBR 6023) das obras citadas, em ordem alfabética:
  - vários autores separados por ponto e vírgula;
  - sobrenome com sufixo (Filho, Neto, Junior, Sobrinho) fica junto;
  - obra sem autor entra pelo título;
  - dados ausentes aparecem como [S. l.], [s. n.], [S. l.: s. n.] e [s. d.].
- **Comparação lado a lado:** todos os trechos citados agrupados por autor (ou pela obra, quando o autor não é conhecido), em cartões roláveis.
- **Botão "Montar prancha"** no dossiê. A tela da prancha permite compartilhar e copiar o texto e avisa que dados bibliográficos incompletos aparecem com [s. d.] e [S. l.: s. n.].
- **Dados bibliográficos das obras** (`Paridade/obras_referencias_v1.json`, gerado por `Tools/referencias_obras.py`):
  - o catálogo só trazia o autor de 1 obra; o autor foi separado do título ("Título - Autor");
  - correções feitas à mão ficam em `Paridade/obras_referencias_manual.json`;
  - resultado: 322 obras, 130 com autor; ano, editora e local ficam para completar à mão.

## Verificação

- Casos de referência (2 dossiês e 9 referências isoladas) reproduzidos exatamente pelo iOS e pelo Android. Cobrem título, seções, comparação, referências e texto completo.
- Teste de interface no iPhone: monta o dossiê, abre a prancha, copia (o botão passa a "Prancha copiada.") e fecha.
- Teste de interface no Android: o mesmo roteiro, aprovado duas vezes seguidas.
- Testes unitários do iOS: 92, com 3 pulados e 0 falhas. Testes do caderno no Android: 5/5.
- Verificação de paridade: regras sincronizadas e casos conferidos no gate (`referencias_obras.py --check` e `prancha_referencia.py --check`).

## Observações

- Nos testes de interface do iPhone, consultas de texto sobre a prancha inteira ficam lentas. O teste aciona só os botões; o conteúdo é conferido pelos casos de referência.
- Ler a área de transferência dentro do teste abre o pedido "Permitir Colar" do iOS e trava o teste. Por isso o teste não lê a área de transferência.

- No Android 13 ou mais novo, copiar mostra por alguns segundos um aviso do próprio sistema por cima do app; o teste espera ele sumir.
- Depois de reiniciar o emulador, a primeira montagem de dossiê passa de 20 s porque monta o índice de busca. Isso fica para a Fase 13 (desempenho).

## Pendências

- Completar ano, editora e local das obras em `obras_referencias_manual.json` e rodar `python3 Tools/referencias_obras.py --atualizar`.
- 192 obras sem autor identificado entram na bibliografia pelo título.
