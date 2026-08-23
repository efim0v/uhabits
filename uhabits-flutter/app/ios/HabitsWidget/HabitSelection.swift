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
/// What every habit widget's configuration answers.
///
/// Upstream a widget's configure activity is chosen per provider
/// (`widgets.registration#6`): the unfiltered `HabitPickerDialog` for
/// Checkmark, Frequency, History and Score, `BooleanHabitPickerDialog` for
/// Streaks and `NumericalHabitPickerDialog` for Target. AppIntents takes the
/// list of choices from the *entity type* of the parameter —
/// `AppEntity.defaultQuery` — so "the same picker, filtered" has to be a
/// different entity type, and therefore a different intent type. This protocol
/// is what lets one timeline provider serve all three of them.
protocol HabitSelectionIntent: WidgetConfigurationIntent {

    /// The habit id the user picked, or nil when they have not picked one.
    var selectedHabitId: Int? { get }
}

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
    /// boolean variants filter it down (`widgets.registration#6`). Checkmark,
    /// Frequency, History and Score are the four whose Android picker is the
    /// unfiltered `HabitPickerDialog`, so no filter is applied here either;
    /// Streaks and Target have their own queries below.
    func suggestedEntities() async throws -> [HabitEntity] {
        WidgetStore().allHabits().map { HabitEntity(id: $0.id, name: $0.name) }
    }
}

/// The configuration a habit widget carries: which habit it shows.
///
/// `settings.widget-preferences.habit-ids#9` — the habit list is the only
/// per-widget setting upstream, so it is the only parameter here.
struct SelectHabitIntent: WidgetConfigurationIntent, HabitSelectionIntent {

    static var title: LocalizedStringResource { "Select Habit" }

    static var description: IntentDescription {
        IntentDescription("Choose which habit this widget shows.")
    }

    @Parameter(title: "Habit")
    var habit: HabitEntity?

    var selectedHabitId: Int? { habit?.id }

    init() {}

    init(habit: HabitEntity?) {
        self.habit = habit
    }
}

// MARK: - The filtered pickers

/// The habits `BooleanHabitPickerDialog` would list.
///
/// `widgets.config-picker#4`: it sets `shouldHideNumerical() = true`, so a
/// measurable habit is not offered for a Streak widget at all.
struct BooleanHabitEntity: AppEntity {

    let id: Int
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Yes-or-No Habit")
    }

    static var defaultQuery = BooleanHabitEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct BooleanHabitEntityQuery: EntityQuery {

    func entities(for identifiers: [Int]) async throws -> [BooleanHabitEntity] {
        try await suggestedEntities()
            .filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [BooleanHabitEntity] {
        WidgetStore().allHabits()
            .filter { !$0.isNumerical }
            .map { BooleanHabitEntity(id: $0.id, name: $0.name) }
    }
}

/// The Streak widget's configuration (`widgets.streak#5`).
struct SelectBooleanHabitIntent: WidgetConfigurationIntent, HabitSelectionIntent {

    static var title: LocalizedStringResource { "Select Habit" }

    static var description: IntentDescription {
        IntentDescription("Choose which yes-or-no habit this widget shows.")
    }

    @Parameter(title: "Habit")
    var habit: BooleanHabitEntity?

    var selectedHabitId: Int? { habit?.id }

    init() {}

    init(habit: BooleanHabitEntity?) {
        self.habit = habit
    }
}

/// The habits `NumericalHabitPickerDialog` would list.
///
/// `widgets.config-picker#5`: it sets `shouldHideBoolean() = true`.
struct NumericalHabitEntity: AppEntity {

    let id: Int
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Measurable Habit")
    }

    static var defaultQuery = NumericalHabitEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct NumericalHabitEntityQuery: EntityQuery {

    func entities(for identifiers: [Int]) async throws -> [NumericalHabitEntity] {
        try await suggestedEntities()
            .filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [NumericalHabitEntity] {
        WidgetStore().allHabits()
            .filter { $0.isNumerical }
            .map { NumericalHabitEntity(id: $0.id, name: $0.name) }
    }
}

/// The Target widget's configuration (`widgets.target#8`).
struct SelectNumericalHabitIntent: WidgetConfigurationIntent, HabitSelectionIntent {

    static var title: LocalizedStringResource { "Select Habit" }

    static var description: IntentDescription {
        IntentDescription("Choose which measurable habit this widget shows.")
    }

    @Parameter(title: "Habit")
    var habit: NumericalHabitEntity?

    var selectedHabitId: Int? { habit?.id }

    init() {}

    init(habit: NumericalHabitEntity?) {
        self.habit = habit
    }
}

// MARK: - Resolution

extension WidgetStore {
    /// The habit a configured widget should render.
    ///
    /// Falls back to the first published habit the widget's own picker would
    /// have offered, so that a freshly dropped widget shows something instead
    /// of an empty card while the user has not opened the edit sheet yet. The
    /// fallback is filtered too: a Target widget must never fall back onto a
    /// boolean habit, which is a habit its picker refuses to list
    /// (`widgets.target#8`).
    func resolve(
        _ configuration: some HabitSelectionIntent,
        eligible: (WidgetHabit) -> Bool = { _ in true }
    ) -> WidgetHabit? {
        if let selected = configuration.selectedHabitId {
            return habit(id: selected)
        }
        return allHabits().first(where: eligible)
    }

    /// Distinguishes "you have not picked a habit / there are none" from
    /// "the habit you picked is gone" (`widgets.error-states#1`).
    func isDeleted(_ configuration: some HabitSelectionIntent) -> Bool {
        guard let selected = configuration.selectedHabitId else { return false }
        return habit(id: selected) == nil
    }
}
