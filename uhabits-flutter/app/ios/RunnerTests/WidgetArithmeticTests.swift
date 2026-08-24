import XCTest
import SwiftUI

/// The widget extension's own arithmetic, executed.
///
/// Everything else that guards this code reads it as text: `flutter test`
/// cannot run Swift, so the Dart suite can only assert that a field is
/// declared or that a pattern is absent. That blind spot has produced eight
/// audit findings, and the last two were logic errors a source-text assertion
/// could never have caught — a roll-forward that walked the wrong way and a
/// date parsed in the device's own calendar.
///
/// These cases compile the widget sources into the test bundle and run them.
class WidgetArithmeticTests: XCTestCase {

    // MARK: - the wire format

    /// The bridge writes a proleptic-Gregorian ISO day and the extension must
    /// read back the same civil day, whatever calendar the device is set to
    /// (`audit17.ios-widgets-do-day-arithmetic-in-the-device-calendar#1`).
    func testTheWireFormatRoundTrips() {
        for text in ["2026-08-24", "2000-01-01", "1999-12-31", "2024-02-29"] {
            guard let date = WidgetStore.parseDate(text) else {
                return XCTFail("\(text) did not parse")
            }
            XCTAssertEqual(WidgetStore.formatDate(date), text,
                           "\(text) did not survive the round trip")
        }
    }

    /// The pinned calendar is what makes that true. If it followed the device,
    /// a Buddhist or Japanese setting would shift the era.
    func testTheCalendarIsGregorianAndUTC() {
        XCTAssertEqual(widgetCalendar.identifier, .gregorian)
        XCTAssertEqual(widgetCalendar.timeZone.secondsFromGMT(), 0)
    }

    /// The concrete failure the seventeenth pass found: a Buddhist calendar
    /// reads 2026 as BE, i.e. CE 1483, and the roll-forward then walks ~198,000
    /// days off the end of every array.
    func testABuddhistDeviceWouldHaveShiftedTheDay() throws {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: 2026, month: 8, day: 24)
        let asBuddhist = try XCTUnwrap(buddhist.date(from: components))
        let asGregorian = try XCTUnwrap(widgetCalendar.date(from: components))

        let days = Int(asGregorian.timeIntervalSince(asBuddhist) / 86_400)
        XCTAssertGreaterThan(abs(days), 190_000,
                             "the two calendars really do disagree by centuries — "
                             + "which is why the identifier is pinned rather than inherited")
    }

    // MARK: - which day it is

    /// The widget's "today" is the LOCAL civil day, exactly as
    /// `DateUtils.getLocalTime()` is `now + tz.getOffset(now)` before the day
    /// is floored. Flooring the raw instant makes it the UTC day instead
    /// (`audit18.widget-today-must-be-the-local-day#1`).
    func testTodayFollowsTheLocalWallClockWestOfGMT() throws {
        // New York, 20:00 on the 24th. In UTC it is already the 25th.
        let newYork = try XCTUnwrap(TimeZone(secondsFromGMT: -4 * 3600))
        let now = try XCTUnwrap(
            WidgetStore.parseDate("2026-08-25")?.addingTimeInterval(0 * 3600))
        let evening = now  // 2026-08-25T00:00Z == 2026-08-24T20:00-04:00

        let today = WidgetStore.logicalToday(
            midnightDelayHours: 0, now: evening, zone: newYork)

        XCTAssertEqual(WidgetStore.formatDate(today), "2026-08-24",
                       "the user is still on the 24th; a widget that rolled "
                       + "here would un-tick the card and stamp any tap with "
                       + "tomorrow, which the queue then drops")
    }

    func testTodayFollowsTheLocalWallClockEastOfGMT() throws {
        // Tokyo, 08:00 on the 25th. In UTC it is still the 24th.
        let tokyo = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 3600))
        let morning = try XCTUnwrap(
            WidgetStore.parseDate("2026-08-24")?.addingTimeInterval(23 * 3600))

        let today = WidgetStore.logicalToday(
            midnightDelayHours: 0, now: morning, zone: tokyo)

        XCTAssertEqual(WidgetStore.formatDate(today), "2026-08-25",
                       "the user's day has already turned")
    }

    /// The "new day starts at 3am" preference moves the boundary, and it moves
    /// it in local time.
    func testTheMidnightDelayMovesTheLocalBoundary() throws {
        let newYork = try XCTUnwrap(TimeZone(secondsFromGMT: -4 * 3600))
        // 2026-08-25T05:00Z == 01:00 local on the 25th: before the 3am turn.
        let justAfterMidnight = try XCTUnwrap(
            WidgetStore.parseDate("2026-08-25")?.addingTimeInterval(5 * 3600))

        XCTAssertEqual(
            WidgetStore.formatDate(WidgetStore.logicalToday(
                midnightDelayHours: 3, now: justAfterMidnight, zone: newYork)),
            "2026-08-24",
            "with the delay on, 01:00 still belongs to the previous day")
        XCTAssertEqual(
            WidgetStore.formatDate(WidgetStore.logicalToday(
                midnightDelayHours: 0, now: justAfterMidnight, zone: newYork)),
            "2026-08-25",
            "and without it, it does not")
    }

    /// The reload policy has to name a real instant, not a day key.
    func testTheNextTurnIsARealInstant() throws {
        let newYork = try XCTUnwrap(TimeZone(secondsFromGMT: -4 * 3600))
        let noon = try XCTUnwrap(
            WidgetStore.parseDate("2026-08-24")?.addingTimeInterval(16 * 3600))

        let turn = WidgetStore.startOfNextDay(
            midnightDelayHours: 0, from: noon, zone: newYork)

        XCTAssertGreaterThan(turn, noon, "the turn is in the future")
        XCTAssertLessThan(turn.timeIntervalSince(noon), 24 * 3600,
                          "and within the day")
        // Local midnight on the 25th in New York is 04:00Z.
        XCTAssertEqual(WidgetStore.formatDate(turn.addingTimeInterval(-1)),
                       "2026-08-25",
                       "the turn lands at the user's own midnight, not UTC's")
    }

    // MARK: - the roll-forward

    /// A document published yesterday, drawn today, must show today.
    /// `audit15.ios-home-screen-widgets-never-roll#1`.
    func testRollingForwardShiftsNewestFirstArrays() throws {
        let published = try XCTUnwrap(WidgetStore.parseDate("2026-08-23"))
        let current = try XCTUnwrap(WidgetStore.parseDate("2026-08-24"))
        let document: [String: Any] = [
            "today": "2026-08-23",
            "habits": [[
                "entries": [EntryValue.yesManual, EntryValue.no, EntryValue.no],
                "value": EntryValue.yesManual,
                "notesIndicators": [true, false, false],
            ]],
        ]
        XCTAssertEqual(WidgetStore.formatDate(published), "2026-08-23")

        let rolled = WidgetStore.rolledForward(document, to: current)
        XCTAssertEqual(rolled["today"] as? String, "2026-08-24",
                       "the card names the day it is drawn on")

        let habit = try XCTUnwrap((rolled["habits"] as? [[String: Any]])?.first)
        let entries = try XCTUnwrap(habit["entries"] as? [Int])
        XCTAssertEqual(entries.count, 3, "the grid keeps its width")
        XCTAssertEqual(entries[0], EntryValue.unknown, "today is unanswered")
        XCTAssertEqual(entries[1], EntryValue.yesManual,
                       "and yesterday is what today used to be")
        XCTAssertEqual(entries[2], EntryValue.no,
                       "every day moves by exactly one place — an off-by-one "
                       + "here is invisible at index 1, where both a correct "
                       + "shift and a doubled one land on the same value")
        XCTAssertEqual(habit["value"] as? Int, EntryValue.unknown,
                       "`value` is entries[0] by definition — the tick, the "
                       + "ring glyph and the intent's next value all read it")
        XCTAssertEqual(habit["notesIndicators"] as? [Bool], [false, true, false],
                       "the note dots travel with their days")
    }

    func testADocumentPublishedTodayIsLeftAlone() throws {
        let current = try XCTUnwrap(WidgetStore.parseDate("2026-08-24"))
        let document: [String: Any] = [
            "today": "2026-08-24",
            "habits": [["entries": [EntryValue.yesManual, EntryValue.no]]],
        ]
        let rolled = WidgetStore.rolledForward(document, to: current)
        let habit = try XCTUnwrap((rolled["habits"] as? [[String: Any]])?.first)
        XCTAssertEqual(habit["entries"] as? [Int],
                       [EntryValue.yesManual, EntryValue.no])
    }

    /// A widget nobody has published to in months shows nothing, rather than
    /// reading past the end of its own array.
    func testRollingForwardPastTheEndEmptiesRatherThanCrashes() throws {
        let current = try XCTUnwrap(WidgetStore.parseDate("2027-08-24"))
        let document: [String: Any] = [
            "today": "2026-08-24",
            "habits": [["entries": [EntryValue.yesManual, EntryValue.no]]],
        ]
        let rolled = WidgetStore.rolledForward(document, to: current)
        let habit = try XCTUnwrap((rolled["habits"] as? [[String: Any]])?.first)
        XCTAssertEqual(habit["entries"] as? [Int],
                       [EntryValue.unknown, EntryValue.unknown])
    }

    // MARK: - the opacity rule

    /// Android's checkmark widget overwrites the card paint's whole ARGB when
    /// the habit is done, discarding the opacity alpha — so a completed card is
    /// solid at every setting (`audit17.ios-checkmark-done-card-must-stay-opaque#1`).
    func testTheDoneCardIgnoresTheOpacityPreference() throws {
        // `CheckmarkWidget.cardColor` is the whole rule: the completed branch
        // returns the opaque habit colour, the unanswered one the card colour
        // carrying the preference's alpha. If both were dimmed the two states
        // would be indistinguishable at 20% and invisible at 0%.
        let done = try habit(value: EntryValue.yesManual)
        let notDone = try habit(value: EntryValue.no)

        XCTAssertNotEqual("\(CheckmarkWidgetView.cardColor(done))",
                          "\(CheckmarkWidgetView.cardColor(notDone))",
                          "done and not-done must never look the same")
    }

    // MARK: - the streak chart's date labels

    /// `JavaLocalDateFormatter.longFormat` is two settings, not one: the
    /// locale's MEDIUM pattern for the words, and `df.timeZone =
    /// TimeZone.getTimeZone("UTC")` for the instant — because
    /// `LocalDate.toGregorianCalendar()` is a UTC midnight, exactly like every
    /// `Date` in this extension (`audit18.streak-date-labels-must-be-formatted
    /// -in-utc#1`).
    ///
    /// `DateFormatter.timeZone` is independent of `DateFormatter.calendar`:
    /// assigning the UTC-pinned `widgetCalendar` leaves the formatter on
    /// `NSTimeZone.default`, which is what makes the gap invisible to a reader
    /// and to any source-text guard.
    func testTheStreakLabelsNameTheDayTheAppComputed() throws {
        let original = NSTimeZone.default
        addTeardownBlock { NSTimeZone.default = original }

        let day = try XCTUnwrap(WidgetStore.parseDate("2026-08-24"))
        let reference: String = {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.calendar = widgetCalendar
            formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: day)
        }()

        for identifier in ["America/Los_Angeles", "UTC", "Asia/Tokyo"] {
            NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: identifier))
            XCTAssertEqual(
                DateNames.longFormat(day), reference,
                "in \(identifier) the label must still name 2026-08-24 — the "
                + "day key the app wrote. A formatter left on the device zone "
                + "reads the UTC-midnight instant back as the previous day "
                + "everywhere west of GMT, so both ends of every streak bar "
                + "are printed one day early and the widget and the app "
                + "disagree about the same streak")
        }
    }

    // MARK: - the chart month names

    /// Every month INDEX in this extension is Gregorian — `MonthKey` is built
    /// with `widgetCalendar`, and upstream reads its names off
    /// `LocalDate.toGregorianCalendar()`, an explicit `GregorianCalendar`. So
    /// the NAME the footer prints has to be the Gregorian one for that index,
    /// whatever calendar the device is set to
    /// (`audit21.ios-widget-month-names-come-from-the-gregorian-calendar#1`).
    ///
    /// A bare `DateFormatter` takes its calendar from its locale, and
    /// `fa_IR`/`ar_SA` resolve to persian/islamic-umalqura with no Settings
    /// override at all — so this is the region default, not an exotic choice.
    /// Buddhist and Japanese are Gregorian-month-aligned and would hide the
    /// defect, which is exactly why the seventeenth pass's sweep walked past
    /// this one.
    func testTheChartMonthNamesAreTheGregorianOnes() throws {
        for identifier in ["fa_IR", "ar_SA", "he_IL@calendar=hebrew",
                           "en_US", "zh_CN"] {
            let locale = Locale(identifier: identifier)
            // What upstream prints: this locale's words for the twelve
            // GREGORIAN months.
            let reference: [String] = {
                let formatter = DateFormatter()
                formatter.locale = locale
                formatter.calendar = Calendar(identifier: .gregorian)
                return formatter.shortMonthSymbols ?? []
            }()
            XCTAssertEqual(reference.count, 12,
                           "\(identifier): a Gregorian year has twelve months "
                           + "in every locale")

            for month in 1...12 {
                XCTAssertEqual(
                    DateNames.shortMonth(month: month, locale: locale),
                    reference[month - 1],
                    "\(identifier) month \(month): the grid column is a "
                    + "Gregorian month, so the footer under it must carry the "
                    + "Gregorian month's name. A device-calendar formatter "
                    + "names a Hijri or Solar-Hijri month the chart is not "
                    + "showing — or, on a Hebrew calendar, returns fourteen "
                    + "symbols, fails the count guard and prints nothing at all")
            }
        }
    }

    /// The two overloads are the same function with and without a date in
    /// hand: `ScoreChart` measures all twelve to size its columns and then
    /// labels the axis from a `Date`. If they disagree the axis and the width
    /// it was laid out for come from different calendars.
    func testTheTwoMonthNameOverloadsAgree() throws {
        for identifier in ["fa_IR", "ar_SA", "he_IL@calendar=hebrew", "en_US"] {
            let locale = Locale(identifier: identifier)
            for month in 1...12 {
                let day = try XCTUnwrap(WidgetStore.parseDate(
                    String(format: "2026-%02d-15", month)))
                XCTAssertEqual(
                    DateNames.shortMonth(month: month, locale: locale),
                    DateNames.shortMonth(day, locale: locale),
                    "\(identifier) month \(month): FrequencyWidget draws its "
                    + "footer with the first and ScoreWidget its axis with the "
                    + "second, on the same home screen")
            }
        }
    }

    /// One habit, decoded the way the extension decodes them — so this
    /// exercises the decoder too, rather than a hand-built struct that could
    /// drift from the wire format.
    private func habit(value: Int) throws -> WidgetHabit {
        let json = """
        {
          "id": 1, "name": "Meditate", "question": "", "color": 3,
          "type": "YES_NO", "unit": "", "target": 0, "targetType": "AT_LEAST",
          "isArchived": false, "value": \(value), "entries": [\(value)]
        }
        """
        return try JSONDecoder().decode(WidgetHabit.self,
                                        from: Data(json.utf8))
    }
}
