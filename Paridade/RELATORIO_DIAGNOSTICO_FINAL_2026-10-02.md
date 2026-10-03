# Diagnóstico final — 02/10/2026

Análise completa do sistema (funcionalidades, rapidez, confiabilidade, OCR, navegação) e varredura do código das duas plataformas em busca de defeitos e código obsoleto. Ramo `revisao/diagnostico-final`, a partir do PR #16.

## Resumo

| Item | Situação |
|---|---|
| Compilação iOS | Sem avisos (app, widget e relógio) |
| Relógios, widgets e servidor do caderno | Revisados na segunda rodada (ver abaixo) |
| Cache de notas (iOS) | 1,2 GB de caches órfãos encontrados e corrigidos |
| Compilação Android | Sem avisos depois das correções; lint sem erros |
| Paridade | `verificar_paridade.sh`: 0 falhas, 0 alertas |
| Testes iOS (unidade) | 98, 0 falhas |
| Testes Android (unidade) | 36, 0 falhas |
| Testes Android (emulador) | 94; as falhas de dossiê (espera de 20 s) só acontecem com o Mac rodando o simulador em paralelo; sozinha, `NavigationFlowTest` passa nos 26 testes |
| Testes de interface iOS | 42 (2 pulados de propósito); os 4 que falhavam foram corrigidos e todos passam |
| Resultados iguais iOS × Android | Sim, com o mesmo acervo: buscas e seleção de estudos idênticas |
| OCR | 99,6% das 59.978 páginas legíveis |

## Funcionalidades e paridade

- Com o mesmo acervo nas duas plataformas, as buscas "maçonaria", "grande loja", "ética virtude" e "escada de jacó" e a seleção de estudos das 16 coleções e trilhas dão resultados idênticos, na mesma ordem.
- A primeira comparação mostrou diferenças, mas a causa era o ambiente de teste, não o código: o emulador tinha 94 pacotes de antes do OCR refeito e o simulador tinha 2 pacotes velhos na pasta de downloads do app. Os dois foram atualizados para comparar.
- Lembrete: o iOS procura primeiro os pacotes baixados pelo próprio app (`Application Support`) e só depois o corpus de auditoria em `Documents`.

## Rapidez (acervo completo: 290 obras, 62.816 páginas)

Valores antes → depois das correções.

| Medida | iOS (simulador) | Android (emulador) |
|---|---|---|
| Busca "maçonaria" (todo o acervo) | 1,7 s → 0,86–0,93 s | 1,2 s → 0,6–1,0 s |
| Busca "grande loja" | 0,37 s → 0,33–0,42 s | 0,5 s → 0,4–0,5 s |
| Busca "ética virtude" | 0,30 s → 0,18–0,24 s | 0,45 s → 0,25–0,29 s |
| Seleção de estudos (16 regras) | 0,9 s | 28 ms com o cache pronto; 4,5 s na primeira vez depois de instalar |
| Índice de páginas da maior obra (2.678 p.) | 25–39 ms | 592–833 ms → 46–59 ms |
| Voltar da leitura | cerca de 170 ms a menos (ver defeito 4) | — |

Simulador e emulador rodam no Mac; não são medidas de aparelho físico.

## OCR

- 59.978 páginas avaliadas: 179 ruidosas e 65 ilegíveis (0,4%).
- Obras por nível: 289 boas, 6 regulares, 1 baixa.
- A obra "baixa" ("A Abóbada Celeste de um Templo Maçônico") é uma apresentação de mapas do céu. As páginas "ilegíveis" são rótulos de diagramas e títulos em letras espaçadas, e as páginas de texto corrido estão bem lidas. Não há OCR melhor a fazer nelas.

## Defeitos encontrados e corrigidos

1. **Busca de notas enfileirada (iOS e Android).**
   - Problema: uma trava global prendia a busca de notas de rodapé durante todo o trabalho de cada pacote. Como a busca no acervo percorre os 290 pacotes em paralelo, essa trava os enfileirava, e uma chamada vinda da interface ficava esperando trabalho de prioridade menor (o Xcode acusava "priority inversion" em todos os testes de interface).
   - Correção: agora há uma trava por arquivo de cache, ou seja, por pacote.
   - Efeito: o teste de interface do dossiê voltou a passar.
2. **Índice de páginas lento no Android.**
   - Problema: para cada página da obra, o filtro e o título eram normalizados (acentos e expressão regular), mesmo com o filtro vazio, que é o caso ao abrir a obra.
   - Correção: o filtro é normalizado uma vez, e a comparação só acontece quando há filtro.
   - Além disso, `normalized()`, usada em todo o app, deixou de criar um `Locale` e compilar uma expressão regular a cada chamada.
3. **Estado calculado e nunca lido (iOS, tela inicial).**
   - Problema: `itensRecentesCache`, `leiturasRecentes`, `diasCalendarioMesAtualCache`, `dataHojeBreviarioCache`, `buscaIndice` e `pdfURL` eram recalculados a cada atualização da tela inicial, mas nenhuma tela os lia.
   - Correção: removidos, junto com o cálculo do calendário mensal antigo.
4. **Voltar da leitura lento (iOS).**
   - Problema: a cada Voltar, `LeituraVozService.parar()` perguntava ao sintetizador de voz se ele estava falando, o que custava cerca de 170 ms na thread principal (medido com amostragem), mesmo sem leitura em voz alta.
   - Correção: só o próprio serviço fala por esse sintetizador, então os estados dele (`estaLendo`, `estaPausado`) bastam para decidir se há o que parar.
5. **APIs depreciadas (Android).**
   - `Locale("pt","BR")` passou a `Locale.forLanguageTag("pt-BR")`.
   - `scaledDensity` passou a `TypedValue.applyDimension`.
   - Os dois usos de `LineBreaker.JUSTIFICATION_MODE_*` (constantes da API 29 inlinadas, em métodos que existem desde a API 26) foram marcados com uma supressão comentada.
   - O falso positivo do lint em `produceState` foi suprimido, com comentário.
6. **Testes desatualizados.**
   - **Contagem de pacotes:** os testes de catálogo completo esperavam 314 pacotes; agora são 290, nas duas plataformas.
   - **Coleções (iOS):** os testes procuravam títulos de breviário fixos, que mudam quando o acervo está baixado. Agora abrem a primeira leitura da coleção por um identificador estável (`study.first.<coleção>`).
   - **Busca (iOS):** o teste agora busca só nos breviários e por uma frase da leitura que ele abre.
   - **Prancha (iOS):** a espera pelo botão copiar passou de 20 s para 40 s. Com o acervo inteiro a prancha é longa, e o XCUITest demora para ler a tela.

## Código obsoleto removido

**iOS**

- **Importador e acesso a dados:**
  - `BibliotecaPDFStructuredImporter.swift` inteiro (295 linhas, nada o chamava);
  - `percorrerItens` e `percorrerItensBiblioteca`.
- **Modelos e regra antiga de IA:**
  - `ExportacaoEstudoAvancado`, `BibliotecaItemID`, `BibliotecaData`, `BibliotecaRAGContextoIA`, `BibliotecaRAGPoliticaIA`;
  - `GeminiAnaliseService.validarCitacoes` e o erro `fontesInvalidas`. Era a regra antiga de citações; as respostas com fontes passam por `InterpretacaoAssistida`.
- **Telas que nunca eram exibidas:**
  - índice remissivo por breviário (`IndiceRemissivoView`, `abrirEntradaIndice`);
  - calendário mensal e próxima leitura;
  - card "Recentes" antigo (a tela inicial usa "Últimas leituras");
  - `leituraDoDiaContainer`.
- **Funções soltas:** `voltarParaHome`, `temaUnificadoBinding`, `corStatus`, `corSelecaoTema`, `singularPluralLigado`, `datasBusca`.

**Android**

- Tela `Index` (índice remissivo por breviário), que nenhuma navegação abria, com `IndexScreen`, `IndexCard` e `buscarIndice`.
- `createTextPdf`, `drawAcaciaOrnament`, `primeiraPaginaDaObra`, `datesWithComments`.
- `GeminiService.validarCitacoes`.

**Comum**

- Os casos `citations` de `casos_comuns_v1.json` (só testavam a regra antiga) e os testes correspondentes.
- Pontos de entrada usados apenas pelos testes de paridade (`select`, `incorporate`, `rankLocalTexts`, `pontuarTextosLocais`, `showHome`, `substituirObra`) foram mantidos.

**Ferramentas**

- **Cópias repetidas em `Tools/`:** os 4 arquivos idênticos aos de `BibliotecaMaconica_Dev/Tools/` (`AuditImport.swift`, `GenerateAppIcon.swift`, `OCRPageSample.swift`, `organize_breviario_pdf.py`).
- **Geradores de capturas antigos em `Tools/`:** ainda diziam "Breviário Maçônico"; as cópias atuais, com "Biblioteca Maçônica", ficam em `BibliotecaMaconica_Dev/Tools/`.
- **Envio ao R2:**
  - removidos `upload_rag_r2.sh`, `upload_rag_r2_wrangler.sh` (mandava tudo para `rag/v1`), `preparar_manifesto_r2.py` e `r2.env.example`;
  - o envio atual é `publicar_rag_r2_wrangler.sh`.

Ao todo, cerca de 2.780 linhas removidas na primeira rodada.

## Navegação

- **iOS:** os 42 testes de interface cobrem início, coleções, dossiê, prancha, caderno, busca, leitura, voltar, fonte grande, temas e acessibilidade. Todos passam.
- **Android:** os testes de fluxo de navegação estão incluídos nos 94 testes instrumentados.
- **Tela inalcançável:** o Android tinha uma tela (`Index`) que nenhuma navegação abria. Foi removida.
- **Toque em Voltar ignorado (falso alarme):** uma falha intermitente parecia ignorar o Voltar depois de uma leitura aberta pela busca. A investigação (botões na tela, amostragem da thread principal) mostrou que só havia um botão Voltar, visível, e que nenhum travamento longo ocorria. As falhas vinham de o teste depender de um título fixo e de rodar com o simulador sob carga; com o teste corrigido, passa.

## Segunda rodada (03/10/2026)

Cobriu o que a primeira tocou pouco: os apps de relógio (Wear OS e Apple Watch), os widgets, o servidor do caderno, as ferramentas em Python, o estado escrito e nunca lido no Android e as duas recomendações pendentes.

### Verificações

| Item | Resultado |
|---|---|
| Servidor do caderno (`worker.js`) | As 12 verificações de `teste_servidor.mjs` passam (R2 simulado em memória, sem publicar nada) |
| Wear OS | Compila; lint sem erros |
| Apple Watch e widgets | Compilam sem avisos |
| Pacotes locais (`medir_acervo_local.py`) | 291 pacotes, todos com sha256 certo e `quick_check` ok; 62.989 páginas |
| Ferramentas em Python | 42 scripts, nenhum import ou função sem uso; os 2 testes passam |
| Estado escrito e nunca lido (Android) | Nenhum; as propriedades da sessão de estudo são lidas pelas telas por delegação |

### Defeitos encontrados e corrigidos

7. **Caches de notas órfãos ocupando 1,2 GB (iOS).**
   - Problema: o nome de cada cache era o hash do caminho absoluto do pacote, e o caminho do contêiner do app muda quando ele é reinstalado (no simulador, a cada instalação). A Apple também não garante que esse caminho se mantenha nas atualizações. Cada mudança deixava todos os caches para trás e reconstruía todos. O simulador de teste acumulou 26.441 arquivos (1,2 GB) para 291 pacotes.
   - Correção:
     - o nome passa a usar o caminho relativo ao contêiner, que não muda;
     - ao abrir o app, os caches de nenhum pacote atual, sem alteração há mais de um dia, são apagados.
   - O Android já usa um caminho estável (290 caches, 16 MB) e ganhou a mesma limpeza, para os pacotes que saem do catálogo.
8. **Cache de notas preparado antes da primeira busca.**
   - O iOS não preparava esse cache: a primeira busca depois de instalar ou atualizar o construía. O Android preparava só 8 s depois de abrir o app.
   - Agora as duas plataformas o preparam ao abrir o app e logo depois de cada download (era a recomendação pendente).
   - Como no Android, os pacotes já preparados são pulados pela identidade do arquivo (marcador `.preparado` ao lado do cache), sem abrir nenhum banco. Na primeira versão, abrir os 291 bancos a cada abertura ocupava o disco por cerca de 20 s e atrasou a abertura da leitura num teste de interface.
9. **Widget do iOS mostrando a leitura de ontem.** O widget se atualizava a cada 6 horas e podia manter a leitura do dia anterior até as 6 h. Agora também se atualiza à meia-noite. O do Android se atualiza a cada 30 min.
10. **Notificação diária do Apple Watch parava depois de 60 dias.**
    - O relógio agenda uma notificação por dia (o watchOS guarda no máximo 64), e nada renovava a lista.
    - Agora, ao abrir o app, ela é reagendada quando faltam menos de 30 dias.
11. **Lembrete de revisão no relógio.**
    - Apple Watch: o lembrete das 19 h contava o total de cartões e continuava agendado depois de todos respondidos. Agora conta só os pendentes e é cancelado quando não sobra nenhum, como no Wear OS.
    - Wear OS: o lembrete se perdia ao reiniciar o relógio. Agora é reagendado se a sessão salva for a do dia.
12. **Controles do áudio das coleções fora da tela (iOS e Android).**
    - Problema: a barra "Ouvindo… leitura 1 de N", com Pausar, Próxima e Parar, ficava no topo da lista. Ao tocar em "ouvir" numa trilha mais abaixo, os controles apareciam fora da vista. Os testes só passavam porque rolavam a tela até ela (o do iOS falhava de vez em quando).
    - Correção: enquanto a sequência toca, a barra fica fixa no rodapé da tela, nas duas plataformas, com fundo opaco no iOS.
    - Os testes agora conferem que os controles estão visíveis sem rolar.
13. **Resumo da leitura no Wear OS com "…" indevido.** As reticências eram decididas pelo tamanho do texto original, não do texto já sem espaços repetidos, e apareciam em resumos completos.
14. **Textos sem acento.**
    - 23 mensagens do app iOS ("Nao foi possivel…", "indisponivel", "invalido", "Validacao", "Teste de notificacao", "Observacao de importacao") e 3 do Apple Watch ("Permissao negada", "Notificacao diaria ativa", "Notificacao cancelada") foram corrigidas.
    - A cor do aviso não muda, porque `AvisoApp` reconhece as duas grafias.
15. **Script de medição com data fixa.** `medir_acervo_local.py` gravava sempre em `evidencias/2026-09-18`; agora grava na pasta do dia.

### Código obsoleto removido

- `Tools/modularizar_servicos_ios.py`: era de uso único. A divisão dos serviços do iOS que ele fazia já está aplicada, e rodá-lo de novo não faz nada.
- `WearProgressSync` (Wear OS): um objeto que só repassava a chamada para `ProgressTransport.send`.

### Novos testes

- `testOrphanNoteCachesAreRemovedAfterADay` (iOS) e `orphanNoteCachesAreRemovedAfterADay` (Android), com os mesmos casos.
- Totais: iOS com 98 testes de unidade e Android com 36, nenhuma falha.

## Recomendações (não alterado)

- **Backup na thread principal (iOS):** `UserDataPersistenceService.salvarBackup()` compara o backup inteiro na thread principal, 0,7 s depois de cada mudança nos dados (cerca de 126 ms). O custo está em copiar e comparar todo o domínio de preferências, que também é a fonte do estado que o serviço grava. Tirá-lo de lá exige reorganizar o isolamento de concorrência do serviço inteiro.
- **Flags de abertura no Wear OS:** o lint recomenda não usar `FLAG_ACTIVITY_NEW_TASK` e `FLAG_ACTIVITY_CLEAR_TOP` nas telas abertas por notificação, por causa da lista de recentes do relógio. Mudar isso pede teste num relógio de verdade.

## Para decidir (não alterado)

- **Mídias antigas das lojas:**
  - `AppStoreConnect_Midia/{iPhone,iPad,AppleWatch}/`, versões anteriores às pastas `*_Final_*`;
  - `GooglePlay_Midia/backup_nome_antigo/`.
- **Dependências do Android:** o lint aponta 16 bibliotecas com versão nova no app e 7 no Wear OS (Compose, Core, Lifecycle, Play Services). Atualizar exige testar o app inteiro de novo.
- **Scripts de uso único do Rizzardo:** `corrigir_til_rizzardo.py`, `refazer_breviario_rizzardo.py` e `importar_breviario_rizzardo.py` documentam como o texto foi corrigido e ficam por rastreabilidade.
