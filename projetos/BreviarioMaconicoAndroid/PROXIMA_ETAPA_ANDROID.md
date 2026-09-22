# Próxima etapa para gerar APK/AAB

Este projeto Android já foi criado em:

`/Users/renatocamargo/Downloads/BreviarioMaconicoXXI_2/projetos/BreviarioMaconicoAndroid`

O ambiente local de linha de comando foi instalado em:

`/Users/renatocamargo/Downloads/BreviarioMaconicoXXI_2/.tools/android`

Inclui:

- JDK 17 Temurin
- Android SDK command-line tools
- Android SDK Platform 35
- Android SDK Build Tools 34/35
- Android Platform Tools
- Gradle 8.10.2

## Abrir no Android Studio

1. Instale o Android Studio:

   `https://developer.android.com/studio`

2. Ao abrir o Android Studio pela primeira vez, aceite instalar:

   - Android SDK
   - Android SDK Platform
   - Android SDK Build-Tools
   - Android Emulator, se for testar em simulador

3. Abra o projeto:

   **File > Open**

4. Selecione:

   `/Users/renatocamargo/Downloads/BreviarioMaconicoXXI_2/projetos/BreviarioMaconicoAndroid`

5. Aguarde o **Gradle Sync**.

## Gerar APK de teste

No Android Studio:

**Build > Build Bundle(s) / APK(s) > Build APK(s)**

Arquivo esperado:

`app/build/outputs/apk/debug/app-debug.apk`

Arquivo já gerado:

`/Users/renatocamargo/Downloads/BreviarioMaconicoXXI_2/projetos/BreviarioMaconicoAndroid/app/build/outputs/apk/debug/app-debug.apk`

## Gerar AAB para Google Play

No Android Studio:

**Build > Generate Signed Bundle / APK > Android App Bundle**

Arquivo esperado:

`app/build/outputs/bundle/release/app-release.aab`

Arquivo já gerado:

`/Users/renatocamargo/Downloads/BreviarioMaconicoXXI_2/projetos/BreviarioMaconicoAndroid/app/build/outputs/bundle/release/app-release.aab`

Observação: o AAB atual foi assinado com chave de upload própria e está pronto para ser enviado ao Google Play Console.

Arquivo de publicação:

`/Users/renatocamargo/Downloads/BreviarioMaconicoXXI_2/projetos/BreviarioMaconicoAndroid/app/build/outputs/bundle/release/app-release.aab`

Guia completo de envio público:

`/Users/renatocamargo/Downloads/BreviarioMaconicoXXI_2/projetos/BreviarioMaconicoAndroid/GOOGLE_PLAY_PUBLICACAO.md`

## Nome visual do app

Nas telas e navegação, o nome visual foi padronizado como:

`Breviário Maçônico`

O conteúdo da obra e os PDFs exportados preservam o nome completo quando ele faz parte do texto, documento ou metadados.
