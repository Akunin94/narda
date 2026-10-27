# Частые команды. Запуск из корня репозитория: make <цель>.
ADMOB_APP_ID := ca-app-pub-1433969118220772~6892904840
RELEASE := --release --dart-define-from-file=release.json -Padmob_app_id=$(ADMOB_APP_ID)

.PHONY: dev check aab

# Сборка с журналом → установка по USB → запуск → журнал в narda-game.log.
dev:
	app/tool/dev_install.sh

# Анализ и тесты ядра и приложения.
check:
	cd packages/narda_core && dart analyze && NARDA_PROPERTY_GAMES=200 dart test
	cd app && flutter analyze && flutter test

# Бандл для Google Play (версию в app/pubspec.yaml поднять заранее).
aab:
	cd app && flutter build appbundle $(RELEASE) && open build/app/outputs/bundle/release
