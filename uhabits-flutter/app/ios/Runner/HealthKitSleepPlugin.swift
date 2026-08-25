import Flutter
import Foundation
import HealthKit

/// Reads sleep out of Apple Health and hands it over raw.
///
/// Deliberately holds no logic. Which source wins, how stretches join into a
/// night, how a night is scored — all of that lives in Dart, where it is
/// covered by tests. What is here is what only the platform can do: ask for
/// access, run the query, and pass the answer along unchanged.
final class HealthKitSleepPlugin: NSObject {
  /// Must match `HealthKitSleepSource.methodChannelName` in
  /// `lib/platform/health_kit_sleep_source.dart`.
  static let channelName = "org.isoron.uhabits/health_sleep"

  /// Must match `HealthKitSleepSource.dataChangedMethod`.
  static let dataChangedMethod = "healthDataChanged"

  private let store = HKHealthStore()
  private var channel: FlutterMethodChannel?
  private var observerQuery: HKObserverQuery?

  private var sleepType: HKCategoryType? {
    HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
  }

  /// Wires the plugin to an engine, through the registrar.
  ///
  /// Deliberately not through `window?.rootViewController`: under the scene
  /// lifecycle the window is still nil while `didFinishLaunchingWithOptions`
  /// runs, so a registration written that way silently registers nothing and
  /// every call from Dart comes back as a missing plugin — which the Dart side
  /// reads, correctly but uselessly, as "no health data".
  ///
  /// The registrar is available from the application delegate itself and does
  /// not depend on the window existing.
  @discardableResult
  static func register(with registrar: FlutterPluginRegistrar) -> HealthKitSleepPlugin {
    let plugin = HealthKitSleepPlugin()
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    plugin.channel = channel
    channel.setMethodCallHandler { [weak plugin] call, result in
      plugin?.handle(call, result: result)
    }
    registrar.publish(plugin)
    return plugin
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(), let sleepType else {
      // No health data on this device at all. Not an error: the habit works
      // on hand-entered nights, and Dart reads a false the same way it reads
      // a refusal.
      result(call.method == "readSegments" ? [] : false)
      return
    }

    switch call.method {
    case "authorizationStatus":
      result(store.authorizationStatus(for: sleepType) == .sharingAuthorized)

    case "requestAuthorization":
      store.requestAuthorization(toShare: [sleepType], read: [sleepType]) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }

    case "readSegments":
      guard let arguments = call.arguments as? [String: Any],
        let from = arguments["from"] as? Int,
        let to = arguments["to"] as? Int
      else {
        result([])
        return
      }
      readSegments(from: from, to: to, type: sleepType, result: result)

    case "writeSession":
      guard let arguments = call.arguments as? [String: Any],
        let start = arguments["start"] as? Int,
        let end = arguments["end"] as? Int
      else {
        result(false)
        return
      }
      writeSession(from: start, to: end, type: sleepType, result: result)

    case "enableBackgroundDelivery":
      enableBackgroundDelivery(type: sleepType)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func readSegments(
    from: Int, to: Int, type: HKCategoryType, result: @escaping FlutterResult
  ) {
    let predicate = HKQuery.predicateForSamples(
      withStart: Self.date(fromMillis: from),
      end: Self.date(fromMillis: to),
      options: []
    )
    let query = HKSampleQuery(
      sampleType: type,
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: nil
    ) { _, samples, _ in
      let encoded = (samples as? [HKCategorySample] ?? []).map(Self.encode)
      DispatchQueue.main.async { result(encoded) }
    }
    store.execute(query)
  }

  private func writeSession(
    from: Int, to: Int, type: HKCategoryType, result: @escaping FlutterResult
  ) {
    // The undifferentiated "asleep" value, which iOS 16 renamed but did not
    // renumber. A night typed in by hand carries no stage information, so this
    // is the honest thing to write.
    let sample = HKCategorySample(
      type: type,
      value: HKCategoryValueSleepAnalysis.asleep.rawValue,
      start: Self.date(fromMillis: from),
      end: Self.date(fromMillis: to)
    )
    store.save(sample) { saved, _ in
      DispatchQueue.main.async { result(saved) }
    }
  }

  private func enableBackgroundDelivery(type: HKCategoryType) {
    guard observerQuery == nil else { return }
    let query = HKObserverQuery(sampleType: type, predicate: nil) {
      [weak self] _, completionHandler, _ in
      DispatchQueue.main.async {
        self?.channel?.invokeMethod(Self.dataChangedMethod, arguments: nil)
      }
      completionHandler()
    }
    observerQuery = query
    store.execute(query)
    store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
  }

  // MARK: - Pure conversions
  //
  // Everything below is arithmetic and naming, kept static and free of the
  // store so it can be run in tests rather than read and hoped over.

  /// The instant [millis] milliseconds after the epoch.
  static func date(fromMillis millis: Int) -> Date {
    Date(timeIntervalSince1970: Double(millis) / 1000)
  }

  /// Milliseconds since the epoch for [date], rounded toward zero.
  static func millis(from date: Date) -> Int {
    Int((date.timeIntervalSince1970 * 1000).rounded())
  }

  /// The name Dart knows a sleep value by.
  ///
  /// Apple adds cases to `HKCategoryValueSleepAnalysis` between releases. An
  /// unrecognised one is reported as such and dropped on the Dart side; it
  /// must never be filed as one of the known kinds, because a guess here would
  /// turn up as sleep the person never had.
  ///
  /// The sleep stages arrived in iOS 16. The app still runs on 13, where the
  /// only distinction Health makes is asleep or not, so the stage cases are
  /// reached behind an availability check rather than by raising the whole
  /// app's floor for one feature.
  static func kindName(for value: Int) -> String {
    if #available(iOS 16.0, *) {
      switch value {
      case HKCategoryValueSleepAnalysis.asleepCore.rawValue: return "asleepCore"
      case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: return "asleepDeep"
      case HKCategoryValueSleepAnalysis.asleepREM.rawValue: return "asleepREM"
      default: break
      }
    }
    switch value {
    case HKCategoryValueSleepAnalysis.inBed.rawValue: return "inBed"
    case HKCategoryValueSleepAnalysis.awake.rawValue: return "awake"
    // Renamed to `asleepUnspecified` in iOS 16, same raw value. Dart is told
    // the newer name on every version, so it has one name to know.
    case HKCategoryValueSleepAnalysis.asleep.rawValue:
      return "asleepUnspecified"
    default: return "unknown"
    }
  }

  /// One stretch, in the shape the Dart side decodes.
  static func encode(_ sample: HKCategorySample) -> [String: Any] {
    [
      "start": millis(from: sample.startDate),
      "end": millis(from: sample.endDate),
      "kind": kindName(for: sample.value),
      "source": sample.sourceRevision.source.bundleIdentifier,
    ]
  }
}
