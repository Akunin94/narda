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

# Все телефоны, подключённые по USB и разрешившие отладку.
DEVICES=($(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'))
if (( ${#DEVICES[@]} == 0 )); then
  echo "Нет телефонов: подключи по USB и разреши отладку" >&2
  exit 1
fi

for d in "${DEVICES[@]}"; do
  echo "→ Установка на $d (разблокируй телефон и подтверди окно Xiaomi)"
  if ! out=$(adb -s "$d" install -r "$APK" 2>&1); then
    echo "$out"
    # Версия из Play подписана другим ключом — поверх не встанет.
    if [[ "$out" == *INSTALL_FAILED_UPDATE_INCOMPATIBLE* ]]; then
      echo "→ Другая подпись: удаляю старую версию на $d"
      adb -s "$d" uninstall "$PKG"
      adb -s "$d" install "$APK"
    else
      exit 1
    fi
  fi
  adb -s "$d" logcat -c
  adb -s "$d" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
done

echo "→ Игра запущена на ${#DEVICES[@]} телефон(ах), журнал пишется в narda-game.log (Ctrl+C — стоп)"
# Строки журнала помечаются серийным номером телефона.
for d in "${DEVICES[@]}"; do
  adb -s "$d" logcat -s flutter | grep --line-buffered NARDA | sed -u "s/^/[$d] /" &
done | tee "$LOG"
