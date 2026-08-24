/// Android's resource-resolution rule, which Flutter does not have.
///
/// `Resources.getString` never fails on an unknown locale. Android matches the
/// device's `LocaleList` against the `values-<lang>` directories the APK ships
/// and falls back to the default set, `res/values/`, for anything it cannot
/// match — which is why
/// `uhabits-android/src/main/res/values/strings.xml:21-23` may open with
/// `tools:ignore="MissingTranslation"` at all. The default set is English, so a
/// phone set to Thai, Estonian, Lithuanian, Malay or Bengali runs Loop in plain
/// English while `Locale.getDefault()` still reports th/et/lt for the date and
/// number conventions (see lib/platform/device_locale.dart).
///
/// Flutter has no default set. `basicLocaleListResolution` ends at
/// `supportedLocales.first`, and `flutter gen-l10n` emits that list
/// alphabetically by ARB filename, so this app's last resort is `Locale('af')`:
/// an ARB with 22 of the template's ~200 messages, which also pulls
/// `GlobalMaterialLocalizations` — every date picker, every OK/Cancel label —
/// into Afrikaans. Reordering the generated list is not a remedy; it is
/// regenerated from the filenames on every `flutter gen-l10n`. The rule belongs
/// at the points that consume it, which is this file.
///
/// Two of them consume it:
///
///  * the two `MaterialApp`s in lib/main.dart, through
///    `localeListResolutionCallback: resolveAppLocale`;
///  * `AppScope.startPlatformServices`, which has to name the notification
///    buttons before any widget exists and so cannot ask a `BuildContext`.
///
/// The second one is why this is not merely cosmetic: `lookupL10n` *throws* for
/// an unsupported language, and the only caller outside the widget tree used to
/// hand it the raw device locale.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// `res/values/` — the resource set Android serves whenever no `values-<lang>`
/// directory matches the device.
const Locale defaultResourceLocale = Locale('en');

/// The locale the app's strings should be resolved from, given the device's
/// preferred locales.
///
/// Android 7 and later resolve against the whole `LocaleList`, not just its
/// head, so a phone whose first language is untranslated but whose second one
/// is not gets the second one; that is what delegating to
/// [basicLocaleListResolution] preserves. What it does not preserve on its own
/// is the *end* of the walk: with nothing matched it answers
/// `supportedLocales.first`, where Android answers `res/values/`. So the
/// languages the app cannot serve are dropped before the walk begins, and an
/// empty remainder is answered with [defaultResourceLocale].
///
/// Dropping them first also disables the framework's country-only consolation
/// match — a `th_TW` device resolving to `zh_TW` because both are Taiwanese —
/// which Android's resolver, matching on language first, never makes.
///
/// Shaped as a [LocaleListResolutionCallback] so it can be passed straight to
/// `WidgetsApp.localeListResolutionCallback`.
Locale resolveAppLocale(
  List<Locale>? deviceLocales,
  Iterable<Locale> supportedLocales,
) {
  if (deviceLocales == null || deviceLocales.isEmpty) {
    return defaultResourceLocale;
  }
  final Set<String> translated = <String>{
    for (final Locale locale in supportedLocales) locale.languageCode,
  };
  final List<Locale> matchable = deviceLocales
      .where((Locale locale) => translated.contains(locale.languageCode))
      .toList();
  if (matchable.isEmpty) return defaultResourceLocale;
  return basicLocaleListResolution(matchable, supportedLocales);
}

/// The device's preferred locales, in order.
///
/// Read through `WidgetsBinding.instance` rather than
/// `PlatformDispatcher.instance` — the same seam, and the same reason, as
/// `deviceLocale()` in lib/platform/device_locale.dart: a widget test can drive
/// the binding's dispatcher with `platformDispatcher.localesTestValue` and
/// cannot drive the singleton at all.
List<Locale> platformLocales() {
  final PlatformDispatcher dispatcher =
      WidgetsBinding.instance.platformDispatcher;
  final List<Locale> locales = dispatcher.locales;
  return locales.isEmpty ? <Locale>[dispatcher.locale] : locales;
}

/// The app's strings for the current device, resolved the way the widget tree
/// resolves them and without a `BuildContext`.
///
/// `AndroidNotificationTray` reads its six strings from the application
/// `Context` at fire time, where a missing translation is simply the English
/// one. This is that guarantee for a caller that has no context: it can never
/// throw, so it can never take the notification tray, the reminder scheduler
/// and the widget publisher down with it.
L10n platformL10n() =>
    lookupL10n(resolveAppLocale(platformLocales(), L10n.supportedLocales));
