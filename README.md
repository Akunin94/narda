# narda

«Uzun narda» — длинные нарды для Android с узбекским интерфейсом, ботом,
hotseat-режимом и (в последней фазе) онлайном.

Правила и план фаз — в [SPEC.md](SPEC.md).

## Структура

```
packages/narda_core/   чистый Dart: состояние, правила, генератор ходов, бот
app/                   Flutter: доска на CustomPaint, экраны, локализация
app/store/             материалы Google Play: иконка, графика, тексты, политика
```

Приложение подключает ядро как path-зависимость. До фазы P4 в проекте нет Firebase.

## Статус

- **P1 — ядро и тесты**: готово.
- **P2 — играбельный оффлайн**: готово (бот трёх уровней, hotseat, доска на
  CustomPaint, тап и перетаскивание, отмена и подтверждение хода).
- **P3 — публикуемая оффлайн-версия**: готово (матчи до 3/5/7, статистика,
  звук и вибрация, обучение «Qoidalar», темы доски, реклама с UMP, иконка,
  графика и тексты стора).
- P4 — онлайн на Firebase.
- P5 — рейтинг, профили, таблица лидеров.

## Как проверить ядро

```bash
cd packages/narda_core
dart pub get
dart analyze                       # без замечаний
dart test                          # включая 10 000 property-партий (~40 с)
NARDA_PROPERTY_GAMES=200 dart test # быстрый прогон
```

Просмотр партии бот-против-бота в ASCII:

```bash
cd packages/narda_core
dart run bin/selfplay.dart --seed=42 --level=kuchli
dart run bin/selfplay.dart --games=100 --level=orta   # только сводка
```

## Как запустить приложение

```bash
cd app
flutter pub get
flutter analyze                    # без замечаний
flutter test                       # ход, геометрия доски, экраны, 20 партий подряд
flutter run                        # Android, portrait
```

Язык интерфейса — узбекский по умолчанию; русский включается, если он стоит в
языках устройства или выбран вручную в настройках.

## Ассеты: всё рисуется и синтезируется здесь

Ни одной заимствованной текстуры и ни одного чужого звука. Файлы закоммичены,
пересобирать нужно только после правки генераторов:

```bash
cd app
dart run tool/generate_sounds.dart      # assets/sounds/*.wav  (~140 КБ)
flutter test tool/generate_art.dart     # иконки mipmap-* и store/*.png
```

## Релизная сборка

Тестовые ad unit ID подставляются в debug автоматически; в релиз реальные
приходят снаружи (§P3). App id AdMob попадает в манифест через gradle:

```bash
cd app
flutter build appbundle --release \
  -Padmob_app_id=ca-app-pub-XXXX~YYYY \
  --dart-define=ADMOB_INTERSTITIAL=ca-app-pub-XXXX/AAAA \
  --dart-define=ADMOB_REWARDED=ca-app-pub-XXXX/BBBB
```

Без `--dart-define` реклама в релизе просто выключается. Ключ подписи берётся
из `app/android/key.properties` (в git не попадает), иначе — debug-ключ.

Размеры последней сборки: AAB 53,4 МБ, APK по ABI 17,2 / 19,9 / 21,3 МБ,
универсальный APK 44 МБ.

Порядок публикации и требование Google «12 тестировщиков × 14 дней» —
в [app/store/closed-testing-checklist.md](app/store/closed-testing-checklist.md).
