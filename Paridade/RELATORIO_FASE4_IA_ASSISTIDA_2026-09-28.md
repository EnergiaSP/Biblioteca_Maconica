# Fase 4: interpretacao assistida por IA (opcional)

Periodo: 28/09/2026. Desenvolvimento iOS/Android 1.0.15.

## Principio

O app e completo sem IA: o dossie (Fase 3) e todo extraido do acervo. A IA e um passo opcional, que so interpreta os trechos do proprio dossie e nao pode acrescentar nada sem fonte.

## Antes

- Os dois apps mandavam prompts diferentes ao Gemini (divergencia de paridade).
- A resposta era aceita inteira se todas as citacoes [Fn] existissem, ou recusada inteira. Frases sem citacao passavam junto com as citadas.
- Citacao literal nao era conferida com o texto da fonte.

## Agora

- Regras comuns em `Paridade/ia_assistida_v1.json` (instrucoes, blocos da resposta, limites e rotulos) e implementacao de referencia `Tools/ia_referencia.py`. Os apps reproduzem prompt, filtro e exibicao exatamente: iOS `Services/InterpretacaoAssistida.swift`, Android `data/AssistedInterpretation.kt`.
- Prompt: a IA recebe somente os trechos exibidos no dossie (ate 30), numerados [F1]..[Fn]. Cada trecho e uma janela de ate 1.200 caracteres centrada na primeira ocorrencia do tema, com as mesmas variantes de grafia do dossie; notas de rodape ate 300 caracteres. Fontes oficiais cadastradas entram so como referencia e nao podem ser citadas como [F].
- Filtro da resposta, frase por frase:
  - fica somente a frase com ao menos uma citacao, e todas as citacoes precisam existir (uma citacao inexistente como [F9], ou com numero absurdo, derruba a frase);
  - citacao literal entre aspas (a partir de 20 caracteres) precisa existir, com a mesma grafia normalizada, em um dos trechos citados; citacao inventada derruba a frase;
  - titulos so sao aceitos quando sao os blocos pedidos; secao que fica sem frases desaparece;
  - "p. 210" e outras abreviacoes nao cortam a frase; citacoes depois do ponto pertencem a frase anterior.
- Exibicao: "Interpretacao assistida por IA", aviso de que o texto foi gerado por IA a partir apenas dos trechos do dossie, quantas frases foram removidas e a lista "Fontes citadas" com obra, pagina ou data e area. Se nada puder ser mantido, nada e exibido e o app avisa.
- Compartilhar e PDF levam o mesmo texto; o cabecalho antigo "Analise por IA" saiu para nao duplicar o titulo.
- Na tela: "Interpretacao assistida (opcional)", com a explicacao de que a IA recebe somente os N trechos exibidos e de que frases sem citacao sao removidas.
- A analise de IA das leituras diarias (comentarios) nao mudou nesta fase.

## Evidencias

| Verificacao | Resultado |
| --- | --- |
| Casos de referencia `Paridade/casos_ia_v1.json` (2 prompts e 4 respostas: citacoes validas, remocao de frase sem fonte, fonte inexistente e citacao inventada, resposta sem nada aproveitavel, numero de fonte gigante) - iOS `testAssistedInterpretationMatchesReferenceCases`, Android `assistedInterpretationMatchesReferenceCases` | Aprovados; identicos a referencia |
| Acervo real v2, dossie "Escada de Jacó": prompt montado nas duas plataformas | Identico byte a byte (35.574 caracteres, 30 trechos, todos contendo o tema) |
| Dossie no acervo real (`comparar_dossie_acervo.py`) | 13 secoes, 77 fontes, 0 diferencas |
| iOS unitarios | 80, 0 falhas |
| iOS interface do dossie (5 testes, inclusive dossie salvo) | Aprovados |
| Android `DataIntegrityTest`, `NavigationFlowTest`, `FullCatalogBenchmarkTest` | 40, 18 e 3, 0 falhas |
| Gate `Tools/verificar_paridade.sh` (agora tambem com `ia_referencia.py --check`) | 0 falhas |

## Limites conhecidos

- Nao houve chamada real ao Gemini nesta validacao: o teste ao vivo existente continua opcional e depende de uma chave configurada para teste. O filtro e deterministico e testado com respostas simuladas.
- A IA ainda pode parafrasear mal um trecho citado; o filtro garante fonte e citacoes literais, nao a fidelidade de uma parafrase. Por isso o aviso pede conferencia no original, e cada frase indica a fonte.
- Algumas paginas do acervo trazem ruido de OCR do PDF original (caracteres soltos); isso chega ao prompt como esta no texto.
