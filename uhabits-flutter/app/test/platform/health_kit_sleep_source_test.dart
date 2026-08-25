import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/health_kit_sleep_source.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel(HealthKitSleepSource.methodChannelName);
  final List<MethodCall> log = <MethodCall>[];

  void answerWith(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      log.add(call);
      return handler(call);
    });
  }

  setUp(() {
    log.clear();
    answerWith((MethodCall call) async {
      switch (call.method) {
        case 'authorizationStatus':
        case 'requestAuthorization':
          return true;
        case 'readSegments':
          return <Object?>[
            <Object?, Object?>{
              'start': 1756080000000,
              'end': 1756105200000,
              'kind': 'asleepCore',
              'source': 'com.apple.health.watch',
            },
            <Object?, Object?>{
              'start': 1756076400000,
              'end': 1756108800000,
              'kind': 'inBed',
              'source': 'com.apple.health.watch',
            },
          ];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('reading', () {
    test('decodes stretches into core value objects', () async {
      final List<SleepSegment> segments =
          await HealthKitSleepSource().readSegments(0, 1);
      expect(segments.length, 2, reason: 'sleep.sync#5');
      expect(segments.first.kind, SleepSegmentKind.asleepCore,
          reason: 'sleep.sync#5');
      expect(segments.first.startMillis, 1756080000000,
          reason: 'sleep.sync#5');
      expect(segments.first.sourceId, 'com.apple.health.watch',
          reason: 'sleep.sync#5');
      expect(segments.last.kind, SleepSegmentKind.inBed,
          reason: 'sleep.sync#5');
    });

    test('passes the window through unchanged', () async {
      await HealthKitSleepSource().readSegments(111, 222);
      expect(log.single.method, 'readSegments', reason: 'sleep.sync#1');
      expect(log.single.arguments, <String, Object?>{'from': 111, 'to': 222},
          reason: 'sleep.sync#1');
    });

    test('every named kind is understood', () async {
      // The names are a contract with the Swift side; a rename on either side
      // would silently drop every stretch of that kind.
      const List<String> names = <String>[
        'inBed',
        'asleepCore',
        'asleepDeep',
        'asleepREM',
        'asleepUnspecified',
        'awake',
      ];
      answerWith((MethodCall call) async => <Object?>[
            for (final String name in names)
              <Object?, Object?>{
                'start': 0,
                'end': 60000,
                'kind': name,
                'source': 'watch',
              },
          ]);
      final List<SleepSegment> segments =
          await HealthKitSleepSource().readSegments(0, 1);
      expect(segments.length, names.length, reason: 'sleep.sync#5');
      expect(
        segments.map((SleepSegment s) => s.kind).toSet().length,
        names.length,
        reason: 'sleep.sync#5',
      );
    });

    test('an unknown kind is dropped, not guessed at', () async {
      // Apple adds values to HKCategoryValueSleepAnalysis between releases.
      // A new one must not be quietly filed as sleep.
      answerWith((MethodCall call) async => <Object?>[
            <Object?, Object?>{
              'start': 0,
              'end': 1,
              'kind': 'asleepSomethingNew',
              'source': 'watch',
            },
            <Object?, Object?>{
              'start': 0,
              'end': 1,
              'kind': 'unknown',
              'source': 'watch',
            },
            <Object?, Object?>{
              'start': 0,
              'end': 1,
              'kind': 'asleepCore',
              'source': 'watch',
            },
          ]);
      final List<SleepSegment> segments =
          await HealthKitSleepSource().readSegments(0, 1);
      expect(segments.length, 1, reason: 'sleep.sync#5');
      expect(segments.single.kind, SleepSegmentKind.asleepCore,
          reason: 'sleep.sync#5');
    });

    test('a malformed entry is dropped rather than throwing', () async {
      answerWith((MethodCall call) async => <Object?>[
            <Object?, Object?>{'kind': 'asleepCore'}, // no instants
            <Object?, Object?>{
              'start': 'not a number',
              'end': 1,
              'kind': 'asleepCore',
            },
            'not even a map',
          ]);
      expect(await HealthKitSleepSource().readSegments(0, 1), isEmpty,
          reason: 'sleep.sync#5');
    });

    test('a missing source id becomes empty, not null', () async {
      answerWith((MethodCall call) async => <Object?>[
            <Object?, Object?>{'start': 0, 'end': 1, 'kind': 'asleepCore'},
          ]);
      final List<SleepSegment> segments =
          await HealthKitSleepSource().readSegments(0, 1);
      expect(segments.single.sourceId, '', reason: 'sleep.sync#5');
    });
  });

  group('when the platform says no', () {
    test('a refusal is an answer, not a failure', () async {
      answerWith((MethodCall call) async {
        throw PlatformException(code: 'denied');
      });
      final HealthKitSleepSource source = HealthKitSleepSource();
      expect(await source.requestAuthorization(), isFalse,
          reason: 'sleep.sync#5');
      expect(await source.isAuthorized(), isFalse, reason: 'sleep.sync#5');
      expect(await source.readSegments(0, 1), isEmpty, reason: 'sleep.sync#5');
      await source.writeSession(0, 1);
      await source.enableBackgroundDelivery();
    });

    test('a platform with no plugin at all behaves the same', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final HealthKitSleepSource source = HealthKitSleepSource();
      expect(await source.isAuthorized(), isFalse, reason: 'sleep.sync#5');
      expect(await source.readSegments(0, 1), isEmpty, reason: 'sleep.sync#5');
    });

    test('a null answer is not mistaken for a yes', () async {
      answerWith((MethodCall call) async => null);
      expect(await HealthKitSleepSource().isAuthorized(), isFalse,
          reason: 'sleep.sync#5');
    });
  });

  group('background delivery', () {
    test('a change notification reaches the callback', () async {
      var calls = 0;
      final HealthKitSleepSource source =
          HealthKitSleepSource(onDataChanged: () async => calls++);
      source.listen();

      await TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .handlePlatformMessage(
        HealthKitSleepSource.methodChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(HealthKitSleepSource.dataChangedMethod),
        ),
        (_) {},
      );

      expect(calls, 1, reason: 'sleep.sync#1');
    });

    test('an unrelated call does not trigger it', () async {
      var calls = 0;
      final HealthKitSleepSource source =
          HealthKitSleepSource(onDataChanged: () async => calls++);
      source.listen();

      await TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .handlePlatformMessage(
        HealthKitSleepSource.methodChannelName,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('somethingElse')),
        (_) {},
      );

      expect(calls, 0, reason: 'sleep.sync#1');
    });
  });

  group('the absent source', () {
    test('answers everything without a platform', () async {
      const NoSleepDataSource source = NoSleepDataSource();
      expect(await source.isAuthorized(), isFalse, reason: 'sleep.sync#5');
      expect(await source.requestAuthorization(), isFalse,
          reason: 'sleep.sync#5');
      expect(await source.readSegments(0, 1), isEmpty, reason: 'sleep.sync#5');
      await source.writeSession(0, 1);
      await source.enableBackgroundDelivery();
    });
  });
}
