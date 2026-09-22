#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IOS_BREVIARIO="$ROOT_DIR/BibliotecaMaconica_Dev/Resources/breviario.json"
ANDROID_BREVIARIO="$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/src/main/assets/breviario.json"
IOS_CATALOGO="$ROOT_DIR/BibliotecaMaconica_Dev/Resources/rag_catalogo.json"
ANDROID_CATALOGO="$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/src/main/assets/rag_catalogo.json"

falhar() {
  echo "FALHA: $1" >&2
  exit 1
}

cmp -s "$IOS_BREVIARIO" "$ANDROID_BREVIARIO" || falhar "breviario.json divergiu entre iOS e Android."
cmp -s "$IOS_CATALOGO" "$ANDROID_CATALOGO" || falhar "rag_catalogo.json divergiu entre iOS e Android."

IOS_VERSION="$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' "$ROOT_DIR/BibliotecaMaconica_Dev/BreviarioMaconicoXXI.xcodeproj/project.pbxproj" | head -n 1)"
ANDROID_VERSION="$(sed -n 's/.*versionName = "\([^"]*\)".*/\1/p' "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/build.gradle.kts" | head -n 1)"

[[ -n "$IOS_VERSION" ]] || falhar "Versão iOS não encontrada."
[[ -n "$ANDROID_VERSION" ]] || falhar "Versão Android não encontrada."
[[ "$IOS_VERSION" == "$ANDROID_VERSION" ]] || falhar "Versões diferentes: iOS $IOS_VERSION e Android $ANDROID_VERSION."

grep -q 'local_pdf_ocr_import' "$ROOT_DIR/Paridade/contrato-paridade.json" || falhar "Contrato incompleto."
grep -q 'structured_fts_search' "$ROOT_DIR/Paridade/contrato-paridade.json" || falhar "Contrato incompleto."
grep -q 'secure_api_key_storage' "$ROOT_DIR/Paridade/contrato-paridade.json" || falhar "Contrato incompleto."

grep -q 'GeminiAPIKeyStore' "$ROOT_DIR/BibliotecaMaconica_Dev/Services/CommentsService.swift" || falhar "Cofre da chave Gemini ausente no iOS."
grep -q 'class SecureKeyStore' "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/src/main/java/com/renatocamargo/breviariomaconico/data/SecureKeyStore.kt" || falhar "Cofre da chave Gemini ausente no Android."
grep -q 'CREATE VIRTUAL TABLE IF NOT EXISTS rag_fts USING fts5' "$ROOT_DIR/BibliotecaMaconica_Dev/Services/BibliotecaSQLiteService.swift" || falhar "Busca FTS5 ausente no iOS."
grep -q 'WHERE rag_fts MATCH' "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/src/main/java/com/renatocamargo/breviariomaconico/data/BibliotecaCatalog.kt" || falhar "Busca FTS ausente no Android."
grep -Rq --include='*.swift' 'Minha reflexão de hoje' "$ROOT_DIR/BibliotecaMaconica_Dev/Views" || falhar "Reflexão pessoal ausente no iOS."
grep -Rq --include='*.kt' 'Minha reflexão de hoje' "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/src/main/java/com/renatocamargo/breviariomaconico" || falhar "Reflexão pessoal ausente no Android."
grep -q 'notificationWorkIds' "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/src/main/java/com/renatocamargo/breviariomaconico/data/Models.kt" || falhar "Notificação multiobra ausente no Android."
grep -q '"android": "native_mlkit"' "$ROOT_DIR/Paridade/contrato-paridade.json" || falhar "OCR Android ainda não foi declarado nativo."
! grep -q '"android": "planned"' "$ROOT_DIR/Paridade/contrato-paridade.json" || falhar "Contrato ainda contém capacidade Android planejada."
grep -q 'class LocalPdfOcrImporter' "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/src/main/java/com/renatocamargo/breviariomaconico/data/LocalPdfOcrImporter.kt" || falhar "Importador OCR local ausente no Android."
grep -q 'CREATE VIRTUAL TABLE rag_fts USING fts5' "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/src/main/java/com/renatocamargo/breviariomaconico/data/LocalPdfOcrImporter.kt" || falhar "OCR Android não gera índice FTS."
grep -q 'include(":wear")' "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/settings.gradle.kts" || falhar "Módulo Wear OS ausente."
grep -q 'android.hardware.type.watch' "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/wear/src/main/AndroidManifest.xml" || falhar "Manifesto Wear OS inválido."
grep -q 'Marcar' "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/wear/src/main/java/com/renatocamargo/breviariomaconico/wear/WearMainActivity.kt" || falhar "Marcação de leitura ausente no Wear OS."
grep -q 'WatchProgressService' "$ROOT_DIR/BibliotecaMaconica_Dev/Watch/BreviarioWatchApp.swift" || falhar "Marcação de leitura ausente no watchOS."

python3 "$ROOT_DIR/Tools/sincronizar_regras_estudo.py" --check || falhar "Regras ou casos de teste comuns divergentes."
python3 "$ROOT_DIR/Tools/auditar_paridade_profunda.py" "$@" || falhar "Auditoria de conteúdo, capacidades ou liberação encontrou pendências."

echo "Paridade estrutural validada para a versão $IOS_VERSION."
echo "Conteúdo compartilhado: idêntico."
echo "Contrato e capacidades críticas: presentes e válidos."
echo "Esta verificacao e estrutural: nao comprova equivalencia funcional ou visual."
echo "Para liberar: executar testes nas duas plataformas e revisar as diferencas do relatorio de auditoria."
