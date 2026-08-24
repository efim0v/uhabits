/*
 * Copyright (C) 2016-2025 Álinson Santos Xavier <git@axavier.org>
 *
 * This file is part of Loop Habit Tracker.
 *
 * Loop Habit Tracker is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * Loop Habit Tracker is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import AppIntents
import Foundation
import WidgetKit

/// The reading half of the contract that `lib/platform/home_widget_bridge.dart`
/// writes.
///
/// Everything here is a mirror of `HomeWidgetBridge`: the key names, the
/// schema version and the field names must be changed on both sides at once.
/// A widget extension can outlive an app update by as long as the user leaves
/// it on the home screen, so [WidgetDocument] refuses any `version` it does not
/// know rather than decoding a shape that has moved on.
enum WidgetContract {

    /// `HomeWidgetBridge.schemaVersion`.
    static let schemaVersion = 1

    /// `HomeWidgetBridge.keyPrefix`.
    static let keyPrefix = "uhabits"

    /// `HomeWidgetBridge.indexKey`.
    static let indexKey = "\(keyPrefix).index"

    /// `HomeWidgetBridge.documentKey(widgetId)`.
    static func documentKey(_ widgetId: Int) -> String {
        "\(keyPrefix).widget.\(widgetId)"
    }

    /// `WidgetToggleQueue.key` — the taps this extension has performed in place
    /// and the app has not applied yet.
    ///
    /// The queue is written here and read by
    /// `app/lib/state/widget_toggle_queue.dart`, which is the only thing that
    /// may turn one into an entry. It shares [schemaVersion]: both documents
    /// are this same contract.
    static let pendingKey = "\(keyPrefix).pending"

    /// The App Group both the app and this extension belong to.
    ///
    /// `HomeWidgetPlugin.ensureInitialized()` passes the same string to
    /// `HomeWidget.setAppGroupId`, which makes `saveWidgetData` write into
    /// `UserDefaults(suiteName:)` for this suite. The two must match exactly or
    /// the extension reads an empty store and every widget shows the
    /// "no habit" placeholder.
    static let appGroupId = "group.org.isoron.uhabits"
}

// MARK: - Links

/// The deep links a tap on a widget sends into the app.
///
/// This is the iOS half of `app/android/.../widgets/WidgetIntents.kt`, and it
/// is deliberately the same vocabulary: the same scheme, the same authority and
/// the same three action names, so both platforms land in the one router,
/// `app/lib/state/widget_link.dart`. Upstream these are three different
/// `PendingIntent`s addressed to three different components
/// (`BaseWidget.getOnClickPendingIntent` with `PendingIntentFactory`); neither
/// platform can reach Dart from the widget's process, so both send a URI
/// instead and let the app rebuild the intent.
///
/// ```
/// uhabits://widget/toggle?habit=<id>&homeWidget=true
/// uhabits://widget/edit?habit=<id>&date=<yyyy-MM-dd>&homeWidget=true
/// uhabits://widget/show?habit=<id>&homeWidget=true
/// ```
///
/// Two differences from the Android URIs, both forced:
///
///  - There is no `widgetId`. A WidgetKit widget has no id — it is configured
///    by an App Intent, not by the launcher — and `WidgetLink.parse` already
///    reads a missing id as 0 (`widgets.config-picker#1`).
///  - There is a `homeWidget` query item. `SwiftHomeWidgetPlugin.isWidgetUrl`
///    forwards a URL to Dart only if it carries a query item with that name;
///    without it the tap opens the app and the URL is dropped, which looks to
///    the user exactly like the tap doing nothing.
///
/// The scheme is claimed by `ios/Runner/Info.plist` (`CFBundleURLTypes`).
/// Without that claim iOS refuses to deliver any of these at all.
enum WidgetLink {

    /// `WidgetIntents.SCHEME` / `WidgetLink.scheme`.
    static let scheme = "uhabits"

    /// `WidgetIntents.AUTHORITY` / `WidgetLink.authority`.
    static let authority = "widget"

    /// `widgets.checkmark#6` — toggle today's entry.
    static let actionToggle = "toggle"

    /// `widgets.checkmark#7` — open the value picker for a day.
    static let actionEdit = "edit"

    /// `widgets.history#5`, `widgets.score#7`, `widgets.streak#6`,
    /// `widgets.frequency#6`, `widgets.target#9` — open the habit screen.
    static let actionShow = "show"

    /// The query item name `SwiftHomeWidgetPlugin.isWidgetUrl` filters on.
    static let pluginMarker = "homeWidget"

    static func toggle(_ habit: WidgetHabit) -> URL? {
        link(actionToggle, habit: habit)
    }

    /// [date] is the published `today` — the app-wide today, already offset by
    /// the midnight-delay preference. A widget must not compute it itself
    /// (`widgets.checkmark#5`).
    static func edit(_ habit: WidgetHabit, date: String) -> URL? {
        link(actionEdit, habit: habit, date: date)
    }

    static func show(_ habit: WidgetHabit) -> URL? {
        link(actionShow, habit: habit)
    }

    private static func link(
        _ action: String,
        habit: WidgetHabit,
        date: String? = nil
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = authority
        components.path = "/\(action)"
        var items = [URLQueryItem(name: "habit", value: String(habit.id))]
        if let date {
            items.append(URLQueryItem(name: "date", value: date))
        }
        items.append(URLQueryItem(name: pluginMarker, value: "true"))
        components.queryItems = items
        return components.url
    }
}

// MARK: - Documents

/// The `uhabits.index` document.
struct WidgetIndex: Decodable {
    let version: Int
    let today: String
    let providers: [String]
    let widgets: [WidgetBinding]

    /// Every habit the app knows, in habit-list order, independent of any
    /// widget binding — `HomeWidgetBridge.buildIndexDocument`'s `habits`.
    ///
    /// This is the list `HabitEntityQuery` offers in a widget's edit sheet, and
    /// the list an unconfigured widget falls back on. It exists because
    /// [widgets] cannot serve either purpose here: a binding is created by
    /// `HabitPickerDialog`, which is an Android configure activity reached
    /// through the `uhabits://widget/configure` deep link, and nothing on iOS
    /// ever sends one. Without the catalogue the query has nothing to list, so
    /// no widget can be configured, so no binding is ever created — the empty
    /// case is self-sustaining.
    ///
    /// Optional so that a document written by a build that predates it still
    /// decodes: an extension outlives an app update for as long as the widget
    /// sits on the home screen, and the per-widget documents below still carry
    /// the habits an Android-configured widget was bound to.
    let habits: [WidgetHabit]?

    /// `Preferences.isSkipEnabled` — the two inputs of
    /// `Entry.nextToggleValue` (`widgets.behavior#3`), published because
    /// `ToggleHabitIntent` has to predict the value the app will write.
    let isSkipEnabled: Bool?

    /// `Preferences.areQuestionMarksEnabled`.
    let areQuestionMarksEnabled: Bool?

    /// `Preferences.firstWeekday`, as `daysSinceSunday` (0 = Sunday …
    /// 6 = Saturday) — the weekday the History grid's rows and the Frequency
    /// grid's rows start on (`audit4.history-and-frequency-home-screen-widgets`).
    ///
    /// It rides on the catalogue as well as on the per-widget document because
    /// the catalogue is what an iOS widget resolved through `HabitEntityQuery`
    /// reads; see [WidgetStore.firstWeekday].
    ///
    /// Optional, like the two preferences above: a document written before the
    /// field existed falls back to the device calendar's own first weekday,
    /// which is what both grids used unconditionally before.
    let firstWeekday: Int?

    /// `Preferences.widgetOpacity` — 0..255, the alpha
    /// `HabitWidgetView.rebuildBackground` paints the card with on Android
    /// (`settings.preferences.widget-opacity#5`,
    /// `audit16.widget-opacity-never-reaches-ios#1`).
    ///
    /// Optional: a document written before the field existed keeps the opaque
    /// card every widget drew before.
    let widgetOpacity: Int?

    /// `Preferences.midnightDelayHours` — 3 while "new day starts at 3am" is
    /// on, 0 otherwise (`audit15.ios-home-screen-widgets-never-roll#1`).
    ///
    /// The one input of `computeToday(midnightDelayHours, 0)` that is not the
    /// system clock, and so the one thing this side needs in order to tell
    /// whether [today] is still the day it is drawing on. A widget still never
    /// *asks* the system what day it is: it asks what day the app would say it
    /// is.
    ///
    /// It rides on the index rather than only on the per-widget document
    /// because a WidgetKit widget never reads a per-widget document — it has no
    /// widget id and no configure activity, and resolves its habit out of
    /// [habits]. [WidgetStore.rolledDocument] reads the raw value; this
    /// declaration is what [WidgetStore.midnightDelayHours] answers the reload
    /// policy with.
    ///
    /// Optional, like the three preferences above: an index written before the
    /// field existed carries no key, and 0 — a day that turns at midnight — is
    /// the preference's own default.
    let midnightDelayHours: Int?

    struct WidgetBinding: Decodable {
        let id: Int
        let key: String
        let habits: [Int]
    }
}

/// One `uhabits.widget.<id>` document.
struct WidgetDocument: Decodable {
    let version: Int
    let widgetId: Int
    let today: String
    let habits: [WidgetHabit]

    /// The ids `HomeWidgetBridge` could not resolve to a habit.
    ///
    /// This is where `HabitNotFoundException` ended up: upstream
    /// `BaseWidgetProvider` catches it and pushes the `widget_error` layout
    /// with "Habit deleted / not found" (`widgets.error-states#1`); the bridge
    /// cannot throw across the process boundary, so it names the ids and this
    /// side draws that same state.
    let missingHabitIds: [Int]

    /// `Preferences.firstWeekday`, as `daysSinceSunday`; see
    /// [WidgetIndex.firstWeekday]. A widget an Android install bound reads its
    /// origin from here, exactly as `HistoryWidgetProvider.kt` and
    /// `FrequencyWidgetProvider.kt` read `document.firstWeekday`.
    let firstWeekday: Int?
}

/// One habit inside a widget document.
struct WidgetHabit: Decodable, Identifiable {
    let id: Int
    let name: String
    let question: String
    /// The palette index, fed to `WidgetTheme.color(paletteIndex:)`.
    let color: Int
    /// `HabitType.csvName`: "YES_NO" or "NUMERICAL".
    let type: String
    let unit: String
    let target: Double
    /// `NumericalHabitType.csvName`: "AT_LEAST" or "AT_MOST".
    let targetType: String
    let isArchived: Bool
    /// Today's entry value; the same number as `entries[0]`.
    let value: Int
    /// `HomeWidgetBridge.entryCount` daily values read from `computedEntries`,
    /// newest first, so `entries[0]` is today and `entries[n]` is n days ago.
    /// YES_AUTO days are already filled in.
    let entries: [Int]

    /// One flag per published day, in the same newest-first order as
    /// [entries]: true where that entry carries a note.
    ///
    /// `HistoryCardPresenter.buildState` computes it as
    /// `entries.map { it.notes != "" }` and `HistoryWidget.refreshData` hands
    /// the result to `HistoryChart.notesIndicators`, which marks the day with a
    /// dot (`audit6.history-home-screen-widget-never-draws#1`). The note text
    /// never crosses: a widget draws a dot, not prose.
    ///
    /// Optional, like [score] and [scores]: a widget outlives an app update for
    /// as long as it stays on the home screen, and a document written before
    /// the field existed simply has no dots to draw.
    let notesIndicators: [Bool]?

    /// The History grid's own series, newest first: one character per day,
    /// `HistorySquare`'s ordinal as a digit, running back to the habit's oldest
    /// known entry (`audit10.history-home-screen-widget-draws-more#1`).
    ///
    /// Not [entries] under another name. [entries] is sixty days long because
    /// that is all the tick mark needs; the History grid lays its columns out
    /// from the *card's geometry* — `nColumns = Int(floor((width - 2 * padding
    /// - weekdayColumnWidth) / squareSize))`, spanning `7 * nColumns` days — so
    /// a `.systemMedium` card, which this widget offers by default, asks for
    /// 127-133 days. Every day past the end of the series is drawn `.off`, in
    /// the same low-contrast colour a genuinely missed day gets, so more than
    /// half the grid was a fabricated record of failure.
    ///
    /// Optional, like [score] and [scores]: a document written before the field
    /// existed falls back to mapping [entries], which is what this replaced.
    let historySeries: String?

    /// The offsets into [historySeries] whose day carries a note
    /// (`audit6.history-home-screen-widget-never-draws#1`), ascending.
    ///
    /// Offsets rather than one flag per day: notes are sparse, and a
    /// `[false, false, …]` array over 750 days would be the largest thing in
    /// the document.
    let historyNotes: [Int]?

    /// `habit.scores[today].value`, the ring percentage the Checkmark widget
    /// needs (`widgets.checkmark#2`).
    ///
    /// **Not published by schema version 1.** The score is an exponential
    /// moving average over the habit's whole history, so it cannot be
    /// recomputed from the 60 days above, and the ring degrades to its
    /// unearned track until the bridge starts publishing this field.
    let score: Double?

    /// The daily score series the Score widget charts, newest first
    /// (`widgets.score#6`).
    ///
    /// **Not published by schema version 1**, for the same reason as [score].
    /// Without it the Score widget draws its grid and footer and no line.
    let scores: [Double]?

    /// The bucket [scores] was built at, in days — `ScoreCardState.bucketSize`,
    /// i.e. `BUCKET_SIZES[Preferences.scoreCardSpinnerPosition]`
    /// (`widgets.score#3`, `#4`).
    ///
    /// It is what turns a column index back into a date: `ScoreChart` labels
    /// its footer with `today - offset * bucketSize`. A chart that assumed the
    /// weekly default plotted a correct yearly line against dates spaced one
    /// week apart.
    ///
    /// Optional only for a document that predates the field, which is then read
    /// as the preference's own default of 7.
    let bucketSize: Int?

    /// `habit.streaks.getBest(n)` over the habit's WHOLE record
    /// (`widgets.streak#3`), each with its real first and last day.
    ///
    /// Not derivable from [entries]: that array is sixty days long, so a
    /// rebuild here reports a 200-day run as 60 and loses every streak that
    /// ended before the window — which is the entire content of the widget.
    ///
    /// Optional, like [score] and [scores]: a document written before the field
    /// existed falls back to the rebuild, exactly as
    /// `app/android/.../widgets/StreakWidget.kt` does.
    let streaks: [WidgetStreakData]?

    /// `habit.originalEntries.computeWeekdayFrequency(isNumerical)`
    /// (`widgets.frequency#3`, `#4`, `#5`): one 7-slot bucket per calendar
    /// month for every month the habit has existed, keyed by that month's first
    /// day in `HomeWidgetBridge.formatDate`'s format and indexed
    /// `(daysSinceSunday + 1) % 7`.
    ///
    /// The ORIGINAL entries, so the YES_AUTO days a non-daily frequency
    /// generates never appear — and every month, so a habit two years old does
    /// not read as if it started two months ago.
    let weekdayFrequency: [String: [Int]]?

    /// `TargetCardPresenter.buildState`'s three parallel lists, zipped
    /// (`widgets.target#5`, `#6`, `#7`).
    ///
    /// Which rows exist and what each target is are both decided by
    /// `frequency.denominator`, and the sums are calendar-truncated over the
    /// habit's whole record — none of which a widget process can see. So the
    /// bridge runs the presenter and this draws its answer.
    let targetRows: [WidgetTargetRow]?

    var isNumerical: Bool { type == "NUMERICAL" }

    var isAtMost: Bool { targetType == "AT_MOST" }

    /// `Habit.isCompletedToday()` (`widgets.checkmark#4`): AT_LEAST habits
    /// compare today's value against the target, AT_MOST habits are never
    /// "completed today".
    var isCompletedToday: Bool {
        guard isNumerical else { return false }
        if isAtMost { return false }
        return Double(value) / 1000.0 >= target
    }
}

/// One entry of [WidgetHabit.streaks] — `org.isoron.uhabits.core.models.Streak`
/// as the bridge writes it.
///
/// The dates are `HomeWidgetBridge.formatDate` strings rather than offsets: a
/// streak the app found may begin years before the published `today`, which is
/// the whole reason the field exists.
struct WidgetStreakData: Decodable {
    let start: String
    let end: String
    /// `Streak.length` = `start.daysUntil(end) + 1`.
    let length: Int
}

/// One row of [WidgetHabit.targetRows] (`widgets.target#4`, `#6`, `#7`).
///
/// [interval] is the row's key rather than its length in days: 1 is Today, 7 is
/// Week, 30 is Month, 91 is Quarter and anything else is Year — the same table
/// `TargetCardState.labels` reads.
struct WidgetTargetRow: Decodable {
    let interval: Int
    let value: Double
    let target: Double
}

/// `Entry`'s reserved values (`models.entry-values#2`).
enum EntryValue {
    static let skip = 3
    static let yesManual = 2
    static let yesAuto = 1
    static let no = 0
    static let unknown = -1
}

// MARK: - Store

/// Reads the App Group container the bridge writes into.
///
/// `HomeWidget.saveWidgetData` stores every value as a String under
/// `UserDefaults(suiteName: appGroupId)`, so reading is a `string(forKey:)`
/// plus a `JSONDecoder`. Nothing here throws: a widget that cannot read its
/// data renders a placeholder, never a crash — an extension that traps is
/// killed and the user sees a blank card with no way to tell why.
/// The calendar every date in the extension is read and written with.
///
/// Every date in this port is a proleptic-Gregorian day number — the core's
/// `LocalDate` is integer arithmetic over `daysSince2000` — and the bridge
/// serialises it as a Gregorian ISO string. `Calendar.current` is the user's
/// Settings > General > Language & Region > Calendar choice, so on a Buddhist,
/// Persian, Islamic or Japanese device it would read that string back as a
/// different civil day and stamp everything this side emits with the wrong
/// era. The Android host pins `GregorianCalendar(TimeZone.getTimeZone("GMT"))`
/// for exactly this reason
/// (`audit17.ios-widgets-do-day-arithmetic-in-the-device-calendar#1`).
///
/// UTC, not the device zone, because the day being named is the one the app
/// computed: re-deriving it in local time can land on the day either side.
let widgetCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

struct WidgetStore {

    let defaults: UserDefaults?

    init(appGroupId: String = WidgetContract.appGroupId) {
        defaults = UserDefaults(suiteName: appGroupId)
    }

    func index() -> WidgetIndex? {
        decode(WidgetIndex.self, key: WidgetContract.indexKey)
    }

    func document(widgetId: Int) -> WidgetDocument? {
        decode(WidgetDocument.self, key: WidgetContract.documentKey(widgetId))
    }

    /// Every habit the app has published, in habit-list order, deduplicated by
    /// habit id.
    ///
    /// This is the closest thing iOS has to `HabitPickerDialog`'s list. On
    /// Android the launcher hands each widget an id and `WidgetPreferences`
    /// maps it to habits; WidgetKit has no widget id at all, so the habit is
    /// chosen in the widget's own edit sheet (see `HabitEntityQuery`) out of
    /// whatever the app has published.
    ///
    /// The catalogue comes first because it is the whole list; the per-widget
    /// documents are read after it only to keep a widget that an Android
    /// install had bound working against an index that predates the catalogue.
    func allHabits() -> [WidgetHabit] {
        guard let index = index() else { return [] }
        var seen = Set<Int>()
        var result: [WidgetHabit] = []
        for habit in index.habits ?? [] where !seen.contains(habit.id) {
            seen.insert(habit.id)
            result.append(habit)
        }
        for binding in index.widgets {
            guard let document = document(widgetId: binding.id) else { continue }
            for habit in document.habits where !seen.contains(habit.id) {
                seen.insert(habit.id)
                result.append(habit)
            }
        }
        return result
    }

    /// `today` as the app computed it — already offset by the midnight-delay
    /// preference (`widgets.checkmark#5`), which is why it is read from the
    /// document rather than from `Date()` here.
    ///
    /// It is the *rolled-forward* day: [rolledDocument] has already advanced
    /// the index to the day this process is drawing on
    /// (`audit15.ios-home-screen-widgets-never-roll#1`), so a widget nobody has
    /// republished since yesterday reports today rather than the day the app
    /// last ran.
    func today() -> Date? {
        guard let raw = index()?.today else { return nil }
        return Self.parseDate(raw)
    }

    /// The same day as [today], in the wire format, for the links that carry a
    /// date back to the app.
    func todayText() -> String? { index()?.today }

    /// `Preferences.midnightDelayHours`, as the app published it.
    ///
    /// Zero when nothing has been published, or when the index predates the
    /// field — the preference's own default, a day that turns at midnight.
    func midnightDelayHours() -> Int {
        index()?.midnightDelayHours ?? 0
    }

    /// `Preferences.areQuestionMarksEnabled`, as the app published it.
    ///
    /// Upstream `CheckmarkWidgetView` holds a live `Preferences` and reads this
    /// on every redraw, so a boolean habit with no entry for today draws `?`
    /// rather than `✗` (`audit5.checkmark-widget-always-draws-for-an#1`). An
    /// extension has no `Preferences`, so the flag arrives on the index — the
    /// same value `stageToggle` already reads for `Entry.nextToggleValue`, read
    /// through one accessor so the two halves cannot disagree.
    ///
    /// False when nothing has been published, which is the preference's own
    /// default.
    func areQuestionMarksEnabled() -> Bool {
        index()?.areQuestionMarksEnabled ?? false
    }

    /// `Preferences.firstWeekday`, as `daysSinceSunday`
    /// (`audit4.history-and-frequency-home-screen-widgets#1`).
    ///
    /// Upstream `HistoryWidget.refreshData` and `FrequencyWidgetProvider` both
    /// read `prefs.firstWeekday`, so the two grids and the habit-list header
    /// can never disagree about where a week starts. An extension has no
    /// `Preferences`, so the value arrives on the document — read here through
    /// one accessor for the same reason.
    ///
    /// The device calendar's own first weekday is the fallback, and only that:
    /// it is what a document written before the field was published leaves
    /// this side with, and it is what both grids used unconditionally before.
    func firstWeekday() -> Int {
        index()?.firstWeekday ?? DateNames.firstWeekdayDaysSinceSunday()
    }

    /// `BaseWidget.preferedBackgroundAlpha`, as the fraction SwiftUI wants.
    ///
    /// 255 — a fully opaque card — is both the preference's own default and
    /// what a document written before the field was published leaves this side
    /// with (`audit16.widget-opacity-never-reaches-ios#1`).
    func widgetOpacity() -> Double {
        let alpha = index()?.widgetOpacity ?? 255
        return Double(min(255, max(0, alpha))) / 255.0
    }

    func habit(id: Int) -> WidgetHabit? {
        allHabits().first { $0.id == id }
    }

    /// True when the app has published documents but none of them contains
    /// [id] — i.e. the habit was deleted (`widgets.error-states#1`).
    func isMissing(id: Int) -> Bool {
        guard let index = index() else { return false }
        for binding in index.widgets {
            guard let document = document(widgetId: binding.id) else { continue }
            if document.missingHabitIds.contains(id) { return true }
        }
        return false
    }

    /// The document under [key], advanced to the day it is being drawn on, as
    /// the type that describes it.
    ///
    /// This is the single point every reader passes through — `index()`,
    /// `document(widgetId:)`, and so every card of all six widgets — which
    /// makes it the counterpart of `WidgetData.readWidget` on the Android host,
    /// where the same roll-forward already happens
    /// (`audit15.ios-home-screen-widgets-never-roll#1`). The document is rolled
    /// while it is still a dictionary rather than after decoding, because
    /// [stageToggle] has to roll the very same document by hand — it writes the
    /// index back, so it may not lose the keys this side does not understand —
    /// and two implementations of the shift would be two chances to disagree.
    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard
            let defaults,
            let document = rolledDocument(forKey: key, in: defaults),
            JSONSerialization.isValidJSONObject(document),
            let data = try? JSONSerialization.data(withJSONObject: document),
            let decoded = try? JSONDecoder().decode(type, from: data)
        else { return nil }
        return decoded
    }

    /// The wire format is `HomeWidgetBridge.formatDate`: a plain ISO-8601
    /// calendar date, no time and no zone. It is parsed in the current calendar
    /// so that "today" here means the same civil day it meant in Dart.
    /// The inverse of [parseDate]: `HomeWidgetBridge.formatDate`'s output for a
    /// day, used when nothing has been published and the device's own today is
    /// the best a link can carry.
    static func formatDate(_ date: Date) -> String {
        let parts = widgetCalendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }

    static func parseDate(_ raw: String) -> Date? {
        let parts = raw.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return widgetCalendar.date(from: components)
    }
}

// MARK: - Rolling a snapshot forward

/// Turning a document built for an earlier day into one for *this* day
/// (`audit15.ios-home-screen-widgets-never-roll#1`).
///
/// Upstream a widget has nothing to roll: `CheckmarkWidget.refreshData` calls
/// `getToday()` and reads the database on every `ACTION_APPWIDGET_UPDATE`, and
/// the app-wide today is re-stamped at the user's own midnight by an
/// `AlarmManager` broadcast (`WidgetUpdater.scheduleStartDayWidgetUpdate`)
/// whether or not the app is running. Here the data arrives pre-computed, so
/// WidgetKit re-rendering at midnight would otherwise redraw the identical
/// stale card: the reload policy was never the missing piece, the moved day
/// was.
///
/// Every method is a port of one in
/// `app/android/app/src/main/kotlin/org/isoron/uhabits/widgets/WidgetData.kt`,
/// which the Android host has had since
/// `audit6.home-screen-widgets-go-stale-at#1`. Keep the two together.
extension WidgetStore {

    /// `DateUtils.getTodayWithOffset()` / the core's
    /// `computeToday(hourOffset, 0)`, recomputed from the system clock.
    ///
    /// This is the *one* thing a widget asks the system: what instant it is
    /// now. Which day that instant belongs to is still the app's rule — local
    /// wall clock, minus the midnight delay the index carries — so a user whose
    /// day turns at 3am sees the widget turn at 3am too. It exists only so a
    /// redraw can notice a snapshot has gone stale; the day a card *draws* is
    /// still the document's own `today`.
    static func logicalToday(
        midnightDelayHours: Int,
        now: Date = Date(),
        zone: TimeZone = .current
    ) -> Date {
        // `DateUtils.getLocalTime()` is `now + tz.getOffset(now)`, and
        // `getStartOfDay` floors those already-localised millis; the
        // Gregorian/GMT calendar is the arithmetic vehicle, never the source of
        // the day. Flooring the raw instant instead would make the widget's
        // "today" the UTC day: west of GMT it turns early — in New York the
        // card un-ticks at 20:00 and a tap until midnight is stamped tomorrow
        // and dropped — and east of it, late
        // (`audit18.widget-today-must-be-the-local-day#1`).
        let local = now.addingTimeInterval(Double(zone.secondsFromGMT(for: now)))
        let shifted = local.addingTimeInterval(-Double(midnightDelayHours) * 3600)
        return widgetCalendar.startOfDay(for: shifted)
    }

    /// The next instant [logicalToday] answers a different day —
    /// `getStartOfTomorrowWithOffset(midnightDelayHours, 0)`, which is when
    /// `WidgetUpdater.scheduleStartDayWidgetUpdate()` arms its alarm.
    static func startOfNextDay(
        midnightDelayHours: Int,
        from now: Date = Date(),
        zone: TimeZone = .current
    ) -> Date {
        let calendar = widgetCalendar
        let today = logicalToday(
            midnightDelayHours: midnightDelayHours, now: now, zone: zone)
        guard
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
            let turn = calendar.date(
                byAdding: .hour,
                value: midnightDelayHours,
                to: tomorrow
            )
        else { return now }
        // [logicalToday] answers in the day-key space — the UTC midnight that
        // names a local civil day — so the turn has to come back out of it to
        // be a real instant WidgetKit can wake on.
        return turn.addingTimeInterval(-Double(zone.secondsFromGMT(for: now)))
    }

    /// Whole days from [from] to [to] — `LocalDate.daysSince`.
    static func daysSince(_ from: Date, to: Date) -> Int {
        let calendar = widgetCalendar
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: from),
            to: calendar.startOfDay(for: to)
        ).day ?? 0
    }

    /// The raw document under [key], advanced to the day this process is
    /// drawing on.
    ///
    /// The version is checked here rather than after decoding: a document from
    /// a schema this build does not know is one whose fields may have moved,
    /// and shifting arrays inside it would be a guess.
    func rolledDocument(forKey key: String, in defaults: UserDefaults) -> [String: Any]? {
        guard
            let document = object(forKey: key, in: defaults),
            (document["version"] as? Int) == WidgetContract.schemaVersion
        else { return nil }
        let delay = document["midnightDelayHours"] as? Int ?? 0
        return Self.rolledForward(
            document,
            to: Self.logicalToday(midnightDelayHours: delay)
        )
    }

    /// [document] as it would have been published on [current], for a [current]
    /// later than the day it names — `WidgetDocument.rolledForwardTo`.
    ///
    /// The arrays are newest-first, so a day passing shifts every value one
    /// place down and the days nobody has answered arrive UNKNOWN — which is
    /// precisely what upstream's live redraw from the database would find,
    /// since the app has not run to record anything.
    ///
    /// What cannot be rolled is left alone and stays a day old until the app
    /// republishes: `score`, `scores`, `streaks`, `weekdayFrequency` and
    /// `targetRows` are reductions over the habit's whole history, and there is
    /// no history in this process to reduce. The rollover buys the day, the
    /// grid and the tick, which is what the six cards draw from.
    static func rolledForward(_ document: [String: Any], to current: Date) -> [String: Any] {
        guard let published = (document["today"] as? String).flatMap(parseDate)
        else { return document }
        let days = daysSince(published, to: current)
        if days <= 0 { return document }
        var rolled = document
        rolled["today"] = formatDate(current)
        if let habits = document["habits"] as? [[String: Any]] {
            rolled["habits"] = habits.map { rolledHabit($0, days: days) }
        }
        return rolled
    }

    /// One habit of [rolledForward] — `HabitData.rolledForward(days)`.
    ///
    /// Shifting past the end of an array simply empties it, which is the right
    /// answer for a widget nobody has looked at in sixty days.
    private static func rolledHabit(_ habit: [String: Any], days: Int) -> [String: Any] {
        var rolled = habit
        let entries = habit["entries"] as? [Int] ?? []
        let shifted = entries.indices.map {
            $0 < days ? EntryValue.unknown : entries[$0 - days]
        }
        rolled["entries"] = shifted
        // `value` is `entries[0]` by definition, and it is what the tick, the
        // ring glyph and `ToggleHabitIntent`'s next value are read from.
        rolled["value"] = shifted.first ?? EntryValue.unknown
        if let notes = habit["notesIndicators"] as? [Bool] {
            rolled["notesIndicators"] = notes.indices.map {
                $0 < days ? false : notes[$0 - days]
            }
        }
        // The History grid draws `historySeries`, not `entries`
        // (`audit10.history-home-screen-widget-draws-more#1`), and it is
        // newest-first too: left unshifted the grid would paint every square
        // `days` days late.
        let series = habit["historySeries"] as? String
        if let series {
            let digits = Array(series)
            rolled["historySeries"] = String(
                digits.indices.map { $0 < days ? offSquare : digits[$0 - days] }
            )
        }
        if let notes = habit["historyNotes"] as? [Int] {
            rolled["historyNotes"] = notes
                .map { $0 + days }
                .filter { $0 < (series?.count ?? 0) }
        }
        return rolled
    }

    /// The digit `historySeries` spells an unanswered day with, which is what
    /// the days at the front of a shifted series have to arrive as.
    private static var offSquare: Character {
        Character(String(HistorySquare.off.ordinal))
    }
}

// MARK: - Toggling in place

/// Where a tap on a boolean Checkmark widget is recorded.
///
/// Upstream the tap is a broadcast: `WidgetReceiver` runs
/// `WidgetBehavior.onToggleRepetition` inside the app's process and the widget
/// flips where it stands, with nothing appearing on screen
/// (`widgets.checkmark#6`). Nothing here can run that code — a widget
/// extension has no Flutter engine, and the engine `home_widget`'s background
/// service would start registers no plugins, so it could open neither the
/// database nor the directory it lives in.
///
/// So the extension does the half it can: it advances the value the card draws,
/// and it appends the tap to `WidgetContract.pendingKey`. The app applies the
/// queue through `CommandRunner` at its next publish — startup, resume, any
/// command, the day rollover — so the entry is still created by the one writer
/// upstream uses. What is written here is a request, never an entry.
extension WidgetStore {

    /// `Entry.nextToggleValue`, ported value for value.
    ///
    /// The two preferences arrive in the index because they belong to the user,
    /// not to the widget: without them a card with skip disabled would show
    /// SKIP for a moment and then correct itself to NO on the next publish.
    static func nextToggleValue(
        _ value: Int,
        isSkipEnabled: Bool,
        areQuestionMarksEnabled: Bool
    ) -> Int {
        switch value {
        case EntryValue.yesAuto:
            return EntryValue.yesManual
        case EntryValue.yesManual:
            return isSkipEnabled ? EntryValue.skip : EntryValue.no
        case EntryValue.skip:
            return EntryValue.no
        case EntryValue.no:
            return areQuestionMarksEnabled
                ? EntryValue.unknown
                : EntryValue.yesManual
        case EntryValue.unknown:
            return EntryValue.yesManual
        default:
            return EntryValue.yesManual
        }
    }

    /// Records one tap and repaints the habit, atomically enough.
    ///
    /// "Repaints the habit" is every card the tap can move, not only the one
    /// under the finger: `ToggleHabitIntent.perform` ends in
    /// `reloadAllTimelines`, and upstream `WidgetUpdater.onCommandFinished`
    /// broadcasts `ACTION_APPWIDGET_UPDATE` to every widget bound to the habit,
    /// so a History widget on the same habit flips today's square at the same
    /// moment the tick does. Today's square is the one digit this side can
    /// move — `historySeries[0]` is decided by today's value alone — while
    /// `score`, `scores`, `streaks`, `weekdayFrequency` and `targetRows` are
    /// reductions over the whole record that only the app can recompute, and
    /// legitimately ride along stale until it republishes.
    ///
    /// The index is rewritten rather than re-encoded from `WidgetIndex`: the
    /// document belongs to the app, this side understands only part of it, and
    /// anything it does not understand has to survive the round trip untouched.
    /// That is what `JSONSerialization` on the raw dictionary buys.
    ///
    /// Nothing here throws. An extension that traps is killed by the system and
    /// the user is left with a blank card and no way to tell why.
    func stageToggle(habitId: Int) {
        guard
            let defaults,
            // The rolled-forward index, not the published one
            // (`audit15.ios-home-screen-widgets-never-roll#1`). The intent runs
            // without ever building a timeline entry, so the roll has to reach
            // it through the store; and the flip below writes into offset 0 of
            // arrays that are only today's once the day has been moved on.
            // Rolling the whole index rather than the one habit is deliberate:
            // `today` is re-stamped by it, so a partial roll would freeze every
            // other habit at the old day forever.
            var index = rolledDocument(forKey: WidgetContract.indexKey, in: defaults)
        else { return }

        let today = index["today"] as? String
        let isSkipEnabled = index["isSkipEnabled"] as? Bool ?? false
        let areQuestionMarksEnabled = index["areQuestionMarksEnabled"] as? Bool ?? false

        // The optimistic half: the card the user is looking at.
        if var habits = index["habits"] as? [[String: Any]] {
            for position in habits.indices
            where habits[position]["id"] as? Int == habitId {
                let current = habits[position]["value"] as? Int ?? EntryValue.unknown
                let next = Self.nextToggleValue(
                    current,
                    isSkipEnabled: isSkipEnabled,
                    areQuestionMarksEnabled: areQuestionMarksEnabled
                )
                habits[position]["value"] = next
                if var entries = habits[position]["entries"] as? [Int],
                   !entries.isEmpty {
                    entries[0] = next
                    habits[position]["entries"] = entries
                }
                // …and the History grid, which reads `historySeries` in
                // preference to `entries`
                // (`audit10.history-home-screen-widget-draws-more#1`). Offset 0
                // is today, and `HistorySquare.of(value:...)` is the same
                // mapping `HistoryCardPresenter` applies per entry, so the
                // digit written here is the digit the app will publish.
                if var series = habits[position]["historySeries"] as? String,
                   !series.isEmpty {
                    let square = HistorySquare.of(
                        value: next,
                        isNumerical: habits[position]["type"] as? String == "NUMERICAL",
                        isAtMost: habits[position]["targetType"] as? String == "AT_MOST",
                        // Through `NSNumber` so that a target the encoder
                        // wrote without a fraction still reads as a Double.
                        target: (habits[position]["target"] as? NSNumber)?
                            .doubleValue ?? 0
                    )
                    series.replaceSubrange(
                        series.startIndex...series.startIndex,
                        with: String(square.ordinal)
                    )
                    habits[position]["historySeries"] = series
                }
            }
            index["habits"] = habits
            write(index, forKey: WidgetContract.indexKey, in: defaults)
        }

        // The durable half: the request the app will act on.
        var queue = object(forKey: WidgetContract.pendingKey, in: defaults) ?? [:]
        if (queue["version"] as? Int) != WidgetContract.schemaVersion {
            queue = ["version": WidgetContract.schemaVersion, "toggles": []]
        }
        var toggles = queue["toggles"] as? [[String: Any]] ?? []
        // `seq` is what makes the app's drain idempotent, and what lets a tap
        // that arrives mid-drain survive it.
        let seq = (toggles.compactMap { $0["seq"] as? Int }.max() ?? 0) + 1
        var toggle: [String: Any] = ["seq": seq, "habit": habitId]
        // The day the tap was made on, which the roll above has made the day
        // the card was drawing. An index that names no day at all names none
        // here either — the Android toggle deep link carries no date and
        // `IntentParser.parseDate` supplies `getToday()` for it, which is what
        // `WidgetToggleQueue._apply` does with a dateless tap. A `""` would
        // have been a date the app could only throw away.
        if let today, !today.isEmpty {
            toggle["date"] = today
        }
        toggles.append(toggle)
        queue["toggles"] = toggles
        write(queue, forKey: WidgetContract.pendingKey, in: defaults)
    }

    private func object(forKey key: String, in defaults: UserDefaults) -> [String: Any]? {
        guard
            let raw = defaults.string(forKey: key),
            let data = raw.data(using: .utf8),
            let decoded = try? JSONSerialization.jsonObject(with: data)
        else { return nil }
        return decoded as? [String: Any]
    }

    private func write(_ value: [String: Any], forKey key: String, in defaults: UserDefaults) {
        guard
            JSONSerialization.isValidJSONObject(value),
            let data = try? JSONSerialization.data(withJSONObject: value),
            let text = String(data: data, encoding: .utf8)
        else { return }
        defaults.set(text, forKey: key)
    }
}

/// The tap itself: `widgets.checkmark#6`, as close as iOS allows.
///
/// A widget `Button(intent:)` runs this inside the extension. `openAppWhenRun`
/// is false, so nothing is brought to the foreground — the user stays on the
/// home screen, which is the entire point of the Checkmark widget — and the
/// reload below is the redraw `BaseWidgetProvider.onUpdate` performs after the
/// broadcast upstream. Every widget is reloaded, not just this kind, because
/// `WidgetUpdater.updateWidgets(habitId)` refreshes all six providers.
struct ToggleHabitIntent: AppIntent {

    static var title: LocalizedStringResource = "Toggle Habit"

    /// The whole point: the tap opens nothing.
    static var openAppWhenRun: Bool = false

    /// It is not an action a user assembles shortcuts out of; it exists only
    /// as the widget's button, so it stays out of the Shortcuts gallery (and
    /// out of the widget-surface strings that have to be translated).
    static var isDiscoverable: Bool = false

    @Parameter(title: "Habit")
    var habitId: Int

    init() {}

    init(habitId: Int) {
        self.habitId = habitId
    }

    func perform() async throws -> some IntentResult {
        WidgetStore().stageToggle(habitId: habitId)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
