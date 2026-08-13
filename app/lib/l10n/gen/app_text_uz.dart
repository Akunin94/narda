// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_text.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppTextUz extends AppText {
  AppTextUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Uzun narda';

  @override
  String get menuSubtitle => 'Uzbek nardasi';

  @override
  String get menuPlayBot => 'Bot bilan o\'ynash';

  @override
  String get menuPlayHotseat => 'Bitta qurilmada';

  @override
  String get menuSettings => 'Sozlamalar';

  @override
  String get levelTitle => 'Bot darajasi';

  @override
  String get levelOson => 'Oson';

  @override
  String get levelOrta => 'O\'rta';

  @override
  String get levelKuchli => 'Kuchli';

  @override
  String get settingAutoMove => 'Avto-yurish';

  @override
  String get settingAutoMoveHint =>
      'Yagona variant qolganda yurish o\'zi bajariladi';

  @override
  String get settingShowPips => 'Pip hisobi';

  @override
  String get settingShowPipsHint => 'Ikkala tomonning pip hisobi ko\'rsatiladi';

  @override
  String get actionClose => 'Yopish';

  @override
  String get statusRolling => 'Zar tashlash';

  @override
  String get statusYourTurn => 'Sizning yurishingiz';

  @override
  String get statusThinking => 'Bot o\'ylayapti';

  @override
  String get statusWhiteTurn => 'Oq toshlar yuradi';

  @override
  String get statusBlackTurn => 'Qora toshlar yuradi';

  @override
  String get statusNoMoves => 'Yurish yo\'q';

  @override
  String get statusConfirmTurn => 'Yurishni tasdiqlang';

  @override
  String get hintSelectChecker => 'Toshni tanlang';

  @override
  String get actionConfirm => 'Tasdiqlash';

  @override
  String get actionUndo => 'Bekor qilish';

  @override
  String get actionResign => 'Taslim bo\'lish';

  @override
  String get resignQuestion => 'Partiyada taslim bo\'lasizmi?';

  @override
  String get actionYes => 'Ha';

  @override
  String get actionNo => 'Yo\'q';

  @override
  String get sideWhite => 'Oq';

  @override
  String get sideBlack => 'Qora';

  @override
  String get labelPip => 'pip';

  @override
  String get labelBorneOff => 'chiqdi';

  @override
  String get resultYouWin => 'Siz yutdingiz!';

  @override
  String get resultYouLose => 'Siz yutqazdingiz';

  @override
  String get resultWhiteWins => 'Oq toshlar yutdi';

  @override
  String get resultBlackWins => 'Qora toshlar yutdi';

  @override
  String get resultOyin => 'Oyin — 1 ochko';

  @override
  String get resultMars => 'Mars — 2 ochko';

  @override
  String get resultByResign => 'Taslim bo\'lish bilan';

  @override
  String get actionRematch => 'Yana o\'ynash';

  @override
  String get actionMenu => 'Menyu';
}
