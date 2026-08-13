import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_text_ru.dart';
import 'app_text_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppText
/// returned by `AppText.of(context)`.
///
/// Applications need to include `AppText.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_text.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppText.localizationsDelegates,
///   supportedLocales: AppText.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppText.supportedLocales
/// property.
abstract class AppText {
  AppText(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppText of(BuildContext context) {
    return Localizations.of<AppText>(context, AppText)!;
  }

  static const LocalizationsDelegate<AppText> delegate = _AppTextDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('uz'),
  ];

  /// Название игры
  ///
  /// In uz, this message translates to:
  /// **'Uzun narda'**
  String get appTitle;

  /// Подзаголовок на главном экране
  ///
  /// In uz, this message translates to:
  /// **'Uzbek nardasi'**
  String get menuSubtitle;

  /// Кнопка: игра против бота
  ///
  /// In uz, this message translates to:
  /// **'Bot bilan o\'ynash'**
  String get menuPlayBot;

  /// Кнопка: hotseat на одном устройстве
  ///
  /// In uz, this message translates to:
  /// **'Bitta qurilmada'**
  String get menuPlayHotseat;

  /// Кнопка настроек
  ///
  /// In uz, this message translates to:
  /// **'Sozlamalar'**
  String get menuSettings;

  /// Заголовок выбора уровня бота
  ///
  /// In uz, this message translates to:
  /// **'Bot darajasi'**
  String get levelTitle;

  /// Уровень бота: лёгкий
  ///
  /// In uz, this message translates to:
  /// **'Oson'**
  String get levelOson;

  /// Уровень бота: средний
  ///
  /// In uz, this message translates to:
  /// **'O\'rta'**
  String get levelOrta;

  /// Уровень бота: сильный
  ///
  /// In uz, this message translates to:
  /// **'Kuchli'**
  String get levelKuchli;

  /// Настройка автохода
  ///
  /// In uz, this message translates to:
  /// **'Avto-yurish'**
  String get settingAutoMove;

  /// Пояснение к автоходу
  ///
  /// In uz, this message translates to:
  /// **'Yagona variant qolganda yurish o\'zi bajariladi'**
  String get settingAutoMoveHint;

  /// Настройка показа pip-счёта
  ///
  /// In uz, this message translates to:
  /// **'Pip hisobi'**
  String get settingShowPips;

  /// Пояснение к pip-счёту
  ///
  /// In uz, this message translates to:
  /// **'Ikkala tomonning pip hisobi ko\'rsatiladi'**
  String get settingShowPipsHint;

  /// Закрыть
  ///
  /// In uz, this message translates to:
  /// **'Yopish'**
  String get actionClose;

  /// Статус: бросок костей
  ///
  /// In uz, this message translates to:
  /// **'Zar tashlash'**
  String get statusRolling;

  /// Статус: ход игрока
  ///
  /// In uz, this message translates to:
  /// **'Sizning yurishingiz'**
  String get statusYourTurn;

  /// Статус: бот думает
  ///
  /// In uz, this message translates to:
  /// **'Bot o\'ylayapti'**
  String get statusThinking;

  /// Статус: ход белых (hotseat)
  ///
  /// In uz, this message translates to:
  /// **'Oq toshlar yuradi'**
  String get statusWhiteTurn;

  /// Статус: ход чёрных (hotseat)
  ///
  /// In uz, this message translates to:
  /// **'Qora toshlar yuradi'**
  String get statusBlackTurn;

  /// Статус: нет легальных ходов
  ///
  /// In uz, this message translates to:
  /// **'Yurish yo\'q'**
  String get statusNoMoves;

  /// Статус: ход собран, нужно подтверждение
  ///
  /// In uz, this message translates to:
  /// **'Yurishni tasdiqlang'**
  String get statusConfirmTurn;

  /// Подсказка: выберите шашку
  ///
  /// In uz, this message translates to:
  /// **'Toshni tanlang'**
  String get hintSelectChecker;

  /// Подтвердить ход
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash'**
  String get actionConfirm;

  /// Отменить перемещение
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get actionUndo;

  /// Сдаться
  ///
  /// In uz, this message translates to:
  /// **'Taslim bo\'lish'**
  String get actionResign;

  /// Вопрос перед сдачей партии
  ///
  /// In uz, this message translates to:
  /// **'Partiyada taslim bo\'lasizmi?'**
  String get resignQuestion;

  /// Да
  ///
  /// In uz, this message translates to:
  /// **'Ha'**
  String get actionYes;

  /// Нет
  ///
  /// In uz, this message translates to:
  /// **'Yo\'q'**
  String get actionNo;

  /// Белые
  ///
  /// In uz, this message translates to:
  /// **'Oq'**
  String get sideWhite;

  /// Чёрные
  ///
  /// In uz, this message translates to:
  /// **'Qora'**
  String get sideBlack;

  /// Подпись pip-счёта
  ///
  /// In uz, this message translates to:
  /// **'pip'**
  String get labelPip;

  /// Подпись количества выброшенных шашек
  ///
  /// In uz, this message translates to:
  /// **'chiqdi'**
  String get labelBorneOff;

  /// Итог: победа игрока
  ///
  /// In uz, this message translates to:
  /// **'Siz yutdingiz!'**
  String get resultYouWin;

  /// Итог: поражение игрока
  ///
  /// In uz, this message translates to:
  /// **'Siz yutqazdingiz'**
  String get resultYouLose;

  /// Итог: выиграли белые
  ///
  /// In uz, this message translates to:
  /// **'Oq toshlar yutdi'**
  String get resultWhiteWins;

  /// Итог: выиграли чёрные
  ///
  /// In uz, this message translates to:
  /// **'Qora toshlar yutdi'**
  String get resultBlackWins;

  /// Итог: обычная победа
  ///
  /// In uz, this message translates to:
  /// **'Oyin — 1 ochko'**
  String get resultOyin;

  /// Итог: марс
  ///
  /// In uz, this message translates to:
  /// **'Mars — 2 ochko'**
  String get resultMars;

  /// Пометка: победа из-за сдачи
  ///
  /// In uz, this message translates to:
  /// **'Taslim bo\'lish bilan'**
  String get resultByResign;

  /// Сыграть ещё раз
  ///
  /// In uz, this message translates to:
  /// **'Yana o\'ynash'**
  String get actionRematch;

  /// Выйти в меню
  ///
  /// In uz, this message translates to:
  /// **'Menyu'**
  String get actionMenu;

  /// Кнопка: обучение правилам
  ///
  /// In uz, this message translates to:
  /// **'Qoidalar'**
  String get menuRules;

  /// Кнопка: статистика
  ///
  /// In uz, this message translates to:
  /// **'Statistika'**
  String get menuStats;

  /// Кнопка: оформление доски
  ///
  /// In uz, this message translates to:
  /// **'Doska mavzusi'**
  String get menuThemes;

  /// Заголовок выбора формата матча
  ///
  /// In uz, this message translates to:
  /// **'Partiya formati'**
  String get matchTitle;

  /// Формат: одиночная партия
  ///
  /// In uz, this message translates to:
  /// **'Bitta partiya'**
  String get matchSingle;

  /// Настройка языка
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get settingLanguage;

  /// Язык: как на устройстве
  ///
  /// In uz, this message translates to:
  /// **'Qurilma tili'**
  String get languageAuto;

  /// Язык: узбекский
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekcha'**
  String get languageUz;

  /// Язык: русский
  ///
  /// In uz, this message translates to:
  /// **'Ruscha'**
  String get languageRu;

  /// Настройка звука
  ///
  /// In uz, this message translates to:
  /// **'Ovoz'**
  String get settingSound;

  /// Пояснение к звуку
  ///
  /// In uz, this message translates to:
  /// **'Zar, tosh va g\'alaba ovozlari'**
  String get settingSoundHint;

  /// Настройка вибрации
  ///
  /// In uz, this message translates to:
  /// **'Tebranish'**
  String get settingVibration;

  /// Пояснение к вибрации
  ///
  /// In uz, this message translates to:
  /// **'Yurish va zar tashlashda tebranish'**
  String get settingVibrationHint;

  /// Кнопка окна согласия UMP
  ///
  /// In uz, this message translates to:
  /// **'Reklama sozlamalari'**
  String get settingPrivacy;

  /// Кнопка сброса статистики
  ///
  /// In uz, this message translates to:
  /// **'Statistikani tozalash'**
  String get actionResetStats;

  /// Вопрос перед сбросом статистики
  ///
  /// In uz, this message translates to:
  /// **'Statistika o\'chirilsinmi?'**
  String get resetStatsQuestion;

  /// Заголовок экрана статистики
  ///
  /// In uz, this message translates to:
  /// **'Statistika'**
  String get statsTitle;

  /// Статистика: сыграно партий
  ///
  /// In uz, this message translates to:
  /// **'Partiyalar'**
  String get statsGames;

  /// Статистика: побед
  ///
  /// In uz, this message translates to:
  /// **'G\'alabalar'**
  String get statsWins;

  /// Статистика: винрейт
  ///
  /// In uz, this message translates to:
  /// **'G\'alaba foizi'**
  String get statsWinRate;

  /// Статистика: марсы в пользу игрока
  ///
  /// In uz, this message translates to:
  /// **'Mars — siz'**
  String get statsMarsWins;

  /// Статистика: марсы в пользу соперника
  ///
  /// In uz, this message translates to:
  /// **'Mars — raqib'**
  String get statsMarsLosses;

  /// Статистика: сыграно матчей
  ///
  /// In uz, this message translates to:
  /// **'Matchlar'**
  String get statsMatches;

  /// Статистика: выиграно матчей
  ///
  /// In uz, this message translates to:
  /// **'Yutilgan matchlar'**
  String get statsMatchWins;

  /// Статистика пуста
  ///
  /// In uz, this message translates to:
  /// **'Hali bitta ham partiya yo\'q'**
  String get statsEmpty;

  /// Пояснение: считаются только партии с ботом
  ///
  /// In uz, this message translates to:
  /// **'Faqat bot bilan o\'ynalgan partiyalar hisobga olinadi'**
  String get statsNote;

  /// Заголовок экрана тем
  ///
  /// In uz, this message translates to:
  /// **'Doska mavzusi'**
  String get themesTitle;

  /// Тема: классика
  ///
  /// In uz, this message translates to:
  /// **'Klassik'**
  String get themeKlassik;

  /// Тема: синий купол
  ///
  /// In uz, this message translates to:
  /// **'Ko\'k gumbaz'**
  String get themeKokGumbaz;

  /// Тема: тёмный орех с золотом
  ///
  /// In uz, this message translates to:
  /// **'Zar'**
  String get themeZar;

  /// Тема выбрана
  ///
  /// In uz, this message translates to:
  /// **'Tanlangan'**
  String get themeSelected;

  /// Открыть тему за ролик
  ///
  /// In uz, this message translates to:
  /// **'Video ko\'rib oching'**
  String get themeUnlockWatch;

  /// Реклама сейчас недоступна
  ///
  /// In uz, this message translates to:
  /// **'Reklama hozircha tayyor emas'**
  String get themeAdsUnavailable;

  /// Пояснение: ролик открывает тему на 24 часа
  ///
  /// In uz, this message translates to:
  /// **'Video ko\'rsangiz mavzu 24 soatga ochiladi'**
  String get themeUnlockedHint;

  /// Заголовок экрана правил
  ///
  /// In uz, this message translates to:
  /// **'Qoidalar'**
  String get rulesTitle;

  /// Правила: цель игры
  ///
  /// In uz, this message translates to:
  /// **'Maqsad'**
  String get rulesGoalTitle;

  /// Правила: цель
  ///
  /// In uz, this message translates to:
  /// **'Barcha 15 toshni aylana bo\'ylab o\'z uyingizga — 1-6 punktlarga — olib boring va raqibdan oldin chiqarib oling. Urish yo\'q, bar yo\'q: toshlar hech qachon urilmaydi.'**
  String get rulesGoalBody;

  /// Правила: старт
  ///
  /// In uz, this message translates to:
  /// **'Boshlanish va yo\'nalish'**
  String get rulesStartTitle;

  /// Правила: старт
  ///
  /// In uz, this message translates to:
  /// **'Boshida barcha 15 tosh boshda turadi. Ikkala tomon halqa bo\'ylab bir yo\'nalishda yuradi, lekin boshlari yarim aylana masofada — shuning uchun toshlar yuzma-yuz uchrashmaydi.'**
  String get rulesStartBody;

  /// Правила: ход
  ///
  /// In uz, this message translates to:
  /// **'Yurish'**
  String get rulesMoveTitle;

  /// Правила: ход
  ///
  /// In uz, this message translates to:
  /// **'Ikki zar tashlanadi: ikki yurish, xohlasangiz bitta tosh bilan ketma-ket. Juft tushsa — to\'rt yurish. Raqibning hech bo\'lmaganda bitta toshi turgan punktga borib bo\'lmaydi; o\'z toshlaringiz bir punktda cheksiz tura oladi.'**
  String get rulesMoveBody;

  /// Правила: голова
  ///
  /// In uz, this message translates to:
  /// **'Bosh qoidasi'**
  String get rulesHeadTitle;

  /// Правила: голова
  ///
  /// In uz, this message translates to:
  /// **'Bitta tashlashda boshdan faqat bitta tosh olinadi. Istisno — partiyadagi eng birinchi tashlash: 6-6, 4-4 yoki 3-3 tushsa, ikkita tosh olish mumkin.'**
  String get rulesHeadBody;

  /// Правила: обязательность полного хода
  ///
  /// In uz, this message translates to:
  /// **'To\'liq yurish'**
  String get rulesFullTitle;

  /// Правила: полный ход
  ///
  /// In uz, this message translates to:
  /// **'Yurish imkon qadar uzun bo\'lishi shart: ikkala sonni ham ishlatish kerak, juftda esa to\'rttadan qanchasi chiqsa. Faqat bitta son o\'ynalsa — kattasi o\'ynaladi. Umuman yurish bo\'lmasa, navbat raqibga o\'tadi.'**
  String get rulesFullBody;

  /// Правила: блок из шести
  ///
  /// In uz, this message translates to:
  /// **'Blok qoidasi'**
  String get rulesBlockTitle;

  /// Правила: блок
  ///
  /// In uz, this message translates to:
  /// **'Ketma-ket oltita punktni egallash mumkin emas, agar to\'siq oldida raqibning birorta ham toshi qolmasa. Uning kamida bitta toshi oldinda bo\'lsa — blok mumkin.'**
  String get rulesBlockBody;

  /// Правила: выброс
  ///
  /// In uz, this message translates to:
  /// **'Chiqarish'**
  String get rulesBearOffTitle;

  /// Правила: выброс
  ///
  /// In uz, this message translates to:
  /// **'Barcha 15 tosh uyga yig\'ilgach, chiqarish boshlanadi: k punktdagi tosh aynan k soni bilan chiqadi. Tushgan son eng uzoq band punktdan katta bo\'lsa — o\'sha punktdagi tosh chiqadi. Chiqarish o\'rniga uy ichida yurish ham mumkin.'**
  String get rulesBearOffBody;

  /// Правила: результат
  ///
  /// In uz, this message translates to:
  /// **'Natija'**
  String get rulesResultTitle;

  /// Правила: результат
  ///
  /// In uz, this message translates to:
  /// **'Barcha 15 toshni birinchi bo\'lib chiqargan yutadi. Oddiy g\'alaba — oyin, 1 ochko; raqib bitta ham chiqara olmasa — mars, 2 ochko. Match 3, 5 yoki 7 ochkogacha o\'ynaladi.'**
  String get rulesResultBody;

  /// Подпись счёта серии
  ///
  /// In uz, this message translates to:
  /// **'Hisob'**
  String get labelScore;

  /// Кнопка: следующая партия серии
  ///
  /// In uz, this message translates to:
  /// **'Keyingi partiya'**
  String get actionNextGame;

  /// Кнопка: новая серия
  ///
  /// In uz, this message translates to:
  /// **'Yangi match'**
  String get actionNewMatch;

  /// Итог серии: победа игрока
  ///
  /// In uz, this message translates to:
  /// **'Matchda yutdingiz!'**
  String get matchWonTitle;

  /// Итог серии: поражение игрока
  ///
  /// In uz, this message translates to:
  /// **'Matchda yutqazdingiz'**
  String get matchLostTitle;

  /// Итог серии: выиграли белые
  ///
  /// In uz, this message translates to:
  /// **'Matchda oq toshlar yutdi'**
  String get matchWhiteWins;

  /// Итог серии: выиграли чёрные
  ///
  /// In uz, this message translates to:
  /// **'Matchda qora toshlar yutdi'**
  String get matchBlackWins;

  /// Формат: серия до N очков
  ///
  /// In uz, this message translates to:
  /// **'{points} ochkogacha'**
  String matchToPoints(int points);

  /// Сколько часов осталось у открытой темы
  ///
  /// In uz, this message translates to:
  /// **'{hours} soat qoldi'**
  String themeHoursLeft(int hours);

  /// Сколько минут осталось у открытой темы
  ///
  /// In uz, this message translates to:
  /// **'{minutes} daqiqa qoldi'**
  String themeMinutesLeft(int minutes);

  /// Кнопка: игра по сети
  ///
  /// In uz, this message translates to:
  /// **'Onlayn o\'ynash'**
  String get menuPlayOnline;

  /// Заголовок экрана онлайна
  ///
  /// In uz, this message translates to:
  /// **'Onlayn'**
  String get onlineTitle;

  /// Быстрый матч
  ///
  /// In uz, this message translates to:
  /// **'Tez o\'yin'**
  String get onlineQuickMatch;

  /// Создать приватную комнату
  ///
  /// In uz, this message translates to:
  /// **'Xona yaratish'**
  String get onlineCreateRoom;

  /// Войти в комнату по коду
  ///
  /// In uz, this message translates to:
  /// **'Kod bilan kirish'**
  String get onlineJoinRoom;

  /// Подсказка поля кода комнаты
  ///
  /// In uz, this message translates to:
  /// **'6 xonali kod'**
  String get onlineCodeHint;

  /// Продиктуйте код сопернику
  ///
  /// In uz, this message translates to:
  /// **'Kodni raqibingizga ayting'**
  String get onlineShareCode;

  /// Ждём второго игрока
  ///
  /// In uz, this message translates to:
  /// **'Raqib kutilmoqda'**
  String get onlineWaitingTitle;

  /// Идёт поиск соперника
  ///
  /// In uz, this message translates to:
  /// **'Raqib qidirilmoqda'**
  String get onlineSearching;

  /// Идёт подключение
  ///
  /// In uz, this message translates to:
  /// **'Ulanmoqda'**
  String get onlineConnecting;

  /// Остановить поиск или ожидание
  ///
  /// In uz, this message translates to:
  /// **'To\'xtatish'**
  String get onlineCancelSearch;

  /// Честное предложение сыграть с ботом, пока идёт поиск
  ///
  /// In uz, this message translates to:
  /// **'Raqib topilmadi. Kutayotganda bot bilan o\'ynaysizmi?'**
  String get onlineBotOffer;

  /// Обещание не выдавать ботов за людей
  ///
  /// In uz, this message translates to:
  /// **'Onlaynda faqat tirik o\'yinchilar bo\'ladi: bot hech qachon odam sifatida ko\'rsatilmaydi.'**
  String get onlineFairPlay;

  /// Нет конфигурации Firebase
  ///
  /// In uz, this message translates to:
  /// **'Onlayn hali sozlanmagan'**
  String get onlineNotConfigured;

  /// Ошибка сети
  ///
  /// In uz, this message translates to:
  /// **'Aloqa yo\'q'**
  String get onlineNetworkError;

  /// Комната по коду не найдена
  ///
  /// In uz, this message translates to:
  /// **'Bunday kodli xona topilmadi'**
  String get onlineNoRoom;

  /// В комнате уже двое
  ///
  /// In uz, this message translates to:
  /// **'Xona to\'la'**
  String get onlineRoomFull;

  /// Соперник без имени
  ///
  /// In uz, this message translates to:
  /// **'Raqib'**
  String get onlineOpponentLabel;

  /// Статус: ход соперника по сети
  ///
  /// In uz, this message translates to:
  /// **'Raqib yuradi'**
  String get onlineOpponentTurn;

  /// Соперник потерял связь
  ///
  /// In uz, this message translates to:
  /// **'Raqib aloqada emas'**
  String get onlineOpponentOffline;

  /// Забрать победу у пропавшего соперника
  ///
  /// In uz, this message translates to:
  /// **'G\'alabani olish'**
  String get onlineClaimWin;

  /// Партия аннулирована
  ///
  /// In uz, this message translates to:
  /// **'Partiya bekor qilindi'**
  String get onlineAborted;

  /// Причина: состояния разошлись
  ///
  /// In uz, this message translates to:
  /// **'O\'yin holatlari mos kelmadi'**
  String get onlineAbortedDesync;

  /// Причина: обрыв связи
  ///
  /// In uz, this message translates to:
  /// **'Aloqa uzildi'**
  String get onlineAbortedConnection;

  /// Заголовок панели готовых фраз
  ///
  /// In uz, this message translates to:
  /// **'Iboralar'**
  String get onlinePhrasesTitle;

  /// Готовая фраза: приветствие
  ///
  /// In uz, this message translates to:
  /// **'Salom!'**
  String get phraseSalom;

  /// Готовая фраза: хороший ход
  ///
  /// In uz, this message translates to:
  /// **'Yaxshi yurish!'**
  String get phraseYaxshiYurish;

  /// Готовая фраза: удачи
  ///
  /// In uz, this message translates to:
  /// **'Omad!'**
  String get phraseOmad;

  /// Готовая фраза: спасибо за игру
  ///
  /// In uz, this message translates to:
  /// **'Rahmat, yaxshi o\'yin'**
  String get phraseRahmat;

  /// Сколько секунд осталось на ход
  ///
  /// In uz, this message translates to:
  /// **'{seconds} s'**
  String onlineSecondsLeft(int seconds);

  /// Кнопка: профиль игрока
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get menuProfile;

  /// Заголовок экрана профиля
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// Поле ника
  ///
  /// In uz, this message translates to:
  /// **'Taxallus'**
  String get profileName;

  /// Подсказка поля ника
  ///
  /// In uz, this message translates to:
  /// **'Taxallusingizni yozing'**
  String get profileNameHint;

  /// Заголовок выбора аватара
  ///
  /// In uz, this message translates to:
  /// **'Avatar'**
  String get profileAvatar;

  /// Рейтинг Elo
  ///
  /// In uz, this message translates to:
  /// **'Reyting'**
  String get profileRating;

  /// Сколько рейтинговых матчей сыграно
  ///
  /// In uz, this message translates to:
  /// **'Reytingli matchlar'**
  String get profileRatedGames;

  /// Пояснение: рейтинг только за онлайн
  ///
  /// In uz, this message translates to:
  /// **'Reyting faqat onlayn matchlarda o\'zgaradi'**
  String get profileRatingNote;

  /// Заголовок таблицы лидеров
  ///
  /// In uz, this message translates to:
  /// **'Reyting jadvali'**
  String get leaderboardTitle;

  /// Таблица лидеров пуста
  ///
  /// In uz, this message translates to:
  /// **'Jadval hozircha bo\'sh'**
  String get leaderboardEmpty;

  /// Пометка своей строки в таблице
  ///
  /// In uz, this message translates to:
  /// **'Siz'**
  String get leaderboardYou;

  /// Кнопка: предложить реванш в онлайне
  ///
  /// In uz, this message translates to:
  /// **'Revansh'**
  String get actionRematchOnline;

  /// Ждём, согласится ли соперник на реванш
  ///
  /// In uz, this message translates to:
  /// **'Raqibning javobi kutilmoqda'**
  String get rematchWaiting;

  /// Соперник предложил реванш
  ///
  /// In uz, this message translates to:
  /// **'Raqib revansh taklif qilyapti'**
  String get rematchOffered;

  /// Рейтинг после матча и его изменение
  ///
  /// In uz, this message translates to:
  /// **'Reyting: {rating} ({delta})'**
  String ratingResult(int rating, String delta);
}

class _AppTextDelegate extends LocalizationsDelegate<AppText> {
  const _AppTextDelegate();

  @override
  Future<AppText> load(Locale locale) {
    return SynchronousFuture<AppText>(lookupAppText(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppTextDelegate old) => false;
}

AppText lookupAppText(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppTextRu();
    case 'uz':
      return AppTextUz();
  }

  throw FlutterError(
    'AppText.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
