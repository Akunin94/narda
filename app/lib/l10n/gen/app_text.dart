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
