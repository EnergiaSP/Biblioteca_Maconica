#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERIAL="${1:-emulator-5554}"
OUT="${2:-$ROOT/Paridade/evidencias/android-regressao}"
CLASSES="${3:-com.renatocamargo.breviariomaconico.DataIntegrityTest,com.renatocamargo.breviariomaconico.NavigationFlowTest}"
[[ "$SERIAL" == emulator-* ]] || { printf 'Este executor aceita somente emuladores de teste.\n' >&2; exit 2; }
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
export JAVA_HOME="$ROOT/.tools/android/jdk-17.0.20.1+1/Contents/Home"
export ANDROID_HOME="$ROOT/.tools/android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export GRADLE_USER_HOME="$ROOT/.tools/android/gradle-home"
ADB="$ANDROID_HOME/platform-tools/adb"
APP="$ROOT/projetos/BreviarioMaconicoAndroid"
[[ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed | tr -d '\r')" == 1 ]] || {
  printf 'Aguarde a inicializacao do emulador.\n' >&2; exit 2;
}
cd "$APP"
"$ROOT/.tools/android/gradle-8.10.2/bin/gradle" --offline --no-daemon --max-workers=2 \
  app:testDebugUnitTest app:assembleDebug app:assembleDebugAndroidTest > "$OUT/build.log" 2>&1
MAIN="app/build/outputs/apk/debug/app-debug.apk"
TEST="app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
shasum -a 256 "$MAIN" "$TEST" > "$OUT/apk-sha256.txt"
"$ADB" -s "$SERIAL" install --no-streaming -r -t "$MAIN" > "$OUT/install-app.log" 2>&1
"$ADB" -s "$SERIAL" install --no-streaming -r -t "$TEST" > "$OUT/install-tests.log" 2>&1
"$ADB" -s "$SERIAL" shell am instrument -w -e class "$CLASSES" \
  com.renatocamargo.breviariomaconico.test/androidx.test.runner.AndroidJUnitRunner > "$OUT/instrumentation.log" 2>&1
# Instrumentation can exit zero even when tests fail or the process crashes.
if rg -q 'FAILURES|INSTRUMENTATION_FAILED|Process crashed|INSTRUMENTATION_ABORTED' "$OUT/instrumentation.log" ||
   ! rg -q '^OK \([0-9]+ tests?\)' "$OUT/instrumentation.log"; then
  printf 'Regressao reprovada. Consulte %s\n' "$OUT/instrumentation.log" >&2
  exit 1
fi
printf 'Regressao concluida; confira casos ignorados e evidencias em %s\n' "$OUT"
