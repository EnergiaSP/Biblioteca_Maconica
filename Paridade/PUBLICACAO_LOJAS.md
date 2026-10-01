# Textos de publicacao nas lojas

Textos para App Store Connect e Google Play Console, versão 1.0.16 (Fases 7 a 14). A publicação acontece pelas contas do responsável nas lojas.

Identificadores: iOS `com.renatocamargo.BreviarioMaconicoSeculoXXIPrivado` (app, widget e Apple Watch), versão 1.0.16 (build 2); Android e Wear OS `com.renatocamargo.breviariomaconico`, versão 1.0.16 (versionCode 16).

Os limites de caracteres de cada campo são conferidos por `Tools/verificar_textos_lojas.py`.

## Nome e subtítulo

<!-- campo: nome | limite: 30 -->
Biblioteca Maçônica
<!-- fim -->

<!-- campo: subtitulo | limite: 30 -->
Breviário, acervo e estudo
<!-- fim -->

<!-- campo: descricaoCurta | limite: 80 -->
Breviários diários, acervo offline, dossiês, prancha e trilhas de estudo.
<!-- fim -->

## Descrição

<!-- campo: descricao | limite: 4000 -->
Biblioteca Maçônica reúne a leitura diária e o estudo maçônico em um só lugar, com cada informação ligada à obra e à página de onde veio.

LEITURA DIÁRIA
• Breviário Maçônico do Século XXI e Breviário de Rizzardo da Camino, com a leitura de cada dia.
• Marque como lida, favorite, faça marcadores e anote reflexões e comentários.
• Ouça a leitura em voz alta ou uma coleção inteira em sequência.
• Widget na tela inicial e leitura no relógio (Apple Watch e Wear OS).

ACERVO PARA ESTUDO
• Centenas de obras organizadas por área, baixadas uma a uma ou todas de uma vez, para ler sem internet.
• Busca no acervo inteiro, com trecho e página de cada resultado, grafias equivalentes (Jacó e Jacob, Hiram e Hirão) e, se quiser, singular e plural juntos.
• Aviso de qualidade nas páginas com ruído de digitalização.
• Coleções e trilhas de estudo por tema.

DOSSIÊ E PRANCHA
• Escolha um tema e o app monta um dossiê só com trechos do acervo: definição, resumo, pontos divergentes, mapa do tema e perguntas.
• Salve o dossiê e receba lembretes de revisão espaçada.
• Monte a prancha a partir do dossiê: introdução, desenvolvimento por autor, conclusão e referências no padrão ABNT, com citação em cada trecho.
• Compare lado a lado como cada autor trata o tema.

REVISÃO ATIVA
• Cartões e perguntas criados a partir dos seus dossiês, com revisão espaçada.
• Revise os cartões também no relógio.

TRILHAS POR GRAU
• Trilhas de Aprendiz, Companheiro e Mestre, com etapas, progresso e obras sugeridas do acervo.

CADERNO DE ESTUDO
• Todas as suas anotações num só lugar: dossiês, marcadores, reflexões e comentários, com busca e organizadas por tema.
• Exporte e importe o caderno entre iPhone, iPad e Android sem perder nada: anotações diferentes ficam as duas.
• Sincronize pelo iCloud (iPhone e iPad) ou pelo Google Drive (Android).

INTERPRETAÇÃO ASSISTIDA (OPCIONAL)
• Com sua própria chave de IA, peça uma interpretação do dossiê.
• A IA recebe somente os trechos do dossiê; frases sem fonte são removidas e cada frase indica o trecho em que se apoia.
• A interpretação fica guardada com o dossiê.

ACESSIBILIDADE
• Textos que acompanham o tamanho de letra do sistema, leitores de tela e contraste verificados em todas as telas principais.

Seus dados ficam no aparelho, com cópia de segurança do sistema. Nada é enviado ao desenvolvedor.
<!-- fim -->

## Novidades da versão 1.0.16

App Store (até 4000 caracteres):

<!-- campo: novidadesAppStore | limite: 4000 -->
• Caderno de estudo: todas as anotações num só lugar, com busca e por tema; exportar, importar e sincronizar pelo iCloud.
• Prancha a partir do dossiê, com citações e referências no padrão ABNT e comparação entre autores.
• Trilhas de Aprendiz, Companheiro e Mestre, com progresso e obras sugeridas.
• Revisão ativa: cartões e perguntas com revisão espaçada, também no Apple Watch.
• Ouça uma coleção ou trilha inteira em sequência.
• Busca com grafias equivalentes e, se quiser, singular e plural juntos.
• Acervo com texto revisado e aviso de qualidade nas páginas com ruído de digitalização.
• A interpretação assistida por IA fica guardada com o dossiê.
• Melhorias de acessibilidade em todas as telas.
<!-- fim -->

Google Play (até 500 caracteres):

<!-- campo: novidadesGooglePlay | limite: 500 -->
• Caderno de estudo com busca, por tema, exportação e Google Drive
• Prancha do dossiê com referências ABNT
• Trilhas de Aprendiz, Companheiro e Mestre
• Revisão ativa com cartões, também no Wear OS
• Ouça coleções e trilhas em sequência
• Busca com grafias equivalentes e singular/plural
• Acervo revisado e aviso de qualidade do texto
• Acessibilidade verificada nas telas principais
<!-- fim -->

## Palavras-chave (App Store)

<!-- campo: palavrasChave | limite: 100 -->
maçonaria,breviário,maçom,loja,estudo,prancha,acervo,ritual,filosofia,simbolismo,aprendiz,mestre
<!-- fim -->

## Categorias

- App Store: Livros (secundária: Educação)
- Google Play: Livros e referências

## Privacidade e segurança de dados

- O desenvolvedor não coleta dados. Anotações, dossiês, cartões e progresso ficam no aparelho e na cópia de segurança do sistema.
- Sincronização do caderno, quando o usuário escolhe:
  - iCloud Drive (pasta do app na conta do usuário);
  - Google Drive (pasta privada do app na conta do usuário).
- A opção "Conta própria" (caderno cifrado no aparelho, guardado num servidor que não consegue lê-lo) só aparece depois que o servidor for publicado. Quando aparecer, o formulário de segurança de dados deve declarar o armazenamento de um arquivo cifrado, sem identificação pessoal.
- Interpretação assistida: a chave de IA fica no aparelho, e o texto do dossiê vai ao provedor de IA somente quando o usuário pede a interpretação.
- Classificação etária: livre (sem conteúdo gerado por outros usuários, sem compras, sem anúncios).

## Capturas de tela

Geradas por `Tools/gerar_capturas_lojas.sh` em `Publicacao/capturas/` (fora do Git):

- iPhone 6,9";
- iPad 13";
- Apple Watch;
- telefone Android;
- Wear OS.

Telas: Início, leitura diária, Coleções, Dossiê, Prancha, Trilhas por grau, Caderno de estudo e Acervo.

## Pendências antes de enviar

- [ ] AAB assinado do Android (precisa de `keystore.properties` e da chave de upload do responsável).
- [ ] Arquivo iOS pelo Xcode (Product > Archive) com a conta de desenvolvedor.
- [ ] URL da política de privacidade.
- [ ] Revisão final dos textos pelo responsável.
