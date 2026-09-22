#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-$ROOT/Tools/r2.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Arquivo de ambiente nao encontrado: $ENV_FILE"
  echo "Copie Tools/r2.env.example para Tools/r2.env e preencha as credenciais do R2."
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

: "${R2_ACCOUNT_ID:?Informe R2_ACCOUNT_ID}"
: "${R2_ACCESS_KEY_ID:?Informe R2_ACCESS_KEY_ID}"
: "${R2_SECRET_ACCESS_KEY:?Informe R2_SECRET_ACCESS_KEY}"
: "${R2_BUCKET:?Informe R2_BUCKET}"
: "${R2_PUBLIC_BASE_URL:?Informe R2_PUBLIC_BASE_URL}"

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="auto"

ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
PACKAGES="$ROOT/ImportacaoLivrosPDF_OCR/_relatorios/RAGPackages"
CATALOG="$ROOT/Resources/rag_catalogo.json"

python3 -B "$ROOT/Tools/preparar_manifesto_r2.py" --base-url "$R2_PUBLIC_BASE_URL"

aws s3 sync "$PACKAGES" "s3://${R2_BUCKET}/rag/v1" \
  --endpoint-url "$ENDPOINT" \
  --size-only \
  --content-type application/vnd.sqlite3

aws s3 cp "$CATALOG" "s3://${R2_BUCKET}/rag/v1/manifest.json" \
  --endpoint-url "$ENDPOINT" \
  --content-type application/json

echo "Upload concluido: ${R2_PUBLIC_BASE_URL}/manifest.json"
