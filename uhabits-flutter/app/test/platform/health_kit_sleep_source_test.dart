// ignore_for_file: implementation_imports
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/health_kit_sleep_source.dart';
import 'package:uhabits_core/src/io/logging.dart';
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
      await source.enableBackgroundDelivery(() async {});
    });

    test('and the reason is written down', () async {
      // Background delivery needs an entitlement a provisioning profile can
      // lack, and a refusal is indistinguishable in the app from a watch that
      // recorded nothing: nights simply do not appear until the app is opened.
      // The log is the only place the difference exists.
      answerWith((MethodCall call) async {
        throw PlatformException(code: 'missing-entitlement');
      });
      final _RecordingLogging logging = _RecordingLogging();
      final HealthKitSleepSource source =
          HealthKitSleepSource(logging: logging);

      await source.enableBackgroundDelivery(() async {});

      expect(
        logging.lines.where((String l) =>
            l.contains('enableBackgroundDelivery') &&
            l.contains('missing-entitlement')),
        isNotEmpty,
        reason: 'sleep.sync#6',
      );
    });

    test('an absent store is not a refusal, and is remembered as such',
        () async {
      // A refusal is reconsidered by asking again; there being nothing to ask
      // is not. The card offers access only while there is something behind
      // the offer.
      answerWith((MethodCall call) async {
        throw PlatformException(
          code: HealthKitSleepSource.noStoreCode,
          message: 'No health data on this device.',
        );
      });
      final HealthKitSleepSource source = HealthKitSleepSource();
      expect(source.hasHealthStore, isTrue,
          reason: 'sleep.ui#9 — until the platform says otherwise');

      expect(await source.requestAuthorization(), isFalse,
          reason: 'sleep.ui#9');
      expect(source.hasHealthStore, isFalse, reason: 'sleep.ui#9');
    });

    test('an ordinary refusal leaves the offer standing', () async {
      // The person said no. They can say yes later, and the card has to keep
      // asking.
      answerWith((MethodCall call) async => false);
      final HealthKitSleepSource source = HealthKitSleepSource();

      expect(await source.requestAuthorization(), isFalse,
          reason: 'sleep.ui#9');
      expect(source.hasHealthStore, isTrue, reason: 'sleep.ui#9');
    });

    test('an unrelated platform failure is not read as an absent store',
        () async {
      answerWith((MethodCall call) async {
        throw PlatformException(code: 'busy');
      });
      final HealthKitSleepSource source = HealthKitSleepSource();

      expect(await source.readSegments(0, 1), isEmpty, reason: 'sleep.ui#9');
      expect(source.hasHealthStore, isTrue,
          reason: 'sleep.ui#9 — a transient failure must not withdraw the '
              'offer for the rest of the session');
    });

    test('a platform that is simply absent is not worth a line', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final _RecordingLogging logging = _RecordingLogging();
      await HealthKitSleepSource(logging: logging).readSegments(0, 1);
      expect(logging.lines, isEmpty,
          reason: 'sleep.sync#6 — every widget test and every platform but '
              'iOS is in this state, and none of them has a problem');
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
      final HealthKitSleepSource source = HealthKitSleepSource();
      await source.enableBackgroundDelivery(() async => calls++);

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
      final HealthKitSleepSource source = HealthKitSleepSource();
      await source.enableBackgroundDelivery(() async => calls++);

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
      await source.enableBackgroundDelivery(() async {});
    });
  });
}

/// Keeps what the source logged.
class _RecordingLogging implements Logging {
  final List<String> lines = <String>[];

  @override
  Logger getLogger(String name) => _RecordingLogger(name, lines);
}

class _RecordingLogger implements Logger {
  _RecordingLogger(this.name, this.lines);

  final String name;
  final List<String> lines;

  @override
  void debug(String message) => lines.add('$name: $message');

  @override
  void error(Object msgOrException, [StackTrace? stackTrace]) =>
      lines.add('$name: $msgOrException');

  @override
  void info(String message) => lines.add('$name: $message');
}
