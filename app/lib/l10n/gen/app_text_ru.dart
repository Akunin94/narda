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
}
