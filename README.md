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

Приложение подключает ядро как path-зависимость.

## Статус

- **P1 — ядро и тесты**: готово.
- **P2 — играбельный оффлайн**: готово (бот трёх уровней, hotseat, доска на
  CustomPaint, тап и перетаскивание, отмена и подтверждение хода).
- **P3 — публикуемая оффлайн-версия**: готово (матчи до 3/5/7, статистика,
  звук и вибрация, обучение «Qoidalar», темы доски, реклама с UMP, иконка,
  графика и тексты стора).
- **P4 — онлайн на Firebase**: готово (быстрый матч, приватная комната по коду,
  таймер хода, реконнект реплеем, готовые фразы).
- **P5 — рейтинг, профили, таблица лидеров, реванш**: готово.

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

## Онлайн (P4)

Ключи Firebase в репозиторий не кладутся: приложение берёт их из
`--dart-define`, а не из `google-services.json`. Без ключей меню открывается,
онлайн честно пишет «Onlayn hali sozlanmagan», всё остальное работает.

```bash
cd app
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=1:000000000000:android:0000000000000000 \
  --dart-define=FIREBASE_SENDER_ID=000000000000 \
  --dart-define=FIREBASE_PROJECT_ID=uzun-narda \
  --dart-define=FIREBASE_DATABASE_URL=https://uzun-narda-default-rtdb.firebaseio.com
```

Что нужно завести в проекте Firebase: анонимную авторизацию и Realtime
Database. Правила базы лежат в
[app/firebase/database.rules.json](app/firebase/database.rules.json) —
`firebase deploy --only database`.

Схема комнаты — в шапке [app/lib/online/protocol.dart](app/lib/online/protocol.dart).
Кости в v1 генерирует клиент активного игрока (честное ограничение MVP по спеке);
точка замены на серверные — `DiceSource` в ядре. Правила базы не могут проверить
легальность хода, поэтому её проверяют оба клиента через `narda_core`:
нелегальный ход или расхождение слепка позиции приводят к пересборке реплеем
журнала, а если и реплей нелегален — партия аннулируется.

Онлайн проверяется без сети: `MemoryOnlineServer` поднимает комнаты в памяти
процесса, и два клиента играют партию целиком в `flutter test`.

## Рейтинг и профили (P5)

Профиль — ник и аватар из набора; аватары рисуются кодом
([app/lib/ui/avatar.dart](app/lib/ui/avatar.dart)), ассетов у них нет. Ник,
аватар и рейтинг едут в комнату вместе с игроком и видны сопернику на доске.

Рейтинг Elo ([app/lib/profile/elo.dart](app/lib/profile/elo.dart)) меняется
**только за онлайн-матчи** — партии с ботом не рейтинговые, иначе рейтинг
накручивался бы тренировкой. Считается по итогу матча целиком (одиночная
партия или серия до 3 / 5 / 7), K = 40 для новичка, 32 обычно и 20 с 2000
очков. Оба клиента берут рейтинги из записей комнаты и приходят к одному и
тому же числу, а потом каждый пишет свою строку `users/{uid}` — как и с
костями (§6), это честное ограничение MVP: серверный пересчёт в Cloud
Function остаётся в backlog, точка замены — `RatingService`. Правила базы
режут диапазон рейтинга и шаг одной записи.

Реванш после доигранного матча — по обоюдному согласию: каждый пишет
`rematch/{uid}`, и новый матч в той же комнате начинается, только когда
согласны оба.

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
