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
import WidgetKit

/// iOS's replacement for `HabitPickerDialog`.
///
/// On Android a widget is configured by an activity that runs when the user
/// drops it on the launcher: it lists the eligible habits, and on confirm
/// writes `widget-%06d-habit` and returns the widget id
/// (`widgets.config-picker`). WidgetKit has neither a configuration activity
/// nor a widget id — the user edits a widget in place, and the chosen value is
/// an `AppIntent` parameter the system stores for that instance. So the picker
/// becomes the entity query below, and the "eligible habits" become whatever
/// the app has published into the App Group.
///
/// One consequence worth stating plainly: nothing on this side can *create* a
/// binding. Until the Dart side publishes at least one widget document there
/// are no habits to choose from and every widget renders
/// `WidgetPlaceholder.noHabits`.
struct HabitEntity: AppEntity {

    let id: Int
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Habit")
    }

    static var defaultQuery = HabitEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// Feeds the habit list into the widget's edit sheet.
struct HabitEntityQuery: EntityQuery {

    func entities(for identifiers: [Int]) async throws -> [HabitEntity] {
        let store = WidgetStore()
        return store.allHabits()
            .filter { identifiers.contains($0.id) }
            .map { HabitEntity(id: $0.id, name: $0.name) }
    }

    /// `HabitPickerDialog` lists habits from `habitList` and the numerical /
    /// boolean variants filter it down (`widgets.registration#6`). The three
    /// widgets in this bundle are the ones whose Android picker is the
    /// unfiltered `HabitPickerDialog`, so no filter is applied here either.
    func suggestedEntities() async throws -> [HabitEntity] {
        WidgetStore().allHabits().map { HabitEntity(id: $0.id, name: $0.name) }
    }
}

/// The configuration a habit widget carries: which habit it shows.
///
/// `settings.widget-preferences.habit-ids#9` — the habit list is the only
/// per-widget setting upstream, so it is the only parameter here.
struct SelectHabitIntent: WidgetConfigurationIntent {

    static var title: LocalizedStringResource { "Select Habit" }

    static var description: IntentDescription {
        IntentDescription("Choose which habit this widget shows.")
    }

    @Parameter(title: "Habit")
    var habit: HabitEntity?

    init() {}

    init(habit: HabitEntity?) {
        self.habit = habit
    }
}

extension WidgetStore {
    /// The habit a configured widget should render.
    ///
    /// Falls back to the first published habit so that a freshly dropped
    /// widget shows something instead of an empty card while the user has not
    /// opened the edit sheet yet.
    func resolve(_ configuration: SelectHabitIntent) -> WidgetHabit? {
        if let selected = configuration.habit {
            return habit(id: selected.id)
        }
        return allHabits().first
    }

    /// Distinguishes "you have not picked a habit / there are none" from
    /// "the habit you picked is gone" (`widgets.error-states#1`).
    func isDeleted(_ configuration: SelectHabitIntent) -> Bool {
        guard let selected = configuration.habit else { return false }
        return habit(id: selected.id) == nil
    }
}
