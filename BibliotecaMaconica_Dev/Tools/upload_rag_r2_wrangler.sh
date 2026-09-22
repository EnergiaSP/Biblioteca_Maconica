#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUCKET="${R2_BUCKET:-biblioteca-maconica}"
PUBLIC_BASE_URL="${R2_PUBLIC_BASE_URL:-https://acervo.bibliotecamaconica.app/rag/v1}"
PACKAGES_DIR="$ROOT_DIR/ImportacaoLivrosPDF_OCR/_relatorios/RAGPackages"
CATALOG_FILE="$ROOT_DIR/Resources/rag_catalogo.json"

cd "$ROOT_DIR"

python3 -B "$ROOT_DIR/Tools/preparar_manifesto_r2.py" --base-url "$PUBLIC_BASE_URL"

if [[ ! -d "$PACKAGES_DIR" ]]; then
  echo "Pasta de pacotes nao encontrada: $PACKAGES_DIR" >&2
  exit 1
fi

total="$(find "$PACKAGES_DIR" -type f -name '*.sqlite' | wc -l | tr -d ' ')"
done_count=0

echo "Bucket: $BUCKET"
echo "Pacotes encontrados: $total"
echo "Destino publico previsto: $PUBLIC_BASE_URL"

find "$PACKAGES_DIR" -type f -name '*.sqlite' -print0 | sort -z | while IFS= read -r -d '' file; do
  rel="${file#$PACKAGES_DIR/}"
  key="rag/v1/$rel"
  done_count=$((done_count + 1))
  echo "[$done_count/$total] Enviando $rel"
  npx --yes wrangler@latest r2 object put "$BUCKET/$key" --file "$file" --remote
done

echo "Enviando manifesto rag/v1/manifest.json"
npx --yes wrangler@latest r2 object put "$BUCKET/rag/v1/manifest.json" --file "$CATALOG_FILE" --remote

echo "Upload concluido."
