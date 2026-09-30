# Fase 12 — Estudo por grau

Data: 2026-09-30. Branch `fase12/trilhas-grau` (sobre a Fase 11).

## Decisões do usuário

- **Sem restrição por grau:** as três trilhas ficam visíveis para todos, só organizadas por grau.
- **Proposta automática de obras e temas:** a lista fica num arquivo de configuração para ajustar depois.

## Entregue (iOS e Android)

- **"Trilhas por grau"** no menu Mais.
- **Trilhas:** Aprendiz com 10 etapas, Companheiro com 9 e Mestre com 8 (`Paridade/trilhas_grau_base.json`, escrito à mão). Cada etapa é um tema clássico do grau, com uma descrição curta.
- **Etapa estudada:** conta quando há um dossiê salvo com o mesmo tema (sem diferenciar maiúsculas, acentos e espaços) ou quando o leitor a marca à mão. As marcas ficam no aparelho.
- **Progresso:**
  - "n de m etapas (p%)" com barra;
  - marcos "Primeira etapa estudada", "Metade da trilha" e "Trilha concluída";
  - próxima etapa, ou "Todas as etapas estudadas".
- **"Estudar no Dossiê":** abre o Dossiê com o tema em toda a biblioteca e já o monta. Um estudo salvo antes mantém as datas de revisão.
- **Obras sugeridas:** obras do catálogo, sem duplicatas, cujo título ou assuntos citam o grau. São 11 para Aprendiz, 1 para Mestre e nenhuma para Companheiro, porque nenhum título do acervo cita esse grau. Quando não há obra, a tela explica que os dossiês consultam toda a biblioteca.
- **Arquivos gerados:** `Tools/trilhas_referencia.py` gera `Paridade/trilhas_grau_v1.json` (com as obras) e os casos `casos_trilhas_v1.json`. Os dois entram no gate.

## Verificação

- Casos de referência (6 cenários: nada estudado, dossiê salvo, metade por dossiês e marcas, trilha concluída, marca de outro grau e tema parecido que não conta) reproduzidos pelo iOS e pelo Android.
- Teste de interface nos dois apps:
  - marca a primeira etapa de Aprendiz e o progresso vai a "1 de 10 etapas (10%)" com o marco;
  - desmarca e volta a 0;
  - "Estudar no Dossiê" monta o dossiê de "Pedra bruta".
- iOS: 93 testes unitários, 3 pulados e 0 falhas.
- Verificação de paridade: 0 falhas.

## Pendências

- Revisar e ajustar temas e obras de cada grau em `Paridade/trilhas_grau_base.json`, depois rodar `python3 Tools/trilhas_referencia.py --atualizar`.
- As marcas manuais de etapa ainda não entram no caderno sincronizado; os dossiês salvos, sim.
