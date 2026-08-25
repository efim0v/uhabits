import 'dart:io';

import 'package:uhabits_core/uhabits_core.dart';

import 'health_kit_sleep_source.dart';

/// The sleep source this platform can offer.
///
/// Only iOS has one in this work. Android answers every question the same way
/// a refusal does, so a habit there runs on hand-entered nights and nothing
/// above this line has to know which platform it is on.
SleepDataSource defaultSleepDataSource() =>
    Platform.isIOS ? HealthKitSleepSource() : const NoSleepDataSource();
