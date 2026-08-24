/// The port's `android.text.format.DateFormat.getTimeFormat(context)`.
///
/// `utils/DateExtensions.kt`'s `formatTime(context, hours, minutes)` builds a
/// `Date` out of `(hours * 60 + minutes)` minutes since the epoch, formats it
/// with `DateFormat.getTimeFormat(context)` and forces the formatter's zone to
/// UTC. That platform call is
/// `SimpleDateFormat(LocaleData.get(locale).timeFormat_(h|H)m, locale)` — i.e.
/// ICU's best pattern for the "hm" or "Hm" skeleton, chosen by
/// `DateFormat.is24HourFormat(context)` — and its `locale` is
/// `context.getResources().getConfiguration().locale`.
///
/// That configuration locale is the DEVICE locale, region and all, exactly like
/// the `Locale.getDefault()` that `audit9.chart-dates-follow-the-device-
/// locale#1`, `audit9.first-weekday-follows-the-device-locale#1` and
/// `audit10.weekday-name-rows-follow-the-device-locale#1` record for dates,
/// week origins and weekday names. Android resolves the app's *strings*
/// separately and falls back to `values/` when it ships no translation for the
/// region, so an en-AU phone reads the plain English strings and still prints
/// the reminder as "8:30 am". Only the UI language follows the resolved locale;
/// the time pattern is one more data convention that follows the device
/// (`audit15.subtitle-card-reminder-time-ignores-the-device-locale#1`).
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

import 'device_locale.dart';

/// `formatTime(context, hours, minutes)`, given the minute of the day the
/// Kotlin arithmetic wraps to (`SubtitleCardState.minuteOfDay`).
///
/// [use24HourFormat] stands in for `DateFormat.is24HourFormat(context)` and
/// defaults to `MediaQuery.alwaysUse24HourFormat`, Flutter's window onto the
/// same system setting. It picks the skeleton, the device locale supplies the
/// pattern:
///
///  * `true` → the "Hm" skeleton: "08:30" for en and ko, "8:30" for es.
///  * `false` → the "jm" skeleton: "8:30 AM" for en-US, "8:30 am" for en-AU,
///    "오전 8:30" for ko.
///
/// Known divergence: `package:intl` carries no forced-12-hour "hm" skeleton,
/// only the locale-preferred "jm", so a user who overrides a 24-hour locale's
/// system setting to 12 hours keeps that locale's 24-hour pattern where Android
/// would switch to "h:mm a". `MaterialLocalizations.formatTimeOfDay` reads
/// `alwaysUse24HourFormat: false` the same way.
String formatDeviceTime(
  BuildContext context, {
  required int minuteOfDay,
  bool? use24HourFormat,
}) {
  final bool use24 =
      use24HourFormat ?? MediaQuery.alwaysUse24HourFormatOf(context);
  final String localeName = resolveDateLocaleName(DeviceLocale.nameOf(context));
  // The formatter's zone is forced to UTC upstream, so the rendered clock is
  // exactly `minuteOfDay` and no zone can shift it.
  final DateTime time = DateTime.utc(
    2000,
    1,
    1,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
  );
  final intl.DateFormat format = use24
      ? intl.DateFormat.Hm(localeName)
      : intl.DateFormat.jm(localeName);
  return format.format(time);
}
