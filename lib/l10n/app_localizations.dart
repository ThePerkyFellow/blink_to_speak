import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('en'),
    Locale('hi'),
    Locale('kn'),
    Locale('mr'),
    Locale('ta'),
    Locale('te')
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'Blink to Speak'**
  String get appTitle;

  /// Home screen main action
  ///
  /// In en, this message translates to:
  /// **'Interpret my blink'**
  String get interpretMyBlink;

  /// Home screen practice button
  ///
  /// In en, this message translates to:
  /// **'Practice screen'**
  String get practiceScreen;

  /// Home screen caregiver setup
  ///
  /// In en, this message translates to:
  /// **'Personalize messages'**
  String get personalizeMessages;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Link to guidebook
  ///
  /// In en, this message translates to:
  /// **'Blink to Speak Guidebook'**
  String get guidebook;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Our services'**
  String get ourServices;

  /// Contact link
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUs;

  /// Back navigation
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// YES button label
  ///
  /// In en, this message translates to:
  /// **'YES'**
  String get yes;

  /// NO button label
  ///
  /// In en, this message translates to:
  /// **'NO'**
  String get no;

  /// 1 blink label
  ///
  /// In en, this message translates to:
  /// **'1 blink'**
  String get oneBlink;

  /// 2 blinks label
  ///
  /// In en, this message translates to:
  /// **'2 blinks'**
  String get twoBlinks;

  /// Permission dialog title
  ///
  /// In en, this message translates to:
  /// **'Allow camera access'**
  String get allowCameraAccess;

  /// Permission rationale
  ///
  /// In en, this message translates to:
  /// **'Please allow access to your device\'s camera which is required for blink interpretation on this app.'**
  String get cameraPermissionReason;

  /// Start button on splash
  ///
  /// In en, this message translates to:
  /// **'BLINK TO START'**
  String get blinkToStart;

  /// Interpret screen section title
  ///
  /// In en, this message translates to:
  /// **'Interpretation'**
  String get interpretation;

  /// Output card header
  ///
  /// In en, this message translates to:
  /// **'Detected Message'**
  String get detectedMessage;

  /// Idle state label
  ///
  /// In en, this message translates to:
  /// **'Waiting for gesture...'**
  String get waitingForGesture;

  /// Buffer display label
  ///
  /// In en, this message translates to:
  /// **'Gesture buffer'**
  String get gestureBuffer;

  /// Instruction on interpret screen
  ///
  /// In en, this message translates to:
  /// **'Long shut eyes to begin'**
  String get longShutToStart;

  /// Emergency alert title
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY'**
  String get emergency;

  /// Emergency message body
  ///
  /// In en, this message translates to:
  /// **'Emergency signal detected! Alerting caregiver.'**
  String get emergencyMessage;

  /// Dismiss button
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// Caregiver screen title
  ///
  /// In en, this message translates to:
  /// **'Caregiver Setup'**
  String get caregiverSetup;

  /// List screen title
  ///
  /// In en, this message translates to:
  /// **'Command List'**
  String get commandList;

  /// Edit screen title
  ///
  /// In en, this message translates to:
  /// **'Edit Command'**
  String get editCommand;

  /// Add button
  ///
  /// In en, this message translates to:
  /// **'Add Custom Command'**
  String get addCustomCommand;

  /// Section label
  ///
  /// In en, this message translates to:
  /// **'Gesture Sequence'**
  String get gestureSequence;

  /// Section label
  ///
  /// In en, this message translates to:
  /// **'Message Text'**
  String get messageText;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Reset button
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// Settings label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Settings label
  ///
  /// In en, this message translates to:
  /// **'Detection Sensitivity'**
  String get sensitivity;

  /// Settings label
  ///
  /// In en, this message translates to:
  /// **'Speech Rate'**
  String get speechRate;

  /// Settings label
  ///
  /// In en, this message translates to:
  /// **'Patient Name'**
  String get patientName;

  /// Practice screen title
  ///
  /// In en, this message translates to:
  /// **'Practice Mode'**
  String get practiceMode;

  /// Practice mode subtitle
  ///
  /// In en, this message translates to:
  /// **'Practice your eye gestures — no messages will be spoken.'**
  String get practiceInstruction;

  /// Command category
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get categoryBasics;

  /// Command category
  ///
  /// In en, this message translates to:
  /// **'Needs'**
  String get categoryNeeds;

  /// Command category
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// Command category
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get categoryEmergency;

  /// Command category
  ///
  /// In en, this message translates to:
  /// **'Emotional'**
  String get categoryEmotional;

  /// Command category
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get categorySocial;

  /// Command category
  ///
  /// In en, this message translates to:
  /// **'Utility'**
  String get categoryUtility;

  /// Command category
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get categoryComfort;

  /// Command category
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get categoryCustom;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'en',
        'hi',
        'kn',
        'mr',
        'ta',
        'te'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'mr':
      return AppLocalizationsMr();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
