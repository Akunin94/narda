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

  @override
  String get menuRules => 'Qoidalar';

  @override
  String get menuStats => 'Statistika';

  @override
  String get menuThemes => 'Doska mavzusi';

  @override
  String get matchTitle => 'Partiya formati';

  @override
  String get matchSingle => 'Bitta partiya';

  @override
  String get settingLanguage => 'Til';

  @override
  String get languageAuto => 'Qurilma tili';

  @override
  String get languageUz => 'O\'zbekcha';

  @override
  String get languageRu => 'Ruscha';

  @override
  String get settingSound => 'Ovoz';

  @override
  String get settingSoundHint => 'Zar, tosh va g\'alaba ovozlari';

  @override
  String get settingVibration => 'Tebranish';

  @override
  String get settingVibrationHint => 'Yurish va zar tashlashda tebranish';

  @override
  String get settingPrivacy => 'Reklama sozlamalari';

  @override
  String get actionResetStats => 'Statistikani tozalash';

  @override
  String get resetStatsQuestion => 'Statistika o\'chirilsinmi?';

  @override
  String get statsTitle => 'Statistika';

  @override
  String get statsGames => 'Partiyalar';

  @override
  String get statsWins => 'G\'alabalar';

  @override
  String get statsWinRate => 'G\'alaba foizi';

  @override
  String get statsMarsWins => 'Mars — siz';

  @override
  String get statsMarsLosses => 'Mars — raqib';

  @override
  String get statsMatches => 'Matchlar';

  @override
  String get statsMatchWins => 'Yutilgan matchlar';

  @override
  String get statsEmpty => 'Hali bitta ham partiya yo\'q';

  @override
  String get statsNote =>
      'Faqat bot bilan o\'ynalgan partiyalar hisobga olinadi';

  @override
  String get themesTitle => 'Doska mavzusi';

  @override
  String get themeKlassik => 'Klassik';

  @override
  String get themeKokGumbaz => 'Ko\'k gumbaz';

  @override
  String get themeZar => 'Zar';

  @override
  String get themeSelected => 'Tanlangan';

  @override
  String get themeUnlockWatch => 'Video ko\'rib oching';

  @override
  String get themeAdsUnavailable => 'Reklama hozircha tayyor emas';

  @override
  String get themeUnlockedHint => 'Video ko\'rsangiz mavzu 24 soatga ochiladi';

  @override
  String get rulesTitle => 'Qoidalar';

  @override
  String get rulesGoalTitle => 'Maqsad';

  @override
  String get rulesGoalBody =>
      'Barcha 15 toshni aylana bo\'ylab o\'z uyingizga — 1-6 punktlarga — olib boring va raqibdan oldin chiqarib oling. Urish yo\'q, bar yo\'q: toshlar hech qachon urilmaydi.';

  @override
  String get rulesStartTitle => 'Boshlanish va yo\'nalish';

  @override
  String get rulesStartBody =>
      'Boshida barcha 15 tosh boshda turadi. Ikkala tomon halqa bo\'ylab bir yo\'nalishda yuradi, lekin boshlari yarim aylana masofada — shuning uchun toshlar yuzma-yuz uchrashmaydi.';

  @override
  String get rulesMoveTitle => 'Yurish';

  @override
  String get rulesMoveBody =>
      'Ikki zar tashlanadi: ikki yurish, xohlasangiz bitta tosh bilan ketma-ket. Juft tushsa — to\'rt yurish. Raqibning hech bo\'lmaganda bitta toshi turgan punktga borib bo\'lmaydi; o\'z toshlaringiz bir punktda cheksiz tura oladi.';

  @override
  String get rulesHeadTitle => 'Bosh qoidasi';

  @override
  String get rulesHeadBody =>
      'Bitta tashlashda boshdan faqat bitta tosh olinadi. Istisno — partiyadagi eng birinchi tashlash: 6-6, 4-4 yoki 3-3 tushsa, ikkita tosh olish mumkin.';

  @override
  String get rulesFullTitle => 'To\'liq yurish';

  @override
  String get rulesFullBody =>
      'Yurish imkon qadar uzun bo\'lishi shart: ikkala sonni ham ishlatish kerak, juftda esa to\'rttadan qanchasi chiqsa. Faqat bitta son o\'ynalsa — kattasi o\'ynaladi. Umuman yurish bo\'lmasa, navbat raqibga o\'tadi.';

  @override
  String get rulesBlockTitle => 'Blok qoidasi';

  @override
  String get rulesBlockBody =>
      'Ketma-ket oltita punktni egallash mumkin emas, agar to\'siq oldida raqibning birorta ham toshi qolmasa. Uning kamida bitta toshi oldinda bo\'lsa — blok mumkin.';

  @override
  String get rulesBearOffTitle => 'Chiqarish';

  @override
  String get rulesBearOffBody =>
      'Barcha 15 tosh uyga yig\'ilgach, chiqarish boshlanadi: k punktdagi tosh aynan k soni bilan chiqadi. Tushgan son eng uzoq band punktdan katta bo\'lsa — o\'sha punktdagi tosh chiqadi. Chiqarish o\'rniga uy ichida yurish ham mumkin.';

  @override
  String get rulesResultTitle => 'Natija';

  @override
  String get rulesResultBody =>
      'Barcha 15 toshni birinchi bo\'lib chiqargan yutadi. Oddiy g\'alaba — oyin, 1 ochko; raqib bitta ham chiqara olmasa — mars, 2 ochko. Match 3, 5 yoki 7 ochkogacha o\'ynaladi.';

  @override
  String get labelScore => 'Hisob';

  @override
  String get actionNextGame => 'Keyingi partiya';

  @override
  String get actionNewMatch => 'Yangi match';

  @override
  String get matchWonTitle => 'Matchda yutdingiz!';

  @override
  String get matchLostTitle => 'Matchda yutqazdingiz';

  @override
  String get matchWhiteWins => 'Matchda oq toshlar yutdi';

  @override
  String get matchBlackWins => 'Matchda qora toshlar yutdi';

  @override
  String matchToPoints(int points) {
    return '$points ochkogacha';
  }

  @override
  String themeHoursLeft(int hours) {
    return '$hours soat qoldi';
  }

  @override
  String themeMinutesLeft(int minutes) {
    return '$minutes daqiqa qoldi';
  }

  @override
  String get menuPlayOnline => 'Onlayn o\'ynash';

  @override
  String get onlineTitle => 'Onlayn';

  @override
  String get onlineQuickMatch => 'Tez o\'yin';

  @override
  String get onlineCreateRoom => 'Xona yaratish';

  @override
  String get onlineJoinRoom => 'Kod bilan kirish';

  @override
  String get onlineCodeHint => '6 xonali kod';

  @override
  String get onlineShareCode => 'Kodni raqibingizga ayting';

  @override
  String get onlineWaitingTitle => 'Raqib kutilmoqda';

  @override
  String get onlineSearching => 'Raqib qidirilmoqda';

  @override
  String get onlineConnecting => 'Ulanmoqda';

  @override
  String get onlineCancelSearch => 'To\'xtatish';

  @override
  String get onlineBotOffer =>
      'Raqib topilmadi. Kutayotganda bot bilan o\'ynaysizmi?';

  @override
  String get onlineFairPlay =>
      'Onlaynda faqat tirik o\'yinchilar bo\'ladi: bot hech qachon odam sifatida ko\'rsatilmaydi.';

  @override
  String get onlineNotConfigured => 'Onlayn hali sozlanmagan';

  @override
  String get onlineNetworkError => 'Aloqa yo\'q';

  @override
  String get onlineNoRoom => 'Bunday kodli xona topilmadi';

  @override
  String get onlineRoomFull => 'Xona to\'la';

  @override
  String get onlineOpponentLabel => 'Raqib';

  @override
  String get onlineOpponentTurn => 'Raqib yuradi';

  @override
  String get onlineOpponentOffline => 'Raqib aloqada emas';

  @override
  String get onlineClaimWin => 'G\'alabani olish';

  @override
  String get onlineAborted => 'Partiya bekor qilindi';

  @override
  String get onlineAbortedDesync => 'O\'yin holatlari mos kelmadi';

  @override
  String get onlineAbortedConnection => 'Aloqa uzildi';

  @override
  String get onlinePhrasesTitle => 'Iboralar';

  @override
  String get phraseSalom => 'Salom!';

  @override
  String get phraseYaxshiYurish => 'Yaxshi yurish!';

  @override
  String get phraseOmad => 'Omad!';

  @override
  String get phraseRahmat => 'Rahmat, yaxshi o\'yin';

  @override
  String onlineSecondsLeft(int seconds) {
    return '$seconds s';
  }
}
