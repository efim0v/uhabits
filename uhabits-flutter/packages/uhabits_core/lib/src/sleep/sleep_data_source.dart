import 'sleep_segment.dart';

/// Where nights come from.
///
/// One of the core's platform ports, alongside `Database`, `Files` and
/// `NotificationTray`: the core states what it needs, and each platform
/// supplies it. Keeping the port here is what lets the whole of the sync be
/// written and tested as plain Dart, with the platform reduced to handing over
/// raw stretches.
abstract class SleepDataSource {
  /// Whether the person has already granted access.
  Future<bool> isAuthorized();

  /// Asks for access. Returns whether it was granted.
  ///
  /// A refusal is an answer, not a failure: the habit goes on working on
  /// hand-entered nights.
  Future<bool> requestAuthorization();

  /// The raw stretches recorded between two instants, in UTC milliseconds.
  ///
  /// Returns empty when there is no access, no data, or no source at all.
  Future<List<SleepSegment>> readSegments(int fromMillis, int toMillis);

  /// Writes a night back, so a night typed in here shows up in the platform's
  /// own health app.
  Future<void> writeSession(int startMillis, int endMillis);

  /// Asks the platform to wake the app when new sleep is recorded.
  Future<void> enableBackgroundDelivery();
}

/// The source on a platform that has none.
///
/// Android has no health integration in this work, and every platform has to
/// answer the same questions, so the absence is a value rather than a null
/// that every caller would have to remember to check.
class NoSleepDataSource implements SleepDataSource {
  const NoSleepDataSource();

  @override
  Future<bool> isAuthorized() async => false;

  @override
  Future<bool> requestAuthorization() async => false;

  @override
  Future<List<SleepSegment>> readSegments(int fromMillis, int toMillis) async =>
      const <SleepSegment>[];

  @override
  Future<void> writeSession(int startMillis, int endMillis) async {}

  @override
  Future<void> enableBackgroundDelivery() async {}
}
