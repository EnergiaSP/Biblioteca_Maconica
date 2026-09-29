# Textos de publicacao nas lojas (rascunho)

Rascunho para App Store Connect e Google Play Console. A publicacao so acontece depois da Fase 14 concluida e pelas contas do responsavel nas lojas.

Identificadores: iOS `com.renatocamargo.BreviarioMaconicoSeculoXXIPrivado` (app, widget e Apple Watch); Android e Wear OS `com.renatocamargo.breviariomaconico` (versionCode 16).

## Nome e subtitulo

- Nome: Biblioteca Maçônica
- Subtitulo (App Store, ate 30): Breviário, acervo e estudo
- Descricao curta (Google Play, ate 80): Breviários diários, acervo maçônico offline e dossiês de estudo com fontes.

## Descricao

Biblioteca Maçônica reúne leitura diária e estudo em um só lugar.

Leitura diária
• Breviário Maçônico do Século XXI e Breviário de Rizzardo da Camino, com a leitura de cada dia.
• Marque como lida, favorite, anote reflexões e comentários.
• Widget na tela inicial e leitura no relógio (Apple Watch e Wear OS).

Acervo para estudo
• Centenas de obras organizadas por área, baixadas uma a uma ou todas de uma vez, para leitura sem internet.
• Busca no acervo inteiro, com trecho e página de cada resultado.
• Coleções de estudo por tema.

Dossiê de estudo
• Escolha um tema e o app monta um dossiê só com trechos do acervo, cada um com obra e página.
• Salve dossiês, receba lembretes de revisão, compartilhe ou gere PDF.

Interpretação assistida (opcional)
• Com sua própria chave de IA, peça uma interpretação do dossiê.
• A IA recebe somente os trechos do dossiê; frases sem fonte são removidas e cada frase indica o trecho em que se apoia.

Seus dados ficam no aparelho, com cópia de segurança do sistema.

## Novidades (base 1.0.16; completar com as Fases 8 a 14)

- Acervo com texto revisado: palavras partidas pela digitalização foram corrigidas; os pacotes instalados mostram "Atualização disponível".
- Dossiê de estudo: salvar, reabrir, lembretes de revisão, compartilhar e PDF.
- Interpretação assistida por IA com fonte em cada frase.
- Busca mais rápida e tela inicial ajustada a textos grandes.
- Leituras do Breviário de Rizzardo também no relógio.

## Palavras-chave (App Store, ate 100 caracteres)

maçonaria,breviário,maçom,loja,estudo,leitura diária,biblioteca,ritual,filosofia,simbolismo

## Categorias

- App Store: Livros (secundaria: Educação)
- Google Play: Livros e referências

## Pendencias antes de enviar

- [ ] AAB assinado do Android (precisa de `keystore.properties` e da chave de upload do responsavel).
- [ ] Arquivo iOS pelo Xcode (Product > Archive) com a conta de desenvolvedor.
- [ ] Capturas de tela reais (iPhone 6,9", iPad 13", Apple Watch, telefone Android, Wear OS).
- [ ] Classificacao etaria e formulario de seguranca de dados (Google Play) / privacidade (App Store): sem coleta pelo desenvolvedor; a chave de IA opcional fica no aparelho e o texto do dossie vai ao provedor de IA somente quando o usuario pede a interpretacao.
- [ ] URL da politica de privacidade.
