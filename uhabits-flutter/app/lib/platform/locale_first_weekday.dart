/// Port of the three platform implementations of
/// `expect fun getFirstWeekdayNumberAccordingToLocale(): Int`
/// (uhabits-core/.../platform/time/Dates.kt).
///
/// The core declares the function and every consumer reads it through
/// `Preferences.firstWeekday`; the value itself is platform data that pure Dart
/// cannot see, so `uhabits_core` ships a hook
/// ([getFirstWeekdayNumberAccordingToLocale]) that defaults to 1 (Sunday) —
/// the same fallback the JS implementation uses — and the app assigns the real
/// one.
///
/// The two upstream implementations, and what stands in for them here:
///
///  * JVM/Android reads `GregorianCalendar(Locale.getDefault()).firstDayOfWeek`
///    (`settings.preferences.first-weekday#4`), already in the
///    `java.util.Calendar` convention 1 = Sunday … 7 = Saturday.
///  * JS reads `Intl.Locale(navigator.language).getWeekInfo().firstDay`, which
///    is CLDR's 1 = Monday … 7 = Sunday, and converts it with
///    `firstDay % 7 + 1` (`settings.preferences.first-weekday#13`).
///
/// Flutter's per-locale table is [MaterialLocalizations.firstDayOfWeekIndex],
/// 0 = Sunday … 6 = Saturday — the same data CLDR feeds both of the above, in a
/// third convention. [firstWeekdayNumberOf] converts it, and
/// [FirstWeekdayFromLocale] installs the result on the core hook.
library;

import 'package:flutter/material.dart';
// The preferences layer is not re-exported from uhabits_core.dart; like
// lib/state/app_scope.dart, this file reaches it by its `src` path.
// ignore: implementation_imports
import 'package:uhabits_core/src/preferences/preferences.dart';

/// `GregorianCalendar(locale).firstDayOfWeek`, from Flutter's copy of the same
/// CLDR table.
///
/// [MaterialLocalizations.firstDayOfWeekIndex] is 0 for Sunday through 6 for
/// Saturday; the model everywhere else counts 1 for Sunday through 7 for
/// Saturday (`settings.preferences.first-weekday#12`), so the conversion is a
/// single increment.
int firstWeekdayNumberOf(MaterialLocalizations localizations) =>
    localizations.firstDayOfWeekIndex + 1;

/// The JS conversion of `settings.preferences.first-weekday#13`, kept as its
/// own function because it is the one piece of arithmetic in that rule:
/// CLDR numbers Monday 1 … Sunday 7, and `firstDay % 7 + 1` maps that onto
/// Sunday 1 … Saturday 7.
int calendarWeekdayFromCldr(int cldrFirstDay) => cldrFirstDay % 7 + 1;

/// The fallback the JS implementation uses when `Intl` is unavailable, and the
/// value the core hook carries until this file replaces it.
const int fallbackFirstWeekdayNumber = 1;

/// Installs [firstWeekdayNumberOf] on the core hook for the ambient locale.
///
/// Mount it inside `MaterialApp.builder`, below the localizations delegates:
/// `Locale.getDefault()` is process-global on Android, and the closest thing a
/// Flutter app has to it is the locale the widget tree is currently built with.
/// The assignment is repeated on every rebuild so that a locale change — the
/// Android 13 per-app language picker, which is what
/// `platform-glue.locale-config` is about — is picked up without a restart.
class FirstWeekdayFromLocale extends StatelessWidget {
  const FirstWeekdayFromLocale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations? localizations =
        Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
    if (localizations != null) {
      final int number = firstWeekdayNumberOf(localizations);
      getFirstWeekdayNumberAccordingToLocale = () => number;
    }
    return child;
  }
}
