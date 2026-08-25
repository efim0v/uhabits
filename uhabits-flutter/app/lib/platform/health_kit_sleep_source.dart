import 'package:flutter/services.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Apple Health, as a [SleepDataSource].
///
/// Holds no logic beyond decoding: the native side hands over raw stretches
/// and this turns them into core value objects. Merging, deduplication and
/// scoring all happen in plain Dart, where they can be tested.
class HealthKitSleepSource implements SleepDataSource {
  HealthKitSleepSource({
    this.channel = const MethodChannel(methodChannelName),
    this.onDataChanged,
  });

  final MethodChannel channel;

  /// Called when the platform reports that new sleep was recorded.
  final Future<void> Function()? onDataChanged;

  /// Must match the constant in `ios/Runner/HealthKitSleepPlugin.swift`.
  static const String methodChannelName = 'org.isoron.uhabits/health_sleep';

  /// The call the native side makes when background delivery fires.
  static const String dataChangedMethod = 'healthDataChanged';

  /// How the native side names each stretch.
  ///
  /// Apple adds values to `HKCategoryValueSleepAnalysis` between releases, so
  /// the native side passes the name through and anything unrecognised is
  /// dropped here rather than guessed at.
  static const Map<String, SleepSegmentKind> _kinds = <String, SleepSegmentKind>{
    'inBed': SleepSegmentKind.inBed,
    'asleepCore': SleepSegmentKind.asleepCore,
    'asleepDeep': SleepSegmentKind.asleepDeep,
    'asleepREM': SleepSegmentKind.asleepRem,
    'asleepUnspecified': SleepSegmentKind.asleepUnspecified,
    'awake': SleepSegmentKind.awake,
  };

  /// Starts listening for the native side's change notifications.
  void listen() {
    channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == dataChangedMethod) {
        await onDataChanged?.call();
      }
      return null;
    });
  }

  @override
  Future<bool> isAuthorized() =>
      _ask<bool>('authorizationStatus').then((bool? v) => v ?? false);

  @override
  Future<bool> requestAuthorization() =>
      _ask<bool>('requestAuthorization').then((bool? v) => v ?? false);

  @override
  Future<List<SleepSegment>> readSegments(int fromMillis, int toMillis) async {
    final List<Object?>? raw = await _ask<List<Object?>>(
      'readSegments',
      <String, Object?>{'from': fromMillis, 'to': toMillis},
    );
    if (raw == null) return const <SleepSegment>[];

    final result = <SleepSegment>[];
    for (final Object? item in raw) {
      if (item is! Map) continue;
      final SleepSegmentKind? kind = _kinds[item['kind']];
      final Object? start = item['start'];
      final Object? end = item['end'];
      if (kind == null || start is! int || end is! int) continue;
      result.add(SleepSegment(
        startMillis: start,
        endMillis: end,
        kind: kind,
        sourceId: item['source'] is String ? item['source'] as String : '',
      ));
    }
    return result;
  }

  @override
  Future<void> writeSession(int startMillis, int endMillis) => _ask<void>(
        'writeSession',
        <String, Object?>{'start': startMillis, 'end': endMillis},
      );

  @override
  Future<void> enableBackgroundDelivery() => _ask<void>(
        'enableBackgroundDelivery',
      );

  /// Every call goes through here, because every one of them has the same
  /// answer to failure: the platform declining, or not being there at all, is
  /// something the habit carries on without.
  Future<T?> _ask<T>(String method, [Object? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
