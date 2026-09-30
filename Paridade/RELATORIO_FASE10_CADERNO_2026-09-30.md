# Fase 10 — Caderno de estudo, sincronização e caderno por tema

Data: 2026-09-30. Branch `fase10/caderno-sync` (PR EnergiaSP/Biblioteca_Maconica#8, sobre a Fase 9).

## Entregue (iOS e Android)

- **Caderno portátil** (`Paridade/caderno_v1.json`, referência `Tools/caderno_referencia.py`): leituras (comentário, reflexão, favorita, lida, marcadores, edição do texto), dossiês salvos com a interpretação da IA e cartões de revisão. O mesmo arquivo abre nos dois sistemas.
- **Mesclagem sem perda**:
  - texto diferente dos dois lados fica duplicado, com o marcador de importação;
  - texto contido no outro fica o mais completo;
  - favorita e lida vêm de qualquer lado;
  - marcadores são unidos;
  - a edição local prevalece;
  - dossiês são casados pelo estudo;
  - nos cartões, fica o de mais respostas;
  - na interpretação da IA, fica a mais recente.
- **Exportar e importar** pelo seletor de arquivos.
- **Sincronização automática** ao abrir o app e no botão "Sincronizar agora":
  - iCloud Drive (iOS);
  - Google Drive, pasta privada do app (Android);
  - conta própria com código de sincronização. O caderno é cifrado no aparelho com AES-256-GCM; o servidor `Servidor/caderno` (Cloudflare Worker + R2) guarda só o arquivo cifrado e recusa gravações concorrentes.
  - Um arquivo remoto de versão mais nova nunca é sobrescrito.
- **Interpretação da IA guardada com o dossiê salvo**: volta ao reabrir o dossiê.
- **Caderno por tema**:
  - todas as anotações numa lista (dossiês com interpretação, marcadores, reflexões e comentários);
  - busca sem acentos e maiúsculas;
  - temas dos dossiês;
  - exportação em texto;
  - toque abre a leitura, a página da obra ou o dossiê.
- **Android**: reflexão e comentário nas páginas das obras do Acervo, como no iOS.

## Verificação

- Casos de referência reproduzidos nas duas plataformas:
  - mesclagens, incluindo a interpretação;
  - validação do arquivo;
  - caderno por tema (7 buscas, temas e exportação);
  - conta própria (código, derivação e cifragem).
- Arquivo escrito pelo iOS lido no Android e vice-versa, com troca real pelo emulador e pelo simulador.
- Sincronização com provedor falso: mescla, aplica e grava de volta; não sobrescreve arquivo de versão futura.
- Conta própria: 12 verificações do Worker local e troca real iPhone↔Android com o mesmo código.
- Testes de interface do caderno por tema aprovados no iPhone e no emulador Android.
- iOS: 90 testes unitários (3 pulados) sem falhas antes do caderno por tema; depois, os testes de regra do caderno aprovados. Android: testes unitários e do caderno (5/5) aprovados.
- Verificação de paridade: 0 falhas.

## Incidente

Uma execução de testes pelo Gradle (`connectedDebugAndroidTest`) desinstalou o app do emulador e apagou o acervo de teste.
- O acervo v4 foi reinstalado a partir do Mac: 857 MB, 315 pacotes.
- A lista de obras importadas à mão naquele emulador não tinha cópia e se perdeu.
- Os testes Android passam a usar só `adb install -r` e `am instrument`.

## Pendências (dependem do usuário, adiadas a pedido)

- Publicar o servidor da conta própria no Cloudflare (bucket privado `biblioteca-maconica-cadernos` e Worker). Até lá, a opção fica oculta.
- Criar o cliente OAuth do Google Drive (pacote e SHA-1) no Google Cloud.
- Testar o iCloud num iPhone real.
- Testar a interpretação com uma chave real do Gemini.
