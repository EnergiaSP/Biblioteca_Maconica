#!/usr/bin/env bash
# Store screenshots of the Android phone (Paridade/PUBLICACAO_LOJAS.md), saved in Publicacao/capturas/android/.
# Runs StoreScreenshotsTest on the emulator with the collection installed, with a fixed status bar (demo mode).
#
#   bash Tools/gerar_capturas_android.sh [serial-do-emulador]
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ADB="$ROOT_DIR/.tools/android/sdk/platform-tools/adb"
SERIAL="${1:-emulator-5554}"
PACKAGE="com.renatocamargo.breviariomaconico"
OUT="$ROOT_DIR/Publicacao/capturas/android"
export ANDROID_SERIAL="$SERIAL"

demo() { "$ADB" shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
"$ADB" shell settings put global sysui_demo_allowed 1
demo enter
demo clock -e hhmm 0941
demo battery -e level 100 -e plugged false
demo network -e wifi show -e level 4 -e mobile show -e level 4
demo notifications -e visible false

"$ADB" shell run-as "$PACKAGE" rm -rf files/capturas
"$ADB" shell am instrument -w -e capturas 1 -e tema "${TEMA:-Acácia}" -e class "$PACKAGE.StoreScreenshotsTest" "$PACKAGE.test/androidx.test.runner.AndroidJUnitRunner" | tr -d '\r' | tail -3
mkdir -p "$OUT"
for name in $("$ADB" shell run-as "$PACKAGE" ls files/capturas | tr -d '\r'); do
  "$ADB" exec-out run-as "$PACKAGE" cat "files/capturas/$name" > "$OUT/$name"
done
demo exit
"$ADB" shell settings put global sysui_demo_allowed 0
ls "$OUT"
