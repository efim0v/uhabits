import HealthKit
import XCTest

@testable import Runner

/// The plugin's arithmetic and naming, executed rather than read.
///
/// These are the only decisions the native side makes; everything else is
/// asking the store and passing the answer along. A rename on either side of
/// the channel silently drops every stretch of that kind, so the names are
/// pinned here against the constants Dart expects.
final class HealthKitSleepPluginTests: XCTestCase {

  func testChannelNameMatchesTheDartSide() {
    XCTAssertEqual(
      HealthKitSleepPlugin.channelName, "org.isoron.uhabits/health_sleep")
    XCTAssertEqual(HealthKitSleepPlugin.dataChangedMethod, "healthDataChanged")
  }

  /// Raw values, not symbols: they are the wire format, they are fixed, and
  /// naming them this way lets the pre-iOS-16 cases be checked on any runtime.
  private let expectedNames: [(Int, String)] = [
    (0, "inBed"),
    (1, "asleepUnspecified"),
    (2, "awake"),
    (3, "asleepCore"),
    (4, "asleepDeep"),
    (5, "asleepREM"),
  ]

  func testEveryKnownSleepValueHasItsDartName() {
    for (value, name) in expectedNames {
      if value >= 3, #unavailable(iOS 16.0) { continue }
      XCTAssertEqual(
        HealthKitSleepPlugin.kindName(for: value), name,
        "\(name) must reach Dart under exactly this name")
    }
  }

  func testTheRawValuesAreTheOnesHealthKitUses() {
    XCTAssertEqual(HKCategoryValueSleepAnalysis.inBed.rawValue, 0)
    XCTAssertEqual(HKCategoryValueSleepAnalysis.asleep.rawValue, 1)
    XCTAssertEqual(HKCategoryValueSleepAnalysis.awake.rawValue, 2)
    if #available(iOS 16.0, *) {
      XCTAssertEqual(HKCategoryValueSleepAnalysis.asleepCore.rawValue, 3)
      XCTAssertEqual(HKCategoryValueSleepAnalysis.asleepDeep.rawValue, 4)
      XCTAssertEqual(HKCategoryValueSleepAnalysis.asleepREM.rawValue, 5)
      XCTAssertEqual(
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        HKCategoryValueSleepAnalysis.asleep.rawValue,
        "iOS 16 renamed this case; it did not renumber it")
    }
  }

  func testTheNamesAreAllDistinct() {
    let names = Set(expectedNames.map { HealthKitSleepPlugin.kindName(for: $0.0) })
    XCTAssertEqual(names.count, expectedNames.count)
  }

  func testAnUnknownValueDoesNotMasqueradeAsSleep() {
    // A case added in a future release must arrive as "unknown" and be
    // dropped, never filed as one of the kinds that counts as sleep.
    for value in [9999, -1, Int.max] {
      XCTAssertEqual(HealthKitSleepPlugin.kindName(for: value), "unknown")
    }
  }

  func testMillisecondsRoundTripThroughDate() {
    for millis in [0, 1_756_080_000_000, 4_102_444_800_000] {
      let date = HealthKitSleepPlugin.date(fromMillis: millis)
      XCTAssertEqual(HealthKitSleepPlugin.millis(from: date), millis)
    }
  }

  func testTheEpochIsUnixNotReferenceDate() {
    // Foundation's own zero is 2001, thirty-one years off. Getting this wrong
    // would put every night in the wrong decade.
    let date = HealthKitSleepPlugin.date(fromMillis: 0)
    XCTAssertEqual(date.timeIntervalSince1970, 0, accuracy: 0.0001)
  }

  func testEncodingCarriesInstantsKindAndSource() {
    guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
    else {
      XCTFail("sleepAnalysis type is always available")
      return
    }
    let start = HealthKitSleepPlugin.date(fromMillis: 1_756_080_000_000)
    let end = HealthKitSleepPlugin.date(fromMillis: 1_756_105_200_000)
    let sample = HKCategorySample(
      type: type,
      value: HKCategoryValueSleepAnalysis.asleep.rawValue,
      start: start,
      end: end)

    let encoded = HealthKitSleepPlugin.encode(sample)
    XCTAssertEqual(encoded["start"] as? Int, 1_756_080_000_000)
    XCTAssertEqual(encoded["end"] as? Int, 1_756_105_200_000)
    XCTAssertEqual(encoded["kind"] as? String, "asleepUnspecified")
    XCTAssertNotNil(encoded["source"] as? String)
  }
}
