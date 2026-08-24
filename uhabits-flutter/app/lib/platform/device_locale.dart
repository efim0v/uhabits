/// The port's `java.util.Locale.getDefault()`.
///
/// Every locale-derived *data* convention upstream reads the device locale,
/// region and all — never the locale the app's strings were resolved against:
///
///  * `getFirstWeekdayNumberAccordingToLocale()` is
///    `GregorianCalendar(Locale.getDefault()).firstDayOfWeek`
///    (`audit9.first-weekday-follows-the-device-locale#1`);
///  * `NumberDialog` prefills with `DecimalFormat("#.##")`, builds its key
///    listener from `DecimalFormatSymbols.getInstance().decimalSeparator` and
///    parses with `NumberFormat.getInstance()`
///    (`audit9.number-popup-follows-the-device-locale#1`);
///  * every chart, the list header, the weekday picker and the history editor
///    build a `JavaLocalDateFormatter(Locale.getDefault())`
///    (`audit9.chart-dates-follow-the-device-locale#1`).
///
/// On Android those two locales genuinely differ. A phone set to English
/// (United Kingdom) reports `en_GB` from `Locale.getDefault()` while the
/// resource resolver, finding no `values-en-rGB/`, serves the plain `values/`
/// strings. The port's equivalent split is [DeviceLocale] on one side and
/// `Localizations.localeOf` — `basicLocaleListResolution` against
/// `L10n.supportedLocales`, a list that is language-only for everything but
/// pt_BR, pt_PT, zh_CN, zh_TW and sr_Latn — on the other. Reading the resolved
/// locale for data conventions silently drops the region: en_GB starts its
/// week on Sunday, es_MX formats "1,5", en_GB dates come out "Jan 25, 2015".
///
/// The UI *language* must keep coming from the resolved locale. This file is
/// only about the conventions.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

/// `Locale.getDefault()`.
///
/// The platform's preferred locale — the head of
/// `PlatformDispatcher.locales`, which on Android is the device language list
/// as the per-app language picker leaves it. Read through
/// `WidgetsBinding.instance` rather than `PlatformDispatcher.instance` so a
/// widget test can drive it with `platformDispatcher.localesTestValue`.
Locale deviceLocale() {
  final PlatformDispatcher dispatcher =
      WidgetsBinding.instance.platformDispatcher;
  final List<Locale> locales = dispatcher.locales;
  return locales.isEmpty ? dispatcher.locale : locales.first;
}

/// [deviceLocale] spelled the way `intl` spells a locale: `en_GB`, `pt_BR`,
/// `sr_Latn`.
String deviceLocaleName() =>
    intl.Intl.canonicalizedLocale(deviceLocale().toString());

/// The locale `intl` will actually serve date data for, closest first.
///
/// Java has data for every locale it is handed and degrades silently;
/// `package:intl` carries a fixed table and answers for the language when it
/// has no entry for the region. `flutter_localizations` installs that table
/// for every locale it ships — `en_GB`, `en_IE`, `es_MX`, `fr_CA` among them —
/// the first time a `GlobalMaterialLocalizations` delegate loads, which is why
/// [DeviceLocale] belongs below the delegates.
///
/// Falls back to [fallbackDateLocaleName], the only locale `intl` has before
/// anything is installed.
String resolveDateLocaleName(String? localeName) {
  if (localeName == null || localeName.isEmpty) return fallbackDateLocaleName;
  final String canonical = intl.Intl.canonicalizedLocale(localeName);
  try {
    if (intl.DateFormat.localeExists(canonical)) return canonical;
    final String language = canonical.split('_').first;
    if (intl.DateFormat.localeExists(language)) return language;
  } on Exception {
    // localeExists throws, rather than returning false, while no locale data
    // at all has been initialized.
  }
  return fallbackDateLocaleName;
}

/// The locale `package:intl` ships date data for out of the box.
const String fallbackDateLocaleName = 'en_US';

/// Publishes [deviceLocale] to the subtree and keeps it current.
///
/// `Locale.getDefault()` is process-global on Android, and a configuration
/// change recreates every activity, so each view reads the new value on its
/// own. A Flutter tree rebuilds for a locale change only when the *resolved*
/// locale changes, and the resolved locale is exactly the thing that hides the
/// region — en_GB to en_US resolves to `en` both times. This scope listens to
/// `didChangeLocales` instead, so the dependents see every change the platform
/// reports.
///
/// Mount it inside `MaterialApp.builder`, below the localizations delegates:
/// [resolveDateLocaleName] needs the date data they install.
class DeviceLocale extends StatefulWidget {
  const DeviceLocale({super.key, required this.child});

  final Widget child;

  /// The device locale for [context].
  ///
  /// Depends on the enclosing [DeviceLocale] when there is one, so the caller
  /// rebuilds when the device locale changes; falls back to reading the
  /// platform directly, which is the same answer without the subscription.
  static Locale of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_DeviceLocaleScope>()
          ?.locale ??
      deviceLocale();

  /// [of] spelled the way `intl` spells a locale.
  static String nameOf(BuildContext context) =>
      intl.Intl.canonicalizedLocale(of(context).toString());

  @override
  State<DeviceLocale> createState() => _DeviceLocaleState();
}

class _DeviceLocaleState extends State<DeviceLocale>
    with WidgetsBindingObserver {
  Locale _locale = deviceLocale();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final Locale next = deviceLocale();
    if (next != _locale) setState(() => _locale = next);
  }

  @override
  Widget build(BuildContext context) =>
      _DeviceLocaleScope(locale: _locale, child: widget.child);
}

class _DeviceLocaleScope extends InheritedWidget {
  const _DeviceLocaleScope({required this.locale, required super.child});

  final Locale locale;

  @override
  bool updateShouldNotify(_DeviceLocaleScope oldWidget) =>
      oldWidget.locale != locale;
}
