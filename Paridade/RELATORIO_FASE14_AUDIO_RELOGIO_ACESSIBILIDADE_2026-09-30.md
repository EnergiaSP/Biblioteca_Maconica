# Fase 14 — Estudar em outros momentos e acessibilidade

Data: 2026-09-30. Branch `fase14/audio-relogio-acessibilidade` (sobre a Fase 13).

## Áudio em sequência (iOS e Android)

- Cada coleção e cada trilha de estudo tem o botão "Ouvir em sequência" no cabeçalho do cartão.
  - As leituras são lidas uma após a outra (até 30), na ordem da tela.
  - Antes de cada leitura, a voz anuncia a posição ("Leitura 2 de 12.").
  - Uma barra mostra "Ouvindo {coleção}: leitura n de m", com Pausar/Continuar, Próxima e Parar.
- Regra comum: `Paridade/audio_sequencia_v1.json` (rótulos, anúncio e limite).
- No Android, a voz do sistema não pausa no meio da frase: "Pausar" guarda a posição e "Continuar" relê a leitura atual. No iOS, a pausa é no meio da palavra.
- Teste de interface nos dois apps: inicia, confere "leitura 1 de", pula para "leitura 2 de" e para.

## Cartões de revisão no relógio (Apple Watch e Wear OS)

- **Envio da sessão:** o celular envia ao relógio os cartões da Revisão ativa vencidos hoje (até 20), com os rótulos da regra `Paridade/relogio_revisao_v1.json`. O relógio guarda a sessão e a abre mesmo sem o celular por perto.
- **No relógio:** "Revisar cartões (n cartão(ões) para hoje)" mostra a frente; "Mostrar resposta" revela a resposta com a fonte; depois vêm Errei, Difícil e Acertei.
- **Volta das notas:** cada nota volta ao celular, que aplica a mesma revisão espaçada e reenvia a sessão atualizada. Uma nota entregue duas vezes (mesmo eventoID) conta uma vez.
- **Lembrete:** se há cartões para o dia, o relógio agenda um aviso às 19h com o número de cartões.
- **Transporte:**
  - iOS: WatchConnectivity (a sessão vai como contexto da aplicação; as notas, como userInfo, entregues depois se o relógio estiver longe);
  - Android: Data Layer do Wear OS (dados `/revisao-cartoes` e `/revisao-resposta/{eventoID}`).
- **Mensagens:** exemplos na própria regra; o iOS e o Android leem o mesmo baralho, recusam as mesmas respostas inválidas e regravam sem perda.
- **Testes:** Android confere que a nota do relógio é aplicada uma vez só. iOS compila o app do iPhone e o do relógio.
- **Não testado:** a troca real entre um celular e um relógio pareados. Não há relógio pareado nos simuladores/emuladores desta máquina; testar com os aparelhos.

## Auditorias automáticas de acessibilidade

- **Android** (`AccessibilityAuditTest`), com o Accessibility Test Framework do Google:
  - audita Início, Coleções, Dossiê, Acervo, Mais, Trilhas por grau e Caderno de estudo;
  - verifica rótulos, áreas de toque, texto falado repetido e contraste medido sobre uma captura da tela;
  - erros e avisos fazem o teste falhar;
  - a árvore vem da janela do app, como no Espresso, para incluir os elementos do Compose (de 45 a 77 por tela).
- **iOS:** Trilhas por grau e Caderno de estudo entram na auditoria (`performAccessibilityAudit`), como as demais telas.
- **Correções encontradas pelas auditorias:**
  - botões repetidos com o mesmo nome falado ("Ouvir em sequência", "Estudar no Dossiê", "Marcar como estudada") agora dizem a coleção ou a etapa;
  - nas trilhas, cada grau mostra a próxima etapa e a lista completa abre em "Ver todas as etapas". Com 27 etapas abertas, a auditoria do iOS estourava o tempo;
  - obras sugeridas e "Ver todas as etapas" com área de toque de 44 pt;
  - campo de busca do caderno no iOS: o texto de dica ficava cortado; agora o rótulo fica acima do campo.
- Os avisos de contraste vistos numa primeira rodada vinham de um diálogo do sistema do emulador ("não está respondendo") que escurecia a tela. Com o emulador reiniciado, as 7 telas passaram sem erro nem aviso.

## Verificação

- iOS: 95 testes unitários, 3 pulados e 0 falhas.
- iOS, testes de interface: áudio, trilhas, auditoria das telas novas e caderno por tema, todos aprovados. O app do relógio compila.
- Android: auditoria (7 telas), áudio, trilhas e mensagens do relógio (2), todos aprovados; testes unitários aprovados; o app Wear compila.
- Verificação de paridade: 0 falhas.

## Observação

- Numa rodada anterior da suíte do Android, uma queda do Compose ("performMeasureAndLayout called during measure layout") apareceu duas vezes. As duas vieram logo depois de um teste que excedeu o tempo esperando o dossiê, ao fechar a tela. Não apareceu em uso normal nem nas rodadas seguintes; fica em observação.
