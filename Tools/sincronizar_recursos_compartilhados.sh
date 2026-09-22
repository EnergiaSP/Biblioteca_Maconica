#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cp "$ROOT_DIR/BibliotecaMaconica_Dev/Resources/breviario.json" \
   "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/src/main/assets/breviario.json"

cp "$ROOT_DIR/BibliotecaMaconica_Dev/Resources/rag_catalogo.json" \
   "$ROOT_DIR/projetos/BreviarioMaconicoAndroid/app/src/main/assets/rag_catalogo.json"

"$ROOT_DIR/Tools/verificar_paridade.sh"
echo "Recursos compartilhados sincronizados com sucesso."
