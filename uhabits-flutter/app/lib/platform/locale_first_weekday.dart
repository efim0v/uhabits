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
/// Both read the DEVICE locale, region included
/// (`audit9.first-weekday-follows-the-device-locale#1`), so the locale here is
/// [DeviceLocale] and never the one the widget tree resolved: the app ships no
/// en_GB translation, and an en_GB phone must still start its week on Monday.
///
/// Flutter's per-locale copy of the same CLDR table is `intl`'s
/// `DateSymbols.FIRSTDAYOFWEEK`, 0 = Monday … 6 = Sunday — a third
/// convention, and the one [MaterialLocalizations.firstDayOfWeekIndex] is built
/// out of. [calendarWeekdayFromIntlFirstDay] converts it,
/// [firstWeekdayNumberOf] looks it up for a locale, and
/// [FirstWeekdayFromLocale] installs the result on the core hook.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
// The preferences layer is not re-exported from uhabits_core.dart; like
// lib/state/app_scope.dart, this file reaches it by its `src` path.
// ignore: implementation_imports
import 'package:uhabits_core/src/preferences/preferences.dart';

import 'device_locale.dart';

/// `GregorianCalendar(locale).firstDayOfWeek`, from `intl`'s copy of the same
/// CLDR table.
///
/// [localeName] is an `intl` locale name — `en_GB`, `es_MX`, `pt_BR`. A locale
/// `intl` has no data for degrades through [resolveDateLocaleName], the way
/// Java degrades to the root locale.
int firstWeekdayNumberOf(String? localeName) => calendarWeekdayFromIntlFirstDay(
  intl.DateFormat.yMMMMEEEEd(
    resolveDateLocaleName(localeName),
  ).dateSymbols.FIRSTDAYOFWEEK,
);

/// `intl` numbers `FIRSTDAYOFWEEK` Monday 0 … Sunday 6; the model everywhere
/// else counts 1 for Sunday through 7 for Saturday
/// (`settings.preferences.first-weekday#12`).
///
/// The `+ 1` is the step `MaterialLocalizations.firstDayOfWeekIndex` already
/// takes to reach its own 0 = Sunday index; the second one is this port's.
int calendarWeekdayFromIntlFirstDay(int firstDayOfWeek) =>
    (firstDayOfWeek + 1) % 7 + 1;

/// The JS conversion of `settings.preferences.first-weekday#13`, kept as its
/// own function because it is the one piece of arithmetic in that rule:
/// CLDR numbers Monday 1 … Sunday 7, and `firstDay % 7 + 1` maps that onto
/// Sunday 1 … Saturday 7.
int calendarWeekdayFromCldr(int cldrFirstDay) => cldrFirstDay % 7 + 1;

/// The fallback the JS implementation uses when `Intl` is unavailable, and the
/// value the core hook carries until this file replaces it.
const int fallbackFirstWeekdayNumber = 1;

/// Installs [firstWeekdayNumberOf] on the core hook for the device locale.
///
/// Mount it inside `MaterialApp.builder`, below the localizations delegates and
/// below a [DeviceLocale]: the locale comes from the device, but the CLDR table
/// it is looked up in is the one `GlobalMaterialLocalizations` installs into
/// `intl` when its delegate loads. With no [MaterialLocalizations] above, that
/// table holds only en_US and there is nothing locale-specific to read — the
/// port's version of the JS "Intl is unavailable" branch — so the hook is left
/// alone rather than overwritten with a fallback.
///
/// The assignment is repeated on every rebuild, and [DeviceLocale] rebuilds
/// this on every `didChangeLocales`, so a locale change — the Android 13
/// per-app language picker, which is what `platform-glue.locale-config` is
/// about — is picked up without a restart.
class FirstWeekdayFromLocale extends StatelessWidget {
  const FirstWeekdayFromLocale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations? localizations =
        Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
    if (localizations != null) {
      final int number = firstWeekdayNumberOf(DeviceLocale.nameOf(context));
      getFirstWeekdayNumberAccordingToLocale = () => number;
    }
    return child;
  }
}
