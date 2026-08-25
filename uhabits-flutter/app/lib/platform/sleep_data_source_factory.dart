// The core logging layer is reached by its `src` path, exactly as
// lib/platform/auto_backup.dart reaches it.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/uhabits_core.dart';

import 'health_kit_sleep_source.dart';

/// The sleep source this platform can offer.
///
/// Only iOS has one in this work. Android answers every question the same way
/// a refusal does, so a habit there runs on hand-entered nights and nothing
/// above this line has to know which platform it is on.
SleepDataSource defaultSleepDataSource({Logging? logging}) => Platform.isIOS
    ? HealthKitSleepSource(logging: logging)
    : const NoSleepDataSource();
