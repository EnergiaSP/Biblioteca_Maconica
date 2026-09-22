# Breviário Maçônico Android

Versão Android nativa criada para espelhar o app iOS do Breviário Maçônico.

## Estrutura

- Tecnologia: Kotlin + Jetpack Compose
- Conteúdo: `app/src/main/assets/breviario.json`
- Ícone: reaproveitado do app iOS em `app/src/main/res/drawable-nodpi/app_icon.png`
- Pacote Android: `com.renatocamargo.breviariomaconico`
- Versão inicial: `1.0.0 (1)`

## Recursos implementados nesta base

- Tela de ativação por código
- Gerador administrativo protegido pela senha local já usada no iOS
- Tela de abertura com ícone e nome do app
- Home com leitura do dia e atalhos
- Tela de leitura diária com texto integral e notas de rodapé
- Navegação anterior/próximo dia
- Favoritos
- Marcar leitura como lida
- Comentário pessoal por data
- Índice remissivo com links por data
- Breviário com busca por data ou texto
- Favoritos, não lidos e comentários em telas próprias
- Estatísticas
- Coleções temáticas
- Exportação de múltiplos dias
- Compartilhamento em texto
- Cópia para área de transferência
- Exportação PDF básica
- Configurações de tema, fonte, espaçamento, voz e notificação
- Notificação diária e teste em 5 segundos
- Widget Android com data, título e trecho do dia
- Backup/transferência das preferências locais do app

## Como abrir

1. Abra o Android Studio.
2. Escolha **Open**.
3. Selecione a pasta:

   `/Users/renatocamargo/Downloads/BreviarioMaconicoXXI_2/projetos/BreviarioMaconicoAndroid`

4. Aguarde o Gradle Sync.
5. Execute em um emulador ou aparelho Android.

## Como gerar arquivo para teste

No Android Studio:

1. **Build > Build Bundle(s) / APK(s) > Build APK(s)** para APK de teste.
2. **Build > Generate Signed Bundle / APK** para gerar AAB de publicação.

## Arquivo assinado para Google Play

O Android App Bundle de publicação já foi gerado e assinado:

`/Users/renatocamargo/Downloads/BreviarioMaconicoXXI_2/projetos/BreviarioMaconicoAndroid/app/build/outputs/bundle/release/app-release.aab`

As instruções completas de envio público estão em:

`/Users/renatocamargo/Downloads/BreviarioMaconicoXXI_2/projetos/BreviarioMaconicoAndroid/GOOGLE_PLAY_PUBLICACAO.md`

## Observações

Esta base Android usa o mesmo arquivo de conteúdo do iOS para preservar a fidelidade dos textos.
