// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_text.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppTextRu extends AppText {
  AppTextRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Длинные нарды';

  @override
  String get menuSubtitle => 'Узбекские нарды';

  @override
  String get menuPlayBot => 'Играть с ботом';

  @override
  String get menuPlayHotseat => 'На одном устройстве';

  @override
  String get menuSettings => 'Настройки';

  @override
  String get levelTitle => 'Уровень бота';

  @override
  String get levelOson => 'Лёгкий';

  @override
  String get levelOrta => 'Средний';

  @override
  String get levelKuchli => 'Сильный';

  @override
  String get settingAutoMove => 'Автоход';

  @override
  String get settingAutoMoveHint =>
      'Единственный возможный ход выполняется сам';

  @override
  String get settingShowPips => 'Счёт pip';

  @override
  String get settingShowPipsHint => 'Показывать счёт pip обоих игроков';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get statusRolling => 'Бросок костей';

  @override
  String get statusYourTurn => 'Ваш ход';

  @override
  String get statusThinking => 'Бот думает';

  @override
  String get statusWhiteTurn => 'Ход белых';

  @override
  String get statusBlackTurn => 'Ход чёрных';

  @override
  String get statusNoMoves => 'Хода нет';

  @override
  String get statusConfirmTurn => 'Подтвердите ход';

  @override
  String get hintSelectChecker => 'Выберите шашку';

  @override
  String get actionConfirm => 'Подтвердить';

  @override
  String get actionUndo => 'Отменить';

  @override
  String get actionResign => 'Сдаться';

  @override
  String get resignQuestion => 'Сдать партию?';

  @override
  String get actionYes => 'Да';

  @override
  String get actionNo => 'Нет';

  @override
  String get sideWhite => 'Белые';

  @override
  String get sideBlack => 'Чёрные';

  @override
  String get labelPip => 'pip';

  @override
  String get labelBorneOff => 'выброшено';

  @override
  String get resultYouWin => 'Вы выиграли!';

  @override
  String get resultYouLose => 'Вы проиграли';

  @override
  String get resultWhiteWins => 'Выиграли белые';

  @override
  String get resultBlackWins => 'Выиграли чёрные';

  @override
  String get resultOyin => 'Ойин — 1 очко';

  @override
  String get resultMars => 'Марс — 2 очка';

  @override
  String get resultByResign => 'Сдача партии';

  @override
  String get actionRematch => 'Ещё партия';

  @override
  String get actionMenu => 'Меню';

  @override
  String get menuRules => 'Правила';

  @override
  String get menuStats => 'Статистика';

  @override
  String get menuThemes => 'Оформление доски';

  @override
  String get matchTitle => 'Формат матча';

  @override
  String get matchSingle => 'Одна партия';

  @override
  String get settingLanguage => 'Язык';

  @override
  String get languageAuto => 'Как на устройстве';

  @override
  String get languageUz => 'Узбекский';

  @override
  String get languageRu => 'Русский';

  @override
  String get settingSound => 'Звук';

  @override
  String get settingSoundHint => 'Звуки костей, шашек и победы';

  @override
  String get settingVibration => 'Вибрация';

  @override
  String get settingVibrationHint => 'Отклик на бросок и перемещение';

  @override
  String get settingPrivacy => 'Настройки рекламы';

  @override
  String get actionResetStats => 'Сбросить статистику';

  @override
  String get resetStatsQuestion => 'Очистить статистику?';

  @override
  String get statsTitle => 'Статистика';

  @override
  String get statsGames => 'Партии';

  @override
  String get statsWins => 'Победы';

  @override
  String get statsWinRate => 'Процент побед';

  @override
  String get statsMarsWins => 'Марс — ваш';

  @override
  String get statsMarsLosses => 'Марс — соперника';

  @override
  String get statsMatches => 'Матчи';

  @override
  String get statsMatchWins => 'Выиграно матчей';

  @override
  String get statsEmpty => 'Пока не сыграно ни одной партии';

  @override
  String get statsNote => 'Учитываются только партии против бота';

  @override
  String get themesTitle => 'Оформление доски';

  @override
  String get themeKlassik => 'Классика';

  @override
  String get themeKokGumbaz => 'Синий купол';

  @override
  String get themeZar => 'Золото и орех';

  @override
  String get themeSelected => 'Выбрано';

  @override
  String get themeUnlockWatch => 'Открыть за ролик';

  @override
  String get themeAdsUnavailable => 'Реклама пока не готова';

  @override
  String get themeUnlockedHint => 'Просмотр ролика открывает тему на 24 часа';

  @override
  String get rulesTitle => 'Правила';

  @override
  String get rulesGoalTitle => 'Цель';

  @override
  String get rulesGoalBody =>
      'Проведите все 15 шашек по кругу в свой дом — пункты 1–6 — и выбросьте их раньше соперника. Битья нет, бара нет: шашки не сбиваются никогда.';

  @override
  String get rulesStartTitle => 'Старт и направление';

  @override
  String get rulesStartBody =>
      'В начале все 15 шашек стоят на голове. Обе стороны идут по кольцу в одну сторону, но их головы разнесены на полкруга — поэтому шашки не встречаются лоб в лоб.';

  @override
  String get rulesMoveTitle => 'Ход';

  @override
  String get rulesMoveBody =>
      'Бросаются два кубика: два перемещения, можно и одной шашкой подряд. Дубль даёт четыре перемещения. Вставать на пункт, где стоит хотя бы одна чужая шашка, нельзя; своих на пункте — сколько угодно.';

  @override
  String get rulesHeadTitle => 'Правило головы';

  @override
  String get rulesHeadBody =>
      'За один бросок с головы снимается только одна шашка. Исключение — самый первый бросок партии: при 6-6, 4-4 или 3-3 можно снять две.';

  @override
  String get rulesFullTitle => 'Полный ход';

  @override
  String get rulesFullBody =>
      'Ход обязан быть максимально длинным: нужно использовать оба числа, а при дубле — сколько получится из четырёх. Если играется только одно число — играется большее. Если ходов нет вовсе, ход пропускается.';

  @override
  String get rulesBlockTitle => 'Правило блока';

  @override
  String get rulesBlockBody =>
      'Нельзя выстроить шесть подряд занятых пунктов, если перед этим забором не осталось ни одной шашки соперника. Если хотя бы одна его шашка уже прошла вперёд — блок разрешён.';

  @override
  String get rulesBearOffTitle => 'Выброс';

  @override
  String get rulesBearOffBody =>
      'Когда все 15 шашек дома, начинается выброс: шашка с пункта k снимается точным числом k. Если выпавшее число больше самого дальнего занятого пункта — снимается шашка с него. Вместо выброса можно ходить внутри дома.';

  @override
  String get rulesResultTitle => 'Результат';

  @override
  String get rulesResultBody =>
      'Кто первым выбросил все 15 шашек — победил. Обычная победа — oyin, 1 очко; если соперник не выбросил ни одной — mars, 2 очка. Матч играется до 3, 5 или 7 очков.';

  @override
  String get labelScore => 'Счёт';

  @override
  String get actionNextGame => 'Следующая партия';

  @override
  String get actionNewMatch => 'Новый матч';

  @override
  String get matchWonTitle => 'Вы выиграли матч!';

  @override
  String get matchLostTitle => 'Вы проиграли матч';

  @override
  String get matchWhiteWins => 'Матч выиграли белые';

  @override
  String get matchBlackWins => 'Матч выиграли чёрные';

  @override
  String matchToPoints(int points) {
    return 'До $points очков';
  }

  @override
  String themeHoursLeft(int hours) {
    return 'Осталось $hours ч';
  }

  @override
  String themeMinutesLeft(int minutes) {
    return 'Осталось $minutes мин';
  }

  @override
  String get menuPlayOnline => 'Играть онлайн';

  @override
  String get onlineTitle => 'Онлайн';

  @override
  String get onlineQuickMatch => 'Быстрая игра';

  @override
  String get onlineCreateRoom => 'Создать комнату';

  @override
  String get onlineJoinRoom => 'Войти по коду';

  @override
  String get onlineCodeHint => '6-значный код';

  @override
  String get onlineShareCode => 'Продиктуйте код сопернику';

  @override
  String get onlineWaitingTitle => 'Ждём соперника';

  @override
  String get onlineSearching => 'Ищем соперника';

  @override
  String get onlineConnecting => 'Подключаемся';

  @override
  String get onlineCancelSearch => 'Остановить';

  @override
  String get onlineBotOffer =>
      'Соперник не нашёлся. Сыграть с ботом, пока ищем?';

  @override
  String get onlineFairPlay =>
      'В онлайне только живые игроки: бот никогда не выдаётся за человека.';

  @override
  String get onlineNotConfigured => 'Онлайн ещё не настроен';

  @override
  String get onlineNetworkError => 'Нет связи';

  @override
  String get onlineNoRoom => 'Комната с таким кодом не найдена';

  @override
  String get onlineRoomFull => 'В комнате уже двое';

  @override
  String get onlineOpponentLabel => 'Соперник';

  @override
  String get onlineOpponentTurn => 'Ход соперника';

  @override
  String get onlineOpponentOffline => 'Соперник не в сети';

  @override
  String get onlineClaimWin => 'Забрать победу';

  @override
  String get onlineAborted => 'Партия аннулирована';

  @override
  String get onlineAbortedDesync => 'Состояния партии разошлись';

  @override
  String get onlineAbortedConnection => 'Связь потеряна';

  @override
  String get onlinePhrasesTitle => 'Фразы';

  @override
  String get phraseSalom => 'Салом!';

  @override
  String get phraseYaxshiYurish => 'Хороший ход!';

  @override
  String get phraseOmad => 'Удачи!';

  @override
  String get phraseRahmat => 'Спасибо, хорошая игра';

  @override
  String onlineSecondsLeft(int seconds) {
    return '$seconds с';
  }
}
