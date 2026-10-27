#!/usr/bin/env bash
# Сборка с журналом партии → установка по USB → запуск → запись журнала.
# Запуск: ./tool/dev_install.sh   (Ctrl+C — остановить запись журнала)
set -euo pipefail
cd "$(dirname "$0")/.."

PKG=uz.uzunnarda.narda
APK=build/app/outputs/flutter-apk/app-release.apk
LOG=../narda-game.log

flutter build apk --release \
  --dart-define-from-file=release.json \
  --dart-define=NARDA_GAME_LOG=true \
  -Padmob_app_id=ca-app-pub-1433969118220772~6892904840

echo "→ Установка (разблокируй телефон и подтверди окно Xiaomi)"
if ! out=$(adb install -r "$APK" 2>&1); then
  echo "$out"
  # Версия из Play подписана другим ключом — поверх не встанет.
  if [[ "$out" == *INSTALL_FAILED_UPDATE_INCOMPATIBLE* ]]; then
    echo "→ Другая подпись: удаляю старую версию"
    adb uninstall "$PKG"
    adb install "$APK"
  else
    exit 1
  fi
fi

adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
echo "→ Игра запущена, журнал пишется в narda-game.log (Ctrl+C — стоп)"
adb logcat -s flutter | grep --line-buffered NARDA | tee "$LOG"
