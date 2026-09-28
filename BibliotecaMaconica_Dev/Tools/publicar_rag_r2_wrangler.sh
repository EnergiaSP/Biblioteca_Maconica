#!/usr/bin/env bash
# Publica os pacotes RAG no R2 usando o login do wrangler (sem r2.env).
#
# Uso: Tools/publicar_rag_r2_wrangler.sh [bucket]
#
# - Le a versao (rag/vN) do baseURL de Resources/rag_catalogo.json; a versao
#   anterior continua publicada para os apps ja instalados.
# - Envia cada pacote de ImportacaoLivrosPDF_OCR/_relatorios/RAGPackages e
#   confere pela URL publica (ETag = MD5 do arquivo). Pode ser executado de
#   novo: o que ja esta publicado e igual e pulado.
# - O manifest.json so e enviado depois de todos os pacotes conferidos.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUCKET="${1:-biblioteca-maconica}"
PACKAGES="$ROOT/ImportacaoLivrosPDF_OCR/_relatorios/RAGPackages"
CATALOG="$ROOT/Resources/rag_catalogo.json"
WRANGLER="${WRANGLER:-npx wrangler}"

BASE_URL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["baseURL"].rstrip("/"))' "$CATALOG")"
PREFIX="${BASE_URL#https://*/}"
[[ "$PREFIX" == rag/v* ]] || { echo "baseURL inesperado: $BASE_URL"; exit 1; }

publicado() {
  local url="$1" md5="$2"
  curl -sfI "$url" | tr -d '\r' | grep -qi "^etag: \"$md5\""
}

python3 - "$CATALOG" "$PACKAGES" <<'EOF'
import hashlib, json, os, sys
catalog, packages = sys.argv[1:]
erros = 0
for p in json.load(open(catalog))["pacotes"]:
    f = os.path.join(packages, p["arquivo"])
    if not os.path.exists(f) or os.path.getsize(f) != p["tamanhoBytes"]:
        print("Pacote ausente ou com tamanho diferente do catalogo:", p["arquivo"]); erros += 1
        continue
    h = hashlib.sha256(open(f, "rb").read()).hexdigest()
    if h != p["sha256"]:
        print("SHA-256 diferente do catalogo:", p["arquivo"]); erros += 1
sys.exit(1 if erros else 0)
EOF
echo "Pacotes locais conferidos com o catalogo."

ARQUIVOS=()
while IFS= read -r linha; do ARQUIVOS+=("$linha"); done < <(
  python3 -c 'import json,sys; [print(p["arquivo"]) for p in json.load(open(sys.argv[1]))["pacotes"]]' "$CATALOG"
)
TOTAL=${#ARQUIVOS[@]}
N=0
for arquivo in "${ARQUIVOS[@]}"; do
  N=$((N + 1))
  local_file="$PACKAGES/$arquivo"
  md5="$(md5 -q "$local_file")"
  url="$BASE_URL/$arquivo"
  if publicado "$url" "$md5"; then
    echo "$N/$TOTAL ja publicado: $arquivo"
    continue
  fi
  echo "$N/$TOTAL enviando: $arquivo"
  $WRANGLER r2 object put "$BUCKET/$PREFIX/$arquivo" --file "$local_file" \
    --content-type application/vnd.sqlite3 --remote >/dev/null
  publicado "$url" "$md5" || { echo "Falha ao conferir $url"; exit 1; }
done

$WRANGLER r2 object put "$BUCKET/$PREFIX/manifest.json" --file "$CATALOG" \
  --content-type application/json --remote >/dev/null
publicado "$BASE_URL/manifest.json" "$(md5 -q "$CATALOG")" || { echo "Falha ao conferir manifest.json"; exit 1; }
echo "Publicacao concluida: $BASE_URL/manifest.json ($TOTAL pacotes)"
