# narda

«Uzun narda» — длинные нарды для Android с узбекским интерфейсом, ботом,
hotseat-режимом и (в последней фазе) онлайном.

Правила и план фаз — в [SPEC.md](SPEC.md).

## Структура

```
packages/narda_core/   чистый Dart: состояние, правила, генератор ходов, бот
app/                   Flutter: доска на CustomPaint, экраны, локализация
```

Приложение подключает ядро как path-зависимость. До фазы P4 в проекте нет Firebase.

## Статус

- **P1 — ядро и тесты**: готово.
- **P2 — играбельный оффлайн**: готово (бот трёх уровней, hotseat, доска на
  CustomPaint, тап и перетаскивание, отмена и подтверждение хода).
- P3 — публикуемая оффлайн-версия.
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
flutter test                       # тесты сборки хода, геометрии доски и экрана
flutter run                        # Android, portrait, minSdk 23
```

Язык интерфейса берётся из языка устройства: русский — если он стоит в системе,
во всех остальных случаях узбекский.
