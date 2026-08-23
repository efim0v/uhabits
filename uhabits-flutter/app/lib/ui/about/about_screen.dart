/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/about/{AboutActivity,AboutScreen,AboutView}.kt
/// and uhabits-android/src/main/res/layout/{about,about_translators}.xml
///
/// The three Kotlin classes collapse into one widget:
///
///  * `AboutActivity` is the theme plus the toolbar — titled "About" and tinted
///    `PaletteColor(11)`.
///  * `AboutView` is `about.xml`: four cards — the app icon with its name and
///    version, the Links card, the Developers card, and the generated
///    Translators card.
///  * `AboutScreen` is the click handling: five link targets, the contributors
///    link, and the developer-mode countdown behind the version line.
///
/// `startActivitySafely` is the one thing a Flutter widget cannot do by itself:
/// there is no URL launcher in this package's dependencies, so the caller
/// supplies [AboutScreen.onOpenLink]. Returning false is
/// `ActivityNotFoundException` and raises the same "No app was found to support
/// this action" snackbar.
///
/// `about_translators.xml` is machine-generated markup upstream; it is ported
/// as the [AboutScreen.translators] data table, exactly as the ledger asks.
library;

// `Preferences` is reached by its `src` path, the way `AppScope` does it.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../l10n/app_localizations.dart';
import '../../state/app_scope.dart';
import '../common/window_insets.dart';
import '../intro/intro_screen.dart';
import '../theme/app_theme.dart' show coreThemeOf;
import '../common/store_listing.dart';

/// `Context.startActivitySafely(intent)`: true when something handled the
/// intent, false when nothing did.
typedef OpenLink = Future<bool> Function(Uri uri);

/// One `About.Item.Language` heading and the `About.Item` names under it.
@immutable
class TranslatorGroup {
  const TranslatorGroup(this.language, this.names);

  final String language;
  final List<String> names;
}

/// Port of the About half of
/// uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentFactory.kt.
class AboutLinks {
  AboutLinks._();

  /// `rateApp` — ACTION_VIEW market://details?id=org.isoron.uhabits, resolved
  /// for the platform by [storeListingUrl].
  static Uri get rateApp => Uri.parse(storeListingUrl);

  /// `sendFeedback` — ACTION_SENDTO mailto:dev@loophabits.org?subject=...
  static final Uri sendFeedback = Uri.parse(
    'mailto:dev@loophabits.org?subject=Feedback%20about%20Loop%20Habit%20Tracker',
  );

  /// `helpTranslate` — ACTION_VIEW http://translate.loophabits.org/
  static final Uri helpTranslate = Uri.parse('http://translate.loophabits.org/');

  /// `viewSourceCode` — ACTION_VIEW https://github.com/iSoron/uhabits
  static final Uri viewSourceCode = Uri.parse('https://github.com/iSoron/uhabits');

  /// `privacyPolicy` — ACTION_VIEW http://loophabits.org/privacy
  static final Uri privacyPolicy = Uri.parse('http://loophabits.org/privacy');

  /// `codeContributors` — ACTION_VIEW
  /// https://github.com/iSoron/uhabits/graphs/contributors
  static final Uri codeContributors =
      Uri.parse('https://github.com/iSoron/uhabits/graphs/contributors');
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({
    super.key,
    this.preferences,
    this.version = appVersionName,
    this.onOpenLink,
  });

  /// Defaults to the scope's, so the screen can be pushed with no arguments;
  /// tests pass one directly.
  final Preferences? preferences;

  /// `BuildConfig.VERSION_NAME`. Flutter cannot read the pubspec version at
  /// runtime without another package, so it is a constant here.
  final String version;

  /// `startActivitySafely`. Null behaves like a device with no app able to
  /// handle any of the intents: every row falls back to the snackbar.
  final OpenLink? onOpenLink;

  /// `uhabits-android/build.gradle.kts`: `versionName = "2.3.1"`.
  static const String appVersionName = '2.3.1';

  static const Key appIconKey = Key('aboutAppIcon');
  static const Key versionKey = Key('aboutVersion');
  static const Key linksCardKey = Key('aboutLinksCard');
  static const Key developersCardKey = Key('aboutDevelopersCard');
  static const Key translatorsCardKey = Key('aboutTranslatorsCard');

  /// `?attr/aboutScreenColor` = `@color/blue_800` in the light theme.
  static const Color aboutScreenColorLight = Color(0xFF1565C0);

  /// `?attr/aboutScreenColor` = `@color/blue_300` in the dark theme.
  static const Color aboutScreenColorDark = Color(0xFF64B5F6);

  /// The Developers card, in the order `about.xml` lists them.
  static const List<String> developers = <String>[
    'Álinson S. Xavier (@iSoron)',
    'Quentin Hibon (@hiqua)',
    'Oleg Ivashchenko (@olegivo)',
    'Kristian Tashkov (@KristianTashkov)',
    'Jakub Kalinowski (@kalina559)',
    'Rechee Jozil (@recheej)',
    'Sebastian Gallese (@sgallese)',
    'Luboš Luňák (@llunak)',
    'Bindu (@vbh)',
    'Victor Yu (@vyu1)',
    'Christoph Hennemann (@chennemann)',
    'Денис (@sciamano)',
    'Joseph Tran (@JotraN)',
    'Nikhil (@regularcoder)',
    'JanetQC',
  ];

  /// `about_translators.xml`, verbatim and in order.
  static const List<TranslatorGroup> translators = <TranslatorGroup>[
  TranslatorGroup('Bahasa Indonesia', <String>[
    'Angga Rifandi',
    'Dika Fitrian Dwi Putra',
    'Heru Yen',
    'Intan Ayunda',
    'Neysa Nasywa',
    'azzamsa',
    'raden20',
  ]),
  TranslatorGroup('Català', <String>[
    'David Nos',
    'carllacan',
  ]),
  TranslatorGroup('Cрпски', <String>[
    'Rancher',
  ]),
  TranslatorGroup('Dansk', <String>[
    'Aputsiak Niels Janussen',
    'Sølv Ræven',
    'Yussuf',
    'fbruna17',
  ]),
  TranslatorGroup('Deutsch', <String>[
    'Can Altas',
    'Laura Sophie',
    'Marius Teufelweich',
    'Matthias Meisser',
    'Michael',
    'Tad Wohlrapp',
    'cobalt59',
    'fabian.bouchal',
    'sojusnik',
    'tat bz',
  ]),
  TranslatorGroup('Español', <String>[
    'Ander Raso Vazquez',
    'Brenda Correa',
    'Eilif Adelvice',
    'Iabin Arteaga',
    'Sebastian05067',
    'Susanamesa',
    'luiandresgonzalez',
  ]),
  TranslatorGroup('Esperanto', <String>[
    '4001982248998',
    'marco.baturan',
  ]),
  TranslatorGroup('Euskara', <String>[
    'Beriain',
    'Osoitz',
    'beriain',
  ]),
  TranslatorGroup('Français', <String>[
    'François Mahé',
    'Mathis Chenuet',
    'Michael Faille',
    'Pierre GALIEGUE',
    'Samuel Guay',
    'Thibaut Girka',
    'Tiralka',
    '_translator',
    'roptat',
  ]),
  TranslatorGroup('Fārsi', <String>[
    'Behnood HRazy',
    'Eman',
    'Saeed Esmaili',
  ]),
  TranslatorGroup('Georgian', <String>[
    'Avalysion',
  ]),
  TranslatorGroup('Hindi', <String>[
    'Ravi Rami',
    'Vijaykumar Borkar',
    'vinayak sharma',
  ]),
  TranslatorGroup('Hrvatski', <String>[
    'Ivan Krušlin',
    'Ivan Vlahov',
  ]),
  TranslatorGroup('Icelandic', <String>[
    'strikeCunny2245',
  ]),
  TranslatorGroup('Italiano', <String>[
    'Marco Cavazza',
    'androide74',
  ]),
  TranslatorGroup('Magyar', <String>[
    'Balázs Keresztury',
    'Isti',
    'gapszi',
  ]),
  TranslatorGroup('Malayalam', <String>[
    'Mathew TK',
  ]),
  TranslatorGroup('Nederlands', <String>[
    'Blinkin',
    'Bryanx',
    'Jelle den Butter',
    'Mark Macaré',
    'chrrris1987',
  ]),
  TranslatorGroup('Norsk', <String>[
    'nitovf9292',
  ]),
  TranslatorGroup('Polski', <String>[
    'Adam Jurkiewicz',
    'Arkadiusz Bubak',
    'Jan Wojtecki',
    'plitwin',
  ]),
  TranslatorGroup('Português', <String>[
    'Alinson Xavier',
    'Bernardo Lopes',
    'Gustavo Lima',
    'Martim Parente',
    'Sofia Neves',
    'Thamara Andrade',
  ]),
  TranslatorGroup('Română', <String>[
    'Alex V.',
    'Andreea Muscalagiu',
    'Andrei Pleș',
    'StoP4Me',
    'bearsdens',
  ]),
  TranslatorGroup('Slovak', <String>[
    'dukelc',
  ]),
  TranslatorGroup('Slovenian', <String>[
    'dusanstrgar',
  ]),
  TranslatorGroup('Slovenščina', <String>[
    'Dušan Strgar',
  ]),
  TranslatorGroup('Suomen kieli', <String>[
    'Antti Kallio',
    'Elina Salminen',
    'Sofia Veijonen',
  ]),
  TranslatorGroup('Svenska', <String>[
    'Alexander Jansson',
    'David',
    'Robin',
  ]),
  TranslatorGroup('Telugu', <String>[
    'easyrepro',
  ]),
  TranslatorGroup('Tiếng Việt', <String>[
    'Anh Quân',
    'Huy Ngo',
    'Lương Vĩnh Khang',
    'Trần Thái',
    'bruhwut',
    'pnhpnh',
  ]),
  TranslatorGroup('Türkçe', <String>[
    'Alparslan Şakçi',
    'Caner Başaran',
    'Evren',
    'Ishmaeel',
    'hodanli',
  ]),
  TranslatorGroup('Čeština', <String>[
    'Radek Kuklík',
    'Tomáš Borovec',
    'andaryon',
    'boban77',
  ]),
  TranslatorGroup('Ελληνικά', <String>[
    'Alexander Haronitakis',
    'Andreas Michelakis',
    'DionysosDV',
    'c.m',
  ]),
  TranslatorGroup('Български', <String>[
    'Mihail Stefanov',
  ]),
  TranslatorGroup('Русский', <String>[
    'Andrew Firnes',
    'Diana Karaseva',
    'Dmitriy Bogdanov',
    'Tanya',
    'engineeringforgood',
  ]),
  TranslatorGroup('Українська', <String>[
    'Andrij Mizyk',
    'Oglaigh Rystard',
    'Prosta4ok_ua',
    'Rystard',
    'Yurii Stavytskyi',
    'taras-ko',
  ]),
  TranslatorGroup('српски', <String>[
    'OP Smosher',
    'Slobodan Simić',
    'Đorđe Vasiljević',
  ]),
  TranslatorGroup('עברית‎', <String>[
    'Ohad Edri',
    'Omry Cohen',
    'Yoav Argov',
  ]),
  TranslatorGroup('العَرَبِية‎', <String>[
    'Al Alloush',
    'Boula',
    'Israa Z',
    'Mahdi Nasiri',
    'Michael Malak',
    'Saeed Esmaili',
    'Sief Tarek',
    'alalloush',
    'mohmans',
    'reyhoon',
  ]),
  TranslatorGroup('فارسی‎', <String>[
    'Mahdi Nasiri',
  ]),
  TranslatorGroup('हिन्दी', <String>[
    'Aman Satnami',
    'Niraj Yadav',
  ]),
  TranslatorGroup('தமிழ்‎', <String>[
    'Anshoe',
    'Aravinth_Earth',
    'Magimai Prakasam',
    'Mohammed Imthath',
    'magimai',
  ]),
  TranslatorGroup('中文', <String>[
    'Bowie Chen',
    'JY3',
    'Jo Chuang',
    'JoeLi',
    'KMakoto',
    'Lee',
    'Limin Lu',
    'Liveeasy',
    'Star7',
    'Ting-Hua',
    'XuToTo',
    'hypnotichemionus',
    'yoding',
    '黄克',
  ]),
  TranslatorGroup('日本語', <String>[
    'Naofumi F',
    'Tomairuka',
    'ayane.m',
    'mimizuk',
    'pi hobbes',
    'yukitsubaki',
    '長谷川知里',
  ]),
  TranslatorGroup('한국어', <String>[
    'Josh Graham',
    'PILHA PARK',
    'Seoyul',
    'Sumin Son',
  ]),
  ];

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  /// `private var developerCountdown = 5` — per instance, never persisted.
  int _developerCountdown = 5;

  Preferences get _preferences =>
      widget.preferences ?? context.read<AppScope>().preferences;

  /// `AboutView.init` reads `currentTheme()`, so the About screen picks up
  /// `PureBlackTheme` along with everything else. [Brightness] cannot make that
  /// distinction — both dark variants report `Brightness.dark` — so this goes
  /// through the shared [coreThemeOf], which reads the theme the `ThemeData`
  /// was built from.
  core.Theme get _coreTheme => coreThemeOf(context);

  Color get _aboutScreenColor => Theme.of(context).brightness == Brightness.dark
      ? AboutScreen.aboutScreenColorDark
      : AboutScreen.aboutScreenColorLight;

  /// `AboutScreen.onPressDeveloperCountdown()`.
  void _onPressDeveloperCountdown() {
    _developerCountdown--;
    if (_developerCountdown == 0) {
      _preferences.isDeveloper = true;
      _showMessage(L10n.of(context).youAreNowADeveloper);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// `Context.startActivitySafely(intent)`.
  Future<void> _open(Uri uri) async {
    final onOpenLink = widget.onOpenLink;
    final handled = onOpenLink == null ? false : await onOpenLink(uri);
    if (!handled && mounted) {
      _showMessage(L10n.of(context).activityNotFound);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = _coreTheme;
    final accent = _aboutScreenColor;

    return Scaffold(
      backgroundColor: _toFlutterColor(theme.appBackgroundColor),
      appBar: AppBar(
        title: Text(l10n.about),
        // `setupToolbar(..., color = PaletteColor(11), ...)`, including the
        // branch it makes on `?attr/useHabitColorAsPrimary`: the palette blue
        // only in the light theme, `?attr/colorPrimary` in the dark ones.
        backgroundColor: _toFlutterColor(
          theme.toolbarColorFor(theme.colorOf(const core.PaletteColor(11))),
        ),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      // `applyBottomInset` on the About screen's inner layout
      // (`platform-glue.window-insets#5`): the last card has to clear the
      // navigation bar, which the scroll view alone does not do.
      body: BottomInset(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Card(
                theme: theme,
                children: <Widget>[
                  // `android:layout_width="100dp" android:layout_height="100dp"`
                  // — a fixed square, not stretched by the card around it.
                  const Padding(
                    padding: EdgeInsets.all(6),
                    child: Center(
                      child: SizedBox(
                        key: AboutScreen.appIconKey,
                        width: 100,
                        height: 100,
                        child: IntroIcon1(size: 100),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l10n.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    key: AboutScreen.versionKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: _onPressDeveloperCountdown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        l10n.versionN(widget.version),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _toFlutterColor(theme.mediumContrastTextColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _Card(
                key: AboutScreen.linksCardKey,
                theme: theme,
                children: <Widget>[
                  _CardHeader(text: l10n.links, color: accent),
                  _LinkItem(
                    text: l10n.prefRateThisApp,
                    theme: theme,
                    onTap: () => _open(AboutLinks.rateApp),
                  ),
                  _LinkItem(
                    text: l10n.prefSendFeedback,
                    theme: theme,
                    onTap: () => _open(AboutLinks.sendFeedback),
                  ),
                  _LinkItem(
                    text: l10n.helpTranslate,
                    theme: theme,
                    onTap: () => _open(AboutLinks.helpTranslate),
                  ),
                  _LinkItem(
                    text: l10n.prefViewSourceCode,
                    theme: theme,
                    onTap: () => _open(AboutLinks.viewSourceCode),
                  ),
                  _LinkItem(
                    text: l10n.prefViewPrivacy,
                    theme: theme,
                    onTap: () => _open(AboutLinks.privacyPolicy),
                  ),
                ],
              ),
              _Card(
                key: AboutScreen.developersCardKey,
                theme: theme,
                children: <Widget>[
                  _CardHeader(text: l10n.developers, color: accent),
                  for (final developer in AboutScreen.developers)
                    _Item(text: developer, theme: theme),
                  _LinkItem(
                    text: l10n.viewAllContributors,
                    theme: theme,
                    onTap: () => _open(AboutLinks.codeContributors),
                  ),
                ],
              ),
              _Card(
                key: AboutScreen.translatorsCardKey,
                theme: theme,
                children: <Widget>[
                  _CardHeader(text: l10n.translators, color: accent),
                  for (final group in AboutScreen.translators) ...<Widget>[
                    _LanguageItem(text: group.language, theme: theme),
                    for (final name in group.names)
                      _Item(text: name, theme: theme),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// `@style/Card` inside `@style/CardList`.
class _Card extends StatelessWidget {
  const _Card({required this.theme, required this.children, super.key});

  final core.Theme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 8, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _toFlutterColor(theme.cardBackgroundColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// `@style/CardHeader`.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// `@style/About.Item`.
class _Item extends StatelessWidget {
  const _Item({required this.text, required this.theme});

  final String text;
  final core.Theme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: TextStyle(
          fontSize: theme.regularTextSize,
          color: _toFlutterColor(theme.highContrastTextColor),
        ),
      ),
    );
  }
}

/// `@style/About.Item.Language`.
class _LanguageItem extends StatelessWidget {
  const _LanguageItem({required this.text, required this.theme});

  final String text;
  final core.Theme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      // `android:background="?attr/contrast20"`
      color: _toFlutterColor(theme.lowContrastTextColor),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: TextStyle(
          fontSize: theme.smallTextSize,
          fontWeight: FontWeight.bold,
          color: _toFlutterColor(theme.highContrastTextColor),
        ),
      ),
    );
  }
}

/// `@style/About.Item.Clickable`.
class _LinkItem extends StatelessWidget {
  const _LinkItem({
    required this.text,
    required this.theme,
    required this.onTap,
  });

  final String text;
  final core.Theme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          text,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: theme.regularTextSize,
            color: _toFlutterColor(theme.highContrastTextColor),
          ),
        ),
      ),
    );
  }
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
