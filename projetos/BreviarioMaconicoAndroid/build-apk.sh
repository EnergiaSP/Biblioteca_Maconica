#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

ROOT_DIR="$(cd ../.. && pwd)"
export JAVA_HOME="$ROOT_DIR/.tools/android/jdk-17.0.20.1+1/Contents/Home"
export ANDROID_HOME="$ROOT_DIR/.tools/android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export GRADLE_USER_HOME="$ROOT_DIR/.tools/android/gradle-home"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ROOT_DIR/.tools/android/gradle-8.10.2/bin:$PATH"

if [[ -x "./gradlew" ]]; then
  ./gradlew assembleDebug
else
  "$ROOT_DIR/.tools/android/gradle-8.10.2/bin/gradle" assembleDebug
fi

echo "APK gerado em: app/build/outputs/apk/debug/app-debug.apk"
