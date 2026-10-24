# Чек-лист публикации в Google Play

Пакет приложения: `uz.uzunnarda.narda`. Его нельзя поменять после первой
загрузки в Play — всё остальное (код, тексты, графику) можно менять в любой момент.

Новый аккаунт разработчика-физлица получает production только после закрытого
теста: **не менее 12 тестировщиков, установивших приложение, 14 дней подряд**.

## 1. Аккаунты и ключи

- [ ] Play Console: аккаунт создан ($25), личность, адрес и телефон подтверждены.
- [ ] Ключ подписи (один раз, файл хранить вне репозитория и сделать бэкап):
      `keytool -genkey -v -keystore ~/keys/narda-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias narda`
- [ ] `cp android/key.properties.example android/key.properties`, вписать путь и пароли.
- [ ] Play App Signing включён при первой загрузке (Google хранит ключ
      приложения, наш — только загрузочный; потерянный загрузочный можно сбросить).

## 2. Firebase (онлайн)

- [ ] console.firebase.google.com → новый проект (например `uzun-narda`), тариф
      **Blaze** (на бесплатном Spark Realtime Database держит ~100 подключений;
      поставь бюджетный алерт на $5–10).
- [ ] Authentication → Sign-in method → **Anonymous** включить.
- [ ] Realtime Database → создать (регион europe-west1 ближе к Ташкенту).
- [ ] Project settings → Add app → Android, package `uz.uzunnarda.narda`.
      Из настроек приложения взять API key, App ID, Sender ID, Project ID, Database URL.
- [ ] `cd app && firebase deploy --only database --project <id проекта>`
      (нужен `npm i -g firebase-tools` и `firebase login`).

## 3. AdMob

- [ ] admob.google.com → приложение Android, получить **app id** (`~`) и два
      ad unit: interstitial и rewarded.
- [ ] Связать AdMob с приложением в Play после публикации (AdMob → App settings).
- [ ] По желанию: `app-ads.txt` на сайте разработчика (без него часть
      рекламодателей не покупает показы).

## 4. Сборка

- [ ] `cp release.example.json release.json`, вписать ключи Firebase и AdMob.
- [ ] `version` в `pubspec.yaml` поднимать на каждую загрузку (`+N` — versionCode).
- [ ] Сборка:
      ```bash
      cd app
      flutter analyze && flutter test
      flutter build appbundle --release --dart-define-from-file=release.json -Padmob_app_id=ca-app-pub-XXXX~YYYY
      ```
- [ ] AAB лежит в `build/app/outputs/bundle/release/app-release.aab`.

## 5. Проверка на телефоне (лучше бюджетном)

Поставить релизный APK тем же набором флагов (`flutter build apk --release ...`
и `adb install`), **не кликать по своей рекламе** — за это AdMob банит.

- [ ] Свежая установка → партия с ботом начинается в два тапа.
- [ ] 20 партий подряд с ботом без крэша и без нелегального хода.
- [ ] Interstitial только между партиями, ни разу во время партии.
- [ ] Rewarded открывает тему доски на 24 часа.
- [ ] Онлайн с двух телефонов: быстрый матч, комната по коду, фразы, сдача,
      реванш, рейтинг изменился у обоих, ник появился в таблице лидеров.
- [ ] Онлайн: выключить интернет на одном телефоне на 20 с и включить — партия
      продолжается.

## 6. Политика конфиденциальности

- [ ] Выложить `privacy.html` по постоянному публичному URL. Вариант: положить
      в репозиторий портфолио на GitHub Pages как `narda/privacy.html` →
      `https://akunin94.github.io/portfolio/narda/privacy.html`.
- [ ] URL открывается без входа и не отдаёт PDF.

## 7. Play Console → App content

- [ ] Privacy policy — URL из п. 6.
- [ ] Ads — **да, есть реклама**.
- [ ] App access — всё доступно без входа.
- [ ] Target audience — 13+ (или 18+), приложение **не для детей**.
- [ ] Content rating (IARC) — анкета: азартных игр на деньги нет, пользователи
      взаимодействуют (онлайн, ники, готовые фразы), свободного чата нет.
- [ ] Data safety (ниже).
- [ ] Account deletion — URL: `<URL политики>#delete`.

### Data safety

| Раздел | Ответ |
| --- | --- |
| Собираются ли данные? | Да |
| Шифруются при передаче? | Да |
| Можно запросить удаление? | Да (по e-mail, см. `#delete` в политике) |
| Personal info → Name | Ник. Собирается, не передаётся третьим лицам. Цель: App functionality. Необязательно — только для онлайна |
| Personal info → User IDs | Анонимный ID Firebase. Цель: App functionality. Необязательно |
| App activity → App interactions | Ходы, рейтинг, число партий онлайн. Цель: App functionality |
| Device or other IDs | Рекламный ID (AdMob). Цель: Advertising or marketing, Analytics. Передаётся: да (Google) |
| Данные детей | Нет |

## 8. Листинг

- [ ] Тексты из `listing-uz.md` и `listing-ru.md` (узбекский вычитан носителем).
- [ ] Иконка `icon-512.png`, feature graphic `feature-graphic-1024x500.png`.
- [ ] 4–8 скриншотов телефона (16:9 или 9:16, сторона ≥ 1080): меню, партия с
      ботом, онлайн-партия, таблица лидеров, «Qoidalar», темы.
- [ ] Категория Games → Board. Контактный e-mail.

## 9. Закрытый тест

- [ ] Трек *Closed testing*, список тестировщиков — Google-аккаунты (минимум 12,
      лучше 15–16 с запасом).
- [ ] Каждый принял приглашение по opt-in ссылке и **установил** приложение.
- [ ] Дата старта 14 дней: ______________
- [ ] Тестировщики не удаляют приложение все 14 дней.
- [ ] Обновления выкладываются в тот же трек сколько угодно раз — поднять
      `version`, собрать, загрузить; отсчёт 14 дней не сбрасывается.

## 10. Production

- [ ] После 14 дней — анкета на production-доступ (как тестировали, что
      поменяли по отзывам).
- [ ] После одобрения — продвинуть сборку из closed в production (можно
      staged rollout: 20% → 100%).
