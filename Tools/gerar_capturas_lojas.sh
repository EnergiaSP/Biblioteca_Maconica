#!/usr/bin/env bash
# Store screenshots of iPhone 6.9" and iPad 13" (Paridade/PUBLICACAO_LOJAS.md), saved in Publicacao/capturas/.
# Each simulator gets the whole collection installed where the app keeps it (Application Support, with
# the .sha256 version markers of the catalog), a fixed status bar (9:41, full battery) and runs
# testStoreScreenshots, whose attachments are exported here.
#
#   bash Tools/gerar_capturas_lojas.sh
#   SOMENTE=iphone-6.9 bash Tools/gerar_capturas_lojas.sh   # one device only
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/BibliotecaMaconica_Dev/BreviarioMaconicoXXI.xcodeproj"
BUNDLE="com.renatocamargo.BreviarioMaconicoSeculoXXIPrivado"
PACKAGES="$ROOT_DIR/BibliotecaMaconica_Dev/ImportacaoLivrosPDF_OCR/_relatorios/RAGPackages"
OUT="$ROOT_DIR/Publicacao/capturas"
WORK="$(mktemp -d)"
DERIVED="$WORK/derived"

# name|simulator
DEVICES=(
  "iphone-6.9|$(xcrun simctl list devices available | sed -n 's/.*iPhone 17 Pro Max (\([0-9A-F-]*\)).*/\1/p' | head -1)"
  "ipad-13|$(xcrun simctl list devices available | sed -n 's/.*iPad Pro 13-inch (M5) (\([0-9A-F-]*\)).*/\1/p' | head -1)"
)

[[ -d "$PACKAGES" ]] || { echo "Pacotes do acervo não encontrados: $PACKAGES" >&2; exit 1; }
# Version markers as the app writes after a download: the catalog's sha256 of each package.
MARKERS="$WORK/marcadores"
python3 - "$ROOT_DIR/BibliotecaMaconica_Dev/Resources/rag_catalogo.json" "$MARKERS" <<'EOF'
import json, sys
from pathlib import Path
catalog, target = json.load(open(sys.argv[1])), Path(sys.argv[2])
for package in catalog["pacotes"]:
    marker = target / (package["arquivo"] + ".sha256")
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(package["sha256"])
EOF

xcodebuild build-for-testing -project "$PROJECT" -scheme BibliotecaMaconicaUITests \
  -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" -quiet
APP="$(find "$DERIVED/Build/Products" -maxdepth 2 -name 'BreviarioMaconicoXXI.app' | head -1)"
XCTESTRUN="$(find "$DERIVED/Build/Products" -name '*.xctestrun' | head -1)"

for entry in "${DEVICES[@]}"; do
  name="${entry%%|*}"; udid="${entry##*|}"
  [[ -z "${SOMENTE:-}" || "$SOMENTE" == "$name" ]] || continue
  [[ -n "$udid" ]] || { echo "Simulador não encontrado: $name" >&2; exit 1; }
  echo "== $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3
  xcrun simctl install "$udid" "$APP"
  data="$(xcrun simctl get_app_container "$udid" "$BUNDLE" data)"
  installed="$data/Library/Application Support/BreviarioMaconicoXXI/RAGPackages"
  mkdir -p "$installed"
  rsync -a --exclude imported_works.json "$PACKAGES/" "$installed/"
  rsync -a "$MARKERS/" "$installed/"
  result="$WORK/$name.xcresult"
  TEST_RUNNER_CAPTURAS=1 xcodebuild test-without-building -xctestrun "$XCTESTRUN" \
    -destination "id=$udid" -only-testing:BibliotecaMaconicaUITests/BibliotecaMaconicaUITests/testStoreScreenshots \
    -resultBundlePath "$result" -quiet || echo "Teste de capturas falhou em $name; as capturas feitas são exportadas."
  xcrun xcresulttool export attachments --path "$result" --output-path "$WORK/$name" >/dev/null
  mkdir -p "$OUT/$name"
  python3 - "$WORK/$name" "$OUT/$name" <<'EOF'
import json, shutil, sys
from pathlib import Path
source, target = Path(sys.argv[1]), Path(sys.argv[2])
count = 0
for test in json.loads((source / "manifest.json").read_text()):
    for attachment in test.get("attachments", []):
        title = attachment.get("suggestedHumanReadableName", "")
        if title.startswith("loja-"):
            name = title[len("loja-"):].split("_")[0]
            shutil.copy(source / attachment["exportedFileName"], target / f"{name}.png")
            count += 1
print(f"{count} captura(s) em {target}")
EOF
  xcrun simctl status_bar "$udid" clear
done
rm -rf "$WORK"
