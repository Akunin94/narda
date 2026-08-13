# narda

«Uzun narda» — длинные нарды для Android с узбекским интерфейсом, ботом,
hotseat-режимом и (в последней фазе) онлайном.

Правила и план фаз — в [SPEC.md](SPEC.md).

## Структура

```
packages/narda_core/   чистый Dart: состояние, правила, генератор ходов, бот
```

Flutter-приложение появится в фазе P2 и подключит ядро как path-зависимость.
До фазы P4 в проекте нет Firebase.

## Статус

- **P1 — ядро и тесты**: готово.
- P2 — играбельный оффлайн (доска на CustomPaint, бот, hotseat).
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
