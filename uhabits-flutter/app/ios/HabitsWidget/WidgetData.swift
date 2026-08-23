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
struct WidgetStore {

    let defaults: UserDefaults?

    init(appGroupId: String = WidgetContract.appGroupId) {
        defaults = UserDefaults(suiteName: appGroupId)
    }

    func index() -> WidgetIndex? {
        decode(WidgetIndex.self, key: WidgetContract.indexKey, version: \.version)
    }

    func document(widgetId: Int) -> WidgetDocument? {
        decode(
            WidgetDocument.self,
            key: WidgetContract.documentKey(widgetId),
            version: \.version
        )
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
    func today() -> Date? {
        guard let raw = index()?.today else { return nil }
        return Self.parseDate(raw)
    }

    /// The same day as [today], in the wire format, for the links that carry a
    /// date back to the app.
    func todayText() -> String? { index()?.today }

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

    private func decode<T: Decodable>(
        _ type: T.Type,
        key: String,
        version: KeyPath<T, Int>
    ) -> T? {
        guard
            let raw = defaults?.string(forKey: key),
            let data = raw.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(type, from: data)
        else { return nil }
        guard decoded[keyPath: version] == WidgetContract.schemaVersion else { return nil }
        return decoded
    }

    /// The wire format is `HomeWidgetBridge.formatDate`: a plain ISO-8601
    /// calendar date, no time and no zone. It is parsed in the current calendar
    /// so that "today" here means the same civil day it meant in Dart.
    /// The inverse of [parseDate]: `HomeWidgetBridge.formatDate`'s output for a
    /// day, used when nothing has been published and the device's own today is
    /// the best a link can carry.
    static func formatDate(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
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
        return Calendar.current.date(from: components)
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
            var index = object(forKey: WidgetContract.indexKey, in: defaults),
            (index["version"] as? Int) == WidgetContract.schemaVersion
        else { return }

        let today = index["today"] as? String ?? ""
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
        toggles.append(["seq": seq, "habit": habitId, "date": today])
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
