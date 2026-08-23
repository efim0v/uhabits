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

import Foundation

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

    /// The App Group both the app and this extension belong to.
    ///
    /// `HomeWidgetPlugin.ensureInitialized()` passes the same string to
    /// `HomeWidget.setAppGroupId`, which makes `saveWidgetData` write into
    /// `UserDefaults(suiteName:)` for this suite. The two must match exactly or
    /// the extension reads an empty store and every widget shows the
    /// "no habit" placeholder.
    static let appGroupId = "group.org.isoron.uhabits"
}

// MARK: - Documents

/// The `uhabits.index` document.
struct WidgetIndex: Decodable {
    let version: Int
    let today: String
    let providers: [String]
    let widgets: [WidgetBinding]

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

    /// Every habit the app has published, in the order the documents list them,
    /// deduplicated by habit id.
    ///
    /// This is the closest thing iOS has to `HabitPickerDialog`'s list. On
    /// Android the launcher hands each widget an id and `WidgetPreferences`
    /// maps it to habits; WidgetKit has no widget id at all, so the habit is
    /// chosen in the widget's own edit sheet (see `HabitEntityQuery`) out of
    /// whatever the app has published.
    func allHabits() -> [WidgetHabit] {
        guard let index = index() else { return [] }
        var seen = Set<Int>()
        var result: [WidgetHabit] = []
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
