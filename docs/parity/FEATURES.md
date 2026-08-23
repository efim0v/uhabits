# Flutter Migration Parity Ledger — Loop Habit Tracker (fork at `/Users/artemefimov/Desktop/uhabits`)

## What this document is

This is the **definition of done** for the Flutter port. It enumerates every observable behavior of the
current Kotlin/Android app, split into domains, features and individually addressable **behavior rules**.
It is a contract, not a summary: each rule is reproduced verbatim from the source audit, because the
rules — not the prose around them — are what the port must reproduce.

## How to use it

- **Every unchecked box is work.** A `- [ ]` line is one feature that does not yet exist at parity in the Flutter app.
- **A box may only be checked when both are true:**
  1. A Dart test asserts that feature's behavior rules (cite the rule ids, e.g. `expect(..., reason: 'models.score-formula#4')`), and
  2. the feature actually runs on **both iOS and Android** (or, for `android-only` features, the port has an explicit, recorded decision to keep it native-Android-only or to drop it — recorded in the High-risk section below).
- **Rule ids are stable.** Every rule is prefixed `<feature-id>#<n>`. Cite them from Dart tests, commit messages and PR descriptions so coverage can be traced mechanically.
- **Do not "fix" rules while porting.** Several rules describe upstream bugs or naming inversions (e.g. `models.habit-list-ordering#8`, `settings.preferences.habit-list-orders#4`, `charts-canvas-theming.color-model#7`). They are marked as such; deviating is a product decision, not a porting detail, and must be recorded.
- **`Kotlin tests: none — write Dart test from rules`** means there is no existing executable spec: the Dart test is the first one, and the rules are the only source of truth.
- **Platform values:** `core` = pure logic, straight Dart port; `ui` = rendering/interaction, port to Flutter widgets; `android-only` = no Flutter equivalent, needs native code or a deliberate drop; `needs-native-per-platform` = must be implemented separately for Android and iOS.
- Features that appeared twice in the source audit under different ids have been **merged**; the surviving entry keeps the more specific id, lists the union of source files and Kotlin tests, and notes the absorbed id. All distinct rules from both entries are preserved.

## Summary

| Domain | Features | Behavior rules | With Kotlin tests | portRisk=high |
|---|---:|---:|---:|---:|
| Models, scoring and streaks | 39 | 332 | 38 | 1 |
| Commands and undo/redo | 18 | 140 | 15 | 0 |
| SQLite persistence, schema and migrations | 36 | 277 | 21 | 3 |
| Import, export and file IO | 33 | 260 | 30 | 6 |
| Habit list screen | 25 | 267 | 22 | 2 |
| Show habit screen and its cards | 22 | 204 | 13 | 2 |
| Create/edit habit screen and common dialogs | 26 | 238 | 18 | 2 |
| Settings, preferences, theming and intro | 31 | 260 | 23 | 5 |
| Home screen widgets | 22 | 181 | 17 | 17 |
| Reminders, notifications and time | 34 | 278 | 20 | 14 |
| Charts, canvas abstraction and theming | 32 | 310 | 21 | 6 |
| Platform glue (automation, intents, manifest, DI, startup, localization) | 26 | 197 | 11 | 6 |
| Gap-found (behaviour discovered outside the original inventory) | 8 | 56 | 0 | 0 |
| **Total** | **352** | **3000** | **249** | **64** |

"With Kotlin tests" counts features that already have at least one Kotlin unit/instrumentation test to
port or mirror; the remaining 103 features have no executable spec at all and their Dart tests must be
written from the rules below.
## Domain: Models, scoring and streaks

#### models.entry-values

- [x] `models.entry-values` — Entry value constants and semantics
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/HistoryCard.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/regression/ListHabitsRegressionTest.kt`
- **Notes:** Pure data; direct Dart port. (Merged duplicate id: `entry.values`.)

1. `models.entry-values#1` — Entry is an immutable value object with exactly three fields: date (LocalDate), value (Int), notes (String, default ""). Two Entries are equal iff all three fields are equal.
2. `models.entry-values#2` — The five reserved entry values are exactly: SKIP = 3, YES_MANUAL = 2, YES_AUTO = 1, NO = 0, UNKNOWN = -1.
3. `models.entry-values#3` — SKIP (3) means 'habit not applicable on this date'. YES_MANUAL (2) means the user explicitly checked the habit. YES_AUTO (1) means the user did not perform it but was not expected to, given the habit's frequency. NO (0) means the user was expected to perform it and did not. UNKNOWN (-1) means no data.
4. `models.entry-values#4` — For numerical habits, value holds the measured amount multiplied by 1000 (i.e. entering 2.0 miles stores 2000). Displayed/target math always divides the stored value by 1000.0.
5. `models.entry-values#5` — Entry.formattedValue returns the literal strings "YES_MANUAL", "YES_AUTO", "NO", "SKIP", "UNKNOWN" for values 2, 1, 0, 3, -1 respectively, and value.toString() for any other value (e.g. 2000 -> "2000"). Note that a numerical entry of exactly 3000 formats as "3000", but a numerical entry of 3 formats as "SKIP".
6. `models.entry-values#6` — Because SKIP == 3, a numerical habit entry whose stored value is 3 (i.e. 0.003 units) is indistinguishable from SKIP.
7. `models.entry-values#7` — Entry value constants: SKIP = 3, YES_MANUAL = 2, YES_AUTO = 1, NO = 0, UNKNOWN = -1.
8. `models.entry-values#8` — Entry.formattedValue renders those five constants as the strings "SKIP", "YES_MANUAL", "YES_AUTO", "NO", "UNKNOWN"; any other integer renders as its decimal representation (numerical habits store value*1000).
9. `models.entry-values#9` — Entry.nextToggleValue(value, isSkipEnabled, areQuestionMarksEnabled) returns: YES_AUTO -> YES_MANUAL; YES_MANUAL -> SKIP if isSkipEnabled else NO; SKIP -> NO; NO -> UNKNOWN if areQuestionMarksEnabled else YES_MANUAL; UNKNOWN -> YES_MANUAL; anything else -> YES_MANUAL.
10. `models.entry-values#10` — The CheckmarkDialog exposes the four end states directly instead of cycling; the cycle function is used only when the short-toggle preference bypasses the dialog.

#### models.entry-toggle-cycle

- [x] `models.entry-toggle-cycle` — Checkmark toggle cycle (nextToggleValue)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryTest.kt`

1. `models.entry-toggle-cycle#1` — Entry.nextToggleValue(value, isSkipEnabled, areQuestionMarksEnabled) is a pure function returning the next value when the user taps a boolean checkmark.
2. `models.entry-toggle-cycle#2` — YES_AUTO (1) always maps to YES_MANUAL (2).
3. `models.entry-toggle-cycle#3` — YES_MANUAL (2) maps to SKIP (3) when isSkipEnabled is true, otherwise to NO (0).
4. `models.entry-toggle-cycle#4` — SKIP (3) always maps to NO (0).
5. `models.entry-toggle-cycle#5` — NO (0) maps to UNKNOWN (-1) when areQuestionMarksEnabled is true, otherwise to YES_MANUAL (2).
6. `models.entry-toggle-cycle#6` — UNKNOWN (-1) always maps to YES_MANUAL (2).
7. `models.entry-toggle-cycle#7` — Any other value (e.g. a numerical value such as 2000) maps to YES_MANUAL (2).
8. `models.entry-toggle-cycle#8` — With isSkipEnabled=true and areQuestionMarksEnabled=true the full cycle is YES_MANUAL -> SKIP -> NO -> UNKNOWN -> YES_MANUAL.
9. `models.entry-toggle-cycle#9` — With isSkipEnabled=false and areQuestionMarksEnabled=false the cycle is YES_MANUAL -> NO -> YES_MANUAL.
10. `models.entry-toggle-cycle#10` — isSkipEnabled comes from preference key "pref_skip_enabled" (default false); areQuestionMarksEnabled from "pref_unknown_enabled" (default false).

#### models.entry-list-storage

- [x] `models.entry-list-storage` — EntryList storage and lookup
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryListTest.kt`

1. `models.entry-list-storage#1` — EntryList holds a map from LocalDate to Entry; there is at most one entry per date.
2. `models.entry-list-storage#2` — get(date) returns the stored Entry for that date, or Entry(date, UNKNOWN, "") when nothing is stored. It never returns null.
3. `models.entry-list-storage#3` — add(entry) inserts the entry keyed by entry.date, replacing any previously stored entry for the same date (including its notes).
4. `models.entry-list-storage#4` — getKnown() returns all stored entries sorted by date DESCENDING (newest first, oldest last). Entries explicitly stored with value UNKNOWN are still returned by getKnown().
5. `models.entry-list-storage#5` — getByInterval(from, to) returns exactly (to - from + 1) entries, one per day, ordered newest-first (index 0 == to, last index == from); days with no stored entry yield Entry(date, UNKNOWN). If from is newer than to, it returns an empty list.
6. `models.entry-list-storage#6` — clear() removes every stored entry.
7. `models.entry-list-storage#7` — All EntryList mutators and readers are annotated @Synchronized in Kotlin; in Dart single-threaded isolates this is a no-op, but the list must not be mutated during iteration.

#### models.entry-list-build-intervals

- [x] `models.entry-list-build-intervals` — Frequency interval construction (buildIntervals)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryListTest.kt`

1. `models.entry-list-build-intervals#1` — EntryList.buildIntervals(freq, entries) takes entries ordered NEWEST-FIRST and first filters to only entries whose value == YES_MANUAL (2). YES_AUTO, NO, SKIP and UNKNOWN are all discarded.
2. `models.entry-list-build-intervals#2` — Let num = freq.numerator, den = freq.denominator and filtered be the YES_MANUAL entries newest-first. For each index i from num-1 up to filtered.size-1: begin = filtered[i].date (the older endpoint), center = filtered[i - num + 1].date (the newer endpoint, the num-th checkmark counting back from begin).
3. `models.entry-list-build-intervals#3` — size defaults to den, except when den == 30 or den == 31: then size = begin.plus(1).monthLength if begin.day == begin.monthLength, otherwise size = begin.monthLength. (i.e. monthly frequencies use real calendar month lengths, and a check on the last day of the month uses the NEXT month's length.)
4. `models.entry-list-build-intervals#4` — The interval is emitted only if begin.daysUntil(center) < size; when emitted it is Interval(begin, center, begin.plus(size - 1)). Otherwise nothing is emitted for that i.
5. `models.entry-list-build-intervals#5` — The returned list is ordered newest-interval-first, matching the order of filtered.
6. `models.entry-list-build-intervals#6` — Interval.length == begin.daysUntil(end) + 1.
7. `models.entry-list-build-intervals#7` — Concrete example with Frequency.WEEKLY (1,7) and YES_MANUAL entries on day-offsets 8, 18, 23 (offset counted backwards from a reference date): result is [Interval(d8, d8, d2), Interval(d18, d18, d12), Interval(d23, d23, d17)].
8. `models.entry-list-build-intervals#8` — Concrete example with Frequency.DAILY (1,1) and the same entries: result is [Interval(d8,d8,d8), Interval(d18,d18,d18), Interval(d23,d23,d23)] (each interval is a single day).
9. `models.entry-list-build-intervals#9` — Concrete example with Frequency.TWO_TIMES_PER_WEEK (2,7) and YES_MANUAL entries at offsets 8, 15, 18, 22, 23: result is [Interval(d18,d15,d12), Interval(d22,d18,d16), Interval(d23,d22,d17)] — note no interval is produced for i = 0 because num-1 == 1.
10. `models.entry-list-build-intervals#10` — Concrete example with Frequency(1,3) and entries YES_MANUAL@d10, SKIP@d20, YES_MANUAL@d30: result is [Interval(d10,d10,d8), Interval(d30,d30,d28)] — the SKIP is ignored entirely.

#### models.entry-list-snap-intervals

- [x] `models.entry-list-snap-intervals` — Interval snapping (snapIntervalsTogether)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryListTest.kt`
- **Notes:** Purpose: remove gaps and maximise streaks for non-daily habits.

1. `models.entry-list-snap-intervals#1` — snapIntervalsTogether(intervals) mutates the list in place. intervals must be ordered newest-first.
2. `models.entry-list-snap-intervals#2` — For i from 1 to size-1: curr = intervals[i] (older), next = intervals[i-1] (newer). gapNextToCurrent = next.begin.daysUntil(curr.end) (i.e. curr.end - next.begin in days). gapCenterToEnd = curr.center.daysUntil(curr.end).
3. `models.entry-list-snap-intervals#3` — If gapNextToCurrent >= 0 (the two intervals touch or overlap), shift = min(gapCenterToEnd, gapNextToCurrent + 1), and intervals[i] is replaced with Interval(curr.begin.minus(shift), curr.center (unchanged), curr.end.minus(shift)) — i.e. the older interval slides backwards into the past.
4. `models.entry-list-snap-intervals#4` — If gapNextToCurrent < 0 the interval is left untouched.
5. `models.entry-list-snap-intervals#5` — The shift is applied cumulatively as i increases, because each iteration reads the already-shifted intervals[i-1].
6. `models.entry-list-snap-intervals#6` — Concrete example: input [(d8,d8,d2),(d12,d12,d6),(d20,d20,d14),(d27,d27,d21)] becomes [(d8,d8,d2),(d15,d12,d9),(d22,d20,d16),(d29,d27,d23)] where dN = reference minus N days.
7. `models.entry-list-snap-intervals#7` — Concrete example: input [(d6,d4,d0),(d11,d8,d5)] becomes [(d6,d4,d0),(d13,d8,d7)].

#### models.entry-list-build-entries-from-interval

- [x] `models.entry-list-build-entries-from-interval` — Deriving computed entries from intervals
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryListTest.kt`

1. `models.entry-list-build-entries-from-interval#1` — buildEntriesFromInterval(original, intervals) returns an empty list when original is empty (even if intervals is non-empty).
2. `models.entry-list-build-entries-from-interval#2` — It computes 'to' = the maximum date over all original entries AND all interval begin/end dates; 'from' = the minimum date over the same set.
3. `models.entry-list-build-entries-from-interval#3` — It builds one Entry per day from 'to' down to 'from' inclusive (index 0 == 'to'), all initialised to UNKNOWN with empty notes. The index for a date d is d.daysUntil(to).
4. `models.entry-list-build-entries-from-interval#4` — Every day covered by any interval (begin..end inclusive) is overwritten with Entry(date, YES_AUTO) and empty notes.
5. `models.entry-list-build-entries-from-interval#5` — Then each original entry is copied over the result at its index. The written value is entry.value when the current slot is UNKNOWN, OR entry.value == SKIP, OR entry.value == YES_MANUAL; otherwise (slot is YES_AUTO and entry is NO or another value) the written value is YES_AUTO. The original entry's notes are always preserved.
6. `models.entry-list-build-entries-from-interval#6` — Consequence: a NO entry that falls inside an interval becomes YES_AUTO (but keeps its notes); a NO entry outside all intervals stays NO.
7. `models.entry-list-build-entries-from-interval#7` — Concrete example: original = [YES_MANUAL@d1, NO@d2 notes="Test", NO@d4, YES_MANUAL@d5, YES_MANUAL@d10, NO@d11]; intervals = [(d2,d2,d1),(d6,d5,d4),(d10,d8,d8)]. Result (oldest-index-last, listed here d1..d11) = YES_MANUAL@d1, YES_AUTO@d2 notes="Test", UNKNOWN@d3, YES_AUTO@d4, YES_MANUAL@d5, YES_AUTO@d6, UNKNOWN@d7, YES_AUTO@d8, YES_AUTO@d9, YES_MANUAL@d10, NO@d11.
8. `models.entry-list-build-entries-from-interval#8` — The returned list is ordered newest-first (index 0 is the newest date).

#### models.entry-list-recompute

- [x] `models.entry-list-recompute` — Recomputing computedEntries from originalEntries
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteEntryList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryListTest.kt`

1. `models.entry-list-recompute#1` — EntryList.recomputeFrom(originalEntries, frequency, isNumerical) first clears the receiver, then repopulates it.
2. `models.entry-list-recompute#2` — When isNumerical is true it simply copies every entry from originalEntries.getKnown() verbatim (values, notes and dates unchanged); no YES_AUTO entries are ever created for numerical habits.
3. `models.entry-list-recompute#3` — When isNumerical is false it runs: original = originalEntries.getKnown(); intervals = buildIntervals(frequency, original); snapIntervalsTogether(intervals); computed = buildEntriesFromInterval(original, intervals); then adds only those computed entries where value != UNKNOWN OR notes is non-empty. (So UNKNOWN days with notes ARE stored, UNKNOWN days without notes are not.)
4. `models.entry-list-recompute#4` — Calling recomputeFrom a second time fully replaces the previous contents; recomputeFrom(EntryList(), freq, false) leaves the list empty.
5. `models.entry-list-recompute#5` — Concrete boolean example with Frequency(1,3) and original YES_MANUAL at day-offsets 4, 9 and 10 from a reference date: computed.getKnown() equals, newest-first: YES_AUTO@offset2, YES_AUTO@offset3, YES_MANUAL@offset4, YES_AUTO@offset7, YES_AUTO@offset8, YES_MANUAL@offset9, YES_MANUAL@offset10, YES_AUTO@offset11, YES_AUTO@offset12.
6. `models.entry-list-recompute#6` — Concrete numerical example: original values 100@offset4, 200@offset9, 300@offset10 with Frequency.DAILY produce exactly those three entries and nothing else.
7. `models.entry-list-recompute#7` — SQLiteEntryList.recomputeFrom throws UnsupportedOperationException — only the in-memory computedEntries list is ever recomputed.

#### models.entry-grouped-sum

- [x] `models.entry-grouped-sum` — Grouped sums over entries (groupedSum)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/TargetCard.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryListTest.kt`
- **Notes:** SKIP is explicitly zeroed for numerical habits so a SKIP day does not count as 0.003 units.

1. `models.entry-grouped-sum#1` — List<Entry>.groupedSum(truncateField, firstWeekday = 7, isNumerical) maps each entry to a value, groups by truncated date, and sums.
2. `models.entry-grouped-sum#2` — Value mapping when isNumerical == true: SKIP (3) maps to 0; everything else maps to max(0, value) (so UNKNOWN -1 and NO 0 map to 0).
3. `models.entry-grouped-sum#3` — Value mapping when isNumerical == false: YES_MANUAL (2) maps to 1000; every other value (including YES_AUTO, SKIP, NO, UNKNOWN) maps to 0.
4. `models.entry-grouped-sum#4` — Date truncation: DAY -> the date itself; WEEK_NUMBER -> date.startOfWeek(firstWeekdayEnum); MONTH -> date.startOfMonth(); QUARTER -> date.startOfQuarter(); YEAR -> date.startOfYear().
5. `models.entry-grouped-sum#5` — firstWeekday is a 1-based index into the DayOfWeek enum ordered SUNDAY(1), MONDAY(2), TUESDAY(3), WEDNESDAY(4), THURSDAY(5), FRIDAY(6), SATURDAY(7); the parameter default is 7 (SATURDAY). It is only used for WEEK_NUMBER.
6. `models.entry-grouped-sum#6` — The result is one Entry(truncatedDate, sum) per non-empty group, sorted by date DESCENDING (newest bucket first). Periods with no source entries produce no bucket at all (gaps are preserved, not filled with zeros).
7. `models.entry-grouped-sum#7` — Concrete boolean example: 100 YES_MANUAL entries at fixed offsets from 2014-06-01 grouped by MONTH yield 17 buckets with byMonth[0] == Entry(2014-06-01, 1000), byMonth[6] == Entry(2013-12-01, 7000), byMonth[12] == Entry(2013-05-01, 6000); by YEAR they yield Entry(2014-01-01, 34000) and Entry(2013-01-01, 66000).
8. `models.entry-grouped-sum#8` — Consumers (TargetCard) take .firstOrNull()?.value ?: 0 for 'the current period'.

#### models.entry-count-skipped-days

- [x] `models.entry-count-skipped-days` — Counting skipped days per period
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `models.entry-count-skipped-days#1` — List<Entry>.countSkippedDays(truncateField, firstWeekday = 7) maps every entry whose value == SKIP (3) to 1 and every other value to 0, then groups by the same truncation rules as groupedSum and sums.
2. `models.entry-count-skipped-days#2` — The result is one Entry(truncatedDate, skipCount) per non-empty group, sorted by date DESCENDING (newest first).
3. `models.entry-count-skipped-days#3` — It has no isNumerical parameter — SKIP is detected identically for boolean and numerical habits.

#### models.entry-weekday-frequency

- [x] `models.entry-weekday-frequency` — Weekday-vs-month frequency histogram
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryListTest.kt`

1. `models.entry-weekday-frequency#1` — EntryList.computeWeekdayFrequency(isNumerical) returns a Map<LocalDate, Array<Int>> keyed by the first day of each month (date.startOfMonth()), with a 7-element int array as value.
2. `models.entry-weekday-frequency#2` — The array index is computed as (date.dayOfWeek.daysSinceSunday + 1) % 7, so index 0 = Saturday, 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday.
3. `models.entry-weekday-frequency#3` — It iterates getKnown() (all stored entries). When isNumerical is true it adds entry.value to the bucket (raw stored value, including SKIP's 3 and UNKNOWN's -1). When isNumerical is false it adds 1 only when entry.value == YES_MANUAL.
4. `models.entry-weekday-frequency#4` — Months with no stored entries have no key in the map at all — lookups for those months return null, and callers must treat null as 'no data'.
5. `models.entry-weekday-frequency#5` — Buckets are created lazily as arrayOf(0,0,0,0,0,0,0) the first time any entry in that month is seen, so a month with entries but zero YES_MANUAL yields an all-zero array (not null).
6. `models.entry-weekday-frequency#6` — This is computed from habit.originalEntries (not computedEntries) at every call site.

#### models.score-formula

- [x] `models.score-formula` — Score exponential-decay formula
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Score.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/ScoreTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/ScoreListTest.kt`

1. `models.score-formula#1` — Score is an immutable pair (date: LocalDate, value: Double).
2. `models.score-formula#2` — Score.compute(frequency, previousScore, checkmarkValue) = previousScore * multiplier + checkmarkValue * (1 - multiplier), where multiplier = 0.5.pow(sqrt(frequency) / 13.0).
3. `models.score-formula#3` — frequency is the habit's numerator/denominator as a Double (e.g. 3 times per 8 days -> 0.375). The 13.0 divisor and the 0.5 base are the only tuning constants; there is no separate half-life constant.
4. `models.score-formula#4` — For frequency = 1.0 (daily): multiplier = 0.948077514..., 1 - multiplier = 0.051922486...; compute(1.0, 0.0, 1.0) == 0.051922 (±1e-6), compute(1.0, 0.5, 1.0) == 0.525961, compute(1.0, 0.75, 1.0) == 0.762981, compute(1.0, 0.0, 0.0) == 0.0, compute(1.0, 0.5, 0.0) == 0.474039, compute(1.0, 0.75, 0.0) == 0.711058.
5. `models.score-formula#5` — For frequency = 1/3: multiplier = 0.969685248...; compute(1/3, 0.0, 1.0) == 0.030314, compute(1/3, 0.5, 1.0) == 0.515157, compute(1/3, 0.75, 1.0) == 0.757578, compute(1/3, 0.5, 0.0) == 0.484842, compute(1/3, 0.75, 0.0) == 0.727263.
6. `models.score-formula#6` — checkmarkValue is a completion fraction in [0.0, 1.0], not a raw entry value.
7. `models.score-formula#7` — Score values are always in [0.0, 1.0] given inputs in that range; a daily habit reaches > 0.99 within 90 consecutive checks, a weekly (1/7) habit within 39 weekly checks, and a monthly (1/30) habit within 18 monthly checks.

#### models.score-list-recompute-boolean

- [x] `models.score-list-recompute-boolean` — Score recomputation for boolean habits
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ScoreList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/ScoreListTest.kt`

1. `models.score-list-recompute-boolean#1` — ScoreList.recompute(frequency, isNumerical, numericalHabitType, targetValue, computedEntries, from, to) clears the internal map and rebuilds one Score for every date in [from, to].
2. `models.score-list-recompute-boolean#2` — values = computedEntries.getByInterval(from, to) mapped to their Int values, so values[0] is the newest (date 'to'). The loop runs i = 0..values.size-1 with offset = values.size - i - 1, so it walks from OLDEST to newest, and writes map[from.plus(i)] = Score(from.plus(i), previousValue) at the end of each iteration.
3. `models.score-list-recompute-boolean#3` — freq = frequency.toDouble() = numerator / denominator, computed BEFORE any doubling.
4. `models.score-list-recompute-boolean#4` — For boolean habits with freq < 1.0 (non-daily), both numerator and denominator are DOUBLED before the loop (e.g. 3/7 becomes 6/14, 1/7 becomes 2/14). freq itself is not doubled. This smooths irregular repetition schedules. Daily habits (freq == 1.0) are not doubled.
5. `models.score-list-recompute-boolean#5` — Rolling sum: at each step, rollingSum += 1.0 if values[offset] == YES_MANUAL; and if offset + denominator < values.size then rollingSum -= 1.0 if values[offset + denominator] == YES_MANUAL. Only YES_MANUAL counts — YES_AUTO, SKIP, NO and UNKNOWN do not add to the rolling sum.
6. `models.score-list-recompute-boolean#6` — If values[offset] == SKIP (3), the score is NOT updated for that day: previousValue is carried over unchanged and stored for that date (a skipped day has the same score as the day before it).
7. `models.score-list-recompute-boolean#7` — Otherwise percentageCompleted = min(1.0, rollingSum / numerator) and previousValue = Score.compute(freq, previousValue, percentageCompleted).
8. `models.score-list-recompute-boolean#8` — previousValue starts at 0.0 for boolean habits.
9. `models.score-list-recompute-boolean#9` — Concrete: an empty daily boolean habit with YES_MANUAL on the 20 days ending today yields, from today going back one day at a time: 0.655747, 0.636894, 0.617008, 0.596033, 0.573910, 0.550574, 0.525961, 0.500000, 0.472617, 0.443734, 0.413270, 0.381137, 0.347244, 0.311495, 0.273788, 0.234017, 0.192067, 0.147820, 0.101149, 0.051922, then 0.0 for all earlier days.
10. `models.score-list-recompute-boolean#10` — Concrete: the same habit with SKIP added at offsets 5, 10 and 11 yields from today: 0.596033, 0.573910, 0.550574, 0.525961, 0.500000, 0.472617, 0.472617, 0.443734, 0.413270, 0.381137, 0.347244, 0.347244, 0.347244, 0.311495, ... (each skipped day repeats the previous day's value).
11. `models.score-list-recompute-boolean#11` — Convergence check: a 3-per-7 habit performed exactly 2 of 3 required times each week converges to 2/3; a 4-per-7 habit performed 2 of 4 times converges to 0.5.
12. `models.score-list-recompute-boolean#12` — Convergence check: a 1-per-7 habit performed once per week but on varying weekdays still converges to 1.0 (within 1e-3), thanks to the doubling and to YES_AUTO fill-in.

#### models.score-list-recompute-numerical-at-least

- [x] `models.score-list-recompute-numerical-at-least` — Score recomputation for numerical AT_LEAST habits
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ScoreList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/ScoreListTest.kt`

1. `models.score-list-recompute-numerical-at-least#1` — For numerical habits the numerator/denominator are NEVER doubled, regardless of freq.
2. `models.score-list-recompute-numerical-at-least#2` — Rolling sum: rollingSum += max(0, values[offset]); and if offset + denominator < values.size then rollingSum -= max(0, values[offset + denominator]). UNKNOWN (-1) contributes 0. SKIP (3) contributes 3 to the rolling sum (a known artifact of SKIP == 3).
3. `models.score-list-recompute-numerical-at-least#3` — normalizedRollingSum = rollingSum / 1000 (integer rollingSum stored as Double, divided by 1000 to get real units).
4. `models.score-list-recompute-numerical-at-least#4` — If values[offset] == SKIP the score is not updated at all for that day — previousValue is carried over and stored (skipped days repeat the previous day's score).
5. `models.score-list-recompute-numerical-at-least#5` — For AT_LEAST with targetValue > 0: percentageCompleted = min(1.0, normalizedRollingSum / targetValue).
6. `models.score-list-recompute-numerical-at-least#6` — For AT_LEAST with targetValue <= 0: percentageCompleted = 1.0 (score converges to 1.0, and is always finite — never NaN).
7. `models.score-list-recompute-numerical-at-least#7` — previousValue starts at 0.0 for AT_LEAST.
8. `models.score-list-recompute-numerical-at-least#8` — previousValue = Score.compute(freq, previousValue, percentageCompleted) on non-SKIP days.
9. `models.score-list-recompute-numerical-at-least#9` — Concrete: an AT_LEAST habit with target 2.0, frequency 1/1 and value 2000 on the 20 days ending today produces exactly the same score sequence as the equivalent boolean habit: 0.655747, 0.636894, 0.617008, ... 0.101149, 0.051922, 0.0, 0.0.
10. `models.score-list-recompute-numerical-at-least#10` — Overachieving is clamped: a single entry of 10000000 on one day with target 2.0 gives 0.051922 today, identical to an entry of exactly 2000.
11. `models.score-list-recompute-numerical-at-least#11` — Steady value equal to half the target (1000 with target 2.0) over 500 days converges the score to 0.5; a quarter of the target (500) converges to 0.25.
12. `models.score-list-recompute-numerical-at-least#12` — SKIP days behave as if they never existed: 500 days at 1000 followed by 500 SKIP days keeps the score identical to the score after the first 500 days, and interleaving 200 SKIP days in the middle also leaves the final score unchanged.

#### models.score-list-recompute-numerical-at-most

- [x] `models.score-list-recompute-numerical-at-most` — Score recomputation for numerical AT_MOST habits
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ScoreList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/ScoreListTest.kt`

1. `models.score-list-recompute-numerical-at-most#1` — For NumericalHabitType.AT_MOST, previousValue is initialised to 1.0 (not 0.0) before the loop, so a brand-new AT_MOST habit with no entries scores 1.0.
2. `models.score-list-recompute-numerical-at-most#2` — With targetValue > 0: percentageCompleted = (1 - ((normalizedRollingSum - targetValue) / targetValue)).coerceIn(0.0, 1.0). So rollingSum == target gives 1.0, rollingSum == 2*target gives 0.0, rollingSum == 0 gives 1.0 (clamped from 2.0).
3. `models.score-list-recompute-numerical-at-most#3` — With targetValue <= 0: percentageCompleted = 0.0 if normalizedRollingSum > 0, else 1.0. The score is always finite (never NaN).
4. `models.score-list-recompute-numerical-at-most#4` — SKIP days are handled identically to AT_LEAST: the score is not updated and the previous value is stored.
5. `models.score-list-recompute-numerical-at-most#5` — Concrete: an AT_MOST habit with target 2.0, daily frequency, value 1000 on the day 20 days ago and 5000 on each of the 20 days ending today yields from today: 0.344253, 0.363106, 0.382992, 0.403967, 0.426090, 0.449426, 0.474039, 0.500000, 0.527383, 0.556266, 0.586730, 0.618863, 0.652756, 0.688505, 0.726212, 0.765983, 0.807933, 0.852180, 0.898851, 0.948078, 1.0, then 0.0 for earlier days (outside the computed range).
6. `models.score-list-recompute-numerical-at-most#6` — Concrete: recompute with no entries gives 1.0 today; adding 5000 on today and yesterday gives 0.898850; then changing the frequency to 1/2 gives 0.927369.
7. `models.score-list-recompute-numerical-at-most#7` — Concrete: a steady 3000/day against target 2.0 converges the score to 0.5; a steady 3500/day converges it to 0.25.
8. `models.score-list-recompute-numerical-at-most#8` — Undershooting is clamped: a single 10000000 entry yesterday gives 0.950773 today; a 5000 entry today plus either 0 or 1000 yesterday both give 0.948077.
9. `models.score-list-recompute-numerical-at-most#9` — Habit.isCompletedToday() ALWAYS returns false for numerical AT_MOST habits, regardless of today's value.

#### models.score-list-access

- [x] `models.score-list-access` — Score lookup and interval queries
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ScoreList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/ScoreListTest.kt`

1. `models.score-list-access#1` — ScoreList.get(date) (operator get / indexing) returns the stored Score for that date, or Score(date, 0.0) if the date is outside the recomputed range (before the first entry or after the last computed day).
2. `models.score-list-access#2` — getByInterval(from, to) returns exactly one Score per day in [from, to] inclusive, ordered by date DESCENDING (index 0 == to). If from is newer than to it returns an empty list.
3. `models.score-list-access#3` — recompute() always clears the whole map first — there is no incremental update.

#### models.streak-computation

- [x] `models.streak-computation` — Streak computation
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/StreakList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Streak.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/StreakListTest.kt`
- **Notes:** Note SKIP counts as part of a boolean streak, but UNKNOWN breaks it.

1. `models.streak-computation#1` — Streak is an immutable pair (start: LocalDate, end: LocalDate) with start <= end and length == start.daysUntil(end) + 1.
2. `models.streak-computation#2` — StreakList.recompute(computedEntries, from, to, isNumerical, targetValue, targetType) clears the list and rebuilds it from computedEntries.getByInterval(from, to) (newest-first).
3. `models.streak-computation#3` — A day qualifies for a streak when: boolean habit -> value > 0 (so YES_AUTO 1, YES_MANUAL 2 and SKIP 3 all qualify; NO 0 and UNKNOWN -1 do not); numerical AT_LEAST -> value / 1000.0 >= targetValue; numerical AT_MOST -> value != UNKNOWN && value / 1000.0 <= targetValue.
4. `models.streak-computation#4` — If no day qualifies, the streak list ends up empty and getBest returns an empty list.
5. `models.streak-computation#5` — Qualifying dates are walked newest-to-oldest; consecutive calendar days (current == begin.minus(1)) extend the current streak backwards, any gap closes the current Streak(begin, end) and starts a new one. The final streak is always appended after the loop.
6. `models.streak-computation#6` — Streaks are therefore appended newest-first in the internal list.
7. `models.streak-computation#7` — Concrete: with only YES_MANUAL today and NO five days ago on a daily boolean habit, exactly one streak of length 1 exists.

#### models.streak-best

- [x] `models.streak-best` — Best streaks selection and ordering
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/StreakList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Streak.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/StreakListTest.kt`

1. `models.streak-best#1` — Streak.compareLonger(other) returns length - other.length when the lengths differ, otherwise it falls through to compareNewer(other).
2. `models.streak-best#2` — Streak.compareNewer(other) returns end.daysSince2000 - other.end.daysSince2000.
3. `models.streak-best#3` — StreakList.getBest(limit) first sorts the whole internal list DESCENDING by compareLonger (longest first; ties broken by newer end first), then takes the first min(size, limit) elements, then re-sorts that sublist DESCENDING by compareNewer (newest end first) and returns it as an immutable list.
4. `models.streak-best#4` — The returned list therefore contains the `limit` longest streaks, ordered from NEWEST to OLDEST (not by length).
5. `models.streak-best#5` — getBest mutates the internal list order as a side effect; repeated calls still produce correct results.
6. `models.streak-best#6` — getBest(limit) with limit greater than the number of streaks returns all streaks; getBest on an empty list returns an empty list.
7. `models.streak-best#7` — Concrete with the standard 'long habit' fixture (Frequency 3/7 overridden to DAILY, YES_MANUAL at offsets 0,1,3,5,7,8,9,10,12,14,15,17,19,20,26,27,28,50,51,52,53,54,58,60,63,65,70,71,72,73,74,75,80,81,83,89,90,91,95,102,103,108,109,120): getBest(4) returns lengths [4, 3, 5, 6] in that order (newest first) and getBest(2) returns lengths [5, 6].
8. `models.streak-best#8` — Callers use getBest(10) for the Streak card, getBest(5) for the streak chart, and a widget-configurable count for the streak widget.

#### models.habit-fields-defaults

- [x] `models.habit-fields-defaults` — Habit model, fields and defaults
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitNotFoundException.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ModelFactory.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitTest.kt`

1. `models.habit-fields-defaults#1` — Habit default field values are: color = PaletteColor(8) (teal), description = "", frequency = Frequency.DAILY (1/1), id = null, isArchived = false, name = "", position = 0, question = "", reminder = null, targetType = NumericalHabitType.AT_LEAST, targetValue = 0.0, type = HabitType.YES_NO, unit = "", uuid = null.
2. `models.habit-fields-defaults#2` — On construction, if uuid is null a new random UUID is generated and stored as a lowercase 32-character hex string with no dashes (Uuid.random().toHexString()). Two freshly built habits always have different uuids.
3. `models.habit-fields-defaults#3` — Habit holds four non-null collaborators supplied by the ModelFactory: computedEntries, originalEntries, scores, streaks. originalEntries is what the user edits; computedEntries is derived.
4. `models.habit-fields-defaults#4` — habit.isNumerical == (type == HabitType.NUMERICAL).
5. `models.habit-fields-defaults#5` — habit.uriString == "content://org.isoron.uhabits/habit/$id" (e.g. id 0 gives "content://org.isoron.uhabits/habit/0").
6. `models.habit-fields-defaults#6` — habit.hasReminder() == (reminder != null).
7. `models.habit-fields-defaults#7` — habit.observable is a fresh ModelObservable per habit instance.
8. `models.habit-fields-defaults#8` — Habit.equals compares color, description, frequency, id, isArchived, name, position, question, reminder, targetType, targetValue, type and uuid. It deliberately ignores computedEntries, originalEntries, scores, streaks and observable.
9. `models.habit-fields-defaults#9` — Habit.hashCode combines the same 14 fields with the 31*result + field.hashCode() pattern, using targetType.value and type.value for the enums, 0 for null id/reminder/uuid.
10. `models.habit-fields-defaults#10` — copyFrom(other) copies every field EXCEPT id (color, description, frequency, isArchived, name, position, question, reminder, targetType, targetValue, type, unit, uuid). The uuid IS copied.
11. `models.habit-fields-defaults#11` — HabitNotFoundException is a plain RuntimeException with no message, thrown by callers that fail to resolve a habit.

#### models.habit-recompute

- [x] `models.habit-recompute` — Habit.recompute window and pipeline
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/ScoreListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/StreakListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitTest.kt`

1. `models.habit-recompute#1` — Habit.recompute() runs three steps in order: computedEntries.recomputeFrom(originalEntries, frequency, isNumerical); then scores.recompute(...); then streaks.recompute(...).
2. `models.habit-recompute#2` — The window end is always to = getToday().plus(30) — scores and streaks are computed 30 days INTO THE FUTURE.
3. `models.habit-recompute#3` — The window start is from = the date of the OLDEST entry in computedEntries.getKnown() (i.e. getKnown().lastOrNull()?.date), or getToday() when there are no entries at all.
4. `models.habit-recompute#4` — If from is newer than to, from is clamped to to.
5. `models.habit-recompute#5` — scores.recompute is called with (frequency, isNumerical, numericalHabitType = targetType, targetValue, computedEntries, from, to).
6. `models.habit-recompute#6` — streaks.recompute is called with (computedEntries, from, to, isNumerical, targetValue, targetType).
7. `models.habit-recompute#7` — recompute() must be called after any change to originalEntries, frequency, type, targetType or targetValue before scores/streaks/computedEntries are read; nothing recomputes lazily.
8. `models.habit-recompute#8` — Because 'today' is a global (getToday()), recompute results change when the day rolls over.

#### models.habit-completed-entered

- [x] `models.habit-completed-entered` — isCompletedToday and isEnteredToday
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitTest.kt`

1. `models.habit-completed-entered#1` — Both read computedEntries.get(getToday()).value.
2. `models.habit-completed-entered#2` — isEnteredToday() returns value != UNKNOWN (-1). A NO (0) entry today counts as 'entered'.
3. `models.habit-completed-entered#3` — isCompletedToday() for boolean habits returns value != NO && value != UNKNOWN — so YES_MANUAL (2), YES_AUTO (1) and SKIP (3) all count as completed.
4. `models.habit-completed-entered#4` — isCompletedToday() for numerical AT_LEAST habits returns value / 1000.0 >= targetValue (so exactly hitting the target counts).
5. `models.habit-completed-entered#5` — isCompletedToday() for numerical AT_MOST habits ALWAYS returns false, whatever today's value is.
6. `models.habit-completed-entered#6` — Concrete: numerical AT_LEAST with target 100.0 -> entry 200000 completed, entry 100000 completed, entry 50000 not completed. Switching the same habit to AT_MOST makes all three not completed.
7. `models.habit-completed-entered#7` — These two predicates drive HabitMatcher's isCompletedAllowed / isEnteredAllowed filters and the BY_STATUS sort order.

#### models.frequency

- [x] `models.frequency` — Frequency (x times per y days)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Frequency.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/ScoreListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/EditHabitCommandTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`
- **Notes:** Merged duplicate id: `frequency.model`.

1. `models.frequency#1` — Frequency is a mutable data class with fields numerator and denominator (both Int).
2. `models.frequency#2` — Its init block normalises any frequency where numerator == denominator to exactly 1/1 (so Frequency(2,2), Frequency(7,7) and Frequency(0,0) all become numerator=1, denominator=1).
3. `models.frequency#3` — toDouble() returns numerator.toDouble() / denominator.
4. `models.frequency#4` — The four named constants are: DAILY = Frequency(1,1), THREE_TIMES_PER_WEEK = Frequency(3,7), TWO_TIMES_PER_WEEK = Frequency(2,7), WEEKLY = Frequency(1,7).
5. `models.frequency#5` — Because the constants are single shared instances of a class with `var` fields, assigning habit.frequency = Frequency.DAILY shares the object; a Dart port should make Frequency immutable or copy on assignment to avoid aliasing bugs.
6. `models.frequency#6` — Frequency equality is structural on (numerator, denominator) after normalisation.
7. `models.frequency#7` — Denominators of 30 or 31 are treated as 'monthly' by EntryList.buildIntervals and use real calendar month lengths instead of the literal denominator; all other denominators are used literally.
8. `models.frequency#8` — The habit's frequency drives three things: interval construction for YES_AUTO fill-in, the score decay multiplier (via toDouble()), and the score rolling-sum window (denominator, doubled for non-daily boolean habits).
9. `models.frequency#9` — Frequency is a data class of (numerator, denominator), both mutable Ints.
10. `models.frequency#10` — The constructor normalizes: if numerator == denominator then BOTH are rewritten to 1, so Frequency(7,7) == Frequency(1,1) and Frequency(30,30) == Frequency(1,1).
11. `models.frequency#11` — Frequency.toDouble() returns numerator.toDouble() / denominator (integer numerator promoted, so 3/7 = 0.42857...).
12. `models.frequency#12` — Named constants: DAILY = (1,1), THREE_TIMES_PER_WEEK = (3,7), TWO_TIMES_PER_WEEK = (2,7), WEEKLY = (1,7).
13. `models.frequency#13` — Habit.frequency defaults to Frequency.DAILY.

#### models.habit-type-enums

- [x] `models.habit-type-enums` — HabitType and NumericalHabitType enums
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitType.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/NumericalHabitType.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`

1. `models.habit-type-enums#1` — HabitType has exactly two entries with fixed persisted ints: YES_NO(0) and NUMERICAL(1).
2. `models.habit-type-enums#2` — HabitType.fromInt(0) == YES_NO, fromInt(1) == NUMERICAL, any other int throws IllegalStateException.
3. `models.habit-type-enums#3` — NumericalHabitType has exactly two entries with fixed persisted ints: AT_LEAST(0) and AT_MOST(1).
4. `models.habit-type-enums#4` — NumericalHabitType.fromInt(0) == AT_LEAST, fromInt(1) == AT_MOST, any other int throws IllegalStateException.
5. `models.habit-type-enums#5` — Enum .name strings ("YES_NO", "NUMERICAL", "AT_LEAST", "AT_MOST") are used verbatim in CSV export.
6. `models.habit-type-enums#6` — targetType is only meaningful when type == NUMERICAL; boolean habits still carry AT_LEAST as their stored default.

#### models.weekday-list

- [x] `models.weekday-list` — WeekdayList bit-packing
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/WeekdayList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/NotificationTray.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/WeekdayListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`
- **Notes:** Merged duplicate id: `weekday-list.model`.

1. `models.weekday-list#1` — WeekdayList wraps a BooleanArray of exactly 7 elements, index 0..6.
2. `models.weekday-list#2` — WeekdayList(packedList: Int) sets weekdays[i] = true when (packedList and (1 shl i)) != 0, for i in 0..6. Bits above bit 6 are ignored.
3. `models.weekday-list#3` — WeekdayList(weekdays: BooleanArray) copies the array to exactly length 7 (padding with false or truncating).
4. `models.weekday-list#4` — toInteger() packs back: bit i set iff weekdays[i], producing a value in 0..127.
5. `models.weekday-list#5` — toArray() returns a defensive copy of length 7.
6. `models.weekday-list#6` — isEmpty is true iff every element is false.
7. `models.weekday-list#7` — WeekdayList.EVERY_DAY == WeekdayList(127).
8. `models.weekday-list#8` — Round-trip: WeekdayList(booleanArrayOf(false,false,true,true,true,true,true)).toInteger() == 124, and WeekdayList(124).toArray() equals that same array.
9. `models.weekday-list#9` — equals compares the arrays element-wise; hashCode is the array's content hash.
10. `models.weekday-list#10` — toString() renders as "{weekdays: [false,false,false,false,false,false,false]}" — a comma-joined list with no spaces inside the brackets.
11. `models.weekday-list#11` — The bit index convention is only meaningful in combination with Reminder; index 0 corresponds to the first weekday slot as persisted in the reminder_days DB column.
12. `models.weekday-list#12` — Index semantics across the whole app: index 0 = Saturday, 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday. NotificationTray decides whether to fire a reminder with reminderDays[(date.dayOfWeek.daysSinceSunday + 1) % 7], where DayOfWeek.SUNDAY.daysSinceSunday == 0 ... SATURDAY == 6.
13. `models.weekday-list#13` — The habit database column stores reminder days as this packed integer (0 when there is no reminder).

#### models.reminder

- [x] `models.reminder` — Reminder value object and weekday set
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Reminder.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/WeekdayList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/WeekdayListTest.kt`
- **Notes:** Merged duplicate id: `reminders.model`. The 0=Saturday index convention is the single most error-prone thing to port. It is never written down in the Kotlin; it is implied by NotificationTray.shouldShowReminderToday and by DateExtensions.toFormattedString which uses weekday names starting at SATURDAY.

1. `models.reminder#1` — Reminder is an immutable data class with three fields: hour (Int, 0..23), minute (Int, 0..59), days (WeekdayList).
2. `models.reminder#2` — Equality is structural over all three fields.
3. `models.reminder#3` — Habit.reminder is nullable; null means 'no reminder' and hasReminder() returns false.
4. `models.reminder#4` — Persistence: reminderHour, reminderMin and reminderDays (days.toInteger(), or 0 when there is no reminder) are stored on the habit row. On load, a Reminder is reconstructed only when BOTH reminderHour and reminderMin are non-null; otherwise habit.reminder stays null.
5. `models.reminder#5` — A Reminder is an immutable value with exactly three fields: hour (Int), minute (Int), days (WeekdayList). Two Reminders are equal iff all three fields are equal.
6. `models.reminder#6` — Habit.reminder is nullable; Habit.hasReminder() returns true iff reminder != null.
7. `models.reminder#7` — WeekdayList wraps a BooleanArray of length exactly 7. WeekdayList(packedList: Int) sets weekdays[i] = true iff (packedList and (1 shl i)) != 0, for i in 0..6.
8. `models.reminder#8` — WeekdayList.toInteger() packs back: result |= (1 shl i) for every i in 0..6 where weekdays[i] is true. WeekdayList(127).toInteger() == 127.
9. `models.reminder#9` — WeekdayList.EVERY_DAY == WeekdayList(127) (all seven days true).
10. `models.reminder#10` — WeekdayList.isEmpty returns true iff no day is true (packed value 0).
11. `models.reminder#11` — WeekdayList.toArray() returns a defensive copy of length 7; mutating it must not affect the list.
12. `models.reminder#12` — WeekdayList(BooleanArray) copies the input to length exactly 7 (padding with false / truncating).
13. `models.reminder#13` — WeekdayList.toString() is "{weekdays: [a,b,c,d,e,f,g]}" with the seven boolean values joined by commas.
14. `models.reminder#14` — Index semantics: index 0 = Saturday, 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday. This is derived from NotificationTray's lookup index (date.dayOfWeek.daysSinceSunday + 1) % 7 and from the UI which lists day names starting at Saturday.
15. `models.reminder#15` — equals/hashCode are content-based on the 7-element boolean array.

#### models.palette-color

- [ ] `models.palette-color` — PaletteColor and the fixed 20-colour mapping
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/PaletteColor.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/PaletteUtils.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/StyledResources.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`
- **Notes:** The actual rendered colors on Android come from theme resources; toCsvColor is the canonical CSV/export mapping. (Merged duplicate id: `platform-glue.palette-fixed-colors`.)

1. `models.palette-color#1` — PaletteColor is an immutable data class wrapping a single Int paletteIndex.
2. `models.palette-color#2` — toCsvColor() maps paletteIndex to a fixed 20-entry hex list, in this exact order: 0 "#D32F2F" (red), 1 "#E64A19" (deep orange), 2 "#F57C00" (orange), 3 "#FF8F00" (amber), 4 "#F9A825" (yellow), 5 "#AFB42B" (lime), 6 "#7CB342" (light green), 7 "#388E3C" (green), 8 "#00897B" (teal), 9 "#00ACC1" (cyan), 10 "#039BE5" (light blue), 11 "#1976D2" (blue), 12 "#303F9F" (indigo), 13 "#5E35B1" (deep purple), 14 "#8E24AA" (purple), 15 "#D81B60" (pink), 16 "#5D4037" (brown), 17 "#303030" (dark grey), 18 "#757575" (grey), 19 "#aaaaaa" (light grey).
3. `models.palette-color#3` — An index outside 0..19 throws IndexOutOfBoundsException from toCsvColor().
4. `models.palette-color#4` — compareTo(other) is a plain method (not an operator/Comparable implementation) returning paletteIndex.compareTo(other.paletteIndex); it is what drives BY_COLOR_ASC / BY_COLOR_DESC sorting.
5. `models.palette-color#5` — The default habit color is PaletteColor(8) (teal).
6. `models.palette-color#6` — PaletteColor.toFixedAndroidColor() maps paletteIndex 0..19 to exactly these hex colors in order: 0 #D32F2F red, 1 #E64A19 deep orange, 2 #F57C00 orange, 3 #FF8F00 amber, 4 #F9A825 yellow, 5 #AFB42B lime, 6 #7CB342 light green, 7 #388E3C green, 8 #00897B teal, 9 #00ACC1 cyan, 10 #039BE5 light blue, 11 #1976D2 blue, 12 #303F9F indigo, 13 #5E35B1 deep purple, 14 #8E24AA purple, 15 #D81B60 pink, 16 #5D4037 brown, 17 #303030 dark grey, 18 #757575 grey, 19 #aaaaaa light grey.
7. `models.palette-color#7` — An index outside 0..19 throws ArrayIndexOutOfBoundsException — there is no clamping.
8. `models.palette-color#8` — PaletteUtils.getAndroidTestColor(index) is just PaletteColor(index).toFixedAndroidColor() and is used only by instrumentation tests.
9. `models.palette-color#9` — Int.toPaletteColor(context) does the inverse using the CURRENT THEME's palette (StyledResources(context).getPalette()) and returns PaletteColor(palette.indexOf(this)); an unmatched color yields PaletteColor(-1).
10. `models.palette-color#10` — PaletteColor(11) (blue #1976D2) is the hard-coded toolbar color for the Tasker edit screen and the About screen.

#### models.model-observable

- [x] `models.model-observable` — ModelObservable listener notification
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ModelObservable.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitListTest.kt`

1. `models.model-observable#1` — ModelObservable keeps an ordered mutable list of Listener callbacks, initially empty.
2. `models.model-observable#2` — addListener(l) appends; removeListener(l) removes the first matching listener and does nothing if it is not registered.
3. `models.model-observable#3` — notifyListeners() invokes onModelChange() on every listener in registration order.
4. `models.model-observable#4` — Listener is a functional interface with a single method onModelChange().
5. `models.model-observable#5` — The same listener instance can be added more than once and will then be notified more than once.
6. `models.model-observable#6` — Each Habit has its own observable; HabitList has one observable; ScoreList / StreakList / EntryList do NOT have observables.

#### models.model-factory

- [x] `models.model-factory` — ModelFactory / MemoryModelFactory
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ModelFactory.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/memory/MemoryModelFactory.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLModelFactory.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitTest.kt`

1. `models.model-factory#1` — ModelFactory is an interface with buildComputedEntries(), buildOriginalEntries(), buildHabitList(), buildScoreList(), buildStreakList() and a default buildHabit().
2. `models.model-factory#2` — buildHabit() constructs a Habit wiring in freshly built scores, streaks, originalEntries and computedEntries; all other Habit fields take their declared defaults and a fresh uuid is generated.
3. `models.model-factory#3` — MemoryModelFactory returns plain EntryList / ScoreList / StreakList instances and a MemoryHabitList.
4. `models.model-factory#4` — SQLModelFactory returns SQLiteEntryList for originalEntries (backed by the entry repository) but a plain in-memory EntryList for computedEntries.

#### models.habit-list-crud

- [x] `models.habit-list-crud` — HabitList CRUD contract
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/memory/MemoryHabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitListTest.kt`

1. `models.habit-list-crud#1` — HabitList is an ordered Iterable<Habit> with abstract add, getById, getByUUID, getByPosition, getFiltered, indexOf, remove, size, update(List<Habit>), reorder and resort.
2. `models.habit-list-crud#2` — add(habit) throws IllegalArgumentException with message "habit already added" when the list already contains an equal habit.
3. `models.habit-list-crud#3` — MemoryHabitList.add assigns habit.id = list.size.toLong() when habit.id is null; if habit.id is non-null and already present it throws RuntimeException("duplicate id"). After adding it calls resort(), which notifies listeners.
4. `models.habit-list-crud#4` — getById(id) returns the matching habit or null (it does not throw). getById on an id that was never used returns null.
5. `models.habit-list-crud#5` — getByUUID(uuid) returns the matching habit or null; it dereferences each habit's uuid, which is never null.
6. `models.habit-list-crud#6` — getByPosition(index) indexes the sorted backing list and throws IndexOutOfBoundsException for an invalid index. Note this is the list INDEX, which equals habit.position only when the order is BY_POSITION and positions are compact.
7. `models.habit-list-crud#7` — indexOf(habit) returns the index in the sorted list, or -1 when absent.
8. `models.habit-list-crud#8` — isEmpty == (size() == 0).
9. `models.habit-list-crud#9` — remove(habit) removes it (no-op if absent) and notifies listeners. SQLiteHabitList.remove additionally clears the habit's originalEntries, deletes the habit row and rebuilds all positions.
10. `models.habit-list-crud#10` — removeAll() removes every habit one by one and then notifies listeners once more.
11. `models.habit-list-crud#11` — update(habit) delegates to update(listOf(habit)). In MemoryHabitList update only re-sorts; in SQLiteHabitList it also writes each habit back to the database and notifies listeners.
12. `models.habit-list-crud#12` — iterator() iterates over a snapshot copy of the list, so the list can be modified during iteration without a ConcurrentModificationException.

#### models.habit-list-ordering

- [x] `models.habit-list-ordering` — Habit list sort orders
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/memory/MemoryHabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`
- **Notes:** The BY_SCORE_ASC/DESC naming inversion is preserved from upstream Loop; do not 'fix' it during the port without also flipping the menu icons.

1. `models.habit-list-ordering#1` — HabitList.Order has exactly nine values: BY_NAME_ASC, BY_NAME_DESC, BY_COLOR_ASC, BY_COLOR_DESC, BY_SCORE_ASC, BY_SCORE_DESC, BY_STATUS_ASC, BY_STATUS_DESC, BY_POSITION.
2. `models.habit-list-ordering#2` — Defaults are primaryOrder = BY_POSITION and secondaryOrder = BY_NAME_ASC.
3. `models.habit-list-ordering#3` — The effective comparator applies the primary comparator; only when it returns 0 (and a secondary order is set) does it apply the secondary comparator.
4. `models.habit-list-ordering#4` — Setting primaryOrder or secondaryOrder rebuilds the composed comparator and immediately re-sorts the list, notifying listeners.
5. `models.habit-list-ordering#5` — BY_POSITION compares habit.position ascending.
6. `models.habit-list-ordering#6` — BY_NAME_ASC compares habit.name with plain String.compareTo (ordinal/UTF-16 code-unit order, case-sensitive, NOT locale-aware collation). BY_NAME_DESC is its exact reverse.
7. `models.habit-list-ordering#7` — BY_COLOR_ASC compares color.paletteIndex ascending; BY_COLOR_DESC is its exact reverse.
8. `models.habit-list-ordering#8` — BY_SCORE_DESC compares habit.scores[getToday()].value ASCENDING (habit1 vs habit2) — i.e. the enum name is 'DESC' but the raw comparator puts the LOWEST score first; BY_SCORE_ASC is its exact reverse and puts the highest score first. Port this literally to preserve UI behaviour.
9. `models.habit-list-ordering#9` — BY_STATUS_DESC orders: habits completed today first (isCompletedToday() true before false); then, among equally-completed habits, numerical habits before boolean habits; then by today's computedEntries value DESCENDING. BY_STATUS_ASC is its exact reverse.
10. `models.habit-list-ordering#10` — resort() re-sorts using the current comparator and notifies listeners.
11. `models.habit-list-ordering#11` — Concrete: given habits A(color 2,pos 1), B(color 2,pos 3), C(color 0,pos 0), D(color 1,pos 2) added in order C,A,D,B: BY_POSITION gives C,A,D,B; BY_NAME_DESC gives D,C,B,A; BY_NAME_ASC gives A,B,C,D; BY_COLOR_ASC with secondary BY_NAME_ASC gives C,D,A,B; BY_COLOR_DESC with secondary BY_NAME_ASC gives A,B,D,C.

#### models.habit-list-reorder

- [x] `models.habit-list-reorder` — Manual reordering and position renumbering
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/memory/MemoryHabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitListTest.kt`

1. `models.habit-list-reorder#1` — reorder(from, to) moves habit `from` to the list index currently occupied by habit `to`.
2. `models.habit-list-reorder#2` — It throws IllegalStateException("cannot reorder automatically sorted list") when primaryOrder != BY_POSITION.
3. `models.habit-list-reorder#3` — It throws IllegalStateException when called on a filtered (child) list — message: "Filtered lists cannot be modified directly. You should modify the parent list instead."
4. `models.habit-list-reorder#4` — It throws IllegalArgumentException when either habit is not in the list ("list does not contain (from) habit" / "list does not contain (to) habit").
5. `models.habit-list-reorder#5` — The target index toPos is captured BEFORE the removal: the list removes `from`, then inserts it at index toPos of the shortened list.
6. `models.habit-list-reorder#6` — After the move, every habit's position field is renumbered 0..n-1 in list order, and listeners are notified. resort() is NOT called.
7. `models.habit-list-reorder#7` — Concrete with habits ids 0..9 in order: reorder(5,2) -> [0,1,5,2,3,4,6,7,8,9]; then reorder(3,7) -> [0,1,5,2,4,6,7,3,8,9]; then reorder(4,4) -> unchanged; then reorder(8,3) -> [0,1,5,2,4,6,7,8,3,9].
8. `models.habit-list-reorder#8` — Filtered child lists reflect the new order after the parent notifies them (e.g. after reorder(5,2) the active-habits child list has habit 5 at index 0 and habit 2 at index 1).
9. `models.habit-list-reorder#9` — SQLiteHabitList.reorder additionally issues 'update habits set position = position + 1 where position >= toPos and position < fromPos' when moving up, or 'position = position - 1 where position > fromPos and position <= toPos' when moving down, then writes the moved habit's new position.
10. `models.habit-list-reorder#10` — SQLiteHabitList.repair() and its load path rebuild positions to 0..n-1 whenever the stored positions do not already match their row index.

#### models.habit-list-filtering

- [x] `models.habit-list-filtering` — Filtered (child) habit lists
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/memory/MemoryHabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitListTest.kt`

1. `models.habit-list-filtering#1` — HabitList.filter defaults to HabitMatcher(isArchivedAllowed = true), i.e. an unfiltered top-level list shows archived habits.
2. `models.habit-list-filtering#2` — getFiltered(matcher) returns a NEW MemoryHabitList that holds the given matcher, keeps a reference to the parent, registers a listener on the parent's observable, and immediately loads from the parent.
3. `models.habit-list-filtering#3` — The child copies the parent's primaryOrder and secondaryOrder at construction time; setting those properties rebuilds the child's own comparator, so the comparator argument passed to the child constructor is effectively overwritten.
4. `models.habit-list-filtering#4` — Every time the parent notifies its observable, the child clears itself, re-adds every parent habit for which filter.matches(h) is true, re-sorts and notifies its own listeners.
5. `models.habit-list-filtering#5` — add, remove and reorder on a filtered list all throw IllegalStateException("Filtered lists cannot be modified directly. You should modify the parent list instead.").
6. `models.habit-list-filtering#6` — A child list created after the parent's order was set to BY_COLOR_ASC reports primaryOrder == BY_COLOR_ASC.
7. `models.habit-list-filtering#7` — Child lists share the same Habit instances as the parent (no copying), so mutating a habit through the child mutates the parent's habit.

#### models.habit-matcher

- [x] `models.habit-matcher` — HabitMatcher filtering and search
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitMatcher.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitMatcherTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`

1. `models.habit-matcher#1` — HabitMatcher is an immutable data class with defaults isArchivedAllowed = false, isReminderRequired = false, isCompletedAllowed = true, isEnteredAllowed = true, searchQuery = "".
2. `models.habit-matcher#2` — matches(habit) returns false when: (!isArchivedAllowed && habit.isArchived); or (isReminderRequired && !habit.hasReminder()); or (!isCompletedAllowed && habit.isCompletedToday()); or (!isEnteredAllowed && habit.isEnteredToday()).
3. `models.habit-matcher#3` — Search: when searchQuery is non-empty, the query is trimmed. If the trimmed query is empty (whitespace only), the search filter is skipped and everything matches.
4. `models.habit-matcher#4` — Otherwise the habit matches only if the trimmed query is a case-insensitive substring of habit.name OR habit.question OR habit.description.
5. `models.habit-matcher#5` — Case-insensitivity uses Kotlin's ignoreCase String.contains — it does NOT strip accents. Query "MÉDITER" matches a habit named "Méditer", but query "mediter" does NOT.
6. `models.habit-matcher#6` — Emoji in the habit name do not block matching ("stretching" matches "🧘 Stretching"), and digits match ("10k" matches "10k Run").
7. `models.habit-matcher#7` — A query longer than every field matches nothing; a query matching no field matches nothing.
8. `models.habit-matcher#8` — HabitMatcher.WITH_ALARM == HabitMatcher(isArchivedAllowed = true, isReminderRequired = true).
9. `models.habit-matcher#9` — Concrete: given habits [Yoga practice], [Running / "Did you run today?" / "daily jog"], [Exercise / "Did you do yoga today?"], [Méditer / "mindfulness session"], [🧘 Stretching], [10k Run]: query "yoga" matches {Yoga practice, Exercise}; "run" matches {Running, 10k Run}; "jog" matches {Running}; "y" matches {Yoga practice, Running, Exercise}.

#### models.habit-list-csv

- [x] `models.habit-list-csv` — Habit list CSV export
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Strings.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`

1. `models.habit-list-csv#1` — HabitList.writeCSV() emits a header line then one line per habit in current iteration (sort) order, each line terminated by "\n".
2. `models.habit-list-csv#2` — The header is exactly: Position,Name,Type,Question,Description,FrequencyNumerator,FrequencyDenominator,Color,Unit,Target Type,Target Value,Archived?
3. `models.habit-list-csv#3` — Position is format("%03d", indexOf(habit) + 1), so the first habit is "001".
4. `models.habit-list-csv#4` — Type is habit.type.name ("YES_NO" or "NUMERICAL"). Color is habit.color.toCsvColor() (e.g. "#FF8F00").
5. `models.habit-list-csv#5` — Unit, Target Type and Target Value are emitted only for numerical habits; for boolean habits they are empty strings. Target Value is format("%.1f", targetValue) (e.g. "2.0").
6. `models.habit-list-csv#6` — Archived? is habit.isArchived.toString() -> "true" or "false".
7. `models.habit-list-csv#7` — Fields are joined by ","; a field containing a comma, double quote, CR or LF is wrapped in double quotes with inner quotes doubled.
8. `models.habit-list-csv#8` — Concrete expected output for habits Meditate (YES_NO, question "Did you meditate this morning?", description "this is a test description", 1/1, color index 3), Run (NUMERICAL, "How many miles did you run today?", 1/1, color index 1, unit miles, AT_LEAST, 2.0) and Wake up early (YES_NO, "Did you wake up before 6am?", 2/3, color index 5), sorted BY_POSITION then BY_NAME_ASC:\n001,Meditate,YES_NO,Did you meditate this morning?,this is a test description,1,1,#FF8F00,,,,false\n002,Run,NUMERICAL,How many miles did you run today?,,1,1,#E64A19,miles,AT_LEAST,2.0,false\n003,Wake up early,YES_NO,Did you wake up before 6am?,,2,3,#AFB42B,,,,false

#### time.local-date-core

- [x] `time.local-date-core` — LocalDate representation and arithmetic
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/DatesTest.kt`
- **Notes:** Do NOT substitute Dart's DateTime — the entire model keys on the integer day number, and switching representations risks DST/timezone drift.

1. `time.local-date-core#1` — LocalDate is a value type wrapping a single Int daysSince2000, where daysSince2000 == 0 is 2000-01-01. Equality and Comparable ordering are on daysSince2000 alone.
2. `time.local-date-core#2` — plus(n) / minus(n) return LocalDate(daysSince2000 ± n). daysUntil(other) == other.daysSince2000 - this.daysSince2000 (may be negative).
3. `time.local-date-core#3` — isOlderThan(other) == daysSince2000 < other.daysSince2000; isNewerThan(other) == daysSince2000 > other.daysSince2000.
4. `time.local-date-core#4` — Construction from (year, month, day) uses: result = 365*(year-2000) + ceil((year-2000)/4.0) - ceil((year-2000)/100.0) + ceil((year-2000)/400.0) + monthOffset[month-1] + (day-1), where monthOffset is leapOffset = [0,31,60,91,121,152,182,213,244,274,305,335,366] for leap years and nonLeapOffset = [0,31,59,90,120,151,181,212,243,273,304,334,365] otherwise.
5. `time.local-date-core#5` — isLeapYear(y) == (y % 4 == 0 && y % 100 != 0) || y % 400 == 0.
6. `time.local-date-core#6` — Decoding daysSince2000 back to year/month/day walks years from 2000 forward; for negative daysSince2000 it starts at year 1600 with an offset of -146097 days (the length of a 400-year cycle). Values are cached per instance.
7. `time.local-date-core#7` — Dates before 2000 work: LocalDate(-1) has day 31, month 12, year 1999.
8. `time.local-date-core#8` — monthLength == 30 for months 4, 6, 9 and 11; 29 for February in a leap year, 28 otherwise; 31 for all other months.
9. `time.local-date-core#9` — yearLength == 366 in a leap year, 365 otherwise.
10. `time.local-date-core#10` — toString() renders "LocalDate($year-$month-$day)" without zero padding; toCSVString() renders zero-padded "YYYY-MM-DD" (e.g. "2015-01-25", "2024-02-29", "1999-12-31").

#### time.day-of-week

- [x] `time.day-of-week` — Day-of-week computation and weekday sequences
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/DatesTest.kt`
- **Notes:** The Saturday-first array indexing is shared with EntryList.computeWeekdayFrequency and must match exactly for the frequency chart to render correctly.

1. `time.day-of-week#1` — DayOfWeek is an enum declared in the order SUNDAY(0), MONDAY(1), TUESDAY(2), WEDNESDAY(3), THURSDAY(4), FRIDAY(5), SATURDAY(6), where the payload is daysSinceSunday.
2. `time.day-of-week#2` — LocalDate.dayOfWeek computes rem = daysSince2000 % 7, mod = rem < 0 ? rem + 7 : rem, then maps mod: 0 -> SATURDAY, 1 -> SUNDAY, 2 -> MONDAY, 3 -> TUESDAY, 4 -> WEDNESDAY, 5 -> THURSDAY, 6 -> FRIDAY. (2000-01-01 was a Saturday.)
3. `time.day-of-week#3` — It is correct for negative daysSince2000: 1999-12-31 is FRIDAY, 1999-12-30 is THURSDAY, 1999-12-25 is SATURDAY, 1999-12-26 is SUNDAY.
4. `time.day-of-week#4` — getWeekdaySequence(firstWeekday) returns the 7 DayOfWeek values starting at firstWeekday and wrapping: allDays[(firstWeekday.daysSinceSunday + offset) % 7] for offset 0..6. E.g. TUESDAY gives [TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY, MONDAY].
5. `time.day-of-week#5` — countWeekdayOccurrencesInMonth(startOfMonth) returns a 7-element array indexed as (dayOfWeek.daysSinceSunday + 1) % 7 — i.e. index 0 = Saturday, 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday. It walks day from weekday to weekday + monthLength - 1 and increments freq[day % 7].
6. `time.day-of-week#6` — Concrete: February 2018 -> [4,4,4,4,4,4,4]; February 2020 -> [5,4,4,4,4,4,4]; April 2020 -> [4,4,4,4,5,5,4]; August 2020 -> [5,5,5,4,4,4,4].

#### time.truncation

- [x] `time.truncation` — Date truncation (start of week/month/quarter/year)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/DatesTest.kt`

1. `time.truncation#1` — TruncateField has exactly five values: DAY, WEEK_NUMBER, MONTH, QUARTER, YEAR.
2. `time.truncation#2` — startOfWeek(firstWeekday): delta = this.dayOfWeek.daysSinceSunday - firstWeekday.daysSinceSunday; if delta < 0 then delta += 7; result = this.minus(delta). If the date already IS the first weekday, it returns itself.
3. `time.truncation#3` — Concrete: Wednesday 2015-01-28 with firstWeekday SUNDAY gives 2015-01-25; with MONDAY gives 2015-01-26; with WEDNESDAY gives 2015-01-28; with SATURDAY gives 2015-01-24.
4. `time.truncation#4` — startOfMonth() == LocalDate(year, month, 1). E.g. 2024-02-29 -> 2024-02-01.
5. `time.truncation#5` — startOfQuarter() == LocalDate(year, ((month - 1) / 3) * 3 + 1, 1). So Jan/Feb/Mar -> Jan 1, Apr/May/Jun -> Apr 1, Jul/Aug/Sep -> Jul 1, Oct/Nov/Dec -> Oct 1.
6. `time.truncation#6` — startOfYear() == LocalDate(year, 1, 1).
7. `time.truncation#7` — The private truncateDate(date, field, firstWeekday) helper maps DAY -> date itself, WEEK_NUMBER -> startOfWeek(firstWeekday), MONTH -> startOfMonth(), QUARTER -> startOfQuarter(), YEAR -> startOfYear().

#### time.unix-conversion

- [ ] `time.unix-conversion` — Unix timestamp conversion
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/DatesTest.kt`

1. `time.unix-conversion#1` — EPOCH_2000_MILLIS == 946684800000L and MILLIS_PER_DAY == 86400000L.
2. `time.unix-conversion#2` — LocalDate.unixTime == 946684800000 + daysSince2000 * 86400000 (UTC midnight of that calendar day).
3. `time.unix-conversion#3` — LocalDate.fromUnixTime(millis): diff = millis - 946684800000; days = diff >= 0 ? diff / 86400000 : (diff - 86400000 + 1) / 86400000 — i.e. a floor division that works for pre-2000 timestamps.
4. `time.unix-conversion#4` — Concrete: fromUnixTime(946684800000 - 1) == 1999-12-31; fromUnixTime(946684800000 - 86400000) == 1999-12-31; fromUnixTime(946684800000 - 86400000 - 1) == 1999-12-30.
5. `time.unix-conversion#5` — All entry timestamps in the database are stored as this UTC-midnight value, so no timezone conversion is applied when reading/writing rows.

#### time.today-and-day-boundary

- [ ] `time.today-and-day-boundary` — Global 'today', midnight delay and day boundary
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/JvmDates.kt`, `uhabits-core/src/jsMain/kotlin/org/isoron/platform/time/JsDates.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateUtils.kt`, `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/utils/MidnightTimer.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/DatesTest.kt`, `uhabits-core/src/jvmTest/java/org/isoron/platform/time/DateUtilsTest.kt`, `uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/utils/MidnightTimerTest.kt`
- **Notes:** computeToday depends on the platform default timezone (JVM TimeZone / JS Intl). In Flutter this needs DateTime.now() plus timeZoneOffset, and a timer/lifecycle hook to roll the day over while the app is running or resumed. (Merged duplicate id: `time.compute-today`.)

1. `time.today-and-day-boundary#1` — 'Today' is a process-global mutable LocalDate. getToday() throws IllegalStateException("getToday() called before setToday()") when setToday() has never been called; setToday(date) sets it; resetToday() clears it back to the throwing state.
2. `time.today-and-day-boundary#2` — Every model that depends on the current day (Habit.recompute, isCompletedToday, isEnteredToday, ScoreList sorting, MemoryHabitList status/score comparators) reads this global — tests set it to a fixed date (the shared unit-test fixture uses 2015-01-25).
3. `time.today-and-day-boundary#3` — computeToday(hourOffset, minuteOffset) computes: localMillis = System.currentTimeMillis() + defaultTimeZone.getOffset(now); adjusted = localMillis - (hourOffset*3600000 + minuteOffset*60000); daysSinceEpoch = floorDiv(adjusted, 86400000); daysSince2000 = daysSinceEpoch - 10957 (10957 = days between 1970-01-01 and 2000-01-01).
4. `time.today-and-day-boundary#4` — The 'midnight delay' preference shifts the day boundary: Preferences.MIDNIGHT_DELAY_HOURS == 3, and midnightDelayHours returns 3 when the boolean preference "pref_midnight_delay" is true, else 0. With the delay on, times between 00:00 and 02:59 local still count as the previous day.
5. `time.today-and-day-boundary#5` — MidnightTimer schedules a repeating task first firing at millisecondsUntilTomorrowWithOffset(midnightDelayHours, 0) + 1000 ms and then every 86400000 ms; each firing calls setToday(computeToday(midnightDelayHours, 0)) and then notifies its listeners.
6. `time.today-and-day-boundary#6` — DateUtils.getStartOfDayWithOffset(timestamp, hourOffset, minuteOffset) == getStartOfDay(timestamp - hourOffset*3600000 - minuteOffset*60000), and getStartOfDay(t) == (t / 86400000) * 86400000.
7. `time.today-and-day-boundary#7` — Concrete: with a 3h30m offset, a timestamp of 03:29 on Sep 3 2020 truncates to the start of Sep 2 2020.
8. `time.today-and-day-boundary#8` — computeToday(hourOffset = 0, minuteOffset = 0) on JVM: nowMillis = System.currentTimeMillis(); localMillis = nowMillis + TimeZone.getDefault().getOffset(nowMillis); adjustedMillis = localMillis - (hourOffset*3600000 + minuteOffset*60000); daysSinceEpoch = Math.floorDiv(adjustedMillis, 86400000); return LocalDate(daysSinceEpoch - 10957).
9. `time.today-and-day-boundary#9` — 10957 is the number of days between 1970-01-01 and 2000-01-01, so LocalDate is stored as daysSince2000.
10. `time.today-and-day-boundary#10` — getToday() returns the last value passed to setToday() and throws IllegalStateException("getToday() called before setToday()") if none was set. resetToday() clears it.
11. `time.today-and-day-boundary#11` — setToday is called from: HabitsApplication.onCreate, MidnightTimer.notifyListeners, and WidgetReceiver on ACTION_UPDATE_WIDGETS_VALUE.
12. `time.today-and-day-boundary#12` — Because 'today' is a process-global cached value, a background alarm firing in a cold-started process gets 'today' from HabitsApplication.onCreate.

#### models.test-fixtures

- [x] `models.test-fixtures` — Shared habit test fixtures
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/test/HabitFixtures.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/BaseUnitTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/HabitFixtures.kt`

1. `models.test-fixtures#1` — HabitFixtures.createEmptyHabit(name = "Meditate", color = PaletteColor(3), position = 0) sets question = "Did you meditate this morning?" and frequency = DAILY, and adds no entries.
2. `models.test-fixtures#2` — createEmptyNumericalHabit(targetType) builds type = NUMERICAL, name = "Run", question = "How many miles did you run today?", unit = "miles", targetValue = 2.0, color = PaletteColor(1), and adds no entries.
3. `models.test-fixtures#3` — createNumericalHabit() is the same as createEmptyNumericalHabit(AT_LEAST) but adds values [100,200,300,400,500,600,700,800] at day offsets [0,1,3,5,7,8,9,10] from today and then calls recompute().
4. `models.test-fixtures#4` — createLongHabit() starts from createEmptyHabit(), sets frequency 3/7 and color PaletteColor(4), adds YES_MANUAL at day offsets 0,1,3,5,7,8,9,10,12,14,15,17,19,20,26,27,28,50,51,52,53,54,58,60,63,65,70,71,72,73,74,75,80,81,83,89,90,91,95,102,103,108,109,120 and recomputes.
5. `models.test-fixtures#5` — createShortHabit() sets name "Wake up early", question "Did you wake up before 6am?", frequency 2/3, and writes 10 consecutive days ending today with the pattern [YES_MANUAL, NO, NO, YES_MANUAL, YES_MANUAL, YES_MANUAL, NO, NO, YES_MANUAL, YES_MANUAL] and notes ["", "Sick", "Forgot to do it, really", "", "", "", "\"Vacation\"", "", "", ""].
6. `models.test-fixtures#6` — createLongNumericalHabit(reference) builds a NUMERICAL 'Walk' habit with unit "steps", AT_LEAST target 100.0 and 100 entries at fixed offsets/values from the reference date.
7. `models.test-fixtures#7` — The unit-test base class pins today to LocalDate(2015, 1, 25) before every test.
8. `models.test-fixtures#8` — A Dart port should reproduce these fixtures verbatim so the expected score/streak vectors in the ported tests still hold.

## Domain: Commands and undo/redo

#### commands.command-interface

- [x] `commands.command-interface` — Command interface
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/Command.kt`, `.../ArchiveHabitsCommand.kt`, `.../ChangeHabitColorCommand.kt`, `.../CreateHabitCommand.kt`, `.../CreateRepetitionCommand.kt`, `.../DeleteHabitsCommand.kt`, `.../EditHabitCommand.kt`, `.../UnarchiveHabitsCommand.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** The whole command layer is plain Kotlin with no platform APIs; a straight Dart port.

1. `commands.command-interface#1` — The Command interface declares exactly one member: `fun run()`. It has no `undo()`, no `redo()`, no id, no name, no description, no `isUndoable` flag, and no return value.
2. `commands.command-interface#2` — `run()` is synchronous and returns Unit; it reports failure only by throwing.
3. `commands.command-interface#3` — There are exactly 7 concrete Command implementations in the codebase: ArchiveHabitsCommand, ChangeHabitColorCommand, CreateHabitCommand, CreateRepetitionCommand, DeleteHabitsCommand, EditHabitCommand, UnarchiveHabitsCommand.
4. `commands.command-interface#4` — Every concrete command is a Kotlin `data class`, so it has structural equality/hashCode over its constructor properties and positional destructuring (component1..componentN). Listeners rely on destructuring: `val (_, habit) = createRepetitionCommand` yields habitList then habit; `val (_, deleted) = deleteHabitsCommand` yields habitList then the selected list. A Dart port must expose the same field order.
5. `commands.command-interface#5` — Every command holds a direct reference to the mutable HabitList (and, where relevant, to live Habit instances); commands mutate those objects in place rather than returning new state.
6. `commands.command-interface#6` — Commands are never serialized, never persisted, and never stored in any history list.

#### commands.no-undo-redo

- [ ] `commands.no-undo-redo` — No undo/redo exists in this fork
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/Command.kt`, `uhabits-android/src/main/res/values/strings.xml`, `uhabits-android/src/main/res/values/fontawesome.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/UnarchiveHabitsCommandTest.kt`
- **Notes:** Recorded explicitly so the port does not invent an undo stack that the original does not have.

1. `commands.no-undo-redo#1` — There is NO undo and NO redo anywhere in the app. There is no undo stack, no redo stack, no history size limit, no 'Undo' menu item, no undo snackbar/toast action, and no keyboard/gesture undo affordance.
2. `commands.no-undo-redo#2` — Because Command has only `run()`, no command can be reverted programmatically; the only way to reverse an action is for the user to issue the inverse action (e.g. Unarchive after Archive, or set the entry value back).
3. `commands.no-undo-redo#3` — Deletion is irreversible and the UI says so: the delete-confirmation string is 'The habit will be permanently deleted. This action cannot be undone.' (quantity=one) and 'The habits will be permanently deleted. This action cannot be undone.' (quantity=other), from R.plurals in uhabits-android/src/main/res/values/strings.xml.
4. `commands.no-undo-redo#4` — The Font Awesome glyph for `fa_undo` exists in resources but is commented out (unused).
5. `commands.no-undo-redo#5` — The test method name `UnarchiveHabitsCommandTest.testExecuteUndoRedo` is a leftover from an older upstream version; it only calls `command.run()` and asserts the forward effect. A Dart port must NOT introduce undo to satisfy that name.
6. `commands.no-undo-redo#6` — A Flutter port should therefore implement commands as fire-and-forget mutations; adding undo would be a new feature, not a port.

#### commands.command-runner-run

- [x] `commands.command-runner-run` — CommandRunner.run dispatch
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CommandRunner.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/AppScope.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/tasks/CoroutineTaskRunnerTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HabitCardListCacheTest.kt`
- **Notes:** In Dart the natural equivalent is an async method plus a broadcast stream; the background/main split must be preserved so that mutation happens off the UI isolate/microtask and notification happens after it completes.

1. `commands.command-runner-run#1` — CommandRunner is constructed with a single dependency: a TaskRunner. It is annotated @AppScope, i.e. exactly one instance exists for the whole application.
2. `commands.command-runner-run#2` — `run(command)` never calls `command.run()` directly on the caller's thread. It builds an anonymous Task whose `doInBackground()` calls `command.run()` and whose `onPostExecute()` calls `notifyListeners(command)`, and hands that Task to `taskRunner.execute(...)`.
3. `commands.command-runner-run#3` — The observable order for a single `run(command)` is exactly: task.onAttached(runner) -> TaskRunner.Listener.onTaskStarted(task) -> task.onPreExecute() (no-op) -> command.run() on the IO dispatcher -> notifyListeners(command) on the main dispatcher -> TaskRunner.Listener.onTaskFinished(task).
4. `commands.command-runner-run#4` — `run()` returns immediately (void); callers get no completion callback, no future, and no result. UI code that must react has to register a CommandRunner.Listener.
5. `commands.command-runner-run#5` — The exact same command instance that was passed to `run()` is the instance handed to every listener in `onCommandFinished`.
6. `commands.command-runner-run#6` — If `command.run()` throws, `onPostExecute()` is never reached, so NO listener is notified and the UI is left stale; the exception escapes into the coroutine scope's uncaught-exception path (on Android it reaches Thread's default uncaught handler).
7. `commands.command-runner-run#7` — CommandRunner does not deduplicate, coalesce, batch, queue, or serialize commands; two `run()` calls made in quick succession are two independent tasks that may interleave.
8. `commands.command-runner-run#8` — `CommandRunner`, `run`, `addListener`, `removeListener`, and `notifyListeners` are all `open` so tests may subclass and stub them; `notifyListeners(command)` is public and can be invoked directly to simulate a finished command without executing it.

#### commands.command-runner-listeners

- [ ] `commands.command-runner-listeners` — CommandRunner listener registry
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CommandRunner.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HabitCardListAdapter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HabitCardListCacheTest.kt`

1. `commands.command-runner-listeners#1` — Listeners are held in an insertion-ordered mutable list. `notifyListeners(command)` iterates that list front-to-back and calls `onCommandFinished(command)` on each; there is no priority, no filtering, and no way for a listener to stop propagation.
2. `commands.command-runner-listeners#2` — Every listener is notified for EVERY command type; filtering by command class happens inside each listener, not in the runner.
3. `commands.command-runner-listeners#3` — `addListener(l)` appends without a duplicate check: registering the same listener twice makes it receive each command twice.
4. `commands.command-runner-listeners#4` — `removeListener(l)` removes the first matching element (list `remove`), and removing a listener that was never added is a silent no-op.
5. `commands.command-runner-listeners#5` — The CommandRunner.Listener interface has exactly one method: `fun onCommandFinished(command: Command)`.
6. `commands.command-runner-listeners#6` — At app startup (HabitsApplication.onCreate) listeners register in this order: WidgetUpdater, then ReminderScheduler, then NotificationTray. Screen-level listeners (ListHabitsScreen, ShowHabitActivity, HistoryEditorDialog) register later in Activity/Fragment onResume and unregister in onPause, so they are always notified after the three app-scoped listeners.
7. `commands.command-runner-listeners#7` — HabitCardListCache registers via `onAttached()` (called from HabitCardListAdapter.onAttached) and unregisters via `onDetached()`.
8. `commands.command-runner-listeners#8` — On app terminate the order is reminderScheduler.stopListening(), widgetUpdater.stopListening(), notificationTray.stopListening().

#### commands.task-runner-contract

- [x] `commands.task-runner-contract` — TaskRunner contract behind CommandRunner
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/Task.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/TaskRunner.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/CoroutineTaskRunner.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/tasks/CoroutineTaskRunnerTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/BaseUnitTest.kt`
- **Notes:** Dart has no separate main/IO dispatcher by default; the synchronous-in-tests property is what makes existing tests pass and should be replicated (e.g. an injectable runner that can execute inline).

1. `commands.task-runner-contract#1` — TaskRunner exposes: addListener(Listener), removeListener(Listener), execute(Task), publishProgress(Task, Int), `val activeTaskCount: Int`, and `suspend fun await()`.
2. `commands.task-runner-contract#2` — Task has: `cancel()` (default no-op), `isCanceled()` (default false), `suspend fun doInBackground()` (the only abstract member), `onAttached(runner)`, `onPostExecute()`, `onPreExecute()`, `onProgressUpdate(currentPosition: Int)` — all defaulted to no-ops except doInBackground.
3. `commands.task-runner-contract#3` — CoroutineTaskRunner is created with a mainDispatcher and an ioDispatcher and owns a CoroutineScope(SupervisorJob() + mainDispatcher).
4. `commands.task-runner-contract#4` — CoroutineTaskRunner.execute(task) runs, in order: task.onAttached(this); then launches on the main dispatcher: activeCount++, each TaskRunner listener's onTaskStarted(task), task.onPreExecute(), and if `!task.isCanceled()` it switches to the io dispatcher for task.doInBackground(); back on main it calls task.onPostExecute(), activeCount--, and each listener's onTaskFinished(task).
5. `commands.task-runner-contract#5` — If `task.isCanceled()` returns true before the background step, doInBackground is skipped but onPostExecute is STILL called — so a cancelled command task would still notify command listeners (CommandRunner never cancels its tasks, so this path is unreachable for commands).
6. `commands.task-runner-contract#6` — Each launched Job is added to an internal `jobs` list and removed on completion; `await()` joins all outstanding jobs then clears the list. Tests use `(taskRunner as CoroutineTaskRunner).await()`.
7. `commands.task-runner-contract#7` — In unit tests both dispatchers are UnconfinedTestDispatcher, which makes `commandRunner.run(cmd)` behave synchronously: by the time `run()` returns, the command has executed and listeners have been notified.

#### commands.create-habit

- [x] `commands.create-habit` — CreateHabitCommand
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CreateHabitCommand.kt`, `.../models/ModelFactory.kt`, `.../models/Habit.kt`, `.../models/memory/MemoryHabitList.kt`, `.../models/sqlite/SQLiteHabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/CreateHabitCommandTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/performance/PerformanceTest.kt`
- **Notes:** MemoryHabitList's `id = list.size` assignment can produce duplicate ids after deletions; SQLite ids come from the DB so this quirk only shows in the in-memory/test implementation.

1. `commands.create-habit#1` — Constructor: `CreateHabitCommand(modelFactory: ModelFactory, habitList: HabitList, model: Habit)`; component order for destructuring is modelFactory, habitList, model.
2. `commands.create-habit#2` — `run()` performs exactly four steps in order: (1) `val habit = modelFactory.buildHabit()`, (2) `habit.copyFrom(model)`, (3) `habitList.add(habit)`, (4) `habit.recompute()`.
3. `commands.create-habit#3` — The command inserts a NEW Habit object built by the factory; the `model` argument is only a template and is never itself added to the list, so mutating `model` afterwards does not affect the stored habit.
4. `commands.create-habit#4` — `ModelFactory.buildHabit()` produces a Habit with defaults: color = PaletteColor(8), description = "", frequency = Frequency.DAILY, id = null, isArchived = false, name = "", position = 0, question = "", reminder = null, targetType = NumericalHabitType.AT_LEAST, targetValue = 0.0, type = HabitType.YES_NO, unit = "", plus fresh empty computedEntries/originalEntries/scores/streaks; if uuid is null the Habit init block sets it to `Uuid.random().toHexString()` (32 lowercase hex chars).
5. `commands.create-habit#5` — `Habit.copyFrom(other)` copies color, description, frequency, isArchived, name, position, question, reminder, targetType, targetValue, type, unit and uuid. It explicitly does NOT copy `id`, and it does NOT copy any entries, scores or streaks.
6. `commands.create-habit#6` — Because copyFrom copies uuid, the created habit inherits the template's uuid (used by the importer to preserve identity across imports); if the template's uuid was null the factory-generated random uuid is overwritten by null only when model.uuid is null — in practice callers pass a habit built by the factory, so uuid is always non-null.
7. `commands.create-habit#7` — The created habit's `originalEntries` is empty: entries present on `model` are NOT imported by this command. Callers that need entries (LoopDBImporter) add them afterwards.
8. `commands.create-habit#8` — MemoryHabitList.add: throws IllegalArgumentException("habit already added") if the list already contains an equal habit; throws RuntimeException("duplicate id") if habit.id != null and another habit with that id exists; if habit.id == null it assigns `id = list.size.toLong()`; then appends and calls resort(), which sorts and fires the list observable.
9. `commands.create-habit#9` — SQLiteHabitList.add: loads records if needed, requires indexOf(habit) < 0, then OVERWRITES habit.position with the current `size()` (so the copied position is discarded), inserts the row and assigns the returned rowid to habit.id, sets the SQLiteEntryList's habitId, adds to the in-memory list, and fires the list observable.
10. `commands.create-habit#10` — After `run()`, `habitList.size()` has grown by exactly 1 and `habitList.getByPosition(0).name` equals `model.name` when the list was previously empty.
11. `commands.create-habit#11` — `habit.recompute()` runs after insertion, so scores and streaks exist (all zero for a habit with no entries) before any listener is notified.

#### commands.edit-habit

- [ ] `commands.edit-habit` — EditHabitCommand
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/EditHabitCommand.kt`, `.../models/HabitNotFoundException.kt`, `.../models/Habit.kt`, `.../models/sqlite/SQLiteHabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/EditHabitCommandTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`
- **Notes:** EditHabitCommand is the only command that can throw a domain exception.

1. `commands.edit-habit#1` — Constructor: `EditHabitCommand(habitList: HabitList, habitId: Long, modified: Habit)`; component order is habitList, habitId, modified.
2. `commands.edit-habit#2` — `run()` performs exactly six steps in order: (1) `val habit = habitList.getById(habitId)`, (2) if null throw `HabitNotFoundException` (a subclass of RuntimeException with no message), (3) `habit.copyFrom(modified)`, (4) `habitList.update(habit)`, (5) `habit.observable.notifyListeners()`, (6) `habit.recompute()`, (7) `habitList.resort()`.
3. `commands.edit-habit#3` — The command edits the EXISTING habit instance in place; the `modified` habit is only a value carrier and is never inserted into the list.
4. `commands.edit-habit#4` — Because copyFrom does not copy `id`, the edited habit keeps its original id; because copyFrom DOES copy `position` and `uuid`, whatever position/uuid the `modified` object carries overwrite the stored ones — callers therefore build `modified` by first doing `modified.copyFrom(original)`.
5. `commands.edit-habit#5` — Entries are untouched: originalEntries survive the edit. EditHabitCommandTest asserts that `habit.scores[today].value` is unchanged after renaming a habit whose frequency is unchanged.
6. `commands.edit-habit#6` — Changing frequency, type, targetType or targetValue takes effect through step (6): `recompute()` rebuilds computedEntries from originalEntries and then recomputes scores and streaks.
7. `commands.edit-habit#7` — The habit's own ModelObservable is notified BEFORE recompute, and the list is re-sorted AFTER recompute, so score-based orderings (BY_SCORE_ASC/DESC) see the fresh scores.
8. `commands.edit-habit#8` — `habitList.update(habit)` delegates to `update(listOf(habit))`. SQLiteHabitList.update resorts the in-memory list (firing the inner observable), writes one UPDATE row per habit, then fires the outer observable — so a single EditHabitCommand fires the list observable at least three times (update, update-inner, resort).
9. `commands.edit-habit#9` — Throwing HabitNotFoundException inside `run()` means CommandRunner never reaches onPostExecute, so no listener is notified and no toast is shown; the exception escapes the coroutine.
10. `commands.edit-habit#10` — In the Android editor, `habitId >= 0` selects EditHabitCommand and `habitId < 0` selects CreateHabitCommand.

#### commands.delete-habits

- [x] `commands.delete-habits` — DeleteHabitsCommand
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/DeleteHabitsCommand.kt`, `.../models/memory/MemoryHabitList.kt`, `.../models/sqlite/SQLiteHabitList.kt`, `.../ui/screens/habits/list/ListHabitsSelectionMenuBehavior.kt`, `.../ui/screens/habits/show/ShowHabitMenuPresenter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/DeleteHabitsCommandTest.kt`, `.../ui/screens/habits/list/HabitCardListCacheTest.kt`, `.../ui/screens/habits/list/ListHabitsSelectionMenuBehaviorTest.kt`

1. `commands.delete-habits#1` — Constructor: `DeleteHabitsCommand(habitList: HabitList, selected: List<Habit>)`; component order is habitList, selected.
2. `commands.delete-habits#2` — `run()` is exactly `for (h in selected) habitList.remove(h)` — one removal call per selected habit, in the order the list was given. There is no batching and no transaction.
3. `commands.delete-habits#3` — Deletion is permanent: no copy of the habit or of its entries is retained anywhere, so nothing can restore it.
4. `commands.delete-habits#4` — MemoryHabitList.remove(h): removes the habit from the backing list and fires the list observable; it does NOT renumber `position` of the remaining habits.
5. `commands.delete-habits#5` — SQLiteHabitList.remove(h): removes from the in-memory list, calls `h.originalEntries.clear()` which deletes every repetition row for that habit id, deletes the habit row via `repository.delete(h.id!!)`, then calls rebuildOrder() which renumbers every remaining habit's `position` to 0,1,2,... in DB order, then fires the list observable.
6. `commands.delete-habits#6` — Removing a habit that is not in the list is a silent no-op for MemoryHabitList (it still fires the observable); SQLiteHabitList would still try to clear entries and delete the row, and throws NullPointerException if `h.id` is null.
7. `commands.delete-habits#7` — Deleting 3 of 4 habits leaves size()==1 and the surviving habit at position 0 (DeleteHabitsCommandTest asserts exactly this with the survivor named "extra").
8. `commands.delete-habits#8` — An empty `selected` list makes `run()` a complete no-op, but CommandRunner still notifies all listeners afterwards.
9. `commands.delete-habits#9` — In the multi-select UI the adapter cache is optimistically updated BEFORE the command runs (`adapter.performRemove(selected)` removes the rows from the cache only, not the DB), so the row disappears instantly and the DB catches up asynchronously.
10. `commands.delete-habits#10` — In the single-habit detail screen the command is run and then `screen.close()` is called immediately, without waiting for the command to finish.

#### commands.archive-habits

- [ ] `commands.archive-habits` — ArchiveHabitsCommand
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/ArchiveHabitsCommand.kt`, `.../ui/screens/habits/list/ListHabitsSelectionMenuBehavior.kt`, `.../ui/screens/habits/show/ShowHabitMenuPresenter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/ArchiveHabitsCommandTest.kt`, `.../ui/screens/habits/list/ListHabitsSelectionMenuBehaviorTest.kt`

1. `commands.archive-habits#1` — Constructor: `ArchiveHabitsCommand(habitList: HabitList, selected: List<Habit>)`; component order is habitList, selected.
2. `commands.archive-habits#2` — `run()` is exactly: `for (h in selected) h.isArchived = true` followed by ONE call to `habitList.update(selected)`.
3. `commands.archive-habits#3` — Archiving is idempotent: running it on an already-archived habit leaves isArchived == true and still performs the update/persist.
4. `commands.archive-habits#4` — It does not touch entries, scores, streaks, colors, positions, reminders or names; it does not call recompute().
5. `commands.archive-habits#5` — The single `habitList.update(selected)` writes every selected habit's full row (SQLite `archived` column becomes 1) and triggers a resort plus list-observable notifications.
6. `commands.archive-habits#6` — An empty `selected` list still calls `habitList.update(emptyList())`, which still resorts and notifies.
7. `commands.archive-habits#7` — This command is reachable from two places: the multi-select action bar (`ListHabitsSelectionMenuBehavior.onArchiveHabits`, which passes `adapter.getSelected()` then clears the selection) and the habit detail menu (`ShowHabitMenuPresenter.onArchiveHabits`, which passes `listOf(habit)` and then shows Message.HABIT_ARCHIVED).
8. `commands.archive-habits#8` — The Archive action is enabled only when `canArchive()` is true: no selected habit is archived (vacuously true for an empty selection); on the detail screen `canArchive() == !habit.isArchived`.
9. `commands.archive-habits#9` — After it finishes, ListHabitsScreen shows the quantity string R.plurals.toast_habits_archived with quantity = command.selected.size ("Habit archived" / "Habits archived").

#### commands.unarchive-habits

- [ ] `commands.unarchive-habits` — UnarchiveHabitsCommand
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/UnarchiveHabitsCommand.kt`, `.../ui/screens/habits/list/ListHabitsSelectionMenuBehavior.kt`, `.../ui/screens/habits/show/ShowHabitMenuPresenter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/UnarchiveHabitsCommandTest.kt`, `.../ui/screens/habits/list/ListHabitsSelectionMenuBehaviorTest.kt`

1. `commands.unarchive-habits#1` — Constructor: `UnarchiveHabitsCommand(habitList: HabitList, selected: List<Habit>)`; component order is habitList, selected.
2. `commands.unarchive-habits#2` — `run()` is exactly: `for (h in selected) h.isArchived = false` followed by ONE call to `habitList.update(selected)`.
3. `commands.unarchive-habits#3` — It is the exact structural mirror of ArchiveHabitsCommand — the only difference is the boolean written — but it is NOT wired as an 'undo' of it; both are ordinary forward commands invoked by the user.
4. `commands.unarchive-habits#4` — Unarchiving is idempotent and touches nothing else on the habit.
5. `commands.unarchive-habits#5` — Reachable from `ListHabitsSelectionMenuBehavior.onUnarchiveHabits` (passes `adapter.getSelected()`, then clears the selection) and `ShowHabitMenuPresenter.onUnarchiveHabits` (passes `listOf(habit)`, then shows Message.HABIT_UNARCHIVED).
6. `commands.unarchive-habits#6` — The Unarchive action is enabled only when `canUnarchive()` is true: ALL selected habits are archived (vacuously true for an empty selection); on the detail screen `canUnarchive() == habit.isArchived`.
7. `commands.unarchive-habits#7` — After it finishes, ListHabitsScreen shows R.plurals.toast_habits_unarchived with quantity = command.selected.size ("Habit unarchived" / "Habits unarchived").

#### commands.change-habit-color

- [ ] `commands.change-habit-color` — ChangeHabitColorCommand
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/ChangeHabitColorCommand.kt`, `.../ui/screens/habits/list/ListHabitsSelectionMenuBehavior.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/ChangeHabitColorCommandTest.kt`, `.../ui/screens/habits/list/ListHabitsSelectionMenuBehaviorTest.kt`

1. `commands.change-habit-color#1` — Constructor: `ChangeHabitColorCommand(habitList: HabitList, selected: List<Habit>, newColor: PaletteColor)`; component order is habitList, selected, newColor.
2. `commands.change-habit-color#2` — `run()` is exactly: `for (h in selected) h.color = newColor` followed by ONE call to `habitList.update(selected)`.
3. `commands.change-habit-color#3` — Every selected habit ends up with the identical PaletteColor instance, regardless of its previous colour (test sets colours PaletteColor(1), PaletteColor(2), PaletteColor(3) and asserts all three become PaletteColor(0) after run()).
4. `commands.change-habit-color#4` — The default habit colour is PaletteColor(8); the picker in tests returns PaletteColor(30), proving palette indices well above 8 are valid.
5. `commands.change-habit-color#5` — It writes only the `color` column; entries, scores, streaks and archived state are untouched and recompute() is not called.
6. `commands.change-habit-color#6` — The colour picker is opened with the FIRST selected habit's colour as the default (`val (color) = adapter.getSelected()[0]` — component1 of Habit is `color`); `adapter.getSelected()` is re-read inside the picker callback, so the command applies to whatever is selected at confirmation time, and the selection is cleared afterwards.
7. `commands.change-habit-color#7` — Calling onChangeColor with an empty selection would throw IndexOutOfBoundsException at `getSelected()[0]` — the menu item is only shown while a selection exists.
8. `commands.change-habit-color#8` — After it finishes, ListHabitsScreen shows R.plurals.toast_habits_changed with quantity = command.selected.size ("Habit changed" / "Habits changed").
9. `commands.change-habit-color#9` — ReminderScheduler deliberately ignores this command (see commands.listener-reminder-scheduler).

#### commands.create-repetition

- [x] `commands.create-repetition` — CreateRepetitionCommand
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CreateRepetitionCommand.kt`, `.../models/Entry.kt`, `.../models/EntryList.kt`, `.../models/sqlite/SQLiteEntryList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/CreateRepetitionCommandTest.kt`, `.../ui/widgets/WidgetBehaviorTest.kt`, `.../ui/screens/habits/list/HabitCardListCacheTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/performance/PerformanceTest.kt`
- **Notes:** By far the highest-frequency command; every checkmark tap, widget tap and notification action goes through it.

1. `commands.create-repetition#1` — Constructor: `CreateRepetitionCommand(habitList: HabitList, habit: Habit, date: LocalDate, value: Int, notes: String)`; component order is habitList, habit, date, value, notes. Listeners rely on component2 being `habit`.
2. `commands.create-repetition#2` — `run()` performs exactly three steps in order: (1) `habit.originalEntries.add(Entry(date, value, notes))`, (2) `habit.recompute()`, (3) `habitList.resort()`.
3. `commands.create-repetition#3` — Despite the name it is an upsert, not an insert: EntryList.add stores by date in a HashMap, so an existing entry for the same date is REPLACED (value and notes both overwritten). CreateRepetitionCommandTest starts from Entry.YES_MANUAL on today and asserts the value becomes 100 after running with value=100.
4. `commands.create-repetition#4` — There is no delete-repetition command: an entry is 'removed' by writing value Entry.NO (0) or Entry.UNKNOWN (-1) for that date.
5. `commands.create-repetition#5` — For YES_NO habits the value is one of the Entry constants: UNKNOWN = -1, NO = 0, YES_AUTO = 1, YES_MANUAL = 2, SKIP = 3. For NUMERICAL habits the value is the user value in thousandths, i.e. `(userValue * 1000).roundToInt()`.
6. `commands.create-repetition#6` — The command writes to `originalEntries`, never to `computedEntries`; computedEntries is regenerated by step (2) `recompute()`, which also recomputes scores and streaks.
7. `commands.create-repetition#7` — SQLiteEntryList.add persists by first `deleteByHabitIdAndTimestamp(habitId, date.unixTime)` and then inserting EntryData(habitId, timestamp = date.unixTime, value, notes) — so at most one repetition row per (habit, date) can exist.
8. `commands.create-repetition#8` — The command does NOT call `habitList.update(...)`, so no habit row is written; only the repetitions table changes.
9. `commands.create-repetition#9` — `habitList.resort()` is called even though no habit field changed, because BY_SCORE and BY_STATUS orderings depend on today's entry value.
10. `commands.create-repetition#10` — `notes` may be the empty string and is stored verbatim; callers that only change the value pass through the existing `entry.notes` so notes are preserved.
11. `commands.create-repetition#11` — This is the only command that listeners special-case for a targeted (single-habit) refresh instead of a full refresh.

#### commands.listener-list-habits-toasts

- [ ] `commands.listener-list-habits-toasts` — Toast feedback per finished command
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `uhabits-android/src/main/res/values/strings.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Android plural resources map onto Flutter intl plurals; the quantity=1 hard-code for EditHabitCommand is deliberate and must be preserved.

1. `commands.listener-list-habits-toasts#1` — ListHabitsScreen implements CommandRunner.Listener; it subscribes in `onAttached()` (from ListHabitsActivity.onResume) and unsubscribes in `onDetached()` (onPause), so toasts appear only while the habit list screen is in the foreground.
2. `commands.listener-list-habits-toasts#2` — `onCommandFinished(command)` computes `getExecuteString(command)` and, if non-null, shows it as a message/toast; a null result means no feedback at all.
3. `commands.listener-list-habits-toasts#3` — Mapping (all strings from uhabits-android/src/main/res/values/strings.xml): ArchiveHabitsCommand -> R.plurals.toast_habits_archived with quantity = command.selected.size ("Habit archived"/"Habits archived"); ChangeHabitColorCommand -> R.plurals.toast_habits_changed with quantity = command.selected.size ("Habit changed"/"Habits changed"); CreateHabitCommand -> R.string.toast_habit_created ("Habit created"); DeleteHabitsCommand -> R.plurals.toast_habits_deleted with quantity = command.selected.size ("Habit deleted"/"Habits deleted"); EditHabitCommand -> R.plurals.toast_habits_changed with quantity hard-coded to 1 ("Habit changed"); UnarchiveHabitsCommand -> R.plurals.toast_habits_unarchived with quantity = command.selected.size ("Habit unarchived"/"Habits unarchived").
4. `commands.listener-list-habits-toasts#4` — CreateRepetitionCommand falls into the `else -> return null` branch: ticking a checkmark never produces a toast.
5. `commands.listener-list-habits-toasts#5` — None of these toasts carries an action button; there is no 'UNDO' affordance on any of them.
6. `commands.listener-list-habits-toasts#6` — The habit detail screen shows its own messages instead, via ShowHabitMenuPresenter.Message.HABIT_ARCHIVED and HABIT_UNARCHIVED, emitted synchronously by the presenter rather than from the command listener.

#### commands.listener-screen-refresh

- [ ] `commands.listener-screen-refresh` — Detail screen and history dialog refresh on any command
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/HistoryEditorDialog.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabit.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `commands.listener-screen-refresh#1` — ShowHabitActivity implements CommandRunner.Listener: it registers in onResume, unregisters in onPause, and its `onCommandFinished(command)` calls `screen.refresh()` for EVERY command type without inspecting the command.
2. `commands.listener-screen-refresh#2` — `screen.refresh()` rebuilds the whole ShowHabitPresenter state (streaks, scores, frequency, history, bar cards) from the current habit and re-renders.
3. `commands.listener-screen-refresh#3` — HistoryEditorDialog also implements CommandRunner.Listener: it registers in onResume, unregisters in onPause, and its `onCommandFinished(command)` calls `refreshData()` for every command type, rebuilding the history chart series, defaultSquare and notesIndicators via HistoryCardPresenter.buildState and then invalidating the view.
4. `commands.listener-screen-refresh#4` — Because both are active simultaneously while the history editor is open over the detail screen, a single CreateRepetitionCommand refreshes both.
5. `commands.listener-screen-refresh#5` — Neither listener filters by habit: a command touching a different habit still triggers a full refresh of the visible one.

#### commands.dispatch-show-habit-menu

- [x] `commands.dispatch-show-habit-menu` — Habit detail menu dispatches commands
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenterTest.kt`
- **Notes:** onRandomize is a debug/demo affordance that mutates state outside the command layer — worth porting as-is including the missing notification.

1. `commands.dispatch-show-habit-menu#1` — `ShowHabitMenuPresenter` is constructed with (commandRunner, habit, habitList, screen, system, taskRunner) and always wraps the single habit in `listOf(habit)`.
2. `commands.dispatch-show-habit-menu#2` — `onArchiveHabits()`: runs `ArchiveHabitsCommand(habitList, listOf(habit))` and then immediately calls `screen.showMessage(Message.HABIT_ARCHIVED)` — the message is shown synchronously at dispatch time, not when the command finishes.
3. `commands.dispatch-show-habit-menu#3` — `onUnarchiveHabits()`: runs `UnarchiveHabitsCommand(habitList, listOf(habit))` then `screen.showMessage(Message.HABIT_UNARCHIVED)`.
4. `commands.dispatch-show-habit-menu#4` — `onDeleteHabit()`: calls `screen.showDeleteConfirmationScreen { ... }` and only on confirmation runs `DeleteHabitsCommand(habitList, listOf(habit))` and then `screen.close()` without waiting for completion.
5. `commands.dispatch-show-habit-menu#5` — `onEditHabit()` dispatches no command; it opens the editor via `screen.showEditHabitScreen(habit)`.
6. `commands.dispatch-show-habit-menu#6` — `onExportCSV()` dispatches no command; it runs an ExportCSVTask directly on the TaskRunner and reports either `screen.showSendFileScreen(filename)` or `Message.COULD_NOT_EXPORT`.
7. `commands.dispatch-show-habit-menu#7` — `onRandomize()` deliberately BYPASSES the command layer: it clears `habit.originalEntries`, generates 365*5 = 1825 days of pseudo-random entries walking backwards from today (re-rolling a Gaussian strength every 7 days, clamped to 0..100, skipping a day when `Random.nextInt(100) > strength`, using YES_MANUAL for boolean habits and `((1000 + 250*gaussian*strength/100).toInt() * 1000)` for numerical ones), calls `habit.recompute()` and `screen.refresh()` — no CommandRunner listener is ever notified, so widgets, reminders and the list cache do not update.
8. `commands.dispatch-show-habit-menu#8` — `ShowHabitMenuPresenter.Message` has exactly three values: COULD_NOT_EXPORT, HABIT_ARCHIVED, HABIT_UNARCHIVED.

#### commands.direct-run-bypass

- [ ] `commands.direct-run-bypass` — Commands executed directly, bypassing CommandRunner
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/LoopDBImporter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/performance/PerformanceTest.kt`
- **Notes:** A Dart port must keep the mutation logic callable without the dispatcher so bulk import stays cheap and silent.

1. `commands.direct-run-bypass#1` — `Command.run()` can be and is called directly, bypassing CommandRunner entirely; when that happens NO listener is notified (no widget refresh, no reminder rescheduling, no toast, no list-cache refresh).
2. `commands.direct-run-bypass#2` — LoopDBImporter does exactly this: for each imported habit it looks up `habitList.getByUUID(habitData.uuid)`; if null it builds a habit from the record with `id = null` and calls `CreateHabitCommand(modelFactory, habitList, habit).run()`; otherwise it builds a `modified` habit from the record with `id = habit.id` and calls `EditHabitCommand(habitList, habit.id!!, modified).run()`.
3. `commands.direct-run-bypass#3` — LoopDBImporter is injected with a CommandRunner (`val runner: CommandRunner`) but never uses it — the field is dead.
4. `commands.direct-run-bypass#4` — After the create/edit step the importer re-fetches the habit by uuid, then copies repetitions one by one: for each row it reads timestamp/value/notes, converts with `LocalDate.fromUnixTime(timestamp)`, and calls `entries.add(Entry(date, value, notes))` ONLY when the existing entry's value or notes differ — an equal row is skipped. This bypasses CreateRepetitionCommand entirely.
5. `commands.direct-run-bypass#5` — The importer calls `habit.recompute()` once per habit after all its entries are copied, and `habitList.resort()` exactly once after all habits are processed.
6. `commands.direct-run-bypass#6` — PerformanceTest also calls `CreateHabitCommand(...).run()` and `CreateRepetitionCommand(...).run()` directly inside an explicit `db.begin()`/`db.commit()` transaction (1000 habits and 5000 repetitions, both @Ignore'd with a 5000 ms timeout), confirming direct execution is a supported usage.

#### commands.list-mutations-triggered

- [x] `commands.list-mutations-triggered` — HabitList side effects triggered by commands
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitList.kt`, `.../models/memory/MemoryHabitList.kt`, `.../models/sqlite/SQLiteHabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/ArchiveHabitsCommandTest.kt`, `.../ChangeHabitColorCommandTest.kt`, `.../DeleteHabitsCommandTest.kt`
- **Notes:** Included because every command's persistence and re-sorting behavior is defined by these HabitList methods, not by the command itself.

1. `commands.list-mutations-triggered#1` — `HabitList.update(habit)` is a convenience that delegates to `update(listOf(habit))`.
2. `commands.list-mutations-triggered#2` — MemoryHabitList.update(habits) ignores its argument entirely and just calls `resort()`, which sorts with the current comparator and fires the list observable.
3. `commands.list-mutations-triggered#3` — SQLiteHabitList.update(habits) does, in order: loadRecords(); `list.update(habits)` on the inner MemoryHabitList (which resorts and fires the INNER observable that filtered sublists listen to); one `repository.update(copyFrom(h))` per habit; then fires the OUTER observable. So one Archive/Unarchive/ChangeColor command produces multiple observable notifications.
4. `commands.list-mutations-triggered#4` — `HabitList.resort()` on MemoryHabitList sorts in place with the composed comparator and fires the observable; on SQLiteHabitList it resorts the inner list and then fires the outer observable.
5. `commands.list-mutations-triggered#5` — The comparator is composed from `primaryOrder` then `secondaryOrder`: if the primary comparison returns 0 (and a secondary order exists) the secondary comparator breaks the tie. Defaults are primaryOrder = BY_POSITION and secondaryOrder = BY_NAME_ASC.
6. `commands.list-mutations-triggered#6` — Order enum values are exactly: BY_NAME_ASC, BY_NAME_DESC, BY_COLOR_ASC, BY_COLOR_DESC, BY_SCORE_ASC, BY_SCORE_DESC, BY_STATUS_ASC, BY_STATUS_DESC, BY_POSITION.
7. `commands.list-mutations-triggered#7` — Filtered sublists (MemoryHabitList with a parent) throw IllegalStateException from add/remove/reorder — commands must always be given the root list.
8. `commands.list-mutations-triggered#8` — Because commands hold the HabitList reference directly, running a command on a filtered list would throw; all call sites inject the root list.

#### commands.test-harness

- [x] `commands.test-harness` — Command test harness expectations
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/BaseUnitTest.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/BaseUnitTest.kt`, `.../commands/CreateHabitCommandTest.kt`, `.../commands/CreateRepetitionCommandTest.kt`, `.../commands/EditHabitCommandTest.kt`

1. `commands.test-harness#1` — BaseUnitTest.setUp() pins today to LocalDate(2015, 1, 25) via `setToday(...)` before building anything, so command tests are deterministic.
2. `commands.test-harness#2` — It builds a MemoryModelFactory, `habitList = memoryModelFactory.buildHabitList()` (a MemoryHabitList), `fixtures = HabitFixtures(memoryModelFactory, habitList)`, `modelFactory = memoryModelFactory`, `taskRunner = CoroutineTaskRunner(UnconfinedTestDispatcher(), UnconfinedTestDispatcher())`, and `commandRunner = CommandRunner(taskRunner)`.
3. `commands.test-harness#3` — Because both dispatchers are unconfined test dispatchers, `commandRunner.run(cmd)` completes and notifies listeners before it returns, letting tests assert immediately after the call.
4. `commands.test-harness#4` — Command tests call `command.run()` directly (not through the runner) for the seven command classes; only the listener tests (HabitCardListCacheTest) go through `commandRunner.run(...)`.
5. `commands.test-harness#5` — A Dart port should provide the same two knobs: a fixed 'today' and an inline/synchronous task runner.

## Domain: SQLite persistence, schema and migrations

#### persistence.schema-habits

- [x] `persistence.schema-habits` — Habits table schema at version 25
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/09.sql`, `11.sql`, `16.sql`, `18.sql`, `23.sql`, `24.sql`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/HabitRepository.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/HabitRepositoryTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/MigrationTest.kt`
- **Notes:** Verified against the real schema of uhabits-core/assets/test/databases/021.db and 022.db plus migrations 23/24/25.

1. `persistence.schema-habits#1` — The final (user_version = 25) schema of table `Habits` has exactly 18 columns, in this physical order: id, archived, color, description, freq_den, freq_num, highlight, name, position, reminder_hour, reminder_min, reminder_days, type, target_type, target_value, unit, question, uuid.
2. `persistence.schema-habits#2` — `id` is `integer primary key autoincrement`; with AUTOINCREMENT SQLite keeps a `sqlite_sequence` row and never reuses a deleted id. First inserted habit gets id = 1.
3. `persistence.schema-habits#3` — Columns created in migration 09 are all nullable with no default: archived integer, color integer, description text, freq_den integer, freq_num integer, highlight integer, name text, position integer, reminder_hour integer, reminder_min integer.
4. `persistence.schema-habits#4` — `reminder_days integer not null default 127` (added by migration 11). 127 = 0b1111111 = all seven weekdays enabled.
5. `persistence.schema-habits#5` — `type integer not null default 0` (migration 16). 0 = boolean habit, 1 = numerical habit.
6. `persistence.schema-habits#6` — `target_type integer not null default 0`, `target_value real not null default 0`, `unit text not null default ''` (migration 18, added in that order).
7. `persistence.schema-habits#7` — `question text` (migration 23) and `uuid text` (migration 24) are both nullable with no default.
8. `persistence.schema-habits#8` — Row-to-model mapping (SQLiteHabitList.copyTo): archived != 0 → isArchived true; color → PaletteColor(paletteIndex = color); Frequency(freq_num, freq_den); type → HabitType.fromInt; target_type → NumericalHabitType.fromInt.
9. `persistence.schema-habits#9` — A Reminder is only created when BOTH reminder_hour and reminder_min are non-NULL; it is Reminder(hour, minute, WeekdayList(reminder_days)). If either is NULL, the habit has no reminder and reminder_days is ignored.
10. `persistence.schema-habits#10` — Model-to-row mapping (SQLiteHabitList.copyFrom) always writes `highlight = 0`; the column is never read back into the model, so it is a dead column that must nonetheless exist in the schema.
11. `persistence.schema-habits#11` — When the habit has no reminder, copyFrom writes reminder_hour = NULL, reminder_min = NULL and reminder_days = 0.

#### persistence.schema-repetitions

- [x] `persistence.schema-repetitions` — Repetitions (entries) table schema at version 25
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/09.sql`, `16.sql`, `22.sql`, `25.sql`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/EntryRepository.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/EntryRepositoryTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/migrations/Version22Test.kt`

1. `persistence.schema-repetitions#1` — The final schema of table `Repetitions` is: `id integer primary key autoincrement, habit integer not null references habits(id), timestamp integer not null, value integer not null, notes text`.
2. `persistence.schema-repetitions#2` — `notes` is nullable with no default; every reader coerces NULL to the empty string "".
3. `persistence.schema-repetitions#3` — A UNIQUE index `idx_repetitions_habit_timestamp` exists on (habit, timestamp): inserting a second row with the same (habit, timestamp) pair fails with a constraint violation.
4. `persistence.schema-repetitions#4` — With `pragma foreign_keys=ON` (set by migration 22), inserting a row whose `habit` does not exist in Habits fails with a constraint violation.
5. `persistence.schema-repetitions#5` — Inserting a row with NULL `timestamp` or NULL `habit` fails with a constraint violation.
6. `persistence.schema-repetitions#6` — `timestamp` stores UTC midnight of the entry's date in epoch milliseconds: timestamp = 946684800000 + daysSince2000 * 86400000. It is time-zone independent; the reverse mapping is LocalDate.fromUnixTime, which floors toward negative infinity for pre-2000 dates: days = diff >= 0 ? diff / 86400000 : (diff - 86400000 + 1) / 86400000.
7. `persistence.schema-repetitions#7` — `value` stores Entry values: UNKNOWN = -1, NO = 0, YES_AUTO = 1, YES_MANUAL = 2, SKIP = 3. For numerical habits it stores the numeric amount multiplied by 1000 as an integer (e.g. 80000 means 80.0).
8. `persistence.schema-repetitions#8` — Only a habit's originalEntries are persisted; computedEntries (which contain YES_AUTO values derived from frequency) live in memory only and are never written to Repetitions.
9. `persistence.schema-repetitions#9` — Deleting a habit does NOT cascade in SQL — the application deletes the habit's repetitions explicitly before deleting the Habits row.

#### persistence.schema-legacy-tables

- [x] `persistence.schema-legacy-tables` — Legacy and unused tables
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/09.sql`, `19.sql`, `20.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.schema-legacy-tables#1` — Migration 09 also creates three derived-data tables that no longer exist at version 25: `Checkmarks(id, habit, timestamp, value)`, `Streak(id, end, habit, length, start)` and `Score(id, habit, score, timestamp)`.
2. `persistence.schema-legacy-tables#2` — Migration 20 executes `drop table checkmarks; drop table streak; drop table score;`. After version 20 those tables must not exist; scores, streaks and checkmarks are recomputed in memory on every app start.
3. `persistence.schema-legacy-tables#3` — Migration 19 creates `Events(id integer primary key autoincrement, timestamp integer, message text, server_id integer)`. This table still exists at version 25 and is never read or written by any application code — it must be created by the migration but has no behavior.
4. `persistence.schema-legacy-tables#4` — A version-25 database opened through Android's SQLiteOpenHelper additionally contains `android_metadata(locale TEXT)` (created by Android) and `sqlite_sequence` (created by AUTOINCREMENT). Neither is created by the migrations.

#### persistence.schema-indexes

- [x] `persistence.schema-indexes` — Index lifecycle across migrations
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/13.sql`, `17.sql`, `20.sql`, `22.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.schema-indexes#1` — Migration 13 creates four indexes: idx_score_habit_timestamp on Score(habit, timestamp); idx_checkmark_habit_timestamp on Checkmarks(habit, timestamp); idx_repetitions_habit_timestamp on Repetitions(habit, timestamp) (non-unique); idx_streak_habit_end on Streak(habit, end).
2. `persistence.schema-indexes#2` — Migration 17 drops and recreates the Score table, then recreates idx_score_habit_timestamp on Score(habit, timestamp).
3. `persistence.schema-indexes#3` — Migration 20 drops Checkmarks, Streak and Score, which implicitly drops idx_checkmark_habit_timestamp, idx_streak_habit_end and idx_score_habit_timestamp.
4. `persistence.schema-indexes#4` — Migration 22 executes `drop index if exists idx_repetitions_habit_timestamp` and then `create unique index idx_repetitions_habit_timestamp on Repetitions(habit, timestamp)`.
5. `persistence.schema-indexes#5` — At version 25 the only application-created index in the database is the UNIQUE idx_repetitions_habit_timestamp on Repetitions(habit, timestamp).

#### persistence.migration-runner

- [ ] `persistence.migration-runner` — Migration runner and database versioning
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Database.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/Constants.kt`, `uhabits-android/build.gradle.kts`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/MigrationTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/DatabaseTest.kt`, `uhabits-core/src/jvmTest/java/org/isoron/platform/io/TestDatabaseHelper.kt`

1. `persistence.migration-runner#1` — DATABASE_VERSION = 25 and DATABASE_FILENAME = "uhabits.db" (org.isoron.uhabits.core.Constants).
2. `persistence.migration-runner#2` — Database.getVersion() executes `PRAGMA user_version` and reads column 0 as an Int. Database.setVersion(v) executes the literal string `PRAGMA user_version = $v` (value interpolated into the SQL, not bound).
3. `persistence.migration-runner#3` — Database.migrateTo(targetVersion, loadMigrationSQL): if getVersion() >= targetVersion it returns immediately without executing anything (idempotent).
4. `persistence.migration-runner#4` — Otherwise, for v from currentVersion + 1 up to and including targetVersion, in ascending order: load the SQL text for v, split it with SQLParser.parse, execute each resulting statement in order with Database.run, then call setVersion(v).
5. `persistence.migration-runner#5` — Because user_version is written after each individual migration completes, an interrupted upgrade resumes at the first unapplied version on the next attempt.
6. `persistence.migration-runner#6` — Migration resources are named with a zero-padded two-digit version: `%02d.sql`, loaded from the path `migrations/NN.sql` (e.g. migrations/09.sql, migrations/25.sql).
7. `persistence.migration-runner#7` — Migration files exist only for versions 09 through 25 inclusive; there is no file for versions 0–8. A brand-new database is created by stamping user_version = 8 and then migrating to 25, so migration 09 is the effective CREATE TABLE script.
8. `persistence.migration-runner#8` — Calling migrateTo(v) where v equals the current version leaves user_version unchanged and executes no SQL.
9. `persistence.migration-runner#9` — On Android the migration SQL ships as app assets: uhabits-android/build.gradle.kts adds "../uhabits-core/assets/main" as an assets source dir, so `context.assets.open("migrations/25.sql")` resolves.

#### persistence.migration-v09

- [x] `persistence.migration-v09` — Migration 09 — initial schema
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/09.sql`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/MigrationTest.kt`

1. `persistence.migration-v09#1` — Creates `Habits(id integer primary key autoincrement, archived integer, color integer, description text, freq_den integer, freq_num integer, highlight integer, name text, position integer, reminder_hour integer, reminder_min integer)` — no NOT NULL and no DEFAULT on any column.
2. `persistence.migration-v09#2` — Creates `Checkmarks(id integer primary key autoincrement, habit integer references habits(id), timestamp integer, value integer)`.
3. `persistence.migration-v09#3` — Creates `Repetitions(id integer primary key autoincrement, habit integer references habits(id), timestamp integer)` — note there is no `value` column yet.
4. `persistence.migration-v09#4` — Creates `Streak(id integer primary key autoincrement, end integer, habit integer references habits(id), length integer, start integer)`.
5. `persistence.migration-v09#5` — Creates `Score(id integer primary key autoincrement, habit integer references habits(id), score integer, timestamp integer)` — score is INTEGER at this version.
6. `persistence.migration-v09#6` — The five CREATE TABLE statements run in the order Habits, Checkmarks, Repetitions, Streak, Score.

#### persistence.migration-cache-resets

- [x] `persistence.migration-cache-resets` — Migrations 10, 12 and 15 — derived-cache resets
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/10.sql`, `12.sql`, `15.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-cache-resets#1` — Migrations 10, 12 and 15 are byte-for-byte equivalent and consist of exactly three statements in this order: `delete from Score;`, `delete from Streak;`, `delete from Checkmarks;`.
2. `persistence.migration-cache-resets#2` — They never touch Habits or Repetitions, so no user data is lost; they only force the app to recompute derived data.
3. `persistence.migration-cache-resets#3` — In a port that computes scores/streaks/checkmarks on demand, these three migrations are semantic no-ops but must still advance user_version 9→10, 11→12 and 14→15 respectively.

#### persistence.migration-v11

- [x] `persistence.migration-v11` — Migration 11 — reminder_days column
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/11.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-v11#1` — Executes exactly `alter table Habits add column reminder_days integer not null default 127`.
2. `persistence.migration-v11#2` — Every pre-existing habit row receives reminder_days = 127, i.e. a WeekdayList bitmask with all seven days enabled.

#### persistence.migration-v13

- [x] `persistence.migration-v13` — Migration 13 — create per-habit timestamp indexes
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/13.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-v13#1` — Executes four CREATE INDEX statements in this exact order: idx_score_habit_timestamp on Score(habit, timestamp); idx_checkmark_habit_timestamp on Checkmarks(habit, timestamp); idx_repetitions_habit_timestamp on Repetitions(habit, timestamp); idx_streak_habit_end on Streak(habit, end).
2. `persistence.migration-v13#2` — All four indexes are non-unique at this version.

#### persistence.migration-v14

- [x] `persistence.migration-v14` — Migration 14 — first color remap (ARGB to palette 0..12)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/14.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-v14#1` — Rewrites Habits.color from raw ARGB integers to palette indices with these exact 13 mappings, applied as separate UPDATE statements in this order: -2937041→0, -1684967→1, -415707→2, -5262293→3, -13070788→4, -16742021→5, -16732991→6, -16540699→7, -10603087→8, -7461718→9, -2614432→10, -13619152→11, -5592406→12.
2. `persistence.migration-v14#2` — The final statement is `update habits set color=0 where color<0 or color>12` — any color not in the mapping table (including already-migrated values outside 0..12) is clamped to 0.
3. `persistence.migration-v14#3` — The clamp runs last, so it does not undo any of the 13 mappings.

#### persistence.migration-v16

- [x] `persistence.migration-v16` — Migration 16 — habit type and repetition value
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/16.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-v16#1` — Executes `alter table Habits add column type integer not null default 0` — all existing habits become type 0 (boolean).
2. `persistence.migration-v16#2` — Then executes `alter table Repetitions add column value integer not null default 2` — every pre-existing repetition gets value 2 = Entry.YES_MANUAL, because before this version a row's mere existence meant a manual check.
3. `persistence.migration-v16#3` — The two statements run in that order.

#### persistence.migration-v17

- [x] `persistence.migration-v17` — Migration 17 — Score.score becomes REAL
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/17.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-v17#1` — Executes `drop table Score`, then recreates `Score(id integer primary key autoincrement, habit integer references habits(id), score real, timestamp integer)` — the score column changes from integer to real.
2. `persistence.migration-v17#2` — Then recreates `create index idx_score_habit_timestamp on Score(habit, timestamp)`.
3. `persistence.migration-v17#3` — Then executes `delete from streak;` and `delete from checkmarks;` (in that order) to force recomputation.
4. `persistence.migration-v17#4` — All existing Score rows are lost (the table is dropped, not converted).

#### persistence.migration-v18

- [x] `persistence.migration-v18` — Migration 18 — numerical target columns
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/18.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-v18#1` — Executes three ALTER TABLE statements on Habits in this order: `add column target_type integer not null default 0`, `add column target_value real not null default 0`, `add column unit text not null default ""`.
2. `persistence.migration-v18#2` — The double-quoted "" in the unit default is interpreted by SQLite as the empty-string literal, so existing rows get unit = '' (not NULL, not the literal two quote characters).
3. `persistence.migration-v18#3` — Existing habits get target_type = 0, target_value = 0.0, unit = ''.

#### persistence.migration-v19

- [x] `persistence.migration-v19` — Migration 19 — Events table
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/19.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-v19#1` — Executes exactly one statement: `create table Events (id integer primary key autoincrement, timestamp integer, message text, server_id integer)`.
2. `persistence.migration-v19#2` — No application code ever inserts into, selects from, or drops this table; it survives to version 25 as dead schema.

#### persistence.migration-v20

- [x] `persistence.migration-v20` — Migration 20 — drop derived tables
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/20.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-v20#1` — Executes exactly three statements in this order: `drop table checkmarks;`, `drop table streak;`, `drop table score;`.
2. `persistence.migration-v20#2` — After this migration the database persists only habits, repetitions and the unused Events table; all scores, streaks and checkmarks become purely computed values.

#### persistence.migration-v21

- [x] `persistence.migration-v21` — Migration 21 — second color remap (palette 0..12 to 0..19)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/21.sql`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-v21#1` — Rewrites Habits.color with these 11 mappings applied as separate UPDATE statements in exactly this descending-source order: 12→19, 11→17, 10→15, 9→14, 8→13, 7→10, 6→9, 5→8, 4→7, 3→5, 2→4.
2. `persistence.migration-v21#2` — Colors 0 and 1 are left unchanged (no statement touches them).
3. `persistence.migration-v21#3` — The descending order is load-bearing: it guarantees no value is remapped twice (e.g. 10→15 executes before 7→10 creates new 10s).
4. `persistence.migration-v21#4` — The final statement `update habits set color=0 where color<0 or color>19` clamps any out-of-range value to 0.
5. `persistence.migration-v21#5` — Palette indices 2, 3, 6, 11, 12, 16 and 18 are unreachable after this migration for pre-existing habits.

#### persistence.migration-v22

- [x] `persistence.migration-v22` — Migration 22 — Repetitions cleanup and constraint rebuild
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/assets/main/migrations/22.sql`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/migrations/Version22Test.kt`
- **Notes:** Test fixture uhabits-core/assets/test/databases/021.db (user_version 21) is the input for Version22Test.

1. `persistence.migration-v22#1` — Four DELETE statements run BEFORE the transaction, in this exact order: (1) `delete from repetitions where habit not in (select id from habits)`; (2) `delete from repetitions where timestamp is null`; (3) `delete from repetitions where habit is null`; (4) `delete from repetitions where rowid not in (select min(rowid) from repetitions group by habit, timestamp)`.
2. `persistence.migration-v22#2` — Deduplication keeps the row with the SMALLEST rowid for each (habit, timestamp) group — i.e. the first-inserted value wins and later duplicates are discarded, regardless of their value.
3. `persistence.migration-v22#3` — Then, inside `begin transaction` / `commit`, in order: `alter table Repetitions rename to RepetitionsBak`; `create table Repetitions(id integer primary key autoincrement, habit integer not null references habits(id), timestamp integer not null, value integer not null)`; `drop index if exists idx_repetitions_habit_timestamp`; `create unique index idx_repetitions_habit_timestamp on Repetitions(habit, timestamp)`; `insert into Repetitions select * from RepetitionsBak`; `drop table RepetitionsBak`.
4. `persistence.migration-v22#4` — The copy is positional (`select *`), so it relies on the old table's column order being exactly id, habit, timestamp, value.
5. `persistence.migration-v22#5` — The new `value` column is `not null` with NO default (the old one had `default 2`).
6. `persistence.migration-v22#6` — The last statement is `pragma foreign_keys=ON`, which is a per-connection setting; the port must ensure foreign key enforcement is enabled on every connection, not just during migration.
7. `persistence.migration-v22#7` — After migrating, an insert of `(habit=99999, timestamp=100, value=2)` fails with an error whose message contains "constraint".
8. `persistence.migration-v22#8` — After migrating, an insert with a missing timestamp, a missing habit, or a duplicate (habit, timestamp) each fail with an error whose message contains "constraint".
9. `persistence.migration-v22#9` — Repetitions rows referencing an existing habit with a non-null timestamp survive the migration unchanged (3 valid rows in, 3 rows out).

#### persistence.migration-v23

- [x] `persistence.migration-v23` — Migration 23 — description split into question
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/23.sql`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/migrations/Version23Test.kt`
- **Notes:** Test fixture uhabits-core/assets/test/databases/022.db (user_version 22) is the input for Version23Test.

1. `persistence.migration-v23#1` — Executes three statements in this order: `alter table Habits add column question text;`, `update Habits set question = description;`, `update Habits set description = "";`.
2. `persistence.migration-v23#2` — After migration, every habit's `question` equals its previous `description` value (including NULL if it was NULL).
3. `persistence.migration-v23#3` — After migration, every habit's `description` is the empty string "" — SQLite parses the double-quoted "" as an empty-string literal, so the value is '' and not NULL and not the two-character string `""`.
4. `persistence.migration-v23#4` — Selecting the `question` column after migration must succeed on every row.

#### persistence.migration-v24

- [x] `persistence.migration-v24` — Migration 24 — uuid backfill
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/24.sql`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/HabitRepository.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.migration-v24#1` — Executes two statements: `alter table habits add column uuid text;` then `update habits set uuid = lower(hex(randomblob(16) || id));`.
2. `persistence.migration-v24#2` — The generated uuid is lowercase hexadecimal with NO dashes; it is not an RFC-4122 UUID.
3. `persistence.migration-v24#3` — Because 16 random bytes are concatenated with the decimal text of the id, the length is 32 + 2 * (number of digits in id) characters — a habit with id 7 gets a 34-character uuid, a habit with id 42 gets 36 characters.
4. `persistence.migration-v24#4` — The uuid is unique per row in practice (16 random bytes plus the unique id) but there is no UNIQUE constraint on the column.
5. `persistence.migration-v24#5` — Rows inserted after this migration do not get a uuid from SQL: HabitRepository binds whatever HabitData.uuid holds, and binds SQL NULL when it is null.

#### persistence.migration-v25

- [x] `persistence.migration-v25` — Migration 25 — repetition notes
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/assets/main/migrations/25.sql`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/EntryRepository.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/EntryRepositoryTest.kt`

1. `persistence.migration-v25#1` — Executes exactly `alter table Repetitions add column notes text`.
2. `persistence.migration-v25#2` — The column is nullable with no default, so every pre-existing repetition has notes = NULL.
3. `persistence.migration-v25#3` — EntryRepository.findAllByHabitId converts a NULL notes column to the empty string "" when building EntryData; LoopDBImporter does the same.
4. `persistence.migration-v25#4` — 25 is the highest migration; DATABASE_VERSION must equal 25 after this file runs.

#### persistence.sql-parser

- [x] `persistence.sql-parser` — SQL script parser
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/SQLParser.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/SQLParserTest.kt`
- **Notes:** Merged duplicate id: `io.sql-parser`.

1. `persistence.sql-parser#1` — SQLParser.parse(input) returns a List<String> of statements, splitting on top-level `;` characters; each statement is trimmed and empty statements are dropped.
2. `persistence.sql-parser#2` — `parse("create table t(a int); insert into t values(1);")` returns exactly ["create table t(a int)", "insert into t values(1)"] — the trailing semicolons are removed.
3. `persistence.sql-parser#3` — `--` outside a string starts a line comment; all characters up to and including the next `\r` or `\n` are discarded.
4. `persistence.sql-parser#4` — `/*` outside a string starts a block comment terminated by the first `*/`; nesting is not supported, and the comment content is discarded entirely.
5. `persistence.sql-parser#5` — A single quote `'` toggles string mode. Inside a string, `;`, `--` and `/*` are literal text. `parse("insert into t values('hello; world');")` returns exactly one command: "insert into t values('hello; world')".
6. `persistence.sql-parser#6` — Outside strings, each run of whitespace (`\r`, `\n`, `\t`, space) is collapsed to a single space, and a space is appended only when the buffer is non-empty and does not already end in a space — so statements never start with a space and never contain double spaces.
7. `persistence.sql-parser#7` — Whitespace inside a quoted string is preserved verbatim.
8. `persistence.sql-parser#8` — Any non-blank text after the final `;` is emitted as an additional command.
9. `persistence.sql-parser#9` — parse(""), parse("  \n  ") and parse("-- just a comment") all return an empty list (size 0).
10. `persistence.sql-parser#10` — A script mixing a leading line comment and a block comment between two statements still yields exactly 2 commands.
11. `persistence.sql-parser#11` — SQLParser.parse(input) splits a SQL script into a List<String> of statements on ';' at top level.
12. `persistence.sql-parser#12` — Line comments start with '--' and run to the next '\r' or '\n'; block comments start with '/*' and run to the next '*/'; both are removed entirely.
13. `persistence.sql-parser#13` — A ';' inside a single-quoted string does NOT split the statement: parse("insert into t values('hello; world');") yields exactly one command, "insert into t values('hello; world')".
14. `persistence.sql-parser#14` — Outside strings, runs of whitespace ('\r', '\n', '\t', ' ') are collapsed into a single space, and each command is trimmed.
15. `persistence.sql-parser#15` — Empty commands are dropped: parse(''), parse('  \n  ') and parse('-- just a comment') all return an empty list.
16. `persistence.sql-parser#16` — Text after the last ';' is emitted as a final command when it is non-empty after trimming.
17. `persistence.sql-parser#17` — parse('create table t(a int); insert into t values(1);') returns ['create table t(a int)', 'insert into t values(1)'].

#### persistence.database-abstraction

- [x] `persistence.database-abstraction` — Database / PreparedStatement abstraction and query helpers
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Database.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/database/AndroidDatabaseOpener.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/DatabaseTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/DatabaseQueryHelpersTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/database/AndroidDatabaseTest.kt`
- **Notes:** Merged duplicate id: `io.database-query-helpers`.

1. `persistence.database-abstraction#1` — Column getters are 0-indexed: getInt(0) reads the first selected column. Bind parameters are 1-indexed: bindInt(1, v) binds the first `?`.
2. `persistence.database-abstraction#2` — step() returns StepResult.ROW while rows remain and StepResult.DONE afterwards; a non-SELECT statement executes and returns DONE.
3. `persistence.database-abstraction#3` — getIntOrNull / getLongOrNull / getRealOrNull / getTextOrNull return null exactly when the column value is SQL NULL; the non-null variants return the driver's coerced value.
4. `persistence.database-abstraction#4` — reset() rewinds the statement and clears all bindings so it can be re-bound and re-stepped; a statement bound 10, reset, bound 20, reset, bound 30 inserts three rows with values 10, 20 and 30.
5. `persistence.database-abstraction#5` — finalize() releases the statement and any open cursor.
6. `persistence.database-abstraction#6` — Database.run(sql) prepares the statement, calls step() exactly ONCE, then finalizes — it does not drain multi-row results.
7. `persistence.database-abstraction#7` — Database.run(sql) { bindInt(1, 99) } prepares, applies the binding lambda, steps once, finalizes.
8. `persistence.database-abstraction#8` — Database.queryInt(sql) and Database.queryLong(sql) prepare, step once, read column 0 as Int/Long, finalize.
9. `persistence.database-abstraction#9` — Database.query(sql, vararg params) { block } binds each vararg param as TEXT at index i+1, then invokes block once per row until DONE, then finalizes. With zero rows, the block is never called.
10. `persistence.database-abstraction#10` — Database.querySingle(sql, vararg params) { block } binds params as TEXT, steps once, returns block(stmt) when a row exists and null when the result set is empty, then finalizes. Given rows 42 and 99 ordered ascending, it returns 42.
11. `persistence.database-abstraction#11` — Nested queries are supported: a query's per-row block may open and drain another query on the same Database instance.
12. `persistence.database-abstraction#12` — Database.begin() runs the literal "BEGIN" and Database.commit() runs the literal "COMMIT".
13. `persistence.database-abstraction#13` — `select last_insert_rowid()` via queryLong is the mechanism used to obtain generated ids, and returns strictly increasing values for successive inserts into an AUTOINCREMENT table.
14. `persistence.database-abstraction#14` — Database exposes only prepareStatement(sql) and close(); everything else is an extension function.
15. `persistence.database-abstraction#15` — query(sql, vararg params) { block } binds each param as TEXT at index i+1 (1-based), steps until StepResult.DONE, invoking block for every ROW, then finalizes the statement; a query with no rows never invokes the block.
16. `persistence.database-abstraction#16` — querySingle(sql, vararg params) { block } binds params the same way and returns block(stmt) for the first row, or null when there are no rows.
17. `persistence.database-abstraction#17` — run(sql) prepares, steps once and finalizes; begin() runs 'BEGIN'; commit() runs 'COMMIT'.
18. `persistence.database-abstraction#18` — getVersion() = queryInt('PRAGMA user_version'); setVersion(v) runs 'PRAGMA user_version = <v>'.
19. `persistence.database-abstraction#19` — PreparedStatement provides both throwing getters (getInt/getLong/getReal/getText) and nullable getters (getIntOrNull/getLongOrNull/getRealOrNull/getTextOrNull); the importers use the nullable variants for optional columns.
20. `persistence.database-abstraction#20` — On Android, DatabaseOpener.open(path) calls SQLiteDatabase.openDatabase(path, null, OPEN_READWRITE) — the imported file must be writable, since migrations are applied to it.

#### persistence.habit-repository

- [x] `persistence.habit-repository` — HabitRepository query semantics
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/HabitRepository.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/HabitRepositoryTest.kt`

1. `persistence.habit-repository#1` — HabitData default values are: id=null, name="", description="", question="", freqNum=1, freqDen=1, color=0, position=0, reminderHour=null, reminderMin=null, reminderDays=0, highlight=0, archived=0, type=0, targetValue=0.0, targetType=0, unit="", uuid=null.
2. `persistence.habit-repository#2` — findAll() runs `SELECT id, name, description, question, freq_num, freq_den, color, position, reminder_hour, reminder_min, reminder_days, highlight, archived, type, target_value, target_type, unit, uuid FROM Habits ORDER BY position` and returns HabitData objects in that row order.
3. `persistence.habit-repository#3` — findAll() calls reset() on its cached prepared statement before stepping, so successive calls re-execute the query and observe writes made in between.
4. `persistence.habit-repository#4` — findAll() on an empty table returns an empty list.
5. `persistence.habit-repository#5` — insert(data) when data.id == null inserts the 17 non-id columns and returns `SELECT last_insert_rowid()`; the returned id is > 0.
6. `persistence.habit-repository#6` — insert(data) when data.id != null inserts 18 columns including the explicit id and returns data.id directly without querying last_insert_rowid().
7. `persistence.habit-repository#7` — update(data) runs `UPDATE Habits SET name=?, description=?, question=?, freq_num=?, freq_den=?, color=?, position=?, reminder_hour=?, reminder_min=?, reminder_days=?, highlight=?, archived=?, type=?, target_value=?, target_type=?, unit=?, uuid=? WHERE id=?` — all 17 columns are always rewritten; id is bound at parameter 18. It throws NPE when data.id is null.
8. `persistence.habit-repository#8` — delete(id) runs `DELETE FROM Habits WHERE id = ?` only; it does not delete the habit's Repetitions rows.
9. `persistence.habit-repository#9` — Binding rules: reminderHour and reminderMin bind SQL NULL when the Kotlin value is null; uuid binds SQL NULL when null; targetValue is bound as REAL; every other field is bound non-null as INTEGER or TEXT.
10. `persistence.habit-repository#10` — A full round trip through insert() + findAll() preserves every field exactly, including targetValue as a Double and uuid as a String.
11. `persistence.habit-repository#11` — execSQL(sql) runs one arbitrary statement through Database.run; execSQL(sql) { bind } binds first. This is the escape hatch used by SQLiteHabitList for bulk position shifts and bulk deletes.

#### persistence.entry-repository

- [x] `persistence.entry-repository` — EntryRepository query semantics
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/EntryRepository.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/EntryRepositoryTest.kt`

1. `persistence.entry-repository#1` — EntryData default values are: id=null, habitId=null, timestamp=0L, value=0, notes="".
2. `persistence.entry-repository#2` — findAllByHabitId(habitId) runs `SELECT id, habit, timestamp, value, notes FROM Repetitions WHERE habit = ? ORDER BY timestamp DESC` — the newest entry is element 0 and the oldest is last.
3. `persistence.entry-repository#3` — findAllByHabitId reads a NULL notes column as the empty string "".
4. `persistence.entry-repository#4` — findAllByHabitId for a habit id with no rows (including a non-existent id such as 9999) returns an empty list without error.
5. `persistence.entry-repository#5` — insert(data) runs `INSERT INTO Repetitions(habit, timestamp, value, notes) VALUES (?, ?, ?, ?)` and returns `SELECT last_insert_rowid()`. data.id is ignored (the id is always generated). data.habitId must be non-null or NPE is thrown.
6. `persistence.entry-repository#6` — deleteByHabitIdAndTimestamp(habitId, timestamp) runs `DELETE FROM Repetitions WHERE habit = ? AND timestamp = ?` and removes only the matching row(s).
7. `persistence.entry-repository#7` — deleteByHabitId(habitId) runs `DELETE FROM Repetitions WHERE habit = ?` and leaves other habits' entries untouched.
8. `persistence.entry-repository#8` — The repository never filters by value, so entries with value UNKNOWN(-1) or NO(0) are stored and returned like any other.
9. `persistence.entry-repository#9` — All statements are cached and reset() before each use, so repeated calls re-execute against current data.

#### persistence.sqlite-habit-list-cache

- [x] `persistence.sqlite-habit-list-cache` — SQLiteHabitList lazy loading, row mapping and position repair
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/memory/MemoryHabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitListTest.kt`
- **Notes:** Merged duplicate id: `models.sqlite-habit-list`.

1. `persistence.sqlite-habit-list-cache#1` — SQLiteHabitList delegates all in-memory list behavior to an internal MemoryHabitList and loads rows from SQLite lazily exactly once, guarded by a boolean `loaded` flag.
2. `persistence.sqlite-habit-list-cache#2` — loadRecords() sets loaded = true BEFORE reading from the database, so re-entrant calls made during loading do not recurse.
3. `persistence.sqlite-habit-list-cache#3` — loadRecords() first calls list.removeAll() on the in-memory list, then adds one Habit per row returned by HabitRepository.findAll() (which is ordered by position).
4. `persistence.sqlite-habit-list-cache#4` — For each loaded habit, the habit's originalEntries — always a SQLiteEntryList — has its habitId assigned to the habit's id during loading.
5. `persistence.sqlite-habit-list-cache#5` — If any loaded record's stored `position` differs from its 0-based index in the position-ordered result set, loadRecords() calls rebuildOrder() immediately after the load completes.
6. `persistence.sqlite-habit-list-cache#6` — rebuildOrder() re-reads all records with findAll() and, for each 0-based index pos, if record.position != pos, sets record.position = pos and persists it with repository.update(record). Rows whose position already matches are not written.
7. `persistence.sqlite-habit-list-cache#7` — Every one of add, getById, getByUUID, getByPosition, getFiltered, indexOf, iterator, remove, reorder, repair, size and update calls loadRecords() first.
8. `persistence.sqlite-habit-list-cache#8` — removeAll() and resort() do NOT call loadRecords().
9. `persistence.sqlite-habit-list-cache#9` — reload() only sets loaded = false; it does not clear the in-memory list. The next read re-queries the database and rebuilds the list. No production code in the repository calls reload().
10. `persistence.sqlite-habit-list-cache#10` — The cache assumes the app is the only writer of the SQLite file; there is no invalidation on external modification.
11. `persistence.sqlite-habit-list-cache#11` — All public methods are annotated @Synchronized (the setters for primaryOrder/secondaryOrder use @set:Synchronized), so the list is guarded by a single monitor.
12. `persistence.sqlite-habit-list-cache#12` — SQLiteHabitList lazily loads all habit rows on first access (loadRecords), building each Habit through the ModelFactory and setting its SQLiteEntryList.habitId.
13. `persistence.sqlite-habit-list-cache#13` — If any loaded row's position does not equal its zero-based row index, positions are rebuilt to 0..n-1 and written back.
14. `persistence.sqlite-habit-list-cache#14` — add(habit) sets habit.position = size() before insert, takes the DB-assigned id, propagates it to the entry list, adds to the in-memory list and notifies listeners. Adding an already-present habit throws IllegalArgumentException("habit already added").
15. `persistence.sqlite-habit-list-cache#15` — A habit added with an explicit id keeps that id (e.g. id 12300 is preserved in the stored row).
16. `persistence.sqlite-habit-list-cache#16` — removeAll() clears the in-memory list and executes 'delete from habits' and 'delete from repetitions'.
17. `persistence.sqlite-habit-list-cache#17` — reload() sets loaded = false so the next access re-reads everything from the database.
18. `persistence.sqlite-habit-list-cache#18` — copyFrom(habit) maps model to row: freqNum/freqDen from frequency, color = paletteIndex, reminderHour/reminderMin nullable, reminderDays = reminder?.days?.toInteger() ?: 0, highlight = 0, archived = 1/0, type = habitType.value, targetType = numericalHabitType.value.
19. `persistence.sqlite-habit-list-cache#19` — copyTo(data, habit) maps back and only creates a Reminder when reminderHour and reminderMin are both non-null.
20. `persistence.sqlite-habit-list-cache#20` — Ordering and filtering are delegated entirely to an internal MemoryHabitList, so all sort/filter rules above apply unchanged.

#### persistence.sqlite-habit-list-mutations

- [x] `persistence.sqlite-habit-list-mutations` — SQLiteHabitList write operations
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitListTest.kt`

1. `persistence.sqlite-habit-list-mutations#1` — add(habit) requires list.indexOf(habit) < 0, otherwise it throws IllegalArgumentException with message "habit already added".
2. `persistence.sqlite-habit-list-mutations#2` — add(habit) sets habit.position = size() (the current count, so the habit is appended at the end with a 0-based position) BEFORE inserting.
3. `persistence.sqlite-habit-list-mutations#3` — add(habit) inserts via HabitRepository.insert(copyFrom(habit)), assigns the returned id to habit.id and to (habit.originalEntries as SQLiteEntryList).habitId, adds to the in-memory list, then calls observable.notifyListeners().
4. `persistence.sqlite-habit-list-mutations#4` — add(habit) with habit.id pre-set to a specific value (e.g. 12300) inserts that explicit id and the habit keeps id 12300; findAll() then contains a record with that id and the habit's name.
5. `persistence.sqlite-habit-list-mutations#5` — remove(h) removes from the in-memory list, calls h.originalEntries.clear() (which deletes all of that habit's Repetitions rows), calls repository.delete(h.id!!), calls rebuildOrder(), then notifies. Afterwards indexOf(h) == -1.
6. `persistence.sqlite-habit-list-mutations#6` — After remove(), the remaining habits are renumbered to contiguous positions 0..n-1 in position order — removing the habit at position 1 of 10 moves the habit that was at position 2 to position 1.
7. `persistence.sqlite-habit-list-mutations#7` — remove() re-compacts positions even when primaryOrder is not BY_POSITION (e.g. BY_NAME_DESC).
8. `persistence.sqlite-habit-list-mutations#8` — removeAll() clears the in-memory list, then executes two raw statements `delete from habits` and `delete from repetitions` (in that order), then notifies. It does not load records first and does not reset the AUTOINCREMENT sequence.
9. `persistence.sqlite-habit-list-mutations#9` — reorder(from, to) reads fromPos = from.position and toPos = to.position BEFORE mutating, delegates to the in-memory reorder, then issues one bulk UPDATE: if toPos < fromPos it runs `update habits set position = position + 1 where position >= {toPos} and position < {fromPos}`; otherwise it runs `update habits set position = position - 1 where position > {fromPos} and position <= {toPos}`. Finally it writes the moved habit with position = toPos.
10. `persistence.sqlite-habit-list-mutations#10` — The reorder position values are string-interpolated into the SQL, not bound as parameters.
11. `persistence.sqlite-habit-list-mutations#11` — Concrete reorder example: with habits at positions 0..9, reorder(habitAtPos3, habitAtPos2) leaves the moved habit at position 2 and pushes the habit that was at position 2 to position 3.
12. `persistence.sqlite-habit-list-mutations#12` — reorder throws IllegalStateException when primaryOrder != Order.BY_POSITION (inherited from MemoryHabitList: "cannot reorder automatically sorted list").
13. `persistence.sqlite-habit-list-mutations#13` — repair() = loadRecords() + rebuildOrder() + notifyListeners(); it renumbers positions and touches nothing else. Repetitions are never modified by repair().
14. `persistence.sqlite-habit-list-mutations#14` — update(habits) refreshes the in-memory sort and then calls repository.update(copyFrom(h)) for every habit in the argument list, then notifies once.
15. `persistence.sqlite-habit-list-mutations#15` — Setting primaryOrder or secondaryOrder only updates the in-memory list and notifies listeners; the sort order is never written to SQLite by this class.
16. `persistence.sqlite-habit-list-mutations#16` — resort() re-sorts the in-memory list and notifies without loading or touching SQLite.

#### persistence.sqlite-entry-list

- [x] `persistence.sqlite-entry-list` — SQLite-backed originalEntries: caching and write-through
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteEntryList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteEntryListTest.kt`
- **Notes:** Dart port would use sqflite/drift; the lazy-load + write-through semantics must be preserved. (Merged duplicate id: `models.sqlite-entry-list`.)

1. `persistence.sqlite-entry-list#1` — SQLiteEntryList extends EntryList, holds a nullable habitId and a public isLoaded flag, and wraps a single EntryRepository shared across all habits.
2. `persistence.sqlite-entry-list#2` — Any operation performed while habitId is null throws IllegalStateException("habitId must be set").
3. `persistence.sqlite-entry-list#3` — loadRecords() runs at most once: it calls repository.findAllByHabitId(habitId) and for each record calls super.add(Entry(LocalDate.fromUnixTime(rec.timestamp), rec.value, rec.notes)), then sets isLoaded = true AFTER the loop (unlike SQLiteHabitList which sets its flag before loading).
4. `persistence.sqlite-entry-list#4` — get(date), getByInterval(from, to), getKnown() and add(entry) each call loadRecords() first.
5. `persistence.sqlite-entry-list#5` — get(date) for a date with no stored row returns Entry(date, UNKNOWN = -1, notes = "").
6. `persistence.sqlite-entry-list#6` — add(entry) performs delete-then-insert: it calls repository.deleteByHabitIdAndTimestamp(habitId, entry.date.unixTime), then repository.insert(EntryData(habitId, entry.date.unixTime, entry.value, entry.notes)), then super.add(entry). Adding a second entry for the same date leaves exactly one row in the database with the newest value and notes.
7. `persistence.sqlite-entry-list#7` — Concrete example: add(Entry(date, 150)) then add(Entry(date, 90)) leaves exactly 1 row for that habit with value 90.
8. `persistence.sqlite-entry-list#8` — clear() calls super.clear() (empties the in-memory map) and repository.deleteByHabitId(habitId!!). It throws NPE if habitId is null and it does NOT reset isLoaded.
9. `persistence.sqlite-entry-list#9` — recomputeFrom(originalEntries, frequency, isNumerical) always throws UnsupportedOperationException — only original entries are SQLite-backed; computed entries live in a plain in-memory EntryList built by SQLModelFactory.buildComputedEntries().
10. `persistence.sqlite-entry-list#10` — The timestamp written is LocalDate.unixTime = 946684800000 + daysSince2000 * 86400000, i.e. UTC midnight, independent of the device time zone.
11. `persistence.sqlite-entry-list#11` — getKnown() returns all loaded entries sorted newest-first (inherited EntryList behavior).
12. `persistence.sqlite-entry-list#12` — Any of get / getByInterval / add / getKnown triggers loadRecords() first; loadRecords throws IllegalStateException("habitId must be set") when habitId is null, otherwise it loads every row for that habit exactly once (isLoaded guards re-entry).
13. `persistence.sqlite-entry-list#13` — Each DB row is converted to Entry(LocalDate.fromUnixTime(rec.timestamp), rec.value, rec.notes).

#### persistence.model-factory

- [x] `persistence.model-factory` — SQLModelFactory wiring
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLModelFactory.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/inject/HabitsApplicationComponent.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteEntryListTest.kt`

1. `persistence.model-factory#1` — SQLModelFactory takes one Database and constructs exactly one HabitRepository and one EntryRepository, both shared by everything it builds.
2. `persistence.model-factory#2` — buildOriginalEntries() returns a new SQLiteEntryList(entryRepository) with habitId still null.
3. `persistence.model-factory#3` — buildComputedEntries() returns a plain in-memory EntryList (not SQLite-backed).
4. `persistence.model-factory#4` — buildHabitList() returns SQLiteHabitList(this).
5. `persistence.model-factory#5` — buildScoreList() and buildStreakList() return plain in-memory ScoreList / StreakList — scores and streaks are never persisted.
6. `persistence.model-factory#6` — SQLiteHabitList casts its injected ModelFactory to SQLModelFactory to reach habitRepository; constructing it with any other ModelFactory implementation throws ClassCastException.
7. `persistence.model-factory#7` — On Android the DI graph binds ModelFactory to SQLModelFactory(providedDb) and HabitList to SQLiteHabitList, both @AppScope singletons; providedDb = AndroidDatabase(DatabaseUtils.openDatabase()) is created lazily on first access, which is also when the SQLite file is first opened and migrated.

#### persistence.android-opener

- [ ] `persistence.android-opener` — Android database opener, creation, version guard and file bootstrap
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/HabitsDatabaseOpener.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/UnsupportedDatabaseVersionException.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/database/AndroidDatabaseOpener.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DatabaseUtils.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/Constants.kt`, `uhabits-android/build.gradle.kts`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/database/AndroidDatabaseTest.kt`
- **Notes:** SQLiteOpenHelper's onCreate/onUpgrade/onDowngrade lifecycle and WAL toggling have no exact Flutter equivalent; sqflite's onCreate/onUpgrade must be wired so that onCreate stamps version 8 and replays migrations 09..25. (Merged duplicate id: `platform-glue.database-bootstrap`.)

1. `persistence.android-opener#1` — HabitsDatabaseOpener extends SQLiteOpenHelper(context, databaseFilename, null, version) with version = DATABASE_VERSION = 25.
2. `persistence.android-opener#2` — onCreate(db) calls db.disableWriteAheadLogging(), sets db.version = 8, then calls onUpgrade(db, -1, 25). A brand-new database is therefore produced entirely by running migrations 09 through 25 — there is no separate CREATE script.
3. `persistence.android-opener#3` — onOpen(db) calls super.onOpen(db) then db.disableWriteAheadLogging(); WAL is never used, so the .db file is always self-contained (important for the file-copy backup).
4. `persistence.android-opener#4` — onUpgrade disables WAL, then throws UnsupportedDatabaseVersionException if db.version < 8; otherwise it wraps the SQLiteDatabase in AndroidDatabase, calls setVersion(db.version), and runs migrateTo(newVersion) loading each migration with `context.assets.open("migrations/" + "%02d.sql".format(version))`.
5. `persistence.android-opener#5` — onDowngrade always throws UnsupportedDatabaseVersionException — a database file newer than 25 is refused rather than silently downgraded.
6. `persistence.android-opener#6` — UnsupportedDatabaseVersionException is a plain RuntimeException with no message.
7. `persistence.android-opener#7` — HabitsApplication.onCreate wraps DatabaseUtils.initializeDatabase(context) in try/catch(UnsupportedDatabaseVersionException); on catch it renames the database file to `<absolutePath>.invalid` and re-initializes, so an unusable file yields a fresh empty database instead of a permanent crash loop.
8. `persistence.android-opener#8` — The database is only physically opened (and therefore only migrated) when writableDatabase is first requested, which happens lazily via the DI component's providedDb.
9. `persistence.android-opener#9` — The production database filename is DATABASE_FILENAME = "uhabits.db"; under test mode it is "test.db". The current schema version is DATABASE_VERSION = 25.
10. `persistence.android-opener#10` — DatabaseUtils.getDatabaseFile(context) returns File("<context.filesDir.path>/../databases/<filename>").
11. `persistence.android-opener#11` — DatabaseUtils.initializeDatabase(context) constructs a HabitsDatabaseOpener(context, filename, DATABASE_VERSION) and stores it in a module-level singleton; openDatabase() checkNotNull's that singleton and returns opener.writableDatabase.
12. `persistence.android-opener#12` — Migration assets come from two source dirs merged at build time: uhabits-android/src/main/assets and ../uhabits-core/assets/main.
13. `persistence.android-opener#13` — DatabaseUtils.saveDatabaseCopy(context, dir: File) writes "<dir.absolutePath>/Loop Habits Backup <yyyy-MM-dd HHmmss>.db" (Locale.US format) and returns the absolute path.
14. `persistence.android-opener#14` — DatabaseUtils.saveDatabaseCopy(context, dir: DocumentFile) creates a file with MIME "application/octet-stream" named "Loop Habits Backup <yyyy-MM-dd HHmmss>.db", throws IOException("Unable to create backup file") if creation fails, streams the DB into it, and returns file.uri.toString().

#### persistence.android-prepared-statement

- [ ] `persistence.android-prepared-statement` — AndroidDatabase PreparedStatement adapter
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/database/AndroidDatabase.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/database/AndroidDatabaseTest.kt`
- **Notes:** The NULL-becomes-empty-string quirk on the query path is a real behavioral wart; a Flutter port should decide explicitly whether to reproduce or fix it. No current query in the codebase binds NULL, so fixing it is safe.

1. `persistence.android-prepared-statement#1` — AndroidPreparedStatement classifies a statement as a query if and only if sql.trimStart().uppercase() starts with "SELECT" or "PRAGMA"; every other statement is compiled with SQLiteDatabase.compileStatement and executed with SQLiteStatement.execute().
2. `persistence.android-prepared-statement#2` — For query statements, bound values are collected in a map keyed by 1-based index and converted to a String[] on the first step(): the array length equals the maximum bound index, and any index that was never bound becomes the empty string "".
3. `persistence.android-prepared-statement#3` — bindNull(i) on a query statement stores null, which buildBindArgs converts to the empty string "" — SQL NULL cannot be expressed through the query path. bindNull on a non-query statement calls SQLiteStatement.bindNull and does produce a real NULL.
4. `persistence.android-prepared-statement#4` — For query statements, ints, longs and doubles are all bound as their toString() and passed as rawQuery selectionArgs, relying on SQLite's implicit coercion.
5. `persistence.android-prepared-statement#5` — step() on a query lazily calls db.rawQuery on the first invocation and then advances the cursor by one row, returning ROW while moveToNext() succeeds and DONE afterwards. step() on a non-query executes the compiled statement and always returns DONE.
6. `persistence.android-prepared-statement#6` — reset() closes and nulls the cursor, clears the bindings map, and calls clearBindings() on the compiled statement.
7. `persistence.android-prepared-statement#7` — finalize() closes the cursor and the compiled statement.
8. `persistence.android-prepared-statement#8` — Column getters are 0-indexed against the Cursor; the *OrNull variants check cursor.isNull(index) first.
9. `persistence.android-prepared-statement#9` — AndroidDatabase.prepareStatement returns a new AndroidPreparedStatement per call and close() closes the underlying SQLiteDatabase.
10. `persistence.android-prepared-statement#10` — Transactions are done purely through raw "BEGIN"/"COMMIT" statements, not SQLiteDatabase.beginTransaction; two inserts between begin() and commit() are both visible afterwards.

#### persistence.jvm-database

- [ ] `persistence.jvm-database` — JVM/JDBC database adapter and transaction emulation
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/jvmMain/java/org/isoron/platform/io/JavaDatabase.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/DatabaseTest.kt`, `uhabits-core/src/jvmTest/java/org/isoron/platform/io/TestDatabaseHelper.kt`

1. `persistence.jvm-database#1` — JavaDatabase.prepareStatement inspects sql.trimStart().uppercase(): if it starts with "BEGIN" it returns a no-op statement that, on step(), sets conn.autoCommit = false when transactionDepth == 0 and then increments transactionDepth.
2. `persistence.jvm-database#2` — If it starts with "COMMIT", step() decrements transactionDepth and, when it reaches 0, calls conn.commit() and restores conn.autoCommit = true. Nested BEGIN/COMMIT pairs therefore collapse into a single outermost transaction.
3. `persistence.jvm-database#3` — All other SQL becomes a real JDBC PreparedStatement wrapped in JavaPreparedStatement.
4. `persistence.jvm-database#4` — JavaPreparedStatement getters add 1 to the index (JDBC ResultSet columns are 1-based) while bind methods pass the index through unchanged (already 1-based).
5. `persistence.jvm-database#5` — getIntOrNull/getLongOrNull/getRealOrNull read the value then consult ResultSet.wasNull(); getTextOrNull relies on getString returning null.
6. `persistence.jvm-database#6` — bindNull(index) calls stmt.setNull(index, java.sql.Types.NULL).
7. `persistence.jvm-database#7` — reset() closes the result set, nulls it, and calls stmt.clearParameters(); finalize() closes the result set and the statement.
8. `persistence.jvm-database#8` — step() executes the statement on first call: if execute() returns true it takes the result set and returns ROW/DONE based on next(); otherwise it returns DONE. Subsequent calls just advance the result set.
9. `persistence.jvm-database#9` — JavaDatabaseOpener.open(path) connects to "jdbc:sqlite:$path"; the path ":memory:" yields an in-memory database, which is what the test helper uses.
10. `persistence.jvm-database#10` — The NoOpStatement used for BEGIN/COMMIT throws UnsupportedOperationException for every getter and binder; only step(), reset() and finalize() are usable.

#### persistence.js-database

- [ ] `persistence.js-database` — JS/sql.js database adapter
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/jsMain/kotlin/org/isoron/platform/io/JsDatabase.kt`, `uhabits-core/src/jsMain/kotlin/org/isoron/platform/io/JsFiles.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/DatabaseTest.kt`

1. `persistence.js-database#1` — JsDatabase wraps a sql.js Database; JsPreparedStatement builds bindings into a JS array where bindings[index - 1] corresponds to bind index `index`, and calls stmt.bind(bindings) lazily on the next step() when any binding changed.
2. `persistence.js-database#2` — step() returns StepResult.ROW when stmt.step() is true (caching stmt.get() as the current row) and DONE otherwise.
3. `persistence.js-database#3` — Getters index the current row array 0-based; the *OrNull variants return null when the JS value is null/undefined.
4. `persistence.js-database#4` — bindLong requires the value to be within -9e15..9e15 and throws IllegalArgumentException ("Long value $value exceeds JS safe integer range") otherwise, because JS numbers are doubles.
5. `persistence.js-database#5` — reset() calls stmt.reset(), clears the cached row and replaces the bindings array; finalize() calls stmt.free().
6. `persistence.js-database#6` — JsDatabaseOpener.open(path) creates a brand-new empty in-memory database when path == ":memory:" or when no JsFileStorage is configured; otherwise it reads the file bytes from JsFileStorage into a Uint8Array and opens sql.js on that byte array, erroring with "File not found in storage: $path" when absent.

#### persistence.db-file-location

- [ ] `persistence.db-file-location` — Database file location and test mode
- **Platform:** android-only · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/DatabaseUtils.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/Constants.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `persistence.db-file-location#1` — DatabaseUtils.getDatabaseFile(context) returns File("${context.filesDir.path}/../databases/$databaseFilename") — i.e. the standard Android app databases directory alongside filesDir.
2. `persistence.db-file-location#2` — databaseFilename is "uhabits.db" normally and "test.db" when HabitsApplication.isTestMode() is true.
3. `persistence.db-file-location#3` — In test mode, HabitsApplication.onCreate deletes the database file (if it exists) before initializing, so every instrumented run starts from an empty database.
4. `persistence.db-file-location#4` — DatabaseUtils.initializeDatabase(context) only constructs and stores the HabitsDatabaseOpener; it does not open or migrate the database.
5. `persistence.db-file-location#5` — DatabaseUtils.openDatabase() asserts the opener is non-null (checkNotNull) and returns opener.writableDatabase, which is what actually triggers onCreate/onUpgrade.
6. `persistence.db-file-location#6` — There is exactly one database file for the whole app; there is no per-profile or per-user separation.

#### persistence.android-backup-agent

- [ ] `persistence.android-backup-agent` — Android system backup agent
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/HabitsBackupAgent.kt`, `uhabits-android/src/main/AndroidManifest.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** BackupAgentHelper has no Flutter equivalent at all. A port either keeps a thin Android-native agent or drops system backup and relies solely on the file-copy backups. (Merged duplicate id: `platform-glue.backup-agent`.)

1. `persistence.android-backup-agent#1` — HabitsBackupAgent extends BackupAgentHelper and in onCreate registers exactly two helpers: addHelper("preferences", SharedPreferencesBackupHelper(this, "preferences")) and addHelper("database", FileBackupHelper(this, "../databases/uhabits.db")).
2. `persistence.android-backup-agent#2` — The FileBackupHelper path is relative to getFilesDir(), which is why it is prefixed with "../databases/".
3. `persistence.android-backup-agent#3` — The backed-up database filename is hard-coded to "uhabits.db"; the test-mode "test.db" file is never included.
4. `persistence.android-backup-agent#4` — The manifest declares android:allowBackup="true" and android:backupAgent=".HabitsBackupAgent", so Android cloud backup / `adb backup` captures the SharedPreferences file named "preferences" plus the raw database file.
5. `persistence.android-backup-agent#5` — There is no custom onRestore logic — the framework restores the two blobs in place; the app then opens the restored uhabits.db normally and migrates it if it is older than version 25.
6. `persistence.android-backup-agent#6` — Note the default SharedPreferences file used at runtime by PreferenceManager.getDefaultSharedPreferences is "<packageName>_preferences", not "preferences", so the preferences helper as written does not actually cover the app's live settings file.

#### persistence.loop-db-import

- [x] `persistence.loop-db-import` — Importing a Loop database file (DB-side view)
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/LoopDBImporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/utils/FileExtensions.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/utils/FileExtensionsTest.kt`

1. `persistence.loop-db-import#1` — isSQLite3File(file) returns false when the file does not exist; otherwise it reads the first 16 bytes and returns true only when the decoded string starts with "SQLite format 3".
2. `persistence.loop-db-import#2` — LoopDBImporter.canHandle(file) returns false immediately when isSQLite3File is false. Otherwise it opens the file and requires `select count(*) from SQLITE_MASTER where name='Habits' or name='Repetitions'` to equal exactly 2, logging "Cannot handle file: tables not found" and returning false otherwise.
3. `persistence.loop-db-import#3` — canHandle also returns false when the file's PRAGMA user_version is greater than DATABASE_VERSION (25), logging "Cannot handle file: incompatible version: X > 25". A file with a LOWER version is accepted.
4. `persistence.loop-db-import#4` — canHandle always closes the database, on both the accept and reject paths.
5. `persistence.loop-db-import#5` — importHabitsFromFile first migrates the imported file IN PLACE to version 25 using the bundled migration SQL (path "migrations/%02d.sql"), so importing a version-12 file replays migrations 13 through 25 including both color remappings before any row is read.
6. `persistence.loop-db-import#6` — Habits are read with the same 18-column projection as HabitRepository.findAll, `ORDER BY position`, applying these NULL fallbacks: name/description/question/unit → "", freq_num → 1, freq_den → 1, color → 0, position → 0, reminder_days → 0, highlight → 0, archived → 0, type → 0, target_type → 0, target_value → 0.0; reminder_hour/reminder_min/uuid remain nullable.
7. `persistence.loop-db-import#7` — Matching is by uuid: if habitList.getByUUID(uuid) returns null, a new habit is built, HabitData is copied with id = null, and CreateHabitCommand runs (so a fresh local id is assigned). If a habit with that uuid exists, HabitData is copied with id = the existing local id and EditHabitCommand runs.
8. `persistence.loop-db-import#8` — Entries are then read per habit with `SELECT timestamp, value, notes FROM Repetitions WHERE habit = ? ORDER BY timestamp DESC` using the SOURCE habit id (not the local id).
9. `persistence.loop-db-import#9` — A repetition row with NULL timestamp or NULL value is skipped; NULL notes become "".
10. `persistence.loop-db-import#10` — An entry is written to the target habit only when the imported value differs from the existing value OR the imported notes differ from the existing notes for that date — identical entries are not rewritten.
11. `persistence.loop-db-import#11` — After each habit's entries are merged, habit.recompute() is called; after all habits, habitList.resort() is called and the source database is closed.
12. `persistence.loop-db-import#12` — Importing uhabits-core/assets/test/loop.db (user_version 12) yields 9 habits; the habit at position 0 is named "Wake up early" with frequency 3/7, checked on 2016-03-14 and 2016-03-16 and not checked on 2016-03-17.

#### persistence.repair-db-action

- [x] `persistence.repair-db-action` — Repair database action
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`

1. `persistence.repair-db-action#1` — Settings → "Repair database" (preference key "repairDB") calls ListHabitsBehavior.onRepairDB, which runs habitList.repair() on a background task and then shows Message.DATABASE_REPAIRED.
2. `persistence.repair-db-action#2` — For SQLiteHabitList, repair() = loadRecords() + rebuildOrder() + observable.notifyListeners().
3. `persistence.repair-db-action#3` — rebuildOrder() renumbers every habit's `position` to its 0-based index in the current `ORDER BY position` result and persists only the rows whose position actually changed.
4. `persistence.repair-db-action#4` — repair() never touches the Repetitions table, never deletes anything, and never changes any habit field other than position.
5. `persistence.repair-db-action#5` — For the base HabitList (and MemoryHabitList), repair() is an empty no-op.

## Domain: Import, export and file IO

#### io.csv-archive-layout

- [x] `io.csv-archive-layout` — CSV export ZIP archive layout
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporterTest.kt`
- **Notes:** Reference expected output is checked into uhabits-core/assets/test/csv_export/ and compared entry by entry by HabitsCSVExporterTest.

1. `io.csv-archive-layout#1` — HabitsCSVExporter is constructed with two arguments: allHabits (the full HabitList) and selectedHabits (a List<Habit>); writeArchive() returns the ZIP file as a ByteArray.
2. `io.csv-archive-layout#2` — writeArchive() adds entries in this exact order: (1) 'Habits.csv', (2) for each habit h in selectedHabits, in list order, '<dir>Scores.csv' then '<dir>Checkmarks.csv' where <dir> is the habit folder name ending in '/', (3) 'Scores.csv', (4) 'Checkmarks.csv'.
3. `io.csv-archive-layout#3` — 'Habits.csv' always contains ALL habits from allHabits, even when only one habit was selected for export (e.g. export from the single-habit menu).
4. `io.csv-archive-layout#4` — The per-habit files are stored using forward-slash paths inside the ZIP (e.g. '001 Meditate/Scores.csv'); no explicit directory entries are written.
5. `io.csv-archive-layout#5` — The top-level 'Scores.csv' and 'Checkmarks.csv' contain one column per SELECTED habit (not per habit in allHabits).
6. `io.csv-archive-layout#6` — For an exporter with 2 selected habits, the archive contains exactly 7 entries: Habits.csv, Scores.csv, Checkmarks.csv, and 2 files for each of the 2 habit folders.
7. `io.csv-archive-layout#7` — If selectedHabits is empty, the archive still contains Habits.csv, Scores.csv and Checkmarks.csv; the latter two contain only the header line 'Date,' followed by a newline and no data rows.

#### io.csv-habits-file

- [x] `io.csv-habits-file` — Habits.csv content (HabitList.writeCSV)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/PaletteColor.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporterTest.kt`
- **Notes:** PaletteColor.toCsvColor() throws IndexOutOfBounds for paletteIndex outside 0..19.

1. `io.csv-habits-file#1` — The first line is exactly: 'Position,Name,Type,Question,Description,FrequencyNumerator,FrequencyDenominator,Color,Unit,Target Type,Target Value,Archived?' followed by '\n'.
2. `io.csv-habits-file#2` — One row per habit, iterating the habit list in its current display order (primary order BY_POSITION, secondary BY_NAME_ASC by default).
3. `io.csv-habits-file#3` — Column 1 'Position' = format('%03d', habitList.indexOf(habit) + 1), i.e. zero-padded to 3 digits, 1-based ('001', '002', ... '010', '100', '1000' for the 1000th).
4. `io.csv-habits-file#4` — Column 2 'Name' = habit.name verbatim (CSV-quoted only if it contains , " \n or \r).
5. `io.csv-habits-file#5` — Column 3 'Type' = the enum NAME of habit.type: 'YES_NO' or 'NUMERICAL'.
6. `io.csv-habits-file#6` — Column 4 'Question' = habit.question; column 5 'Description' = habit.description.
7. `io.csv-habits-file#7` — Columns 6 and 7 = habit.frequency numerator and denominator as plain integers (e.g. 1 and 1 for daily, 2 and 3).
8. `io.csv-habits-file#8` — Column 8 'Color' = the palette hex string for habit.color.paletteIndex, from the fixed 20-entry table: 0 #D32F2F, 1 #E64A19, 2 #F57C00, 3 #FF8F00, 4 #F9A825, 5 #AFB42B, 6 #7CB342, 7 #388E3C, 8 #00897B, 9 #00ACC1, 10 #039BE5, 11 #1976D2, 12 #303F9F, 13 #5E35B1, 14 #8E24AA, 15 #D81B60, 16 #5D4037, 17 #303030, 18 #757575, 19 #aaaaaa.
9. `io.csv-habits-file#9` — Column 9 'Unit' = habit.unit when habit.isNumerical, otherwise the empty string.
10. `io.csv-habits-file#10` — Column 10 'Target Type' = habit.targetType enum NAME ('AT_LEAST' or 'AT_MOST') when habit.isNumerical, otherwise the empty string.
11. `io.csv-habits-file#11` — Column 11 'Target Value' = format('%.1f', habit.targetValue) when habit.isNumerical (e.g. '2.0'), otherwise the empty string.
12. `io.csv-habits-file#12` — Column 12 'Archived?' = 'true' or 'false' (Kotlin Boolean.toString of habit.isArchived).
13. `io.csv-habits-file#13` — Every line, including the header, is terminated with '\n'; there is no trailing blank data line beyond the final '\n'.
14. `io.csv-habits-file#14` — Exact expected output for a 3-habit list: '001,Meditate,YES_NO,Did you meditate this morning?,this is a test description,1,1,#FF8F00,,,,false' / '002,Run,NUMERICAL,How many miles did you run today?,,1,1,#E64A19,miles,AT_LEAST,2.0,false' / '003,Wake up early,YES_NO,Did you wake up before 6am?,,2,3,#AFB42B,,,,false'.

#### io.csv-per-habit-scores

- [x] `io.csv-per-habit-scores` — Per-habit Scores.csv
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ScoreList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporterTest.kt`
- **Notes:** Fixture 'uhabits-core/assets/test/csv_export/001 Meditate/Scores.csv' shows the empty-habit case: header + a single row for today with score 0.0000.

1. `io.csv-per-habit-scores#1` — File name inside the archive is '<NNN Habit Name>/Scores.csv'.
2. `io.csv-per-habit-scores#2` — Header line is exactly 'Date,Score\n'.
3. `io.csv-per-habit-scores#3` — The date range is [oldest .. today] where today = getToday() and oldest = the date of the LAST element of habit.computedEntries.getKnown() (getKnown() is sorted newest-first, so the last element is the oldest known entry).
4. `io.csv-per-habit-scores#4` — If habit.computedEntries.getKnown() is empty, oldest defaults to today, so the file contains the header plus exactly one row for today.
5. `io.csv-per-habit-scores#5` — Rows come from habit.scores.getByInterval(oldest, today), which yields dates in DESCENDING order (today first, oldest last); one row per calendar day with no gaps.
6. `io.csv-per-habit-scores#6` — Each row is '<date>,<score>' where date = LocalDate.toCSVString() = 'yyyy-MM-dd' with year zero-padded to 4 and month/day to 2, and score = format('%.4f', score.value), e.g. '0.2557', '0.0000'.
7. `io.csv-per-habit-scores#7` — Every row ends with '\n'.

#### io.csv-per-habit-checkmarks

- [x] `io.csv-per-habit-checkmarks` — Per-habit Checkmarks.csv
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporterTest.kt`

1. `io.csv-per-habit-checkmarks#1` — File name inside the archive is '<NNN Habit Name>/Checkmarks.csv'.
2. `io.csv-per-habit-checkmarks#2` — Header line is exactly 'Date,Value,Notes\n'.
3. `io.csv-per-habit-checkmarks#3` — Rows are produced from habit.computedEntries.getKnown() — the COMPUTED entry list (which contains YES_AUTO entries synthesized from the habit frequency), not originalEntries.
4. `io.csv-per-habit-checkmarks#4` — getKnown() returns entries sorted by date ascending then reversed, i.e. newest date first; rows appear in that descending-date order.
5. `io.csv-per-habit-checkmarks#5` — Only dates that have a known entry are emitted; there are no rows for unknown days (so the list can have gaps).
6. `io.csv-per-habit-checkmarks#6` — Column 1 = entry.date.toCSVString() ('yyyy-MM-dd').
7. `io.csv-per-habit-checkmarks#7` — Column 2 = entry.formattedValue: 'YES_MANUAL' for 2, 'YES_AUTO' for 1, 'NO' for 0, 'SKIP' for 3, 'UNKNOWN' for -1, otherwise the raw integer as a decimal string (numerical habits store value*1000, so 30 units is written as '30000').
8. `io.csv-per-habit-checkmarks#8` — Column 3 = entry.notes, CSV-quoted when needed; an empty note produces an empty trailing field, e.g. '2015-01-25,YES_MANUAL,'.
9. `io.csv-per-habit-checkmarks#9` — A note containing a comma is quoted: 'Forgot to do it, really' becomes "Forgot to do it, really"; a note containing double quotes doubles them: the note "Vacation" (with quotes) becomes """Vacation""".
10. `io.csv-per-habit-checkmarks#10` — If the habit has no known computed entries, the file contains only the header line.

#### io.csv-combined-scores

- [x] `io.csv-combined-scores` — Top-level Scores.csv (all selected habits)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporterTest.kt`

1. `io.csv-combined-scores#1` — Header is built by writeMultipleHabitsHeader: the literal 'Date' followed by ',' then, for each selected habit in order, habit.name followed by ',', then '\n'. Note the header ends with a TRAILING comma, e.g. 'Date,Meditate,Wake up early,'.
2. `io.csv-combined-scores#2` — Habit names in the header are appended RAW, without CSV quoting — a habit name containing a comma or quote will corrupt the header (reproduce this behavior verbatim).
3. `io.csv-combined-scores#3` — The row range is [oldest .. today] where today = getToday() and oldest = getTimeframe()[0]; getTimeframe scans only selectedHabits' originalEntries.getKnown(), taking the minimum of the last (oldest) entry date and starting from the sentinel LocalDate(1000000) (daysSince2000 = 1_000_000).
4. `io.csv-combined-scores#4` — Habits with no known original entries are skipped by getTimeframe (they contribute neither oldest nor newest).
5. `io.csv-combined-scores#5` — Loop is 'for i in 0..days' where days = oldest.daysUntil(today) = today.daysSince2000 - oldest.daysSince2000; the row date is today.minus(i), so rows run from today backwards to oldest inclusive.
6. `io.csv-combined-scores#6` — If NO selected habit has any known original entry, oldest stays LocalDate(1000000), days is negative, the loop body never runs, and the file contains only the header line.
7. `io.csv-combined-scores#7` — Each row is '<date>,' then, for each selected habit j, format('%.4f', scores[j][i].value) followed by ','; the line then ends with '\n'. Every row therefore ends with a trailing comma.
8. `io.csv-combined-scores#8` — scores[j] = selectedHabits[j].scores.getByInterval(oldest, today) which is newest-first, so index i aligns with date today.minus(i).
9. `io.csv-combined-scores#9` — Example fixture row: '2015-01-25,0.0000,0.2557,'.

#### io.csv-combined-checkmarks

- [x] `io.csv-combined-checkmarks` — Top-level Checkmarks.csv (all selected habits)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporterTest.kt`

1. `io.csv-combined-checkmarks#1` — Header is identical to the top-level Scores.csv header: 'Date,' + each selected habit name + ',' each, then '\n' (trailing comma included, names not CSV-escaped).
2. `io.csv-combined-checkmarks#2` — The date range and loop are identical to the combined Scores.csv: from today = getToday() backwards to oldest = getTimeframe()[0], i in 0..oldest.daysUntil(today).
3. `io.csv-combined-checkmarks#3` — Values come from selectedHabits[j].computedEntries.getByInterval(oldest, today), which returns one Entry per calendar day newest-first, filling unknown days with Entry(date, UNKNOWN=-1).
4. `io.csv-combined-checkmarks#4` — Each cell is entry.formattedValue, so unknown days render as 'UNKNOWN', and each cell is followed by ','; the row ends with '\n'.
5. `io.csv-combined-checkmarks#5` — Example fixture rows: '2015-01-25,UNKNOWN,YES_MANUAL,' and '2015-01-23,UNKNOWN,YES_AUTO,'.
6. `io.csv-combined-checkmarks#6` — Cells are NOT CSV-quoted (numerical values render as raw integers such as '30000').

#### io.csv-habit-folder-naming

- [x] `io.csv-habit-folder-naming` — Per-habit folder naming and filename sanitization
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporterTest.kt`

1. `io.csv-habit-folder-naming#1` — habitDirName(h) = format('%03d', allHabits.indexOf(h) + 1) + ' ' + sanitizeFilename(h.name).trim() + '/'.
2. `io.csv-habit-folder-naming#2` — sanitizeFilename removes every character not matching the class [ a-zA-Z0-9._-] using the regex '[^ a-zA-Z0-9._-]+' replaced with the empty string; note the class allows space, dot, underscore and hyphen only, and strips all accented/CJK/emoji characters.
3. `io.csv-habit-folder-naming#3` — After stripping, the string is truncated to at most 100 characters (substring(0, min(length, 100))); the truncation happens BEFORE the .trim() applied by habitDirName.
4. `io.csv-habit-folder-naming#4` — The index used is allHabits.indexOf(h), so it matches the Position column in Habits.csv and is NOT the index within selectedHabits; if the habit is not in allHabits, indexOf returns -1 and the folder becomes '000 ...'.
5. `io.csv-habit-folder-naming#5` — Example: habit at index 0 named 'Meditate' produces the folder '001 Meditate/'; a habit named 'Café / Naps!' at index 1 produces '002 Caf  Naps/' after stripping (with internal spaces preserved) and trimming of leading/trailing spaces.
6. `io.csv-habit-folder-naming#6` — Two habits whose sanitized names collide at the same position cannot occur because the numeric prefix is unique per habit.

#### io.csv-line-writer

- [x] `io.csv-line-writer` — CSV field quoting (csvLine)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Strings.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporterTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`

1. `io.csv-line-writer#1` — csvLine(fields) joins fields with ',' and appends a trailing '\n'.
2. `io.csv-line-writer#2` — A field is wrapped in double quotes if and only if it contains at least one of: ',', '"', '\n', '\r'.
3. `io.csv-line-writer#3` — When quoting, every embedded '"' is replaced by '""' before wrapping.
4. `io.csv-line-writer#4` — Fields that need no quoting are emitted verbatim, including leading/trailing spaces.
5. `io.csv-line-writer#5` — An empty field is emitted as the empty string (never as '""').
6. `io.csv-line-writer#6` — csvLine(arrayOf('a','b')) == 'a,b\n'; csvLine(arrayOf('x,y')) == '"x,y"\n'; csvLine(arrayOf('say "hi"')) == '"say ""hi"""\n'.
7. `io.csv-line-writer#7` — Only Habits.csv and the two per-habit files use csvLine; the two combined (multi-habit) files build lines by hand and do NOT quote.

#### io.csv-line-parser

- [x] `io.csv-line-parser` — CSV field parsing (parseCsvLine)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Strings.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/StringsTest.kt`

1. `io.csv-line-parser#1` — parseCsvLine(line) returns a List<String> of the comma-separated fields of a single line, honoring double-quoted fields.
2. `io.csv-line-parser#2` — Inside quotes, a doubled '""' yields one literal '"'; a single '"' ends the quoted section.
3. `io.csv-line-parser#3` — Outside quotes, ',' terminates a field and '"' begins a quoted section; every other character is appended verbatim.
4. `io.csv-line-parser#4` — The parser always emits a final field, so parseCsvLine(',,') == ['', '', ''] (3 empty fields) and parseCsvLine('single') == ['single'].
5. `io.csv-line-parser#5` — parseCsvLine('"has,comma",normal') == ['has,comma', 'normal'].
6. `io.csv-line-parser#6` — parseCsvLine('"has""quote",x') == ['has"quote', 'x'].
7. `io.csv-line-parser#7` — Newlines inside quotes are preserved when present in the input string: parseCsvLine('a,"line\nbreak",b') == ['a', 'line\nbreak', 'b'] — but note the importer feeds it one physical line at a time, so multi-line quoted CSV records are NOT reassembled.
8. `io.csv-line-parser#8` — An unterminated quote simply consumes the rest of the line without error.

#### io.printf-format

- [ ] `io.printf-format` — printf-style format helper
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Strings.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/io/JavaStrings.kt`, `uhabits-core/src/jsMain/kotlin/org/isoron/platform/io/JsStrings.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/StringsTest.kt`
- **Notes:** Dart has no printf; implement padLeft/toStringAsFixed helpers. The locale-dependent decimal separator is a real (buggy) behavior worth fixing rather than porting.

1. `io.printf-format#1` — format(pattern, arg) is an expect/actual with three overloads (String, Int, Double) used for '%03d', '%.4f', '%.1f' and '%02d' in this domain.
2. `io.printf-format#2` — format('%03d', 5) == '005'; format('%3d', 5) == '  5'; format('%3d', 145) == '145'; format('%8.2f', 13.419187263) == '   13.42'; format('%08.2f', 13.419187263) == '00013.42'; format('%-8.2f', 13.419187263) == '13.42   '; format('hello %s!', 'world') == 'hello world!'.
3. `io.printf-format#3` — The JVM/Android implementation delegates to java.lang.String.format WITHOUT an explicit locale, so the decimal separator follows the device default locale (a device set to a comma-decimal locale writes '0,2557' in the exported CSV). The reference fixtures assume a dot separator.
4. `io.printf-format#4` — The JS implementation delegates to the npm 'sprintf-js' package.
5. `io.printf-format#5` — Score values are always formatted with exactly 4 decimals ('%.4f'), target values with exactly 1 decimal ('%.1f'), positions with '%03d', and migration file names with '%02d'.

#### io.zip-writer-reader

- [x] `io.zip-writer-reader` — ZIP writing and reading
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Zip.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/io/Zip.kt`, `uhabits-core/src/jsMain/kotlin/org/isoron/platform/io/Zip.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/ZipTest.kt`
- **Notes:** Dart needs the 'archive' package; ZipWriter/ZipReader are expect/actual per platform in Kotlin.

1. `io.zip-writer-reader#1` — ZipWriter() is created empty; addEntry(name, content) appends one deflated entry whose bytes are content.toByteArray() (UTF-8); toBytes() closes the stream and returns the complete archive bytes.
2. `io.zip-writer-reader#2` — Entry names may contain '/' to express folders; no separate directory entries are created.
3. `io.zip-writer-reader#3` — ZipReader(bytes).entries() returns a List<ZipEntry(name, content)> in the archive's stored order, decoding each entry's bytes as UTF-8.
4. `io.zip-writer-reader#4` — Content compresses: a 100_000-character repeated string produces an archive smaller than the raw content.
5. `io.zip-writer-reader#5` — An entry with empty content round-trips as the empty string.
6. `io.zip-writer-reader#6` — The JS implementation uses JSZip with type 'uint8array' and compression 'DEFLATE', and skips entries whose 'dir' flag is true when reading.

#### io.export-csv-task

- [x] `io.export-csv-task` — ExportCSVTask: zip file naming and output location
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/ExportCSVTask.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Files.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenterTest.kt`

1. `io.export-csv-task#1` — ExportCSVTask(habitList, selectedHabits, outputDir, listener) builds a HabitsCSVExporter(habitList, selectedHabits), calls writeArchive(), and writes the bytes to outputDir.resolve('Loop Habits CSV <yyyy-MM-dd>.zip') where the date is getToday().toCSVString().
2. `io.export-csv-task#2` — On success the listener receives the resolved file's absolute path string (zipFile.pathString); this string is then passed to the share-file screen.
3. `io.export-csv-task#3` — Any Exception thrown during export is caught, its stack trace printed, and archiveFilename stays null; the listener then receives null and the UI shows the COULD_NOT_EXPORT message ('Failed to export data.').
4. `io.export-csv-task#4` — Exporting twice on the same calendar day overwrites the previous file, because the name contains only the date and no time component.
5. `io.export-csv-task#5` — writeBytes creates any missing parent directories before writing.
6. `io.export-csv-task#6` — The task always calls listener.onExportCSVFinished(...) in onPostExecute, whether or not the export succeeded.

#### io.export-csv-entry-points

- [ ] `io.export-csv-entry-points` — CSV export entry points (all habits / single habit)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/HabitsDirFinder.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/AndroidDirFinder.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/FileUtils.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitMenu.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenterTest.kt`
- **Notes:** Flutter equivalent needs path_provider + a per-platform 'external files' notion; Android's scoped external app dir has no direct desktop/iOS analogue.

1. `io.export-csv-entry-points#1` — ListHabitsBehavior.onExportCSV() exports habitList.toList() as the selected habits (the full, currently filtered list) into dirFinder.getCSVOutputDir().
2. `io.export-csv-entry-points#2` — ShowHabitMenuPresenter.onExportCSV() exports listOf(habit) — a single habit — into system.getCSVOutputDir(); Habits.csv still contains every habit.
3. `io.export-csv-entry-points#3` — Both run the export on the TaskRunner (background) and, on a non-null filename, call screen.showSendFileScreen(filename); on null they call screen.showMessage(COULD_NOT_EXPORT).
4. `io.export-csv-entry-points#4` — On Android the CSV output directory is HabitsDirFinder.getCSVOutputDir() = the first writable entry of ContextCompat.getExternalFilesDirs(context, null) plus '/CSV/', created with mkdirs() if missing (e.g. /sdcard/Android/data/org.isoron.uhabits/files/CSV/).
5. `io.export-csv-entry-points#5` — If no external files dir is writable, FileUtils.getDir returns null and HabitsDirFinder dereferences it with '!!', which throws.
6. `io.export-csv-entry-points#6` — The list-screen entry point is reached from Settings > Database > 'Export as CSV' (preference key 'exportCSV', result code 102); the single-habit entry point is the 'Export' item (R.id.export) in the show-habit overflow menu.

#### io.importer-dispatch

- [x] `io.importer-dispatch` — GenericImporter dispatch across the four importers
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/GenericImporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/AbstractImporter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`

1. `io.importer-dispatch#1` — GenericImporter holds an ordered list of importers: [LoopDBImporter, RewireDBImporter, TickmateDBImporter, HabitBullCSVImporter].
2. `io.importer-dispatch#2` — canHandle(file) returns true as soon as ANY importer's canHandle returns true, evaluated in the list order above.
3. `io.importer-dispatch#3` — importHabitsFromFile(file) iterates the SAME list and calls importHabitsFromFile on EVERY importer whose canHandle(file) returns true — it does not stop after the first match, so a file recognised by two importers is imported twice.
4. `io.importer-dispatch#4` — canHandle is therefore re-evaluated inside importHabitsFromFile (the file is opened and probed a second time).
5. `io.importer-dispatch#5` — AbstractImporter defines exactly two suspend members: canHandle(file: UserFile): Boolean and importHabitsFromFile(file: UserFile).
6. `io.importer-dispatch#6` — There is no CSV importer: files exported by the app's CSV export cannot be imported back (only the .db full backup can).

#### io.sqlite-magic-detection

- [x] `io.sqlite-magic-detection` — SQLite file detection (isSQLite3File)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/utils/FileExtensions.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/io/JavaFiles.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/utils/FileExtensionsTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/FilesTest.kt`

1. `io.sqlite-magic-detection#1` — isSQLite3File(file) returns false immediately if file.exists() is false.
2. `io.sqlite-magic-detection#2` — It reads the first 16 bytes via file.readBytes(16), decodes them as UTF-8, and returns true only if the result startsWith('SQLite format 3') (15 characters, no trailing NUL check).
3. `io.sqlite-magic-detection#3` — All three database importers (Loop, Rewire, Tickmate) call it as their first gate, so a non-SQLite file never reaches SQLiteDatabase.openDatabase.
4. `io.sqlite-magic-detection#4` — readBytes on a file shorter than the limit returns only the available bytes (and an empty array for an empty file), so a short file returns false rather than throwing.

#### io.loop-db-detection

- [x] `io.loop-db-detection` — Loop backup (.db) detection heuristics
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/LoopDBImporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/Constants.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`

1. `io.loop-db-detection#1` — LoopDBImporter.canHandle returns false immediately if isSQLite3File(file) is false.
2. `io.loop-db-detection#2` — It opens the database at file.pathString and runs: select count(*) from SQLITE_MASTER where name='Habits' or name='Repetitions'; the result must be exactly 2 (both tables present), otherwise it logs 'Cannot handle file: tables not found' and the file is rejected.
3. `io.loop-db-detection#3` — It also reads PRAGMA user_version; if the version is GREATER than DATABASE_VERSION (currently 25) it logs 'Cannot handle file: incompatible version: <v> > 25' and rejects the file. A version equal to or lower than 25 is accepted.
4. `io.loop-db-detection#4` — Both checks are evaluated (the version check runs even when the table check already failed) and the database is always closed before returning.
5. `io.loop-db-detection#5` — A Loop backup at an older schema version (e.g. the test fixture loop.db has user_version = 12) IS accepted and migrated during import.

#### io.loop-db-migration

- [x] `io.loop-db-migration` — Loop backup migration to the current schema before import
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/LoopDBImporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Database.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/SQLParser.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/MigrationTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`

1. `io.loop-db-migration#1` — Before reading any data, LoopDBImporter calls db.migrateTo(25) on the imported file itself, which mutates the user's uploaded copy.
2. `io.loop-db-migration#2` — migrateTo(target) reads PRAGMA user_version; if currentVersion >= target it returns immediately doing nothing.
3. `io.loop-db-migration#3` — Otherwise, for v in (currentVersion + 1)..target it loads the resource file 'migrations/' + format('%02d.sql', v) (e.g. 'migrations/09.sql', 'migrations/25.sql'), joins its lines with '\n', splits it into statements with SQLParser.parse, runs each statement, and then sets PRAGMA user_version = v.
4. `io.loop-db-migration#4` — Migration assets exist for versions 09 through 25 inclusive (17 files) under uhabits-core/assets/main/migrations/.
5. `io.loop-db-migration#5` — A database already at version 25 is left byte-identical (migration is idempotent).
6. `io.loop-db-migration#6` — A missing migration resource is opened successfully but yields no lines, producing zero statements and only a version bump (openResourceFile never fails for a missing file per the FileOpener contract).

#### io.loop-db-habit-mapping

- [x] `io.loop-db-habit-mapping` — Loop backup habit rows: query, defaults, merge by UUID
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/LoopDBImporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/HabitRepository.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`

1. `io.loop-db-habit-mapping#1` — Habits are loaded with: SELECT id, name, description, question, freq_num, freq_den, color, position, reminder_hour, reminder_min, reminder_days, highlight, archived, type, target_value, target_type, unit, uuid FROM Habits ORDER BY position.
2. `io.loop-db-habit-mapping#2` — NULL handling per column: name/description/question/unit default to '', freq_num and freq_den default to 1, color/position/reminder_days/highlight/archived/type/target_type default to 0, target_value defaults to 0.0, reminder_hour and reminder_min stay null, uuid stays null.
3. `io.loop-db-habit-mapping#3` — For each loaded row, the importer looks up habitList.getByUUID(uuid). If no habit with that UUID exists, it builds a new Habit, copies the row with id = null into it, and runs CreateHabitCommand(modelFactory, habitList, habit).
4. `io.loop-db-habit-mapping#4` — If a habit with that UUID already exists, the importer builds a scratch Habit, copies the row with id = the existing habit's id into it, and runs EditHabitCommand(habitList, existingId, modified) — i.e. importing the same backup twice UPDATES habits in place instead of duplicating them.
5. `io.loop-db-habit-mapping#5` — Field mapping when copying a row into a Habit: name, description, question and unit copy directly; frequency = Frequency(freqNum, freqDen); color = PaletteColor(color); isArchived = (archived != 0); type = HabitType.fromInt(type); targetType = NumericalHabitType.fromInt(targetType); targetValue and position copy directly; uuid copies directly.
6. `io.loop-db-habit-mapping#6` — A reminder is set only when BOTH reminderHour and reminderMin are non-null: Reminder(hour, min, WeekdayList(reminderDays)); otherwise the habit has no reminder.
7. `io.loop-db-habit-mapping#7` — The 'highlight' column is read into HabitData but is not copied onto the Habit.
8. `io.loop-db-habit-mapping#8` — After all habits are processed, habitList.resort() is called once and the database is closed.
9. `io.loop-db-habit-mapping#9` — Importing the test fixture loop.db yields 9 habits; the habit displayed first is 'Wake up early' with frequency 3/7 (THREE_TIMES_PER_WEEK).

#### io.loop-db-entry-mapping

- [x] `io.loop-db-entry-mapping` — Loop backup entries (Repetitions) mapping
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/LoopDBImporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`

1. `io.loop-db-entry-mapping#1` — For each imported habit, entries are read with: SELECT timestamp, value, notes FROM Repetitions WHERE habit = ? ORDER BY timestamp DESC, binding the SOURCE habit's id (habitData.id) as TEXT.
2. `io.loop-db-entry-mapping#2` — Rows whose timestamp is NULL are skipped; rows whose value is NULL are skipped; a NULL notes column becomes ''.
3. `io.loop-db-entry-mapping#3` — date = LocalDate.fromUnixTime(timestamp) where fromUnixTime subtracts the 2000-01-01 epoch (946684800000 ms) and floor-divides by 86400000, handling negative differences by (diff - 86400000 + 1) / 86400000.
4. `io.loop-db-entry-mapping#4` — The row is written into habit.originalEntries only when it differs from what is already there: the existing entry for that date is fetched, and Entry(date, value, notes) is added only if existingValue != value || existingNotes != notes. Re-importing an identical backup therefore produces no entry writes.
5. `io.loop-db-entry-mapping#5` — After the entries loop, habit.recompute() is called for that habit.
6. `io.loop-db-entry-mapping#6` — Values are stored raw: 0 = NO, 1 = YES_AUTO, 2 = YES_MANUAL, 3 = SKIP, -1 = UNKNOWN, and numerical habits store value*1000.

#### io.habitbull-detection

- [x] `io.habitbull-detection` — HabitBull CSV detection
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitBullCSVImporter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`

1. `io.habitbull-detection#1` — HabitBullCSVImporter.canHandle reads file.lines(); if the list is empty it returns false.
2. `io.habitbull-detection#2` — It returns true only when lines[0].startsWith('HabitName,HabitDescription,HabitCategory') — the remaining header columns (CalendarDate,Value,CommentText) are not checked.
3. `io.habitbull-detection#3` — Any exception thrown while reading the file (e.g. a binary file that cannot be decoded) is caught and canHandle returns false.
4. `io.habitbull-detection#4` — Detection is prefix-based, so a header with extra trailing columns still matches.

#### io.habitbull-mapping

- [x] `io.habitbull-mapping` — HabitBull CSV import mapping rules
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitBullCSVImporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Strings.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`

1. `io.habitbull-mapping#1` — Every line is parsed with parseCsvLine; lines producing fewer than 6 columns are skipped silently.
2. `io.habitbull-mapping#2` — A line whose column 0 equals exactly 'HabitName' is skipped (this skips the header wherever it appears, not just line 1).
3. `io.habitbull-mapping#3` — Column layout: 0 = HabitName, 1 = HabitDescription, 2 = HabitCategory (IGNORED), 3 = CalendarDate, 4 = Value, 5 = CommentText (used as the entry notes).
4. `io.habitbull-mapping#4` — Habits are keyed by name in a HashMap. The first line for a name creates the habit with name = col0, description = col1, frequency = Frequency.DAILY, and adds it to habitList; later lines for the same name reuse it and do NOT update the description.
5. `io.habitbull-mapping#5` — Date parsing: if the raw value contains '-', it is split on '-' and read as year-month-day (parts[0], parts[1], parts[2]); else if it contains '/', it is split on '/' and read as MONTH/DAY/YEAR (LocalDate(parts[2], parts[0], parts[1])); otherwise it throws Exception('Unrecognized date format: <raw>'), which aborts the whole import.
6. `io.habitbull-mapping#6` — Value parsing: rawValue.toInt(); on NumberFormatException it logs 'Could not parse int: <raw>. Replacing by zero.' and uses 0. A value outside Int range (e.g. '-2150000000') therefore becomes 0.
7. `io.habitbull-mapping#7` — Value 0 adds Entry(date, Entry.NO = 0, notes). Value 1 adds Entry(date, Entry.YES_MANUAL = 2, notes).
8. `io.habitbull-mapping#8` — Any other value adds Entry(date, value * 1000, notes); additionally, if value > 1 and the habit's type is not already NUMERICAL, the habit is switched to HabitType.NUMERICAL and 'Found a value of <v>, considering this habit as numerical.' is logged. Negative values (< 0) also take this branch but do NOT flip the type.
9. `io.habitbull-mapping#9` — After all lines are processed, recompute() is called once on every habit that was created during this import.
10. `io.habitbull-mapping#10` — Fixture expectations: habitbull.csv -> 4 habits, 'Breed dragons' with description 'with love and fire', daily, checked on 2016-03-18 and 2016-03-19, not checked on 2016-03-20, notes 'text' on 2016-03-18. habitbull2.csv -> 6 habits with US-style slash dates; 'H3' is checked on 2019-04-11 and 2019-05-07 and not on 2019-06-14 which carries notes 'Habit 3 notes'. habitbull3.csv -> 'Pushups' becomes NUMERICAL with value 30000 on 2021-09-01 and 100000 on 2022-01-08, while 'run' stays YES_NO. habitbull4.csv -> 'Caffeine' becomes NUMERICAL with 80000 on 2022-11-21 and 2022-11-22.
11. `io.habitbull-mapping#11` — Habits are added with habitList.add(h) directly (no Command), so a HabitBull import is not undoable.

#### io.rewire-import

- [x] `io.rewire-import` — Rewire database import
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/RewireDBImporter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`

1. `io.rewire-import#1` — canHandle returns false unless isSQLite3File(file); it then runs: select count(*) from SQLITE_MASTER where name='CHECKINS' or name='UNIT' and returns true only when the count is exactly 2. Table names are matched in UPPERCASE.
2. `io.rewire-import#2` — importHabitsFromFile opens the file, issues BEGIN on the imported database, creates habits, issues COMMIT, then closes it.
3. `io.rewire-import#3` — Habits query: select _id, name, description, schedule, active_days, repeating_count, days, period from habits. A NULL description becomes ''.
4. `io.rewire-import#4` — Frequency mapping by 'schedule': schedule 0 -> numerator = number of comma-separated tokens in active_days, denominator = 7 (e.g. '1,3,5' -> 3/7); schedule 1 -> numerator = days, denominator = periods[period] where periods = [7, 31, 365]; schedule 2 -> numerator = 1, denominator = repeating_count. Any other schedule throws IllegalStateException.
5. `io.rewire-import#5` — Entries query: select distinct date from checkins where habit_id=? and type=2 (only type 2 rows count as checks). Each date is an 8-character 'YYYYMMDD' string: year = substring(0,4), month = substring(4,6), day = substring(6,8); the entry is added as Entry(LocalDate(y, m, d), Entry.YES_MANUAL).
6. `io.rewire-import#6` — Reminder query: select time, active_days from reminders where habit_id=? limit 1. 'time' is minutes since midnight: values <= 0 or >= 1440 produce no reminder. Otherwise hour = time / 60 and minute = time % 60.
7. `io.rewire-import#7` — Reminder weekdays: active_days is comma-separated; for each token d the boolean array index (d.toInt() + 1) % 7 is set true (Rewire uses Monday = 0 while WeekdayList uses Sunday = 0). '0,1,2,3,4' therefore yields [false, true, true, true, true, true, false] (Mon–Fri).
8. `io.rewire-import#8` — When a reminder is produced it is assigned to the habit and habitList.update(habit) is called.
9. `io.rewire-import#9` — Habits are created with modelFactory.buildHabit() and habitList.add(habit) (no Command).
10. `io.rewire-import#10` — Fixture rewire.db expectations: 3 habits; 'Wake up early' (schedule 0, active_days '1,3,5') has frequency 3/7 and no reminder, is checked on 2016-01-18 and 2016-01-28 but not 2015-12-31 or 2016-03-10; 'brush teeth' (schedule 1, days 3, period 0) has frequency 3/7 and a reminder at 08:00 on Mon–Fri; 'Sleep early' (schedule 2, repeating_count 5) has frequency 1/5.

#### io.tickmate-import

- [x] `io.tickmate-import` — Tickmate database import
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/TickmateDBImporter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`

1. `io.tickmate-import#1` — canHandle returns false unless isSQLite3File(file); it then runs: select count(*) from SQLITE_MASTER where name='tracks' or name='track2groups' and returns true only when the count is exactly 2 (lowercase table names).
2. `io.tickmate-import#2` — importHabitsFromFile opens the file, issues BEGIN, creates habits, issues COMMIT, then closes it.
3. `io.tickmate-import#3` — Habits query: select _id, name, description from tracks. A NULL description becomes ''. Every imported habit gets frequency = Frequency.DAILY.
4. `io.tickmate-import#4` — Entries query: select distinct year, month, day from ticks where _track_id=?.
5. `io.tickmate-import#5` — Tickmate months are 0-based, so the entry date is LocalDate(year, month + 1, day); every tick is stored as Entry.YES_MANUAL.
6. `io.tickmate-import#6` — Habits are added with habitList.add(habit) (no Command) and no reminders are imported.
7. `io.tickmate-import#7` — Fixture tickmate.db expectations: 3 tracks ('Vegan', 'Sport', 'I love you'); 'Vegan' is checked on 2016-01-24, 2016-02-05 and 2016-03-18 but not on 2016-03-14.

#### io.import-task

- [x] `io.import-task` — ImportDataTask: transaction and result codes
- **Platform:** android-only · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/tasks/ImportDataTask.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/tasks/ImportDataTaskFactory.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `io.import-task#1` — ImportDataTask wraps the whole import in a transaction on the APP database: modelFactory.database.begin() before, commit() after.
2. `io.import-task#2` — Result constants are exactly: SUCCESS = 1, NOT_RECOGNIZED = 2, FAILED = 3.
3. `io.import-task#3` — If importer.canHandle(file) is true, importHabitsFromFile runs, result = SUCCESS (1) and the transaction is committed.
4. `io.import-task#4` — If canHandle is false, result = NOT_RECOGNIZED (2) and the transaction is still committed (no rollback).
5. `io.import-task#5` — If any Exception escapes, result = FAILED (3), the exception is logged as 'ImportDataTask'/'Import failed', and commit() is attempted again inside a nested try/catch so the transaction is always closed — note the partial import is COMMITTED, not rolled back.
6. `io.import-task#6` — onPostExecute always calls listener.onImportDataFinished(result).
7. `io.import-task#7` — The task casts the injected ModelFactory to SQLModelFactory to reach the database; a non-SQL model factory would throw ClassCastException at construction.

#### io.import-file-picker

- [ ] `io.import-file-picker` — Import data: file picking, temp copy and user messages
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentFactory.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/FileUtils.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/BackupTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/BackupSteps.kt`
- **Notes:** ACTION_OPEN_DOCUMENT / SAF content URIs have no Flutter equivalent; needs file_picker plus per-platform handling.

1. `io.import-file-picker#1` — Settings > Database > 'Import data' (preference key 'importData') returns RESULT_IMPORT_DATA = 101 to the list screen, which launches an ACTION_OPEN_DOCUMENT intent with CATEGORY_OPENABLE and type '*/*' using request code REQUEST_OPEN_DOCUMENT = 106.
2. `io.import-file-picker#2` — On RESULT_OK with non-null data, the selected content URI is opened via contentResolver.openInputStream and copied byte-for-byte (1024-byte buffer) into a temp file created with File.createTempFile('import', '', activity.externalCacheDir).
3. `io.import-file-picker#3` — The temp file is wrapped in a JavaUserFile and handed to ImportDataTask; the temp file is deleted in the task's completion callback, whatever the result.
4. `io.import-file-picker#4` — Result 1 (SUCCESS) refreshes the habit list adapter and shows 'Habits imported successfully.'; result 2 (NOT_RECOGNIZED) shows 'File not recognized.'; any other result shows 'Failed to import data.'.
5. `io.import-file-picker#5` — An IOException while copying shows 'Failed to import data.' and prints the stack trace, without starting the import task.
6. `io.import-file-picker#6` — If the result code is not RESULT_OK, or data is null, nothing happens at all.
7. `io.import-file-picker#7` — The settings summary states the supported formats: full backups exported by this app, plus files generated by Tickmate, HabitBull or Rewire.

#### io.export-db-backup

- [ ] `io.export-db-backup` — Export full backup (.db) and its file naming
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/tasks/ExportDBTask.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/tasks/ExportDBTaskFactory.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DatabaseUtils.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateFormats.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/Constants.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `uhabits-android/src/main/res/xml/preferences.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/BackupTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/BackupSteps.kt`
- **Notes:** DocumentFile/SAF tree URIs and the '<filesDir>/../databases' layout are Android-specific. (Merged duplicate id: `persistence.manual-export-db`.)

1. `io.export-db-backup#1` — Settings > Database > 'Export full backup' (preference key 'exportDB') returns RESULT_EXPORT_DB = 103, which runs ExportDBTask on the TaskRunner.
2. `io.export-db-backup#2` — ExportDBTask reads the default SharedPreferences string 'publicBackupFolder'. When it is set, the URI is parsed: scheme 'content' -> DocumentFile.fromTreeUri, any other scheme -> DocumentFile.fromFile(File(uri.path)); the backup is written there and the returned filename is the created document's URI string.
3. `io.export-db-backup#3` — When 'publicBackupFolder' is not set, the backup goes to AndroidDirFinder.getFilesDir('Backups') — the first writable ContextCompat.getExternalFilesDirs entry plus '/Backups/', created if missing — and the returned filename is the absolute file path.
4. `io.export-db-backup#4` — If the private backup dir cannot be obtained (null), doInBackground returns early leaving filename = null.
5. `io.export-db-backup#5` — The backup file name is always 'Loop Habits Backup <date>.db' where <date> = SimpleDateFormat('yyyy-MM-dd HHmmss', Locale.US) with the time zone forced to UTC, applied to System.currentTimeMillis() (e.g. 'Loop Habits Backup 2025-08-22 143012.db').
6. `io.export-db-backup#6` — In the public-folder path the document is created with MIME type 'application/octet-stream'; if createFile returns null an IOException('Unable to create backup file') is thrown.
7. `io.export-db-backup#7` — The source file copied is context.filesDir/../databases/uhabits.db (DATABASE_FILENAME), or '.../databases/test.db' when the app runs in test mode.
8. `io.export-db-backup#8` — Any IOException during export is rethrown wrapped in a RuntimeException.
9. `io.export-db-backup#9` — On completion, a non-null filename opens the share screen; a null filename shows 'Failed to export data.'.
10. `io.export-db-backup#10` — Settings → "Export full backup" (preference key "exportDB") runs ExportDBTask.
11. `io.export-db-backup#11` — ExportDBTask uses the same destination resolution as AutoBackup: SharedPreferences "publicBackupFolder" URI (content scheme → DocumentFile.fromTreeUri, otherwise DocumentFile.fromFile), else AndroidDirFinder.getFilesDir("Backups").
12. `io.export-db-backup#12` — Unlike AutoBackup, ExportDBTask performs NO rotation and NO freshness check — it always writes a new copy, even if a backup was written seconds earlier.
13. `io.export-db-backup#13` — The file name uses the same format: "Loop Habits Backup yyyy-MM-dd HHmmss.db" (UTC, Locale.US).
14. `io.export-db-backup#14` — On success the listener receives the absolute file path (private dir) or the content URI string (public dir); if the destination folder resolves to null the listener receives null.
15. `io.export-db-backup#15` — An IOException during the copy is rethrown wrapped in RuntimeException.
16. `io.export-db-backup#16` — The exported file is a valid Loop database at user_version 25 and can be re-imported by LoopDBImporter.

#### io.auto-backup

- [ ] `io.auto-backup` — Automatic daily backup with rotation
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/database/AutoBackup.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DatabaseUtils.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/AndroidDirFinder.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/FileUtils.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateFormats.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateUtils.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/tasks/ExportDBTask.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/database/AutoBackupTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/BackupTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/BackupSteps.kt`
- **Notes:** Storage Access Framework (DocumentFile/tree URIs) and getExternalFilesDirs have no direct Flutter equivalent; needs path_provider + file_picker or a platform channel. The rotation/freshness algorithm itself is pure logic and portable. AutoBackupTest also asserts the produced name 'Loop Habits Backup 1970-02-10 000000.db' after DateUtils.setFixedLocalTime(40*DAY_LENGTH), even though DatabaseUtils.saveDatabaseCopy actually formats System.currentTimeMillis(); the source, not the test, is authoritative for the timestamp source. (Merged duplicate ids: `persistence.auto-backup`, `platform-glue.auto-backup`.)

1. `io.auto-backup#1` — AutoBackup(context).run(keep = 5) is invoked from ListHabitsActivity.onResume inside a background taskRunner block wrapped in try/catch, so any failure is logged ("TaskRunner failed") and swallowed — a failing backup never crashes the app.
2. `io.auto-backup#2` — Destination selection: read the default SharedPreferences string "publicBackupFolder". If non-null, parse it as a Uri; if uri.scheme == "content" use DocumentFile.fromTreeUri(context, uri), otherwise DocumentFile.fromFile(File(uri.path!!)). If the resulting DocumentFile is non-null, run the public-directory flow and return.
3. `io.auto-backup#3` — If "publicBackupFolder" is unset, or the DocumentFile is null, fall back to AndroidDirFinder(context).getFilesDir("Backups"); if that returns null the whole run does nothing.
4. `io.auto-backup#4` — AndroidDirFinder.getFilesDir(rel) picks the first entry of ContextCompat.getExternalFilesDirs(context, null) that canWrite(), then returns File("<thatDir>/<rel>/"), creating it with mkdirs() when missing; it returns null when no parent is writable or the directory cannot be created.
5. `io.auto-backup#5` — Private-directory flow: list ALL files in the Backups directory with no name filtering (null list → empty list), sort ascending by lastModified(); newestTimestamp = the last file's lastModified() or 0L when the directory is empty.
6. `io.auto-backup#6` — Public-directory flow: identical, except the listing is first filtered to entries where isFile is true AND the name matches the regex `^Loop Habits Backup .+\.db$`.
7. `io.auto-backup#7` — Rotation: for k in 0 until (files.size - keep), delete files[k]. With keep = 5 and 30 files, files at indices 0..24 are deleted and the 5 newest remain. When files.size <= keep, nothing is deleted.
8. `io.auto-backup#8` — newestTimestamp is captured BEFORE deletion, so rotation never influences the freshness decision.
9. `io.auto-backup#9` — Freshness: a new backup is written only when DateUtils.getLocalTime() - newestTimestamp > DateUtils.DAY_LENGTH (86_400_000 ms). Otherwise it logs "Fresh backup found (timestamp=$newestTimestamp)" and writes nothing. An empty directory has newestTimestamp = 0, so a backup is always written.
10. `io.auto-backup#10` — Backup file name is "Loop Habits Backup " + SimpleDateFormat("yyyy-MM-dd HHmmss", Locale.US) formatted in the UTC time zone + ".db" — e.g. "Loop Habits Backup 1970-02-10 000000.db".
11. `io.auto-backup#11` — The backup is a raw byte-for-byte copy of the SQLite file made with a 1024-byte buffer; WAL is disabled on the database so the single file is a complete snapshot. There is no VACUUM, checkpoint or transaction wrapper.
12. `io.auto-backup#12` — For a public DocumentFile destination, the file is created with dir.createFile("application/octet-stream", name) and written through ContentResolver.openOutputStream; a null result from createFile raises IOException("Unable to create backup file").
13. `io.auto-backup#13` — Running with a non-existent or empty backup directory must not throw.
14. `io.auto-backup#14` — AutoBackup.run(keep = 5) is invoked from ListHabitsActivity.onResume inside a TaskRunner block; exceptions are caught and logged as 'ListHabitActivity'/'TaskRunner failed'.
15. `io.auto-backup#15` — The default retention is keep = 5.
16. `io.auto-backup#16` — Rotation happens BEFORE the freshness check, so old files are pruned even on a day when no new backup is written.

#### io.public-backup-folder-pref

- [ ] `io.public-backup-folder-pref` — Public backup folder preference
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/BackupTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/BackupSteps.kt`
- **Notes:** Storage Access Framework tree URIs and persistable permissions have no Flutter equivalent. (Merged duplicate id: `persistence.public-backup-folder-pref`.)

1. `io.public-backup-folder-pref#1` — The preference lives in Settings > Database with key 'publicBackupFolder', title 'Select public backup folder' and default summary 'No folder selected'.
2. `io.public-backup-folder-pref#2` — Tapping it launches ACTION_OPEN_DOCUMENT_TREE with FLAG_GRANT_READ_URI_PERMISSION | FLAG_GRANT_WRITE_URI_PERMISSION | FLAG_GRANT_PERSISTABLE_URI_PERMISSION, request code PUBLIC_BACKUP_REQUEST_CODE.
3. `io.public-backup-folder-pref#3` — On result, contentResolver.takePersistableUriPermission(uri, READ|WRITE) is called and the URI string is stored in the default SharedPreferences under 'publicBackupFolder'.
4. `io.public-backup-folder-pref#4` — The summary is then recomputed: for a 'content' URI the tree document id is split on ':' into type and relative path; type 'primary' (case-insensitive) maps to Environment.getExternalStorageDirectory().absolutePath, any other type maps to '/storage/<type>'; the summary is that base, plus '/<rel>' when rel is non-empty. For a 'file' URI the summary is the absolute file path. For anything else the raw URI string is shown.
5. `io.public-backup-folder-pref#5` — When the preference is unset, both ExportDBTask and AutoBackup fall back to the app-private external 'Backups' folder.
6. `io.public-backup-folder-pref#6` — Both the manual export and the automatic backup consult this same preference key.
7. `io.public-backup-folder-pref#7` — The preference summary shows the human-readable path derived from the tree document id when it can be resolved, otherwise the raw URI string; when the key is unset the summary is the "no public backup folder selected" string.

#### io.share-file-screen

- [ ] `io.share-file-screen` — Sharing the exported file
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`, `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/src/main/res/xml/file_paths.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** FileProvider + ACTION_SEND maps roughly to share_plus in Flutter, but the content-URI passthrough and permission grant semantics differ. The "extendal-cache-path" typo is a real bug in the current manifest resource — the external cache directory is effectively not shareable. (Merged duplicate id: `platform-glue.file-sharing`.)

1. `io.share-file-screen#1` — showSendFileScreen(filename) parses the filename as a URI: if the scheme is 'content' the URI is used as-is; if the scheme is 'file' a File is built from uri.path; otherwise the string is treated as a plain path.
2. `io.share-file-screen#2` — For non-content URIs, a shareable URI is produced with FileProvider.getUriForFile(context, 'org.isoron.uhabits', file).
3. `io.share-file-screen#3` — It then starts an ACTION_SEND intent with type 'application/zip', EXTRA_STREAM set to that URI, and FLAG_GRANT_READ_URI_PERMISSION.
4. `io.share-file-screen#4` — The MIME type is hard-coded to 'application/zip' even when sharing a .db full backup.
5. `io.share-file-screen#5` — If no activity can handle the intent, ActivityNotFoundException is caught and the message from R.string.activity_not_found is shown instead of crashing.
6. `io.share-file-screen#6` — The FileProvider authority is 'org.isoron.uhabits', not exported, with grantUriPermissions=true, and its file_paths.xml exposes files-path, cache-path, external-path, external-files-path (and a typo'd 'extendal-cache-path') all rooted at '.'.
7. `io.share-file-screen#7` — file_paths.xml exposes five roots: files-path "." (name "files"), cache-path "." ("cache"), external-path "." ("external"), a MISSPELLED "extendal-cache-path" "." ("external-cache") which the platform ignores, and external-files-path "." ("external-files").
8. `io.share-file-screen#8` — Activity.showSendEmailScreen(toResId, subjectResId, content) fires ACTION_SEND with type "message/rfc822", EXTRA_EMAIL = arrayOf(getString(toResId)), EXTRA_SUBJECT = getString(subjectResId), EXTRA_TEXT = content — and is NOT wrapped in startActivitySafely, so a device with no mail client throws ActivityNotFoundException.

#### io.userfile-api

- [x] `io.userfile-api` — UserFile abstraction (read/write/delete/resolve/list)
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Files.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/io/JavaFiles.kt`, `uhabits-android/src/main/java/org/isoron/platform/io/AndroidFiles.kt`, `uhabits-core/src/jsMain/kotlin/org/isoron/platform/io/JsFiles.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/FilesTest.kt`

1. `io.userfile-api#1` — UserFile exposes: pathString (resolved absolute path), suspend delete(), suspend exists(), suspend lines(), suspend writeString(content), suspend writeBytes(bytes), suspend readBytes(limit), resolve(child), suspend listFiles(), suspend mkdirs().
2. `io.userfile-api#2` — lines() returns the file split into lines WITHOUT trailing line terminators, and throws if the file does not exist.
3. `io.userfile-api#3` — writeString and writeBytes overwrite the file and create parent directories first (path.toFile().parentFile?.mkdirs()).
4. `io.userfile-api#4` — readBytes(limit) reads at most 'limit' bytes from the start and returns an empty ByteArray when the file is empty or the read returns <= 0 bytes; it returns fewer bytes when the file is shorter than the limit.
5. `io.userfile-api#5` — resolve(child) resolves the child against this path (JavaUserFile delegates to java.nio.Path.resolve).
6. `io.userfile-api#6` — listFiles() returns null when the path is not a directory or does not exist, otherwise the list of children.
7. `io.userfile-api#7` — delete() on a JavaUserFile uses Files.delete and throws when the file does not exist (unlike the interface doc for the ResourceFile copy path, which calls exists() first).
8. `io.userfile-api#8` — FileOpener has exactly two methods: openResourceFile(path) (relative to the assets folder, e.g. 'migrations/09.sql') and openUserFile(path) (relative to the user data folder); both are documented to always succeed even when the file does not exist.
9. `io.userfile-api#9` — On Android, openUserFile(path) resolves against context.filesDir; on the JVM test platform it resolves against '/tmp/'; on JS it is an in-memory key/value store.

#### io.resourcefile-api

- [ ] `io.resourcefile-api` — ResourceFile abstraction (bundled assets)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Files.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/io/JavaFiles.kt`, `uhabits-android/src/main/java/org/isoron/platform/io/AndroidFiles.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporterTest.kt`

1. `io.resourcefile-api#1` — ResourceFile exposes: suspend copyTo(dest: UserFile), suspend lines(), suspend exists(), suspend toImage().
2. `io.resourcefile-api#2` — copyTo replaces the destination if it already exists; the Java implementation deletes the destination first and creates the destination's parent directories, while the Android implementation simply reads the asset bytes and calls dest.writeBytes.
3. `io.resourcefile-api#3` — On Android, resource paths are asset paths (assets/<path>) and exists() is implemented by attempting assets.open(path) and catching IOException.
4. `io.resourcefile-api#4` — On the JVM, a resource path is looked up first under 'assets/main/<path>' and falls back to 'assets/test/<path>' when the main file does not exist — this is how the CSV export fixtures and test databases are loaded in unit tests.
5. `io.resourcefile-api#5` — The only production use of ResourceFile in this domain is LoopDBImporter loading 'migrations/NN.sql'.

#### io.logging

- [ ] `io.logging` — Logging abstraction (importers and platform adapter)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/Logging.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/io/AndroidLogging.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/inject/HabitsApplicationComponent.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Merged duplicate id: `platform-glue.logging`.

1. `io.logging#1` — Logging.getLogger(name) returns a Logger with info(msg), debug(msg), error(msg) and error(exception).
2. `io.logging#2` — StandardLogging/StandardLogger (used in core and tests) prints '[<name>] <msg>' to stdout for info, debug and error, and calls printStackTrace for error(exception).
3. `io.logging#3` — AndroidLogging/AndroidLogger maps info/debug/error to Log.i/Log.d/Log.e with the logger name as the tag, and error(exception) to Log.e(name, 'Exception', exception).
4. `io.logging#4` — LoopDBImporter uses the logger name 'LoopDBImporter' and HabitBullCSVImporter uses 'HabitBullCSVImporter'; RewireDBImporter and TickmateDBImporter do not log.
5. `io.logging#5` — Messages emitted during import that a port should preserve: 'Creating habit: <name>', 'Found a value of <v>, considering this habit as numerical.', 'Could not parse int: <raw>. Replacing by zero.', 'Cannot handle file: tables not found', 'Cannot handle file: incompatible version: <v> > 25'.
6. `io.logging#6` — AndroidLogging implements the core Logging interface and returns an AndroidLogger for a given name (the log tag).
7. `io.logging#7` — AndroidLogger.info(msg) -> Log.i(name, msg); debug(msg) -> Log.d(name, msg); error(msg) -> Log.e(name, msg); error(exception) -> Log.e(name, "Exception", exception) (the literal message "Exception" plus the throwable).
8. `io.logging#8` — Logging is bound in the app component as an @AppScope singleton returning a fresh AndroidLogging().

#### io.bug-report-dump

- [ ] `io.bug-report-dump` — Bug report generation and log file dump
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/AndroidBugReporter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsModule.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/res/values/constants.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/HabitsApplicationTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`
- **Notes:** Reading logcat via Runtime.exec has no Flutter/iOS equivalent. `logcat -d` cannot be shelled out from Dart; on Flutter the log capture must be replaced by an in-process ring buffer. HabitsApplicationTest asserts a message printed via printStackTrace appears in getLogcat() output. (Merged duplicate id: `platform-glue.bug-report-generation`.)

1. `io.bug-report-dump#1` — Settings > Troubleshooting > 'Generate bug report' (preference key 'bugReport') returns RESULT_BUG_REPORT = 104, which calls ListHabitsBehavior.onSendBugReport().
2. `io.bug-report-dump#2` — onSendBugReport() first calls bugReporter.dumpBugReportToFile(), then bugReporter.getBugReport(); on success it opens the send-email screen with that text, on Exception it prints the stack trace and shows COULD_NOT_GENERATE_BUG_REPORT ('Failed to generate bug report.').
3. `io.bug-report-dump#3` — getBugReport() returns '---------- BUG REPORT BEGINS ----------\n' + logcat + '\n' + device info + '\n' + '---------- BUG REPORT ENDS ------------\n'.
4. `io.bug-report-dump#4` — getLogcat() runs the OS command ['logcat', '-d'] and keeps only the LAST 250 lines (a LinkedList that drops the head whenever size exceeds 250), each terminated by a newline.
5. `io.bug-report-dump#5` — Device info lines are, in order: App Version Name, App Version Code, OS Version (os.version plus Build.VERSION.INCREMENTAL), OS API Level, Device, Model (Product), Manufacturer, Other tags, Screen Width, Screen Height, External storage state, then a blank line.
6. `io.bug-report-dump#6` — dumpBugReportToFile() writes the report to '<Logs dir>/Log <yyyy-MM-dd HHmmss>.txt' where the date uses SimpleDateFormat('yyyy-MM-dd HHmmss', Locale.US) in the DEFAULT time zone and the Logs dir is AndroidDirFinder.getFilesDir('Logs'); a null dir raises IOException('log dir should not be null').
7. `io.bug-report-dump#7` — Every IOException inside dumpBugReportToFile is swallowed after printStackTrace, so a failed dump never aborts the flow.
8. `io.bug-report-dump#8` — The same dump is invoked from BaseExceptionHandler when the app crashes.
9. `io.bug-report-dump#9` — getDeviceInfo() emits these lines in order: "App Version Name: <VERSION_NAME>", "App Version Code: <VERSION_CODE>", "OS Version: <os.version> (<Build.VERSION.INCREMENTAL>)", "OS API Level: <Build.VERSION.SDK_INT>", "Device: <Build.DEVICE>", "Model (Product): <Build.MODEL> (<Build.PRODUCT>)", "Manufacturer: <Build.MANUFACTURER>", "Other tags: <Build.TAGS>", "Screen Width: <display width>", "Screen Height: <display height>", "External storage state: <Environment.getExternalStorageState()>", followed by one blank line.
10. `io.bug-report-dump#10` — showSendBugReportToDeveloperScreen(log) fires an ACTION_SEND intent with type "message/rfc822", EXTRA_EMAIL = [@string/bugReportTo], EXTRA_SUBJECT = @string/bugReportSubject, EXTRA_TEXT = the full log.
11. `io.bug-report-dump#11` — The bug report is reachable from Settings via the preference with key "bugReport" under the @string/troubleshooting category, titled @string/generate_bug_report.
12. `io.bug-report-dump#12` — ListHabitsModule is an @Inject class extending AndroidBugReporter(appContext) and implementing ListHabitsBehavior.BugReporter — that is the DI binding used by the list screen.

## Domain: Habit list screen (card list, header, menus, selection, entry buttons, hints, empty state, search)

#### list-habits.screen-layout

- [ ] `list-habits.screen-layout` — Screen layout and visible column count
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsRootView.kt`, `.../views/HabitCardListView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/TaskProgressBar.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`, `uhabits-android/src/main/res/values/dimens.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Confetti overlay is a third-party Android view (KonfettiView); the pixel-perfect column-count formula must be reproduced to keep the header and the rows aligned.

1. `list-habits.screen-layout#1` — The root screen is a stack of: a confetti overlay (translationZ 10), a toolbar pinned to the top, a HeaderView directly below the toolbar, the habit card list filling the rest below the header, an EmptyListView occupying the same area as the list, an indeterminate horizontal TaskProgressBar below the header with topMargin = -6dp, and a HintView pinned to the bottom.
2. `list-habits.screen-layout#2` — Toolbar title is the string 'Habits' (R.string.main_activity_title), home-as-up is disabled, elevation 2dp, and its color is PaletteColor(17) resolved through the current theme (or colorPrimary when the theme attribute useHabitColorAsPrimary is false). The window status bar color is set to the same color.
3. `list-habits.screen-layout#3` — MAX_CHECKMARK_COUNT is the constant 60. The number of visible entry columns is recomputed on every size change as: labelWidth = max(measuredWidth / 3, 160dp); buttonCount = floor((measuredWidth - labelWidth) / 48dp); visibleCount = min(60, max(0, buttonCount)).
4. `list-habits.screen-layout#4` — On size change the computed visibleCount is assigned to header.buttonCount and to listView.checkmarkCount, and header maxDataOffset is set to max(60 - visibleCount, 0).
5. `list-habits.screen-layout#5` — Each entry button is exactly 48dp wide and 48dp high (R.dimen.checkmarkWidth / checkmarkHeight); the habit name column minimum width is 160dp (R.dimen.habitNameWidth).
6. `list-habits.screen-layout#6` — TaskProgressBar is GONE while TaskRunner.activeTaskCount == 0 and VISIBLE otherwise; every visibility update is applied with a 500 ms postDelayed.
7. `list-habits.screen-layout#7` — The root view applies left/right window insets as padding (max of systemBars and displayCutout insets) and paints its background black behind the insets; the toolbar applies the top inset as its own top padding.
8. `list-habits.screen-layout#8` — The last item of the card list receives an extra bottom item-decoration offset equal to the bottom systemBars inset, added exactly once.

#### list-habits.card-list-cache

- [x] `list-habits.card-list-cache` — Habit card list cache and incremental refresh
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HabitCardListCache.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HabitCardListCacheTest.kt`
- **Notes:** HabitCardListCacheTest asserts exact listener call sequences, including the cascade onItemMoved(3,2),(4,3),(5,4),(6,5),(7,6) produced when habit 2 is reordered to position 7 in the underlying list. (Merged duplicate id: `commands.listener-habit-card-list-cache`.)

1. `list-habits.card-list-cache#1` — HabitCardListCache is an application-singleton shared by all activities; it holds, per habit id, an IntArray of entry values, an Array<String> of notes, and a Double score, plus the ordered list of habits.
2. `list-habits.card-list-cache#2` — setCheckmarkCount(n) stores n; the list screen always calls setCheckmarkCount(60).
3. `list-habits.card-list-cache#3` — A full refresh fetches habits from the currently filtered list, skipping any habit whose id is null, then for each habit sets score = habit.scores[today].value and reads entries over the closed interval [today - (checkmarkCount - 1), today]; index 0 of the resulting arrays is today and index i is today - i days.
4. `list-habits.card-list-cache#4` — When a habit has no previously cached data, its default score is 0.0, its default checkmark array is an IntArray of length checkmarkCount filled with 0, and its default notes array has length checkmarkCount + 1 filled with empty strings (off-by-one is present in the original).
5. `list-habits.card-list-cache#5` — refreshAllHabits() cancels any in-flight refresh task before starting a new one; refreshHabit(id) starts a task that recomputes only the habit with that id and leaves every other row untouched.
6. `list-habits.card-list-cache#6` — onCommandFinished: if the finished command is a CreateRepetitionCommand, only that command's habit is refreshed (refreshHabit(habit.id)); for every other command type the whole list is refreshed.
7. `list-habits.card-list-cache#7` — During refresh the cache first emits a 'removed habits' pass: every id present in the old data but absent from the new data is removed and onItemRemoved(oldPosition) is fired for each.
8. `list-habits.card-list-cache#8` — For each new position: if the habit is not in the old data, it is inserted at that position and onItemInserted(position) fires; otherwise, if its old index differs from the new index it is moved and onItemMoved(oldIndex, newIndex) fires; then an update check runs.
9. `list-habits.card-list-cache#9` — The update check fires onItemChanged(position) only if the score, the checkmark array, or the notes array actually differ from the cached values; if all three are unchanged no listener call is made.
10. `list-habits.card-list-cache#10` — performMove clamps the destination index to data.habits.size when the requested destination is strictly greater than the list size, logging an error (workaround for upstream issue 968).
11. `list-habits.card-list-cache#11` — remove(id) on an id not present in the cache is a no-op; otherwise it deletes the habit and its checkmarks/notes/score entries and fires onItemRemoved(position).
12. `list-habits.card-list-cache#12` — reorder(from, to) removes the habit at index from and re-inserts it at index to, then fires onItemMoved(from, to); it does not touch the database.
13. `list-habits.card-list-cache#13` — onRefreshFinished() fires once at the end of every refresh task, after all incremental notifications.
14. `list-habits.card-list-cache#14` — hasNoHabit() returns true when the unfiltered habit list is empty (it ignores the active filter).
15. `list-habits.card-list-cache#15` — getHabitByPosition(position) returns null when position < 0 or position >= habitCount.
16. `list-habits.card-list-cache#16` — Setting primaryOrder or secondaryOrder assigns the order to both the unfiltered and the filtered list and then triggers a full refresh.
17. `list-habits.card-list-cache#17` — setFilter(matcher) replaces the filtered list with allHabits.getFiltered(matcher) but does NOT refresh by itself; the caller must call refresh().
18. `list-habits.card-list-cache#18` — HabitCardListCache implements CommandRunner.Listener; it subscribes in `onAttached()` and unsubscribes in `onDetached()`.
19. `list-habits.card-list-cache#19` — `onCommandFinished(command)`: if `command is CreateRepetitionCommand`, it calls `command.habit.id?.let { refreshHabit(it) }` — a targeted refresh of that one habit (and nothing at all if the habit's id is null). For EVERY other command type it calls `refreshAllHabits()`.
20. `list-habits.card-list-cache#20` — `refreshAllHabits()` cancels the currently running fetch task (if any) before starting a new full RefreshTask; `refreshHabit(id)` starts a RefreshTask scoped to that id without cancelling anything.
21. `list-habits.card-list-cache#21` — Observable outcome for a targeted refresh (HabitCardListCacheTest.testCommandListener_single): running CreateRepetitionCommand on the habit at position 2 produces exactly `listener.onItemChanged(2)` and `listener.onRefreshFinished()` and no other listener callbacks.
22. `list-habits.card-list-cache#22` — Observable outcome for a full refresh (HabitCardListCacheTest.testCommandListener_all): running DeleteHabitsCommand on the habit at position 0 produces `listener.onItemRemoved(0)` and `listener.onRefreshFinished()`, and `cache.habitCount` drops from 10 to 9.
23. `list-habits.card-list-cache#23` — The cache's own `remove(id)` (used for optimistic removal) drops the habit from data.habits, idToHabit, checkmarks, notes and scores, and emits `onItemRemoved(position)`; it is a no-op if the id is unknown.

#### list-habits.adapter

- [x] `list-habits.adapter` — List adapter: item binding, stable ids, selection storage
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HabitCardListAdapter.kt`, `.../HabitCardListView.kt`, `.../HabitCardViewHolder.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `list-habits.adapter#1` — The adapter reports itemCount == cache.habitCount and uses stable ids equal to the habit id (setHasStableIds(true)).
2. `list-habits.adapter#2` — On construction the adapter sets cache.checkmarkCount = 60, then assigns cache.secondaryOrder = preferences.defaultSecondaryOrder and cache.primaryOrder = preferences.defaultPrimaryOrder (secondary is assigned first).
3. `list-habits.adapter#3` — Setting adapter.primaryOrder writes through to both the cache (triggering a refresh) and to Preferences.defaultPrimaryOrder; the same holds for secondaryOrder and defaultSecondaryOrder.
4. `list-habits.adapter#4` — isSortable is true if and only if cache.primaryOrder == BY_POSITION.
5. `list-habits.adapter#5` — Binding a row passes the habit, its cached score, its cached IntArray of values, its cached notes array, and a boolean 'selected' = selected list contains this habit.
6. `list-habits.adapter#6` — toggleSelection(position): if there is no habit at that position, do nothing; otherwise add the habit to the selection if absent, or remove it if present, then notify the whole data set changed.
7. `list-habits.adapter#7` — clearSelection() is a no-op when nothing is selected; otherwise it clears the list, notifies the whole data set changed, and notifies the ModelObservable listeners.
8. `list-habits.adapter#8` — Every cache listener callback (onItemChanged / onItemInserted / onItemMoved / onItemRemoved / onRefreshFinished) forwards to the matching RecyclerView notification and then notifies the adapter's ModelObservable.
9. `list-habits.adapter#9` — performRemove(selected) removes each selected habit from the cache only (optimistic UI); the database is untouched and the change is reverted on the next refresh.
10. `list-habits.adapter#10` — performReorder(from, to) calls cache.reorder(from, to) only (optimistic UI).
11. `list-habits.adapter#11` — The adapter registers with MidnightTimer while attached; at midnight it calls cache.refreshAllHabits().
12. `list-habits.adapter#12` — onAttached registers the cache with the CommandRunner and adds the midnight listener; onDetached removes both.

#### list-habits.menu.overflow-items

- [ ] `list-habits.menu.overflow-items` — Main toolbar menu items
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsMenu.kt`, `.../ListHabitsActivity.kt`, `.../ListHabitsScreen.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehavior.kt`, `uhabits-android/src/main/res/menu/list_habits.xml`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehaviorTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/ListHabitsSteps.kt`

1. `list-habits.menu.overflow-items#1` — The toolbar menu contains, in this order: a SearchView action-view container (id actionSearchContainer, showAsAction=always), then a group 'actionItems' containing: 'Add habit' (icon, always), 'Filter' (icon, always, with a submenu), 'Dark theme' (checkable, orderInCategory 50, never), 'Settings' (orderInCategory 100, never), 'Help & FAQ' (orderInCategory 100, never), 'About' (orderInCategory 100, never).
2. `list-habits.menu.overflow-items#2` — The Filter submenu contains, in order: 'Hide archived' (checkable), 'Hide completed'/'Hide entered' (checkable), a 'Sort' submenu, and 'Search'.
3. `list-habits.menu.overflow-items#3` — The Sort submenu contains, in order: 'Manually', 'By name', 'By color', 'By score', 'By status'.
4. `list-habits.menu.overflow-items#4` — On menu creation: 'Dark theme' isChecked = themeSwitcher.isNightMode; 'Hide archived' isChecked = !preferences.showArchived; 'Hide completed' isChecked = !preferences.showCompleted.
5. `list-habits.menu.overflow-items#5` — The title of the hide-completed item is 'Hide entered' when preferences.areQuestionMarksEnabled OR preferences.isSkipEnabled is true, and 'Hide completed' otherwise.
6. `list-habits.menu.overflow-items#6` — Tapping 'Add habit' shows the habit-type selection dialog (a fragment with tag 'habitType') which offers 'Yes or No' and the measurable type.
7. `list-habits.menu.overflow-items#7` — Tapping 'Help & FAQ' opens the FAQ screen, 'About' opens the About screen, 'Settings' opens the Settings screen with startActivityForResult using request code 107.
8. `list-habits.menu.overflow-items#8` — Tapping 'Hide archived' or 'Hide completed' toggles the corresponding filter and then re-creates the options menu so the checkbox state is redrawn.
9. `list-habits.menu.overflow-items#9` — Selecting any options-menu item first invalidates the options menu and then dispatches the item; unknown ids return false (not handled).
10. `list-habits.menu.overflow-items#10` — When the questions-marks preference changes while the screen is visible, the options menu is invalidated and the filter is recomputed.

#### list-habits.sort-modes

- [ ] `list-habits.sort-modes` — Sort modes and toggle-direction logic
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehavior.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitList.kt`, `.../models/memory/MemoryHabitList.kt`, `.../preferences/Preferences.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsMenu.kt`, `.../views/HabitCardListAdapter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehaviorTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/regression/ListHabitsRegressionTest.kt`

1. `list-habits.sort-modes#1` — HabitList.Order has exactly nine values: BY_NAME_ASC, BY_NAME_DESC, BY_COLOR_ASC, BY_COLOR_DESC, BY_SCORE_ASC, BY_SCORE_DESC, BY_STATUS_ASC, BY_STATUS_DESC, BY_POSITION.
2. `list-habits.sort-modes#2` — 'Manually' sets primaryOrder = BY_POSITION unconditionally and never changes secondaryOrder.
3. `list-habits.sort-modes#3` — For each of the toggling sort entries the (defaultOrder, reversedOrder) pairs are: name -> (BY_NAME_ASC, BY_NAME_DESC); color -> (BY_COLOR_ASC, BY_COLOR_DESC); score -> (BY_SCORE_DESC, BY_SCORE_ASC); status -> (BY_STATUS_ASC, BY_STATUS_DESC).
4. `list-habits.sort-modes#4` — Toggle rule: if primaryOrder != defaultOrder then (if primaryOrder != reversedOrder, first copy the current primaryOrder into secondaryOrder) and set primaryOrder = defaultOrder; otherwise set primaryOrder = reversedOrder and leave secondaryOrder unchanged.
5. `list-habits.sort-modes#5` — Example: primaryOrder == BY_NAME_ASC, user taps 'By status' -> secondaryOrder becomes BY_NAME_ASC and primaryOrder becomes BY_STATUS_ASC. Tapping 'By status' again -> primaryOrder becomes BY_STATUS_DESC and secondaryOrder is NOT written.
6. `list-habits.sort-modes#6` — Ordering uses a composed comparator: compare by primaryOrder first, and only if that returns 0 compare by secondaryOrder.
7. `list-habits.sort-modes#7` — Comparator definitions: BY_POSITION compares habit.position ascending; BY_NAME_ASC compares habit.name with plain string compareTo (case-sensitive, code-point order) and BY_NAME_DESC is its reverse; BY_COLOR_ASC compares the palette color index ascending and BY_COLOR_DESC is its reverse.
8. `list-habits.sort-modes#8` — The comparator registered for BY_SCORE_DESC compares habit1.scores[today].value to habit2.scores[today].value (i.e. it actually sorts ascending by score value) and BY_SCORE_ASC is its reverse; this naming inversion must be preserved to match observed ordering.
9. `list-habits.sort-modes#9` — The comparator registered for BY_STATUS_DESC works as: if isCompletedToday() differs, the completed habit sorts first (-1); else if isNumerical differs, the numerical habit sorts first (-1); else compare today's entry values with v2.compareTo(v1) (higher value first). BY_STATUS_ASC is its exact reverse.
10. `list-habits.sort-modes#10` — Preferences.defaultPrimaryOrder is persisted under key 'pref_default_order' with default 'BY_POSITION'; defaultSecondaryOrder under 'pref_default_secondary_order' with default 'BY_NAME_ASC'; an unparseable stored value resets the primary preference to BY_POSITION.
11. `list-habits.sort-modes#11` — In the Sort submenu only the currently active primary order gets an arrow icon: *_ASC orders show a down arrow, *_DESC orders show an up arrow, and BY_POSITION shows an up arrow on 'Manually'. All other sort entries show no icon.
12. `list-habits.sort-modes#12` — Changing the sort order triggers a full cache refresh, so rows are re-ordered immediately and the change persists across app restarts.
13. `list-habits.sort-modes#13` — Reordering (drag) is rejected by the model with an IllegalStateException when primaryOrder is not BY_POSITION.

#### list-habits.filters

- [x] `list-habits.filters` — Archived and completed/entered filters
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehavior.kt`, `.../models/HabitMatcher.kt`, `.../models/Habit.kt`, `.../preferences/Preferences.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehaviorTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitMatcherTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`

1. `list-habits.filters#1` — Initial state on screen creation: showCompleted = Preferences.showCompleted (key 'pref_show_completed', default true) and showArchived = Preferences.showArchived (key 'pref_show_archived', default false); the filter is applied immediately during construction.
2. `list-habits.filters#2` — onToggleShowArchived() flips showArchived, persists it to Preferences.showArchived, rebuilds the filter and refreshes the adapter.
3. `list-habits.filters#3` — onToggleShowCompleted() flips showCompleted, persists it to Preferences.showCompleted, rebuilds the filter and refreshes the adapter.
4. `list-habits.filters#4` — Filter construction: when Preferences.areQuestionMarksEnabled is true, the matcher is HabitMatcher(isArchivedAllowed = showArchived, isEnteredAllowed = showCompleted, searchQuery = searchQuery); otherwise it is HabitMatcher(isArchivedAllowed = showArchived, isCompletedAllowed = showCompleted, searchQuery = searchQuery). The other matcher field keeps its default true.
5. `list-habits.filters#5` — HabitMatcher.matches rejects in this order: archived habit when !isArchivedAllowed; habit without reminder when isReminderRequired; habit completed today when !isCompletedAllowed; habit entered today when !isEnteredAllowed; habit not matching the search query.
6. `list-habits.filters#6` — Habit.isCompletedToday(): for a YES_NO habit it is true when today's computed value is neither NO(0) nor UNKNOWN(-1) — so YES_MANUAL(2), YES_AUTO(1) and SKIP(3) all count as completed. For a numerical habit with targetType AT_LEAST it is value/1000.0 >= targetValue; for targetType AT_MOST it is always false.
7. `list-habits.filters#7` — Habit.isEnteredToday() is true when today's computed value != UNKNOWN(-1).
8. `list-habits.filters#8` — HabitMatcher default values are isArchivedAllowed=false, isReminderRequired=false, isCompletedAllowed=true, isEnteredAllowed=true, searchQuery="".
9. `list-habits.filters#9` — Rebuilding the filter always calls adapter.refresh() afterwards; setting the matcher alone does not refresh.

#### list-habits.search

- [ ] `list-habits.search` — Habit search (fork feature)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehavior.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitMatcher.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsMenu.kt`, `uhabits-android/src/main/res/menu/list_habits.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitMatcherTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehaviorTest.kt`
- **Notes:** Added by fork commit 4a930f5e 'Implement habit search'. The Android SearchView's own X-button semantics (first press clears text, second press fires the close listener) are platform behavior that must be reimplemented explicitly in Flutter.

1. `list-habits.search#1` — ListHabitsMenuBehavior exposes a read-only searchQuery, initialised to the empty string; onSearchQueryChanged(query) stores it verbatim and immediately rebuilds the filter and refreshes the adapter.
2. `list-habits.search#2` — HabitMatcher.matches with a non-empty searchQuery trims the query; if the trimmed query is empty the habit matches. Otherwise the habit matches only if its name, question, or description contains the trimmed query with ignoreCase = true.
3. `list-habits.search#3` — An empty query ('') and a whitespace-only query ('   ') both match every habit.
4. `list-habits.search#4` — Matching is case-insensitive: 'YOGA' matches 'Yoga practice'; leading/trailing whitespace is ignored: '  yoga  ' behaves like 'yoga'.
5. `list-habits.search#5` — Matching is a plain substring test with no accent folding: query 'méditer' matches the habit named 'Méditer' and 'MÉDITER' matches it too, but the unaccented query 'mediter' does NOT match it.
6. `list-habits.search#6` — Substring matching applies anywhere in the field: query 'run' matches the habit whose question is 'Did you run today?' and the habit named '10k Run'; query 'jog' matches a habit only through its description 'daily jog'.
7. `list-habits.search#7` — A query longer than every field matches nothing; a single-character query matches every habit containing that character in any of the three fields.
8. `list-habits.search#8` — The search filter composes with the archived/completed filters — search never bypasses them.
9. `list-habits.search#9` — UI: tapping Filter > 'Search' sets an internal isSearchActive flag and re-creates the options menu. When isSearchActive, the SearchView action-view container is made visible and the whole 'actionItems' group is hidden; when not active, the container is hidden and the group is shown.
10. `list-habits.search#10` — The SearchView is created non-iconified, with query hint 'Search', and is repopulated with the current behavior.searchQuery (without submitting) each time the menu is re-created, so the query survives menu invalidation.
11. `list-habits.search#11` — Every keystroke calls onSearchQueryChanged(newText) and the handler returns true; query submit is ignored (returns false).
12. `list-habits.search#12` — The SearchView close listener sets isSearchActive = false, makes the 'actionItems' group visible again, invalidates the options menu, and returns true. It does not clear the stored searchQuery, so a still-non-empty query keeps filtering after the search bar closes.

#### list-habits.selection-mode

- [ ] `list-habits.selection-mode` — Selection mode entry, toggling and exit
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HabitCardListController.kt`, `.../HabitCardListView.kt`, `.../HabitCardListAdapter.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsSelectionMenu.kt`, `.../views/HabitCardView.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`
- **Notes:** Android ActionMode (contextual action bar) has no direct Flutter widget; the acceptance test shouldAllowMultipleSelection asserts the title shows '2'.

1. `list-habits.selection-mode#1` — The list controller has exactly two modes: NormalMode (nothing selected) and SelectionMode (at least one habit selected); it starts in NormalMode.
2. `list-habits.selection-mode#2` — NormalMode single tap on a row opens the habit detail screen for that habit; if there is no habit at that position nothing happens.
3. `list-habits.selection-mode#3` — NormalMode long press on a row starts selection: it toggles that row into the selection, switches to SelectionMode, and starts the contextual action mode.
4. `list-habits.selection-mode#4` — SelectionMode single tap toggles the tapped row's selection; SelectionMode long press does the same. After each toggle, if the selection is now empty the mode reverts to NormalMode and the contextual action bar is finished, otherwise the action bar is invalidated so its title and item visibility refresh.
5. `list-habits.selection-mode#5` — Whenever the adapter notifies a model change and the selection is empty, the controller resets to NormalMode and finishes the contextual action bar.
6. `list-habits.selection-mode#6` — Destroying the contextual action bar (e.g. system back) cancels the selection: the selection is cleared, the mode resets to NormalMode, and the action bar is finished.
7. `list-habits.selection-mode#7` — Starting a drag also goes through the same selection toggling path (NormalMode.startDrag starts selection, SelectionMode.startDrag toggles).
8. `list-habits.selection-mode#8` — The contextual action bar title is the selected count rendered as a plain decimal string (e.g. '2').
9. `list-habits.selection-mode#9` — Selecting an already-selected habit removes it from the selection (selection is a toggle, not additive-only).
10. `list-habits.selection-mode#10` — Selected rows are drawn with the R.drawable.selected_box background instead of the normal ripple background.

#### list-habits.selection-menu-actions

- [ ] `list-habits.selection-menu-actions` — Selection (contextual) menu actions and dispatch
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsSelectionMenuBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsSelectionMenu.kt`, `.../ListHabitsScreen.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/ConfirmDeleteDialog.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/ArchiveHabitsCommand.kt`, `.../UnarchiveHabitsCommand.kt`, `.../DeleteHabitsCommand.kt`, `.../ChangeHabitColorCommand.kt`, `uhabits-android/src/main/res/menu/list_habits_selection.xml`, `uhabits-android/src/main/res/values/strings.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HabitCardListAdapter.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsSelectionMenuBehaviorTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`
- **Notes:** Merged duplicate id: `commands.dispatch-selection-menu`.

1. `list-habits.selection-menu-actions#1` — The selection menu has exactly six items in this order: Edit (icon), Change color (icon), Archive, Unarchive, Delete, Reminder/notify.
2. `list-habits.selection-menu-actions#2` — Item visibility is recomputed on every selection change: colour is always visible; Edit is visible only when exactly one habit is selected; Archive is visible only when NO selected habit is archived; Unarchive is visible only when EVERY selected habit is archived; the notify item is visible only when Preferences.isDeveloper ('pref_developer', default false) is true.
3. `list-habits.selection-menu-actions#3` — canArchive() and canUnarchive() both return true for an empty selection (vacuous truth); canEdit() returns false for an empty selection.
4. `list-habits.selection-menu-actions#4` — Edit: if the selection is non-empty, open the edit screen for the first selected habit; afterwards the selection is always cleared (even when the selection was empty).
5. `list-habits.selection-menu-actions#5` — Archive: run ArchiveHabitsCommand which sets isArchived = true on every selected habit and persists them, then clear the selection.
6. `list-habits.selection-menu-actions#6` — Unarchive: run UnarchiveHabitsCommand which sets isArchived = false on every selected habit and persists them, then clear the selection.
7. `list-habits.selection-menu-actions#7` — Change color: open the color picker seeded with the colour of the FIRST selected habit; when a colour is picked, run ChangeHabitColorCommand applying that colour to every selected habit, then clear the selection.
8. `list-habits.selection-menu-actions#8` — Delete: show a confirmation dialog whose title/message are pluralised on the number of selected habits ('Delete habit?' / 'Delete habits?', message 'The habit(s) will be permanently deleted. This action cannot be undone.') with Yes/No buttons; only the Yes button confirms. On confirmation the habits are first removed from the cache optimistically, then DeleteHabitsCommand removes them from the list, then the selection is cleared.
9. `list-habits.selection-menu-actions#9` — Notify (developer only): for every selected habit, show its notification for today with reminder-time 0; the selection is not cleared.
10. `list-habits.selection-menu-actions#10` — Toast/snackbar feedback after a command finishes: ArchiveHabitsCommand -> 'Habit archived'/'Habits archived'; UnarchiveHabitsCommand -> 'Habit unarchived'/'Habits unarchived'; DeleteHabitsCommand -> 'Habit deleted'/'Habits deleted'; ChangeHabitColorCommand -> 'Habit changed'/'Habits changed'; CreateHabitCommand -> 'Habit created'; EditHabitCommand -> 'Habit changed' (always quantity 1). Plural selection is by the command's selected.size.
11. `list-habits.selection-menu-actions#11` — Messages are shown as a short snackbar with white text; if the snackbar cannot be attached the message is silently dropped.
12. `list-habits.selection-menu-actions#12` — `ListHabitsSelectionMenuBehavior` is constructed with (habitList, screen, adapter, commandRunner) and is the only place that dispatches Archive/Unarchive/ChangeColor from a multi-selection.
13. `list-habits.selection-menu-actions#13` — `onArchiveHabits()`: runs `ArchiveHabitsCommand(habitList, adapter.getSelected())` then `adapter.clearSelection()`.
14. `list-habits.selection-menu-actions#14` — `onUnarchiveHabits()`: runs `UnarchiveHabitsCommand(habitList, adapter.getSelected())` then `adapter.clearSelection()`.
15. `list-habits.selection-menu-actions#15` — `onChangeColor()`: reads the first selected habit's colour as the picker default, calls `screen.showColorPicker(defaultColor, callback)`, and inside the callback runs `ChangeHabitColorCommand(habitList, adapter.getSelected(), selectedColor)` then clears the selection. If the picker is dismissed without a choice, no command runs.
16. `list-habits.selection-menu-actions#16` — `onDeleteHabits()`: calls `screen.showDeleteConfirmationScreen(callback, quantity = adapter.getSelected().size)`; only on confirmation does it (in this order) call `adapter.performRemove(adapter.getSelected())`, then run `DeleteHabitsCommand(habitList, adapter.getSelected())`, then `adapter.clearSelection()`. Cancelling the dialog runs nothing.
17. `list-habits.selection-menu-actions#17` — `onEditHabits()`: dispatches NO command — it calls `screen.showEditHabitsScreen(selected)` only when the selection is non-empty, and clears the selection unconditionally.
18. `list-habits.selection-menu-actions#18` — Enablement predicates: `canArchive()` returns false if ANY selected habit is archived; `canUnarchive()` returns false if ANY selected habit is not archived; `canEdit()` returns `adapter.getSelected().size == 1`. Both can* predicates return true for an empty selection.
19. `list-habits.selection-menu-actions#19` — The selection is always cleared after a menu action, whether or not a command ran (except when the colour picker or delete dialog is cancelled).

#### list-habits.drag-reorder

- [ ] `list-habits.drag-reorder` — Drag-and-drop manual reordering
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HabitCardListView.kt`, `.../HabitCardListController.kt`, `.../HabitCardListAdapter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `.../models/memory/MemoryHabitList.kt`, `.../models/sqlite/SQLiteHabitList.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HabitCardListCacheTest.kt`
- **Notes:** ItemTouchHelper drag mechanics must be reimplemented with a Flutter ReorderableListView; the drag hint text is the first startup hint.

1. `list-habits.drag-reorder#1` — Drag is only started when adapter.isSortable is true, i.e. when the primary order is BY_POSITION ('Manually').
2. `list-habits.drag-reorder#2` — A long press on a row simultaneously triggers the selection long-click handler AND, if sortable, starts the drag of that row's view holder.
3. `list-habits.drag-reorder#3` — The touch helper allows vertical movement (UP or DOWN) and declares horizontal swipe flags (START or END), but swipe is explicitly disabled (isItemViewSwipeEnabled() == false) and long-press-drag by the helper itself is disabled (isLongPressDragEnabled() == false) because drag is started manually.
4. `list-habits.drag-reorder#4` — onMove(from, to) calls controller.drop(from.adapterPosition, to.adapterPosition) and returns true.
5. `list-habits.drag-reorder#5` — drop(from, to): if from == to it returns immediately without any side effect; otherwise it first cancels the selection (clears selection, resets to NormalMode, finishes the action bar), then looks up both habits; if either is null it returns; then it reorders the cache optimistically and dispatches the persistent reorder on a background task.
6. `list-habits.drag-reorder#6` — The persistent reorder moves the 'from' habit to the index currently occupied by the 'to' habit and renumbers positions: after the move every habit's position is reassigned to its index, starting at 0.
7. `list-habits.drag-reorder#7` — In SQLite persistence, a move to a smaller position increments position by 1 for all habits with position >= toPos and < fromPos; a move to a larger position decrements position by 1 for all habits with position > fromPos and <= toPos; then the moved habit's position is written as toPos.
8. `list-habits.drag-reorder#8` — Reordering a filtered/sorted list throws: the model requires primaryOrder == BY_POSITION and requires both habits to be present in the list.
9. `list-habits.drag-reorder#9` — onSwiped is a no-op.

#### list-habits.checkmark-button

- [ ] `list-habits.checkmark-button` — Checkmark button tap / long-press and toggle order
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/CheckmarkButtonView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/EntryButtonViewTest.kt`, `.../EntryPanelViewTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/regression/ListHabitsRegressionTest.kt`

1. `list-habits.checkmark-button#1` — Entry value constants: SKIP = 3, YES_MANUAL = 2, YES_AUTO = 1, NO = 0, UNKNOWN = -1.
2. `list-habits.checkmark-button#2` — Entry.nextToggleValue(value, isSkipEnabled, areQuestionMarksEnabled) is: YES_AUTO -> YES_MANUAL; YES_MANUAL -> SKIP if isSkipEnabled else NO; SKIP -> NO; NO -> UNKNOWN if areQuestionMarksEnabled else YES_MANUAL; UNKNOWN -> YES_MANUAL; any other value -> YES_MANUAL.
3. `list-habits.checkmark-button#3` — So with both options off the cycle is YES_MANUAL -> NO -> YES_MANUAL; with skip on it is YES_MANUAL -> SKIP -> NO -> YES_MANUAL; with question marks on, NO -> UNKNOWN -> YES_MANUAL; with both on the full cycle is YES_MANUAL -> SKIP -> NO -> UNKNOWN -> YES_MANUAL.
4. `list-habits.checkmark-button#4` — performToggle() computes the next value, updates the button's own value immediately (optimistic), fires onToggle(newValue, currentNotes), performs LONG_PRESS haptic feedback, and invalidates the button.
5. `list-habits.checkmark-button#5` — When Preferences.isShortToggleEnabled ('pref_short_toggle', default false) is FALSE: a single tap opens the entry edit popup and a long press performs the toggle.
6. `list-habits.checkmark-button#6` — When isShortToggleEnabled is TRUE the two are swapped: a single tap performs the toggle and a long press opens the edit popup.
7. `list-habits.checkmark-button#7` — onLongClick always returns true (consumes the event).
8. `list-habits.checkmark-button#8` — The toggle keeps the existing notes for that date unchanged (it passes the current notes through).

#### list-habits.checkmark-button-rendering

- [ ] `list-habits.checkmark-button-rendering` — Checkmark button rendering
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/CheckmarkButtonView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`, `uhabits-android/src/main/res/values/dimens.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/EntryButtonViewTest.kt`, `.../EntryPanelViewTest.kt`
- **Notes:** Depends on the FontAwesome typeface and theme contrast attributes; rendering is verified by golden-image tests under uhabits-android/src/androidTest/assets/views/habits/list/CheckmarkButtonView/ (render_explicit_check, render_implicit_check, render_unchecked; all 96x96px = 48x48dp at density 2). (Merged duplicate id: `charts-canvas-theming.checkmark-button-android`.)

1. `list-habits.checkmark-button-rendering#1` — The button is a fixed 48dp x 48dp canvas drawing a single centred FontAwesome glyph.
2. `list-habits.checkmark-button-rendering#2` — Glyph colour: YES_MANUAL, YES_AUTO and SKIP use the habit colour; NO uses the contrast60 colour when question marks are enabled and contrast40 otherwise; UNKNOWN (and anything else) uses contrast40.
3. `list-habits.checkmark-button-rendering#3` — Glyph selection: SKIP -> fa_skipped; NO -> fa_times; UNKNOWN -> fa_question when question marks are enabled, fa_times otherwise; YES_MANUAL and YES_AUTO -> fa_check.
4. `list-habits.checkmark-button-rendering#4` — Text size: 12sp when the glyph is the question mark, 13sp when the value is YES_AUTO, 14sp otherwise.
5. `list-habits.checkmark-button-rendering#5` — YES_AUTO is drawn as a hollow/outlined check: the glyph is first stroked with strokeWidth 5 and Paint.Style.STROKE in the habit colour, then re-drawn filled in the card background colour on top.
6. `list-habits.checkmark-button-rendering#6` — For all other values the paint uses strokeWidth 0 and Paint.Style.FILL.
7. `list-habits.checkmark-button-rendering#7` — The glyph baseline is placed at the rect centre after offsetting the rect vertically by 0.4 * em, where em = paint.measureText("m").
8. `list-habits.checkmark-button-rendering#8` — If the entry's notes string is not blank, a filled circle of radius 8px in the habit colour is drawn at (width - 0.8*em, 0.8*em); nothing is drawn when notes are blank.
9. `list-habits.checkmark-button-rendering#9` — CheckmarkButtonView measures itself to exactly the checkmarkWidth x checkmarkHeight dimensions (48dp x 48dp), regardless of the incoming measure spec.
10. `list-habits.checkmark-button-rendering#10` — Tap behaviour depends on preferences.isShortToggleEnabled: when enabled a short click toggles and a long click opens the editor; when disabled a short click opens the editor and a long click toggles. Long click always returns true (consumes the event).
11. `list-habits.checkmark-button-rendering#11` — performToggle() advances the value through Entry.nextToggleValue(value, isSkipEnabled, areQuestionMarksEnabled), fires onToggle(newValue, notes), triggers HapticFeedbackConstants.LONG_PRESS and invalidates.
12. `list-habits.checkmark-button-rendering#12` — Setting color, value or notes each triggers invalidate().

#### list-habits.number-button

- [ ] `list-habits.number-button` — Number (measurable) button behaviour and rendering
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/NumberButtonView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/NumberButtonViewTest.kt`, `.../NumberPanelViewTest.kt`
- **Notes:** Goldens: uhabits-android/src/androidTest/assets/views/habits/list/NumberButtonView/{render_above,render_below,render_zero,render_unitless,render_at_most_above,render_at_most_below,render_at_most_between}.png, all 96x96px. (Merged duplicate id: `charts-canvas-theming.number-button-android`.)

1. `list-habits.number-button#1` — For a numerical habit both a single tap and a long press open the numeric edit popup; there is no in-place toggle cycle.
2. `list-habits.number-button#2` — The button is 48dp x 48dp.
3. `list-habits.number-button#3` — Active colour: value < 0.0 -> contrast40; targetType AT_LEAST and value >= threshold -> habit colour; targetType AT_MOST and value <= threshold -> habit colour; otherwise contrast60.
4. `list-habits.number-button#4` — Label selection: if value == Entry.SKIP/1000 (i.e. exactly 0.003) draw the fa_skipped glyph at 14sp in FontAwesome; else if value >= 0 draw value.toShortString() in bold condensed sans-serif at 14sp; else if question marks are enabled draw the fa_question glyph at 12sp in FontAwesome; otherwise draw the literal string '0' in bold condensed at 14sp.
5. `list-habits.number-button#5` — toShortString formatting thresholds, checked top-down: >=1e9 -> '%.1fG'; >=1e8 -> '%.0fM'; >=1e7 -> '%.1fM'; >=1e6 -> '%.1fM'; >=1e5 -> '%.0fk'; >=1e4 -> '%.1fk'; >=1e3 -> '%.1fk'; >=1e2 -> DecimalFormat('#'); >=1e1 -> DecimalFormat('#.#'); otherwise DecimalFormat('#.##').
6. `list-habits.number-button#6` — Concrete formatting examples that must hold: 0.1235 -> '0.12', 0.1 -> '0.1', 5.0 -> '5', 5.25 -> '5.25', 12.3456 -> '12.3', 123.123 -> '123', 321.2 -> '321', 4321.2 -> '4.3k', 54321.2 -> '54.3k', 654321.2 -> '654k', 7654321.2 -> '7.7M', 87654321.2 -> '87.7M', 987654321.2 -> '988M', 1987654321.2 -> '2.0G'.
7. `list-habits.number-button#7` — When the unit string is blank the number is drawn alone, vertically centred after offsetting the rect by 0.5 * em.
8. `list-habits.number-button#8` — When a unit string is present the number is drawn at the vertical centre and the unit is drawn 1.3 * em below it, at 12sp in normal condensed sans-serif using the same active colour.
9. `list-habits.number-button#9` — The unit string is trimmed to fit: while its length > 2 and its measured width > 0.9 * buttonWidth, drop the last two characters and append the ellipsis character '…'.
10. `list-habits.number-button#10` — A notes indicator (filled circle radius 8px in the habit colour at (width - 0.8*em, 0.8*em)) is drawn when the entry's notes are non-blank; em here is measured from the number paint.
11. `list-habits.number-button#11` — NumberButtonView measures itself to exactly checkmarkWidth x checkmarkHeight (48dp x 48dp).
12. `list-habits.number-button#12` — The number typefaces are Typeface.create("sans-serif-condensed", BOLD) for values and Typeface.create("sans-serif-condensed", NORMAL) for units.
13. `list-habits.number-button#13` — Both a short click and a long click invoke onEdit(); long click returns true.
14. `list-habits.number-button#14` — Setting color, value, threshold, targetType, units or notes each triggers invalidate().

#### list-habits.entry-panels

- [ ] `list-habits.entry-panels` — Entry button panels: column count, data offset, reversed order
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/ButtonPanelView.kt`, `.../CheckmarkPanelView.kt`, `.../NumberPanelView.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/EntryPanelViewTest.kt`, `.../NumberPanelViewTest.kt`

1. `list-habits.entry-panels#1` — A panel lays out exactly buttonCount buttons of 48dp width each; the panel measures itself as exactly (48dp * buttonCount) wide and 48dp high.
2. `list-habits.entry-panels#2` — Changing buttonCount to a different value re-creates all buttons; setting the same value again is a no-op.
3. `list-habits.entry-panels#3` — Changing dataOffset to a different value re-binds all buttons without recreating them; setting the same value again is a no-op.
4. `list-habits.entry-panels#4` — Button index i maps to the date today.minus(i + dataOffset). With dataOffset = 3, buttons[0] shows today-3, buttons[2] shows today-5 and buttons[3] shows today-6.
5. `list-habits.entry-panels#5` — The value bound to button i is values[i + dataOffset] when that index exists, otherwise UNKNOWN (-1) for the checkmark panel and 0.0 for the number panel.
6. `list-habits.entry-panels#6` — The notes bound to button i is notes[i + dataOffset] when that index exists, otherwise the empty string.
7. `list-habits.entry-panels#7` — When Preferences.isCheckmarkSequenceReversed ('pref_checkmark_reverse_order', default false) is false the buttons are added left-to-right in index order, so today (index 0) is the LEFTMOST column and older days go rightwards.
8. `list-habits.entry-panels#8` — When isCheckmarkSequenceReversed is true the buttons are added in reversed order, so today is the RIGHTMOST column.
9. `list-habits.entry-panels#9` — The panel registers as a Preferences listener while attached; a change to the checkmark-sequence preference re-inflates the buttons immediately.
10. `list-habits.entry-panels#10` — The number panel additionally propagates targetType, threshold, units and colour to every button; the checkmark panel propagates colour only.

#### list-habits.habit-card

- [ ] `list-habits.habit-card` — Habit card row rendering
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HabitCardView.kt`, `.../HabitCardListView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/RingView.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/HabitCardViewTest.kt`

1. `list-habits.habit-card#1` — A row is a horizontal strip containing, left to right: a score ring, the habit name label (weight 1), then either the checkmark panel (yes/no habits) or the number panel (numerical habits).
2. `list-habits.habit-card#2` — The score ring is 15dp x 15dp with 3dp stroke thickness and 8dp horizontal margins, centred vertically; its percentage is the cached score (0..1) and its precision is 1/16, so the drawn sweep angle is 360 * round(percentage / (1/16)) * (1/16).
3. `list-habits.habit-card#3` — The name label has maxLines = 2, ellipsizes at the END, and (API 29+) uses a balanced line-break strategy.
4. `list-habits.habit-card#4` — The active colour of a row is the theme colour for habit.color, EXCEPT when habit.isArchived is true, in which case the contrast60 colour is used for both the label and the ring.
5. `list-habits.habit-card#5` — For a yes/no habit the checkmark panel is VISIBLE and the number panel is GONE; for a numerical habit the reverse.
6. `list-habits.habit-card#6` — Row values are set from the cached IntArray; the number panel receives the same values divided by 1000.0 element-wise.
7. `list-habits.habit-card#7` — When binding a row the numeric threshold is finally set to habit.targetValue / habit.frequency.denominator (this write happens after the habit assignment which had set it to habit.targetValue, so the divided value wins).
8. `list-habits.habit-card#8` — The card is a FrameLayout with padding (3dp left, 0 top, 3dp right, 3dp bottom); the inner strip has 1dp elevation and a ripple background, replaced by the 'selected_box' drawable while the row is selected.
9. `list-habits.habit-card#9` — Toggling or editing an entry triggers a ripple: the inner background hotspot is set at the tapped button's centre, the pressed+enabled state is applied, and the state is cleared 25 ms later.
10. `list-habits.habit-card#10` — The row observes its habit's model; a model change re-applies name, colour, unit, targetType, threshold and panel visibility on the main thread.

#### list-habits.header-dates

- [ ] `list-habits.header-dates` — Header date columns
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HeaderView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HabitListHeader.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/HeaderViewTest.kt`
- **Notes:** The KMP HabitListHeader in core draws the same information but numbers columns in the opposite direction (today = rightmost); the Android HeaderView is the one used by this screen. Goldens: uhabits-android/src/androidTest/assets/views/habits/list/HeaderView/{render,render_reverse}.png, both 1200x96px = 600x48dp. (Merged duplicate id: `charts-canvas-theming.header-view-android`.)

1. `list-habits.header-dates#1` — The header is a fixed 48dp-high strip with the headerBackgroundColor background and 2dp elevation, drawing buttonCount date columns of 48dp width each.
2. `list-habits.header-dates#2` — Column index i shows the date today.minus(i + dataOffset).
3. `list-habits.header-dates#3` — When the checkmark sequence is NOT reversed, column i is positioned at horizontal offset (i - buttonCount) * 48dp measured from (canvasWidth - 3dp), so column 0 (today) is the leftmost and dates go backwards to the right.
4. `list-habits.header-dates#4` — When the checkmark sequence IS reversed, column i is positioned at -(i + 1) * 48dp from (canvasWidth - 3dp), so column 0 (today) is the rightmost.
5. `list-habits.header-dates#5` — In right-to-left layouts each column rect is mirrored horizontally about the canvas width.
6. `list-habits.header-dates#6` — Each column draws two centred lines of bold text at 10sp in the contrast60 colour: the locale short weekday name uppercased on the first line, and the day-of-month number (no leading zero) on the second.
7. `list-habits.header-dates#7` — Vertical placement: the weekday text baseline is at rectCenterY - 0.25*em and the day number baseline at rectCenterY + 1.25*em, where em = paint.measureText("m").
8. `list-habits.header-dates#8` — The header repaints itself at midnight (MidnightTimer listener) and whenever the checkmark-sequence preference changes.
9. `list-habits.header-dates#9` — HeaderView extends ScrollableChart, sets its scroller bucket size to the checkmarkWidth dimension (48dp), paints its background with the headerBackgroundColor attribute and sets elevation to 2dp.
10. `list-habits.header-dates#10` — onMeasure reports the incoming width spec unchanged and forces the height to the checkmarkHeight dimension (48dp) with mode EXACTLY.
11. `list-habits.header-dates#11` — The scroll direction is recomputed on attach and whenever preferences.onCheckmarkSequenceChanged fires: it starts at -1, is multiplied by -1 when preferences.isCheckmarkSequenceReversed, and multiplied by -1 again when the view's layout direction is RTL.
12. `list-habits.header-dates#12` — Text is drawn with Typeface.DEFAULT_BOLD at the tinyTextSize dimension (10sp), CENTER-aligned, in the contrast60 colour; em = paint.measureText("m").
13. `list-habits.header-dates#13` — A MidnightTimer listener forces a repaint at midnight (post { invalidate() }); listeners for both Preferences and MidnightTimer are registered on attach and removed on detach.

#### list-habits.header-scrolling

- [ ] `list-habits.header-scrolling` — Horizontal scrolling of date columns
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/ScrollableChart.kt`, `.../views/HeaderView.kt`, `.../views/HabitCardListView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsRootView.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/regression/ListHabitsRegressionTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/regression/SavedStateTest.kt`
- **Notes:** Uses android.widget.Scroller physics; a Flutter port needs an equivalent snap-to-column scroll with the same 48dp bucket and 60-day maximum.

1. `list-habits.header-scrolling#1` — The header is horizontally scrollable and drives the whole list: its ScrollController pushes each new dataOffset into the list view, which pushes it into every attached row.
2. `list-habits.header-scrolling#2` — The scroller bucket size is 48dp (one column), so dataOffset = clamp(scroller.currX / 48dp, 0, maxDataOffset).
3. `list-habits.header-scrolling#3` — maxDataOffset is set to max(60 - visibleColumnCount, 0); the scrollable pixel range is maxDataOffset * 48dp. Setting maxDataOffset also clamps the current dataOffset down to it and notifies the controller.
4. `list-habits.header-scrolling#4` — Scroll direction starts at -1, is multiplied by -1 when the checkmark sequence is reversed, and multiplied by -1 again in RTL layouts; the resulting direction must be exactly +1 or -1.
5. `list-habits.header-scrolling#5` — During a drag, horizontal deltas are multiplied by -direction and clamped so scroller.currX never exceeds maxX; when |dx| > |dy| the parent is asked to stop intercepting touch events.
6. `list-habits.header-scrolling#6` — A fling uses velocityX * direction / 2 as the fling velocity, constrained to x in [0, maxX], and is animated with a ValueAnimator whose duration equals the scroller duration.
7. `list-habits.header-scrolling#7` — dataOffset changes only fire the controller callback and invalidate when the computed value actually differs from the current one.
8. `list-habits.header-scrolling#8` — Both the header's scroll state (x, y, dataOffset, direction, maxDataOffset) and the list's dataOffset are saved and restored across configuration changes / process death via saved instance state.
9. `list-habits.header-scrolling#9` — Rows that are scrolled off-screen and later re-attached immediately receive the current dataOffset (regression fix for upstream issue 713).

#### list-habits.entry-edit-popup-boolean

- [ ] `list-habits.entry-edit-popup-boolean` — Checkmark edit popup (yes/no habits) from the list screen
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/CheckmarkDialog.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CreateRepetitionCommand.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`

1. `list-habits.entry-edit-popup-boolean#1` — Opening the edit popup for a yes/no habit passes the current entry value, the current notes and the habit colour.
2. `list-habits.entry-edit-popup-boolean#2` — The popup shows four glyph buttons — Yes, No, Skip, Unknown — plus a free-text notes field prefilled with the current notes.
3. `list-habits.entry-edit-popup-boolean#3` — The Skip button is hidden unless Preferences.isSkipEnabled ('pref_skip_enabled', default false); the Unknown button is hidden unless Preferences.areQuestionMarksEnabled ('pref_unknown_enabled', default false).
4. `list-habits.entry-edit-popup-boolean#4` — Yes and Skip buttons are tinted with the habit colour; No and Unknown use the contrast60 colour.
5. `list-habits.entry-edit-popup-boolean#5` — Tapping Yes saves value YES_MANUAL(2), No saves NO(0), Skip saves SKIP(3), Unknown saves UNKNOWN(-1); the notes saved are the text field content trimmed.
6. `list-habits.entry-edit-popup-boolean#6` — Pressing the editor action on the notes field saves with the ORIGINAL value and the trimmed notes.
7. `list-habits.entry-edit-popup-boolean#7` — If the dialog is dismissed without any explicit save action, the entry is still saved with the original value when the trimmed notes differ from the original notes; if the notes are unchanged nothing is written.
8. `list-habits.entry-edit-popup-boolean#8` — Saving runs CreateRepetitionCommand(habitList, habit, date, value, notes), which adds the entry to the habit's original entries, recomputes the habit, and resorts the list.
9. `list-habits.entry-edit-popup-boolean#9` — Confetti is shown only when the newly saved value differs from the previous value AND the new value is exactly YES_MANUAL.

#### list-habits.entry-edit-popup-numeric

- [ ] `list-habits.entry-edit-popup-numeric` — Number edit popup (measurable habits) from the list screen
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/NumberDialog.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`
- **Notes:** ListHabitsBehaviorTest.testOnEdit asserts showNumberPopup is called with 0.1 for a fixture value of 100 and that picking 100.0 yields a stored value of 100000.

1. `list-habits.entry-edit-popup-numeric#1` — Opening the edit popup for a numerical habit passes oldValue = entry.value / 1000.0 (a Double) and the current notes.
2. `list-habits.entry-edit-popup-numeric#2` — The value field is prefilled with '0' when the old value is < 0.01, otherwise with DecimalFormat('#.##') of the old value.
3. `list-habits.entry-edit-popup-numeric#3` — Saving computes value = round(newValue * 1000) as an Int and runs CreateRepetitionCommand with that integer; e.g. picking 100.0 stores 100000.
4. `list-habits.entry-edit-popup-numeric#4` — An empty value field on save is stored as Entry.UNKNOWN / 1000 (i.e. -0.001 -> -1 after scaling).
5. `list-habits.entry-edit-popup-numeric#5` — Unparseable input leaves the value unchanged (the original value is kept).
6. `list-habits.entry-edit-popup-numeric#6` — The Skip shortcut fills the field with Entry.SKIP/1000 = 0.003 and saves; the Unknown shortcut fills it with Entry.UNKNOWN/1000 = -0.001 and saves. Skip is hidden unless isSkipEnabled; Unknown is hidden unless areQuestionMarksEnabled.
7. `list-habits.entry-edit-popup-numeric#7` — Pressing Enter in the value field or the editor action in the notes field saves.
8. `list-habits.entry-edit-popup-numeric#8` — Dismissing without saving still writes the entry when the trimmed notes changed, keeping the original value.
9. `list-habits.entry-edit-popup-numeric#9` — Confetti is shown only when newValue != oldValue AND ((targetType == AT_LEAST and newValue >= habit.targetValue) or (targetType == AT_MOST and newValue <= habit.targetValue)).
10. `list-habits.entry-edit-popup-numeric#10` — The decimal separator accepted by the value field follows the current locale.

#### list-habits.toggle-from-row

- [ ] `list-habits.toggle-from-row` — Toggling an entry directly from a row (and the list behavior dispatch)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HabitCardView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CreateRepetitionCommand.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HabitCardListCache.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`, `.../HabitCardListCacheTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/regression/ListHabitsRegressionTest.kt`
- **Notes:** Note that reorder and repair are NOT commands, so widgets/reminders are not refreshed after them. (Merged duplicate id: `commands.dispatch-list-toggle`.)

1. `list-habits.toggle-from-row#1` — A toggle from a row calls ListHabitsBehavior.onToggle(habit, date, value, notes, x, y), which runs CreateRepetitionCommand(habitList, habit, date, value, notes) and then shows confetti at (x, y) if and only if value == YES_MANUAL(2).
2. `list-habits.toggle-from-row#2` — Running CreateRepetitionCommand adds/replaces the entry for that date in the habit's original entries, recomputes the habit's derived entries/scores/streaks, and re-sorts the habit list (so a status/score sort can reorder the row immediately).
3. `list-habits.toggle-from-row#3` — After a CreateRepetitionCommand the cache refreshes only that one habit, so other rows keep their cached values.
4. `list-habits.toggle-from-row#4` — The row's own button already shows the new value optimistically before the command result arrives.
5. `list-habits.toggle-from-row#5` — `ListHabitsBehavior.onToggle(habit, date, value, notes, x, y)` runs `CreateRepetitionCommand(habitList, habit, date, value, notes)` FIRST and only then, if `value == Entry.YES_MANUAL` (2), calls `screen.showConfetti(habit.color, x, y)`.
6. `list-habits.toggle-from-row#6` — `ListHabitsBehavior.onEdit(habit, date, x, y)` reads `habit.computedEntries.get(date)` and branches on habit type.
7. `list-habits.toggle-from-row#7` — NUMERICAL branch: shows a number popup pre-filled with `entry.value / 1000.0` and `entry.notes`; on confirm it computes `value = (newValue * 1000).roundToInt()`, shows confetti when `newValue != oldValue` AND ((targetType == AT_LEAST && newValue >= habit.targetValue) || (targetType == AT_MOST && newValue <= habit.targetValue)), and then runs `CreateRepetitionCommand(habitList, habit, date, value, newNotes)`.
8. `list-habits.toggle-from-row#8` — YES_NO branch: shows a checkmark popup pre-filled with `entry.value`, `entry.notes` and `habit.color`; on confirm it shows confetti when `newValue != entry.value && newValue == Entry.YES_MANUAL`, then runs `CreateRepetitionCommand(habitList, habit, date, newValue, newNotes)`.
9. `list-habits.toggle-from-row#9` — Dismissing either popup without confirming runs no command.
10. `list-habits.toggle-from-row#10` — In the numerical branch the confetti check happens before the command dispatch; in the toggle path it happens after — a port should preserve both orders because the command mutates the habit that `habit.color` is read from.
11. `list-habits.toggle-from-row#11` — `ListHabitsBehavior` dispatches no other command type: reordering uses `taskRunner.execute { habitList.reorder(from, to) }` directly and DB repair uses `habitList.repair()` directly, both bypassing CommandRunner (so no listener is notified for reorder or repair).

#### list-habits.confetti

- [ ] `list-habits.confetti` — Confetti celebration animation
- **Platform:** ui · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `.../views/HabitCardView.kt`, `.../ListHabitsRootView.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Uses the nl.dionsegijn.konfetti Android library and Settings.Global.ANIMATOR_DURATION_SCALE; both need Flutter-native replacements.

1. `list-habits.confetti#1` — showConfetti(color, x, y) returns immediately without any animation when x == 0f AND y == 0f (this is the case for entries edited via the ACTION_EDIT intent).
2. `list-habits.confetti#2` — It also returns immediately when Preferences.isConfettiAnimationDisabled ('pref_disable_animation', default false) is true, or when the system animator duration scale is exactly 0.
3. `list-habits.confetti#3` — The particle burst uses: speed 0, maxSpeed 16, damping 0.9, spread 360 degrees, angle 0, absolute position (x, y), an emitter lasting 25 ms with at most 25 particles, and timeToLive 0.
4. `list-habits.confetti#4` — The palette is four colours derived from the habit's theme colour: hue-rotated by +180, +20, -20 degrees, plus the base colour itself.
5. `list-habits.confetti#5` — The burst origin is the centre of the tapped entry button, converted to window coordinates, minus the display-cutout left safe inset and (on API <= 35) minus the top system-window inset.

#### list-habits.empty-state

- [ ] `list-habits.empty-state` — Empty state view
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/EmptyListView.kt`, `.../ListHabitsRootView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HabitCardListCache.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/EmptyListViewTest.kt`
- **Notes:** Both EmptyListViewTest render tests are currently @Ignore'd as non-deterministic.

1. `list-habits.empty-state#1` — The empty view is re-evaluated every time the adapter's ModelObservable notifies (i.e. after every refresh, insert, remove, move or change).
2. `list-habits.empty-state#2` — If the adapter item count is 0 and the underlying unfiltered habit list is empty, the 'no habits' state is shown: the fa_star_half_o FontAwesome glyph and the text 'You have no active habits'.
3. `list-habits.empty-state#3` — If the adapter item count is 0 but habits do exist (they were all filtered out, e.g. by hide-completed or by search), the 'done' state is shown: the fa_umbrella_beach glyph and the text "You're all done for today!".
4. `list-habits.empty-state#4` — If the adapter item count is greater than 0 the empty view is hidden.
5. `list-habits.empty-state#5` — The empty view is a vertically centred column: the icon TextView at 40sp in the contrast60 colour, then the message TextView with 20dp top padding, also centred and in contrast60.
6. `list-habits.empty-state#6` — The empty view starts hidden.

#### list-habits.hints

- [ ] `list-habits.hints` — Startup hints
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HintList.kt`, `.../HintListFactory.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HintView.kt`, `.../ListHabitsRootView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HintListTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/HintViewTest.kt`

1. `list-habits.hints#1` — The hint list for this screen contains exactly two strings, in order: (1) 'To rearrange the entries, press-and-hold on the name of the habit, then drag it to the correct place.' and (2) 'You can see more days by putting your phone in landscape mode.'
2. `list-habits.hints#2` — HintList.shouldShow() returns true if and only if Preferences.lastHintDate is non-null AND strictly earlier than today; it returns false when lastHintDate is null or equals today.
3. `list-habits.hints#3` — Preferences.lastHintDate is null when the stored unix time under 'last_hint_timestamp' is negative (i.e. never set).
4. `list-habits.hints#4` — HintList.pop() computes next = Preferences.lastHintNumber + 1 (lastHintNumber key 'last_hint_number' defaults to -1); if next >= hints.size it returns null without touching preferences; otherwise it persists updateLastHint(next, today) and returns hints[next].
5. `list-habits.hints#5` — So the first ever pop returns hints[0] and records number 0; once all hints have been shown pop() returns null forever.
6. `list-habits.hints#6` — The hint view shows itself when attached: if shouldShow() is false, or pop() returns null, nothing is shown; otherwise the content text is set, alpha starts at 0, visibility becomes VISIBLE and the view fades in over 500 ms.
7. `list-habits.hints#7` — Tapping the hint dismisses it: it fades out over 500 ms and becomes GONE at the end of the animation.
8. `list-habits.hints#8` — The hint is a bottom-anchored vertical box with indigo_500 background, padding (16dp left, 16dp top, 4dp right, 16dp bottom), a bold white title 'Did you know?', and the white hint body with 5dp top padding.
9. `list-habits.hints#9` — On first run the app records updateLastHint(-1, today), which makes shouldShow() false for the rest of that day and lets the first hint appear the next day.

#### list-habits.startup-lifecycle

- [ ] `list-habits.startup-lifecycle` — Startup, first run, resume/pause and midnight refresh
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`, `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/utils/MidnightTimer.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`
- **Notes:** POST_NOTIFICATIONS permission flow, activity lifecycle and the ACTION_EDIT intent are Android-specific and need per-platform reimplementation.

1. `list-habits.startup-lifecycle#1` — onStartup() always increments the launch count ('launch_count', default 0) and then, if Preferences.isFirstRun ('pref_first_run', default true) is true, runs the first-run flow.
2. `list-habits.startup-lifecycle#2` — The first-run flow sets isFirstRun = false, calls updateLastHint(-1, today) and shows the intro screen.
3. `list-habits.startup-lifecycle#3` — On resume the screen: refreshes the adapter, registers as a CommandRunner listener, invalidates the root view, resumes the midnight timer, schedules reminders, runs an auto-backup and a widget update on the task runner (swallowing exceptions), possibly restarts for a pure-black theme change, and finally parses pending intents.
4. `list-habits.startup-lifecycle#4` — On pause the screen: pauses the midnight timer, unregisters the CommandRunner listener, cancels any in-flight cache refresh, and dismisses the currently visible dialog.
5. `list-habits.startup-lifecycle#5` — Reminder scheduling only runs when at least one habit has a reminder. On API < 33 it schedules directly; on API >= 33 it schedules if POST_NOTIFICATIONS is granted, otherwise it requests the permission exactly once per activity instance (guarded by a flag to avoid an infinite onResume loop) and does nothing further if denied.
6. `list-habits.startup-lifecycle#6` — The midnight timer fires at the next midnight offset by Preferences.midnightDelayHours (3 hours when 'pref_midnight_delay' is enabled, otherwise 0) plus a 1-second safety offset, then repeats every 24 hours; each fire updates the app-wide 'today' and notifies listeners.
7. `list-habits.startup-lifecycle#7` — At midnight the adapter triggers a full cache refresh and the header repaints.
8. `list-habits.startup-lifecycle#8` — The activity handles the intent action 'org.isoron.uhabits.ACTION_EDIT' with extras 'habit' (Long id) and 'timestamp' (Long unix millis) by opening the entry edit popup for that habit and date with coordinates (0f, 0f) — which suppresses confetti; the intent is then cleared so it is handled only once.
9. `list-habits.startup-lifecycle#9` — An unhandled exception installs BaseExceptionHandler as the default uncaught exception handler for the process.

#### list-habits.data-io-actions

- [ ] `list-habits.data-io-actions` — CSV export, DB export/import, repair and bug report entry points
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `.../ListHabitsModule.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`
- **Notes:** File sharing uses a FileProvider content URI and ACTION_SEND; the bug-report path uses an email intent.

1. `list-habits.data-io-actions#1` — These actions are not on the list menu itself; they are triggered by result codes returned from the Settings screen (started with request code 107): 101 -> show import file picker, 102 -> export CSV, 103 -> export DB, 104 -> send bug report, 105 -> repair database.
2. `list-habits.data-io-actions#2` — onExportCSV() exports ALL habits in the list (habitList.toList(), not the current selection or filter) into the CSV output directory on a background task; on success it opens the share-file screen with the produced filename, on failure it shows the message COULD_NOT_EXPORT ('Failed to export data.').
3. `list-habits.data-io-actions#3` — onRepairDB() runs habitList.repair() on a background task and then shows the message DATABASE_REPAIRED ('Database repaired.'); repair rebuilds contiguous habit positions 0..n-1.
4. `list-habits.data-io-actions#4` — onSendBugReport() first dumps the bug report to a file, then tries to read it; on success it opens the send-email screen with the log as body; if reading throws, it prints the stack trace and shows COULD_NOT_GENERATE_BUG_REPORT.
5. `list-habits.data-io-actions#5` — The document picker result (request code 106) copies the selected stream into a temp file in the external cache dir, imports it, then deletes the temp file; an IOException shows 'Failed to import data.'
6. `list-habits.data-io-actions#6` — Import results map to messages: SUCCESS refreshes the adapter and shows 'Habits imported.'; NOT_RECOGNIZED shows 'File not recognized.'; anything else shows 'Failed to import data.'
7. `list-habits.data-io-actions#7` — The ListHabitsBehavior.Message enum has exactly six values: COULD_NOT_EXPORT, IMPORT_SUCCESSFUL, IMPORT_FAILED, DATABASE_REPAIRED, COULD_NOT_GENERATE_BUG_REPORT, FILE_NOT_RECOGNIZED.

## Domain: Show habit screen and its cards

#### show-habit.screen-scaffold

- [ ] `show-habit.screen-scaffold` — Show habit screen: loading, toolbar, refresh lifecycle
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`, `.../ShowHabitView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabit.kt`, `uhabits-android/src/main/res/layout/show_habit.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`, `.../activities/AndroidThemeSwitcher.kt`, `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentFactory.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`, `.../acceptance/steps/CommonSteps.kt`
- **Notes:** Acceptance test identifies the screen by the presence of the subtitleCard view. Manifest declares ListHabitsActivity as the parent activity for Up navigation.

1. `show-habit.screen-scaffold#1` — The screen is opened with an intent whose data URI is "content://org.isoron.uhabits/habit/<id>" (Habit.uriString); the habit is resolved by parsing the trailing id and calling habitList.getById(id).
2. `show-habit.screen-scaffold#2` — If getById returns null the code dereferences null (`!!`) and crashes: there is NO 'habit not found' empty state on this screen.
3. `show-habit.screen-scaffold#3` — The whole ShowHabitState is rebuilt from scratch on every refresh by ShowHabitPresenter.buildState(habit, preferences, theme); there is no incremental/partial card update.
4. `show-habit.screen-scaffold#4` — refresh() is invoked: (1) in onResume, (2) on every CommandRunner.onCommandFinished(command) for ANY command, (3) after the Randomize menu action, (4) after any card spinner selection change.
5. `show-habit.screen-scaffold#5` — refresh() runs on the main dispatcher via a coroutine scope created with Dispatchers.Main.
6. `show-habit.screen-scaffold#6` — onResume registers the screen as a CommandRunner.Listener; onPause dismisses the currently open dialog and unregisters the listener.
7. `show-habit.screen-scaffold#7` — On onResume, if a dialog fragment tagged "historyEditor" is still present, its OnDateClickedListener is re-attached to the screen's HistoryCardPresenter so the reopened dialog remains interactive after a configuration change.
8. `show-habit.screen-scaffold#8` — Toolbar title equals habit.name exactly (no truncation logic in code).
9. `show-habit.screen-scaffold#9` — Toolbar background colour is theme.color(habit.color) when the theme attribute useHabitColorAsPrimary is true, otherwise the theme's colorPrimary; the window status bar colour is set to the same value; the Up (home-as-up) button is enabled.
10. `show-habit.screen-scaffold#10` — ShowHabitState defaults are title="", isNumerical=false, color=PaletteColor(1); in practice buildState always overrides them from the habit.
11. `show-habit.screen-scaffold#11` — The theme passed into every card state is LightTheme, DarkTheme or PureBlackTheme depending on the preference pref_theme plus system dark mode (system dark detection only on API >= 29; below that it always resolves to light).
12. `show-habit.screen-scaffold#12` — Content is a vertically scrolling list (ScrollView) below a fixed toolbar; bottom window insets are applied to the card list and toolbar insets to the toolbar.

#### show-habit.card-order-and-visibility

- [ ] `show-habit.card-order-and-visibility` — Card order and per-habit-type card visibility
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitView.kt`, `uhabits-android/src/main/res/layout/show_habit.xml`, `uhabits-android/src/main/res/values/styles.xml`, `uhabits-android/src/main/res/values/styles_show_habit.xml`
- **Kotlin tests:** none — write Dart test from rules

1. `show-habit.card-order-and-visibility#1` — Cards appear in this exact top-to-bottom order: Subtitle, Notes, Overview, Target, Score, Bar, History, Streak, Frequency.
2. `show-habit.card-order-and-visibility#2` — When habit.isNumerical is true the Overview card is hidden (GONE) and the Target card is shown; when false the Target card is hidden and the Overview card is shown.
3. `show-habit.card-order-and-visibility#3` — Visibility is only ever set to GONE in setState, never back to VISIBLE, so a card hidden for the habit type stays hidden for the life of the screen.
4. `show-habit.card-order-and-visibility#4` — The Notes card additionally hides itself whenever habit.description is empty, independently of habit type.
5. `show-habit.card-order-and-visibility#5` — All cards except Subtitle use the 'Card' style: match_parent width, vertical orientation, 16dp top and bottom padding, 1dp bottom margin, 1dp elevation, cardBgColor background; the History card overrides paddingBottom to 0dp.
6. `show-habit.card-order-and-visibility#6` — The Subtitle card uses headerBackgroundColor background, 2dp elevation, 60dp left/right padding, 15dp top padding, 10dp bottom padding.
7. `show-habit.card-order-and-visibility#7` — Fixed card chart heights: Score chart 220dp, Bar chart 220dp, History chart 160dp, Target chart 300dp, Frequency chart 200dp; the Streak chart is wrap_content (baseSize per streak row).

#### show-habit.subtitle-card

- [ ] `show-habit.subtitle-card` — Subtitle card (question, target, frequency, reminder)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/SubtitleCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/SubtitleCardView.kt`, `uhabits-android/src/main/res/layout/show_habit_subtitle.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DateExtensions.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/show/views/SubtitleCardViewTest.kt`
- **Notes:** FontAwesome glyph font is an Android asset; needs an icon-font or vector-icon equivalent in Flutter.

1. `show-habit.subtitle-card#1` — State is built directly from the habit: color, frequency, isNumerical, question, reminder, targetValue, targetType, unit. SubtitleCardState defaults are targetValue=0.0, targetType=AT_LEAST, unit="".
2. `show-habit.subtitle-card#2` — The question label shows habit.question tinted with theme.color(habit.color); it is set VISIBLE first and then set GONE when habit.question is empty.
3. `show-habit.subtitle-card#3` — Frequency text follows formatFrequency(num, den) exactly, in this order: num==1 && (den==30||den==31) -> "Every month"; den==30||den==31 -> "%d times per month" with num; num==1 && den==1 -> "Every day"; num==1 && den==7 -> "Every week"; num==1 && den>1 -> "Every %d days" with den; den==7 -> "%d times per week" with num; otherwise "%d times in %d days" with (num, den).
4. `show-habit.subtitle-card#4` — Frequency(numerator, denominator) normalises numerator==denominator to Frequency(1,1), so 7/7 renders as "Every day".
5. `show-habit.subtitle-card#5` — Reminder text is the reminder's hour:minute formatted with the system 12h/24h time format (rendered in UTC from hour*60+minute minutes since midnight); when habit.reminder is null the text is "Off".
6. `show-habit.subtitle-card#6` — Target icon and target text are visible only when habit.isNumerical; for boolean habits both are GONE.
7. `show-habit.subtitle-card#7` — Target text is exactly "<targetValue.toShortString()> <unit>" (single space separator), limited to maxEms=7, one line, ellipsized at the end.
8. `show-habit.subtitle-card#8` — Target icon glyph is FontAwesome arrow-circle-up (fa_arrow_circle_up) when targetType == AT_LEAST and arrow-circle-down (fa_arrow_circle_down) for AT_MOST.
9. `show-habit.subtitle-card#9` — The frequency icon is fa_calendar and the reminder icon is fa_bell_o; all three icons use the FontAwesome typeface.
10. `show-habit.subtitle-card#10` — Question label uses regularTextSize; target/frequency/reminder labels use smallTextSize and colour contrast60; the target icon uses 16sp.

#### show-habit.notes-card

- [ ] `show-habit.notes-card` — Notes card (habit description)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/NotesCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/NotesCardView.kt`, `uhabits-android/src/main/res/layout/show_habit_notes.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/show/views/NotesCardViewTest.kt`

1. `show-habit.notes-card#1` — NotesCardState carries a single field: description = habit.description.
2. `show-habit.notes-card#2` — The card view is set GONE when description is the empty string and VISIBLE otherwise.
3. `show-habit.notes-card#3` — When visible the description is rendered verbatim as plain text in contrast100 colour; no markdown, links or formatting is applied.
4. `show-habit.notes-card#4` — setState always calls invalidate() after updating.

#### show-habit.overview-card

- [ ] `show-habit.overview-card` — Overview card (score ring, month/year delta, total)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/OverviewCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/OverviewCardView.kt`, `uhabits-android/src/main/res/layout/show_habit_overview.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/RingView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ScoreList.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/show/views/OverviewCardViewTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`
- **Notes:** Acceptance test shouldToggleCheckmarksAndUpdateScore asserts the text "10%" appears on this screen after two long-press check marks.

1. `show-habit.overview-card#1` — scoreToday = habit.scores[getToday()].value as Float; scoreLastMonth = habit.scores[today.minus(30)].value; scoreLastYear = habit.scores[today.minus(365)].value.
2. `show-habit.overview-card#2` — ScoreList.get returns Score(date, 0.0) for any date without a computed score, so dates before the habit started give 0.
3. `show-habit.overview-card#3` — scoreMonthDiff = scoreToday - scoreLastMonth; scoreYearDiff = scoreToday - scoreLastYear.
4. `show-habit.overview-card#4` — totalCount = the number of entries in habit.originalEntries.getKnown() whose value == 2 (Entry.YES_MANUAL); YES_AUTO(1), NO(0), SKIP(3) and UNKNOWN(-1) are not counted.
5. `show-habit.overview-card#5` — The score label is String.format("%.0f%%", scoreToday * 100): 0.74 renders "74%", 0.005 renders "1%" (HALF_UP), 0.0 renders "0%".
6. `show-habit.overview-card#6` — Each diff label is String.format("%s%.0f%%", sign, abs(diff)*100) where sign is "+" when diff >= 0 and the Unicode MINUS SIGN U+2212 when diff < 0: +0.23 -> "+23%", -0.05 -> "−5%", 0.0 -> "+0%".
7. `show-habit.overview-card#7` — A diff label is coloured with theme.color(habit.color) when its diff >= 0 (including exactly 0) and with the contrast60 attribute colour when negative.
8. `show-habit.overview-card#8` — The title, score label and total-count label are always coloured with the habit colour; the four caption labels ("Score", "Month", "Year", "Total") use contrast60.
9. `show-habit.overview-card#9` — The total-count label text is totalCount.toString() (raw integer, no abbreviation or grouping).
10. `show-habit.overview-card#10` — The ring view is 30dp square, 5dp thick, 12sp text, and receives percentage = scoreToday with default precision 0.01, so the drawn sweep angle is 360 * round(percentage / 0.01) * 0.01 degrees starting at -90 degrees (12 o'clock), with the remainder drawn in the inactive colour (contrast100 at 15% alpha).
11. `show-habit.overview-card#11` — Layout is a horizontal row with weights 5 (ring), 4 (Score), 4 (Month), 4 (Year), 4 (Total).
12. `show-habit.overview-card#12` — The whole card is hidden for numerical habits.

#### show-habit.target-card

- [ ] `show-habit.target-card` — Target card (numerical habits only)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/TargetCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/TargetCardView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/TargetChart.kt`, `uhabits-android/src/main/res/layout/show_habit_target.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `show-habit.target-card#1` — entries = habit.computedEntries.getByInterval(oldest, today) where oldest = habit.computedEntries.getKnown().lastOrNull()?.date ?: today (getKnown is newest-first, so lastOrNull is the OLDEST known entry); the list is newest-first with one entry per day.
2. `show-habit.target-card#2` — valueToday / valueThisWeek / valueThisMonth / valueThisQuarter / valueThisYear = the value of the FIRST bucket of entries.groupedSum(field, firstWeekdayInt, isNumerical) for fields DAY, WEEK_NUMBER, MONTH, QUARTER, YEAR respectively, or 0 when the list is empty.
3. `show-habit.target-card#3` — groupedSum for numerical habits maps SKIP(3) to 0 and every other value to max(0, value) (so UNKNOWN=-1 becomes 0); for boolean habits it maps YES_MANUAL(2) to 1000 and everything else to 0; it then sums per truncated bucket and returns buckets sorted newest-first.
4. `show-habit.target-card#4` — skippedDays for each period = the first bucket of entries.countSkippedDays(field, firstWeekdayInt), i.e. the number of days in that period whose value == 3 (SKIP).
5. `show-habit.target-card#5` — dailyTarget = habit.targetValue / habit.frequency.denominator.
6. `show-habit.target-card#6` — targetToday = dailyTarget.
7. `show-habit.target-card#7` — targetThisWeek = habit.targetValue when denominator == 7, otherwise dailyTarget * 7.
8. `show-habit.target-card#8` — targetThisMonth = habit.targetValue when denominator == 30; habit.targetValue * (today.monthLength / 7, integer division, which is always 4) when denominator == 7; otherwise dailyTarget * today.monthLength.
9. `show-habit.target-card#9` — targetThisQuarter = habit.targetValue * 3 when denominator == 30; habit.targetValue * 13 when denominator == 7; otherwise dailyTarget * 91.
10. `show-habit.target-card#10` — targetThisYear = habit.targetValue * 12 when denominator == 30; habit.targetValue * 52 when denominator == 7; otherwise dailyTarget * today.yearLength (366 in leap years).
11. `show-habit.target-card#11` — Every target is then reduced for skipped days: target = max(0.0, target - dailyTarget * skippedDaysInThatPeriod).
12. `show-habit.target-card#12` — values[i] = periodValue / 1000.0 (entry values are stored in thousandths).
13. `show-habit.target-card#13` — Rows included: the Today row only when habit.frequency.denominator <= 1; the Week row only when denominator <= 7; Month, Quarter and Year rows always. values, targets and intervals are three parallel lists built with the same filter.
14. `show-habit.target-card#14` — intervals are the integers 1, 7, 30, 91, 365 (filtered as above) and map to labels: 1 -> "Today", 7 -> "Week", 30 -> "Month", 91 -> "Quarter", anything else -> "Year".
15. `show-habit.target-card#15` — Each row draws a rounded background bar; fill fraction = min(1.0, value / target) when target > 0, and 1.0 when target <= 0.
16. `show-habit.target-card#16` — A non-zero fill narrower than 2 * 2dp is widened to 2 * 2dp so it stays visible.
17. `show-habit.target-card#17` — The completed value text = value.toShortString() drawn centred in the filled part, and only if the filled width exceeds the text width + 8dp; the remaining text = (target - value).toShortString() drawn centred in the empty part under the same width condition. Remaining may be negative (e.g. "-3.5").
18. `show-habit.target-card#18` — The card title is "Target"; the title and the filled bar use theme.color(habit.color); the empty bar uses contrast20 and labels use contrast60.
19. `show-habit.target-card#19` — The chart is 300dp tall and rows split that height evenly (baseSize = height / rowCount).
20. `show-habit.target-card#20` — The card is hidden for boolean habits.

#### show-habit.score-card

- [ ] `show-habit.score-card` — Score card and its day/week/month/quarter/year spinner
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/ScoreCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/ScoreCardView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/ScoreChart.kt`, `.../ScrollableChart.kt`, `uhabits-android/src/main/res/layout/show_habit_score.xml`, `uhabits-android/src/main/res/values/constants.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/show/views/ScoreCardViewTest.kt`, `.../activities/common/views/ScoreChartTest.kt`, `.../acceptance/steps/CommonSteps.kt`

1. `show-habit.score-card#1` — ScoreCardPresenter.BUCKET_SIZES = [1, 7, 31, 92, 365] indexed by spinner position 0..4; the spinner entries are "Day", "Week", "Month", "Quarter", "Year".
2. `show-habit.score-card#2` — The selected position is persisted in preference key "pref_score_view_interval", default 1 (Week), and clamped on read with min(4, max(0, stored)).
3. `show-habit.score-card#3` — getTruncateField(bucketSize): 1 -> DAY, 7 -> WEEK_NUMBER, 31 -> MONTH, 92 -> QUARTER, 365 -> YEAR, any other value -> MONTH.
4. `show-habit.score-card#4` — scores = habit.scores.getByInterval(oldest, today) grouped by truncated date, where oldest = the oldest known computed entry date or today; each group becomes Score(truncatedDate, arithmetic mean of the daily values in the group); the result is sorted ascending by date and then reversed, i.e. NEWEST bucket first.
5. `show-habit.score-card#5` — Week truncation uses date.startOfWeek(DayOfWeek.entries[firstWeekdayInt - 1]) where firstWeekdayInt is 1=Sunday .. 7=Saturday; startOfWeek subtracts ((dayOfWeek.daysSinceSunday - firstWeekday.daysSinceSunday) mod 7) days.
6. `show-habit.score-card#6` — Month truncation -> first day of month, Quarter -> first day of the quarter (month = ((month-1)/3)*3+1), Year -> January 1st, Day -> the date itself.
7. `show-habit.score-card#7` — Selecting a spinner position calls preferences.scoreCardSpinnerPosition = position, then screen.updateWidgets(), then screen.refresh(); Android also fires this when the spinner is programmatically set during setState, so a refresh loop through the same value is expected.
8. `show-habit.score-card#8` — setState calls setSelection(spinnerPosition), setScores, reset() (rewinds horizontal scroll to the newest bucket) and setBucketSize, then colours the chart and title with theme.color(habit.color).
9. `show-habit.score-card#9` — The chart draws 5 horizontal grid rows labelled "100%", "80%", "60%", "40%", "20%" (formula 100 - i*100/5 for i in 0..4) and the plot area is 8*baseSize tall, so a score of 1.0 reaches the top row.
10. `show-habit.score-card#10` — Footer labels: the year is printed when it changes from the previous column, but skipped when bucketSize >= 365 and the year is odd, and skipped for one column immediately after a year was printed; when bucketSize < 365 the short month name is printed when the month changes, otherwise the day number.
11. `show-habit.score-card#11` — The card title is "Score" and the chart is 220dp tall.
12. `show-habit.score-card#12` — Horizontal drag/fling scrolls the chart by whole columns; dataOffset is clamped to >= 0 (cannot scroll into the future) and <= 2400 by default.

#### show-habit.bar-card

- [ ] `show-habit.bar-card` — Bar card and its two bucket spinners
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/BarCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/BarCardView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/BarChart.kt`, `uhabits-android/src/main/res/layout/show_habit_bar.xml`, `uhabits-android/src/main/res/values/constants.xml`, `uhabits-android/src/main/java/org/isoron/platform/gui/AndroidDataView.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `show-habit.bar-card#1` — BarCardPresenter.numericalBucketSizes = [1, 7, 31, 92, 365]; BarCardPresenter.boolBucketSizes = [7, 31, 92, 365].
2. `show-habit.bar-card#2` — For numerical habits the bucket size is numericalBucketSizes[numericalSpinnerPosition], the numerical spinner shows "Day","Week","Month","Quarter","Year" and the boolean spinner is GONE.
3. `show-habit.bar-card#3` — For boolean habits the bucket size is boolBucketSizes[boolSpinnerPosition], the boolean spinner shows "Week","Month","Quarter","Year" (no Day option) and the numerical spinner is GONE.
4. `show-habit.bar-card#4` — Preference keys and defaults: "pref_bar_card_numerical_spinner" default 0, clamped min(4, max(0, x)); "pref_bar_card_bool_spinner" default 0, clamped min(3, max(0, x)).
5. `show-habit.bar-card#5` — entries = habit.computedEntries.getByInterval(oldest, today).groupedSum(truncateField = ScoreCardPresenter.getTruncateField(bucketSize), firstWeekday = preferences.firstWeekdayInt, isNumerical = habit.isNumerical); oldest is the oldest known computed entry date, or today when there are none.
6. `show-habit.bar-card#6` — The chart plots one series of entry.value / 1000.0 with axis = entry dates (newest first) coloured theme.color(habit.color.paletteIndex).
7. `show-habit.bar-card#7` — setState assigns a brand new BarChart and then calls resetDataOffset(), so every refresh scrolls the bar chart back to the most recent bucket.
8. `show-habit.bar-card#8` — The y scale is max(largest series value, 1.0); there are 6 grid lines and bars whose value is <= 0 are not drawn at all.
9. `show-habit.bar-card#9` — Each bar is labelled above with the core toShortString() of its value.
10. `show-habit.bar-card#10` — Bar geometry: barWidth 12, barMargin 3, barGroupMargin 4, paddingTop 20, footerHeight 40; a group is 2*4 + nSeries*(12 + 2*3) wide and the column count is floor(availableWidth / groupWidth).
11. `show-habit.bar-card#11` — Axis labelling: 'large interval' mode (only the year is printed) is selected when axis.size < 2 || axis[0].daysUntil(axis[1]) > 300 — because the axis is newest-first that difference is negative, so in practice only an axis with fewer than 2 points takes that branch; otherwise the short month name is printed when the month differs from the previous column, else the day number, and the year is printed on a second line when the year changes.
12. `show-habit.bar-card#12` — The card title uses the string resource R.string.history whose value is "History" (not "Bar"), and is coloured with the habit colour.
13. `show-habit.bar-card#13` — The chart is 220dp tall and can be scrolled horizontally by whole bar groups with dataOffset clamped to >= 0.

#### show-habit.history-card

- [ ] `show-habit.history-card` — History (calendar) card rendering
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/HistoryCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/HistoryCardView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HistoryChart.kt`, `uhabits-android/src/main/res/layout/show_habit_history.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/show/views/HistoryCardViewTest.kt`, `.../acceptance/steps/CommonSteps.kt`

1. `show-habit.history-card#1` — entries = habit.computedEntries.getByInterval(oldest, today), newest first, one entry per day, where oldest is the oldest known computed entry date or today when none exist.
2. `show-habit.history-card#2` — For NUMERICAL habits each entry maps to a square in this priority order: value == -1 (UNKNOWN) -> OFF; value == 3 (SKIP) -> HATCHED; targetType == AT_MOST && value/1000.0 <= habit.targetValue -> ON; targetType == AT_LEAST && value/1000.0 >= habit.targetValue -> ON; otherwise GREY.
3. `show-habit.history-card#3` — For BOOLEAN habits: 2 (YES_MANUAL) -> ON; 1 (YES_AUTO) -> DIMMED; 3 (SKIP) -> HATCHED; everything else (0 NO and -1 UNKNOWN) -> OFF.
4. `show-habit.history-card#4` — notesIndicators[i] is true exactly when entries[i].notes is not the empty string.
5. `show-habit.history-card#5` — defaultSquare is OFF and is used for every grid cell whose offset is beyond the end of the series.
6. `show-habit.history-card#6` — Square colours: ON -> theme.color(habit.color); OFF -> lowContrastTextColor; GREY -> mediumContrastTextColor; DIMMED and HATCHED -> the habit colour blended 50% with the card background.
7. `show-habit.history-card#7` — HATCHED squares additionally get 5 diagonal hatch lines in the card background colour, stroke width 0.75.
8. `show-habit.history-card#8` — Each square is a rounded rect with corner radius = width * 0.15 and 1.0 spacing between squares; the day-of-month number is drawn centred inside, in whichever of cardBackgroundColor / mediumContrastTextColor has the higher contrast against the square colour.
9. `show-habit.history-card#9` — When an entry has notes, a filled circle of radius width/12 is drawn in the square's top-right corner (at x + width - width/5, y + width/5); its colour is lowContrastTextColor for ON and GREY squares and the habit colour otherwise.
10. `show-habit.history-card#10` — Grid layout: squares are squareSize = round((height - 2*padding)/8); rows 1..7 are the 7 weekdays starting from preferences.firstWeekday; row 0 is the month/year header; short weekday names are drawn in a column on the right.
11. `show-habit.history-card#11` — Column headers print the short month name when it differs from the previously printed month, else the year when the year differs, else nothing.
12. `show-habit.history-card#12` — The top-left date = today.minus((nColumns - 1 + dataOffset) * 7 + ((today.dayOfWeek.daysSinceSunday - firstWeekday.daysSinceSunday + 7) % 7)).
13. `show-habit.history-card#13` — The card title is "Calendar" (R.string.calendar) coloured with the habit colour; the chart is 160dp tall.
14. `show-habit.history-card#14` — A borderless button labelled "Edit" (grey_400, smallTextSize) is centred below the chart and opens the history editor dialog.

#### show-habit.history-interaction

- [ ] `show-habit.history-interaction` — Tapping a day in the history card
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/HistoryCard.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HistoryChart.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CreateRepetitionCommand.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`, `uhabits-android/src/main/java/org/isoron/platform/gui/AndroidDataView.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Haptic feedback is platform-specific (HapticFeedback.vibrate in Flutter). (Merged duplicate id: `commands.dispatch-history-card`.)

1. `show-habit.history-interaction#1` — Hit testing: col = floor((x - padding) / squareSize), row = floor((y - padding) / squareSize), offset = col*7 + (row - 1); the tap is ignored when (x - padding) < 0, or row == 0 (header), or row > 7, or col == nColumns.
2. `show-habit.history-interaction#2` — clickedDate = topLeftDate.plus(offset); the tap is ignored when clickedDate is newer than today (future days are not editable).
3. `show-habit.history-interaction#3` — Every accepted press first triggers haptic feedback (HapticFeedbackConstants.VIRTUAL_KEY on the window decor view).
4. `show-habit.history-interaction#4` — For NUMERICAL habits both short press and long press open the number popup.
5. `show-habit.history-interaction#5` — For BOOLEAN habits with preferences.isShortToggleEnabled == true: short press toggles the value directly and long press opens the check-mark popup.
6. `show-habit.history-interaction#6` — For BOOLEAN habits with isShortToggleEnabled == false (default): short press opens the check-mark popup and long press toggles directly.
7. `show-habit.history-interaction#7` — Direct toggle computes Entry.nextToggleValue(currentValue, isSkipEnabled, areQuestionMarksEnabled) with the cycle: YES_AUTO(1) -> YES_MANUAL(2); YES_MANUAL(2) -> SKIP(3) if isSkipEnabled else NO(0); SKIP(3) -> NO(0); NO(0) -> UNKNOWN(-1) if areQuestionMarksEnabled else YES_MANUAL(2); UNKNOWN(-1) -> YES_MANUAL(2); any other value -> YES_MANUAL(2).
8. `show-habit.history-interaction#8` — Toggling preserves the existing entry.notes and runs CreateRepetitionCommand(habitList, habit, date, newValue, notes).
9. `show-habit.history-interaction#9` — The number popup is seeded with entry.value / 1000.0 and entry.notes; when the user confirms, the stored value is (enteredValue * 1000).roundToInt() and a CreateRepetitionCommand is run with the new notes.
10. `show-habit.history-interaction#10` — The check-mark popup is seeded with entry.value, entry.notes and the habit colour; its callback runs CreateRepetitionCommand with the chosen value and notes.
11. `show-habit.history-interaction#11` — CreateRepetitionCommand adds Entry(date, value, notes) to habit.originalEntries, calls habit.recompute() and habitList.resort(); the finished command triggers a full screen refresh through the CommandRunner listener.
12. `show-habit.history-interaction#12` — The current entry value is read from habit.computedEntries.get(date), which returns Entry(date, UNKNOWN=-1) when nothing is recorded for that day.
13. `show-habit.history-interaction#13` — `HistoryCardPresenter` implements OnDateClickedListener and always calls `screen.showFeedback()` first on both short and long press.

#### show-habit.streak-card

- [ ] `show-habit.streak-card` — Best streaks card
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/StreakCart.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/StreakCardView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/StreakChart.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/StreakList.kt`, `.../models/Streak.kt`, `uhabits-android/src/main/res/layout/show_habit_streak.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/show/views/StreakCardViewTest.kt`

1. `show-habit.streak-card#1` — bestStreaks = habit.streaks.getBest(10).
2. `show-habit.streak-card#2` — getBest first sorts ALL streaks descending by compareLonger (longer first; ties broken by the newer end date first), takes the first min(size, 10), then re-sorts that sub-list descending by compareNewer, so the displayed order is newest-ending first among the ten longest streaks.
3. `show-habit.streak-card#3` — Streak.length = start.daysUntil(end) + 1 (inclusive of both endpoints).
4. `show-habit.streak-card#4` — Streaks are recomputed from computedEntries: a day counts when value > 0 for boolean habits; for numerical AT_LEAST when value/1000.0 >= targetValue; for numerical AT_MOST when value != UNKNOWN and value/1000.0 <= targetValue. Consecutive qualifying days form one streak.
5. `show-habit.streak-card#5` — Each row draws a horizontal bar whose width fraction = streak.length / maxLength (of the displayed set), centred, and never narrower than the width of the length label plus one em.
6. `show-habit.streak-card#6` — Bar colour by fraction: >= 1.0 the full habit colour; >= 0.8 the habit colour at alpha 192; >= 0.5 the habit colour at alpha 96; below 0.5 the contrast20 colour.
7. `show-habit.streak-card#7` — The bar label is the streak length as a plain integer, coloured contrast0 when fraction >= 0.5 and contrast60 otherwise.
8. `show-habit.streak-card#8` — Start and end dates are drawn in the locale long format to the left and right of the bar, but only when (viewWidth - 2*maxLabelWidth) >= viewWidth * 0.25; otherwise both labels are omitted.
9. `show-habit.streak-card#9` — Row height = R.dimen.baseSize and the view's height is streakCount * baseSize (wrap_content).
10. `show-habit.streak-card#10` — The card title is "Best streaks" coloured with the habit colour.
11. `show-habit.streak-card#11` — When the streak list is empty nothing is drawn (an empty card body).

#### show-habit.frequency-card

- [ ] `show-habit.frequency-card` — Frequency card (weekday x month bubble chart)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/FrequencyCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/FrequencyCardView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/FrequencyChart.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`, `uhabits-android/src/main/res/layout/show_habit_frequency.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/show/views/FrequencyCardViewTest.kt`

1. `show-habit.frequency-card#1` — frequency = habit.originalEntries.computeWeekdayFrequency(isNumerical) — it is built from ORIGINAL entries, so YES_AUTO days created by the frequency rules are never counted.
2. `show-habit.frequency-card#2` — The map key is the entry date's startOfMonth(); the value is an Int array of length 7 indexed by (date.dayOfWeek.daysSinceSunday + 1) % 7, i.e. index 0 = Saturday, 1 = Sunday, 2 = Monday, ... 6 = Friday.
3. `show-habit.frequency-card#3` — For boolean habits the counter is incremented by 1 only when the entry value == 2 (YES_MANUAL); for numerical habits the raw entry value (thousandths) is added, so SKIP adds 3 and UNKNOWN subtracts 1.
4. `show-habit.frequency-card#4` — Months with no known entries are absent from the map and their column draws no bubbles.
5. `show-habit.frequency-card#5` — maxFreq = the maximum value across the whole map, floored at 1.
6. `show-habit.frequency-card#6` — Bubble radius = maxRadius * (max(0, value) / scalingFactor), where scalingFactor = maxFreq for numerical habits and the number of occurrences of that weekday in that month (countWeekdayOccurrencesInMonth) for boolean habits; maxRadius = (rowHeight - 2*0.2*rowHeight)/2.
7. `show-habit.frequency-card#7` — Bubble colour index = min(3, round(3 * scale)) over the palette [contrast20, mix(contrast20, habitColor, 0.66), mix(contrast20, habitColor, 0.33), habitColor].
8. `show-habit.frequency-card#8` — Rows are the 7 weekdays in the order produced by getWeekdaySequence(preferences.firstWeekday); short weekday names are drawn in the rightmost column and horizontal grid lines separate rows.
9. `show-habit.frequency-card#9` — The footer under each column shows the short month name, and additionally the 4-digit year on a second line when the month number is 2 (February).
10. `show-habit.frequency-card#10` — Columns advance one calendar month at a time starting from the current month minus (nColumns - 2 + dataOffset) months; the chart is horizontally scrollable and its scroll position is NOT reset on refresh.
11. `show-habit.frequency-card#11` — Chart height is 200dp with baseSize = height/8 (7 weekday rows + 1 footer row).
12. `show-habit.frequency-card#12` — The card title is "Frequency" coloured with the habit colour.

#### show-habit.menu

- [ ] `show-habit.menu` — Overflow menu contents and visibility rules
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitMenu.kt`, `uhabits-android/src/main/res/menu/show_habit.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`

1. `show-habit.menu#1` — The menu contains, in this declaration order: Export, Archive, Unarchive, Delete, Edit, Randomize.
2. `show-habit.menu#2` — Only Edit is shown as an action button (showAsAction="ifRoom", icon ?iconEdit); Export, Archive, Unarchive, Delete and Randomize are overflow-only (showAsAction="never").
3. `show-habit.menu#3` — The Archive item is visible only when the habit is NOT archived (canArchive() == !habit.isArchived).
4. `show-habit.menu#4` — The Unarchive item is visible only when the habit IS archived (canUnarchive() == habit.isArchived).
5. `show-habit.menu#5` — The Randomize item is declared android:visible="false" and is made visible only when preferences.isDeveloper (pref_developer, default false) is true; its title is the untranslated literal "Randomize".
6. `show-habit.menu#6` — Menu titles: "Export", "Archive", "Unarchive", "Delete", "Edit".
7. `show-habit.menu#7` — onOptionsItemSelected returns true for the six known ids and false for anything else (so Up/home navigation falls through to the default handler).

#### show-habit.edit-action

- [ ] `show-habit.edit-action` — Edit habit from the show screen
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentFactory.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenterTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`
- **Notes:** Covered by acceptance test shouldEditHabit_fromStatisticsScreen and unit test testOnEditHabit.

1. `show-habit.edit-action#1` — Selecting Edit calls ShowHabitMenuPresenter.onEditHabit(), which calls screen.showEditHabitScreen(habit) and nothing else (no command, no state change).
2. `show-habit.edit-action#2` — The edit screen is started with an intent carrying the long extra "habitId" = habit.id and the extra "habitType" = habit.type.
3. `show-habit.edit-action#3` — The show screen is NOT finished; after saving the edit the user returns to the show screen, and onResume + the finished command both trigger a full refresh, so the new name, colour (toolbar and all cards) and question are visible immediately.
4. `show-habit.edit-action#4` — Pressing Back from the refreshed show screen returns to the habit list, which also shows the updated name.

#### show-habit.archive-unarchive

- [ ] `show-habit.archive-unarchive` — Archive / unarchive from the show screen
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/ArchiveHabitsCommand.kt`, `.../UnarchiveHabitsCommand.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`

1. `show-habit.archive-unarchive#1` — Archive runs ArchiveHabitsCommand(habitList, listOf(habit)), which sets habit.isArchived = true and calls habitList.update(list), then shows the message HABIT_ARCHIVED.
2. `show-habit.archive-unarchive#2` — Unarchive runs UnarchiveHabitsCommand(habitList, listOf(habit)), which sets habit.isArchived = false and calls habitList.update(list), then shows the message HABIT_UNARCHIVED.
3. `show-habit.archive-unarchive#3` — HABIT_ARCHIVED renders the quantity-1 string "Habit archived"; HABIT_UNARCHIVED renders "Habit unarchived"; both are shown as a short Snackbar with white text at the bottom of the screen.
4. `show-habit.archive-unarchive#4` — Neither action closes the screen; the finished command triggers a refresh and the menu keeps the stale Archive/Unarchive visibility until the options menu is rebuilt.
5. `show-habit.archive-unarchive#5` — Messages are shown via Activity.showMessage, which swallows IllegalArgumentException (no suitable parent view) and shows nothing in that case.

#### show-habit.delete

- [ ] `show-habit.delete` — Delete habit from the show screen
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/DeleteHabitsCommand.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/ConfirmDeleteDialog.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`

1. `show-habit.delete#1` — Selecting Delete first opens a confirmation AlertDialog titled "Delete habit?" with the message "The habit will be permanently deleted. This action cannot be undone." and buttons "Yes" (positive) and "No" (negative).
2. `show-habit.delete#2` — Pressing "No" (or dismissing) does nothing at all: no command is run and the screen stays open.
3. `show-habit.delete#3` — Pressing "Yes" runs DeleteHabitsCommand(habitList, listOf(habit)), which calls habitList.remove(habit) for the habit, and then immediately closes (finishes) the show screen, returning to the habit list where the habit no longer appears.
4. `show-habit.delete#4` — The confirmation dialog is shown with dismissCurrentAndShow, dismissing any other tracked dialog first.
5. `show-habit.delete#5` — The quantity used for the plural strings is always 1 on this screen.

#### show-habit.export-csv

- [ ] `show-habit.export-csv` — Export this habit as CSV from the show screen
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/ExportCSVTask.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/HabitsDirFinder.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenterTest.kt`
- **Notes:** FileProvider + ACTION_SEND has no direct Flutter equivalent; needs share_plus / path_provider and per-platform file sharing. Unit test testOnExport asserts exactly one file is written to the output dir.

1. `show-habit.export-csv#1` — Selecting Export runs ExportCSVTask(habitList, listOf(habit), outputDir, callback) on the app's TaskRunner, exporting ONLY the habit currently shown.
2. `show-habit.export-csv#2` — outputDir is the app-private files subdirectory named "CSV".
3. `show-habit.export-csv#3` — The archive file is named "Loop Habits CSV <today>.zip" where <today> is getToday().toCSVString(), i.e. zero-padded YYYY-MM-DD.
4. `show-habit.export-csv#4` — On success the callback receives the archive path and the screen launches a share sheet: ACTION_SEND, type "application/zip", EXTRA_STREAM = a FileProvider URI for authority "org.isoron.uhabits", flag FLAG_GRANT_READ_URI_PERMISSION.
5. `show-habit.export-csv#5` — If no activity can handle the share intent, the message "Could not find an application to handle this action" style fallback is shown via startActivitySafely (R.string.activity_not_found).
6. `show-habit.export-csv#6` — Any exception during export is swallowed (stack trace printed) and the callback receives null, in which case the message COULD_NOT_EXPORT is shown as the snackbar "Failed to export data."
7. `show-habit.export-csv#7` — Exactly one file is produced in the output directory per export.

#### show-habit.randomize

- [ ] `show-habit.randomize` — Randomize entries (developer-only menu action)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitMenu.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `show-habit.randomize#1` — The action is reachable only when preferences.isDeveloper is true.
2. `show-habit.randomize#2` — onRandomize clears habit.originalEntries entirely, then loops i from 0 to 365*5 - 1 = 1824 (five years of days ending today).
3. `show-habit.randomize#3` — A 'strength' variable starts at 50.0 and, every time i % 7 == 0, is updated to max(0.0, min(100.0, strength + 10 * gaussian)) where gaussian is a Box-Muller sample: sqrt(-2*ln(u1)) * cos(2*PI*u2) with u1, u2 uniform in [0,1).
4. `show-habit.randomize#4` — For each i, if Random.nextInt(100) > strength the day is skipped (no entry added).
5. `show-habit.randomize#5` — Otherwise the value is 2 (YES_MANUAL) for boolean habits, and for numerical habits it is (1000 + 250 * gaussian * strength / 100).toInt() * 1000.
6. `show-habit.randomize#6` — The entry is added at getToday().minus(i).
7. `show-habit.randomize#7` — After the loop habit.recompute() is called and then screen.refresh(), so all cards redraw with the generated data.
8. `show-habit.randomize#8` — No command is run, so the change is not undoable and other listeners are not notified.

#### show-habit.widget-refresh

- [ ] `show-habit.widget-refresh` — Widget refresh triggered by bucket spinner changes
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/ScoreCard.kt`, `.../views/BarCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** App widgets / RemoteViews have no Flutter equivalent; requires a native home-screen widget implementation per platform.

1. `show-habit.widget-refresh#1` — Changing the Score card spinner, the Bar card numerical spinner or the Bar card boolean spinner calls screen.updateWidgets() BEFORE screen.refresh().
2. `show-habit.widget-refresh#2` — updateWidgets() delegates to the app's WidgetUpdater, which pushes new data to all home-screen app widgets; the spinner preferences are shared with the widgets so their bucket size changes too.
3. `show-habit.widget-refresh#3` — No other action on the show screen (edit, archive, delete, toggling a day) calls updateWidgets directly; those propagate through the CommandRunner instead.

#### show-habit.number-formatting

- [ ] `show-habit.number-formatting` — Number formatting used by the cards
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/NumberButton.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/NumberButtonView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/OverviewCardView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/TargetChart.kt`, `.../ScoreChart.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `show-habit.number-formatting#1` — Core toShortString() (used by the Bar chart bar labels): >=1e9 -> "%.1fG" of v/1e9; >=1e8 -> "%.0fM" of v/1e6; >=1e7 -> "%.1fM"; >=1e6 -> "%.1fM"; >=1e5 -> "%.0fk" of v/1e3; >=1e4 -> "%.1fk"; >=1e3 -> "%.1fk"; >=1e2 -> "%.0f"; >=1e1 -> "%.0f" when the value is a whole number else "%.1f"; below 10 -> "%.0f" when whole, "%.1f" when it has one decimal, otherwise "%.2f".
2. `show-habit.number-formatting#2` — Android toShortString() (used by the Subtitle target text and the Target chart labels) uses the same thresholds but formats the last three buckets with DecimalFormat: >=1e2 -> "#", >=1e1 -> "#.#", else "#.##" — note DecimalFormat rounds HALF_EVEN while String.format rounds HALF_UP, and negative values always fall into the final "#.##" branch.
3. `show-habit.number-formatting#3` — Overview score label: String.format("%.0f%%", score * 100).
4. `show-habit.number-formatting#4` — Overview month/year deltas: String.format("%s%.0f%%", sign, abs(delta) * 100) with sign "+" for delta >= 0 and U+2212 for delta < 0.
5. `show-habit.number-formatting#5` — Overview total: plain Long.toString() with no abbreviation.
6. `show-habit.number-formatting#6` — Score chart grid labels: String.format("%d%%", 100 - i*100/5) for i in 0..4.
7. `show-habit.number-formatting#7` — Streak chart bar labels: the streak length as a plain integer string.
8. `show-habit.number-formatting#8` — History chart square labels: the day-of-month as a plain integer string.
9. `show-habit.number-formatting#9` — All entry values are stored as integers in thousandths; user-facing values are value / 1000.0 and user input is stored as round(input * 1000).

#### show-habit.chart-scrolling

- [ ] `show-habit.chart-scrolling` — Horizontal scrolling of the show-screen charts
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/platform/gui/AndroidDataView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/ScrollableChart.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/BarCardView.kt`, `.../ScoreCardView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HistoryChart.kt`, `.../views/BarChart.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `show-habit.chart-scrolling#1` — The History and Bar charts are hosted in AndroidDataView: a horizontal drag or fling moves an internal scroller and dataOffset = max(0, scrollerX / (dataColumnWidth * density)), so scrolling right walks backwards in time and offset can never go below 0 (no scrolling into the future).
2. `show-habit.chart-scrolling#2` — The Score and Frequency charts extend ScrollableChart: dataOffset = clamp(scrollerX / bucketWidth, 0, maxDataOffset) with maxDataOffset defaulting to 12*200 = 2400 buckets.
3. `show-habit.chart-scrolling#3` — While a horizontal drag is in progress the chart requests that the parent ScrollView stops intercepting touch events, so the page does not scroll vertically at the same time.
4. `show-habit.chart-scrolling#4` — BarCardView.setState calls resetDataOffset() on every refresh, so the bar chart always jumps back to the most recent bucket after any data change.
5. `show-habit.chart-scrolling#5` — ScoreCardView.setState calls scoreView.reset() on every refresh, so the score chart also jumps back to the newest bucket.
6. `show-habit.chart-scrolling#6` — The Frequency chart does not reset, so its scroll position survives a refresh; ScrollableChart also saves x, y, dataOffset, direction and maxDataOffset in its instance state across configuration changes.
7. `show-habit.chart-scrolling#7` — HistoryCardView replaces the whole HistoryChart object on every setState, which resets its dataOffset field to 0.
8. `show-habit.chart-scrolling#8` — dataColumnWidth is squareSpacing + squareSize for the History chart and barWidth + 2*barMargin (12 + 6 = 18) for the Bar chart.
9. `show-habit.chart-scrolling#9` — A single tap is routed to onClick and a long press to onLongClick, with coordinates divided by the canvas inner density before being handed to the chart.

#### show-habit.theme-colors

- [ ] `show-habit.theme-colors` — Habit colour and theme applied across the cards
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Themes.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/PaletteColor.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/AndroidThemeSwitcher.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `show-habit.theme-colors#1` — Every card title, plus the score/total/diff labels, the ring, the target bar, the streak bars, the frequency bubbles, the bar chart bars and the ON history squares, is tinted with theme.color(habit.color).
2. `show-habit.theme-colors#2` — LightTheme palette indices 0..19 map to 0xD32F2F, 0xE64A19, 0xF57C00, 0xFF8F00, 0xF9A825, 0xAFB42B, 0x7CB342, 0x388E3C, 0x00897B, 0x00ACC1, 0x039BE5, 0x1976D2, 0x303F9F, 0x5E35B1, 0x8E24AA, 0xD81B60, 0x5D4037, 0x424242, 0x757575, 0x9E9E9E; any other index is black.
3. `show-habit.theme-colors#3` — DarkTheme palette indices 0..19 map to 0xEF9A9A, 0xFFAB91, 0xFFCC80, 0xFFECB3, 0xFFF59D, 0xE6EE9C, 0xC5E1A5, 0x69F0AE, 0x80CBC4, 0x80DEEA, 0x81D4FA, 0x64B5F6, 0x9FA8DA, 0xB39DDB, 0xCE93D8, 0xF48FB1, 0xBCAAA4, 0xF5F5F5, 0xE0E0E0, 0x9E9E9E; any other index is white.
4. `show-habit.theme-colors#4` — LightTheme neutrals: cardBackground 0xFAFAFA, lowContrastText 0xE0E0E0, mediumContrastText 0x9E9E9E, highContrastText 0x202020, appBackground 0xF4F4F4.
5. `show-habit.theme-colors#5` — DarkTheme neutrals: cardBackground 0x303030, lowContrastText 0x424242, mediumContrastText 0x9E9E9E, highContrastText 0xF5F5F5, appBackground 0x212121; PureBlackTheme overrides appBackground and cardBackground to 0x000000 and lowContrastText to 0x212121.
6. `show-habit.theme-colors#6` — Theme text sizes exposed to the charts: smallTextSize 10.0, regularTextSize 17.0.
7. `show-habit.theme-colors#7` — Habit.color defaults to PaletteColor(8) (teal) for a new habit.

## Domain: Create/edit habit screen and common dialogs

#### edit-habit.entry-points

- [ ] `edit-habit.entry-points` — Entering the create/edit habit screen
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentFactory.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitType.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`, `.../acceptance/steps/CommonSteps.kt`, `.../acceptance/steps/EditHabitSteps.kt`
- **Notes:** IntentFactory.startEditActivity(context, habit) puts habitId (Long) AND habitType as the *enum* (Serializable) under "habitType"; the enum value is never read because the habitId branch wins. IntentFactory.startEditActivity(context, habitTypeInt) puts only the Int.

1. `edit-habit.entry-points#1` — EditHabitActivity is entered with either an intent extra `habitId` (Long) meaning EDIT, or an intent extra `habitType` (Int) meaning CREATE; the presence of `habitId` is what selects EDIT mode (`intent.hasExtra("habitId")`).
2. `edit-habit.entry-points#2` — In CREATE mode the toolbar title is the string `create_habit` = "Create habit" (set as the layout default `app:title`); in EDIT mode it is replaced with `edit_habit` = "Edit habit".
3. `edit-habit.entry-points#3` — In CREATE mode habitType = HabitType.fromInt(intent.getIntExtra("habitType", HabitType.YES_NO.value)), i.e. defaults to YES_NO (value 0) when the extra is missing. NUMERICAL has value 1. HabitType.fromInt throws IllegalStateException for any int other than 0 or 1.
4. `edit-habit.entry-points#4` — In EDIT mode the habit is fetched by id from the habit list and the screen state is seeded from it: habitType = habit.type, color = habit.color, freqNum = habit.frequency.numerator, freqDen = habit.frequency.denominator, targetType = habit.targetType; nameInput = habit.name, questionInput = habit.question, notesInput = habit.description, unitInput = habit.unit, targetInput = habit.targetValue.toString() (so a target of 15.0 shows as the literal text "15.0").
5. `edit-habit.entry-points#5` — In EDIT mode, if habit.reminder is non-null then reminderHour = reminder.hour, reminderMin = reminder.minute, reminderDays = reminder.days; if it is null the defaults (-1, -1, EVERY_DAY) are kept.
6. `edit-habit.entry-points#6` — The habit TYPE cannot be changed from this screen: there is no UI control for it, and save() always writes back the habitType the screen was opened with.
7. `edit-habit.entry-points#7` — Entering EDIT mode for an id that is not in the habit list crashes (non-null assertion on `component.habitList.getById(habitId)!!`).
8. `edit-habit.entry-points#8` — The default in-memory field values before any seeding are: habitId = -1L, unit = "", color = PaletteColor(11) (blue), androidColor = 0, freqNum = 1, freqDen = 1, reminderHour = -1, reminderMin = -1, reminderDays = WeekdayList.EVERY_DAY, targetType = NumericalHabitType.AT_LEAST.
9. `edit-habit.entry-points#9` — Note the screen's default color PaletteColor(11) differs from the Habit model's own default PaletteColor(8); a habit created through this screen without touching the color picker is blue (index 11), not teal.

#### edit-habit.form-layout

- [ ] `edit-habit.form-layout` — Form fields, order, hints and input constraints
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/res/layout/activity_edit_habit.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-android/src/main/res/values/styles.xml`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/CommonSteps.kt`

1. `edit-habit.form-layout#1` — The form is a vertical scrolling list of labelled boxes in this exact order: (row 1) Name + Color side by side, (2) Question, (3) Frequency [yes/no only], (4) Unit [numerical only], (5) row of Target + Frequency [numerical only], (6) Target Type [numerical only], (7) Reminder, (8) Notes.
2. `edit-habit.form-layout#2` — Name field: label "Name" (R.string.name), maxLength = 50 characters, maxLines = 2, inputType = textCapSentences|textMultiLine.
3. `edit-habit.form-layout#3` — Name hint is "e.g. Exercise" (yes_or_no_short_example) for YES_NO and is replaced at runtime with "e.g. Run" (measurable_short_example) for NUMERICAL.
4. `edit-habit.form-layout#4` — Question field: label "Question" (R.string.question), inputType = textCapSentences|textMultiLine, no maxLength, no maxLines cap. Hint is "e.g. Did you exercise today?" (example_question_boolean) for YES_NO and "e.g. How many miles did you run today?" (measurable_question_example) for NUMERICAL.
5. `edit-habit.form-layout#5` — Name and Question are separate, independently stored fields (Habit.name and Habit.question); neither is derived from the other.
6. `edit-habit.form-layout#6` — Notes field: label "Notes" (R.string.notes), hint "(Optional)" (example_notes), inputType = textCapSentences|textMultiLine, unlimited length. It is persisted into Habit.description (not Habit.notes — no such field exists).
7. `edit-habit.form-layout#7` — Unit field: label "Unit", hint "e.g. miles" (measurable_units_example), maxLines = 1, ems = 10, default text inputType.
8. `edit-habit.form-layout#8` — Target field: label "Target", hint "e.g. 15" (example_target), maxLines = 1, inputType = numberDecimal.
9. `edit-habit.form-layout#9` — Target Type field: label "Target Type", rendered as a dropdown TextView (no free text).
10. `edit-habit.form-layout#10` — The color control is an 80dp-wide button whose background tint is the resolved habit color; its label is "Color".
11. `edit-habit.form-layout#11` — Both Frequency controls and the Reminder controls are dropdown-style TextViews with a drop-down arrow drawable (style FormDropdown), not spinners.

#### edit-habit.type-field-visibility

- [ ] `edit-habit.type-field-visibility` — Field visibility by habit type
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-android/src/main/res/layout/activity_edit_habit.xml`
- **Kotlin tests:** none — write Dart test from rules

1. `edit-habit.type-field-visibility#1` — When habitType == HabitType.YES_NO the Unit box, the Target/Frequency row and the Target Type box are set to GONE, and the yes/no Frequency box remains visible.
2. `edit-habit.type-field-visibility#2` — When habitType == HabitType.NUMERICAL the yes/no Frequency box is set to GONE, and the Unit box, Target/Frequency row and Target Type box remain visible.
3. `edit-habit.type-field-visibility#3` — Field visibility is decided once at screen creation and never changes while the screen is open (the type is not editable).
4. `edit-habit.type-field-visibility#4` — Hidden fields still hold their seeded text (e.g. targetInput is populated from habit.targetValue even for a YES_NO habit) but that text is never read back on save.

#### edit-habit.validation

- [ ] `edit-habit.validation` — Save-time validation
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Target parsing uses Kotlin String.toDouble() (always '.' as decimal separator), while the NumberDialog parses with the locale-aware NumberFormat. This inconsistency is real in the source.

1. `edit-habit.validation#1` — Validation runs only when the Save button is pressed; there is no live/as-you-type validation.
2. `edit-habit.validation#2` — If the Name field is empty (before trimming) the name input shows the inline error "Cannot be blank" (R.string.validation_cannot_be_blank) and the save is aborted.
3. `edit-habit.validation#3` — The name error text is wrapped in HTML as `<font color=#FFFFFF>Cannot be blank</font>` and rendered with Html.fromHtml, i.e. the name error is drawn in white; the target error uses the plain unstyled string.
4. `edit-habit.validation#4` — If habitType == NUMERICAL and the Target field is empty, the target input shows the plain error "Cannot be blank" and the save is aborted.
5. `edit-habit.validation#5` — Both errors are evaluated in the same pass, so a numerical habit with an empty name AND an empty target shows both errors at once.
6. `edit-habit.validation#6` — A name consisting only of whitespace passes validation (the emptiness check is done on the raw text, before trim), and is then saved as an empty name after trimming.
7. `edit-habit.validation#7` — There is no validation on Question, Notes, Unit, Target Type, Frequency or Reminder; all of them may be blank/default.
8. `edit-habit.validation#8` — There is no upper/lower bound validation on Target: 0, negative values and huge values are all accepted.
9. `edit-habit.validation#9` — If the Target text is non-empty but not parseable by Kotlin's String.toDouble() (e.g. "1,5" typed on a locale keyboard that emits a comma, or a bare "."), save() throws NumberFormatException and the screen crashes — the Flutter port must parse defensively and reject with an inline error instead.

#### edit-habit.save

- [ ] `edit-habit.save` — Saving the habit (create vs edit command dispatch)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CreateHabitCommand.kt`, `.../commands/EditHabitCommand.kt`, `.../models/Habit.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/commands/CreateHabitCommandTest.kt`, `.../EditHabitCommandTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`, `.../regression/ListHabitsRegressionTest.kt`
- **Notes:** Merged duplicate id: `commands.dispatch-edit-habit-activity`.

1. `edit-habit.save#1` — Save builds a fresh Habit from the model factory. In EDIT mode it first calls habit.copyFrom(original), which copies color, description, frequency, isArchived, name, position, question, reminder, targetType, targetValue, type, unit and uuid but NOT id; then the form values overwrite the relevant fields.
2. `edit-habit.save#2` — habit.name, habit.question and habit.description are assigned the TRIMMED text of nameInput, questionInput and notesInput respectively.
3. `edit-habit.save#3` — habit.color is set to the currently selected PaletteColor.
4. `edit-habit.save#4` — habit.reminder is set to Reminder(reminderHour, reminderMin, reminderDays) when reminderHour >= 0, and to null when reminderHour < 0.
5. `edit-habit.save#5` — habit.frequency is always set to Frequency(freqNum, freqDen), for both habit types.
6. `edit-habit.save#6` — Only when habitType == NUMERICAL are habit.targetValue (targetInput parsed with toDouble()), habit.targetType and habit.unit (trimmed) written; for YES_NO habits these three fields keep whatever came from copyFrom (i.e. the original values are preserved on edit, and the model defaults targetValue=0.0/targetType=AT_LEAST/unit="" on create).
7. `edit-habit.save#7` — habit.type is set to the screen's habitType last.
8. `edit-habit.save#8` — If habitId >= 0 the command is EditHabitCommand(habitList, habitId, habit); otherwise it is CreateHabitCommand(modelFactory, habitList, habit).
9. `edit-habit.save#9` — CreateHabitCommand.run() builds another Habit, copyFrom(model), adds it to the habit list, then calls habit.recompute().
10. `edit-habit.save#10` — EditHabitCommand.run() looks up the habit by id (throws HabitNotFoundException if missing), copyFrom(modified), habitList.update(habit), notifies the habit observable, recompute(), then habitList.resort().
11. `edit-habit.save#11` — After the command is run the activity finishes immediately; there is no confirmation dialog and no unsaved-changes prompt when leaving via the back/up button.
12. `edit-habit.save#12` — Leaving the screen with the back or up button discards all edits silently.
13. `edit-habit.save#13` — EditHabitActivity.save() runs only after validate() passes: the name must be non-empty, and for HabitType.NUMERICAL the target must be non-empty; otherwise inline errors are shown and no command is dispatched.
14. `edit-habit.save#14` — It always starts from `component.modelFactory.buildHabit()`; when `habitId >= 0` it first does `habit.copyFrom(original)` where `original = component.habitList.getById(habitId)!!`, preserving position, uuid, isArchived and any fields the form does not edit.
15. `edit-habit.save#15` — Form fields are then applied: name/question/description are trimmed; color is set from the picker; `reminder = Reminder(reminderHour, reminderMin, reminderDays)` when `reminderHour >= 0` and `reminder = null` otherwise; `frequency = Frequency(freqNum, freqDen)`; and only when habitType == NUMERICAL are targetValue, targetType and unit written; finally `habit.type = habitType`.
16. `edit-habit.save#16` — Edge case: switching an existing NUMERICAL habit to YES_NO leaves the previously copied targetValue/targetType/unit intact on the saved habit, because those assignments are skipped for non-numerical types.
17. `edit-habit.save#17` — Dispatch: `habitId >= 0` -> `EditHabitCommand(component.habitList, habitId, habit)`; otherwise -> `CreateHabitCommand(component.modelFactory, component.habitList, habit)`. The command is run through `component.commandRunner.run(command)` and the activity calls `finish()` immediately without waiting for completion.
18. `edit-habit.save#18` — Because the activity finishes immediately, the resulting toast is shown by ListHabitsScreen (which is resumed by then), not by the editor.

#### edit-habit.color-control

- [ ] `edit-habit.color-control` — Color button and live theming of the screen
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Themes.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/AndroidThemeSwitcher.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`

1. `edit-habit.color-control#1` — Tapping the color button opens the palette color picker seeded with the current color and the current Theme; the dialog is shown with tag "colorPicker".
2. `edit-habit.color-control#2` — When the picker returns a PaletteColor, the screen's color is replaced and updateColors() runs immediately.
3. `edit-habit.color-control#3` — updateColors() computes androidColor = themeSwitcher.currentTheme.color(color).toInt() and applies it as the color button's backgroundTintList.
4. `edit-habit.color-control#4` — updateColors() additionally paints the window status bar and the toolbar background with androidColor ONLY when the theme is not night mode; in dark/pure-black themes the toolbar keeps ?attr/colorPrimary.
5. `edit-habit.color-control#5` — androidColor is also what is passed as the accent color to the reminder time picker, so changing the color changes the time picker's highlight color.
6. `edit-habit.color-control#6` — LightTheme palette index -> RGB: 0 #D32F2F, 1 #E64A19, 2 #F57C00, 3 #FF8F00, 4 #F9A825, 5 #AFB42B, 6 #7CB342, 7 #388E3C, 8 #00897B, 9 #00ACC1, 10 #039BE5, 11 #1976D2, 12 #303F9F, 13 #5E35B1, 14 #8E24AA, 15 #D81B60, 16 #5D4037, 17 #424242, 18 #757575, 19 #9E9E9E; any other index -> #000000.
7. `edit-habit.color-control#7` — DarkTheme palette index -> RGB: 0 #EF9A9A, 1 #FFAB91, 2 #FFCC80, 3 #FFECB3, 4 #FFF59D, 5 #E6EE9C, 6 #C5E1A5, 7 #69F0AE, 8 #80CBC4, 9 #80DEEA, 10 #81D4FA, 11 #64B5F6, 12 #9FA8DA, 13 #B39DDB, 14 #CE93D8, 15 #F48FB1, 16 #BCAAA4, 17 #F5F5F5, 18 #E0E0E0, 19 #9E9E9E; any other index -> #FFFFFF.

#### edit-habit.frequency-display

- [ ] `edit-habit.frequency-display` — Frequency summary text (formatFrequency)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** none — write Dart test from rules

1. `edit-habit.frequency-display#1` — The top-level function formatFrequency(freqNum, freqDen, resources) is evaluated in this exact order and returns: (1) if freqNum==1 && (freqDen==30 || freqDen==31) -> "Every month"; (2) else if freqDen==30 || freqDen==31 -> "%d times per month" with freqNum; (3) else if freqNum==1 && freqDen==1 -> "Every day"; (4) else if freqNum==1 && freqDen==7 -> "Every week"; (5) else if freqNum==1 && freqDen>1 -> "Every %d days" with freqDen; (6) else if freqDen==7 -> "%d times per week" with freqNum; (7) else -> "%d times in %d days" with (freqNum, freqDen).
2. `edit-habit.frequency-display#2` — Example outputs: (1,1)->"Every day"; (1,7)->"Every week"; (1,3)->"Every 3 days"; (3,7)->"3 times per week"; (1,30)->"Every month"; (1,31)->"Every month"; (5,30)->"5 times per month"; (5,31)->"5 times per month"; (3,14)->"3 times in 14 days".
3. `edit-habit.frequency-display#3` — The yes/no frequency dropdown label is always formatFrequency(freqNum, freqDen); on a fresh YES_NO habit it reads "Every day".
4. `edit-habit.frequency-display#4` — The numerical frequency dropdown label is computed separately: freqDen==1 -> "Every day", freqDen==7 -> "Every week", freqDen==30 -> "Every month", any other denominator -> the raw string "$freqNum/$freqDen".
5. `edit-habit.frequency-display#5` — The numerical frequency label ignores the numerator for the three known denominators, so a numerical habit stored as (3,7) still displays "Every week".
6. `edit-habit.frequency-display#6` — Although the layout hard-codes the numerical frequency TextView's initial text to "Every week", populateFrequency() runs during screen creation and overwrites it, so a new numerical habit shows "Every day".

#### edit-habit.numerical-frequency-picker

- [ ] `edit-habit.numerical-frequency-picker` — Numerical habit frequency dropdown (3 options)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `edit-habit.numerical-frequency-picker#1` — For NUMERICAL habits the frequency control opens a plain AlertDialog with an ArrayAdapter list (android.R.layout.select_dialog_item) of exactly three items in this order: "Every day", "Every week", "Every month".
2. `edit-habit.numerical-frequency-picker#2` — Selecting index 0 sets freqDen = 1, index 1 sets freqDen = 7, index 2 sets freqDen = 30. Any other index falls back to freqDen = 1.
3. `edit-habit.numerical-frequency-picker#3` — This dialog changes ONLY the denominator; freqNum is left untouched (so editing a numerical habit stored as 3/7 and choosing "Every month" yields Frequency(3,30)).
4. `edit-habit.numerical-frequency-picker#4` — The dialog dismisses itself after a selection and the frequency label is re-rendered.
5. `edit-habit.numerical-frequency-picker#5` — This dialog is shown with builder.show() and therefore does NOT participate in the global "dismiss current dialog first" mechanism used by the other pickers.
6. `edit-habit.numerical-frequency-picker#6` — There is no cancel button; tapping outside dismisses it without changing the frequency.

#### edit-habit.target-type-picker

- [ ] `edit-habit.target-type-picker` — Target type dropdown (At least / At most)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/NumericalHabitType.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DialogUtils.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `edit-habit.target-type-picker#1` — Tapping the Target Type control opens a plain AlertDialog list with exactly two items in this order: "At least" (target_type_at_least) and "At most" (target_type_at_most).
2. `edit-habit.target-type-picker#2` — Index 0 sets targetType = NumericalHabitType.AT_LEAST (value 0); any other index sets NumericalHabitType.AT_MOST (value 1).
3. `edit-habit.target-type-picker#3` — The dialog is explicitly dismissed by the click handler after the selection.
4. `edit-habit.target-type-picker#4` — The control's label renders "At most" when targetType == AT_MOST and "At least" for every other value (AT_LEAST is the else branch), so AT_LEAST is the displayed default.
5. `edit-habit.target-type-picker#5` — The dropdown is only reachable for NUMERICAL habits; for YES_NO habits the whole box is GONE.
6. `edit-habit.target-type-picker#6` — This dialog is shown via dismissCurrentAndShow(), so it first dismisses any other dialog tracked as 'current'.

#### edit-habit.reminder-time

- [ ] `edit-habit.reminder-time` — Reminder time picker and 'Off' state
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DateExtensions.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Reminder.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/EditHabitSteps.kt`
- **Notes:** The radial time picker itself is a vendored AOSP widget with no Flutter equivalent; see time-picker.radial-dialog.

1. `edit-habit.reminder-time#1` — When reminderHour < 0 the reminder control shows "Off" (R.string.reminder_off) and both the reminder divider and the reminder-days control are GONE.
2. `edit-habit.reminder-time#2` — When reminderHour >= 0 the control shows the formatted time and the divider plus the reminder-days control become VISIBLE.
3. `edit-habit.reminder-time#3` — Tapping the reminder time control opens the radial TimePickerDialog seeded with hour = reminderHour if reminderHour >= 0 else 8, and minute = reminderMin if reminderMin >= 0 else 0. So the default suggested reminder is 08:00.
4. `edit-habit.reminder-time#4` — The picker is created in 24-hour mode iff the Android system setting DateFormat.is24HourFormat is true, and is tinted with the current habit color (androidColor).
5. `edit-habit.reminder-time#5` — Pressing "Done" calls onTimeSet(hourOfDay, minute) which stores reminderHour/reminderMin and re-renders the control.
6. `edit-habit.reminder-time#6` — Pressing "Clear" calls onTimeCleared which sets reminderHour = -1, reminderMin = -1 AND resets reminderDays to WeekdayList.EVERY_DAY, then re-renders (the control goes back to "Off" and the days row disappears).
7. `edit-habit.reminder-time#7` — The dialog is shown with tag "timePicker" via dismissCurrentAndShow.
8. `edit-habit.reminder-time#8` — formatTime(context, hours, minutes) builds a Date at epoch millis = (hours*60 + minutes)*60*1000 and formats it with DateFormat.getTimeFormat(context) forced to the UTC time zone, so the rendered string follows the user's 12/24h system preference (e.g. "8:00 AM" or "08:00").
9. `edit-habit.reminder-time#9` — The reminder is stored as Reminder(hour, minute, days); a saved habit either has a complete reminder or null — there is no partial state.

#### edit-habit.reminder-days

- [ ] `edit-habit.reminder-days` — Reminder days control and its label
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DateExtensions.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/JavaDates.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/platform/time/JavaLocalDateFormatterTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/EditHabitSteps.kt`

1. `edit-habit.reminder-days#1` — The reminder-days control is only visible while a reminder time is set; tapping it opens WeekdayPickerDialog pre-checked with the current reminderDays, shown with tag "dayPicker".
2. `edit-habit.reminder-days#2` — When the picker returns a WeekdayList, it becomes reminderDays; if the returned list is EMPTY it is replaced by WeekdayList.EVERY_DAY (you can never save a reminder with zero days).
3. `edit-habit.reminder-days#3` — The label is WeekdayList.toFormattedString(context), evaluated in this order: (a) exactly one day selected -> the LONG name of that day; (b) exactly two days selected and they are index 0 and index 1 -> "Weekends"; (c) exactly five days selected with index 0 and index 1 both unselected -> "Monday to Friday"; (d) exactly seven days -> "Any day of the week"; (e) otherwise -> the SHORT day names of the selected days joined with ", " in index order.
4. `edit-habit.reminder-days#4` — The weekday arrays are built with first weekday = SATURDAY, so index 0 = Saturday, 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday. That is why indexes 0 and 1 mean the weekend and "not 0 and not 1 plus five selected" means Mon-Fri.
5. `edit-habit.reminder-days#5` — Example: WeekdayList(127) (all bits) -> "Any day of the week"; only index 2 -> "Monday"; indexes 0+1 -> "Weekends"; indexes 2..6 -> "Monday to Friday"; indexes 0+2 -> "Sat, Mon".
6. `edit-habit.reminder-days#6` — An empty WeekdayList would format to the empty string, but the screen prevents that state.

#### edit-habit.instance-state

- [ ] `edit-habit.instance-state` — Rotation / process-death state restoration
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/regression/SavedStateTest.kt`
- **Notes:** Android Bundle save/restore has no direct Flutter equivalent; in Flutter this becomes ordinary widget state, and the targetType bug should probably be fixed rather than reproduced.

1. `edit-habit.instance-state#1` — onSaveInstanceState writes: habitId (Long), habitType (Int = enum value), paletteColor (Int = paletteIndex), androidColor (Int), freqNum, freqDen, reminderHour, reminderMin, reminderDays (Int = WeekdayList.toInteger()).
2. `edit-habit.instance-state#2` — On restore the screen reads back habitId, habitType, paletteColor, freqNum, freqDen, reminderHour, reminderMin and reminderDays. The saved androidColor is written but never read (it is recomputed by updateColors()).
3. `edit-habit.instance-state#3` — targetType is NOT saved/restored, so rotating the screen silently resets the Target Type control back to AT_LEAST. Reproduce it in the port only if bug-for-bug fidelity is wanted; otherwise persist it.
4. `edit-habit.instance-state#4` — The unit / target / name / question / notes text is not part of this bundle; it survives only through the platform's automatic EditText view-state save.
5. `edit-habit.instance-state#5` — The restore block runs AFTER the intent-seeding block, so restored values win over the values loaded from the habit.
6. `edit-habit.instance-state#6` — At the very end of screen creation every DialogFragment attached to the fragment manager is dismissed, so no picker dialog survives a configuration change.

#### edit-habit.window-insets-and-chrome

- [ ] `edit-habit.window-insets-and-chrome` — Toolbar, save button and window insets
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/res/layout/activity_edit_habit.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-android/src/main/res/values/styles.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/EditHabitSteps.kt`

1. `edit-habit.window-insets-and-chrome#1` — The Save action is a MaterialButton with the outlined style placed inside the toolbar, gravity end, 16dp end margin, white text and white stroke/ripple, labelled with R.string.save = "Save" (rendered upper-case by the Material button style).
2. `edit-habit.window-insets-and-chrome#2` — The toolbar shows the up/home affordance (setDisplayHomeAsUpEnabled + setDisplayShowHomeEnabled) and is given an action-bar elevation of 10.0f at runtime (the layout also declares 2dp elevation).
3. `edit-habit.window-insets-and-chrome#3` — The screen root applies root-view insets and a bottom inset, and the toolbar applies toolbar insets, so the form scrolls under the system bars and the last field is not covered by the navigation bar or IME.
4. `edit-habit.window-insets-and-chrome#4` — The screen background is ?attr/contrast0 and the form area is inside a ScrollView with layout weight 1 under the AppBarLayout.
5. `edit-habit.window-insets-and-chrome#5` — The form has 8dp top padding and 4dp side padding; each field box has 4dp top / 8dp bottom / 4dp side padding and a rounded outlined background with the floating label overlapping the top border (-15dp top margin).

#### dialogs.single-current-dialog

- [ ] `dialogs.single-current-dialog` — Global 'only one dialog at a time' mechanism
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/DialogUtils.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `.../activities/habits/show/ShowHabitActivity.kt`, `.../activities/habits/list/ListHabitsScreen.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `dialogs.single-current-dialog#1` — A process-wide pair of WeakReferences (currentDialog for platform Dialogs, currentDialogFragment for DialogFragments) tracks at most one 'current' dialog.
2. `dialogs.single-current-dialog#2` — dismissCurrentDialog() dismisses whichever of the two is still reachable and clears both references.
3. `dialogs.single-current-dialog#3` — Dialog.dismissCurrentAndShow() and DialogFragment.dismissCurrentAndShow(fm, tag) both call dismissCurrentDialog() first, then register themselves as current, then show. The fragment variant also calls fragmentManager.executePendingTransactions() so the dialog is guaranteed to exist synchronously after the call.
4. `dialogs.single-current-dialog#4` — Dialogs routed through this mechanism: color picker, frequency picker, target-type list, time picker, weekday picker, confirm-delete, checkmark popup, number popup.
5. `dialogs.single-current-dialog#5` — Dialogs NOT routed through it: the numerical-frequency 3-item list (builder.show()), HabitTypeDialog (plain show()), HistoryEditorDialog (plain show(), plus its own static currentDialog slot).
6. `dialogs.single-current-dialog#6` — ShowHabitActivity.onPause() calls dismissCurrentDialog(), so leaving the statistics screen closes any open popup.

#### habit-type-dialog.select-type

- [ ] `habit-type-dialog.select-type` — HabitTypeDialog (choose Yes/No vs Measurable)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/HabitTypeDialog.kt`, `uhabits-android/src/main/res/layout/select_habit_type.xml`, `uhabits-android/src/main/res/values/styles.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehavior.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`, `.../acceptance/steps/CommonSteps.kt`

1. `habit-type-dialog.select-type#1` — The dialog is opened from the list screen's "Add" menu action (ListHabitsMenuBehavior.onCreateHabit -> screen.showSelectHabitTypeDialog()), shown with tag "habitType".
2. `habit-type-dialog.select-type#2` — It uses the Translucent theme: no title, transparent window background, translucent status bar, and fade-in/fade-out window animations.
3. `habit-type-dialog.select-type#3` — It is a full-screen vertically centred column over a scrim of colour #a0000000 (black at 62.7% alpha).
4. `habit-type-dialog.select-type#4` — It shows exactly two cards, in this order: (1) title "Yes or No" with body "e.g. Did you wake up early today? Did you exercise? Did you play chess?"; (2) title "Measurable" with body "e.g. How many miles did you run today? How many pages did you read?".
5. `habit-type-dialog.select-type#5` — A third "Subjective" card exists in the layout but is entirely commented out and must not be ported.
6. `habit-type-dialog.select-type#6` — Tapping the "Yes or No" card starts EditHabitActivity with habitType = 0 and dismisses the dialog; tapping "Measurable" starts it with habitType = 1 and dismisses.
7. `habit-type-dialog.select-type#7` — Tapping the scrim background dismisses the dialog without starting anything.
8. `habit-type-dialog.select-type#8` — Card titles are 20sp bold with 8dp bottom margin; card bodies use the small text size with lineSpacingMultiplier 1.25; cards have 6dp elevation and a rounded ripple background.

#### frequency-picker.options

- [ ] `frequency-picker.options` — FrequencyPickerDialog options and layout
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/FrequencyPickerDialog.kt`, `uhabits-android/src/main/res/layout/frequency_picker_dialog.xml`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/EditHabitSteps.kt`, `.../regression/ListHabitsRegressionTest.kt`

1. `frequency-picker.options#1` — The dialog is constructed as FrequencyPickerDialog(freqNumerator, freqDenominator); the no-arg constructor defaults to (1, 1).
2. `frequency-picker.options#2` — It presents exactly five mutually exclusive radio rows, in this order: (1) "Every day" (no input); (2) "Every %d days" with one number field; (3) "%d times per week" with one number field; (4) "%d times per month" with one number field; (5) "%d times in %d days" with two number fields.
3. `frequency-picker.options#3` — Each row is 48dp tall and centred vertically.
4. `frequency-picker.options#4` — Placeholder default texts baked into the layout: every-X-days field = "3" (maxLength 3), times-per-week field = "3" (maxLength 1), times-per-month field = "10" (maxLength 2), times-in-Y-days fields = "3" (maxLength 3) and "14" (maxLength 3). All are inputType=number.
5. `frequency-picker.options#5` — The literal words around each number field are produced at runtime by splitting the localized format string on the substring "%d" and inserting one TextView (trimmed part) at container index 2*i+1 for each part i; so with English strings row 2 reads [radio]["Every"][field]["days"] and row 5 reads [radio][""][fieldX]["times in"][fieldY]["days"].
6. `frequency-picker.options#6` — The radio group is hand-managed: clicking any radio unchecks all five and checks the clicked one, then moves focus to it; clicking rows 2-5 also moves the caret to the end of that row's first number field.
7. `frequency-picker.options#7` — Giving focus to any number field automatically checks that row's radio button (the two-field row is checked by focusing either field).
8. `frequency-picker.options#8` — The dialog has a single positive button labelled "Save" (R.string.save) and NO cancel/negative button; dismissing it by tapping outside or pressing back returns nothing and leaves the frequency unchanged.
9. `frequency-picker.options#9` — populateViews() runs on every onResume (not only on first show), re-deriving the checked row from the current numerator/denominator.

#### frequency-picker.populate-from-frequency

- [ ] `frequency-picker.populate-from-frequency` — FrequencyPickerDialog: mapping an existing Frequency onto the radio rows
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/FrequencyPickerDialog.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `frequency-picker.populate-from-frequency#1` — populateViews() first unchecks all five radios, then selects exactly one row using this order of tests:
2. `frequency-picker.populate-from-frequency#2` — If denominator == 30 OR denominator == 31 -> check "x times per month" and set its field to the numerator (a 1/31 habit therefore opens as "1 times per month").
3. `frequency-picker.populate-from-frequency#3` — Else if numerator == 1 and denominator == 1 -> check "Every day" (no field written).
4. `frequency-picker.populate-from-frequency#4` — Else if numerator == 1 and denominator != 1 -> check "Every X days" and set its field to the denominator.
5. `frequency-picker.populate-from-frequency#5` — Else if numerator != 1 and denominator == 7 -> check "X times per week" and set its field to the numerator.
6. `frequency-picker.populate-from-frequency#6` — Else (numerator != 1, denominator not 7/30/31) -> check "X times in Y days" and set X = numerator, Y = denominator.
7. `frequency-picker.populate-from-frequency#7` — In every branch that writes a field, the caret is placed at the end of that field.
8. `frequency-picker.populate-from-frequency#8` — Rows that were not selected keep their hard-coded placeholder text (3 / 3 / 10 / 3 / 14).

#### frequency-picker.save-and-validation

- [ ] `frequency-picker.save-and-validation` — FrequencyPickerDialog: what Save returns
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/FrequencyPickerDialog.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/regression/ListHabitsRegressionTest.kt`, `.../acceptance/steps/EditHabitSteps.kt`

1. `frequency-picker.save-and-validation#1` — Save starts from numerator = 1, denominator = 1 and then applies exactly one branch based on the checked radio.
2. `frequency-picker.save-and-validation#2` — "Every day" checked -> no change, result (1, 1).
3. `frequency-picker.save-and-validation#3` — "Every X days" checked -> if the field is non-empty, denominator = Integer.parseInt(field); numerator stays 1. If the field is empty the result stays (1, 1).
4. `frequency-picker.save-and-validation#4` — "X times per week" checked -> if the field is non-empty, numerator = parse(field) AND denominator = 7. If the field is empty BOTH stay 1, i.e. the result is (1, 1) — not (1, 7).
5. `frequency-picker.save-and-validation#5` — "X times in Y days" checked -> only if BOTH fields are non-empty are numerator and denominator parsed; otherwise the result stays (1, 1).
6. `frequency-picker.save-and-validation#6` — The month row is the `else` fallback branch: it is used when the month radio is checked AND also when no radio at all is checked. If its field is non-empty, numerator = parse(field) and denominator = 30 (never 31).
7. `frequency-picker.save-and-validation#7` — Final clamp: if numerator >= denominator OR numerator < 1, both are forced to numerator = 1, denominator = 1. So 7 times per week -> (1,1); 30 times per month -> (1,1); 0 times per week -> (1,1); "3 times in 3 days" -> (1,1); "Every 1 days" -> (1,1).
8. `frequency-picker.save-and-validation#8` — After clamping, onFrequencyPicked(numerator, denominator) is invoked and the dialog dismisses.
9. `frequency-picker.save-and-validation#9` — The caller (EditHabitActivity) stores the pair verbatim into freqNum/freqDen and re-renders the summary label.
10. `frequency-picker.save-and-validation#10` — Any non-numeric content is impossible because the fields are inputType=number, but an empty field is possible and is handled by the rules above.

#### weekday-picker.dialog

- [ ] `weekday-picker.dialog` — WeekdayPickerDialog
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/WeekdayPickerDialog.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/JavaDates.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/platform/time/JavaLocalDateFormatterTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/EditHabitSteps.kt`

1. `weekday-picker.dialog#1` — The dialog is an AlertDialog titled "Select days" (R.string.select_weekdays) with a 7-item multi-choice list.
2. `weekday-picker.dialog#2` — The item labels are the LONG weekday names produced with first weekday = SATURDAY, i.e. in English: ["Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"] at indexes 0..6.
3. `weekday-picker.dialog#3` — Initial checked state comes from setSelectedDays(WeekdayList).toArray(); setSelectedDays must be called before the dialog is created or the checked array is null.
4. `weekday-picker.dialog#4` — Toggling item `which` flips selectedDays[which] immediately in the local array; nothing is reported until a button is pressed.
5. `weekday-picker.dialog#5` — The positive button uses android.R.string.yes and returns WeekdayList(selectedDays) through the OnWeekdaysPickedListener.onWeekdaysSet callback.
6. `weekday-picker.dialog#6` — The negative button uses android.R.string.cancel and only dismisses — no callback, no change.
7. `weekday-picker.dialog#7` — Dismissing by tapping outside or pressing back also reports nothing.
8. `weekday-picker.dialog#8` — The checked array is preserved across configuration changes via the instance-state key "selectedDays" (BooleanArray).
9. `weekday-picker.dialog#9` — The dialog itself will happily return an all-unselected WeekdayList; it is the caller (EditHabitActivity) that substitutes EVERY_DAY for an empty result.

#### color-picker.dialog

- [ ] `color-picker.dialog` — ColorPickerDialog (palette grid)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/ColorPickerDialog.kt`, `.../ColorPickerDialogFactory.kt`, `uhabits-android/src/main/java/com/android/colorpicker/ColorPickerDialog.java`, `.../ColorPickerPalette.java`, `.../ColorPickerSwatch.java`, `.../ColorStateDrawable.java`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/PaletteUtils.kt`, `.../utils/StyledResources.kt`, `uhabits-android/src/main/res/values/colors.xml`, `.../values/pickers.xml`, `.../layout/color_picker_dialog.xml`, `.../layout/color_picker_swatch.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsSelectionMenuBehaviorTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`, `.../acceptance/steps/EditHabitSteps.kt`
- **Notes:** The picker is also used from the habit-list selection menu (showColorPicker) with the same factory, so the port should expose one reusable widget. The palette->index round trip through raw ARGB values is fragile; a Flutter port should pass the palette index directly.

1. `color-picker.dialog#1` — ColorPickerDialogFactory.create(color, theme) builds the dialog with: title resource color_picker_default_title = "Change color", the 20-entry themed palette (lightPalette for light themes, darkPalette for dark themes, taken from ?attr/palette), the currently selected ARGB color = theme.color(color).toInt(), columns = 4, size = SIZE_SMALL.
2. `color-picker.dialog#2` — SIZE_SMALL means 48dp swatches with 4dp margins; SIZE_LARGE (unused here) would mean 64dp swatches with 8dp margins.
3. `color-picker.dialog#3` — The palette is laid out as a TableLayout in serpentine order: even-numbered rows (0-based) are filled left-to-right, odd-numbered rows are filled right-to-left (each swatch is inserted at index 0 of the row). With 20 colours and 4 columns this yields 5 rows.
4. `color-picker.dialog#4` — If the last row would be short it is padded with blank ImageViews of the same size so the grid stays rectangular.
5. `color-picker.dialog#5` — Every swatch is a circle drawable tinted with its colour; the currently selected swatch draws an additional checkmark overlay image on top.
6. `color-picker.dialog#6` — Pressing/focusing a swatch darkens it: its HSV value component is multiplied by 0.70.
7. `color-picker.dialog#7` — Swatch accessibility descriptions are "Color %d" (or "Color %d selected") where %d is the 1-based index within the natural reading order — for odd rows the index is computed as ((rowNumber + 1) * columns) - rowElements so the description matches visual left-to-right order, not insertion order.
8. `color-picker.dialog#8` — Tapping a swatch immediately fires onColorSelected(argb), redraws the grid with the new checkmark, and dismisses; there is NO OK button.
9. `color-picker.dialog#9` — Dismissing without tapping a swatch returns nothing.
10. `color-picker.dialog#10` — The returned ARGB is converted back with Int.toPaletteColor(context) = PaletteColor(palette.indexOf(argb)); if the colour is not present in the current themed palette this yields PaletteColor(-1).
11. `color-picker.dialog#11` — A large progress spinner is shown in place of the grid until colours are set (in practice the colours are always set up-front, so the spinner is never visible).
12. `color-picker.dialog#12` — The dialog persists its colour array and selected colour across configuration changes via instance state keys "palette" and "selected_color".
13. `color-picker.dialog#13` — com.android.colorpicker.HsvColorComparator exists in the vendored package but is never referenced — do not port it.

#### color-picker.palette-source

- [ ] `color-picker.palette-source` — Themed palette arrays used by the picker
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/res/values/colors.xml`, `.../values/styles.xml`, `.../values/attrs.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/PaletteColor.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/PaletteUtils.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `color-picker.palette-source#1` — The picker's colour array is resolved from the theme attribute `palette`, which is @array/lightPalette for AppBaseTheme and BaseDialog, @array/darkPalette for AppBaseThemeDark / PureBlack / BaseDialogDark, and @array/transparentWidgetPalette for the widget theme.
2. `color-picker.palette-source#2` — lightPalette (20 entries, in order) = red_700, deep_orange_700, orange_700, amber_800, yellow_800, lime_700, light_green_600, green_700, teal_600, cyan_600, light_blue_600, blue_700, indigo_700, deep_purple_600, purple_600, pink_600, brown_700, grey_800, grey_600, grey_500.
3. `color-picker.palette-source#3` — darkPalette (20 entries, in order) = red_200, deep_orange_200, orange_200, amber_100, yellow_200, lime_200, light_green_200, green_A200, teal_200, cyan_200, light_blue_200, blue_300, indigo_200, deep_purple_200, purple_200, pink_200, brown_200, grey_100, grey_300, grey_500.
4. `color-picker.palette-source#4` — PaletteColor.toCsvColor() maps the same 20 indexes to fixed hex strings independent of theme: #D32F2F, #E64A19, #F57C00, #FF8F00, #F9A825, #AFB42B, #7CB342, #388E3C, #00897B, #00ACC1, #039BE5, #1976D2, #303F9F, #5E35B1, #8E24AA, #D81B60, #5D4037, #303030, #757575, #aaaaaa (index out of range throws).
5. `color-picker.palette-source#5` — PaletteColor.toFixedAndroidColor() (used by tests) returns the same 20 fixed hex values.

#### confirm-delete.dialog

- [ ] `confirm-delete.dialog` — ConfirmDeleteDialog
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/ConfirmDeleteDialog.kt`, `uhabits-android/src/main/res/values/strings.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `.../activities/habits/show/ShowHabitActivity.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsSelectionMenuBehaviorTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/HabitsTest.kt`

1. `confirm-delete.dialog#1` — ConfirmDeleteDialog(context, callback, quantity) is a plain AlertDialog built with a quantity so it can address one or many habits.
2. `confirm-delete.dialog#2` — Title = plural delete_habits_title: quantity 1 -> "Delete habit?", otherwise -> "Delete habits?".
3. `confirm-delete.dialog#3` — Message = plural delete_habits_message: quantity 1 -> "The habit will be permanently deleted. This action cannot be undone.", otherwise -> "The habits will be permanently deleted. This action cannot be undone.".
4. `confirm-delete.dialog#4` — Positive button label = R.string.yes = "Yes"; pressing it invokes OnConfirmedCallback.onConfirmed().
5. `confirm-delete.dialog#5` — Negative button label = R.string.no = "No"; pressing it does nothing at all (empty listener).
6. `confirm-delete.dialog#6` — Dismissing by tapping outside or pressing back does not confirm.
7. `confirm-delete.dialog#7` — It is shown with dismissCurrentAndShow(), so it closes any other tracked dialog first.
8. `confirm-delete.dialog#8` — Call sites: the habit-list selection menu passes the number of selected habits; ShowHabitActivity always passes quantity = 1.

#### checkmark-dialog.popup

- [ ] `checkmark-dialog.popup` — CheckmarkDialog (yes/no entry popup with notes)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/CheckmarkDialog.kt`, `uhabits-android/src/main/res/layout/checkmark_popup.xml`, `uhabits-android/src/main/res/values/fontawesome.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt`, `.../preferences/Preferences.kt`, `.../ui/screens/habits/list/ListHabitsBehavior.kt`, `.../ui/screens/habits/show/views/HistoryCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `.../activities/habits/show/ShowHabitActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DialogUtils.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`
- **Notes:** Depends on the bundled fontawesome-webfont.ttf for its glyphs; a Flutter port should substitute real icons. (Merged duplicate id: `show-habit.checkmark-popup`.)

1. `checkmark-dialog.popup#1` — Arguments (all required): "color" (Int ARGB, already resolved through the current theme), "value" (Int, the existing entry value), "notes" (String, the existing note). A missing "notes" argument crashes (non-null assertion).
2. `checkmark-dialog.popup#2` — The popup is a borderless Dialog (transparent window background) at least 208dp wide and 128dp tall, containing a multi-line notes EditText on top (centred text, hint "Notes", inputType textCapSentences|textMultiLine) and a 48dp row of four buttons below, separated by dividers.
3. `checkmark-dialog.popup#3` — The four buttons are, left to right: YES (FontAwesome glyph U+F00C check), SKIP (U+F068 minus), NO (U+F00D times), UNKNOWN (U+F128 question mark). All four use the FontAwesome typeface.
4. `checkmark-dialog.popup#4` — YES and SKIP are tinted with the habit colour; NO and UNKNOWN use the theme attribute contrast60.
5. `checkmark-dialog.popup#5` — The SKIP button is GONE unless Preferences.isSkipEnabled (default false); the UNKNOWN button is GONE unless Preferences.areQuestionMarksEnabled (default false). So by default only YES and NO are visible.
6. `checkmark-dialog.popup#6` — The notes field is pre-filled with the "notes" argument.
7. `checkmark-dialog.popup#7` — Tapping YES returns Entry.YES_MANUAL = 2; SKIP returns Entry.SKIP = 3; NO returns Entry.NO = 0; UNKNOWN returns Entry.UNKNOWN = -1. In every case the callback is onToggle(value, notes.trim()) and the dialog dismisses.
8. `checkmark-dialog.popup#8` — Pressing the IME action inside the notes field returns the ORIGINAL value from the arguments together with the trimmed notes, and dismisses.
9. `checkmark-dialog.popup#9` — If the dialog is dismissed WITHOUT any of those actions (tap outside / back), and the trimmed notes text differs from the original notes, onToggle(originalValue, trimmedNotes) is still fired so note edits are not lost. If the notes are unchanged, nothing is reported.
10. `checkmark-dialog.popup#10` — An onDismiss() callback always fires last, regardless of how the dialog closed.
11. `checkmark-dialog.popup#11` — The caller turns the returned pair into CreateRepetitionCommand(habitList, habit, date, newValue, newNotes); the list screen additionally fires confetti when newValue != previous value and newValue == YES_MANUAL.
12. `checkmark-dialog.popup#12` — Unlike NumberDialog, this dialog does NOT force the soft keyboard open.
13. `checkmark-dialog.popup#13` — The popup offers four buttons: Yes (value 2 YES_MANUAL), No (value 0), Skip (value 3) and Unknown/question mark (value -1), plus a free-text notes field.
14. `checkmark-dialog.popup#14` — The Yes and Skip buttons are tinted with the habit colour passed in; No and Unknown use contrast60; all four use the FontAwesome typeface.
15. `checkmark-dialog.popup#15` — The popup dismisses any other currently tracked dialog before showing (dismissCurrentAndShow with tag "checkmarkDialog").

#### number-dialog.popup

- [ ] `number-dialog.popup` — NumberDialog (numerical entry popup with notes)
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/NumberDialog.kt`, `uhabits-android/src/main/res/layout/checkmark_popup.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt`, `.../ui/screens/habits/list/ListHabitsBehavior.kt`, `.../ui/screens/habits/show/views/HistoryCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`
- **Notes:** The keyboard-forcing hack and the SwiftKey/Samsung input-method sniffing are Android-specific and have no Flutter equivalent; decimal-separator handling must be reimplemented with Flutter's TextInputFormatter + intl. (Merged duplicate id: `show-habit.number-popup`.)

1. `number-dialog.popup#1` — Arguments (all required): "color" (Int ARGB), "value" (Double, the existing entry value already divided by 1000), "notes" (String).
2. `number-dialog.popup#2` — It reuses the same borderless popup layout as CheckmarkDialog but shows the `numberButtons` row instead: a numeric EditText (layout weight 2, selectAllOnFocus, centre aligned), then "Save", then "Skip", then the FontAwesome question-mark button.
3. `number-dialog.popup#3` — The "Skip" button is GONE unless Preferences.isSkipEnabled; the question-mark button is GONE unless Preferences.areQuestionMarksEnabled.
4. `number-dialog.popup#4` — Initial text of the value field: if value < 0.01 the literal "0", otherwise DecimalFormat("#.##").format(value) using the default locale — e.g. 0.5 -> "0.5", 12.345 -> "12.35", 15.0 -> "15". Because UNKNOWN (-0.001) and SKIP (0.003) are both < 0.01 they are displayed as "0".
5. `number-dialog.popup#5` — The value field's key listener is restricted to the digits 0-9 plus the locale's decimal separator (DecimalFormatSymbols.getInstance().decimalSeparator).
6. `number-dialog.popup#6` — Workaround: if the default input method id contains "swiftkey" or "samsung", the value field's inputType is switched to TYPE_CLASS_TEXT so the decimal separator key appears.
7. `number-dialog.popup#7` — The value field requests focus and forces the soft keyboard open by dispatching a synthetic ACTION_DOWN/ACTION_UP touch pair 250ms after creation.
8. `number-dialog.popup#8` — Pressing the hardware/soft ENTER key inside the value field triggers Save. Pressing the IME action inside the notes field also triggers Save.
9. `number-dialog.popup#9` — "Skip" sets the value text to DecimalFormat("#.###").format(Entry.SKIP/1000.0) = "0.003" and then saves, so the entry ends up with the raw value 3 (SKIP).
10. `number-dialog.popup#10` — The question-mark button sets the value text to DecimalFormat("#.###").format(Entry.UNKNOWN/1000.0) = "-0.001" and then saves, so the entry ends up with the raw value -1 (UNKNOWN).
11. `number-dialog.popup#11` — Save parses the field with the locale-aware NumberFormat.getInstance(); an empty field yields Entry.UNKNOWN/1000.0 = -0.001; a ParseException leaves the original value unchanged. Then onToggle(value, notes.trim()) fires and the dialog dismisses.
12. `number-dialog.popup#12` — If dismissed without saving and the trimmed notes differ from the original notes, onToggle(originalValue, trimmedNotes) is fired so note edits survive; otherwise nothing is reported. An onDismiss() callback always fires last.
13. `number-dialog.popup#13` — The caller converts the returned Double back to the stored integer with (value * 1000).roundToInt() before issuing CreateRepetitionCommand.
14. `number-dialog.popup#14` — The list screen fires confetti when the value changed AND ((targetType == AT_LEAST && newValue >= habit.targetValue) || (targetType == AT_MOST && newValue <= habit.targetValue)).
15. `number-dialog.popup#15` — `view.saveBtn.getCenter()` is computed in save() and never used — dead code, do not port.
16. `number-dialog.popup#16` — The keypad accepts digits and the locale decimal separator only; on SwiftKey and Samsung keyboards the input type is switched to TYPE_CLASS_TEXT as a workaround.
17. `number-dialog.popup#17` — The presenter converts the returned double back to storage units as (value * 1000).roundToInt().
18. `number-dialog.popup#18` — The popup is shown with tag "numberDialog" after dismissing any other tracked dialog.

#### history-editor.dialog

- [ ] `history-editor.dialog` — HistoryEditorDialog (calendar heat-map editor)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/HistoryEditorDialog.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/HistoryCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`, `.../activities/habits/show/views/HistoryCardView.kt`, `uhabits-android/src/main/res/values/dimens.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/show/views/HistoryCardViewTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/views/HistoryChartTest.kt`
- **Notes:** The chart drawing itself belongs to the show-habit domain; what is in scope here is the dialog shell, its sizing, its live refresh on command completion and its stacking behaviour under the entry popups. (Merged duplicate id: `show-habit.history-editor-dialog`.)

1. `history-editor.dialog#1` — Arguments: "habit" (Long habit id). The habit is fetched from the habit list at creation time and crashes if absent.
2. `history-editor.dialog#2` — The dialog is a bare Dialog whose only content is the history heat-map chart; its window is sized to (screenWidthPixels, min(screenHeightPixels, 350dp)).
3. `history-editor.dialog#3` — The chart is created with: dateFormatter = default locale, firstWeekday = Preferences.firstWeekday, paletteColor = habit.color, empty initial series, defaultSquare = Square.OFF, empty notesIndicators, theme = the current app theme, today = getToday(), padding = 10.0.
4. `history-editor.dialog#4` — It applies the app theme (AndroidThemeSwitcher.apply) before building the chart, so it follows light/dark/pure-black.
5. `history-editor.dialog#5` — onResume it registers itself as a CommandRunner.Listener and immediately refreshes; onPause it unregisters.
6. `history-editor.dialog#6` — Every time any command finishes, refreshData() rebuilds the chart state and posts an invalidate, so toggling a day from inside the dialog updates the grid live.
7. `history-editor.dialog#7` — refreshData() calls HistoryCardPresenter.buildState(habit, preferences.firstWeekday, theme = LightTheme()) — the state is always built with a LightTheme even in dark mode, while the chart's own rendering theme is the real current theme.
8. `history-editor.dialog#8` — The series is built from the entries between the oldest known entry (or today when there are none) and today. For numerical habits: value == UNKNOWN -> OFF, value == SKIP -> HATCHED, (AT_MOST && value/1000 <= target) -> ON, (AT_LEAST && value/1000 >= target) -> ON, otherwise GREY. For yes/no habits: YES_MANUAL -> ON, YES_AUTO -> DIMMED, SKIP -> HATCHED, everything else -> OFF.
9. `history-editor.dialog#9` — notesIndicators[i] is true iff that entry's notes string is non-empty.
10. `history-editor.dialog#10` — It keeps its OWN static `currentDialog` slot (separate from the app-wide dismissCurrentDialog mechanism) so that it can stay visible UNDER a NumberDialog/CheckmarkDialog; creating a new instance dismisses the previous one, and dismissing clears the slot.
11. `history-editor.dialog#11` — Tapping a day fires OnDateClickedListener: for numerical habits (both short and long press) the NumberDialog opens; for yes/no habits a short press opens the CheckmarkDialog unless Preferences.isShortToggleEnabled, in which case it toggles directly (and long press does the opposite).
12. `history-editor.dialog#12` — Every date click first calls screen.showFeedback(), which performs a VIRTUAL_KEY haptic feedback.
13. `history-editor.dialog#13` — ShowHabitActivity re-attaches the date-clicked listener on resume by looking the fragment up by tag "historyEditor", so the dialog keeps working after a configuration change.
14. `history-editor.dialog#14` — Tapping the History card's Edit button shows a dialog fragment tagged "historyEditor" whose arguments contain the long "habit" = habit.id.
15. `history-editor.dialog#15` — The dialog content is a full-width HistoryChart with padding 10.0; the dialog window width = screen width and height = min(screen height, R.dimen.history_editor_max_height).
16. `history-editor.dialog#16` — Before showing, HistoryEditorDialog.clearCurrentDialog() dismisses any previously open history editor; the editor keeps its own static currentDialog reference so it can remain open UNDER the number/check-mark popups.
17. `history-editor.dialog#17` — Taps inside the dialog are routed to the same HistoryCardPresenter as the card, so short/long press semantics and the toggle cycle are identical.

#### time-picker.radial-dialog

- [ ] `time-picker.radial-dialog` — Vendored radial TimePickerDialog
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/com/android/datetimepicker/time/TimePickerDialog.java`, `.../time/RadialPickerLayout.java`, `uhabits-android/src/main/res/layout/time_picker_dialog.xml`, `uhabits-android/src/main/res/values/strings.xml`, `.../values/pickers.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/EditHabitSteps.kt`
- **Notes:** This is a fork of the old AOSP datetimepicker (also containing an unused date/ package: DatePickerDialog, DayPickerView, MonthView, YearPickerView, etc. — none of it is referenced from this domain). Flutter's showTimePicker has no Clear button, so the 'Clear reminder' affordance must be added explicitly.

1. `time-picker.radial-dialog#1` — TimePickerDialog.newInstance(callback, hourOfDay, minute, is24HourMode, accentColor) creates the dialog; the accent colour tints the radial selector and the currently-edited hour/minute text.
2. `time-picker.radial-dialog#2` — The listener interface has two methods: onTimeSet(view, hourOfDay, minute) and a default no-op onTimeCleared(view).
3. `time-picker.radial-dialog#3` — There are exactly two text buttons at the bottom: "Clear" (R.string.clear_label) on the left and "Done" (R.string.done_label) on the right. Both are styled with theme attributes contrast80 (text) and contrast0 (background).
4. `time-picker.radial-dialog#4` — "Done" reports the picker's current hour and minute and dismisses; "Clear" reports onTimeCleared and dismisses. There is no cancel button; back/outside dismiss reports nothing.
5. `time-picker.radial-dialog#5` — The dialog starts on the HOUR page (HOUR_INDEX = 0); tapping the hour or minute text switches pages and triggers haptic feedback.
6. `time-picker.radial-dialog#6` — Hours snap in 30-degree steps (12 positions); minutes snap in 6-degree steps (60 positions, i.e. every single minute is selectable).
7. `time-picker.radial-dialog#7` — In 12-hour mode an AM/PM label is shown and tapping it toggles between AM (0) and PM (1); the initial state is AM when the seeded hour < 12, PM otherwise. In 24-hour mode the AM/PM label is GONE and the ':' separator is centred instead.
8. `time-picker.radial-dialog#8` — A hardware keyboard can type a time: digits 0-9 build up a value, DEL removes the last digit, ENTER accepts, ESC/BACK cancels, TAB advances; while a partially-typed time is illegal the Done button is disabled and the placeholder "--" is displayed.
9. `time-picker.radial-dialog#9` — Haptic feedback is emitted on selector movement and on button presses.
10. `time-picker.radial-dialog#10` — Instance state keys: hour_of_day, minute, is_24_hour_view, current_item_showing, in_kb_mode, typed_times, dark_theme, selected_color.

## Domain: Settings, preferences, theming and intro

#### settings.preferences.key-catalog

- [x] `settings.preferences.key-catalog` — Complete preference key catalogue with types and defaults
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/res/xml/preferences.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`
- **Notes:** This is the single source of truth for the preference schema. The XML PreferenceScreen re-declares android:defaultValue="false" for every SwitchPreferenceCompat and "255" for pref_widget_opacity; those XML defaults are materialised into SharedPreferences by PreferenceManager.setDefaultValues(context, R.xml.preferences, false) called from SharedPreferencesStorage's init block.

1. `settings.preferences.key-catalog#1` — Preferences is constructed with a Storage; the constructor calls storage.onAttached(this) exactly once and initialises an empty listener list.
2. `settings.preferences.key-catalog#2` — Key "pref_default_habit_palette_color" is an Int; getDefaultHabitColor(fallbackColor) returns storage.getInt("pref_default_habit_palette_color", fallbackColor), so there is no fixed default — the caller's fallback is the default. setDefaultHabitColor(color) writes the Int.
3. `settings.preferences.key-catalog#3` — Key "pref_default_order" is a String storing a HabitList.Order enum name; default "BY_POSITION".
4. `settings.preferences.key-catalog#4` — Key "pref_default_secondary_order" is a String storing a HabitList.Order enum name; default "BY_NAME_ASC".
5. `settings.preferences.key-catalog#5` — Key "pref_score_view_interval" is an Int; raw default 1; the getter returns min(4, max(0, raw)).
6. `settings.preferences.key-catalog#6` — Key "pref_bar_card_bool_spinner" is an Int; raw default 0; the getter returns min(3, max(0, raw)).
7. `settings.preferences.key-catalog#7` — Key "pref_bar_card_numerical_spinner" is an Int; raw default 0; the getter returns min(4, max(0, raw)).
8. `settings.preferences.key-catalog#8` — Key "last_hint_number" is an Int; default -1.
9. `settings.preferences.key-catalog#9` — Key "last_hint_timestamp" is a Long; default -1; lastHintDate returns null when the stored value is < 0, otherwise LocalDate.fromUnixTime(value).
10. `settings.preferences.key-catalog#10` — Key "pref_show_archived" is a Boolean; default false.
11. `settings.preferences.key-catalog#11` — Key "pref_show_completed" is a Boolean; default true.
12. `settings.preferences.key-catalog#12` — Key "pref_theme" is an Int; default 0 (ThemeSwitcher.THEME_AUTOMATIC).
13. `settings.preferences.key-catalog#13` — Key "launch_count" is an Int; default 0.
14. `settings.preferences.key-catalog#14` — Key "pref_developer" is a Boolean; default false.
15. `settings.preferences.key-catalog#15` — Key "pref_first_run" is a Boolean; default true.
16. `settings.preferences.key-catalog#16` — Key "pref_pure_black" is a Boolean; default false.
17. `settings.preferences.key-catalog#17` — Key "pref_short_toggle" is a Boolean; default false.
18. `settings.preferences.key-catalog#18` — Key "pref_disable_animation" is a Boolean; default false.
19. `settings.preferences.key-catalog#19` — Key "pref_sticky_notifications" is a Boolean; default false.
20. `settings.preferences.key-catalog#20` — Key "pref_checkmark_reverse_order" is a Boolean; default false.
21. `settings.preferences.key-catalog#21` — Key "pref_midnight_delay" is a Boolean; default false.
22. `settings.preferences.key-catalog#22` — Key "last_version" is an Int; default 0.
23. `settings.preferences.key-catalog#23` — Key "pref_widget_opacity" is a String holding a decimal integer; default "255"; the getter returns it parsed with toInt() and the setter writes value.toString().
24. `settings.preferences.key-catalog#24` — Key "pref_skip_enabled" is a Boolean; default false.
25. `settings.preferences.key-catalog#25` — Key "pref_unknown_enabled" is a Boolean; default false.
26. `settings.preferences.key-catalog#26` — Key "pref_first_weekday" is a String holding "1".."7"; Preferences.firstWeekday reads it with default "-1", Preferences.firstWeekdayInt reads it with default "".
27. `settings.preferences.key-catalog#27` — Preferences.clear() delegates to storage.clear(); after clear(), getDefaultHabitColor(0) returns 0.
28. `settings.preferences.key-catalog#28` — MIDNIGHT_DELAY_HOURS is a companion constant equal to 3.

#### settings.preferences.storage-contract

- [x] `settings.preferences.storage-contract` — Preferences.Storage interface and MemoryStorage semantics
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `.../preferences/MemoryStorage.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/utils/StringUtils.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`
- **Notes:** StringUtils.joinLongs/splitLongs live in uhabits-core/src/commonMain/kotlin/org/isoron/platform/utils/StringUtils.kt.

1. `settings.preferences.storage-contract#1` — Preferences.Storage declares: clear(), getBoolean(key, defValue), getInt(key, defValue), getLong(key, defValue), getString(key, defValue), onAttached(preferences) (default no-op), putBoolean, putInt, putLong, putString, remove(key).
2. `settings.preferences.storage-contract#2` — Storage.putLongArray(key, values) has a default implementation writing putString(key, values.joinToString(separator = ",")); an empty LongArray therefore writes the empty string.
3. `settings.preferences.storage-contract#3` — Storage.getLongArray(key, defValue) has a default implementation: read getString(key, ""); if the result is empty return defValue; otherwise split on "," and map each part with toLong(); if any part throws NumberFormatException the whole result is an empty LongArray (size 0), NOT defValue.
4. `settings.preferences.storage-contract#4` — MemoryStorage backs everything with a HashMap<String, String>; every put converts the value with toString().
5. `settings.preferences.storage-contract#5` — MemoryStorage.getBoolean(key, def) returns map[key]?.toBoolean() ?: def — a present-but-unparsable value such as "7" yields false, not the default; only a missing key yields the default.
6. `settings.preferences.storage-contract#6` — MemoryStorage.getInt(key, def) returns map[key]?.toIntOrNull() ?: def, so a present non-numeric value falls back to the default.
7. `settings.preferences.storage-contract#7` — MemoryStorage.getLong(key, def) returns map[key]?.toLongOrNull() ?: def.
8. `settings.preferences.storage-contract#8` — MemoryStorage.getString(key, def) returns map[key] ?: def.
9. `settings.preferences.storage-contract#9` — MemoryStorage.remove(key) deletes a single key; MemoryStorage.clear() empties the whole map.
10. `settings.preferences.storage-contract#10` — MemoryStorage.onAttached(preferences) is a no-op.

#### settings.preferences.listeners

- [x] `settings.preferences.listeners` — Preferences change listeners
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `settings.preferences.listeners#1` — Preferences.Listener has three methods, all with empty default implementations: onCheckmarkSequenceChanged(), onNotificationsChanged(), onQuestionMarksChanged().
2. `settings.preferences.listeners#2` — addListener(listener) appends to an internal MutableList; removeListener(listener) removes it. Duplicates are not de-duplicated.
3. `settings.preferences.listeners#3` — Setting isCheckmarkSequenceReversed notifies every listener via onCheckmarkSequenceChanged().
4. `settings.preferences.listeners#4` — Setting isMidnightDelayEnabled ALSO notifies onCheckmarkSequenceChanged() (there is no dedicated midnight-delay callback).
5. `settings.preferences.listeners#5` — setNotificationsSticky(sticky) notifies every listener via onNotificationsChanged().
6. `settings.preferences.listeners#6` — Setting areQuestionMarksEnabled notifies every listener via onQuestionMarksChanged().
7. `settings.preferences.listeners#7` — No other setter (theme, pure black, short toggle, skip, widget opacity, show archived/completed, developer, first run, orders, spinner positions) fires any listener callback.

#### settings.preferences.android-storage-bridge

- [ ] `settings.preferences.android-storage-bridge` — SharedPreferences-backed storage and change bridging
- **Platform:** needs-native-per-platform · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/preferences/SharedPreferencesStorage.kt`, `uhabits-android/src/main/res/xml/preferences.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** In Flutter this maps onto SharedPreferences/shared_preferences plus an explicit change stream; the un/re-register anti-recursion trick must be reproduced or made unnecessary. (Merged duplicate id: `platform-glue.shared-preferences-storage`.)

1. `settings.preferences.android-storage-bridge#1` — SharedPreferencesStorage wraps PreferenceManager.getDefaultSharedPreferences(context) and is an app-scoped singleton.
2. `settings.preferences.android-storage-bridge#2` — On construction it registers itself as an OnSharedPreferenceChangeListener and then calls PreferenceManager.setDefaultValues(context, R.xml.preferences, false), which writes the XML-declared defaults (all switches false, pref_widget_opacity "255", pref_sync_base_url "https://sync.loophabits.org", pref_sync_key "", pref_encryption_key "") into SharedPreferences the first time.
3. `settings.preferences.android-storage-bridge#3` — getString(key, defValue) force-unwraps the SharedPreferences result, so a key stored as null would throw.
4. `settings.preferences.android-storage-bridge#4` — When SharedPreferences changes, the storage first unregisters itself, then dispatches, then re-registers, so the write performed while dispatching does not re-enter the handler.
5. `settings.preferences.android-storage-bridge#5` — Only four keys are bridged back into the Preferences object on change: "pref_checkmark_reverse_order" -> preferences.isCheckmarkSequenceReversed = value; "pref_midnight_delay" -> preferences.isMidnightDelayEnabled = value; "pref_sticky_notifications" -> preferences.setNotificationsSticky(value); "pref_unknown_enabled" -> preferences.areQuestionMarksEnabled = value. Each read uses false as the default.
6. `settings.preferences.android-storage-bridge#6` — Changes to pref_short_toggle, pref_skip_enabled, pref_pure_black, pref_disable_animation, pref_widget_opacity and pref_first_weekday are NOT bridged and therefore fire no Preferences.Listener callback.
7. `settings.preferences.android-storage-bridge#7` — If onAttached(preferences) has not yet been called (preferences field null), onSharedPreferenceChanged returns immediately without dispatching.
8. `settings.preferences.android-storage-bridge#8` — Defaults declared in res/xml/preferences.xml: pref_short_toggle=false, pref_midnight_delay=false, pref_skip_enabled=false, pref_unknown_enabled=false, pref_checkmark_reverse_order=false, pref_pure_black=false, pref_disable_animation=false, pref_widget_opacity="255", pref_sticky_notifications=false, pref_developer=false, pref_sync_base_url=@string/syncBaseURL, pref_sync_key="", pref_encryption_key="".
9. `settings.preferences.android-storage-bridge#9` — pref_first_weekday is a ListPreference with no default declared in XML (populated at runtime from the locale).

#### settings.preferences.checkmark-reverse-order

- [ ] `settings.preferences.checkmark-reverse-order` — Reverse order of days
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/ButtonPanelView.kt`, `.../views/HeaderView.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/HeaderViewTest.kt`

1. `settings.preferences.checkmark-reverse-order#1` — Preference key "pref_checkmark_reverse_order", Boolean, default false.
2. `settings.preferences.checkmark-reverse-order#2` — The getter memoises: the first read loads storage.getBoolean("pref_checkmark_reverse_order", false) into a nullable in-memory field and every later read returns the cached value without touching storage. Writing through the setter updates the cache, so an external write directly to storage that bypasses the setter is not observed until the process restarts.
3. `settings.preferences.checkmark-reverse-order#3` — The setter writes the Boolean to storage and then calls onCheckmarkSequenceChanged() on every registered listener.
4. `settings.preferences.checkmark-reverse-order#4` — Settings row: SwitchPreferenceCompat in the "Interface" category, title "Reverse order of days", summary "Show days in reverse order on the main screen.", default false.
5. `settings.preferences.checkmark-reverse-order#5` — ButtonPanelView.inflateButtons() adds the freshly created buttons in reversed order when the flag is true and in natural order when false, and it re-inflates whenever onCheckmarkSequenceChanged() fires.
6. `settings.preferences.checkmark-reverse-order#6` — HeaderView.updateScrollDirection() starts with direction = -1, multiplies by -1 when isCheckmarkSequenceReversed is true, and multiplies by -1 again when the layout is RTL; the resulting product is passed to setScrollDirection.
7. `settings.preferences.checkmark-reverse-order#7` — HeaderView label placement: with reverse=true the rect for index i is offset by -(i + 1) * checkmarkWidth from the right edge; with reverse=false it is offset by (i - buttonCount) * checkmarkWidth.

#### settings.preferences.first-weekday

- [ ] `settings.preferences.first-weekday` — First day of the week (locale and preference)
- **Platform:** needs-native-per-platform · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/JavaDates.kt`, `uhabits-core/src/jsMain/kotlin/org/isoron/platform/time/JsDates.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/res/xml/preferences.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/DatesTest.kt`
- **Notes:** Flutter can derive this from MaterialLocalizations.firstDayOfWeekIndex (0=Sunday) — remember to convert to the 1-based Calendar convention used everywhere in the model. Consumers: HistoryChart, FrequencyChart, ScoreCard, TargetCard, BarCard, HistoryWidget, TargetWidget, ScoreWidget, FrequencyWidget, StackWidgetService, HistoryEditorDialog. (Merged duplicate id: `time.first-weekday`.)

1. `settings.preferences.first-weekday#1` — Preferences.firstWeekday reads storage.getString("pref_first_weekday", "-1").toInt(); if the value is < 0 it is replaced by getFirstWeekdayNumberAccordingToLocale().
2. `settings.preferences.first-weekday#2` — The integer-to-enum mapping is exactly 1->SUNDAY, 2->MONDAY, 3->TUESDAY, 4->WEDNESDAY, 5->THURSDAY, 6->FRIDAY, 7->SATURDAY; any other positive value throws IllegalArgumentException.
3. `settings.preferences.first-weekday#3` — Preferences.firstWeekdayInt (deprecated) reads storage.getString("pref_first_weekday", "") and returns getFirstWeekdayNumberAccordingToLocale() when the string is empty, otherwise weekday.toInt(). It performs no range validation.
4. `settings.preferences.first-weekday#4` — getFirstWeekdayNumberAccordingToLocale() on JVM/Android returns GregorianCalendar(Locale.getDefault()).firstDayOfWeek, i.e. 1 for Sunday through 7 for Saturday.
5. `settings.preferences.first-weekday#5` — DayOfWeek is an enum with daysSinceSunday values SUNDAY=0, MONDAY=1, TUESDAY=2, WEDNESDAY=3, THURSDAY=4, FRIDAY=5, SATURDAY=6.
6. `settings.preferences.first-weekday#6` — getWeekdaySequence(firstWeekday) returns a 7-element list where element i is DayOfWeek.entries[(firstWeekday.daysSinceSunday + i) % 7].
7. `settings.preferences.first-weekday#7` — LocalDate.startOfWeek(firstWeekday) subtracts delta days where delta = dayOfWeek.daysSinceSunday - firstWeekday.daysSinceSunday, and delta is increased by 7 when negative.
8. `settings.preferences.first-weekday#8` — The settings row is a ListPreference with key "pref_first_weekday", title "First day of the week", no summary in XML and no android:defaultValue in XML.
9. `settings.preferences.first-weekday#9` — At runtime SettingsFragment.updateWeekdayPreference() sets entryValues to exactly ["7","1","2","3","4","5","6"] and entries to JavaLocalDateFormatter(Locale.getDefault()).longWeekdayNames(DayOfWeek.SATURDAY), i.e. the 7 localized long weekday names starting at Saturday: [Saturday, Sunday, Monday, Tuesday, Wednesday, Thursday, Friday].
10. `settings.preferences.first-weekday#10` — The row summary is dayNames[currentFirstWeekday % 7] where currentFirstWeekday = firstWeekday.daysSinceSunday + 1; e.g. SUNDAY -> index 1 -> "Sunday", MONDAY -> index 2 -> "Monday", SATURDAY -> 7 % 7 = 0 -> "Saturday".
11. `settings.preferences.first-weekday#11` — updateWeekdayPreference() also calls setDefaultValue(currentFirstWeekday.toString()) each time it runs, and it runs on every onResume and on every SharedPreferences change.
12. `settings.preferences.first-weekday#12` — The first-weekday number uses the java.util.Calendar convention: 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday, 7 = Saturday.
13. `settings.preferences.first-weekday#13` — getFirstWeekdayNumberAccordingToLocale() on JS reads Intl.Locale(navigator.language).getWeekInfo().firstDay (CLDR 1=Monday..7=Sunday) and converts with firstDay % 7 + 1, defaulting to 1 (Sunday) if Intl is unavailable.
14. `settings.preferences.first-weekday#14` — Functions taking a raw Int firstWeekday (groupedSum, countSkippedDays) convert it with DayOfWeek.values()[firstWeekday - 1], so the same 1=Sunday..7=Saturday convention holds; their parameter default is 7 (SATURDAY).
15. `settings.preferences.first-weekday#15` — firstWeekday affects only week-bucketed aggregation (WEEK_NUMBER truncation) and calendar rendering; it never affects score, streak or interval computation.

#### settings.preferences.midnight-delay

- [ ] `settings.preferences.midnight-delay` — Extend day a few hours past midnight
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt`, `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/utils/MidnightTimer.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/JvmDates.kt`, `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/reminders/ReminderScheduler.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`, `uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/utils/MidnightTimerTest.kt`
- **Notes:** Merged duplicate id: `time.midnight-delay`.

1. `settings.preferences.midnight-delay#1` — Preference key "pref_midnight_delay", Boolean, default false.
2. `settings.preferences.midnight-delay#2` — The setter writes the value and then fires onCheckmarkSequenceChanged() on every listener.
3. `settings.preferences.midnight-delay#3` — Preferences.midnightDelayHours returns 3 when isMidnightDelayEnabled is true and 0 when false (MIDNIGHT_DELAY_HOURS = 3).
4. `settings.preferences.midnight-delay#4` — Settings row: SwitchPreferenceCompat in the "Interface" category, title "Extend day a few hours past midnight", summary "Wait until 3:00 AM to show a new day. Useful if you typically go to sleep after midnight. Requires app restart.", default false.
5. `settings.preferences.midnight-delay#5` — HabitsApplication.onCreate calls setToday(computeToday(preferences.midnightDelayHours, 0)) at startup, so the change only takes effect after an app restart or a midnight-timer tick.
6. `settings.preferences.midnight-delay#6` — computeToday(hourOffset, minuteOffset) computes: localMillis = System.currentTimeMillis() + timezoneOffset, subtracts hourOffset*3_600_000 + minuteOffset*60_000, then daysSinceEpoch = floorDiv(adjusted, 86_400_000) and returns LocalDate(daysSinceEpoch - 10957).
7. `settings.preferences.midnight-delay#7` — MidnightTimer schedules its next tick at DateUtils.millisecondsUntilTomorrowWithOffset(preferences.midnightDelayHours, 0) and on firing calls setToday(computeToday(preferences.midnightDelayHours, 0)).
8. `settings.preferences.midnight-delay#8` — WidgetUpdater schedules the start-of-day widget refresh at DateUtils.getStartOfTomorrowWithOffset(preferences.midnightDelayHours, 0).
9. `settings.preferences.midnight-delay#9` — Preferences.isMidnightDelayEnabled reads the boolean key "pref_midnight_delay", default false. Setting it writes the key and then fires Listener.onCheckmarkSequenceChanged() on every listener (note: not onNotificationsChanged).
10. `settings.preferences.midnight-delay#10` — Preferences.midnightDelayHours returns Preferences.MIDNIGHT_DELAY_HOURS = 3 when the delay is enabled, otherwise 0. There is no user-configurable hour value.
11. `settings.preferences.midnight-delay#11` — midnightDelayHours is consumed by: MidnightTimer.onResume (initial delay), MidnightTimer.notifyListeners (computeToday), HabitsApplication.onCreate (initial setToday), WidgetReceiver ACTION_UPDATE_WIDGETS_VALUE (setToday), and WidgetUpdater.scheduleStartDayWidgetUpdate.
12. `settings.preferences.midnight-delay#12` — It is deliberately NOT applied by ReminderScheduler.scheduleAtTime, which hard-codes offsets (0, 0) when deriving the reminder's checkmark date.

#### settings.preferences.sticky-notifications

- [ ] `settings.preferences.sticky-notifications` — Sticky (non-dismissible) notifications
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/notifications/AndroidNotificationTray.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderController.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`
- **Notes:** setOngoing and the reshow-on-dismiss workaround have no direct Flutter equivalent; flutter_local_notifications ongoing:true is the closest on Android and there is no iOS equivalent at all.

1. `settings.preferences.sticky-notifications#1` — Preference key "pref_sticky_notifications", Boolean, default false, read through shouldMakeNotificationsSticky() and written through setNotificationsSticky(sticky).
2. `settings.preferences.sticky-notifications#2` — setNotificationsSticky always notifies every listener with onNotificationsChanged(), even when the value did not change.
3. `settings.preferences.sticky-notifications#3` — Settings row: SwitchPreferenceCompat in the "Reminder" category, title "Make notifications sticky", summary "Prevents notifications from being swiped away.", default false.
4. `settings.preferences.sticky-notifications#4` — AndroidNotificationTray builds every reminder with NotificationCompat.Builder(...).setOngoing(preferences.shouldMakeNotificationsSticky()).
5. `settings.preferences.sticky-notifications#5` — ReminderController.onDismiss(habit): when sticky is enabled it calls notificationTray.reshow(habit) instead of cancelling, so a swiped-away notification is immediately recreated (workaround for Android 14+); when sticky is disabled it calls notificationTray.cancel(habit).

#### settings.preferences.short-toggle

- [ ] `settings.preferences.short-toggle` — Toggle with short press
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/CheckmarkButtonView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/HistoryCard.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/EntryButtonViewTest.kt`

1. `settings.preferences.short-toggle#1` — Preference key "pref_short_toggle", Boolean, default false.
2. `settings.preferences.short-toggle#2` — Settings row: first SwitchPreferenceCompat of the "Interface" category, title "Toggle with short press", summary "Put checkmarks with a single tap instead of press-and-hold.", default false.
3. `settings.preferences.short-toggle#3` — CheckmarkButtonView routes a single tap to the toggle action when the flag is true; when false a single tap only shows a hint/notes affordance and a long press performs the toggle.
4. `settings.preferences.short-toggle#4` — HistoryCard behaviour branches on preferences.isShortToggleEnabled in the same way for the history editor.
5. `settings.preferences.short-toggle#5` — The setter fires no listener callback and the SharedPreferences bridge does not forward this key, so views read it lazily on the next interaction.

#### settings.preferences.skip-enabled

- [ ] `settings.preferences.skip-enabled` — Enable skip days
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/CheckmarkDialog.kt`, `.../dialogs/NumberDialog.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsMenu.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehaviorTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryTest.kt`

1. `settings.preferences.skip-enabled#1` — Preference key "pref_skip_enabled", Boolean, default false.
2. `settings.preferences.skip-enabled#2` — Settings row: SwitchPreferenceCompat in the "Interface" category, title "Enable skip days", summary "Toggle twice to add a skip instead of a checkmark. Skips keep your score unchanged and don't break your streak.", default false.
3. `settings.preferences.skip-enabled#3` — The value is fed into Entry.nextToggleValue(...) as isSkipEnabled, which changes the YES_MANUAL successor from NO to SKIP when true.
4. `settings.preferences.skip-enabled#4` — CheckmarkDialog hides its skip button (visibility GONE) when isSkipEnabled is false; NumberDialog hides skipBtnNumber under the same condition.
5. `settings.preferences.skip-enabled#5` — ListHabitsMenu relabels the "Hide completed" filter item to "Hide entered" when either areQuestionMarksEnabled or isSkipEnabled is true.

#### settings.preferences.question-marks

- [ ] `settings.preferences.question-marks` — Show question marks for missing data
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryTest.kt`

1. `settings.preferences.question-marks#1` — Preference key "pref_unknown_enabled", Boolean, default false.
2. `settings.preferences.question-marks#2` — The setter writes the value and then fires onQuestionMarksChanged() on every listener.
3. `settings.preferences.question-marks#3` — Settings row: SwitchPreferenceCompat in the "Interface" category, title "Show question marks for missing data", summary "Differentiate days without data from actual lapses. To enter a lapse, toggle twice.", default false.
4. `settings.preferences.question-marks#4` — The value is fed into Entry.nextToggleValue(...) as areQuestionMarksEnabled, which changes the NO successor from YES_MANUAL to UNKNOWN when true.
5. `settings.preferences.question-marks#5` — ListHabitsMenuBehavior.updateAdapterFilter() builds HabitMatcher(isEnteredAllowed = showCompleted) when question marks are enabled and HabitMatcher(isCompletedAllowed = showCompleted) when disabled.
6. `settings.preferences.question-marks#6` — CheckmarkDialog hides its unknown button and NumberDialog hides unknownBtnNumber when areQuestionMarksEnabled is false.
7. `settings.preferences.question-marks#7` — ListHabitsActivity implements onQuestionMarksChanged() by calling invalidateOptionsMenu() and menu.behavior.onPreferencesChanged(), which re-applies the adapter filter immediately when the switch is flipped in settings.

#### settings.preferences.disable-animations

- [ ] `settings.preferences.disable-animations` — Disable confetti animation
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `settings.preferences.disable-animations#1` — Preference key "pref_disable_animation", Boolean, default false (i.e. the confetti animation is ON by default).
2. `settings.preferences.disable-animations#2` — Settings row: SwitchPreferenceCompat in the "Interface" category, title "Disable animations", summary "Disable confetti animation after adding a checkmark.", default false.
3. `settings.preferences.disable-animations#3` — ListHabitsScreen.showConfetti(color, x, y) returns immediately without animating when preferences.isConfettiAnimationDisabled is true.
4. `settings.preferences.disable-animations#4` — showConfetti also returns immediately when both x == 0f and y == 0f, regardless of the preference.
5. `settings.preferences.disable-animations#5` — ListHabitsBehavior.onToggle only requests confetti when the new entry value is Entry.YES_MANUAL.

#### settings.preferences.widget-opacity

- [ ] `settings.preferences.widget-opacity` — Widget opacity
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/res/values/constants.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/widgets/BaseWidget.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/CheckmarkWidgetTest.kt`, `.../StreakWidgetTest.kt`, `.../TargetWidgetTest.kt`, `.../FrequencyWidgetTest.kt`, `.../HistoryWidgetTest.kt`, `.../ScoreWidgetTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`
- **Notes:** The preference itself is trivial, but it only means anything for Android home-screen widgets rendered through RemoteViews; Flutter has no cross-platform equivalent. (Merged duplicate id: `widgets.opacity-setting`.)

1. `settings.preferences.widget-opacity#1` — Key "pref_widget_opacity" is stored as a String; Preferences.widgetOpacity returns storage.getString("pref_widget_opacity", "255").toInt() and the setter writes value.toString(). A non-numeric stored value makes the getter throw NumberFormatException.
2. `settings.preferences.widget-opacity#2` — Settings row: ListPreference in the "Interface" category, title "Widget opacity", summary "Makes widgets more transparent or more opaque in your home screen.", android:defaultValue "255".
3. `settings.preferences.widget-opacity#3` — Entry labels are exactly ["100%", "80%", "60%", "40%", "20%", "0%"] and the matching stored values are exactly ["255", "204", "153", "102", "51", "0"] (index-aligned).
4. `settings.preferences.widget-opacity#4` — SettingsFragment.onSharedPreferenceChanged calls widgetUpdater.updateWidgets() when and only when the changed key equals "pref_widget_opacity" (and the widget updater is non-null).
5. `settings.preferences.widget-opacity#5` — BaseWidget.preferedBackgroundAlpha returns 255 when the widget is rendered inside a stack widget and prefs.widgetOpacity otherwise.
6. `settings.preferences.widget-opacity#6` — The opacity is applied as the alpha of the widget card's background paint only; text, rings and charts are not made transparent.
7. `settings.preferences.widget-opacity#7` — Widgets rendered inside a StackWidget ignore this preference and always use alpha 255.
8. `settings.preferences.widget-opacity#8` — At alpha 255 the widget additionally gains a drop shadow (shadow alpha 0x4f); below 255 the graph widgets have no shadow.

#### settings.preferences.habit-list-orders

- [ ] `settings.preferences.habit-list-orders` — Persisted habit list sort orders
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsMenu.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`
- **Notes:** The asymmetric fallback in defaultSecondaryOrder looks like an upstream bug but is observable behaviour; decide explicitly whether to port it.

1. `settings.preferences.habit-list-orders#1` — defaultPrimaryOrder reads storage.getString("pref_default_order", "BY_POSITION") and resolves it with HabitList.Order.valueOf.
2. `settings.preferences.habit-list-orders#2` — When the stored primary order string is not a valid enum name, the getter catches IllegalArgumentException, writes BY_POSITION back to storage and returns BY_POSITION.
3. `settings.preferences.habit-list-orders#3` — defaultSecondaryOrder reads storage.getString("pref_default_secondary_order", "BY_NAME_ASC").
4. `settings.preferences.habit-list-orders#4` — When the stored secondary order string is not a valid enum name, the getter writes BY_NAME_ASC back to storage but RETURNS BY_POSITION — the written and returned values deliberately differ (verbatim behaviour of the Kotlin code).
5. `settings.preferences.habit-list-orders#5` — Both setters write order.name as a String.
6. `settings.preferences.habit-list-orders#6` — ListHabitsMenu.updateArrows reads defaultPrimaryOrder to decide which sort menu item shows an up or down arrow icon.

#### settings.preferences.card-spinner-positions

- [ ] `settings.preferences.card-spinner-positions` — Persisted chart spinner positions
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`

1. `settings.preferences.card-spinner-positions#1` — scoreCardSpinnerPosition getter returns min(4, max(0, storage.getInt("pref_score_view_interval", 1))); the setter stores the raw value unclamped, so writing 9000 stores 9000 but reads back as 4.
2. `settings.preferences.card-spinner-positions#2` — barCardBoolSpinnerPosition getter returns min(3, max(0, storage.getInt("pref_bar_card_bool_spinner", 0))).
3. `settings.preferences.card-spinner-positions#3` — barCardNumericalSpinnerPosition getter returns min(4, max(0, storage.getInt("pref_bar_card_numerical_spinner", 0))).
4. `settings.preferences.card-spinner-positions#4` — Negative stored values clamp to 0 in all three cases.
5. `settings.preferences.card-spinner-positions#5` — These three preferences have no settings-screen rows; they are written by the chart spinners on the habit detail screen.

#### settings.preferences.hints

- [ ] `settings.preferences.hints` — Hint bookkeeping
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`

1. `settings.preferences.hints#1` — lastHintNumber is read-only and returns storage.getInt("last_hint_number", -1).
2. `settings.preferences.hints#2` — lastHintDate reads storage.getLong("last_hint_timestamp", -1) and returns null when the value is negative, otherwise LocalDate.fromUnixTime(unixTime).
3. `settings.preferences.hints#3` — updateLastHint(number, date) writes storage.putInt("last_hint_number", number) and storage.putLong("last_hint_timestamp", date.unixTime).
4. `settings.preferences.hints#4` — LocalDate.unixTime = 946684800000 + daysSince2000 * 86400000.
5. `settings.preferences.hints#5` — On first run, ListHabitsBehavior.onFirstRun() calls updateLastHint(-1, getToday()), which stores hint number -1 together with today's timestamp.

#### settings.preferences.first-run-and-launch-count

- [ ] `settings.preferences.first-run-and-launch-count` — First run flag, launch count and last app version
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`

1. `settings.preferences.first-run-and-launch-count#1` — isFirstRun reads "pref_first_run" with default true and is settable.
2. `settings.preferences.first-run-and-launch-count#2` — launchCount is read-only, key "launch_count", default 0; incrementLaunchCount() writes launchCount + 1.
3. `settings.preferences.first-run-and-launch-count#3` — lastAppVersion reads/writes "last_version" as an Int with default 0.
4. `settings.preferences.first-run-and-launch-count#4` — HabitsApplication.onCreate unconditionally assigns prefs.lastAppVersion = BuildConfig.VERSION_CODE on every launch.
5. `settings.preferences.first-run-and-launch-count#5` — ListHabitsBehavior.onStartup() calls prefs.incrementLaunchCount() FIRST and only then checks prefs.isFirstRun, so launch_count is already 1 during the first-run branch.
6. `settings.preferences.first-run-and-launch-count#6` — When isFirstRun is true, onFirstRun() runs: prefs.isFirstRun = false, prefs.updateLastHint(-1, getToday()), screen.showIntroScreen(); in that order.

#### settings.preferences.show-archived-completed

- [ ] `settings.preferences.show-archived-completed` — Show archived / show completed filters
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsMenu.kt`, `uhabits-android/src/main/res/menu/list_habits.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`

1. `settings.preferences.show-archived-completed#1` — showArchived reads/writes "pref_show_archived", Boolean, default false.
2. `settings.preferences.show-archived-completed#2` — showCompleted reads/writes "pref_show_completed", Boolean, default true.
3. `settings.preferences.show-archived-completed#3` — These have no settings-screen rows; they are toggled from the main-screen filter menu items "Hide archived" and "Hide completed".
4. `settings.preferences.show-archived-completed#4` — ListHabitsMenu sets the checked state of the filter items to the NEGATION of the preference: hideArchivedItem.isChecked = !preferences.showArchived and hideCompletedItem.isChecked = !preferences.showCompleted.

#### settings.widget-preferences.habit-ids

- [x] `settings.widget-preferences.habit-ids` — WidgetPreferences habit-id mapping (and snooze storage keys)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/WidgetPreferences.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/utils/StringUtils.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Only meaningful together with Android home-screen widgets, but the key format and legacy migration must be preserved for anyone importing existing SharedPreferences. No dedicated unit test exists for WidgetPreferences; the legacy single-long migration path is untested. (Merged duplicate id: `widgets.preferences`.)

1. `settings.widget-preferences.habit-ids#1` — The storage key for a widget's habit list is format("widget-%06d-habit", widgetId), i.e. the widget id zero-padded to at least 6 digits, e.g. widget id 42 -> "widget-000042-habit".
2. `settings.widget-preferences.habit-ids#2` — addWidget(widgetId, habitIds) writes storage.putLongArray(key, habitIds), which serialises the ids as a comma-separated decimal string.
3. `settings.widget-preferences.habit-ids#3` — getHabitIdsFromWidgetId(widgetId) first tries storage.getLongArray(key, longArrayOf()); if that throws ClassCastException (legacy data from Loop <= 1.7.11 where the key held a single Long) it falls back to storage.getLong(key, -1) and returns an empty LongArray when the result is -1L, or a single-element array otherwise.
4. `settings.widget-preferences.habit-ids#4` — removeWidget(id) calls storage.remove(key) for the same formatted key.
5. `settings.widget-preferences.habit-ids#5` — Because putLongArray serialises an empty array to the empty string and getLongArray returns the supplied default for an empty string, a widget stored with no habits reads back as an empty LongArray.
6. `settings.widget-preferences.habit-ids#6` — WidgetPreferences is an app-scoped class wrapping Preferences.Storage.
7. `settings.widget-preferences.habit-ids#7` — removeWidget(id) deletes the key entirely; this is invoked from BaseWidget.delete() when the launcher reports the widget was removed.
8. `settings.widget-preferences.habit-ids#8` — Snooze times are stored in the same class under key format("snooze-%06d", id.toInt()) where id is a habit id: getSnoozeTime(habitId) defaults to 0, setSnoozeTime(id, time) writes the value, and removeSnoozeTime(id) writes 0 rather than deleting the key.
9. `settings.widget-preferences.habit-ids#9` — Widget preferences survive app restarts and are the only per-widget configuration — there are no other per-widget settings (no per-widget colour, size or opacity).

#### settings.theme.theme-modes

- [ ] `settings.theme.theme-modes` — Theme modes: automatic / light / dark, and the theme switcher
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/ThemeSwitcher.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/AndroidThemeSwitcher.kt`, `uhabits-android/src/main/res/values/styles.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`
- **Notes:** Reading the OS dark-mode flag maps to MediaQuery.platformBrightness in Flutter; the SDK<29 forced-light rule is Android-specific and probably should be dropped. (Merged duplicate ids: `charts-canvas-theming.theme-switcher`, `platform-glue.theme-switcher-glue`.)

1. `settings.theme.theme-modes#1` — ThemeSwitcher exposes three constants: THEME_AUTOMATIC = 0, THEME_DARK = 1, THEME_LIGHT = 2. Preferences.theme defaults to THEME_AUTOMATIC (0).
2. `settings.theme.theme-modes#2` — isNightMode == (userTheme == THEME_DARK) || (systemTheme == THEME_DARK && userTheme == THEME_AUTOMATIC). In particular userTheme == THEME_LIGHT is never night mode, whatever the system says.
3. `settings.theme.theme-modes#3` — "Automatic" means FOLLOW THE SYSTEM DARK-MODE SETTING in this version; there is no time-of-day based automatic switching anywhere in the codebase.
4. `settings.theme.theme-modes#4` — apply() calls applyPureBlackTheme() when isNightMode && preferences.isPureBlackEnabled, applyDarkTheme() when isNightMode && !isPureBlackEnabled, and applyLightTheme() otherwise.
5. `settings.theme.theme-modes#5` — AndroidThemeSwitcher.getSystemTheme() returns THEME_LIGHT unconditionally when Build.VERSION.SDK_INT < 29; on API 29+ it returns THEME_DARK when (resources.configuration.uiMode and UI_MODE_NIGHT_MASK) == UI_MODE_NIGHT_YES and THEME_LIGHT otherwise.
6. `settings.theme.theme-modes#6` — AndroidThemeSwitcher.currentTheme is initialised to LightTheme() before any apply() call.
7. `settings.theme.theme-modes#7` — applyLightTheme() sets currentTheme = LightTheme() and applies style AppBaseTheme; it does NOT change the navigation bar colour.
8. `settings.theme.theme-modes#8` — applyDarkTheme() sets currentTheme = DarkTheme(), applies style AppBaseThemeDark and sets window.navigationBarColor to R.color.grey_900.
9. `settings.theme.theme-modes#9` — applyPureBlackTheme() sets currentTheme = PureBlackTheme(), applies style AppBaseThemeDark_PureBlack and sets window.navigationBarColor to R.color.black.
10. `settings.theme.theme-modes#10` — applyDialog() applies style BaseDialogDark and paints the decor view grey_900 when isNightMode, and applies style BaseDialog otherwise.
11. `settings.theme.theme-modes#11` — AndroidThemeSwitcher is @ActivityScope, extends the core ThemeSwitcher, and starts with currentTheme = LightTheme().
12. `settings.theme.theme-modes#12` — applyDarkTheme and applyPureBlackTheme cast context to Activity, so calling them with a non-Activity context throws ClassCastException.
13. `settings.theme.theme-modes#13` — View.currentTheme() is a helper that constructs a fresh AndroidThemeSwitcher from the application component's preferences, calls apply(), and returns its currentTheme — meaning a theme switcher is created per call, not reused.

#### settings.theme.toggle-night-mode

- [ ] `settings.theme.toggle-night-mode` — Dark theme toggle in the overflow menu
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/ThemeSwitcher.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsMenu.kt`, `.../ListHabitsScreen.kt`, `.../ListHabitsActivity.kt`, `uhabits-android/src/main/res/menu/list_habits.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehaviorTest.kt`
- **Notes:** The activity restart-with-fade has no Flutter analogue; a Flutter port would rebuild the widget tree instead. (Merged duplicate id: `list-habits.night-mode-toggle`.)

1. `settings.theme.toggle-night-mode#1` — The main-screen overflow menu contains a checkable item titled "Dark theme" (R.id.actionToggleNightMode, orderInCategory 50, showAsAction never) whose checked state equals themeSwitcher.isNightMode.
2. `settings.theme.toggle-night-mode#2` — Selecting it runs ListHabitsMenuBehavior.onToggleNightMode(), which calls themeSwitcher.toggleNightMode() and then screen.applyTheme().
3. `settings.theme.toggle-night-mode#3` — toggleNightMode() truth table (userTheme, systemTheme -> new userTheme): (AUTOMATIC, LIGHT) -> DARK; (AUTOMATIC, DARK) -> LIGHT; (LIGHT, LIGHT) -> DARK; (LIGHT, DARK) -> AUTOMATIC; (DARK, LIGHT) -> AUTOMATIC; (DARK, DARK) -> LIGHT.
4. `settings.theme.toggle-night-mode#4` — toggleNightMode() therefore cycles through three states and can land back on AUTOMATIC only when the resulting appearance matches the system setting.
5. `settings.theme.toggle-night-mode#5` — ListHabitsScreen.applyTheme() calls themeSwitcher.apply() and then restarts ListHabitsActivity with a fade transition; the theme change is not applied in place.
6. `settings.theme.toggle-night-mode#6` — Theme constants: THEME_AUTOMATIC = 0, THEME_LIGHT = 2, THEME_DARK = 1; the value is persisted under the preference key 'pref_theme'.
7. `settings.theme.toggle-night-mode#7` — After toggling, the screen applies the theme and restarts the activity: finish(), fade_in/fade_out transition, then start a new ListHabitsActivity — all inside a 500 ms postDelayed so the menu can close first.
8. `settings.theme.toggle-night-mode#8` — Applying the theme picks the pure-black variant instead of the dark variant when preferences.isPureBlackEnabled (key 'pref_pure_black', default false) is true.
9. `settings.theme.toggle-night-mode#9` — On resume, if preferences.theme == THEME_DARK and preferences.isPureBlackEnabled differs from the value captured in onCreate, the activity restarts with the same fade.

#### settings.theme.pure-black

- [ ] `settings.theme.pure-black` — Pure black (AMOLED) dark theme
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/ThemeSwitcher.kt`, `.../ui/views/Themes.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/AndroidThemeSwitcher.kt`, `.../activities/habits/list/ListHabitsActivity.kt`, `uhabits-android/src/main/res/values/styles.xml`, `uhabits-android/src/main/res/xml/preferences.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`
- **Notes:** The THEME_DARK-only restart condition is an observable quirk worth reproducing or deliberately fixing.

1. `settings.theme.pure-black#1` — Preference key "pref_pure_black", Boolean, default false.
2. `settings.theme.pure-black#2` — Settings row: SwitchPreferenceCompat in the "Interface" category, title "Use pure black in dark theme", summary "Replaces gray backgrounds with pure black in dark theme. Reduces battery usage in phones with AMOLED display.", default false.
3. `settings.theme.pure-black#3` — Pure black is only honoured when isNightMode is true; in light mode the flag has no visual effect.
4. `settings.theme.pure-black#4` — PureBlackTheme extends DarkTheme and overrides exactly three colours: appBackgroundColor = 0x000000, cardBackgroundColor = 0x000000, lowContrastTextColor = 0x212121. Every other value (including the dark palette) is inherited from DarkTheme.
5. `settings.theme.pure-black#5` — The Android style AppBaseThemeDark.PureBlack overrides android:textColor=grey_200, cardBgColor/colorPrimary/colorPrimaryDark/headerBackgroundColor/highlightedBackgroundColor/windowBackgroundColor = black, contrast0=black, contrast20=grey_900, contrast40=grey_800, contrast60=grey_500, contrast80=grey_400, contrast100=grey_200.
6. `settings.theme.pure-black#6` — ListHabitsActivity captures pureBlack = prefs.isPureBlackEnabled in onCreate, and in onResume restarts itself with a fade if and only if prefs.theme == THEME_DARK AND prefs.isPureBlackEnabled != the captured value. Toggling pure black while the theme is AUTOMATIC (even if the system is dark) does NOT trigger that automatic restart.

#### settings.screen.structure

- [ ] `settings.screen.structure` — Settings screen structure and hosting
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsActivity.kt`, `.../settings/SettingsFragment.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/res/layout/settings_activity.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/AboutTest.kt`, `.../acceptance/LinksTest.kt`
- **Notes:** androidx PreferenceFragmentCompat has no Flutter equivalent; the screen must be rebuilt as an ordinary scrollable settings list. BackupManager.dataChanged is Android-only.

1. `settings.screen.structure#1` — SettingsActivity applies the theme via AndroidThemeSwitcher(this, preferences).apply() BEFORE inflating its layout, sets a toolbar titled "Settings" coloured with PaletteColor(11), and hosts SettingsFragment via a <fragment> tag below the toolbar.
2. `settings.screen.structure#2` — The preference screen contains exactly six PreferenceCategory blocks in this order with these titles: "Interface" (key interfaceCategory), "Reminder" (key reminderCategory), "Database" (key databaseCategory), "Troubleshooting" (key pref_key_debug), "Links" (key linksCategory), "Development" (key devCategory, hard-coded English title "Development").
3. `settings.screen.structure#3` — The Interface category rows in order are: pref_short_toggle, pref_midnight_delay, pref_skip_enabled, pref_unknown_enabled, pref_checkmark_reverse_order, pref_pure_black, pref_disable_animation, pref_widget_opacity, pref_first_weekday.
4. `settings.screen.structure#4` — Every preference sets app:iconSpaceReserved="false", so no row reserves leading icon space.
5. `settings.screen.structure#5` — SettingsFragment paints its root view with the themed attribute R.attr.contrast0 in onViewCreated.
6. `settings.screen.structure#6` — The fragment registers itself as an OnSharedPreferenceChangeListener in onResume and unregisters in onPause.
7. `settings.screen.structure#7` — In onResume the fragment hides the whole devCategory (isVisible = false) when prefs.isDeveloper is false, and always hides the "reminderSound" row (findPreference("reminderSound").isVisible = false), so the Reminder sound row is never shown to users in this build.
8. `settings.screen.structure#8` — onSharedPreferenceChanged always calls BackupManager.dataChanged("org.isoron.uhabits") and always re-runs updateWeekdayPreference(), regardless of which key changed.

#### settings.screen.reminder-category

- [ ] `settings.screen.reminder-category` — Reminder settings rows
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/notifications/RingtoneManager.kt`, `.../notifications/AndroidNotificationTray.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/NotificationTray.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Ringtone picker, notification channels and the system channel-settings intent are Android-only; the row is currently hidden but the pref_ringtone_uri key is still read when posting reminders. (Merged duplicate id: `notifications.settings-screen`.)

1. `settings.screen.reminder-category#1` — Row "reminderSound" (title "Reminder sound") exists in the XML but is force-hidden in onResume, so it is not user-visible.
2. `settings.screen.reminder-category#2` — When visible, clicking reminderSound launches ACTION_RINGTONE_PICKER with EXTRA_RINGTONE_TYPE = TYPE_NOTIFICATION, EXTRA_RINGTONE_SHOW_DEFAULT = true, EXTRA_RINGTONE_SHOW_SILENT = true, EXTRA_RINGTONE_DEFAULT_URI = Settings.System.DEFAULT_NOTIFICATION_URI and EXTRA_RINGTONE_EXISTING_URI = the currently stored URI, using request code 1.
3. `settings.screen.reminder-category#3` — On result for request code 1, RingtoneManager.update(data) stores data.getParcelableExtra(EXTRA_RINGTONE_PICKED_URI).toString() under key "pref_ringtone_uri", or the empty string when the extra is null (silent), and the row summary is refreshed with the ringtone title.
4. `settings.screen.reminder-category#4` — RingtoneManager.getURI() reads "pref_ringtone_uri" with default Settings.System.DEFAULT_NOTIFICATION_URI.toString(); an empty stored string yields a null URI (silent).
5. `settings.screen.reminder-category#5` — RingtoneManager.getName() returns the localized string "None" when the URI is null or the ringtone cannot be resolved, and returns null (leaving the summary unchanged) if a RuntimeException is thrown.
6. `settings.screen.reminder-category#6` — Row "pref_sticky_notifications": SwitchPreferenceCompat, title "Make notifications sticky", summary "Prevents notifications from being swiped away.", default false.
7. `settings.screen.reminder-category#7` — Row "reminderCustomize": title "Customize notifications", summary "Change sound, vibration, light and other notification settings"; clicking it first calls AndroidNotificationTray.createAndroidNotificationChannel(context) and then starts Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS with EXTRA_APP_PACKAGE = the app package and EXTRA_CHANNEL_ID = "REMINDERS".
8. `settings.screen.reminder-category#8` — The reminders notification channel id is the constant NotificationTray.REMINDERS_CHANNEL_ID = "REMINDERS", created with name = the localized string "Reminder" and importance IMPORTANCE_DEFAULT.
9. `settings.screen.reminder-category#9` — The settings screen has a PreferenceCategory keyed "reminderCategory" titled with the string reminder ("Reminder"), containing three rows in this order: "reminderSound", "pref_sticky_notifications", "reminderCustomize".
10. `settings.screen.reminder-category#10` — Every shared-preference change triggers BackupManager.dataChanged("org.isoron.uhabits").

#### settings.screen.database-category

- [ ] `settings.screen.database-category` — Database settings rows (export, import, public backup folder) and result codes
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/database/AutoBackup.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/tasks/ExportDBTask.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/BackupTest.kt`, `.../acceptance/steps/BackupSteps.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`
- **Notes:** Storage Access Framework tree URIs, persistable permissions and DocumentFile have no Flutter equivalent; a port needs a platform-specific folder picker. (Merged duplicate id: `io.settings-database-section`.)

1. `settings.screen.database-category#1` — Row "exportDB": title "Export full backup", summary "Generates a file that contains all your data. This file can be imported back."
2. `settings.screen.database-category#2` — Row "exportCSV": title "Export as CSV", summary "Generates files that can be opened by spreadsheet software such as Microsoft Excel or OpenOffice Calc. This file cannot be imported back."
3. `settings.screen.database-category#3` — Row "importData": title "Import data", summary "Supports full backups exported by this app, as well as files generated by Tickmate, HabitBull or Rewire. See FAQ for more information."
4. `settings.screen.database-category#4` — Clicking exportDB, exportCSV, importData, repairDB or bugReport calls requireActivity().setResult(code) followed by requireActivity().finish(); the codes are RESULT_IMPORT_DATA = 101, RESULT_EXPORT_CSV = 102, RESULT_EXPORT_DB = 103, RESULT_BUG_REPORT = 104, RESULT_REPAIR_DB = 105.
5. `settings.screen.database-category#5` — ListHabitsScreen.onSettingsResult dispatches those codes to showImportScreen(), behavior.onExportCSV(), onExportDB(), behavior.onSendBugReport() and behavior.onRepairDB() respectively — i.e. the settings screen never performs the work itself, it closes and lets the list screen do it.
6. `settings.screen.database-category#6` — Row "publicBackupFolder": title "Select public backup folder"; its summary is "No folder selected" when the key "publicBackupFolder" is unset.
7. `settings.screen.database-category#7` — Clicking publicBackupFolder starts Intent.ACTION_OPEN_DOCUMENT_TREE with FLAG_GRANT_READ_URI_PERMISSION | FLAG_GRANT_WRITE_URI_PERMISSION | FLAG_GRANT_PERSISTABLE_URI_PERMISSION using request code 2.
8. `settings.screen.database-category#8` — On result for request code 2 with a non-null data URI, the fragment calls takePersistableUriPermission(uri, READ|WRITE), stores uri.toString() under "publicBackupFolder", and refreshes the summary. A null data URI is ignored silently.
9. `settings.screen.database-category#9` — updatePublicBackupFolderSummary() renders a human-readable path: for a "content" URI it takes DocumentsContract.getTreeDocumentId(uri), splits it on the first ":" into (type, rel), uses Environment.getExternalStorageDirectory().absolutePath as base when type equalsIgnoreCase "primary" and "/storage/<type>" otherwise, and appends "/<rel>" when rel is non-empty; for a "file" URI it uses File(uri.path).absolutePath; for any other scheme it falls back to the raw URI string.
10. `settings.screen.database-category#10` — AutoBackup and ExportDBTask both read "publicBackupFolder" directly from default SharedPreferences: when set they write into that DocumentFile tree (DocumentFile.fromTreeUri for content URIs, DocumentFile.fromFile for file URIs), otherwise they fall back to the app-private "Backups" files directory.
11. `settings.screen.database-category#11` — AutoBackup keeps the newest 5 backup files by default (keep = 5) and matches existing backups with the regex ^Loop Habits Backup .+\\.db$.
12. `settings.screen.database-category#12` — The 'Database' preference category contains, in order: 'exportDB', 'exportCSV', 'importData', and 'publicBackupFolder'.
13. `settings.screen.database-category#13` — Each of these preferences sets an activity result and finishes the settings screen; the list screen dispatches on the result codes IMPORT_DATA = 101, EXPORT_CSV = 102, EXPORT_DB = 103, BUG_REPORT = 104, REPAIR_DB = 105, delivered through REQUEST_SETTINGS = 107.
14. `settings.screen.database-category#14` — ListHabitsBehavior.Message has exactly six values used by this domain and the repair action: COULD_NOT_EXPORT, IMPORT_SUCCESSFUL, IMPORT_FAILED, DATABASE_REPAIRED, COULD_NOT_GENERATE_BUG_REPORT, FILE_NOT_RECOGNIZED.
15. `settings.screen.database-category#15` — Message strings: COULD_NOT_EXPORT -> 'Failed to export data.', IMPORT_SUCCESSFUL -> 'Habits imported successfully.', IMPORT_FAILED -> 'Failed to import data.', DATABASE_REPAIRED -> 'Database repaired.', COULD_NOT_GENERATE_BUG_REPORT -> bug report failure string, FILE_NOT_RECOGNIZED -> 'File not recognized.'.
16. `settings.screen.database-category#16` — 'repairDB' (RESULT_REPAIR_DB = 105) runs habitList.repair() on the task runner and then shows DATABASE_REPAIRED.

#### settings.screen.troubleshooting-and-links

- [ ] `settings.screen.troubleshooting-and-links` — Troubleshooting and Links settings rows
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`, `uhabits-android/src/main/res/values/constants.xml`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/LinksTest.kt`, `.../acceptance/AboutTest.kt`

1. `settings.screen.troubleshooting-and-links#1` — Troubleshooting category (key pref_key_debug, title "Troubleshooting") contains exactly two rows: "bugReport" titled "Generate bug report" and "repairDB" titled "Repair database"; both close settings with result codes 104 and 105 respectively.
2. `settings.screen.troubleshooting-and-links#2` — Bug reports are emailed to "dev@loophabits.org" with subject "Bug Report - Loop Habit Tracker"; if BugReporter.getBugReport() throws, the list screen shows the message for COULD_NOT_GENERATE_BUG_REPORT instead.
3. `settings.screen.troubleshooting-and-links#3` — Repairing the database shows the message "Database repaired." when finished.
4. `settings.screen.troubleshooting-and-links#4` — Links category (title "Links") contains exactly three rows in order: a row titled "Help & FAQ" carrying a nested <intent> with action VIEW and data http://loophabits.org/faq.html; a row keyed "rateApp" titled "Rate this app on Google Play"; and a row titled "About" carrying a nested <intent> with action VIEW targeting class org.isoron.uhabits.activities.about.AboutActivity in package org.isoron.uhabits.
5. `settings.screen.troubleshooting-and-links#5` — Clicking "rateApp" builds Intent(ACTION_VIEW, Uri.parse("market://details?id=org.isoron.uhabits")) and launches it via startActivitySafely.
6. `settings.screen.troubleshooting-and-links#6` — startActivitySafely catches ActivityNotFoundException and shows the snackbar "No app was found to support this action" instead of crashing.

#### settings.screen.developer-category

- [ ] `settings.screen.developer-category` — Hidden Development category
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/res/values/constants.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Verified by grep: pref_sync_base_url / pref_sync_key / pref_encryption_key appear only in preferences.xml.

1. `settings.screen.developer-category#1` — The Development category (key devCategory) is hidden whenever prefs.isDeveloper is false; the visibility is recomputed in SettingsFragment.onResume, so enabling developer mode and re-entering settings reveals it.
2. `settings.screen.developer-category#2` — Row "pref_developer": SwitchPreferenceCompat titled "Enable developer mode" (hard-coded English), default false.
3. `settings.screen.developer-category#3` — Row "pref_sync_base_url": EditTextPreference titled "Sync server", android:defaultValue = the string resource syncBaseURL = "https://sync.loophabits.org".
4. `settings.screen.developer-category#4` — Row "pref_sync_key": EditTextPreference titled "Sync key", default empty string.
5. `settings.screen.developer-category#5` — Row "pref_encryption_key": EditTextPreference titled "Encryption key", default empty string.
6. `settings.screen.developer-category#6` — The three sync/encryption keys are written into SharedPreferences but are not read anywhere else in the codebase in this fork — they are inert.

#### settings.about.screen

- [ ] `settings.about.screen` — About screen content and links
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/about/AboutActivity.kt`, `.../about/AboutScreen.kt`, `.../about/AboutView.kt`, `uhabits-android/src/main/res/layout/about.xml`, `.../layout/about_translators.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentFactory.kt`, `uhabits-android/src/main/res/values/constants.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/AboutTest.kt`, `.../acceptance/LinksTest.kt`
- **Notes:** about_translators.xml holds ~217 TextViews and is machine-generated; port it as data, not markup.

1. `settings.about.screen#1` — AboutActivity applies the theme with AndroidThemeSwitcher(this, preferences).apply() and sets AboutView as its content view; the toolbar is titled "About" and coloured with PaletteColor(11).
2. `settings.about.screen#2` — The first card shows the drawable intro_icon_1 at 100dp x 100dp, the bold 16sp app name "Loop Habit Tracker" in the themed aboutScreenColor, and a version line formatted from the string "Version %s" with BuildConfig.VERSION_NAME.
3. `settings.about.screen#3` — The second card is headed "Links" and contains exactly five clickable rows in order: "Rate this app on Google Play", "Send feedback to developer", "Help translate this app", "View source code at GitHub", "View privacy policy".
4. `settings.about.screen#4` — Link targets: rate -> ACTION_VIEW market://details?id=org.isoron.uhabits; feedback -> ACTION_SENDTO mailto:dev@loophabits.org?subject=Feedback%20about%20Loop%20Habit%20Tracker; translate -> ACTION_VIEW http://translate.loophabits.org/; source -> ACTION_VIEW https://github.com/iSoron/uhabits; privacy -> ACTION_VIEW http://loophabits.org/privacy.
5. `settings.about.screen#5` — All About links are launched with startActivitySafely, which falls back to the snackbar "No app was found to support this action".
6. `settings.about.screen#6` — The third card is headed "Developers" and lists these 15 names in this exact order: Álinson S. Xavier (@iSoron), Quentin Hibon (@hiqua), Oleg Ivashchenko (@olegivo), Kristian Tashkov (@KristianTashkov), Jakub Kalinowski (@kalina559), Rechee Jozil (@recheej), Sebastian Gallese (@sgallese), Luboš Luňák (@llunak), Bindu (@vbh), Victor Yu (@vyu1), Christoph Hennemann (@chennemann), Денис (@sciamano), Joseph Tran (@JotraN), Nikhil (@regularcoder), JanetQC.
7. `settings.about.screen#7` — The Developers card ends with a clickable row "View all contributors…" opening ACTION_VIEW https://github.com/iSoron/uhabits/graphs/contributors.
8. `settings.about.screen#8` — The fourth card is headed "Translators" and contains a generated, non-clickable list grouped by language name (language headings use the About.Item.Language style, names use About.Item).

#### settings.about.developer-countdown

- [ ] `settings.about.developer-countdown` — Developer-mode easter egg
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/about/AboutScreen.kt`, `.../about/AboutView.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** none — write Dart test from rules

1. `settings.about.developer-countdown#1` — AboutScreen holds a per-instance counter developerCountdown initialised to 5.
2. `settings.about.developer-countdown#2` — Each tap on the version TextView calls onPressDeveloperCountdown(), which decrements the counter by 1.
3. `settings.about.developer-countdown#3` — When and only when the counter reaches exactly 0 (i.e. on the 5th tap of a single AboutActivity instance), prefs.isDeveloper is set to true and the snackbar "You are now a developer" is shown.
4. `settings.about.developer-countdown#4` — Further taps drive the counter negative and do nothing — no message and no repeated write.
5. `settings.about.developer-countdown#5` — The counter is not persisted; leaving and re-entering the About screen resets it to 5.
6. `settings.about.developer-countdown#6` — There is no in-app way to turn developer mode back off except through the "Enable developer mode" switch in the (now visible) Development category.

#### settings.intro.slides

- [ ] `settings.intro.slides` — First-run intro slides
- **Platform:** ui · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/intro/IntroActivity.kt`, `uhabits-android/src/main/res/values/strings.xml`, `uhabits-android/src/main/AndroidManifest.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Built on the third-party AppIntro2 library (swipe pager, skip/next/done buttons, colour-crossfading background); a Flutter port must reimplement the pager, indicator and Skip/Done chrome by hand.

1. `settings.intro.slides#1` — IntroActivity extends AppIntro2 and calls showStatusBar(false), so the status bar is hidden for the whole intro.
2. `settings.intro.slides#2` — Exactly three slides are added, in this order.
3. `settings.intro.slides#3` — Slide 1: title "Welcome", description "Loop Habit Tracker helps you create and maintain good habits.", image R.drawable.intro_icon_1, background colour #194673.
4. `settings.intro.slides#4` — Slide 2: title "Create some new habits", description "Every day, after performing your habit, put a checkmark on the app.", image R.drawable.intro_icon_2, background colour #ffa726.
5. `settings.intro.slides#5` — Slide 3: title "Track your progress", description "Detailed graphs show you how your habits improved over time.", image R.drawable.intro_icon_4, background colour #9575cd.
6. `settings.intro.slides#6` — Both onDonePressed and onSkipPressed call super and then finish() — skipping and finishing have identical effects and neither writes any preference.
7. `settings.intro.slides#7` — The activity is declared in the manifest with an empty label and theme Theme.AppCompat.Light.NoActionBar.
8. `settings.intro.slides#8` — There is no slide numbered 3 in the resources (intro_title_3 / intro_icon_3 do not exist); the third slide deliberately uses the _4 resources.

#### settings.intro.first-run-trigger

- [ ] `settings.intro.first-run-trigger` — When the intro is shown
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentFactory.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehaviorTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseUserInterfaceTest.kt`

1. `settings.intro.first-run-trigger#1` — The intro is launched only from ListHabitsBehavior.onStartup(), which runs once per ListHabitsActivity.onCreate.
2. `settings.intro.first-run-trigger#2` — onStartup() calls prefs.incrementLaunchCount() unconditionally, then checks prefs.isFirstRun.
3. `settings.intro.first-run-trigger#3` — When isFirstRun is true it runs onFirstRun(): sets prefs.isFirstRun = false, calls prefs.updateLastHint(-1, getToday()), then calls screen.showIntroScreen().
4. `settings.intro.first-run-trigger#4` — showIntroScreen() starts IntroActivity via IntentFactory.startIntroActivity(context) with no extras.
5. `settings.intro.first-run-trigger#5` — Because isFirstRun is cleared before the intro is shown, killing the app during the intro means it is never shown again.
6. `settings.intro.first-run-trigger#6` — Instrumentation tests bypass the intro by setting prefs.isFirstRun = false in BaseUserInterfaceTest setup.

## Domain: Home screen widgets

#### widgets.registration

- [ ] `widgets.registration` — Six home-screen widget types are registered with the launcher
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/src/main/res/xml/widget_checkmark_info.xml`, `.../widget_frequency_info.xml`, `.../widget_history_info.xml`, `.../widget_score_info.xml`, `.../widget_streak_info.xml`, `.../widget_target_info.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/CheckmarkWidgetTest.kt`, `.../FrequencyWidgetTest.kt`, `.../HistoryWidgetTest.kt`, `.../ScoreWidgetTest.kt`, `.../StreakWidgetTest.kt`, `.../TargetWidgetTest.kt`
- **Notes:** Flutter has no cross-platform home-screen widget API. Requires native AppWidgetProvider on Android and WidgetKit on iOS; each of the *_info.xml sizing/preview declarations has to be re-authored per platform. The `testIsInstalled` test in each *WidgetTest.kt asserts the provider is present in AppWidgetManager.installedProviders.

1. `widgets.registration#1` — Exactly six app-widget providers exist and are user-installable: CheckmarkWidgetProvider (launcher label 'Checkmark'), HistoryWidgetProvider ('History'), ScoreWidgetProvider ('Score'), StreakWidgetProvider ('Streaks'), FrequencyWidgetProvider ('Frequency'), TargetWidgetProvider ('Target').
2. `widgets.registration#2` — The Checkmark widget declares minWidth=50dp and minHeight=50dp and uses layout widget_wrapper as its initial layout; it declares no minResizeWidth/minResizeHeight.
3. `widgets.registration#3` — The Frequency, History, Score, Streak and Target widgets each declare minWidth=100dp, minHeight=100dp, minResizeWidth=100dp, minResizeHeight=100dp, and use layout widget_graph as their initial layout.
4. `widgets.registration#4` — All six widgets declare resizeMode='vertical|horizontal', updatePeriodMillis=3600000 (1 hour), and widgetCategory='home_screen'.
5. `widgets.registration#5` — Each widget declares a static preview image: widget_preview_checkmark, widget_preview_frequency, widget_preview_history, widget_preview_score, widget_preview_streaks, widget_preview_target.
6. `widgets.registration#6` — The configure activity is HabitPickerDialog for Checkmark, Frequency, History and Score; BooleanHabitPickerDialog for Streaks; NumericalHabitPickerDialog for Target.
7. `widgets.registration#7` — StackWidgetService is declared as a non-exported Service requiring permission android.permission.BIND_REMOTEVIEWS.
8. `widgets.registration#8` — Each provider receiver is exported and registers only the intent filter android.appwidget.action.APPWIDGET_UPDATE.

#### widgets.provider-lifecycle

- [ ] `widgets.provider-lifecycle` — Widget provider update / delete / resize lifecycle
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/BaseWidgetProvider.kt`, `uhabits-android/src/main/res/layout/widget_error.xml`, `uhabits-android/src/main/res/drawable/widget_background.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** AppWidgetProvider callbacks (onUpdate/onDeleted/onAppWidgetOptionsChanged) have no Flutter equivalent.

1. `widgets.provider-lifecycle#1` — BaseWidgetProvider.onUpdate resolves dependencies (habitList, preferences, widgetPreferences) from the application component, sets the context theme to R.style.WidgetTheme, then starts a new background Thread that calls Looper.prepare() and updates each widget id in the received array sequentially.
2. `widgets.provider-lifecycle#2` — Updating one widget id: resolve the widget via getWidgetFromId, read AppWidgetManager.getAppWidgetOptions(widgetId), call widget.setDimensions(getDimensionsFromOptions(...)), then push the RemoteViews.
3. `widgets.provider-lifecycle#3` — BaseWidgetProvider.updateAppWidget builds landscapeRemoteViews and portraitRemoteViews separately and combines them with RemoteViews(landscape, portrait) before calling manager.updateAppWidget(widget.id, views); the landscape views are built FIRST.
4. `widgets.provider-lifecycle#4` — onAppWidgetOptionsChanged (fired when the user resizes the widget) does the same work but on the calling thread, using the options Bundle supplied by the callback rather than querying the manager.
5. `widgets.provider-lifecycle#5` — Any RuntimeException thrown while building a widget is caught, the stack trace printed, and an error widget (layout widget_error) is pushed instead: a full-bleed LinearLayout with drawable widget_background (solid #3f000000, 4dp corners), centred white TextView with the literal default text 'Error drawing widget'.
6. `widgets.provider-lifecycle#6` — If the caught exception is a HabitNotFoundException, the error widget label text is replaced with R.string.habit_not_found = 'Habit deleted / not found'.
7. `widgets.provider-lifecycle#7` — onDeleted throws RuntimeException('context is null') if context is null and RuntimeException('ids is null') if ids is null.
8. `widgets.provider-lifecycle#8` — onDeleted loops over every deleted widget id and calls widget.delete(), which removes that widget's habit-id preference entry; a HabitNotFoundException while resolving one id is caught and skipped so remaining ids are still processed.
9. `widgets.provider-lifecycle#9` — getHabitsFromWidgetId maps each stored habit id through habitList.getById; if any id no longer resolves, HabitNotFoundException is thrown for the whole widget (producing the 'Habit deleted / not found' error widget).

#### widgets.dimensions

- [ ] `widgets.dimensions` — Widget dimension resolution (portrait vs landscape)
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/WidgetDimensions.kt`, `.../BaseWidgetProvider.kt`, `.../StackWidgetService.kt`, `.../BaseWidget.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseViewTest.kt`
- **Notes:** BaseViewTest.convertToView(widget, w, h) sets WidgetDimensions(w, h, w, h) and applies portraitRemoteViews — this is how all the widget render tests size their subject.

1. `widgets.dimensions#1` — WidgetDimensions is a 4-field value object: portraitWidth, portraitHeight, landscapeWidth, landscapeHeight (all in pixels).
2. `widgets.dimensions#2` — getDimensionsFromOptions reads the four AppWidgetManager option ints OPTION_APPWIDGET_MAX_WIDTH, OPTION_APPWIDGET_MAX_HEIGHT, OPTION_APPWIDGET_MIN_WIDTH, OPTION_APPWIDGET_MIN_HEIGHT (which are in dp), converts each to pixels via dpToPixels, and returns WidgetDimensions(portraitWidth = minWidth, portraitHeight = maxHeight, landscapeWidth = maxWidth, landscapeHeight = minHeight).
3. `widgets.dimensions#3` — In portrait the widget is therefore rendered at (minWidth x maxHeight); in landscape at (maxWidth x minHeight).
4. `widgets.dimensions#4` — Until setDimensions is called, every BaseWidget uses WidgetDimensions(defaultWidth, defaultHeight, defaultWidth, defaultHeight) — i.e. identical portrait and landscape sizes.
5. `widgets.dimensions#5` — Default sizes in pixels are: CheckmarkWidget 125x125, FrequencyWidget 200x200, StreakWidget 200x200, TargetWidget 200x200, EmptyWidget 200x200, HistoryWidget 250x250, ScoreWidget 300x300, StackWidget 0x0.
6. `widgets.dimensions#6` — StackRemoteViewsFactory duplicates the same getDimensionsFromOptions logic verbatim so the child widgets inside a stack are sized from the stack widget's own options bundle.

#### widgets.remoteviews-rendering

- [ ] `widgets.remoteviews-rendering` — Widgets are rendered to a bitmap and shipped as RemoteViews
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/BaseWidget.kt`, `uhabits-android/src/main/res/layout/widget_wrapper.xml`, `uhabits-android/src/main/res/drawable/widget_button_background.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/CheckmarkWidgetTest.kt`
- **Notes:** Rendering an Android View to a Bitmap and shipping it inside RemoteViews has no Flutter analogue. On iOS/WidgetKit the equivalent is a SwiftUI view; on Android a Flutter port would need home_widget + a native bitmap or Glance implementation.

1. `widgets.remoteviews-rendering#1` — BaseWidget.getRemoteViews(width, height) calls buildView() (must be non-null; a null view raises NPE), measures it, calls refreshData(view), and if the view requested layout during refreshData it measures a second time, before rasterising.
2. `widgets.remoteviews-rendering#2` — measureView inflates R.layout.widget_wrapper off-screen, measures it with MeasureSpec.EXACTLY at the requested width/height, lays it out, then reads the measured width/height of its R.id.imageView child and measures/lays out the real widget view at exactly those dimensions.
3. `widgets.remoteviews-rendering#3` — The measured view is drawn into a Bitmap of size max(1, view.measuredWidth) x max(1, view.measuredHeight) with Bitmap.Config.ARGB_8888, and set on R.id.imageView via RemoteViews.setImageViewBitmap.
4. `widgets.remoteviews-rendering#4` — Padding is applied to R.id.buttonOverlay so the tap target is centred on the bitmap: left=right=((entireWidth - imageWidth) / 2).toInt() and top=bottom=((entireHeight - imageHeight) / 2).toInt().
5. `widgets.remoteviews-rendering#5` — The click PendingIntent is attached to R.id.button only when getOnClickPendingIntent returns non-null; EmptyWidget and StackWidget return null and therefore have no click target.
6. `widgets.remoteviews-rendering#6` — widget_wrapper is a RelativeLayout (match_parent, gravity=center, padding 0) containing an ImageView id=imageView (match_parent, adjustViewBounds=true) and a FrameLayout id=buttonOverlay (match_parent) holding a Button id=button (match_parent) whose background is widget_button_background.
7. `widgets.remoteviews-rendering#7` — widget_button_background is a layer-list inset by top=1dp, left=1dp, bottom=3dp, right=3dp containing a ripple of colour #60ffffff with a rounded-rectangle mask of radius 18dp — so the touch ripple exactly matches the 18dp rounded card and is offset to leave room for the drop shadow.

#### widgets.card-chrome

- [ ] `widgets.card-chrome` — Shared widget card chrome: rounded background, opacity and shadow
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/views/HabitWidgetView.kt`, `.../BaseWidget.kt`, `uhabits-android/src/main/res/values/styles.xml`, `.../values/attrs.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/CheckmarkWidgetTest.kt`, `.../HistoryWidgetTest.kt`

1. `widgets.card-chrome#1` — Every widget view extends HabitWidgetView, a FrameLayout that inflates its inner layout and looks up a child with id=frame to use as the card background holder.
2. `widgets.card-chrome#2` — The card background is a RoundRectShape with all 8 corner radii equal to 18dp, wrapped in an InsetDrawable with left=top=max(shadowRadius - shadowOffset, 0) = 1dp and right=bottom=shadowRadius + shadowOffset = 3dp, where shadowRadius = 2dp and shadowOffset = 1dp (converted to px).
3. `widgets.card-chrome#3` — The card paint colour is ?attr/cardBgColor (grey_850 under WidgetTheme) and its alpha is set to the current backgroundAlpha; the shadow layer uses Color.argb(shadowAlpha, 0, 0, 0) at radius 2dp offset (1dp, 1dp).
4. `widgets.card-chrome#4` — On construction shadowAlpha = (255 * ?attr/widgetShadowAlpha).toInt(); WidgetTheme sets widgetShadowAlpha=0, so widgets start with no shadow (the app themes use 0.25 => 63).
5. `widgets.card-chrome#5` — BaseWidget.preferedBackgroundAlpha returns 255 whenever the widget is rendered inside a StackWidget (stacked == true), and otherwise returns Preferences.widgetOpacity.
6. `widgets.card-chrome#6` — Frequency, Score, Streak, Target and History widgets call setBackgroundAlpha(preferedBackgroundAlpha) and, only when preferedBackgroundAlpha >= 255, additionally call setShadowAlpha(0x4f) (=79) — so the drop shadow appears only on fully opaque widgets.
7. `widgets.card-chrome#7` — CheckmarkWidgetView.refresh() unconditionally calls setShadowAlpha(0x4f) regardless of opacity.
8. `widgets.card-chrome#8` — setShadowAlpha and setBackgroundAlpha both rebuild the whole background drawable and reassign it to the frame view.

#### widgets.theme

- [ ] `widgets.theme` — Widgets always render with the dedicated WidgetTheme palette
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Themes.kt`, `uhabits-android/src/main/res/values/styles.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/widgets/BaseWidgetProvider.kt`, `uhabits-android/src/main/java/org/isoron/platform/gui/AndroidImage.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/CheckmarkWidgetTest.kt`

1. `widgets.theme#1` — Providers call context.setTheme(R.style.WidgetTheme) before building any widget; WidgetTheme derives from AppBaseThemeDark and overrides cardBgColor=grey_850, contrast0=white, contrast20=white_a0, contrast60=white_aa, contrast80=grey_800, contrast100=white, palette=transparentWidgetPalette, widgetShadowAlpha=0.
2. `widgets.theme#2` — Habit colours inside widgets come from the core class WidgetTheme (a LightTheme subclass) whose color(paletteIndex) returns, for indices 0..19: 0xD32F2F, 0xE64A19, 0xF57C00, 0xFF8F00, 0xF9A825, 0xAFB42B, 0x7CB342, 0x388E3C, 0x00897B, 0x00ACC1, 0x039BE5, 0x1976D2, 0x6275f0, 0x5E35B1, 0x8E24AA, 0xD81B60, 0x5D4037, 0x757575, 0x757575, 0x9E9E9E, and 0x000000 for any other index.
3. `widgets.theme#3` — WidgetTheme sets cardBackgroundColor = TRANSPARENT, highContrastTextColor = WHITE, mediumContrastTextColor = WHITE at 50% alpha, lowContrastTextColor = WHITE at 10% alpha.
4. `widgets.theme#4` — Color.toInt() converts a core Color into an Android ARGB int as argb(round(255*alpha), round(255*red), round(255*green), round(255*blue)).
5. `widgets.theme#5` — Widgets ignore the user's light/dark app theme entirely — they are always drawn with WidgetTheme.

#### widgets.checkmark

- [ ] `widgets.checkmark` — Checkmark widget
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/CheckmarkWidget.kt`, `.../CheckmarkWidgetProvider.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/PendingIntentFactory.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/CheckmarkWidgetTest.kt`, `.../acceptance/WidgetTest.kt`
- **Notes:** CheckmarkWidgetTest asserts a real click on R.id.button toggles the entry YES_MANUAL -> SKIP -> NO with isSkipEnabled=true, and golden-renders uhabits-android/src/androidTest/assets/views/widgets/CheckmarkWidget/render.png at 150x200.

1. `widgets.checkmark#1` — CheckmarkWidget default size is 125x125 px and its view is a CheckmarkWidgetView.
2. `widgets.checkmark#2` — refreshData sets, in order: setBackgroundAlpha(preferedBackgroundAlpha); activeColor = WidgetTheme().color(habit.color) as an Android int; name = habit.name; entryValue = habit.computedEntries.get(today).value; entryState; percentage = habit.scores[today].value.toFloat(); then calls refresh().
3. `widgets.checkmark#3` — For a boolean habit, entryState = habit.computedEntries.get(today).value (one of UNKNOWN=-1, NO=0, YES_AUTO=1, YES_MANUAL=2, SKIP=3).
4. `widgets.checkmark#4` — For a numerical habit, isNumerical is set true and entryState = YES_MANUAL (2) when habit.isCompletedToday() else NO (0); isCompletedToday for AT_LEAST habits is value/1000.0 >= targetValue, and is always false for AT_MOST habits.
5. `widgets.checkmark#5` — 'today' is org.isoron.platform.time.getToday(), i.e. the app-wide today which already accounts for the midnight-delay offset.
6. `widgets.checkmark#6` — Tapping a boolean Checkmark widget fires a broadcast PendingIntent (requestCode 2, FLAG_IMMUTABLE|FLAG_UPDATE_CURRENT) to WidgetReceiver with action ACTION_TOGGLE_REPETITION and data = habit.uriString, and NO 'timestamp' extra (so the receiver defaults to today).
7. `widgets.checkmark#7` — Tapping a numerical Checkmark widget instead launches ListHabitsActivity with action ACTION_EDIT and extras habit=<habit id> and timestamp=<today.unixTime>, request code ((habit.id % Integer.MAX_VALUE) + 1) — this opens the numeric value picker for today.
8. `widgets.checkmark#8` — ListHabitsActivity.parseIntents, on receiving ACTION_EDIT with both 'habit' and 'timestamp' extras, resolves the habit and calls listHabitsBehavior.onEdit(habit, date, 0f, 0f); the intent is then cleared so it fires only once.
9. `widgets.checkmark#9` — Repeatedly tapping a boolean Checkmark widget cycles the value through Entry.nextToggleValue; with skip enabled and starting at YES_MANUAL the observed sequence is YES_MANUAL -> SKIP -> NO.

#### widgets.checkmark-view

- [ ] `widgets.checkmark-view` — Checkmark widget view rendering (ring, glyph, label)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/views/CheckmarkWidgetView.kt`, `uhabits-android/src/main/res/layout/widget_checkmark.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/RingView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/NumberButtonView.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/views/CheckmarkWidgetViewTest.kt`
- **Notes:** CheckmarkWidgetViewTest golden-renders at 300x300 dp (large_size.png); the 'checked' golden is @Ignore'd as non-deterministic.

1. `widgets.checkmark-view#1` — CheckmarkWidgetView inflates R.layout.widget_checkmark: a vertical, centre-gravity LinearLayout id=frame containing a RingView id=scoreRing (height 0dp, weight 0.9, marginTop 8dp, marginLeft/Right 4dp, thickness attr 2, textSize attr 16, enableFontAwesome=true) and a TextView id=label (weight 0.1, textSize 12sp, white, gravity center, maxLines 2, ellipsize end, marginLeft/Right 6dp, marginTop/Bottom 4dp, fontFamily sans-serif-condensed, breakStrategy balanced).
2. `widgets.checkmark-view#2` — refresh() returns immediately without drawing if backgroundPaint or frame is null.
3. `widgets.checkmark-view#3` — When entryState is YES_MANUAL (2), SKIP (3) or YES_AUTO (1): the card background colour becomes activeColor (the habit colour), the foreground colour is ?attr/contrast0 (white), and the frame background is re-applied.
4. `widgets.checkmark-view#4` — When entryState is NO (0), UNKNOWN (-1) or anything else: the card background colour is ?attr/cardBgColor and the foreground colour is ?attr/contrast60; in this branch the frame background drawable is NOT re-applied.
5. `widgets.checkmark-view#5` — refresh() sets ring.percentage = percentage, ring.color = foreground colour, ring.backgroundColor = background colour, ring text, ring stroked-text flag, label.text = habit name and label text colour = foreground colour.
6. `widgets.checkmark-view#6` — Glyph for a boolean habit: YES_MANUAL and YES_AUTO -> R.string.fa_check; SKIP -> R.string.fa_skipped; NO -> R.string.fa_times; UNKNOWN -> R.string.fa_question when Preferences.areQuestionMarksEnabled is true, otherwise R.string.fa_times; any other value -> R.string.fa_times.
7. `widgets.checkmark-view#7` — Text for a numerical habit is (max(0, entryValue) / 1000.0).toShortString(), i.e. negatives clamp to 0 and the raw milli-units are divided by 1000; toShortString formats >=1e9 as '%.1fG', >=1e8 as '%.0fM', >=1e7/>=1e6 as '%.1fM', >=1e5 as '%.0fk', >=1e4/>=1e3 as '%.1fk', >=1e2 as '#', >=1e1 as '#.#', else '#.##'.
8. `widgets.checkmark-view#8` — Stroked (outlined) ring text is enabled only for a boolean habit whose entryState is YES_AUTO; it is always disabled for numerical habits.
9. `widgets.checkmark-view#9` — onMeasure: if height >= width then height = min(height, round(width * 1.5)); otherwise width = min(width, height). So the widget is at most 1.5x taller than wide, and never wider than it is tall.
10. `widgets.checkmark-view#10` — onMeasure computes textSize = min(0.175f * width, R.dimen.smallTextSize=14sp in px), applies it to the label in px units, sets ring text size to textSize * 0.9f for numerical habits and textSize otherwise, and sets ring thickness to 0.03f * width.
11. `widgets.checkmark-view#11` — In layout-editor preview mode the view seeds percentage=0.75f, name='Wake up early', activeColor=getAndroidTestColor(6), entryValue=YES_MANUAL.
12. `widgets.checkmark-view#12` — RingView draws an arc starting at -90 degrees spanning 360 * round(percentage / precision) * precision degrees (precision default 0.01), fills the remainder with contrast100 at 15% alpha, punches out the inner disc (using PorterDuff CLEAR because transparency is enabled for widgets) and draws the glyph centred at (centerX, centerY + 0.4 * em) in the FontAwesome typeface; stroked text uses strokeWidth = textSize / 15f.
13. `widgets.checkmark-view#13` — RingView.onMeasure forces a square: diameter = max(1, min(height, width)) and setMeasuredDimension(diameter, diameter).

#### widgets.frequency

- [ ] `widgets.frequency` — Frequency widget
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/FrequencyWidget.kt`, `.../FrequencyWidgetProvider.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/FrequencyChart.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/FrequencyWidgetTest.kt`
- **Notes:** FrequencyWidgetTest builds the widget with DayOfWeek.SUNDAY at 400x400 and golden-renders uhabits-android/src/androidTest/assets/views/widgets/FrequencyWidget/render.png.

1. `widgets.frequency#1` — FrequencyWidget default size is 200x200 px and its view is a GraphWidgetView wrapping a FrequencyChart.
2. `widgets.frequency#2` — The widget title is habit.name.
3. `widgets.frequency#3` — refreshData sets the chart's firstWeekday from Preferences.firstWeekday (resolved by FrequencyWidgetProvider at construction time, not read again), colour = WidgetTheme().color(habit.color), isNumerical = habit.isNumerical, and frequency = habit.originalEntries.computeWeekdayFrequency(habit.isNumerical).
4. `widgets.frequency#4` — computeWeekdayFrequency buckets every KNOWN entry by its month start; within each month it accumulates into a 7-slot array indexed by (dayOfWeek.daysSinceSunday + 1) % 7; for numerical habits it adds the raw entry value, for boolean habits it adds 1 only when the entry value equals YES_MANUAL (2).
5. `widgets.frequency#5` — The widget reads originalEntries (user-entered data), not computedEntries — so auto-satisfied YES_AUTO days do not count.
6. `widgets.frequency#6` — Tapping the Frequency widget opens ShowHabitActivity for that habit via a TaskStackBuilder PendingIntent with the parent activity stack (FLAG_IMMUTABLE|FLAG_UPDATE_CURRENT, request code 0).

#### widgets.history

- [ ] `widgets.history` — History widget
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/HistoryWidget.kt`, `.../HistoryWidgetProvider.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/HistoryCard.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/HistoryWidgetTest.kt`
- **Notes:** Golden render at 400x400: uhabits-android/src/androidTest/assets/views/widgets/HistoryWidget/render.png.

1. `widgets.history#1` — HistoryWidget default size is 250x250 px; its view is a GraphWidgetView wrapping an AndroidDataView whose inner view is a core HistoryChart.
2. `widgets.history#2` — The HistoryChart is constructed with today = getToday(), paletteColor = habit.color, theme = WidgetTheme(), dateFormatter = JavaLocalDateFormatter(Locale.getDefault()), firstWeekday = Preferences.firstWeekday, series = empty list, defaultSquare = HistoryChart.Square.OFF, notesIndicators = empty list, and padding = 2.5.
3. `widgets.history#3` — The widget title is habit.name.
4. `widgets.history#4` — refreshData recomputes state via HistoryCardPresenter.buildState(habit, firstWeekday = prefs.firstWeekday, theme = WidgetTheme()) and copies model.series, model.defaultSquare and model.notesIndicators onto the chart.
5. `widgets.history#5` — Tapping the History widget opens ShowHabitActivity for that habit via the parent-stack PendingIntent.
6. `widgets.history#6` — The rendered chart is a static bitmap: the scroll/tap gestures that AndroidDataView supports in the app are unavailable inside the widget.

#### widgets.score

- [ ] `widgets.score` — Score widget
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/ScoreWidget.kt`, `.../ScoreWidgetProvider.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/ScoreCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/ScoreChart.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/ScoreWidgetTest.kt`
- **Notes:** Golden render at 400x400: uhabits-android/src/androidTest/assets/views/widgets/ScoreWidget/render.png.

1. `widgets.score#1` — ScoreWidget default size is 300x300 px — the largest default of any widget; its view is a GraphWidgetView wrapping a ScoreChart.
2. `widgets.score#2` — The widget title is habit.name.
3. `widgets.score#3` — refreshData builds state via ScoreCardPresenter.buildState(habit, firstWeekday = prefs.firstWeekdayInt, spinnerPosition = prefs.scoreCardSpinnerPosition, theme = WidgetTheme()) — so the widget honours whatever bucket the user last selected on the habit detail screen.
4. `widgets.score#4` — BUCKET_SIZES = [1, 7, 31, 92, 365] indexed by spinnerPosition; scoreCardSpinnerPosition is clamped to 0..4 and defaults to 1 (weekly buckets).
5. `widgets.score#5` — refreshData enables transparency on the chart (setIsTransparencyEnabled(true)), sets bucketSize from the view model, sets colour = WidgetTheme().color(habit.color), and sets the score list.
6. `widgets.score#6` — Scores are grouped from the oldest known computed entry date up to today, averaged per bucket, sorted by date and then reversed (newest first).
7. `widgets.score#7` — Tapping the Score widget opens ShowHabitActivity for that habit.

#### widgets.streak

- [ ] `widgets.streak` — Streak widget
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/StreakWidget.kt`, `.../StreakWidgetProvider.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/StreakChart.kt`, `uhabits-android/src/main/res/xml/widget_streak_info.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/StreakWidgetTest.kt`
- **Notes:** Golden render at 400x400: uhabits-android/src/androidTest/assets/views/widgets/StreakWidget/render.png.

1. `widgets.streak#1` — StreakWidget default size is 200x200 px; its view is a GraphWidgetView wrapping a StreakChart, and the GraphWidgetView is given LayoutParams(MATCH_PARENT, MATCH_PARENT).
2. `widgets.streak#2` — The widget title is habit.name.
3. `widgets.streak#3` — refreshData sets colour = WidgetTheme().color(habit.color) and streaks = habit.streaks.getBest(chart.maxStreakCount).
4. `widgets.streak#4` — StreakChart.maxStreakCount = floor(measuredHeight / baseSize) — i.e. the number of streak bars shown adapts to the widget's current height, and is read AFTER the view has been measured.
5. `widgets.streak#5` — The Streak widget's configure activity is BooleanHabitPickerDialog, so numerical habits can never be chosen for it.
6. `widgets.streak#6` — Tapping the Streak widget opens ShowHabitActivity for that habit.

#### widgets.target

- [ ] `widgets.target` — Target widget
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/TargetWidget.kt`, `.../TargetWidgetProvider.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/TargetCard.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/TargetCardView.kt`, `uhabits-android/src/main/res/xml/widget_target_info.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/TargetWidgetTest.kt`
- **Notes:** TargetWidgetTest uses a long numerical habit with PaletteColor(11) and Frequency.WEEKLY, relaxes similarityCutoff to 0.00025, and golden-renders uhabits-android/src/androidTest/assets/views/widgets/TargetWidget/render.png at 400x400.

1. `widgets.target#1` — TargetWidget default size is 200x200 px; its view is a GraphWidgetView wrapping a TargetChart with LayoutParams(MATCH_PARENT, MATCH_PARENT).
2. `widgets.target#2` — The widget title is habit.name.
3. `widgets.target#3` — refreshData runs inside runBlocking and builds state via TargetCardPresenter.buildState(habit, firstWeekday = prefs.firstWeekdayInt, theme = WidgetTheme()), then sets chart colour, targets, labels and values.
4. `widgets.target#4` — Interval labels come from TargetCardView.intervalToLabel: 1 -> R.string.today, 7 -> R.string.week, 30 -> R.string.month, 91 -> R.string.quarter, anything else -> R.string.year.
5. `widgets.target#5` — The interval list is dynamic: interval 1 (today) is included only when habit.frequency.denominator <= 1; interval 7 (week) only when denominator <= 7; intervals 30, 91 and 365 are always included. So a weekly habit shows 4 bars and a monthly habit shows 3.
6. `widgets.target#6` — Values are the grouped sums divided by 1000 (milli-units to units) for day/week/month/quarter/year windows.
7. `widgets.target#7` — Targets are reduced by dailyTarget * skippedDays for each window and floored at 0.0, where dailyTarget = habit.targetValue / habit.frequency.denominator.
8. `widgets.target#8` — The Target widget's configure activity is NumericalHabitPickerDialog, so boolean habits can never be chosen for it.
9. `widgets.target#9` — Tapping the Target widget opens ShowHabitActivity for that habit.

#### widgets.graph-view

- [ ] `widgets.graph-view` — Graph widget shell (title + chart)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/views/GraphWidgetView.kt`, `uhabits-android/src/main/res/layout/widget_graph.xml`, `uhabits-android/src/main/res/values/dimens.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/ScoreWidgetTest.kt`

1. `widgets.graph-view#1` — GraphWidgetView inflates R.layout.widget_graph: a FrameLayout id=frame containing a vertical LinearLayout id=innerFrame (paddingTop 4dp, paddingLeft 8dp, paddingRight 8dp, paddingBottom 8dp) whose first child is a TextView id=title (match_parent width, wrap_content height, gravity center, textSize R.dimen.smallTextSize = 14sp, maxLines 2, textColor white).
2. `widgets.graph-view#2` — The chart view passed into GraphWidgetView's constructor is added to innerFrame below the title with LayoutParams(MATCH_PARENT, MATCH_PARENT), and the title is made VISIBLE.
3. `widgets.graph-view#3` — The title is always set to the habit name and is truncated to at most 2 lines.
4. `widgets.graph-view#4` — Frequency, Score, Streak, Target and History widgets all share this shell; only Checkmark uses a different layout.

#### widgets.empty

- [ ] `widgets.empty` — Empty widget (stack loading placeholder)
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/EmptyWidget.kt`, `.../views/EmptyWidgetView.kt`, `.../StackWidgetService.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `widgets.empty#1` — EmptyWidget has default size 200x200 px, returns null from getOnClickPendingIntent (so it is never clickable), and does nothing in refreshData.
2. `widgets.empty#2` — Its view is an EmptyWidgetView, which inflates the same R.layout.widget_graph as the graph widgets, makes the title TextView visible, and leaves the title text empty (no chart is added).
3. `widgets.empty#3` — EmptyWidget is used exclusively as StackRemoteViewsFactory.getLoadingView() — the placeholder shown while a stack page is being built; it is sized from the stack widget's current AppWidgetOptions.
4. `widgets.empty#4` — EmptyWidget is constructed with stacked=false by default, so the loading placeholder honours the user's widgetOpacity preference rather than being forced opaque.

#### widgets.stack

- [ ] `widgets.stack` — Stack widget (multi-habit swipeable widget)
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/StackWidget.kt`, `.../StackWidgetType.kt`, `uhabits-android/src/main/res/layout/checkmark_stackview_widget.xml`, `.../frequency_stackview_widget.xml`, `.../score_stackview_widget.xml`, `.../history_stackview_widget.xml`, `.../streak_stackview_widget.xml`, `.../target_stackview_widget.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/utils/StringUtils.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Creating new stack widgets was removed from the picker UI (commit 1df9cc76 'Widgets: Remove option to create StackWidgets'), but the rendering path is still live for widgets whose stored preference holds more than one habit id — legacy installs must keep working after a port.

1. `widgets.stack#1` — A provider returns a single-habit widget only when getHabitsFromWidgetId(id).size == 1; for 0 habits or 2+ habits it returns a StackWidget of the matching StackWidgetType.
2. `widgets.stack#2` — StackWidgetType is an enum with explicit values: CHECKMARK=0, FREQUENCY=1, SCORE=2, HISTORY=3, STREAKS=4, TARGET=5; getWidgetTypeFromValue returns null for any other int.
3. `widgets.stack#3` — StackWidget overrides getRemoteViews and ignores the requested width/height entirely; it inflates the per-type stack layout (checkmark_stackview_widget, frequency_stackview_widget, score_stackview_widget, history_stackview_widget, streak_stackview_widget, target_stackview_widget).
4. `widgets.stack#4` — Each stack layout is a FrameLayout containing a StackView with android:loopViews="true" (so swiping wraps around) plus a full-bleed empty-state TextView (white, bold, 16sp, centred).
5. `widgets.stack#5` — Empty-state strings are 'Checkmark Stack Widget', 'Frequency Stack Widget', 'Score Stack Widget', 'History Stack Widget', 'Streaks Stack Widget'; the target layout has a bug and reuses R.string.streaks_stack_widget ('Streaks Stack Widget') instead of a target-specific string.
6. `widgets.stack#6` — StackWidget wires the StackView to StackWidgetService via setRemoteAdapter with an Intent carrying EXTRA_APPWIDGET_ID = widget id, WIDGET_TYPE = type.value, and HABIT_IDS = the habit ids joined with ',' (StringUtils.joinLongs); the Intent's data is set to its own URI_INTENT_SCHEME string so Android treats each configuration as a distinct adapter.
7. `widgets.stack#7` — StackWidget calls AppWidgetManager.notifyAppWidgetViewDataChanged for the StackView every time getRemoteViews runs, and calls setEmptyView to point the StackView at its empty TextView.
8. `widgets.stack#8` — StackWidget.getOnClickPendingIntent returns null, buildView returns null, refreshData is a no-op, and defaultWidth/defaultHeight are both 0.
9. `widgets.stack#9` — StackWidget is constructed with stacked = true, so all of its child widgets render at background alpha 255 regardless of the user's widgetOpacity preference.
10. `widgets.stack#10` — One pending-intent template is set on the whole StackView: for CHECKMARK it is showNumberPickerTemplate() if ANY habit in the widget is numerical, else toggleCheckmarkTemplate(); for FREQUENCY/SCORE/HISTORY/STREAKS/TARGET it is showHabitTemplate().
11. `widgets.stack#11` — Template PendingIntents are created with flags = FLAG_MUTABLE on Android S (API 31) and above, and 0 on older releases.
12. `widgets.stack#12` — StringUtils.joinLongs joins with ','; splitLongs parses comma-separated longs and returns an EMPTY LongArray if any token fails to parse — so a StackWidget built from an empty habit list yields count 0 and shows the empty view.

#### widgets.stack-service

- [ ] `widgets.stack-service` — StackWidgetService / RemoteViewsFactory item construction
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/StackWidgetService.kt`, `.../StackWidgetType.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/PendingIntentFactory.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `widgets.stack-service#1` — StackWidgetService.onGetViewFactory returns a StackRemoteViewsFactory built from the application context and the adapter Intent; the constants are WIDGET_TYPE = "WIDGET_TYPE" and HABIT_IDS = "HABIT_IDS".
2. `widgets.stack-service#2` — Factory construction throws RuntimeException("invalid widget type") when the WIDGET_TYPE extra is missing or negative (default -1), RuntimeException("habitIdsStr is null") when HABIT_IDS is absent, and RuntimeException("unknown widget type value: <v>") when the value does not map to a StackWidgetType.
3. `widgets.stack-service#3` — getCount() returns habitIds.size; getViewTypeCount() returns 1; hasStableIds() returns true; getItemId(position) returns habitIds[position] (the habit id); onCreate, onDestroy and onDataSetChanged are all no-ops.
4. `widgets.stack-service#4` — getViewAt returns null when position < 0 or position >= habitIds.size.
5. `widgets.stack-service#5` — getViewAt prepares a Looper on the current thread if none exists, resolves every habit id (throwing HabitNotFoundException if any is missing), then constructs a child widget of the matching type with stacked=true: CHECKMARK -> CheckmarkWidget, FREQUENCY -> FrequencyWidget(with prefs.firstWeekday), SCORE -> ScoreWidget, HISTORY -> HistoryWidget, STREAKS -> StreakWidget, TARGET -> TargetWidget.
6. `widgets.stack-service#6` — The child widget is sized from the parent stack widget's AppWidgetOptions, both its landscape and portrait RemoteViews are built, the per-item fill-in Intent is attached to R.id.button on BOTH, and the combined RemoteViews(landscape, portrait) is returned.
7. `widgets.stack-service#7` — The per-item fill-in intent for CHECKMARK is showNumberPickerFillIn(habit, today) if ANY habit in the stack is numerical, else toggleCheckmarkFillIn(habit, today); for all other types it is showHabitFillIn(habit).
8. `widgets.stack-service#8` — showHabitFillIn carries only data = habit.uriString; toggleCheckmarkFillIn carries data = habit.uriString plus extra timestamp = date.unixTime; showNumberPickerFillIn carries extras habit = habit.id and timestamp = date.unixTime (no data URI).
9. `widgets.stack-service#9` — getLoadingView returns an EmptyWidget sized from the parent widget's options, as combined landscape/portrait RemoteViews.
10. `widgets.stack-service#10` — The factory constructs its own PendingIntentFactory(context, IntentFactory()) rather than using the DI-provided one.

#### widgets.config-picker

- [ ] `widgets.config-picker` — Widget configuration flow: habit picker dialog
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/activities/HabitPickerDialog.kt`, `uhabits-android/src/main/res/layout/widget_configure_activity.xml`, `.../layout/widget_empty_activity.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/AndroidThemeSwitcher.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/WidgetTest.kt`
- **Notes:** The @Ignore'd acceptance test WidgetTest.shouldCreateAndToggleCheckmarkWidget still clicks a 'Save' button, which no longer exists — it is stale.

1. `widgets.config-picker#1` — HabitPickerDialog is launched by the launcher as the widget's APPWIDGET_CONFIGURE activity and reads the widget id from intent.extras.getInt(EXTRA_APPWIDGET_ID, INVALID_APPWIDGET_ID); if the intent has no extras at all, widgetId falls back to 0.
2. `widgets.config-picker#2` — The dialog theme is applied via AndroidThemeSwitcher.applyDialog(): in night mode it applies R.style.BaseDialogDark and paints the window decor grey_900, otherwise it applies R.style.BaseDialog.
3. `widgets.config-picker#3` — The candidate habit list is built by iterating habitList in its natural order and skipping (a) every archived habit, (b) numerical habits when shouldHideNumerical() is true, (c) boolean habits when shouldHideBoolean() is true.
4. `widgets.config-picker#4` — BooleanHabitPickerDialog sets shouldHideNumerical() = true and its empty message is R.string.no_boolean_habits = 'No yes-or-no habits found'.
5. `widgets.config-picker#5` — NumericalHabitPickerDialog sets shouldHideBoolean() = true and its empty message is R.string.no_numerical_habits = 'No measurable habits found'.
6. `widgets.config-picker#6` — The base HabitPickerDialog hides nothing and its empty message is R.string.no_habits = 'No habits found'.
7. `widgets.config-picker#7` — When no habit survives the filter, the activity shows R.layout.widget_empty_activity (a 250dp x 150dp centred TextView at R.dimen.regularTextSize = 16sp) with the type-specific empty message and returns early — no result is set, so the pending widget placement is cancelled by the launcher.
8. `widgets.config-picker#8` — Otherwise the activity shows R.layout.widget_configure_activity: a wrap_content vertical LinearLayout containing only a ListView id=listView, whose adapter is an ArrayAdapter over habit names using android.R.layout.simple_list_item_1.
9. `widgets.config-picker#9` — Tapping a list row immediately confirms with exactly that one habit id — there is no multi-select and no Save button in the layout (a saveButton lookup remains in the code but resolves to null and is unused).
10. `widgets.config-picker#10` — confirm(selectedIds) calls widgetPreferences.addWidget(widgetId, ids), then widgetUpdater.updateWidgets() (all widgets, all providers), then setResult(RESULT_OK, Intent with EXTRA_APPWIDGET_ID = widgetId), then finish().
11. `widgets.config-picker#11` — Backing out of the picker without choosing leaves the default RESULT_CANCELED, so the widget is not added.

#### widgets.updater

- [ ] `widgets.updater` — WidgetUpdater: pushing updates when data changes
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/WidgetUpdater.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentScheduler.kt`, `.../HabitsApplication.kt`, `.../activities/habits/list/ListHabitsActivity.kt`, `.../activities/habits/show/ShowHabitActivity.kt`, `.../activities/settings/SettingsFragment.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateUtils.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** The listener + selective-refresh logic is portable; the AppWidgetManager broadcast and exact-alarm scheduling are not. (Merged duplicate id: `commands.listener-widget-updater`.)

1. `widgets.updater#1` — WidgetUpdater implements CommandRunner.Listener; onCommandFinished(command) updates only the widgets bound to command.habit.id when the command is a CreateRepetitionCommand, and updates ALL widgets for any other command type.
2. `widgets.updater#2` — startListening() registers the updater with the CommandRunner; stopListening() removes it.
3. `widgets.updater#3` — updateWidgets(modifiedHabitId) runs on the TaskRunner and refreshes the six provider classes in this fixed order: CheckmarkWidgetProvider, HistoryWidgetProvider, ScoreWidgetProvider, StreakWidgetProvider, FrequencyWidgetProvider, TargetWidgetProvider.
4. `widgets.updater#4` — For each provider it fetches AppWidgetManager.getAppWidgetIds(ComponentName(context, providerClass)); when modifiedHabitId is null it uses all of them, otherwise it keeps only the ids whose stored habit id array contains that habit id.
5. `widgets.updater#5` — It then sends an explicit broadcast Intent(context, providerClass) with action AppWidgetManager.ACTION_APPWIDGET_UPDATE and extra EXTRA_APPWIDGET_IDS set to the filtered id array; the broadcast is sent even when the filtered array is empty.
6. `widgets.updater#6` — updateWidgets() with no argument is shorthand for updateWidgets(null), i.e. refresh everything.
7. `widgets.updater#7` — scheduleStartDayWidgetUpdate() computes DateUtils.getStartOfTomorrowWithOffset(preferences.midnightDelayHours, 0) and asks IntentScheduler.scheduleWidgetUpdate(timestamp) so widgets redraw at the start of the next logical day.
8. `widgets.updater#8` — midnightDelayHours is 3 when the 'midnight delay' preference is enabled and 0 otherwise.
9. `widgets.updater#9` — IntentScheduler.scheduleWidgetUpdate uses AlarmManager.setExactAndAllowWhileIdle with alarm type RTC (not RTC_WAKEUP), returns SchedulerResult.IGNORED without scheduling if the timestamp is already in the past, and also returns IGNORED on API 31+ when canScheduleExactAlarms() is false.
10. `widgets.updater#10` — Widgets are additionally refreshed: on HabitsApplication startup (startListening + scheduleStartDayWidgetUpdate, then a TaskRunner job calling updateWidgets()), on ListHabitsActivity.onResume after AutoBackup runs, from ShowHabitActivity's Screen.updateWidgets(), from HabitPickerDialog.confirm(), and when the pref_widget_opacity setting changes.
11. `widgets.updater#11` — HabitsApplication.onTerminate calls widgetUpdater.stopListening().
12. `widgets.updater#12` — `onCommandFinished(command)`: if `command is CreateRepetitionCommand` it calls `updateWidgets(command.habit.id)`; for every other command type it calls `updateWidgets()`, which is `updateWidgets(null)`.
13. `widgets.updater#13` — A CreateRepetitionCommand whose habit.id is null passes null and therefore updates ALL widgets (the `?` differs from HabitCardListCache, which skips entirely in that case).
14. `widgets.updater#14` — WidgetUpdater subscribes in `startListening()` (called first among app-scoped listeners in HabitsApplication.onCreate) and unsubscribes in `stopListening()`.

#### widgets.day-rollover

- [ ] `widgets.day-rollover` — Widgets redraw at the start of the next logical day
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/receivers/WidgetReceiver.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/widgets/WidgetUpdater.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/PendingIntentFactory.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentScheduler.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/intents/IntentSchedulerTest.kt`
- **Notes:** Merged duplicate id: `time.widget-midnight-update`.

1. `widgets.day-rollover#1` — A WidgetReceiver broadcast with action 'org.isoron.uhabits.ACTION_UPDATE_WIDGETS_VALUE' triggers, in order: setToday(computeToday(prefs.midnightDelayHours, 0)), widgetUpdater.updateWidgets(), widgetUpdater.scheduleStartDayWidgetUpdate().
2. `widgets.day-rollover#2` — The rollover alarm therefore re-arms itself every day: each firing schedules the next one.
3. `widgets.day-rollover#3` — The PendingIntent for this alarm is a broadcast to WidgetReceiver with request code 0 and flags FLAG_IMMUTABLE|FLAG_UPDATE_CURRENT — so only one rollover alarm can be pending at a time.
4. `widgets.day-rollover#4` — This action is the only WidgetReceiver action that does NOT parse a habit/date out of the intent.
5. `widgets.day-rollover#5` — Independently of the alarm, each appwidget-provider declares updatePeriodMillis = 3600000, so the system also refreshes every widget roughly once an hour.
6. `widgets.day-rollover#6` — WidgetUpdater.scheduleStartDayWidgetUpdate() computes timestamp = DateUtils.getStartOfTomorrowWithOffset(preferences.midnightDelayHours, 0) and calls intentScheduler.scheduleWidgetUpdate(timestamp).
7. `widgets.day-rollover#7` — scheduleWidgetUpdate builds the updateWidgets PendingIntent (broadcast to WidgetReceiver, action ACTION_UPDATE_WIDGETS_VALUE, request code 0) and schedules it with alarm type RTC (not RTC_WAKEUP).
8. `widgets.day-rollover#8` — scheduleStartDayWidgetUpdate is also called once from HabitsApplication.onCreate.
9. `widgets.day-rollover#9` — getStartOfTomorrowWithOffset(h, 0) is literally getUpcomingTimeInMillis(h, 0), so with the midnight delay disabled it is the next local 00:00 and with it enabled the next local 03:00.
10. `widgets.day-rollover#10` — Instrumented regression: with system time America/Chicago 2020-06-01 12:30, scheduleWidgetUpdate(1591155900000) returns OK, no broadcast arrives by 2020-06-02 22:44, and one arrives by 22:46.

#### widgets.behavior

- [ ] `widgets.behavior` — WidgetBehavior: core logic behind widget taps
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehavior.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehaviorTest.kt`
- **Notes:** WidgetBehaviorTest covers add/remove/toggle (all four current values x skip enabled/disabled)/increment/decrement, and explicitly verifies that add/remove/increment/decrement do NOT read preferences.isSkipEnabled. WidgetBehavior itself is pure core; only its callers (widget providers, notification action receivers) are Android-specific. (Merged duplicate id: `commands.dispatch-widget-behavior`.)

1. `widgets.behavior#1` — WidgetBehavior.onAddRepetition(habit, date) cancels the habit's notification first, reads habit.originalEntries.get(date) for its notes, then runs CreateRepetitionCommand(habitList, habit, date, Entry.YES_MANUAL = 2, notes); it never reads Preferences.isSkipEnabled.
2. `widgets.behavior#2` — WidgetBehavior.onRemoveRepetition(habit, date) cancels the notification first, then runs CreateRepetitionCommand with Entry.NO = 0 and the existing notes; it never reads Preferences.isSkipEnabled.
3. `widgets.behavior#3` — WidgetBehavior.onToggleRepetition(habit, date) reads habit.originalEntries.get(date), computes Entry.nextToggleValue(currentValue, isSkipEnabled = preferences.isSkipEnabled, areQuestionMarksEnabled = preferences.areQuestionMarksEnabled), runs the CreateRepetitionCommand, and only THEN cancels the notification.
4. `widgets.behavior#4` — Entry.nextToggleValue maps: YES_AUTO(1) -> YES_MANUAL(2); YES_MANUAL(2) -> SKIP(3) if skip is enabled else NO(0); SKIP(3) -> NO(0); NO(0) -> UNKNOWN(-1) if question marks are enabled else YES_MANUAL(2); UNKNOWN(-1) -> YES_MANUAL(2); any other value -> YES_MANUAL(2).
5. `widgets.behavior#5` — WidgetBehavior.onIncrement(habit, date, amount) reads habit.computedEntries.get(date) (not originalEntries), runs CreateRepetitionCommand with currentValue + amount, then cancels the notification. With a stored entry of 500 and amount 100 the new value is 600.
6. `widgets.behavior#6` — WidgetBehavior.onDecrement(habit, date, amount) is symmetric: currentValue - amount (500 - 100 = 400); the value is NOT clamped at zero by this method.
7. `widgets.behavior#7` — All five entry points funnel through setValue(habit, date, newValue, notes) which runs CreateRepetitionCommand(habitList, habit, date, newValue, notes) on the CommandRunner; the notes of the existing entry are always preserved.
8. `widgets.behavior#8` — Because the resulting command is a CreateRepetitionCommand, WidgetUpdater refreshes only the widgets bound to that habit.
9. `widgets.behavior#9` — `WidgetBehavior` is constructed with (habitList, commandRunner, notificationTray, preferences) and funnels everything through `setValue(habit, date, newValue, notes)`, which runs `CreateRepetitionCommand(habitList, habit, date, newValue, notes)`.
10. `widgets.behavior#10` — Increment/decrement amounts are raw thousandths values (e.g. 100 means 0.1 units), and no clamping to zero or to the target is applied — the value may go negative.
11. `widgets.behavior#11` — Add/remove/toggle read originalEntries while increment/decrement read computedEntries; this asymmetry is deliberate and must be preserved.

#### widgets.error-states

- [ ] `widgets.error-states` — Widget error and empty states
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/widgets/BaseWidgetProvider.kt`, `uhabits-android/src/main/res/layout/widget_error.xml`, `uhabits-android/src/main/res/drawable/widget_background.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/widgets/activities/HabitPickerDialog.kt`, `.../StackWidget.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/WidgetSteps.kt`
- **Notes:** WidgetSteps.verifyCheckmarkWidgetIsShown explicitly asserts that no view whose text starts with 'Habit deleted' is present.

1. `widgets.error-states#1` — If a widget's stored habit id no longer resolves to a habit, the widget is replaced by the widget_error layout showing 'Habit deleted / not found'.
2. `widgets.error-states#2` — Any other RuntimeException during widget construction or rendering produces the same error layout with its default text 'Error drawing widget'.
3. `widgets.error-states#3` — The error layout is a centred white TextView on drawable widget_background (solid #3f000000, corner radius 4dp) with paddingTop 4dp, paddingLeft/Right 8dp, paddingBottom 0dp; it has no click target.
4. `widgets.error-states#4` — A stack widget whose adapter reports zero items shows its type-specific empty TextView (e.g. 'Checkmark Stack Widget') instead of any habit content.
5. `widgets.error-states#5` — While a stack page is loading, the EmptyWidget placeholder (blank rounded card with an empty title) is shown.
6. `widgets.error-states#6` — If the user has no eligible habits when placing a widget, the configuration activity shows a plain message screen and never returns RESULT_OK, so no widget is created.

## Domain: Reminders, notifications and time

#### reminders.upcoming-time

- [x] `reminders.upcoming-time` — Computing the next occurrence of a wall-clock reminder time
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateUtils.kt`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/platform/time/DateUtilsTest.kt`
- **Notes:** Dart's DateTime/timezone handling differs; the 'local-shifted millis' representation (epoch millis + tz offset) is used pervasively and must be reproduced exactly, including the double-offset applyTimezone that makes DST transitions round-trip.

1. `reminders.upcoming-time#1` — DateUtils.getUpcomingTimeInMillis(hour, minute) returns a UTC epoch-millis instant for the next occurrence of local wall-clock hour:minute.
2. `reminders.upcoming-time#2` — Algorithm: localTime = getLocalTime() (epoch millis shifted by the timezone offset); startOfToday = floor(localTime / 86400000) * 86400000; build a GMT calendar at startOfToday, set HOUR_OF_DAY=hour, MINUTE=minute, SECOND=0 (millis stay 0); call the result `time`; if localTime > time then time += 86400000; return applyTimezone(time).
3. `reminders.upcoming-time#3` — The comparison is strictly greater-than: if the current local time equals the reminder time exactly, the reminder is scheduled for TODAY (the same instant), not tomorrow.
4. `reminders.upcoming-time#4` — With fixed timezone GMT and fixed local time 2015-01-25 08:00, getUpcomingTimeInMillis(10, 1) == 2015-01-25 10:01 UTC.
5. `reminders.upcoming-time#5` — DateUtils.applyTimezone(localTimestamp, tz) = localTimestamp - tz.getOffset(localTimestamp - tz.getOffset(localTimestamp)) (double offset lookup, so DST boundaries resolve correctly).
6. `reminders.upcoming-time#6` — DateUtils.removeTimezone(timestamp, tz) = timestamp + tz.getOffset(timestamp).
7. `reminders.upcoming-time#7` — DateUtils.getLocalTime(tz) = now + tz.getOffset(now), where now = System.currentTimeMillis() unless a fixed local time has been injected for tests.
8. `reminders.upcoming-time#8` — Constants: SECOND_LENGTH=1000, MINUTE_LENGTH=60000, HOUR_LENGTH=3600000, DAY_LENGTH=86400000.
9. `reminders.upcoming-time#9` — DateUtils.getStartOfDay(t) = (t / 86400000) * 86400000 (integer division, so it assumes t >= 0).
10. `reminders.upcoming-time#10` — DateUtils.getStartOfDayWithOffset(t, hourOffset, minuteOffset) = getStartOfDay(t - hourOffset*3600000 - minuteOffset*60000). For t = Sep 3 00:00 plus 3h29m with offset (3, 30), the result is Sep 2 00:00.
11. `reminders.upcoming-time#11` — DateUtils.getStartOfTomorrowWithOffset(h, m) is defined as exactly getUpcomingTimeInMillis(h, m).
12. `reminders.upcoming-time#12` — DateUtils.millisecondsUntilTomorrowWithOffset(h, m) = getStartOfTomorrowWithOffset(h, m) - applyTimezone(getLocalTime()). At GMT 2017-01-01 23:59 with offset (0,0) it is 60000; at 20:00 it is 14400000; at 23:59 with offset (3,30) it is 3*3600000 + 31*60000; at 2017-01-02 01:00 with offset (3,30) it is 2*3600000 + 30*60000.

#### reminders.schedule-one-habit

- [x] `reminders.schedule-one-habit` — Scheduling the alarm for a single habit
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/reminders/ReminderScheduler.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/WidgetPreferences.kt`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/reminders/ReminderSchedulerTest.kt`

1. `reminders.schedule-one-habit#1` — ReminderScheduler.schedule(habit) returns immediately, logging "Habit has null id. Returning.", if habit.id == null.
2. `reminders.schedule-one-habit#2` — It returns immediately, logging "habit=<id> has no reminder. Skipping.", if habit.hasReminder() is false.
3. `reminders.schedule-one-habit#3` — Otherwise reminderTime = DateUtils.getUpcomingTimeInMillis(habit.reminder.hour, habit.reminder.minute).
4. `reminders.schedule-one-habit#4` — It then reads snoozeReminderTime = widgetPreferences.getSnoozeTime(habit.id). If that value is exactly 0L, no snooze is applied.
5. `reminders.schedule-one-habit#5` — If snoozeReminderTime != 0L and snoozeReminderTime > now (now = applyTimezone(getLocalTime()), i.e. current UTC epoch millis), then reminderTime is replaced by snoozeReminderTime.
6. `reminders.schedule-one-habit#6` — If snoozeReminderTime != 0L and snoozeReminderTime <= now, the stored snooze is discarded via widgetPreferences.removeSnoozeTime(habit.id) and the regular reminderTime is used.
7. `reminders.schedule-one-habit#7` — Finally scheduleAtTime(habit, reminderTime) is called.
8. `reminders.schedule-one-habit#8` — Regression scenario from tests (timezone GMT-4, now = 2015-01-01 15:00 local-shifted, reminder 08:30 every day): with a stored snooze of 2015-01-01 21:00 UTC, the scheduled reminder is 2015-01-01 21:00 with checkmark timestamp 2015-01-01 00:00; with a stored snooze of 2015-01-01 07:00 UTC (in the past) the snooze is dropped and the reminder is applyTimezone(2015-01-02 08:30) with checkmark timestamp 2015-01-02 00:00.
9. `reminders.schedule-one-habit#9` — schedule() is synchronized; concurrent calls must not interleave.

#### reminders.schedule-at-time

- [x] `reminders.schedule-at-time` — scheduleAtTime and the derived checkmark timestamp
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/reminders/ReminderScheduler.kt`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/reminders/ReminderSchedulerTest.kt`

1. `reminders.schedule-at-time#1` — ReminderScheduler.scheduleAtTime(habit, reminderTime) skips (logs "has no reminder. Skipping.") when habit.hasReminder() is false.
2. `reminders.schedule-at-time#2` — It skips (logs "is archived. Skipping.") when habit.isArchived is true — archived habits never fire reminders even though they are included in the WITH_ALARM query.
3. `reminders.schedule-at-time#3` — The checkmark timestamp handed to the system scheduler is DateUtils.getStartOfDayWithOffset(DateUtils.removeTimezone(reminderTime), 0, 0) — i.e. the reminder instant converted to local-shifted millis and floored to local midnight. The hour/minute offsets are hard-coded 0, so the user's midnight-delay preference is deliberately NOT applied to the reminder's target date.
4. `reminders.schedule-at-time#4` — It then calls sys.scheduleShowReminder(reminderTime, habit, timestamp).
5. `reminders.schedule-at-time#5` — Test scenario: timezone GMT-4, scheduleAtTime(habit, 2015-01-30 11:30 UTC) with reminder 08:30 produces checkmark timestamp 2015-01-30 00:00.
6. `reminders.schedule-at-time#6` — Test scenario: timezone GMT-4, now = 2015-01-26 06:30, reminder 08:30 -> reminderTime 2015-01-26 12:30 UTC, timestamp 2015-01-26 00:00 ("later today").
7. `reminders.schedule-at-time#7` — Test scenario: timezone GMT-4, now = 2015-01-26 13:00, reminder 08:30 -> reminderTime 2015-01-27 12:30 UTC, timestamp 2015-01-27 00:00 ("tomorrow").

#### reminders.schedule-all

- [x] `reminders.schedule-all` — Scheduling all reminders / WITH_ALARM filter
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/reminders/ReminderScheduler.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitMatcher.kt`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/reminders/ReminderSchedulerTest.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitMatcherTest.kt`

1. `reminders.schedule-all#1` — ReminderScheduler.scheduleAll() logs "Scheduling all alarms" and calls schedule(habit) for every habit returned by habitList.getFiltered(HabitMatcher.WITH_ALARM).
2. `reminders.schedule-all#2` — HabitMatcher.WITH_ALARM == HabitMatcher(isArchivedAllowed = true, isReminderRequired = true, isCompletedAllowed = true, isEnteredAllowed = true, searchQuery = ""). Archived habits therefore pass the filter but are dropped later inside scheduleAtTime.
3. `reminders.schedule-all#3` — Habits with reminder == null are excluded from scheduleAll entirely.
4. `reminders.schedule-all#4` — ReminderScheduler.hasHabitsWithReminders() returns true iff habitList.getFiltered(HabitMatcher.WITH_ALARM) is non-empty.
5. `reminders.schedule-all#5` — Test scenario: with h1 reminder 08:30 every day, h2 reminder 18:30 every day, h3 reminder null, and now = 2015-01-26 13:00 in GMT-4, scheduleAll schedules h1 at 2015-01-27 12:30 UTC and h2 at 2015-01-26 22:30 UTC and schedules nothing for h3.

#### reminders.reschedule-on-command

- [ ] `reminders.reschedule-on-command` — Automatic rescheduling when the model changes
- **Platform:** core · **Port risk:** high
- **Source:** `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/reminders/ReminderScheduler.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/reminders/ReminderSchedulerTest.kt`
- **Notes:** ReminderSchedulerTest covers schedule/scheduleAll/snooze but has NO test for the onCommandFinished filter — the two ignored command types are untested and easy to get wrong in a port. Alarm scheduling itself is AlarmManager-specific. (Merged duplicate id: `commands.listener-reminder-scheduler`.)

1. `reminders.reschedule-on-command#1` — ReminderScheduler implements CommandRunner.Listener. onCommandFinished(command) calls scheduleAll() for every command EXCEPT CreateRepetitionCommand and ChangeHabitColorCommand, for which it returns without doing anything.
2. `reminders.reschedule-on-command#2` — startListening() registers the scheduler with the CommandRunner; stopListening() unregisters it. Both are synchronized.
3. `reminders.reschedule-on-command#3` — Consequence: creating, editing, deleting, archiving or unarchiving a habit re-arms every alarm; checking off a habit or changing its color does not.
4. `reminders.reschedule-on-command#4` — HabitsApplication.onCreate calls reminderScheduler.startListening() and then, on a background task, reminderScheduler.scheduleAll().
5. `reminders.reschedule-on-command#5` — HabitsApplication.onTerminate calls reminderScheduler.stopListening().
6. `reminders.reschedule-on-command#6` — Rationale: ticking a checkmark and recolouring a habit cannot change any reminder, while creating, editing, deleting, archiving and unarchiving all can.
7. `reminders.reschedule-on-command#7` — `scheduleAll()` iterates `habitList.getFiltered(HabitMatcher.WITH_ALARM)` and calls `schedule(habit)` on each; it does not cancel previously scheduled alarms explicitly.
8. `reminders.reschedule-on-command#8` — `schedule(habit)` skips habits with a null id and habits without a reminder; it computes the reminder time as the next occurrence of reminder.hour:reminder.minute, and if a non-zero snooze time exists for that habit id it uses the snooze time when it is still in the future, otherwise it clears the stored snooze time.
9. `reminders.reschedule-on-command#9` — `scheduleAtTime` additionally skips habits that have no reminder or that are archived, so archiving a habit removes it from future scheduling on the next scheduleAll pass.
10. `reminders.reschedule-on-command#10` — The whole method is annotated @Synchronized.

#### reminders.snooze-storage

- [x] `reminders.snooze-storage` — Snooze time persistence
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/WidgetPreferences.kt`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/reminders/ReminderSchedulerTest.kt`
- **Notes:** Merged duplicate id: `settings.widget-preferences.snooze`.

1. `reminders.snooze-storage#1` — Snooze times are stored in WidgetPreferences under the string key format "snooze-%06d" applied to habitId.toInt() — e.g. habit id 10 -> "snooze-000010". Note the deliberate Long->Int narrowing in the key.
2. `reminders.snooze-storage#2` — WidgetPreferences.getSnoozeTime(id) returns storage.getLong(key, 0); the default and the 'no snooze' sentinel are both 0L.
3. `reminders.snooze-storage#3` — WidgetPreferences.removeSnoozeTime(id) writes 0L to the key (it does not delete the key).
4. `reminders.snooze-storage#4` — WidgetPreferences.setSnoozeTime(id, time) writes the absolute UTC epoch-millis instant.
5. `reminders.snooze-storage#5` — Snooze state survives app restarts and reboots because it lives in preferences, not in memory.
6. `reminders.snooze-storage#6` — The snooze key for a habit is format("snooze-%06d", id.toInt()) — note the Long habit id is narrowed to Int before formatting, so ids beyond Int range collide.

#### reminders.snooze-by-delay

- [ ] `reminders.snooze-by-delay` — Snoozing by a fixed delay
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/reminders/ReminderScheduler.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderController.kt`, `uhabits-android/src/main/res/values/constants.xml`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/reminders/ReminderSchedulerTest.kt`

1. `reminders.snooze-by-delay#1` — ReminderScheduler.snoozeReminder(habit, minutes) computes now = DateUtils.applyTimezone(DateUtils.getLocalTime()) (current UTC epoch millis), snoozedUntil = now + minutes * 60 * 1000, stores it with widgetPreferences.setSnoozeTime(habit.id, snoozedUntil), and then calls schedule(habit).
2. `reminders.snooze-by-delay#2` — Because the value is persisted, any subsequent scheduleAll() (e.g. after a boot or a habit edit) re-honours the snooze until it expires.
3. `reminders.snooze-by-delay#3` — ReminderController.onSnoozeDelayPicked(habit, delayInMinutes) calls reminderScheduler.snoozeReminder(habit, delayInMinutes.toLong()) and then notificationTray.cancel(habit), in that order.
4. `reminders.snooze-by-delay#4` — Available delays in minutes are exactly: 15, 30, 60, 120, 240, 480, 1440, plus the sentinel -1 meaning "Custom...".
5. `reminders.snooze-by-delay#5` — Delay labels in order are: "15 minutes", "30 minutes", "1 hour", "2 hours", "4 hours", "8 hours", "24 hours", "Custom...".

#### reminders.snooze-custom-time

- [x] `reminders.snooze-custom-time` — Snoozing until a custom wall-clock time
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderController.kt`, `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/reminders/ReminderScheduler.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `reminders.snooze-custom-time#1` — ReminderController.onSnoozeTimePicked(habit, hour, minute) computes time = DateUtils.getUpcomingTimeInMillis(hour, minute), calls reminderScheduler.scheduleAtTime(habit, time), then notificationTray.cancel(habit).
2. `reminders.snooze-custom-time#2` — Custom-time snooze does NOT write anything to WidgetPreferences. Therefore any later scheduleAll() (triggered by a command, app start, or boot) overwrites the one-off alarm with the habit's regular reminder time. This asymmetry versus delay-based snooze is real behaviour and must be preserved.
3. `reminders.snooze-custom-time#3` — If the chosen hour:minute is still ahead today, the alarm lands today; otherwise it lands tomorrow (getUpcomingTimeInMillis semantics).

#### reminders.snooze-picker-ui

- [ ] `reminders.snooze-picker-ui` — Snooze delay picker dialog
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/notifications/SnoozeDelayPickerActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderController.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/SystemUtils.kt`, `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/src/main/res/values/constants.xml`
- **Kotlin tests:** `uhabits-android/src/test/java/org/isoron/uhabits/receivers/ReminderControllerTest.kt`
- **Notes:** Translucent single-instance activity launched from a notification action over the lock screen has no Flutter equivalent; on Flutter this needs a platform channel plus a native transparent activity, or a redesign (e.g. snooze sub-actions directly on the notification). Showing an activity over the lock screen from a notification action is not expressible in pure Flutter. (Merged duplicate id: `platform-glue.snooze-delay-picker`.)

1. `reminders.snooze-picker-ui#1` — SnoozeDelayPickerActivity is launched with data = Uri.parse(habit.uriString) and flag FLAG_ACTIVITY_NEW_TASK; before launching, ReminderController broadcasts Intent.ACTION_CLOSE_SYSTEM_DIALOGS so the notification shade collapses.
2. `reminders.snooze-picker-ui#2` — It finishes immediately when intent is null, when intent.data is null, or when no habit matches ContentUris.parseId(data).
3. `reminders.snooze-picker-ui#3` — The theme is chosen from AndroidThemeSwitcher: night mode uses R.style.BaseDialogDark with DarkTheme, otherwise R.style.BaseDialog with LightTheme.
4. `reminders.snooze-picker-ui#4` — The dialog title is "Select snooze delay" and the items are the eight snooze names in order.
5. `reminders.snooze-picker-ui#5` — Tapping an item whose value is >= 0 calls ReminderController.onSnoozeDelayPicked(habit, value) and finishes the activity.
6. `reminders.snooze-picker-ui#6` — Tapping the item whose value is < 0 ("Custom...") opens a radial TimePickerDialog pre-set to the current Calendar HOUR_OF_DAY and MINUTE, using 24-hour mode iff DateFormat.is24HourFormat(context), and tinted with the habit's theme colour. Picking a time calls onSnoozeTimePicked(habit, hour, minute) and finishes.
7. `reminders.snooze-picker-ui#7` — Dismissing the dialog (back press / outside tap) finishes the activity.
8. `reminders.snooze-picker-ui#8` — finish() is overridden to call overridePendingTransition(0, 0) — no enter/exit animation.
9. `reminders.snooze-picker-ui#9` — The activity calls KeyguardManager.requestDismissKeyguard so the picker is usable on a locked screen.
10. `reminders.snooze-picker-ui#10` — Manifest attributes: android:excludeFromRecents="true", android:launchMode="singleInstance", android:taskAffinity="", android:theme="@android:style/Theme.Translucent.NoTitleBar".
11. `reminders.snooze-picker-ui#11` — The parallel R.array.snooze_picker_values are exactly [15, 30, 60, 120, 240, 480, 1440, -1] (minutes; -1 is the sentinel for "custom").
12. `reminders.snooze-picker-ui#12` — Selecting an item whose value >= 0 calls reminderController.onSnoozeDelayPicked(habit, minutes) and finishes; onSnoozeDelayPicked calls reminderScheduler.snoozeReminder(habit, minutes) and notificationTray.cancel(habit).
13. `reminders.snooze-picker-ui#13` — SystemUtils.unlockScreen is invoked after showing the dialog: it calls KeyguardManager.requestDismissKeyguard(activity, null) so the picker is usable from the lock screen.
14. `reminders.snooze-picker-ui#14` — The snooze_picker_names array is localizable (it references @string/interval_* entries); snooze_picker_values is marked translatable="false".

#### reminders.snooze-android12-gate

- [ ] `reminders.snooze-android12-gate` — Snooze action hidden on Android 12+
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/notifications/AndroidNotificationTray.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderReceiver.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Reason for the gate: Android 12 forbids notification trampolines that start an activity from a broadcast receiver.

1. `reminders.snooze-android12-gate#1` — The "Later" (snooze) notification action is added only when Build.VERSION.SDK_INT < Build.VERSION_CODES.S (31).
2. `reminders.snooze-android12-gate#2` — ReminderReceiver, on receiving ACTION_SNOOZE_REMINDER, calls reminderController.onSnoozePressed only when SDK_INT < 31; on 31+ it logs a warning ("should be deactivated in recent versions") and does nothing.
3. `reminders.snooze-android12-gate#3` — The action label is the string "snooze" whose English value is "Later" and whose icon is R.drawable.ic_action_snooze.

#### notifications.show-gating

- [x] `notifications.show-gating` — Deciding whether a reminder notification is actually shown
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/NotificationTray.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/CoroutineTaskRunner.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `notifications.show-gating#1` — NotificationTray.show(habit, date, reminderTime) stores NotificationData(date, reminderTime) in an in-memory map keyed by habit and enqueues a ShowNotificationTask on the TaskRunner.
2. `notifications.show-gating#2` — ShowNotificationTask.doInBackground computes isCompleted = habit.isCompletedToday() on a background dispatcher; all the gating below then runs on the main dispatcher in onPostExecute.
3. `notifications.show-gating#3` — Gate 1: if isCompleted is true AND habit.targetType != NumericalHabitType.AT_MOST, skip and log "Habit <id> already checked. Skipping."
4. `notifications.show-gating#4` — Gate 2: if habit.hasReminder() is false, skip and log "Habit <id> does not have a reminder. Skipping."
5. `notifications.show-gating#5` — Gate 3: if habit.isArchived, skip and log "Habit <id> is archived. Skipping."
6. `notifications.show-gating#6` — Gate 4: if the reminder's weekday set does not contain the notification's date, skip and log "Habit <id> not supposed to run today. Skipping."
7. `notifications.show-gating#7` — The weekday test is: index = (date.dayOfWeek.daysSinceSunday + 1) % 7, then reminder.days.toArray()[index]. So SUNDAY->1, MONDAY->2, ..., FRIDAY->6, SATURDAY->0.
8. `notifications.show-gating#8` — The weekday test uses the date carried by the notification (the alarm's target day), not the current day.
9. `notifications.show-gating#9` — Only if all four gates pass is systemTray.showNotification(habit, notificationId, date, reminderTime) invoked. "Showing notification for habit=<id>" is logged before the gates run.
10. `notifications.show-gating#10` — habit.isCompletedToday() for a NUMERICAL habit with targetType AT_LEAST is (value / 1000.0 >= targetValue); for AT_MOST it always returns false; for YES_NO it is value != Entry.NO (0) && value != Entry.UNKNOWN (-1).
11. `notifications.show-gating#11` — Because AT_MOST habits are never 'completed', gate 1 never fires for them — the reminder for an at-most habit always shows.

#### notifications.id-and-registry

- [ ] `notifications.id-and-registry` — Notification ids, active registry, cancel and reshow
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/NotificationTray.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/notifications/AndroidNotificationTray.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `notifications.id-and-registry#1` — NotificationTray.getNotificationId(habit) returns (habit.id % Int.MAX_VALUE).toInt(), or 0 when habit.id is null.
2. `notifications.id-and-registry#2` — NotificationTray keeps a MutableMap<Habit, NotificationData> named `active` holding every notification currently considered shown.
3. `notifications.id-and-registry#3` — cancel(habit) calls systemTray.removeNotification(getNotificationId(habit)) and removes the habit from `active`.
4. `notifications.id-and-registry#4` — reshow(habit) re-runs ShowNotificationTask with the stored NotificationData if the habit is present in `active`; it does nothing if the habit is absent.
5. `notifications.id-and-registry#5` — reshowAll() re-runs ShowNotificationTask for every entry in `active`.
6. `notifications.id-and-registry#6` — AndroidNotificationTray.removeNotification(id) calls NotificationManagerCompat.cancel(id) and removes the id from its own HashSet<Int> of active ids; showNotification adds the id to that set.
7. `notifications.id-and-registry#7` — The `active` map is keyed by the Habit data class instance, so lookups use value equality of the whole Habit; a Flutter port should key by habit id instead and preserve the same observable behaviour.

#### notifications.content

- [ ] `notifications.content` — Reminder notification content
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/notifications/AndroidNotificationTray.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/PendingIntentFactory.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** none — write Dart test from rules

1. `notifications.content#1` — Channel id is the constant "REMINDERS" (NotificationTray.REMINDERS_CHANNEL_ID).
2. `notifications.content#2` — Small icon is R.drawable.ic_notification.
3. `notifications.content#3` — Content title is habit.name verbatim.
4. `notifications.content#4` — Content text is habit.question, unless habit.question.isBlank() in which case it is the string default_reminder_question, English value "Have you completed this habit today?".
5. `notifications.content#5` — Content intent (tap) opens ShowHabitActivity for that habit, built with androidx TaskStackBuilder.addNextIntentWithParentStack so the back stack contains ListHabitsActivity; the intent data is content://org.isoron.uhabits/habit/<id>.
6. `notifications.content#6` — Delete intent (swipe away) is a broadcast to ReminderReceiver with action "org.isoron.uhabits.ACTION_DISMISS_REMINDER" and data content://org.isoron.uhabits/habit/<id>.
7. `notifications.content#7` — setWhen(reminderTime) and setShowWhen(true) — the timestamp shown is the reminder instant passed in, not the moment the notification was posted.
8. `notifications.content#8` — setOngoing(preferences.shouldMakeNotificationsSticky()).
9. `notifications.content#9` — The builder first calls setSound(null); the ringtone URI is applied afterwards only when disableSound is false.
10. `notifications.content#10` — The habit's colour is NOT applied to the notification.
11. `notifications.content#11` — The notification carries no group / summary (notification groups were deliberately removed).

#### notifications.actions

- [ ] `notifications.actions` — Reminder notification action buttons
- **Platform:** ui · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/notifications/AndroidNotificationTray.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/PendingIntentFactory.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/receivers/WidgetReceiver.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehaviorTest.kt`
- **Notes:** WearableExtender / Pebble support and notification action semantics have no direct Flutter equivalent.

1. `notifications.actions#1` — For a NUMERICAL habit exactly one action is added: icon R.drawable.ic_action_check, label "Enter" (R.string.enter), PendingIntent = showNumberPicker(habit, date).
2. `notifications.actions#2` — For a non-numerical (YES_NO) habit exactly two actions are added in this order: "Yes" (R.string.yes, icon ic_action_check) -> addCheckmark(habit, date); "No" (R.string.no, icon ic_action_cancel) -> removeRepetition(habit, date).
3. `notifications.actions#3` — Additionally, on SDK < 31 a third action "Later" (R.string.snooze, icon ic_action_snooze) -> snoozeNotification(habit) is appended after the above.
4. `notifications.actions#4` — The same action list is duplicated into a NotificationCompat.WearableExtender whose background is the bitmap R.drawable.stripe; the comment states Pebble requires the actions on the WearableExtender even though they duplicate the phone actions.
5. `notifications.actions#5` — "Yes" broadcasts to WidgetReceiver with action org.isoron.uhabits.ACTION_ADD_REPETITION, data = habit uri, extra long "timestamp" = date.unixTime; the handler sets the entry value to Entry.YES_MANUAL (2) preserving existing notes and cancels the notification.
6. `notifications.actions#6` — "No" broadcasts to WidgetReceiver with action org.isoron.uhabits.ACTION_REMOVE_REPETITION, same data/extra; the handler sets the entry value to Entry.NO (0) preserving existing notes and cancels the notification.
7. `notifications.actions#7` — "Enter" starts ListHabitsActivity with action org.isoron.uhabits.ACTION_EDIT, extras long "habit" = habit.id and long "timestamp" = date.unixTime; ListHabitsActivity.parseIntents then calls listHabitsBehavior.onEdit(habit, LocalDate.fromUnixTime(timestamp), 0f, 0f) to open the numeric value dialog.
8. `notifications.actions#8` — "Later" broadcasts to ReminderReceiver with action org.isoron.uhabits.ACTION_SNOOZE_REMINDER and data = habit uri, no extras.

#### notifications.channel

- [ ] `notifications.channel` — Notification channel creation
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/notifications/AndroidNotificationTray.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `notifications.channel#1` — AndroidNotificationTray.createAndroidNotificationChannel(context) creates a NotificationChannel with id "REMINDERS", user-visible name R.string.reminder (English "Reminder"), and importance NotificationManager.IMPORTANCE_DEFAULT.
2. `notifications.channel#2` — The channel is (re)created on every showNotification call, immediately before notifying.
3. `notifications.channel#3` — The channel is also created on demand when the user taps the "Customize notifications" settings entry, before launching Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS with extras EXTRA_APP_PACKAGE = packageName and EXTRA_CHANNEL_ID = "REMINDERS".

#### notifications.sound

- [ ] `notifications.sound` — Reminder sound / ringtone selection
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/notifications/RingtoneManager.kt`, `.../AndroidNotificationTray.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `notifications.sound#1` — RingtoneManager.getURI() reads the default SharedPreferences string key "pref_ringtone_uri", defaulting to Settings.System.DEFAULT_NOTIFICATION_URI.toString().
2. `notifications.sound#2` — If the stored string is empty (""), getURI() returns null, meaning silent.
3. `notifications.sound#3` — Otherwise it returns Uri.parse(storedString).
4. `notifications.sound#4` — RingtoneManager.getName() returns the localized string "None" when the URI is null or when the system cannot resolve a Ringtone for it, otherwise the ringtone's own title; it catches RuntimeException and returns null in that case.
5. `notifications.sound#5` — RingtoneManager.update(data): if data is null it returns without change; if the intent contains EXTRA_RINGTONE_PICKED_URI it stores that URI's string; if the extra is absent (user chose Silent) it stores the empty string.
6. `notifications.sound#6` — The picker intent is ACTION_RINGTONE_PICKER with EXTRA_RINGTONE_TYPE = TYPE_NOTIFICATION, EXTRA_RINGTONE_SHOW_DEFAULT = true, EXTRA_RINGTONE_SHOW_SILENT = true, EXTRA_RINGTONE_DEFAULT_URI = Settings.System.DEFAULT_NOTIFICATION_URI and EXTRA_RINGTONE_EXISTING_URI = the current URI; the request code is 1.
7. `notifications.sound#7` — The "reminderSound" preference row is currently forced invisible in SettingsFragment.onResume (findPreference("reminderSound").isVisible = false), so the picker is unreachable from the UI in this build even though all the plumbing exists.
8. `notifications.sound#8` — Notification posting is wrapped in try/catch: if NotificationManagerCompat.notify throws a RuntimeException (documented as happening on some Xiaomi devices with custom sounds), the notification is rebuilt with disableSound = true (setSound(null)) and posted again.

#### notifications.sticky-and-dismiss

- [ ] `notifications.sticky-and-dismiss` — Sticky notifications and dismiss handling
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/NotificationTray.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderController.kt`, `uhabits-android/src/main/res/xml/preferences.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt`, `uhabits-android/src/test/java/org/isoron/uhabits/receivers/ReminderControllerTest.kt`

1. `notifications.sticky-and-dismiss#1` — Preferences.shouldMakeNotificationsSticky() reads the boolean key "pref_sticky_notifications", default false.
2. `notifications.sticky-and-dismiss#2` — Preferences.setNotificationsSticky(sticky) writes the key and then fires Listener.onNotificationsChanged() on every registered listener.
3. `notifications.sticky-and-dismiss#3` — NotificationTray implements Preferences.Listener; its onNotificationsChanged() calls reshowAll(), so toggling the setting immediately re-posts every currently active notification with the new ongoing flag.
4. `notifications.sticky-and-dismiss#4` — When sticky is on, the notification is built with setOngoing(true).
5. `notifications.sticky-and-dismiss#5` — ReminderController.onDismiss(habit): if shouldMakeNotificationsSticky() is true it calls notificationTray.reshow(habit) (immediately re-posting the notification — the documented workaround for Android 14+, where even ongoing notifications can be swiped); otherwise it calls notificationTray.cancel(habit).
6. `notifications.sticky-and-dismiss#6` — onDismiss is reached via the notification's delete intent, action org.isoron.uhabits.ACTION_DISMISS_REMINDER, handled by ReminderReceiver.
7. `notifications.sticky-and-dismiss#7` — The settings screen exposes this as a SwitchPreferenceCompat titled "Make notifications sticky" with summary "Prevents notifications from being swiped away.", default false.
8. `notifications.sticky-and-dismiss#8` — A "Notification light" (led_notifications) string exists in resources but is not wired to any preference or code — it is dead and must not be ported as a feature.

#### notifications.auto-cancel

- [ ] `notifications.auto-cancel` — Automatic cancellation when the habit is entered or deleted
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/NotificationTray.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehavior.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehaviorTest.kt`
- **Notes:** The listener logic is pure, but SystemTray.removeNotification/showNotification map onto Android NotificationManager semantics and the id-derivation must be replicated per platform in Flutter. (Merged duplicate id: `commands.listener-notification-tray`.)

1. `notifications.auto-cancel#1` — NotificationTray implements CommandRunner.Listener. onCommandFinished(command): if command is CreateRepetitionCommand it cancels the notification for command.habit; if command is DeleteHabitsCommand it cancels the notification for every habit in the command's deleted list.
2. `notifications.auto-cancel#2` — startListening() registers NotificationTray with both the CommandRunner and Preferences; stopListening() unregisters from both. HabitsApplication calls startListening() in onCreate and stopListening() in onTerminate.
3. `notifications.auto-cancel#3` — WidgetBehavior.onAddRepetition cancels the notification BEFORE writing the entry; onRemoveRepetition also cancels before writing.
4. `notifications.auto-cancel#4` — WidgetBehavior.onToggleRepetition, onIncrement and onDecrement cancel the notification AFTER writing the entry.
5. `notifications.auto-cancel#5` — The net effect is that answering a reminder from the notification, the widget, or the app removes the notification exactly once.
6. `notifications.auto-cancel#6` — `onCommandFinished(command)` contains two independent `if` checks (not else-if): if `command is CreateRepetitionCommand` it destructures `val (_, habit) = command` and calls `cancel(habit)`; if `command is DeleteHabitsCommand` it destructures `val (_, deleted) = command` and calls `cancel(habit)` for every habit in the deleted list.
7. `notifications.auto-cancel#7` — All other command types (Create/Edit habit, Archive, Unarchive, ChangeColor) are ignored — an archived habit's already-showing notification is NOT dismissed by archiving it.
8. `notifications.auto-cancel#8` — `cancel(habit)` calls `systemTray.removeNotification(notificationId)` and removes the habit from the internal `active` map.
9. `notifications.auto-cancel#9` — The notification id is `(habit.id % Int.MAX_VALUE).toInt()`, and is 0 when `habit.id` is null.
10. `notifications.auto-cancel#10` — The rationale is: recording an entry (from a reminder action or anywhere else) dismisses that habit's reminder notification, and deleting a habit dismisses its notification.
11. `notifications.auto-cancel#11` — WidgetBehavior additionally calls `notificationTray.cancel(habit)` explicitly around each entry change, so the cancel can happen twice for one tap (it is idempotent).

#### notifications.dev-test-action

- [ ] `notifications.dev-test-action` — Developer-only "notify now" action
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsSelectionMenu.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `notifications.dev-test-action#1` — The habit-list selection action mode contains a menu item R.id.action_notify whose visibility equals preferences.isDeveloper (key "pref_developer", default false).
2. `notifications.dev-test-action#2` — Tapping it calls notificationTray.show(h, getToday(), 0) for every selected habit — i.e. date = today, reminderTime = 0.
3. `notifications.dev-test-action#3` — Because reminderTime is 0, the resulting notification's setWhen is the Unix epoch.
4. `notifications.dev-test-action#4` — The same gating hides the item completely for non-developer users.

#### reminders.exact-alarm-scheduling

- [ ] `reminders.exact-alarm-scheduling` — Exact alarm scheduling and its refusal cases
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentScheduler.kt`, `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateFormats.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/intents/IntentSchedulerTest.kt`
- **Notes:** Exact-alarm permission, setExactAndAllowWhileIdle and doze-bypass have no Flutter-portable equivalent; a port needs flutter_local_notifications with exact schedule mode plus its own permission flow, and the IGNORED-on-no-permission behaviour must be replicated (silently no alarm). (Merged duplicate id: `platform-glue.intent-scheduler`.)

1. `reminders.exact-alarm-scheduling#1` — IntentScheduler implements ReminderScheduler.SystemScheduler; SchedulerResult has exactly two values: IGNORED and OK.
2. `reminders.exact-alarm-scheduling#2` — schedule(timestamp, pendingIntent, alarmType) returns SchedulerResult.IGNORED and logs "Ignoring attempt to schedule intent in the past." when timestamp < System.currentTimeMillis(). A timestamp exactly equal to now is accepted.
3. `reminders.exact-alarm-scheduling#3` — On SDK >= 31 (Build.VERSION_CODES.S), if AlarmManager.canScheduleExactAlarms() is false it returns IGNORED and logs "No permission to schedule exact alarms" — no alarm is set and no fallback inexact alarm is used.
4. `reminders.exact-alarm-scheduling#4` — Otherwise it calls AlarmManager.setExactAndAllowWhileIdle(alarmType, timestamp, pendingIntent) and returns OK.
5. `reminders.exact-alarm-scheduling#5` — scheduleShowReminder uses alarm type RTC_WAKEUP (wakes the device).
6. `reminders.exact-alarm-scheduling#6` — scheduleWidgetUpdate uses alarm type RTC (does not wake the device).
7. `reminders.exact-alarm-scheduling#7` — scheduleShowReminder builds the PendingIntent via pendingIntents.showReminder(habit, reminderTime, timestamp) and logs, under tag "ReminderHelper", "Setting alarm (<formatted time>): <first min(5, name.length) characters of habit.name>" using DateFormats.getBackupDateFormat().
8. `reminders.exact-alarm-scheduling#8` — Manifest permissions declared for this: RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, POST_NOTIFICATIONS, VIBRATE.
9. `reminders.exact-alarm-scheduling#9` — Instrumented regression: with system time America/Chicago 2020-06-01 12:30, scheduleShowReminder(1591155900000, habit, 0) returns OK; advancing the clock to 2020-06-02 22:44 leaves ReminderReceiver.lastReceivedIntent null; advancing to 22:46 delivers an intent whose data parses back to the habit's id.
10. `reminders.exact-alarm-scheduling#10` — IntentScheduler is @AppScope, implements ReminderScheduler.SystemScheduler, and holds the AlarmManager obtained from Context.ALARM_SERVICE.
11. `reminders.exact-alarm-scheduling#11` — log(componentName, msg) forwards to Log.d(componentName, msg).
12. `reminders.exact-alarm-scheduling#12` — The formatted time uses the pattern "yyyy-MM-dd HHmmss" in Locale.US and habitNamePrefix is the first min(5, name.length) characters of the habit name.

#### intents.actions-and-extras

- [ ] `intents.actions-and-extras` — Exact intent actions, data URIs and extras
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderReceiver.kt`, `.../receivers/WidgetReceiver.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/PendingIntentFactory.kt`, `.../intents/IntentFactory.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`, `uhabits-android/src/main/AndroidManifest.xml`
- **Kotlin tests:** none — write Dart test from rules

1. `intents.actions-and-extras#1` — ReminderReceiver.ACTION_SHOW_REMINDER = "org.isoron.uhabits.ACTION_SHOW_REMINDER".
2. `intents.actions-and-extras#2` — ReminderReceiver.ACTION_DISMISS_REMINDER = "org.isoron.uhabits.ACTION_DISMISS_REMINDER".
3. `intents.actions-and-extras#3` — ReminderReceiver.ACTION_SNOOZE_REMINDER = "org.isoron.uhabits.ACTION_SNOOZE_REMINDER".
4. `intents.actions-and-extras#4` — WidgetReceiver.ACTION_ADD_REPETITION = "org.isoron.uhabits.ACTION_ADD_REPETITION".
5. `intents.actions-and-extras#5` — WidgetReceiver.ACTION_REMOVE_REPETITION = "org.isoron.uhabits.ACTION_REMOVE_REPETITION".
6. `intents.actions-and-extras#6` — WidgetReceiver.ACTION_TOGGLE_REPETITION = "org.isoron.uhabits.ACTION_TOGGLE_REPETITION".
7. `intents.actions-and-extras#7` — WidgetReceiver.ACTION_UPDATE_WIDGETS_VALUE = "org.isoron.uhabits.ACTION_UPDATE_WIDGETS_VALUE".
8. `intents.actions-and-extras#8` — WidgetReceiver also declares its own constant ACTION_DISMISS_REMINDER with the identical string "org.isoron.uhabits.ACTION_DISMISS_REMINDER"; PendingIntentFactory.dismissNotification actually targets ReminderReceiver but uses WidgetReceiver's copy of the constant — the strings are equal so behaviour is unaffected.
9. `intents.actions-and-extras#9` — ListHabitsActivity.ACTION_EDIT = "org.isoron.uhabits.ACTION_EDIT".
10. `intents.actions-and-extras#10` — The habit is always identified by the intent's data URI "content://org.isoron.uhabits/habit/<id>" (Habit.uriString); receivers resolve it with ContentUris.parseId.
11. `intents.actions-and-extras#11` — The ACTION_SHOW_REMINDER intent carries two long extras: "timestamp" (the local-midnight checkmark timestamp computed by ReminderScheduler) and "reminderTime" (the alarm instant).
12. `intents.actions-and-extras#12` — The ADD/REMOVE/TOGGLE repetition intents carry the long extra "timestamp" = LocalDate.unixTime, and only when a date was supplied.
13. `intents.actions-and-extras#13` — ACTION_EDIT carries long extras "habit" (habit id) and "timestamp" (LocalDate.unixTime) — note the key is "habit", not "habitId".
14. `intents.actions-and-extras#14` — IntentFactory.startEditActivity(context, habit) puts extras "habitId" (Long) and "habitType" (Int); startEditActivity(context, habitType) puts only "habitType".
15. `intents.actions-and-extras#15` — The manifest exports ReminderReceiver with an intent-filter for android.intent.action.BOOT_COMPLETED only.
16. `intents.actions-and-extras#16` — The manifest exports WidgetReceiver with intent-filters for org.isoron.uhabits.ACTION_SET_NUMERICAL_VALUE, ACTION_TOGGLE_REPETITION, ACTION_ADD_REPETITION and ACTION_REMOVE_REPETITION, each with category DEFAULT and data scheme "content", host "org.isoron.uhabits". ACTION_SET_NUMERICAL_VALUE is declared in the manifest but has no matching branch in WidgetReceiver.onReceive (dead filter).

#### intents.pending-intent-request-codes

- [ ] `intents.pending-intent-request-codes` — PendingIntent construction (request codes, flags, templates)
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/intents/PendingIntentFactory.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentFactory.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Request-code collisions are intentional (only one pending add/toggle/remove exists at a time). RemoteViews template+fill-in intents have no Flutter analogue. (Merged duplicate ids: `platform-glue.pending-intent-factory`, `widgets.pending-intents`.)

1. `intents.pending-intent-request-codes#1` — addCheckmark uses getBroadcast request code 1, flags FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT, target WidgetReceiver.
2. `intents.pending-intent-request-codes#2` — dismissNotification uses request code 0, flags FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT, target ReminderReceiver.
3. `intents.pending-intent-request-codes#3` — removeRepetition uses request code 3, flags FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT, target WidgetReceiver.
4. `intents.pending-intent-request-codes#4` — toggleCheckmark uses request code 2, flags FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT, target WidgetReceiver.
5. `intents.pending-intent-request-codes#5` — snoozeNotification uses request code 0, flags FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT, target ReminderReceiver.
6. `intents.pending-intent-request-codes#6` — updateWidgets uses request code 0, flags FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT, target WidgetReceiver, action ACTION_UPDATE_WIDGETS_VALUE, no data.
7. `intents.pending-intent-request-codes#7` — showReminder uses a per-habit request code of ((habit.id % Integer.MAX_VALUE).toInt() + 1), flags FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT — this is what keeps each habit's alarm distinct.
8. `intents.pending-intent-request-codes#8` — showNumberPicker uses the same per-habit request code ((habit.id % Integer.MAX_VALUE).toInt() + 1) but via getActivity.
9. `intents.pending-intent-request-codes#9` — showHabit uses TaskStackBuilder.getPendingIntent(0, FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT).
10. `intents.pending-intent-request-codes#10` — Template PendingIntents used for widget collections (showHabitTemplate request code 0, showNumberPickerTemplate request code 1, toggleCheckmarkTemplate request code 2) use flags = FLAG_MUTABLE on SDK >= 31 and 0 below.
11. `intents.pending-intent-request-codes#11` — Because Android's PendingIntent identity ignores extras, the constant request codes are safe only because the per-habit data URI differs; FLAG_UPDATE_CURRENT then refreshes the "timestamp" extra for a repeat use of the same habit.
12. `intents.pending-intent-request-codes#12` — toggleCheckmark(habit, timestamp) -> broadcast PendingIntent to WidgetReceiver, request code 2, action ACTION_TOGGLE_REPETITION, data = habit.uriString, extra 'timestamp' added only when the argument is non-null; flags FLAG_IMMUTABLE|FLAG_UPDATE_CURRENT.
13. `intents.pending-intent-request-codes#13` — addCheckmark(habit, date) uses request code 1 with action ACTION_ADD_REPETITION; removeRepetition(habit, date) uses request code 3 with action ACTION_REMOVE_REPETITION; both are broadcasts with data = habit.uriString and an optional 'timestamp' extra.
14. `intents.pending-intent-request-codes#14` — showHabit(habit) builds a TaskStackBuilder PendingIntent that adds the ShowHabitActivity intent (data = habit.uriString) with its parent stack, request code 0, flags FLAG_IMMUTABLE|FLAG_UPDATE_CURRENT.
15. `intents.pending-intent-request-codes#15` — showNumberPicker(habit, date) is an activity PendingIntent to ListHabitsActivity with action ACTION_EDIT and extras habit = habit.id, timestamp = date.unixTime, request code ((habit.id % Integer.MAX_VALUE) + 1), flags FLAG_IMMUTABLE|FLAG_UPDATE_CURRENT.
16. `intents.pending-intent-request-codes#16` — Template intents (used only by stack widgets) omit all per-item data: showHabitTemplate() targets ShowHabitActivity with request code 0, showNumberPickerTemplate() targets ListHabitsActivity with ACTION_EDIT and request code 1, toggleCheckmarkTemplate() broadcasts ACTION_TOGGLE_REPETITION to WidgetReceiver with request code 2 — all using getIntentTemplateFlags(), which is FLAG_MUTABLE on API >= 31 and 0 otherwise.
17. `intents.pending-intent-request-codes#17` — Fill-in intents carry only the differentiating data: showHabitFillIn -> data only; toggleCheckmarkFillIn -> data + "timestamp"; showNumberPickerFillIn -> "habit" + "timestamp" extras only (no data).

#### intents.reminder-receiver-dispatch

- [ ] `intents.reminder-receiver-dispatch` — ReminderReceiver dispatch and error handling
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderReceiver.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/intents/IntentSchedulerTest.kt`
- **Notes:** Merged duplicate id: `platform-glue.reminder-receiver`.

1. `intents.reminder-receiver-dispatch#1` — onReceive returns immediately if context is null, intent is null, or intent.action is null.
2. `intents.reminder-receiver-dispatch#2` — The received intent is stored in the static ReminderReceiver.lastReceivedIntent (readable, cleared only by clearLastReceivedIntent()) — used by instrumentation tests.
3. `intents.reminder-receiver-dispatch#3` — The habit is resolved as habits.getById(ContentUris.parseId(intent.data)) when intent.data != null, otherwise null.
4. `intents.reminder-receiver-dispatch#4` — timestamp = intent.getLongExtra("timestamp", getToday().unixTime); reminderTime = intent.getLongExtra("reminderTime", getToday().unixTime). Both default to today's midnight in unix millis.
5. `intents.reminder-receiver-dispatch#5` — ACTION_SHOW_REMINDER: returns silently if habit is null; otherwise calls reminderController.onShowReminder(habit, LocalDate.fromUnixTime(timestamp), reminderTime).
6. `intents.reminder-receiver-dispatch#6` — ACTION_DISMISS_REMINDER: returns silently if habit is null; otherwise calls reminderController.onDismiss(habit).
7. `intents.reminder-receiver-dispatch#7` — ACTION_SNOOZE_REMINDER: returns silently if habit is null; on SDK < 31 calls reminderController.onSnoozePressed(habit, context); on SDK >= 31 only logs a warning.
8. `intents.reminder-receiver-dispatch#8` — Intent.ACTION_BOOT_COMPLETED: calls reminderController.onBootCompleted() (habit is irrelevant).
9. `intents.reminder-receiver-dispatch#9` — Any other action falls through the when with no effect.
10. `intents.reminder-receiver-dispatch#10` — The whole dispatch is wrapped in try/catch(RuntimeException) which logs "could not process intent" and swallows the error — a deleted habit or malformed URI never crashes the app.

#### intents.widget-receiver-dispatch

- [ ] `intents.widget-receiver-dispatch` — WidgetReceiver dispatch (widget taps and notification Yes/No handling)
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/receivers/WidgetReceiver.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehavior.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentParser.kt`, `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/widgets/WidgetUpdater.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehaviorTest.kt`
- **Notes:** Background broadcast delivery while the app is dead has no Flutter equivalent; needs a native receiver or WorkManager/AlarmManager bridge. (Merged duplicate ids: `platform-glue.widget-receiver`, `widgets.receiver-actions`.)

1. `intents.widget-receiver-dispatch#1` — WidgetReceiver stores the received intent in the static WidgetReceiver.lastReceivedIntent, cleared only by clearLastReceivedIntent().
2. `intents.widget-receiver-dispatch#2` — For every action except ACTION_UPDATE_WIDGETS_VALUE it first parses the intent through IntentParser.parseCheckmarkIntent; the comparison used is referential (intent.action !== ACTION_UPDATE_WIDGETS_VALUE).
3. `intents.widget-receiver-dispatch#3` — ACTION_ADD_REPETITION -> WidgetBehavior.onAddRepetition(habit, date) -> cancel notification, then write Entry.YES_MANUAL (2) keeping existing notes.
4. `intents.widget-receiver-dispatch#4` — ACTION_REMOVE_REPETITION -> WidgetBehavior.onRemoveRepetition(habit, date) -> cancel notification, then write Entry.NO (0) keeping existing notes.
5. `intents.widget-receiver-dispatch#5` — ACTION_TOGGLE_REPETITION -> WidgetBehavior.onToggleRepetition(habit, date) -> write Entry.nextToggleValue(current, isSkipEnabled, areQuestionMarksEnabled), then cancel notification. The cycle is YES_AUTO->YES_MANUAL, YES_MANUAL->SKIP if skip enabled else NO, SKIP->NO, NO->UNKNOWN if question marks enabled else YES_MANUAL, UNKNOWN->YES_MANUAL, anything else->YES_MANUAL.
6. `intents.widget-receiver-dispatch#6` — ACTION_UPDATE_WIDGETS_VALUE -> setToday(computeToday(preferences.midnightDelayHours, 0)); widgetUpdater.updateWidgets(); widgetUpdater.scheduleStartDayWidgetUpdate().
7. `intents.widget-receiver-dispatch#7` — The whole dispatch is wrapped in try/catch(RuntimeException) logging "could not process intent", so an invalid or stale intent never crashes.
8. `intents.widget-receiver-dispatch#8` — WidgetReceiver handles four actions, all namespaced 'org.isoron.uhabits.': ACTION_ADD_REPETITION, ACTION_REMOVE_REPETITION, ACTION_TOGGLE_REPETITION and ACTION_UPDATE_WIDGETS_VALUE (ACTION_DISMISS_REMINDER is defined here too but consumed by ReminderReceiver).
9. `intents.widget-receiver-dispatch#9` — IntentParser.parseCheckmarkIntent throws IllegalArgumentException('uri is null') when intent.data is null and IllegalArgumentException('habit not found') when the id in the URI does not resolve.
10. `intents.widget-receiver-dispatch#10` — The date comes from the long extra 'timestamp', defaulting to getToday().unixTime; it is normalised through LocalDate.fromUnixTime and rejected with IllegalArgumentException('timestamp is not valid') if it is negative or in the future.
11. `intents.widget-receiver-dispatch#11` — The receiver stores the last received Intent in a static field (WidgetReceiver.lastReceivedIntent) used by instrumentation tests, with clearLastReceivedIntent() to reset it.
12. `intents.widget-receiver-dispatch#12` — The receiver is exported and declares intent filters (category DEFAULT, scheme 'content', host 'org.isoron.uhabits') for ACTION_SET_NUMERICAL_VALUE, ACTION_TOGGLE_REPETITION, ACTION_ADD_REPETITION and ACTION_REMOVE_REPETITION.
13. `intents.widget-receiver-dispatch#13` — Every receipt logs at INFO: String.format("Received intent: %s", intent.toString()).
14. `intents.widget-receiver-dispatch#14` — ACTION_DISMISS_REMINDER is declared on WidgetReceiver but has no branch in its when-block; dismissal is actually routed to ReminderReceiver.

#### intents.parser-validation

- [x] `intents.parser-validation` — Intent parsing and timestamp validation
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentParser.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Pure logic; the exceptions are caught by the receivers and only logged. (Merged duplicate id: `platform-glue.intent-parser`.)

1. `intents.parser-validation#1` — IntentParser.parseCheckmarkIntent(intent) throws IllegalArgumentException("uri is null") when intent.data is null.
2. `intents.parser-validation#2` — It throws IllegalArgumentException("habit not found") when habits.getById(ContentUris.parseId(uri)) returns null (e.g. the habit was deleted after the notification was posted).
3. `intents.parser-validation#3` — parseDate reads the long extra "timestamp", defaulting to getToday().unixTime, normalizes it with LocalDate.fromUnixTime(t).unixTime (snapping to local midnight), and throws IllegalArgumentException("timestamp is not valid") when the normalized value is < 0 or > today's unixTime.
4. `intents.parser-validation#4` — Consequence: a notification action tapped for a FUTURE date is rejected; one tapped for a past date (e.g. yesterday's notification answered after midnight) is accepted and writes to that past date.
5. `intents.parser-validation#5` — IntentParser.copyIntentData(source, destination) copies source.data to destination.data and puts destination extra "timestamp" = source.getLongExtra("timestamp", getToday().unixTime).
6. `intents.parser-validation#6` — LocalDate.unixTime = 946684800000 + daysSince2000 * 86400000; LocalDate.fromUnixTime(millis) uses floor division: diff = millis - 946684800000; days = diff >= 0 ? diff/86400000 : (diff - 86400000 + 1)/86400000.
7. `intents.parser-validation#7` — IntentParser is @AppScope and takes the HabitList; the result is CheckmarkIntentData(habit, date) with mutable `habit` and `date` fields.

#### reminders.on-show-reminder

- [ ] `reminders.on-show-reminder` — Firing a reminder: show notification and re-arm
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderController.kt`
- **Kotlin tests:** `uhabits-android/src/test/java/org/isoron/uhabits/receivers/ReminderControllerTest.kt`

1. `reminders.on-show-reminder#1` — ReminderController.onShowReminder(habit, date, reminderTime) calls notificationTray.show(habit, date, reminderTime) FIRST and then reminderScheduler.scheduleAll().
2. `reminders.on-show-reminder#2` — The scheduleAll() call is what arms tomorrow's alarm — the app never uses repeating alarms; every firing re-arms the next one.
3. `reminders.on-show-reminder#3` — Because scheduleAll() re-reads the snooze preference, a snooze that has just expired is cleaned up at this point.
4. `reminders.on-show-reminder#4` — Verified by ReminderControllerTest.testOnShowReminder: controller.onShowReminder(habit, LocalDate(2015,1,25), 456) results in notificationTray.show(habit, date, 456) and reminderScheduler.scheduleAll().

#### reminders.boot-reschedule

- [ ] `reminders.boot-reschedule` — Rescheduling reminders after reboot
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderReceiver.kt`, `.../receivers/ReminderController.kt`, `uhabits-android/src/main/AndroidManifest.xml`
- **Kotlin tests:** `uhabits-android/src/test/java/org/isoron/uhabits/receivers/ReminderControllerTest.kt`
- **Notes:** Flutter needs a native boot receiver (or flutter_local_notifications' rescheduleAfterReboot) to reproduce this.

1. `reminders.boot-reschedule#1` — ReminderReceiver is registered in the manifest with android:exported="true" and an intent-filter for android.intent.action.BOOT_COMPLETED; the app declares android.permission.RECEIVE_BOOT_COMPLETED.
2. `reminders.boot-reschedule#2` — On receiving BOOT_COMPLETED the receiver logs "onBootCompleted" and calls ReminderController.onBootCompleted().
3. `reminders.boot-reschedule#3` — ReminderController.onBootCompleted() does exactly one thing: reminderScheduler.scheduleAll().
4. `reminders.boot-reschedule#4` — Because snooze times are persisted, a habit snoozed before the reboot keeps its snooze after the reboot as long as the snoozed-until instant is still in the future.
5. `reminders.boot-reschedule#5` — Verified by ReminderControllerTest.testOnBootCompleted.

#### reminders.app-start-and-permission

- [ ] `reminders.app-start-and-permission` — Rescheduling at app start and POST_NOTIFICATIONS permission flow
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `reminders.app-start-and-permission#1` — HabitsApplication.onCreate, after initializing the database, calls setToday(computeToday(preferences.midnightDelayHours, 0)), recomputes every habit, starts the widget updater (startListening + scheduleStartDayWidgetUpdate), calls reminderScheduler.startListening(), notificationTray.startListening(), and then on the task runner calls reminderScheduler.scheduleAll() followed by widgetUpdater.updateWidgets().
2. `reminders.app-start-and-permission#2` — ListHabitsActivity.onResume calls midnightTimer.onResume() and then, only if appComponent.reminderScheduler.hasHabitsWithReminders() is true, handles notification permission.
3. `reminders.app-start-and-permission#3` — On SDK < 33 (TIRAMISU) it immediately calls reminderScheduler.scheduleAll().
4. `reminders.app-start-and-permission#4` — On SDK >= 33, if POST_NOTIFICATIONS is already granted it calls scheduleAll(); otherwise it launches the permission request exactly once per activity instance, guarded by a `permissionAlreadyRequested` flag whose purpose is explicitly to avoid an infinite onResume loop when the user denies.
5. `reminders.app-start-and-permission#5` — If the permission result is granted, scheduleAll() runs; if denied it only logs "POST_NOTIFICATIONS denied" and no alarms are (re)scheduled from this path.
6. `reminders.app-start-and-permission#6` — If the user has zero habits with reminders, no permission is ever requested.
7. `reminders.app-start-and-permission#7` — ListHabitsActivity.onPause calls midnightTimer.onPause().

#### time.midnight-timer

- [x] `time.midnight-timer` — MidnightTimer day-rollover scheduler
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/utils/MidnightTimer.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateUtils.kt`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/utils/MidnightTimerTest.kt`
- **Notes:** A Dart Timer-based port must reproduce the fixed-rate period of exactly one day and the +1s offset; note the fixed-rate schedule means DST shifts are NOT compensated between firings.

1. `time.midnight-timer#1` — MidnightTimer.onResume(delayOffsetInMillis = DateUtils.SECOND_LENGTH = 1000, testExecutor = null) creates a single-threaded ScheduledExecutorService (or uses the injected one) and schedules notifyListeners at fixed rate with initialDelay = DateUtils.millisecondsUntilTomorrowWithOffset(preferences.midnightDelayHours, 0) + delayOffsetInMillis and period = DateUtils.DAY_LENGTH (86400000 ms).
2. `time.midnight-timer#2` — The default 1000 ms offset exists so the callback fires just AFTER midnight, never a millisecond before.
3. `time.midnight-timer#3` — onPause() calls executor.shutdownNow() and returns the list of pending Runnables. `executor` is a lateinit field, so calling onPause() before any onResume() throws UninitializedPropertyAccessException.
4. `time.midnight-timer#4` — notifyListeners() first calls setToday(computeToday(preferences.midnightDelayHours, 0)) and only then invokes atMidnight() on every registered listener, in registration order.
5. `time.midnight-timer#5` — addListener / removeListener / onPause / onResume / notifyListeners are all synchronized on the timer instance.
6. `time.midnight-timer#6` — MidnightListener is a fun interface with the single method atMidnight().
7. `time.midnight-timer#7` — Regression test: with fixed timezone GMT and fixed local time 2017-01-01 23:59:59.999, onResume(1, executor) causes the listener to fire.

#### time.midnight-listeners

- [ ] `time.midnight-listeners` — What happens at midnight in the UI
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HeaderView.kt`, `.../views/HabitCardListAdapter.kt`, `.../ListHabitsActivity.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `time.midnight-listeners#1` — Registered MidnightListeners are HeaderView and HabitCardListAdapter, both registered while attached and removed on detach.
2. `time.midnight-listeners#2` — HeaderView.atMidnight() posts invalidate() to the view, redrawing the weekday header for the new day.
3. `time.midnight-listeners#3` — HabitCardListAdapter.atMidnight() calls cache.refreshAllHabits(), reloading every habit card.
4. `time.midnight-listeners#4` — HabitCardListAdapter registers in onAttached() and unregisters in onDetached(); HeaderView registers in onAttachedToWindow() and unregisters in onDetachedFromWindow().
5. `time.midnight-listeners#5` — MidnightTimer itself is started/stopped by ListHabitsActivity's onResume/onPause, so the rollover only fires while the habit list is in the foreground.

#### reminders.edit-ui

- [ ] `reminders.edit-ui` — Setting a habit's reminder in the edit screen
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/WeekdayPickerDialog.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DateExtensions.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/steps/EditHabitSteps.kt`

1. `reminders.edit-ui#1` — EditHabitActivity holds reminderHour, reminderMin (both -1 meaning 'no reminder') and reminderDays (default WeekdayList.EVERY_DAY).
2. `reminders.edit-ui#2` — When editing an existing habit, these are seeded from habit.reminder if non-null; otherwise they stay at -1/-1/EVERY_DAY.
3. `reminders.edit-ui#3` — Tapping the reminder time row opens a radial TimePickerDialog pre-set to reminderHour if >= 0 else 8, and reminderMin if >= 0 else 0 — i.e. the default suggested reminder time is 08:00.
4. `reminders.edit-ui#4` — The picker uses 24-hour mode iff DateFormat.is24HourFormat(context) and is tinted with the habit's colour.
5. `reminders.edit-ui#5` — onTimeSet stores the picked hour/minute. onTimeCleared resets reminderHour = -1, reminderMin = -1 AND reminderDays = WeekdayList.EVERY_DAY.
6. `reminders.edit-ui#6` — When reminderHour < 0, the time row shows the string reminder_off (English "Off") and both the weekday row and its divider are hidden (View.GONE).
7. `reminders.edit-ui#7` — When reminderHour >= 0, the time row shows formatTime(context, hour, minute) and the weekday row is visible showing reminderDays.toFormattedString(context).
8. `reminders.edit-ui#8` — Tapping the weekday row opens WeekdayPickerDialog (title "Select days") with multi-choice items = long weekday names starting at Saturday, pre-checked from the current WeekdayList. Confirming builds WeekdayList(selectedDays); if the resulting list isEmpty it is silently replaced by WeekdayList.EVERY_DAY.
9. `reminders.edit-ui#9` — On save: if reminderHour >= 0 then habit.reminder = Reminder(reminderHour, reminderMin, reminderDays), else habit.reminder = null.
10. `reminders.edit-ui#10` — Instance state persists "reminderHour" (Int), "reminderMin" (Int) and "reminderDays" (Int, the packed WeekdayList) across rotation.
11. `reminders.edit-ui#11` — formatTime(context, hours, minutes) formats (hours*60 + minutes)*60000 milliseconds as a Date using DateFormat.getTimeFormat(context) with the formatter's timezone forced to UTC, so the rendered time is exactly the wall-clock hour:minute in the user's 12/24-hour preference.

#### reminders.weekday-label

- [ ] `reminders.weekday-label` — Human-readable weekday summary
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/DateExtensions.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/JavaDates.kt`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/DatesTest.kt`, `uhabits-core/src/jvmTest/java/org/isoron/platform/time/JavaLocalDateFormatterTest.kt`
- **Notes:** The Saturday-anchored index base is easy to get wrong in a port. (Merged duplicate id: `platform-glue.weekday-formatting`.)

1. `reminders.weekday-label#1` — WeekdayList.toFormattedString(context) builds a label from the 7-element array, where index 0 is Saturday through index 6 Friday (names come from JavaLocalDateFormatter with firstWeekday = SATURDAY).
2. `reminders.weekday-label#2` — If exactly one day is selected, the LONG name of that day is returned (e.g. "Wednesday").
3. `reminders.weekday-label#3` — If exactly two days are selected and they are indices 0 and 1 (Saturday and Sunday), the string weekends is returned (English "Weekends").
4. `reminders.weekday-label#4` — If exactly five days are selected and indices 0 and 1 are both false (Monday..Friday), the string any_weekday is returned (English "Monday to Friday").
5. `reminders.weekday-label#5` — If all seven days are selected, the string any_day is returned (English "Any day of the week").
6. `reminders.weekday-label#6` — Otherwise the SHORT day names of the selected days are joined with ", " in index order starting at Saturday.
7. `reminders.weekday-label#7` — getWeekdaySequence(SATURDAY) yields [SATURDAY, SUNDAY, MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY] via allDays[(firstWeekday.daysSinceSunday + offset) % 7].
8. `reminders.weekday-label#8` — The formatter builds short and long weekday names from JavaLocalDateFormatter(Locale.getDefault()) anchored at DayOfWeek.SATURDAY, so array index 0 corresponds to Saturday and index 6 to Friday.
9. `reminders.weekday-label#9` — It iterates i in 0..6 over the boolean array; selected days are appended as short names joined by ", " (comma + space), the first without a separator.

#### reminders.show-habit-subtitle

- [ ] `reminders.show-habit-subtitle` — Reminder shown on the habit detail screen
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/SubtitleCardView.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/show/views/SubtitleCardViewTest.kt`

1. `reminders.show-habit-subtitle#1` — SubtitleCardView renders a reminder row; when state.reminder is non-null the label is formatTime(context, reminder.hour, reminder.minute); when it is null the label is the string reminder_off (English "Off").
2. `reminders.show-habit-subtitle#2` — The reminder icon uses the FontAwesome typeface.

#### reminders.dependency-wiring

- [ ] `reminders.dependency-wiring` — Object graph and lifecycle of the reminder subsystem
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/inject/HabitsApplicationComponent.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReceiverScope.kt`, `.../receivers/WidgetReceiver.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/CoroutineTaskRunner.kt`, `.../tasks/Task.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `reminders.dependency-wiring#1` — ReminderScheduler is an @AppScope singleton constructed as ReminderScheduler(commandRunner, habitList, sys = IntentScheduler, widgetPreferences).
2. `reminders.dependency-wiring#2` — NotificationTray is an @AppScope singleton constructed as NotificationTray(taskRunner, commandRunner, preferences, systemTray = AndroidNotificationTray).
3. `reminders.dependency-wiring#3` — ReminderController is an @AppScope singleton constructed as ReminderController(reminderScheduler, notificationTray, preferences); it is the only entry point used by ReminderReceiver and SnoozeDelayPickerActivity.
4. `reminders.dependency-wiring#4` — MidnightTimer is an @AppScope singleton constructed as MidnightTimer(logging, preferences).
5. `reminders.dependency-wiring#5` — IntentScheduler and PendingIntentFactory and IntentParser are @AppScope singletons; IntentParser depends only on HabitList.
6. `reminders.dependency-wiring#6` — ReceiverScope is a plain @Scope annotation; WidgetComponent is a @ReceiverScope @Component created fresh per WidgetReceiver.onReceive from the application component.
7. `reminders.dependency-wiring#7` — The ShowNotificationTask runs doInBackground on the IO dispatcher and onPostExecute on the main dispatcher via CoroutineTaskRunner; onPreExecute/onProgressUpdate are unused for notifications.

## Domain: Charts, canvas abstraction and theming

#### charts-canvas-theming.canvas-api

- [x] `charts-canvas-theming.canvas-api` — Canvas drawing API surface
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/Canvas.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/CanvasTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/platform/gui/AndroidCanvasTest.kt`
- **Notes:** This is the single API every chart draws through; port it as a thin Dart wrapper over dart:ui Canvas so all core chart code stays platform-independent. drawTestImage is the canary golden used by both CanvasTest.png baselines (1000x800 px = 500x400 logical at pixelScale 2).

1. `charts-canvas-theming.canvas-api#1` — The Canvas abstraction declares exactly these members, all coordinates/sizes as Double in logical (density-independent) units: setColor(Color), drawLine(x1,y1,x2,y2), drawText(text,x,y), fillRect(x,y,width,height), fillRoundRect(x,y,width,height,cornerRadius), drawRect(x,y,width,height), getHeight(), getWidth(), setFont(Font), setFontSize(size), setStrokeWidth(size), fillArc(centerX,centerY,radius,startAngle,swipeAngle), fillCircle(centerX,centerY,radius), setTextAlign(TextAlign), toImage(), measureText(text).
2. `charts-canvas-theming.canvas-api#2` — Canvas.fill() is a default method implemented exactly as fillRect(0.0, 0.0, getWidth(), getHeight()) using the currently set color.
3. `charts-canvas-theming.canvas-api#3` — enum TextAlign has exactly 3 values in ordinal order: LEFT(0), CENTER(1), RIGHT(2).
4. `charts-canvas-theming.canvas-api#4` — enum Font has exactly 3 values in ordinal order: REGULAR(0), BOLD(1), FONT_AWESOME(2).
5. `charts-canvas-theming.canvas-api#5` — data class ScreenLocation has two Double fields, x and y, in that order.
6. `charts-canvas-theming.canvas-api#6` — drawText(text, x, y) anchors the text so that its vertical visual centre sits at y (never the baseline) and its horizontal placement follows the currently set TextAlign: LEFT means x is the left edge, CENTER means x is the horizontal centre, RIGHT means x is the right edge.
7. `charts-canvas-theming.canvas-api#7` — fillArc angles are in degrees; startAngle=90 corresponds to the 12 o'clock direction and a negative swipeAngle sweeps clockwise; the filled shape is a pie sector that includes the centre point (useCenter=true), not a stroked ring.
8. `charts-canvas-theming.canvas-api#8` — fillRect is filled (no stroke) and drawRect is stroked with the current stroke width (no fill); calling drawRect must not leave the backend in FILL mode for the next fillRect.
9. `charts-canvas-theming.canvas-api#9` — setColor applies to both shapes and text; there is no separate text colour setter.
10. `charts-canvas-theming.canvas-api#10` — measureText returns the advance width of the string in logical units under the currently set font and font size.
11. `charts-canvas-theming.canvas-api#11` — drawTestImage() draws, in this exact order: (1) fillRect(0,0,500,400) with Color(0.1,0.1,0.1,0.5); (2) setColor(Color(0x606060)), setStrokeWidth(25.0), drawRect(100,100,300,200); (3) setColor(Color.YELLOW), setStrokeWidth(1.0), then drawRect(0,0,100,100) + fillCircle(50,50,30), drawRect(0,100,100,100) + fillArc(50,150,30,90,135), drawRect(0,200,100,100) + fillArc(50,250,30,90,-135), drawRect(0,300,100,100) + fillArc(50,350,30,45,90); (4) setColor(Color.RED), setStrokeWidth(2.0), drawLine(0,0,500,400) and drawLine(500,0,0,400); (5) setFont(BOLD), setFontSize(50.0), setColor(Color.GREEN), then drawText("HELLO",250,100) with CENTER, drawText("HELLO",250,150) with RIGHT, drawText("HELLO",250,200) with LEFT; (6) setFont(FONT_AWESOME), drawText(FontAwesome.CHECK, 250, 300).
12. `charts-canvas-theming.canvas-api#12` — Backends must keep the current colour, font, font size, stroke width and text alignment as sticky state across calls; nothing resets them between draw operations.

#### charts-canvas-theming.color-model

- [x] `charts-canvas-theming.color-model` — Color value type and colour math
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/Color.kt`, `uhabits-android/src/main/java/org/isoron/platform/gui/AndroidImage.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** contrast() is used by HistoryChart to pick day-number text colour, so its exact formula is user-visible.

1. `charts-canvas-theming.color-model#1` — Color is an immutable data class of four Doubles in 0.0..1.0 named red, green, blue, alpha, in that constructor order; equality is componentwise on all four.
2. `charts-canvas-theming.color-model#2` — The Int constructor Color(rgb) sets red=((rgb shr 16) and 0xFF)/255.0, green=((rgb shr 8) and 0xFF)/255.0, blue=(rgb and 0xFF)/255.0 and alpha=1.0; the top byte of rgb is ignored, so Color(0xFF0000) equals Color(1.0, 0.0, 0.0, 1.0).
3. `charts-canvas-theming.color-model#3` — luminosity == 0.21*red + 0.72*green + 0.07*blue (no gamma correction, no alpha term).
4. `charts-canvas-theming.color-model#4` — blendWith(other, weight) returns componentwise this*(1-weight) + other*weight for red, green, blue AND alpha; weight is not clamped.
5. `charts-canvas-theming.color-model#5` — contrast(other) computes r = (this.luminosity + 0.05) / (other.luminosity + 0.05) and returns r when r >= 1, otherwise 1/r, so the result is always >= 1 and symmetric.
6. `charts-canvas-theming.color-model#6` — withAlpha(a) returns a Color with the same rgb and alpha=a.
7. `charts-canvas-theming.color-model#7` — Companion constants are exactly: TRANSPARENT=(0,0,0,0), RED=(1,0,0,1), GREEN=(0,1,0,1), BLUE=(1,0,1,1), YELLOW=(1,1,0,1), MAGENTA=(1,0,1,1), CYAN=(0,1,1,1), WHITE=(1,1,1,1), BLACK=(0,0,0,1). Note that BLUE is defined as (1,0,1,1) and is therefore identical to MAGENTA; this existing defect must be preserved for pixel-identical goldens (Canvas.drawTestImage does not use BLUE, but any port that 'fixes' it changes nothing visible today).
8. `charts-canvas-theming.color-model#8` — Converting a Color to a 32-bit ARGB int uses roundToInt on each channel: argb(round(255*alpha), round(255*red), round(255*green), round(255*blue)).

#### charts-canvas-theming.image-and-golden-diff

- [ ] `charts-canvas-theming.image-and-golden-diff` — Image abstraction and screenshot diffing
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/Image.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/gui/JavaImage.kt`, `uhabits-android/src/main/java/org/isoron/platform/gui/AndroidImage.kt`, `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/ViewTestHelper.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseViewTest.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/ViewTestHelper.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseViewTest.kt`
- **Notes:** AndroidImage.export() is TODO("Not yet implemented") and throws if called. The Flutter port should reimplement this tolerant diff so the existing PNG baselines remain usable as golden files.

1. `charts-canvas-theming.image-and-golden-diff#1` — Image exposes width:Int, height:Int, getPixel(x,y):Color, setPixel(x,y,Color) and suspend export(path:String).
2. `charts-canvas-theming.image-and-golden-diff#2` — Image.diff(other) throws/errors when width != other.width with message "Width must match: <w> !== <ow>" and when height != other.height with message "Height must match: <h> !== <oh>".
3. `charts-canvas-theming.image-and-golden-diff#3` — Image.diff(other) mutates the receiver: for every pixel (x,y) it starts with l = 1.0, then for every dx in -2..2 and dy in -2..2 whose (x+dx, y+dy) is inside the image it sets l = min(l, abs(this.getPixel(x,y).luminosity - other.getPixel(x+dx,y+dy).luminosity)); finally it writes setPixel(x, y, Color(l, l, l, 1.0)). The 5x5 min-window deliberately tolerates up to 2px of sub-pixel shift.
4. `charts-canvas-theming.image-and-golden-diff#4` — Image.averageLuminosity == sum of luminosity of every pixel divided by (width * height).
5. `charts-canvas-theming.image-and-golden-diff#5` — assertRenders(path, canvas) in the core test helper: renders canvas.toImage(), loads the expected PNG from the test resource path, builds a diff image, computes distance = diffImage.averageLuminosity * 100 and fails with "Images differ (distance=$distance)" when distance >= 1.0; on failure it exports /tmp/failed/<path>, /tmp/failed/<path w/ .expected.png> and /tmp/failed/<path w/ .diff.png>.
6. `charts-canvas-theming.image-and-golden-diff#6` — When the expected PNG is missing, assertRenders exports the actual image to /tmp/failed/<path> and fails with "Expected image file is missing. Actual image: <path>".
7. `charts-canvas-theming.image-and-golden-diff#7` — assertRenders(width, height, expectedPath, view) creates a test canvas of the given logical width/height, calls view.draw(canvas) once, then delegates to assertRenders(expectedPath, canvas).
8. `charts-canvas-theming.image-and-golden-diff#8` — The Android screenshot comparator (BaseViewTest) uses a different metric: it samples roughly 1 in 4 pixels at random, sums abs ARGB channel differences, divides by 255*16*width*height and fails when the value exceeds similarityCutoff, whose default is 0.00018 (AndroidCanvasTest raises it to 0.0005); mismatched dimensions score a distance of 1.0.

#### charts-canvas-theming.view-interfaces

- [x] `charts-canvas-theming.view-interfaces` — View and DataView contracts
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/View.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/views/HistoryChartTest.kt`

1. `charts-canvas-theming.view-interfaces#1` — interface View declares draw(canvas: Canvas) plus onClick(x: Double, y: Double) and onLongClick(x: Double, y: Double), both of which default to doing nothing.
2. `charts-canvas-theming.view-interfaces#2` — interface DataView extends View and adds a mutable `var dataOffset: Int` and a read-only `val dataColumnWidth: Double` expressed in logical units.
3. `charts-canvas-theming.view-interfaces#3` — dataOffset counts whole data columns scrolled back into the past; 0 always means 'the newest column is flush against the right edge of the chart'. Larger values scroll into older data. Negative values are never produced by the host (they are clamped to 0).
4. `charts-canvas-theming.view-interfaces#4` — Click coordinates handed to onClick/onLongClick are in the same logical unit system as draw(), i.e. already divided by device pixel density.
5. `charts-canvas-theming.view-interfaces#5` — Charts must tolerate onClick being called before draw(); HistoryChart specifically throws IllegalStateException("onClick must be called after draw(canvas)") when its cached width is still <= 0.0.

#### charts-canvas-theming.fontawesome-glyphs

- [ ] `charts-canvas-theming.fontawesome-glyphs` — FontAwesome glyph set and font loading
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/FontAwesome.kt`, `uhabits-android/src/main/res/values/fontawesome.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/InterfaceUtils.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/gui/JavaCanvas.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/CanvasTest.kt`
- **Notes:** Flutter port must ship FontAwesome.ttf plus NotoSans Regular/Bold as bundled font assets and register them under stable family names; glyphs are addressed by raw code point, not by icon name.

1. `charts-canvas-theming.fontawesome-glyphs#1` — The core FontAwesome constants are exactly two: CHECK = "" and TIMES = "".
2. `charts-canvas-theming.fontawesome-glyphs#2` — The Android string resources add the rest of the glyph vocabulary used across the UI: fa_check = U+F00C, fa_times = U+F00D, fa_skipped = U+F068 (minus), fa_question = U+F128, fa_star_half_o = U+F5C0, fa_arrow_circle_up = U+F0AA, fa_arrow_circle_down = U+F0AB, fa_bell_o = U+F0F3, fa_calendar = U+F073, fa_exclamation_circle = U+F06A, fa_umbrella_beach = U+F5CA.
3. `charts-canvas-theming.fontawesome-glyphs#3` — Font.FONT_AWESOME resolves to uhabits-android/src/main/assets/fontawesome-webfont.ttf on Android (loaded lazily and cached in a single process-wide Typeface) and to uhabits-core/assets/main/fonts/FontAwesome.ttf in the core/JVM renderer.
4. `charts-canvas-theming.fontawesome-glyphs#4` — Font.REGULAR and Font.BOLD resolve to Typeface.DEFAULT and Typeface.DEFAULT_BOLD on Android, but to uhabits-core/assets/main/fonts/NotoSans-Regular.ttf and NotoSans-Bold.ttf in the core/JVM renderer; the two backends therefore intentionally produce different text metrics and separate golden baselines.
5. `charts-canvas-theming.fontawesome-glyphs#5` — The Android test APK ships its own copy of the icon font at uhabits-android/src/androidTest/assets/fontawesome-webfont.ttf.
6. `charts-canvas-theming.fontawesome-glyphs#6` — A FontAwesome glyph is always drawn through the normal drawText path, so it obeys the current setTextAlign and is vertically centred on the given y like any other text.

#### charts-canvas-theming.android-canvas-impl

- [ ] `charts-canvas-theming.android-canvas-impl` — AndroidCanvas backend semantics
- **Platform:** needs-native-per-platform · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/platform/gui/AndroidCanvas.kt`, `.../AndroidImage.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/platform/gui/AndroidCanvasTest.kt`
- **Notes:** The 0.6*mHeight text-centring hack and the density-scaled units are the two things a Flutter Canvas port must replicate to keep existing screenshots matching.

1. `charts-canvas-theming.android-canvas-impl#1` — AndroidCanvas holds innerCanvas (android.graphics.Canvas), optional innerBitmap, innerDensity (Double, default 1.0), innerWidth, innerHeight (Int pixels) and mHeight (Int, initial value 15).
2. `charts-canvas-theming.android-canvas-impl#2` — Every logical coordinate is converted to device pixels as (value * innerDensity).toFloat(); getWidth() returns innerWidth / innerDensity and getHeight() returns innerHeight / innerDensity.
3. `charts-canvas-theming.android-canvas-impl#3` — measureText(text) returns textPaint.measureText(text) / innerDensity.
4. `charts-canvas-theming.android-canvas-impl#4` — setFont and setFontSize both recompute mHeight as the pixel height of the tight bounds of the single character "m" under the current text paint.
5. `charts-canvas-theming.android-canvas-impl#5` — drawText(text, x, y) draws at device y = (y * innerDensity) + 0.6f * mHeight — i.e. the vertical centring is approximated by shifting the baseline down by 60% of the 'm' height, not by using font ascent/descent.
6. `charts-canvas-theming.android-canvas-impl#6` — setColor sets the colour on both the shape Paint and the TextPaint.
7. `charts-canvas-theming.android-canvas-impl#7` — fillRect and fillRoundRect and fillCircle and fillArc set Paint.Style.FILL before drawing; drawRect sets Paint.Style.STROKE.
8. `charts-canvas-theming.android-canvas-impl#8` — fillRoundRect uses the same radius for x and y: drawRoundRect(x, y, x+width, y+height, cornerRadius, cornerRadius).
9. `charts-canvas-theming.android-canvas-impl#9` — fillArc maps to drawArc(centerX-radius, centerY-radius, centerX+radius, centerY+radius, -startAngle, -swipeAngle, useCenter=true): both angles are negated because Android measures 0 degrees at 3 o'clock and grows clockwise.
10. `charts-canvas-theming.android-canvas-impl#10` — setStrokeWidth(size) sets paint.strokeWidth = size * innerDensity; it does not affect the text paint.
11. `charts-canvas-theming.android-canvas-impl#11` — Both paints are created with isAntiAlias = true, and the TextPaint starts with Paint.Align.CENTER.
12. `charts-canvas-theming.android-canvas-impl#12` — toImage() returns an AndroidImage wrapping innerBitmap and throws UnsupportedOperationException when innerBitmap is null (which is the case for on-screen views).
13. `charts-canvas-theming.android-canvas-impl#13` — setTextAlign maps LEFT->Paint.Align.LEFT, CENTER->Paint.Align.CENTER, RIGHT->Paint.Align.RIGHT.

#### charts-canvas-theming.jvm-canvas-impl

- [ ] `charts-canvas-theming.jvm-canvas-impl` — JavaCanvas golden renderer
- **Platform:** needs-native-per-platform · **Port risk:** medium
- **Source:** `uhabits-core/src/jvmMain/java/org/isoron/platform/gui/JavaCanvas.kt`, `uhabits-core/src/jvmTest/java/org/isoron/platform/io/TestPlatformHelper.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/CanvasTest.kt`, `.../ui/views/BarChartTest.kt`, `.../ui/views/HistoryChartTest.kt`
- **Notes:** This is the backend that produced every PNG under uhabits-core/assets/test/views. A Flutter golden harness should mirror the pixelScale=2 convention.

1. `charts-canvas-theming.jvm-canvas-impl#1` — JavaCanvas(image: BufferedImage, pixelScale: Double = 2.0) renders into an AWT BufferedImage; toPixel(x) = (pixelScale * x).toInt() (truncation, not rounding) and toDp(px) = px / pixelScale.
2. `charts-canvas-theming.jvm-canvas-impl#2` — Test canvases are created as JavaCanvas(BufferedImage(2*width, 2*height, TYPE_INT_ARGB), 2.0), so every core golden PNG is exactly twice the logical size in each dimension.
3. `charts-canvas-theming.jvm-canvas-impl#3` — Rendering hints are fixed to ANTIALIASING=ON, TEXT_ANTIALIASING=ON and FRACTIONALMETRICS=ON.
4. `charts-canvas-theming.jvm-canvas-impl#4` — Fonts: REGULAR = fonts/NotoSans-Regular.ttf, BOLD = fonts/NotoSans-Bold.ttf, FONT_AWESOME = fonts/FontAwesome.ttf, each derived to (fontSize * pixelScale) points; the default fontSize before any setFontSize call is 12.0 and the default Font is REGULAR.
5. `charts-canvas-theming.jvm-canvas-impl#5` — drawText computes the string bounds via FontRenderContext(null, true, true) and places the string at: CENTER -> (toPixel(x) - bx - bWidth/2, toPixel(y) - by - bHeight/2); LEFT -> (toPixel(x) - bx, toPixel(y) - by - bHeight/2); RIGHT -> (toPixel(x) - bx - bWidth, toPixel(y) - by - bHeight/2), where bx/by/bWidth/bHeight are the rounded bounds x/y/width/height.
6. `charts-canvas-theming.jvm-canvas-impl#6` — The default textAlign before any setTextAlign call is CENTER.
7. `charts-canvas-theming.jvm-canvas-impl#7` — setStrokeWidth(size) sets a BasicStroke of (size * pixelScale).
8. `charts-canvas-theming.jvm-canvas-impl#8` — fillArc maps directly to Graphics2D.fillArc with startAngle.roundToInt() and swipeAngle.roundToInt() (Java2D already uses 0 degrees at 3 o'clock growing counter-clockwise, which matches the abstraction's convention without negation).
9. `charts-canvas-theming.jvm-canvas-impl#9` — measureText uses FontMetrics.stringWidth(text) / pixelScale, which returns integer pixel widths — subtly different from the AWT bounds used by drawText.
10. `charts-canvas-theming.jvm-canvas-impl#10` — Missing font files raise RuntimeException("File not found: <path>").

#### charts-canvas-theming.js-canvas-impl

- [ ] `charts-canvas-theming.js-canvas-impl` — JsCanvas backend semantics
- **Platform:** needs-native-per-platform · **Port risk:** low
- **Source:** `uhabits-core/src/jsMain/kotlin/org/isoron/platform/gui/JsCanvas.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Useful as a second reference implementation showing which parts of the Canvas contract are genuinely backend-agnostic.

1. `charts-canvas-theming.js-canvas-impl#1` — JsCanvas.create(width, height, pixelScale = 2.0) allocates an HTMLCanvasElement of (width*pixelScale) by (height*pixelScale) rounded to Int.
2. `charts-canvas-theming.js-canvas-impl#2` — setColor emits a single css string "rgba(r,g,b,a)" with r/g/b as roundToInt(channel*255) and a as the raw 0..1 alpha, and assigns it to both fillStyle and strokeStyle.
3. `charts-canvas-theming.js-canvas-impl#3` — drawText measures the string, then places it at x = px for LEFT, px - textWidth/2 for CENTER, px - textWidth for RIGHT, and at y = py + (actualBoundingBoxAscent - actualBoundingBoxDescent)/2 — a true optical vertical centring.
4. `charts-canvas-theming.js-canvas-impl#4` — setFont/setFontSize build the css font string "<weight> <round(fontSize*pixelScale)>px <family>" where family is NotoSans / NotoSansBold / FontAwesome and weight is "bold" only for Font.BOLD.
5. `charts-canvas-theming.js-canvas-impl#5` — fillArc converts to radians as start = -startAngle*PI/180 and end = -(startAngle+swipeAngle)*PI/180, draws moveTo(centre) then arc(...) with anticlockwise = (swipeAngle > 0), then closePath and fill — producing the same pie sector as the other backends.
6. `charts-canvas-theming.js-canvas-impl#6` — fillRoundRect is built from four arcTo calls starting at (x+cornerRadius, y).
7. `charts-canvas-theming.js-canvas-impl#7` — setStrokeWidth sets ctx.lineWidth = size * pixelScale (no rounding).
8. `charts-canvas-theming.js-canvas-impl#8` — toImage() copies the canvas into a fresh HTMLCanvasElement of the same size rather than aliasing the live canvas.

#### charts-canvas-theming.android-view-host

- [ ] `charts-canvas-theming.android-view-host` — AndroidView chart host
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/platform/gui/AndroidView.kt`, `.../AndroidTestView.kt`, `uhabits-android/src/main/res/layout/canvas_test.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** In Flutter this becomes a CustomPaint/CustomPainter pair; there is no direct equivalent of the re-seeded mutable canvas object.

1. `charts-canvas-theming.android-view-host#1` — AndroidView<T : View> is an android.view.View that owns a single reusable AndroidCanvas instance and a nullable `view: T?`.
2. `charts-canvas-theming.android-view-host#2` — On every onDraw it re-seeds the shared AndroidCanvas with context, the incoming android.graphics.Canvas, the view's current width and height in pixels, and resources.displayMetrics.density as innerDensity, then calls view?.draw(canvas). When view is null nothing is drawn.
3. `charts-canvas-theming.android-view-host#3` — Because the AndroidCanvas is shared and re-seeded per frame, chart state must be recomputed inside draw(); nothing is cached between frames by the host.
4. `charts-canvas-theming.android-view-host#4` — AndroidTestView is a variant that ignores `view` entirely and always calls canvas.drawTestImage(); it does not set innerWidth/innerHeight, so getWidth()/getHeight() return 0.0 inside the test image.

#### charts-canvas-theming.dataview-scrolling

- [ ] `charts-canvas-theming.dataview-scrolling` — AndroidDataView horizontal scrolling and paging
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/platform/gui/AndroidDataView.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Hosts BarChart and HistoryChart (show-habit cards, history widget and the history editor dialog). Flutter needs a custom gesture + physics simulation to reproduce the 'velocity/2' fling and the integer bucket snapping.

1. `charts-canvas-theming.dataview-scrolling#1` — AndroidDataView extends AndroidView<DataView> and wires a GestureDetector, an android.widget.Scroller(context, null, true) and a ValueAnimator.ofFloat(0f,1f).
2. `charts-canvas-theming.dataview-scrolling#2` — onDown returns true so every gesture stream is consumed; onTouchEvent delegates entirely to the GestureDetector.
3. `charts-canvas-theming.dataview-scrolling#3` — onScroll requests the parent to disallow touch interception (requestDisallowInterceptTouchEvent(true)) only when abs(dx) > abs(dy), then calls scroller.startScroll(currX, currY, -dx.toInt(), dy.toInt(), 0), computeScrollOffset() and updateDataOffset(); it returns true. Note dx is negated (dragging right shows older data) while dy is passed through unnegated.
4. `charts-canvas-theming.dataview-scrolling#4` — onFling calls scroller.fling(currX, currY, velocityX.toInt()/2, 0, 0, Integer.MAX_VALUE, 0, 0), invalidates, sets the animator duration to scroller.duration and starts it, and then returns false.
5. `charts-canvas-theming.dataview-scrolling#5` — During the fling animation, each animator update calls scroller.computeScrollOffset() + updateDataOffset() while the scroller is unfinished, and cancels the animator as soon as scroller.isFinished.
6. `charts-canvas-theming.dataview-scrolling#6` — updateDataOffset computes newDataOffset = scroller.currX / (view.dataColumnWidth * canvas.innerDensity).toInt() — integer division by the column width in device pixels — then clamps with max(0, ...) so the chart can never scroll into the future; it only assigns and calls postInvalidate() when the value actually changed.
7. `charts-canvas-theming.dataview-scrolling#7` — resetDataOffset() sets scroller.finalX = 0, calls computeScrollOffset() and updateDataOffset(), snapping the chart back to today.
8. `charts-canvas-theming.dataview-scrolling#8` — onSingleTapUp forwards to view.onClick(x / innerDensity, y / innerDensity) and onLongPress forwards to view.onLongClick with the same conversion; both read the pointer via e.getPointerId(0) and, if any RuntimeException is thrown while reading coordinates, silently return false without dispatching.
9. `charts-canvas-theming.dataview-scrolling#9` — There is no upper bound on dataOffset in AndroidDataView (unlike ScrollableChart), so scrolling into empty history is allowed and charts must render empty/default squares for out-of-range indices.

#### charts-canvas-theming.theme-tokens

- [x] `charts-canvas-theming.theme-tokens` — Theme colour and size tokens
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Themes.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/views/BarChartTest.kt`, `.../HistoryChartTest.kt`

1. `charts-canvas-theming.theme-tokens#1` — The abstract Theme base class defines these open colour tokens (all opaque, given as 0xRRGGBB): appBackgroundColor=0xF4F4F4, cardBackgroundColor=0xFAFAFA, headerBackgroundColor=0xEEEEEE, headerBorderColor=0xCCCCCC, headerTextColor=0x9E9E9E, highContrastTextColor=0x202020, itemBackgroundColor=0xFFFFFF, lowContrastTextColor=0xE0E0E0, mediumContrastTextColor=0x9E9E9E, statusBarBackgroundColor=0x333333, toolbarBackgroundColor=0xF4F4F4, toolbarColor=0xFFFFFF.
2. `charts-canvas-theming.theme-tokens#2` — The Theme base class defines three non-overridable size tokens: checkmarkButtonSize = 48.0, smallTextSize = 10.0, regularTextSize = 17.0 — all in logical units, and all independent of the theme variant.
3. `charts-canvas-theming.theme-tokens#3` — Theme.color(paletteColor: PaletteColor) is a final helper that delegates to the open color(paletteIndex: Int).
4. `charts-canvas-theming.theme-tokens#4` — LightTheme is an empty subclass of Theme and therefore uses every base value unchanged.

#### charts-canvas-theming.theme-palette

- [x] `charts-canvas-theming.theme-palette` — 20-colour habit palette per theme
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Themes.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/PaletteColor.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/PaletteUtils.kt`, `uhabits-android/src/main/res/values/colors.xml`, `uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/Color.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** There are FOUR near-duplicate copies of this palette (Theme light, Theme dark, WidgetTheme, PaletteColor/PaletteUtils, plus the Android lightPalette/darkPalette/transparentWidgetPalette arrays). The Flutter port should keep all variants distinct rather than unifying them, or colours will shift in the widgets and CSV export. (Merged duplicate id: `settings.theme.theme-palettes`.)

1. `charts-canvas-theming.theme-palette#1` — Theme.color(paletteIndex) for the light palette returns, for indices 0..19 in order: 0xD32F2F, 0xE64A19, 0xF57C00, 0xFF8F00, 0xF9A825, 0xAFB42B, 0x7CB342, 0x388E3C, 0x00897B, 0x00ACC1, 0x039BE5, 0x1976D2, 0x303F9F, 0x5E35B1, 0x8E24AA, 0xD81B60, 0x5D4037, 0x424242, 0x757575, 0x9E9E9E; any other index returns 0x000000.
2. `charts-canvas-theming.theme-palette#2` — DarkTheme.color(paletteIndex) returns, for 0..19: 0xEF9A9A, 0xFFAB91, 0xFFCC80, 0xFFECB3, 0xFFF59D, 0xE6EE9C, 0xC5E1A5, 0x69F0AE, 0x80CBC4, 0x80DEEA, 0x81D4FA, 0x64B5F6, 0x9FA8DA, 0xB39DDB, 0xCE93D8, 0xF48FB1, 0xBCAAA4, 0xF5F5F5, 0xE0E0E0, 0x9E9E9E; any other index returns 0xFFFFFF.
3. `charts-canvas-theming.theme-palette#3` — WidgetTheme.color(paletteIndex) equals the light palette except index 12, which is 0x6275F0 instead of 0x303F9F, and index 17, which is 0x757575 instead of 0x424242; out-of-range returns 0x000000.
4. `charts-canvas-theming.theme-palette#4` — PaletteColor.toCsvColor() returns the hex strings "#D32F2F", "#E64A19", "#F57C00", "#FF8F00", "#F9A825", "#AFB42B", "#7CB342", "#388E3C", "#00897B", "#00ACC1", "#039BE5", "#1976D2", "#303F9F", "#5E35B1", "#8E24AA", "#D81B60", "#5D4037", "#303030", "#757575", "#aaaaaa" — note indices 17 and 19 differ from Theme's light palette (0x303030 vs 0x424242 and 0xAAAAAA vs 0x9E9E9E), and out-of-range indices throw ArrayIndexOutOfBoundsException.
5. `charts-canvas-theming.theme-palette#5` — PaletteUtils.getAndroidTestColor(index) / PaletteColor.toFixedAndroidColor() use the same 20 hex strings as toCsvColor(), i.e. the CSV variant with 0x303030 at 17 and 0xAAAAAA at 19; this array is what Android screenshot tests colour habits with.
6. `charts-canvas-theming.theme-palette#6` — The default habit colour used when nothing else is specified is palette index 8 (teal, 0x00897B in light).
7. `charts-canvas-theming.theme-palette#7` — Theme (light base) values: appBackgroundColor 0xf4f4f4, cardBackgroundColor 0xFAFAFA, headerBackgroundColor 0xeeeeee, headerBorderColor 0xcccccc, headerTextColor 0x9E9E9E, highContrastTextColor 0x202020, itemBackgroundColor 0xffffff, lowContrastTextColor 0xe0e0e0, mediumContrastTextColor 0x9E9E9E, statusBarBackgroundColor 0x333333, toolbarBackgroundColor 0xf4f4f4, toolbarColor 0xffffff.
8. `charts-canvas-theming.theme-palette#8` — Theme sizing constants: checkmarkButtonSize = 48.0, smallTextSize = 10.0, regularTextSize = 17.0.
9. `charts-canvas-theming.theme-palette#9` — LightTheme is an unmodified subclass of Theme.
10. `charts-canvas-theming.theme-palette#10` — DarkTheme overrides: appBackgroundColor 0x212121, cardBackgroundColor 0x303030, headerBackgroundColor 0x212121, highContrastTextColor 0xF5F5F5, lowContrastTextColor 0x424242. It re-declares headerBorderColor 0xcccccc, headerTextColor 0x9E9E9E, itemBackgroundColor 0xffffff, mediumContrastTextColor 0x9E9E9E, statusBarBackgroundColor 0x333333, toolbarBackgroundColor 0xf4f4f4 and toolbarColor 0xffffff with the SAME values as the light theme.
11. `charts-canvas-theming.theme-palette#11` — Theme.color(paletteColor: PaletteColor) delegates to color(paletteColor.paletteIndex).
12. `charts-canvas-theming.theme-palette#12` — WidgetTheme extends LightTheme and overrides cardBackgroundColor = Color.TRANSPARENT, highContrastTextColor = Color.WHITE, mediumContrastTextColor = white with alpha 0.50, lowContrastTextColor = white with alpha 0.10.
13. `charts-canvas-theming.theme-palette#13` — Color(rgb: Int) decomposes as red = ((rgb shr 16) and 0xFF)/255.0, green = ((rgb shr 8) and 0xFF)/255.0, blue = (rgb and 0xFF)/255.0, alpha = 1.0.
14. `charts-canvas-theming.theme-palette#14` — Color.luminosity = 0.21*red + 0.72*green + 0.07*blue.
15. `charts-canvas-theming.theme-palette#15` — Color.contrast(other) = max(r, 1/r) where r = (this.luminosity + 0.05) / (other.luminosity + 0.05).
16. `charts-canvas-theming.theme-palette#16` — Color.blendWith(other, weight) linearly interpolates each of red, green, blue and alpha as component*(1-weight) + otherComponent*weight.

#### charts-canvas-theming.theme-variants

- [x] `charts-canvas-theming.theme-variants` — Dark, PureBlack and Widget theme variants
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Themes.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/views/BarChartTest.kt`, `.../HistoryChartTest.kt`
- **Notes:** Goldens exist for all three variants of BarChart and HistoryChart: base.png (light), themeDark.png, themeWidget.png.

1. `charts-canvas-theming.theme-variants#1` — DarkTheme overrides: appBackgroundColor=0x212121, cardBackgroundColor=0x303030, headerBackgroundColor=0x212121, headerBorderColor=0xCCCCCC, headerTextColor=0x9E9E9E, highContrastTextColor=0xF5F5F5, itemBackgroundColor=0xFFFFFF, lowContrastTextColor=0x424242, mediumContrastTextColor=0x9E9E9E, statusBarBackgroundColor=0x333333, toolbarBackgroundColor=0xF4F4F4, toolbarColor=0xFFFFFF, plus the dark palette.
2. `charts-canvas-theming.theme-variants#2` — PureBlackTheme extends DarkTheme and overrides only three tokens: appBackgroundColor=0x000000, cardBackgroundColor=0x000000, lowContrastTextColor=0x212121. Everything else, including the palette, is inherited from DarkTheme.
3. `charts-canvas-theming.theme-variants#3` — WidgetTheme extends LightTheme and overrides: cardBackgroundColor = Color.TRANSPARENT, highContrastTextColor = Color.WHITE, mediumContrastTextColor = Color.WHITE.withAlpha(0.50), lowContrastTextColor = Color.WHITE.withAlpha(0.10), plus its own palette.
4. `charts-canvas-theming.theme-variants#4` — WidgetTheme.cardBackgroundColor being exactly Color.TRANSPARENT is load-bearing: HistoryChart branches on `theme.cardBackgroundColor == Color.TRANSPARENT` to switch day-number text to highContrastTextColor instead of running the contrast comparison, and BarChart's background fill becomes a no-op.
5. `charts-canvas-theming.theme-variants#5` — LightTheme, DarkTheme and WidgetTheme are `open` classes; PureBlackTheme is final.

#### charts-canvas-theming.android-contrast-attrs

- [ ] `charts-canvas-theming.android-contrast-attrs` — Android styled-resource contrast tokens
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/res/values/attrs.xml`, `.../values/styles.xml`, `.../values/dimens.xml`, `.../values/material_colors.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/StyledResources.kt`, `.../utils/InterfaceUtils.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** The Flutter port needs a single ThemeData-like object exposing contrast0..contrast100 plus cardBg, because the two colour systems (core Theme vs Android attrs) currently disagree slightly (e.g. lowContrastTextColor 0xE0E0E0 vs contrast40 #D8D8D8).

1. `charts-canvas-theming.android-contrast-attrs#1` — The legacy Android charts (ScoreChart, FrequencyChart, StreakChart, TargetChart, RingView, HeaderView, CheckmarkButtonView, NumberButtonView) read colours from theme attributes rather than from the core Theme object; the attribute set is contrast0, contrast20, contrast40, contrast60, contrast80, contrast100, plus cardBgColor, headerBackgroundColor, windowBackgroundColor, highlightedBackgroundColor and palette.
2. `charts-canvas-theming.android-contrast-attrs#2` — Light theme (AppBaseTheme) maps: contrast0=#FFFFFF, contrast20=#E0E0E0, contrast40=#D8D8D8, contrast60=#9E9E9E, contrast80=#616161, contrast100=#424242, cardBgColor=#FAFAFA, headerBackgroundColor=#EEEEEE, windowBackgroundColor=#EEEEEE, highlightedBackgroundColor=#F5F5F5, palette=lightPalette, useHabitColorAsPrimary=true.
3. `charts-canvas-theming.android-contrast-attrs#3` — Dark theme (AppBaseThemeDark) maps: contrast0=#212121, contrast20=#424242, contrast40=#525252, contrast60=#9E9E9E, contrast80=#E0E0E0, contrast100=#F5F5F5, cardBgColor=#303030, headerBackgroundColor=#212121, windowBackgroundColor=#212121, highlightedBackgroundColor=#424242, palette=darkPalette, useHabitColorAsPrimary=false.
4. `charts-canvas-theming.android-contrast-attrs#4` — Pure-black theme (AppBaseThemeDark.PureBlack) maps: contrast0=#000000, contrast20=#212121, contrast40=#424242, contrast60=#9E9E9E, contrast80=#BDBDBD, contrast100=#EEEEEE, cardBgColor=#000000, headerBackgroundColor=#000000, highlightedBackgroundColor=#000000, windowBackgroundColor=#000000.
5. `charts-canvas-theming.android-contrast-attrs#5` — Widget theme (style WidgetTheme, parent AppBaseThemeDark) maps: cardBgColor=#303030, contrast0=#FFFFFF, contrast20=#0FFFFFFF (white at ~6% alpha), contrast60=#AFFFFFFF (white at ~69% alpha), contrast80=#424242, contrast100=#FFFFFF, palette=transparentWidgetPalette, widgetShadowAlpha=0.
6. `charts-canvas-theming.android-contrast-attrs#6` — Dimension tokens used by the Android charts: baseSize=20dp, checkmarkWidth=48dp, checkmarkHeight=48dp, regularTextSize=16sp, smallTextSize=14sp, smallerTextSize=12sp, tinyTextSize=10sp, habitNameWidth=160dp, history_editor_max_height=350dp.
7. `charts-canvas-theming.android-contrast-attrs#7` — StyledResources supports a process-wide fixed theme override (setFixedTheme) used by instrumentation tests so that screenshots are deterministic, and InterfaceUtils supports a fixed-resolution override (setFixedResolution) that replaces dp/sp conversion with a plain multiply and rescales getDimension by (dim / actualDensity * fixedResolution).
8. `charts-canvas-theming.android-contrast-attrs#8` — StyledResources.getPalette() reads the int-array pointed at by the `palette` attribute and throws RuntimeException("palette resource not found") when the attribute resolves to a resource id < 0.

#### charts-canvas-theming.barchart

- [ ] `charts-canvas-theming.barchart` — BarChart (show-habit bar/history card)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/BarChart.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/BarCardView.kt`, `uhabits-android/src/main/res/layout/show_habit_bar.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/views/BarChartTest.kt`
- **Notes:** Goldens: uhabits-core/assets/test/views/BarChart/{base,offset,themeDark,themeWidget}.png, all 600x400 px = 300x200 logical. Test fixture: today=2015-01-25, axis = 101 descending days, one series of 11 values, colour index 8, offset case uses dataOffset=5. The host card is 220dp tall.

1. `charts-canvas-theming.barchart#1` — BarChart(theme, dateFormatter) is a DataView with mutable state: series: MutableList<List<Double>> (default empty), colors: MutableList<Color> (default empty), axis: List<LocalDate> (default empty), dataOffset (default 0).
2. `charts-canvas-theming.barchart#2` — Style defaults, all in logical units: paddingTop=20.0, paddingLeft=0.0, paddingRight=0.0, footerHeight=40.0, barGroupMargin=4.0, barMargin=3.0, barWidth=12.0, nGridlines=6.
3. `charts-canvas-theming.barchart#3` — dataColumnWidth == barWidth + 2*barMargin == 18.0 with the defaults.
4. `charts-canvas-theming.barchart#4` — barGroupWidth = 2*barGroupMargin + nSeries*(barWidth + 2*barMargin); with one series and the defaults that is 8 + 18 = 26.0.
5. `charts-canvas-theming.barchart#5` — safeWidth = canvasWidth - paddingLeft - paddingRight; nColumns = floor(safeWidth / barGroupWidth).toInt(); marginLeft = (safeWidth - nColumns*barGroupWidth) / 2 (the leftover is split evenly so the grid is centred).
6. `charts-canvas-theming.barchart#6` — maxBarHeight = canvasHeight - footerHeight - paddingTop.
7. `charts-canvas-theming.barchart#7` — maxValue = max over every series of that series' maximum element, then floored at 1.0 via max(maxValue, 1.0). Drawing with an empty `series` list, or with any series that is an empty list, throws a NullPointerException from maxOrNull()!!.
8. `charts-canvas-theming.barchart#8` — draw() first fills the whole canvas with theme.cardBackgroundColor, then draws the major grid, then every series in index order, then the axis labels — in that order, so labels sit on top.
9. `charts-canvas-theming.barchart#9` — barGroupOffset(c) = marginLeft + paddingLeft + c*barGroupWidth; barOffset(c, s) = barGroupOffset(c) + barGroupMargin + s*(barWidth + 2*barMargin) + barMargin.
10. `charts-canvas-theming.barchart#10` — Column c (0 = leftmost) maps to data index dataColumn = nColumns - c - 1 + dataOffset, so the newest datum is always at the right edge and increasing dataOffset scrolls into the past. Indices < 0 or >= series[s].size are treated as value 0.0.
11. `charts-canvas-theming.barchart#11` — A bar with value <= 0 is skipped entirely: no rectangle and no value label are drawn.
12. `charts-canvas-theming.barchart#12` — Bar geometry: perc = value/maxValue, barHeight = round(maxBarHeight * perc), x = barOffset(c,s), y = canvasHeight - footerHeight - barHeight, r = round(barWidth * 0.15) (= 2.0 with the default barWidth of 12).
13. `charts-canvas-theming.barchart#13` — When 2*r < barHeight the bar is drawn with rounded top corners as four primitives: fillRect(x, y+r, barWidth, barHeight-r), fillRect(x+r, y, barWidth-2*r, r+1), fillCircle(x+r, y+r, r), fillCircle(x+barWidth-r, y+r, r). Otherwise it is a single fillRect(x, y, barWidth, barHeight).
14. `charts-canvas-theming.barchart#14` — Each drawn bar gets a value label in colors[s], centred, at fontSize theme.smallTextSize (10.0), positioned at (x + barWidth/2, y - theme.smallTextSize*0.80); the label text is value.toShortString().
15. `charts-canvas-theming.barchart#15` — Major grid: strokeWidth is set to 1.0 first; when nSeries > 1 a vertical separator in theme.lowContrastTextColor.withAlpha(0.5) is drawn at barGroupOffset(c) for every c in 0 until nColumns-1, spanning y from paddingTop to paddingTop+maxBarHeight. Then for k in 1 until nGridlines a full-width horizontal line in theme.lowContrastTextColor with strokeWidth 0.5 is drawn at y = paddingTop + maxBarHeight * (1 - k/(nGridlines-1)); with nGridlines=6 that is y-fractions 0.8, 0.6, 0.4, 0.2 and 0.0 of maxBarHeight below paddingTop.
16. `charts-canvas-theming.barchart#16` — Axis: a full-width baseline in theme.lowContrastTextColor is drawn at y = paddingTop + maxBarHeight (inheriting strokeWidth 0.5 from the gridline loop), then labels are drawn in theme.mediumContrastTextColor, centred, at fontSize theme.smallTextSize.
17. `charts-canvas-theming.barchart#17` — isLargeInterval == (axis.size < 2) || (axis[0].daysUntil(axis[1]) > 300), where daysUntil(other) == other.daysSince2000 - this.daysSince2000. Because the presenter supplies axis newest-first, this difference is normally negative and isLargeInterval is effectively only true for an axis with fewer than 2 entries — preserve the expression verbatim.
18. `charts-canvas-theming.barchart#18` — When isLargeInterval, each column prints only date.year at (barGroupOffset(c) + barGroupWidth/2, axisY + theme.smallTextSize*1.0).
19. `charts-canvas-theming.barchart#19` — When not isLargeInterval, each column prints dateFormatter.shortMonthName(date) if date.month differs from the previous drawn column's month, otherwise date.day, at y = axisY + theme.smallTextSize*1.0; and additionally prints date.year at y = axisY + theme.smallTextSize*2.3 whenever date.year differs from the previous drawn column's year.
20. `charts-canvas-theming.barchart#20` — prevMonth and prevYear start at -1 for every draw, so the leftmost drawn column always prints both a month name and a year. Columns are iterated left to right while data runs newest-on-the-right, so 'previous' means the older neighbour.
21. `charts-canvas-theming.barchart#21` — Columns whose dataColumn falls outside axis indices are skipped for labelling (continue) but their bars are still drawn as value 0 (i.e. skipped).
22. `charts-canvas-theming.barchart#22` — The Android host wires it as: series = [entries.map { it.value / 1000.0 }], colors = [theme.color(state.color.paletteIndex)], axis = entries.map { it.date }, and calls resetDataOffset() every time the state changes.

#### charts-canvas-theming.historychart-layout

- [x] `charts-canvas-theming.historychart-layout` — HistoryChart calendar layout and rendering
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HistoryChart.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/HistoryCardView.kt`, `uhabits-android/src/main/res/layout/show_habit_history.xml`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/views/HistoryChartTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/show/views/HistoryCardViewTest.kt`
- **Notes:** Goldens: uhabits-core/assets/test/views/HistoryChart/{base,scroll,small,themeDark,themeWidget,weekday}.png. base/scroll/themeDark/themeWidget/weekday are 800x400 px = 400x200 logical; small.png is 400x400 px = 200x200 logical. Fixture: today=2015-01-25, palette index 7, 85 squares, notesIndicators = index % 3 == 0, scroll.png uses dataOffset=2, weekday.png uses firstWeekday=MONDAY.

1. `charts-canvas-theming.historychart-layout#1` — HistoryChart is a DataView constructed with dateFormatter, firstWeekday, paletteColor, series: List<Square>, defaultSquare: Square, notesIndicators: List<Boolean>, theme, today, onDateClickedListener (default no-op) and padding (default 0.0).
2. `charts-canvas-theming.historychart-layout#2` — enum HistoryChart.Square has exactly five values in ordinal order: ON, OFF, GREY, DIMMED, HATCHED.
3. `charts-canvas-theming.historychart-layout#3` — draw() caches width and height from the canvas, fills the whole canvas with theme.cardBackgroundColor, then computes squareSize = round((height - 2*padding) / 8.0) — the grid is always one header row plus seven weekday rows.
4. `charts-canvas-theming.historychart-layout#4` — The font size for the whole chart is set once as min(14.0, height * 0.06).
5. `charts-canvas-theming.historychart-layout#5` — weekdayColumnWidth = maximum over all seven DayOfWeek values of (canvas.measureText(dateFormatter.shortWeekdayName(weekday)) + squareSize*0.15), or 0.0 when the list is somehow empty.
6. `charts-canvas-theming.historychart-layout#6` — nColumns = floor((width - 2*padding - weekdayColumnWidth) / squareSize).toInt(); the weekday-name gutter is reserved on the RIGHT edge.
7. `charts-canvas-theming.historychart-layout#7` — firstWeekdayOffset = (today.dayOfWeek.daysSinceSunday - firstWeekday.daysSinceSunday + 7) % 7, where DayOfWeek.daysSinceSunday is SUNDAY=0 through SATURDAY=6.
8. `charts-canvas-theming.historychart-layout#8` — topLeftOffset = (nColumns - 1 + dataOffset) * 7 + firstWeekdayOffset and topLeftDate = today.minus(topLeftOffset); increasing dataOffset by 1 shifts the whole calendar exactly one week (7 days) into the past.
9. `charts-canvas-theming.historychart-layout#9` — Columns are drawn left to right for column in 0 until nColumns, with topOffset = topLeftOffset - 7*column and topDate = topLeftDate.plus(7*column).
10. `charts-canvas-theming.historychart-layout#10` — Within a column, rows 0..6 map to offset = topOffset - row and date = topDate.plus(row); as soon as offset < 0 the whole remaining column is abandoned (return), so future days after today are simply not drawn.
11. `charts-canvas-theming.historychart-layout#11` — A square is drawn at x = padding + column*squareSize, y = padding + (row+1)*squareSize with width = height = squareSize - squareSpacing, using fillRoundRect with cornerRadius = width*0.15.
12. `charts-canvas-theming.historychart-layout#12` — The square's state is series[offset] when offset < series.size and defaultSquare otherwise; notes indicator is notesIndicators[offset] when offset < notesIndicators.size and false otherwise. Index 0 is always today.
13. `charts-canvas-theming.historychart-layout#13` — Square colours: ON -> theme.color(paletteColor.paletteIndex); OFF -> theme.lowContrastTextColor; GREY -> theme.mediumContrastTextColor; DIMMED and HATCHED -> theme.color(paletteIndex).blendWith(theme.cardBackgroundColor, 0.5).
14. `charts-canvas-theming.historychart-layout#14` — A HATCHED square is additionally overdrawn with diagonal hatching in theme.cardBackgroundColor at strokeWidth 0.75: starting with k = width/10, repeat five times { drawLine(x+k, y, x, y+k); drawLine(x+width-k, y+height, x+width, y+height-k); k += width/5 }.
15. `charts-canvas-theming.historychart-layout#15` — Day-number text colour: if theme.cardBackgroundColor == Color.TRANSPARENT use theme.highContrastTextColor; otherwise compute c1 = squareColor.contrast(theme.cardBackgroundColor) and c2 = squareColor.contrast(theme.mediumContrastTextColor) and use theme.cardBackgroundColor when c1 > c2, else theme.mediumContrastTextColor.
16. `charts-canvas-theming.historychart-layout#16` — The day number is drawn CENTER-aligned at (x + width/2, y + width/2) — note the vertical position uses width, not height (they are equal for square cells).
17. `charts-canvas-theming.historychart-layout#17` — A notes indicator is a filled circle at (x + width - width/5, y + width/5) with radius width/12, coloured theme.lowContrastTextColor for ON and GREY squares and theme.color(paletteIndex) for OFF, DIMMED and HATCHED.
18. `charts-canvas-theming.historychart-layout#18` — Column headers: for each column the header text is dateFormatter.shortMonthName(topDate) when that differs from the last printed month; otherwise the year string when that differs from the last printed year; otherwise the empty string. It is drawn LEFT-aligned in theme.mediumContrastTextColor at (headerOverflow + padding + column*squareSize, padding + squareSize/2).
19. `charts-canvas-theming.historychart-layout#19` — headerOverflow starts at 0.0 for each draw and after each header is updated as headerOverflow = max(0.0, headerOverflow + measureText(headerText) + 0.1*squareSize - squareSize), which pushes wide month labels rightwards until they fit and prevents them from overlapping.
20. `charts-canvas-theming.historychart-layout#20` — lastPrintedMonth and lastPrintedYear both reset to the empty string at the start of every draw, so the leftmost column always prints its month name.
21. `charts-canvas-theming.historychart-layout#21` — Weekday names are drawn last, in theme.mediumContrastTextColor, LEFT-aligned, one per row: for row in 0..6, text = dateFormatter.shortWeekdayName(topLeftDate.plus(row)) at x = padding + nColumns*squareSize + squareSize*0.15 and y = padding + squareSize*(row+1) + squareSize/2. Deriving the name from topLeftDate makes the labels automatically follow firstWeekday.
22. `charts-canvas-theming.historychart-layout#22` — squareSpacing defaults to 1.0 and dataColumnWidth == squareSpacing + squareSize.

#### charts-canvas-theming.historychart-hittest

- [x] `charts-canvas-theming.historychart-hittest` — HistoryChart date hit-testing (tap and long-press)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HistoryChart.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/views/HistoryChartTest.kt`
- **Notes:** OnDateClickedListener is an interface with two default no-op methods, onDateShortPress(date) and onDateLongPress(date).

1. `charts-canvas-theming.historychart-hittest#1` — onClick(x,y) forwards to the shared hit-test with isLongClick=false and onLongClick(x,y) with isLongClick=true; both use the same geometry.
2. `charts-canvas-theming.historychart-hittest#2` — Hit-testing throws IllegalStateException("onClick must be called after draw(canvas)") when the cached width is still <= 0.0, i.e. when draw() has never run.
3. `charts-canvas-theming.historychart-hittest#3` — col = ((x - padding) / squareSize).toInt() and row = ((y - padding) / squareSize).toInt(), both truncating toward zero.
4. `charts-canvas-theming.historychart-hittest#4` — The tap is ignored (no listener call) when any of these hold: x - padding < 0, row == 0 (the month-header row), row > 7, or col == nColumns (the weekday-name gutter).
5. `charts-canvas-theming.historychart-hittest#5` — The clicked date is topLeftDate.plus(col*7 + (row - 1)); row 1 is the first weekday row.
6. `charts-canvas-theming.historychart-hittest#6` — The tap is ignored when the resulting date isNewerThan(today), i.e. taps on empty future cells do nothing.
7. `charts-canvas-theming.historychart-hittest#7` — A valid short press calls onDateClickedListener.onDateShortPress(date); a valid long press calls onDateLongPress(date). Both default to no-ops when no listener is supplied.
8. `charts-canvas-theming.historychart-hittest#8` — Concretely, for a 400x200 logical chart with today=2015-01-25, firstWeekday=SUNDAY and padding=0: tapping (20,46) or (2,28) both resolve to 2014-10-26; (163,113) resolves to 2014-12-10; (336,37) resolves to 2015-01-25 (today); (160,15) is in the header row and is ignored; (360,60) is in the weekday gutter and is ignored.

#### charts-canvas-theming.checkmark-button-core

- [x] `charts-canvas-theming.checkmark-button-core` — CheckmarkButton core view
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/CheckmarkButton.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Orphan goldens exist at uhabits-core/assets/test/views/CheckmarkButton/{explicit,implicit,unchecked}.png (96x96 px = 48x48 logical, matching theme.checkmarkButtonSize) but no core test currently references them; the live Android implementation is the richer CheckmarkButtonView.

1. `charts-canvas-theming.checkmark-button-core#1` — CheckmarkButton(value: Int, color: Color, theme: Theme) is a stateless View drawn entirely from its constructor arguments.
2. `charts-canvas-theming.checkmark-button-core#2` — draw() sets Font.FONT_AWESOME and font size theme.smallTextSize * 1.5 (= 15.0 with the default theme).
3. `charts-canvas-theming.checkmark-button-core#3` — The colour is `color` when value == 2, and theme.lowContrastTextColor for every other value (including 1 and 3).
4. `charts-canvas-theming.checkmark-button-core#4` — The glyph is FontAwesome.TIMES (U+F00D) when value == 0 and FontAwesome.CHECK (U+F00C) for every other value.
5. `charts-canvas-theming.checkmark-button-core#5` — The glyph is drawn at (canvas.getWidth()/2, canvas.getHeight()/2) using whatever text alignment the canvas currently has — the view never calls setTextAlign, so it relies on the backend default of CENTER.
6. `charts-canvas-theming.checkmark-button-core#6` — The view draws no background: the caller is responsible for clearing/filling behind it.

#### charts-canvas-theming.number-button-core

- [x] `charts-canvas-theming.number-button-core` — NumberButton core view and Double.toShortString
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/NumberButton.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/NumberButtonView.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/NumberButtonViewTest.kt`
- **Notes:** Orphan goldens at uhabits-core/assets/test/views/NumberButton/{render_above,render_below,render_zero}.png (96x96 px = 48x48 logical). toShortString is also used by BarChart labels and TargetChart.

1. `charts-canvas-theming.number-button-core#1` — NumberButton(color, value: Double, threshold: Double, units: String, theme) draws the numeric value above its unit label.
2. `charts-canvas-theming.number-button-core#2` — The active colour is `color` when value >= threshold, theme.mediumContrastTextColor when value >= 0.01 but below threshold, and theme.lowContrastTextColor otherwise (including negative values).
3. `charts-canvas-theming.number-button-core#3` — em is defined as theme.smallTextSize (10.0). The number is drawn with Font.BOLD at font size theme.regularTextSize (17.0) at (width/2, height/2 - 0.6*em); the units are drawn with Font.REGULAR at font size theme.smallTextSize (10.0) at (width/2, height/2 + 0.6*em).
4. `charts-canvas-theming.number-button-core#4` — The number text is value.toShortString(); the unit text is drawn verbatim with no truncation in the core view.
5. `charts-canvas-theming.number-button-core#5` — Double.toShortString() (core, org.isoron.uhabits.core.ui.views) returns, in this exact branch order: v >= 1e9 -> "%.1fG" of v/1e9; v >= 1e8 -> "%.0fM" of v/1e6; v >= 1e7 -> "%.1fM" of v/1e6; v >= 1e6 -> "%.1fM" of v/1e6; v >= 1e5 -> "%.0fk" of v/1e3; v >= 1e4 -> "%.1fk" of v/1e3; v >= 1e3 -> "%.1fk" of v/1e3; v >= 1e2 -> "%.0f" of v; v >= 1e1 -> "%.0f" when round(v) == v else "%.1f"; otherwise "%.0f" when round(v)==v, else "%.1f" when round(v*10) == v*10, else "%.2f".
6. `charts-canvas-theming.number-button-core#6` — Examples that must hold: 0.0 -> "0"; 0.5 -> "0.5"; 0.25 -> "0.25"; 5.0 -> "5"; 12.0 -> "12"; 12.5 -> "12.5"; 123.4 -> "123"; 1500.0 -> "1.5k"; 15000.0 -> "15.0k"; 150000.0 -> "150k"; 1.5e6 -> "1.5M"; 1.5e8 -> "150M"; 1.5e9 -> "1.5G".
7. `charts-canvas-theming.number-button-core#7` — The Android duplicate in org.isoron.uhabits.activities.habits.list.views uses DecimalFormat for the three smallest branches instead of %f: v >= 1e2 -> DecimalFormat("#"), v >= 1e1 -> DecimalFormat("#.#"), else DecimalFormat("#.##"). The two implementations agree on integral values but the Android one strips trailing zeros (e.g. 12.5 -> "12.5", 12.50 -> "12.5", 0.10 -> "0.1").

#### charts-canvas-theming.ring-core

- [x] `charts-canvas-theming.ring-core` — Ring core view (progress ring)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Ring.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Orphan golden at uhabits-core/assets/test/views/Ring/draw1.png (120x120 px = 60x60 logical). The shipping Android implementation is RingView, which differs (precision quantisation, inactive colour, stroked text, FontAwesome option).

1. `charts-canvas-theming.ring-core#1` — Ring(color, percentage: Double, thickness: Double, radius: Double, theme, label: Boolean = false) is a stateless View.
2. `charts-canvas-theming.ring-core#2` — angle = 360.0 * max(0.0, min(360.0, percentage)); for the normal 0..1 percentage domain this is simply 360*percentage, and negative percentages clamp to 0. Preserve the expression verbatim (the min(360.0, ...) clamp is applied to the fraction, not the degrees).
3. `charts-canvas-theming.ring-core#3` — draw() paints exactly four (or five with a label) primitives in this order: fillCircle(width/2, height/2, radius) in theme.lowContrastTextColor; fillArc(width/2, height/2, radius, 90.0, -angle) in `color`; fillCircle(width/2, height/2, radius - thickness) in theme.cardBackgroundColor; and, when label is true, the percentage text.
4. `charts-canvas-theming.ring-core#4` — Because the arc starts at 90 degrees and sweeps by -angle, progress fills clockwise starting from the 12 o'clock position.
5. `charts-canvas-theming.ring-core#5` — The hole is punched by overpainting with theme.cardBackgroundColor, not by clearing; under WidgetTheme, where cardBackgroundColor is fully transparent, the hole is effectively not punched at all under normal source-over compositing.
6. `charts-canvas-theming.ring-core#6` — The label, when enabled, is drawn in `color` at font size radius*0.4, centred at (width/2, height/2), with text format("%.0f%%", percentage * 100) — e.g. 0.6 renders as "60%".
7. `charts-canvas-theming.ring-core#7` — Ring never sets a text alignment, so it depends on the canvas default of CENTER.
8. `charts-canvas-theming.ring-core#8` — The view ignores the canvas aspect ratio: the ring is always centred on the canvas centre with the caller-supplied radius, and can overflow a canvas smaller than 2*radius.

#### charts-canvas-theming.habit-list-header-core

- [x] `charts-canvas-theming.habit-list-header-core` — HabitListHeader core view
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HabitListHeader.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Orphan golden at uhabits-core/assets/test/views/HabitListHeader/light.png (1200x96 px = 600x48 logical). The shipping Android equivalent is HeaderView, which additionally supports scrolling, RTL and reversed checkmark order.

1. `charts-canvas-theming.habit-list-header-core#1` — HabitListHeader(today, nButtons, theme, fmt) draws the weekday/day-number strip above the habit list.
2. `charts-canvas-theming.habit-list-header-core#2` — The whole rect (0,0,width,height) is filled with theme.headerBackgroundColor first.
3. `charts-canvas-theming.habit-list-header-core#3` — A 0.5-wide separator line in theme.headerBorderColor is drawn from (0, height-0.5) to (width, height-0.5) — i.e. hugging the bottom edge.
4. `charts-canvas-theming.habit-list-header-core#4` — Text is drawn in theme.headerTextColor with Font.BOLD at font size theme.smallTextSize (10.0).
5. `charts-canvas-theming.habit-list-header-core#5` — buttonSize == theme.checkmarkButtonSize == 48.0.
6. `charts-canvas-theming.habit-list-header-core#6` — For index in 0 until nButtons the date is today.minus(nButtons - index - 1) and the column centre is x = width - (index+1)*buttonSize + buttonSize/2; therefore index 0 sits flush against the right edge and holds the OLDEST date, while index nButtons-1 sits leftmost and holds today.
7. `charts-canvas-theming.habit-list-header-core#7` — Each column prints two lines centred on x: fmt.shortWeekdayName(date).uppercase() at y = height/2 - theme.smallTextSize*0.6, and date.day.toString() at y = height/2 + theme.smallTextSize*0.6.
8. `charts-canvas-theming.habit-list-header-core#8` — The view never calls setTextAlign, relying on the canvas default of CENTER.

#### charts-canvas-theming.scrollable-chart

- [ ] `charts-canvas-theming.scrollable-chart` — ScrollableChart paging base class (legacy Android charts)
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/ScrollableChart.kt`, `.../views/BundleSavedState.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/common/views/ScoreChartTest.kt`, `.../FrequencyChartTest.kt`
- **Notes:** Two independent scroll implementations coexist (this one for legacy Paint-based charts, AndroidDataView for core Canvas charts). Note direction is applied at fling/scroll time, and HeaderView uses direction -1 (or +1 when the checkmark sequence is reversed, flipped again under RTL) so that the list header scrolls in step with the checkmark panels.

1. `charts-canvas-theming.scrollable-chart#1` — ScrollableChart is the abstract base of ScoreChart, FrequencyChart and HeaderView; it exposes a read-only dataOffset (private setter) that starts at 0.
2. `charts-canvas-theming.scrollable-chart#2` — Defaults: scrollerBucketSize = 1, direction = 1, maxDataOffset = 12 * 200 = 2400.
3. `charts-canvas-theming.scrollable-chart#3` — maxX == maxDataOffset * scrollerBucketSize.
4. `charts-canvas-theming.scrollable-chart#4` — onScroll returns false immediately when scrollerBucketSize == 0. Otherwise it requests parent touch-interception disallow when abs(dx) > abs(dy), computes dx = min(dx * -direction, maxX - scroller.currX), calls scroller.startScroll(currX, currY, dx.toInt(), dy.toInt(), 0) with zero duration, computeScrollOffset() and updateDataOffset(), and returns true.
5. `charts-canvas-theming.scrollable-chart#5` — onFling calls scroller.fling(currX, currY, direction*velocityX.toInt()/2, 0, 0, maxX, 0, 0), invalidates, sets the ValueAnimator duration to scroller.duration and starts it, and returns false.
6. `charts-canvas-theming.scrollable-chart#6` — Each animator tick calls scroller.computeScrollOffset() + updateDataOffset() while the scroller is unfinished and cancels the animator once it is finished.
7. `charts-canvas-theming.scrollable-chart#7` — updateDataOffset computes newDataOffset = scroller.currX / scrollerBucketSize (integer division), clamps to max(0, ...) then min(maxDataOffset, ...), and only when the value changed assigns it, calls scrollController.onDataOffsetChanged(newDataOffset) and postInvalidate().
8. `charts-canvas-theming.scrollable-chart#8` — setScrollDirection(direction) throws IllegalArgumentException unless direction is exactly 1 or -1.
9. `charts-canvas-theming.scrollable-chart#9` — setMaxDataOffset(v) sets maxDataOffset, clamps the current dataOffset to min(dataOffset, v), notifies the ScrollController and calls postInvalidate().
10. `charts-canvas-theming.scrollable-chart#10` — reset() sets scroller.finalX = 0, calls computeScrollOffset() and updateDataOffset(), snapping back to the newest data.
11. `charts-canvas-theming.scrollable-chart#11` — Instance state is saved as a BundleSavedState containing ints under the keys "x" (scroller.currX), "y" (scroller.currY), "dataOffset", "direction" and "maxDataOffset"; restoring replays scroller.startScroll(0, 0, x, y, 0) then computeScrollOffset(). A non-BundleSavedState parcelable is passed straight through to super.
12. `charts-canvas-theming.scrollable-chart#12` — onDown returns true, onSingleTapUp returns false, onShowPress and onLongPress are no-ops, and onTouchEvent delegates entirely to the GestureDetector.
13. `charts-canvas-theming.scrollable-chart#13` — ScrollController is an interface with a single default no-op method onDataOffsetChanged(newDataOffset: Int); the default instance installed at construction does nothing.

#### charts-canvas-theming.score-chart

- [ ] `charts-canvas-theming.score-chart` — ScoreChart (strength line chart)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/ScoreChart.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/ScoreCard.kt`, `uhabits-android/src/main/res/layout/show_habit_score.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/common/views/ScoreChartTest.kt`, `.../habits/show/views/ScoreCardViewTest.kt`
- **Notes:** Goldens: uhabits-android/src/androidTest/assets/views/common/ScoreChart/{render,renderDataOffset,renderDifferentSize,renderMonthly,renderTransparent,renderYearly}.png. Test view is 300x200dp (600x400px at density 2), the different-size case 200x200dp; renderDataOffset scrolls by -150dp. The show-habit card is 220dp tall.

1. `charts-canvas-theming.score-chart#1` — ScoreChart is a ScrollableChart drawing a line of score markers with a 5-row percentage grid and a date footer.
2. `charts-canvas-theming.score-chart#2` — onSizeChanged: a height < 9 px is replaced by 200; pText.textSize = min(height * 0.06f, tinyTextSize (10sp)); em = pText.fontSpacing; footerHeight = (3*em).toInt(); internalPaddingTop = em.toInt(); baseSize = (height - footerHeight - internalPaddingTop) / 8.
3. `charts-canvas-theming.score-chart#3` — columnWidth starts at baseSize, is raised to max(columnWidth, maxDayWidth*1.5f) and then to max(columnWidth, maxMonthWidth*1.2f); nColumns = (width / columnWidth).toInt(); columnWidth is then reset to width / nColumns so columns exactly tile the view; setScrollerBucketSize(columnWidth.toInt()).
4. `charts-canvas-theming.score-chart#4` — maxDayWidth and maxMonthWidth are computed identically (both loop months 1..12 of 2020 and measure dateFormatter.shortMonthName) — the day-width getter never measures a day number; keep the resulting sizing behaviour.
5. `charts-canvas-theming.score-chart#5` — columnHeight = 8 * baseSize; pGraph.textSize = baseSize*0.5f; pGraph.strokeWidth = baseSize*0.1f; pGrid.strokeWidth = min(dpToPixels(1f), baseSize*0.05f).
6. `charts-canvas-theming.score-chart#6` — onDraw returns without drawing anything when scores is null (the default before setScores).
7. `charts-canvas-theming.score-chart#7` — Grid: 5 rows over the chart rect; for i in 0..4 it draws the LEFT-aligned label String.format("%d%%", 100 - i*100/5) — i.e. "100%", "80%", "60%", "40%", "20%" — at (left + 0.5*em, top + 1*em), draws a horizontal line at the row top, then offsets down by height/5; after the loop one final horizontal line is drawn at the bottom.
8. `charts-canvas-theming.score-chart#8` — Data: for k in 0 until nColumns, offset = nColumns - k - 1 + dataOffset; columns whose offset >= scores.size are skipped (continue), so scrolling past the oldest score leaves blank columns. The newest score is always in the rightmost column.
9. `charts-canvas-theming.score-chart#9` — Marker position: a baseSize-square rect placed at x = k*columnWidth + (columnWidth - baseSize)/2 and y = internalPaddingTop + columnHeight - (columnHeight*score).toInt() - baseSize/2, where score is the 0..1 score value.
10. `charts-canvas-theming.score-chart#10` — A straight line in primaryColor (strokeWidth baseSize*0.1) is drawn between the centres of consecutive markers; the marker itself is drawn for the PREVIOUS column each iteration, plus explicitly for the final column when k == nColumns-1.
11. `charts-canvas-theming.score-chart#11` — A marker is two concentric ovals: inset the baseSize square by baseSize*0.225 and fill with the card background colour (or PorterDuff CLEAR when transparency is enabled), then inset a further baseSize*0.1 and fill with primaryColor (or SRC when transparency is enabled) — producing a ring with a hole.
12. `charts-canvas-theming.score-chart#12` — Footer: shouldPrintYear starts true and is set false when the year equals previousYearText, when bucketSize >= 365 and the year is odd, or when a skipYear counter is still positive (the counter is then decremented). When a year is printed it is drawn CENTER at (columnCentreX, rectBottom + em*2.2), previousMonthText is cleared and skipYear is set to 1, so the next column never prints a year.
13. `charts-canvas-theming.score-chart#13` — When bucketSize < 365 a second footer line is drawn CENTER at (columnCentreX, rectBottom + em*1.2) showing dateFormatter.shortMonthName(date) if it differs from the previously printed month, otherwise date.day.
14. `charts-canvas-theming.score-chart#14` — previousMonthText, previousYearText and skipYear all reset to "", "" and 0 at the start of each onDraw.
15. `charts-canvas-theming.score-chart#15` — Colours from styled resources: textColor = contrast60, gridColor = contrast20, internalBackgroundColor = cardBgColor; primaryColor starts as Color.BLACK until setColor is called.
16. `charts-canvas-theming.score-chart#16` — Transparency mode (setIsTransparencyEnabled(true)) renders into an ARGB_8888 bitmap of the view size that is erased to Color.TRANSPARENT each frame and then blitted onto the real canvas, so that markers can punch true holes with PorterDuff CLEAR.
17. `charts-canvas-theming.score-chart#17` — Bucket sizes supplied by the presenter are exactly {1, 7, 31, 92, 365} for spinner positions 0..4 (day, week, month, quarter, year).
18. `charts-canvas-theming.score-chart#18` — populateWithRandomData() generates 99 scores walking backwards from today with a random walk of step 0.1 clamped to 0..1, starting at 0.5.

#### charts-canvas-theming.frequency-chart

- [ ] `charts-canvas-theming.frequency-chart` — FrequencyChart (weekday x month bubble chart)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/FrequencyChart.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt`, `uhabits-android/src/main/res/layout/show_habit_frequency.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/common/views/FrequencyChartTest.kt`, `.../habits/show/views/FrequencyCardViewTest.kt`
- **Notes:** Goldens: uhabits-android/src/androidTest/assets/views/common/FrequencyChart/{render,renderDataOffset,renderDifferentSize,renderTransparent}.png (300x100dp, 200x200dp for the different-size case). The show-habit card is 200dp tall.

1. `charts-canvas-theming.frequency-chart#1` — FrequencyChart is a ScrollableChart that renders one column per month and seven rows (one per weekday), with the bubble radius proportional to the frequency.
2. `charts-canvas-theming.frequency-chart#2` — onSizeChanged: a height < 9 px is replaced by 200; baseSize = height/8; setScrollerBucketSize(baseSize); pText.textSize = pGraph.textSize = baseSize*0.4f; pGraph.strokeWidth = baseSize*0.1f; pGrid.strokeWidth = baseSize*0.05f; em = pText.fontSpacing.
3. `charts-canvas-theming.frequency-chart#3` — columnWidth = max(baseSize, maxMonthWidth*1.2f) where maxMonthWidth measures shortMonthName for months 1..12 of 2020; columnHeight = 8*baseSize; nColumns = (width/columnWidth).toInt(); internalPaddingTop = 0.
4. `charts-canvas-theming.frequency-chart#4` — Only nColumns - 1 data columns are drawn; the rightmost column width is reserved for the weekday labels.
5. `charts-canvas-theming.frequency-chart#5` — The leftmost drawn month is computed as the first day of the current month stepped by (-nColumns + 2 - dataOffset) months, and each subsequent column steps forward one month; month arithmetic wraps the year (m<1 adds 12 and decrements the year, m>12 subtracts 12 and increments it) and always normalises to day 1.
6. `charts-canvas-theming.frequency-chart#6` — Grid: 7 label rows over the chart rect with rowHeight = height/8; each weekday label from dateFormatter.shortWeekdayNames(firstWeekday) is drawn LEFT-aligned at (right - columnWidth, top + rowHeight/2 + 0.25*em) in contrast60, a horizontal line in contrast20 with strokeWidth forced to 1f is drawn at each row top, and one final line is drawn after the loop.
7. `charts-canvas-theming.frequency-chart#7` — Within a column, row j (0..6) corresponds to weekday getWeekdaySequence(firstWeekday)[j], and the frequency array index used is i = (weekday.daysSinceSunday + 1) % 7 — i.e. the array is indexed Monday=0 .. Sunday=6.
8. `charts-canvas-theming.frequency-chart#8` — A month with no entry in the frequency map draws no bubbles at all (but still draws its footer).
9. `charts-canvas-theming.frequency-chart#9` — Bubble geometry: value is clamped with max(0, value) so skipped (negative) entries count as 0; padding = cellHeight*0.2; maxRadius = (cellHeight - 2*padding)/2; scalingFactor = maxFreq when the habit is numerical and countWeekdayOccurrencesInMonth(month)[i] otherwise; scale = value / scalingFactor; radius = maxRadius * scale.
10. `charts-canvas-theming.frequency-chart#10` — Bubble colour index = min(3, roundToInt(3 * scale)), selecting from a 4-entry ramp where colors[0] = contrast20 (grid colour), colors[3] = the habit colour, colors[1] = mixColors(colors[0], colors[3], 0.66f) and colors[2] = mixColors(colors[0], colors[3], 0.33f); mixColors(c1, c2, amount) blends per ARGB channel as c1*amount + c2*(1-amount), so colors[1] is 66% grid and colors[2] is 67% habit colour.
11. `charts-canvas-theming.frequency-chart#11` — maxFreq = max over every value in the frequency map, with a floor of 1.
12. `charts-canvas-theming.frequency-chart#12` — Footer: the short month name is drawn CENTER at (columnCentreX, cellCentreY - 0.1*em); additionally, when the month is February (month == 2), the year is drawn at (columnCentreX, cellCentreY + 0.9*em).
13. `charts-canvas-theming.frequency-chart#13` — setIsBackgroundTransparent(true) only re-runs initColors(); the chart has no offscreen/xfermode transparency path, so the transparent-background golden differs from the normal one only via the theme in effect.
14. `charts-canvas-theming.frequency-chart#14` — populateWithRandomData() fills 40 consecutive months backwards from the current month with seven random values in 0..4 each.

#### charts-canvas-theming.streak-chart

- [ ] `charts-canvas-theming.streak-chart` — StreakChart (best streaks bar chart)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/StreakChart.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Streak.kt`, `uhabits-android/src/main/res/layout/show_habit_streak.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/common/views/StreakChartTest.kt`, `.../habits/show/views/StreakCardViewTest.kt`
- **Notes:** Goldens: uhabits-android/src/androidTest/assets/views/common/StreakChart/{render,renderSmallSize,renderTransparent}.png (300x100dp and 100x100dp). The test fixture uses habit.streaks.getBest(5).

1. `charts-canvas-theming.streak-chart#1` — StreakChart is a plain View (no scrolling) drawing one horizontal centred bar per Streak, top to bottom, each baseSize (20dp) tall.
2. `charts-canvas-theming.streak-chart#2` — onDraw returns immediately when the streak list is empty; the default streak list after construction is emptyList().
3. `charts-canvas-theming.streak-chart#3` — maxStreakCount == floor(measuredHeight / baseSize) and is exposed so the caller can decide how many streaks to fetch.
4. `charts-canvas-theming.streak-chart#4` — onMeasure: when layoutParams.height is WRAP_CONTENT the measured height becomes streaks.size * baseSize and the measured width is the incoming spec size, both EXACTLY.
5. `charts-canvas-theming.streak-chart#5` — onSizeChanged sets paint.textSize = max(min(baseSize*0.5f, regularTextSize (16sp)), tinyTextSize (10sp)); em = paint.fontSpacing; textMargin = 0.5f*em.
6. `charts-canvas-theming.streak-chart#6` — drawRow returns immediately when maxLength == 0; percentage = streak.length / maxLength where Streak.length == start.daysUntil(end) + 1.
7. `charts-canvas-theming.streak-chart#7` — availableWidth = viewWidth - 2*maxLabelWidth, minus a further 2*textMargin when labels are shown; barWidth = max(percentage * availableWidth, paint.measureText(lengthText) + em) so a bar is never narrower than its own number; gap = (viewWidth - barWidth)/2 so every bar is horizontally centred.
8. `charts-canvas-theming.streak-chart#8` — The bar is a round rect with corner radius 2dp, inset vertically by baseSize*0.05 on both sides.
9. `charts-canvas-theming.streak-chart#9` — Bar colour by percentage: >= 1.0 -> the habit colour; >= 0.8 -> the habit colour at alpha 192; >= 0.5 -> the habit colour at alpha 96; otherwise contrast20.
10. `charts-canvas-theming.streak-chart#10` — Number colour by percentage: >= 0.5 -> contrast0; otherwise contrast60. The number is drawn CENTER at (rowCentreX, rowCentreY + 0.3f*em).
11. `charts-canvas-theming.streak-chart#11` — When labels are shown, the start date is drawn RIGHT-aligned at x = gap - textMargin and the end date LEFT-aligned at x = viewWidth - gap + textMargin, both in contrast60 and both formatted with DateFormat.MEDIUM in the default locale.
12. `charts-canvas-theming.streak-chart#12` — Labels are suppressed (shouldShowLabels = false and maxLabelWidth reset to 0) when viewWidth - 2*maxLabelWidth < viewWidth * 0.25f — i.e. when the bars would be squeezed below a quarter of the view width.
13. `charts-canvas-theming.streak-chart#13` — maxLabelWidth is never reset to 0 at the start of updateMaxMinLengths, so it only ever grows across successive setStreaks/onSizeChanged calls within one view instance.
14. `charts-canvas-theming.streak-chart#14` — initColors builds the 4-entry ramp from the primary colour's red/green/blue components using Color.argb with alphas 255, 192, 96 and the contrast20 colour at index 0, and the 3-entry text ramp as contrast80, contrast60, contrast0 at indices 0, 1, 2.
15. `charts-canvas-theming.streak-chart#15` — populateWithRandomData() creates 10 consecutive streaks of random length 0..99 starting at today, each beginning the day after the previous one ends.

#### charts-canvas-theming.target-chart

- [ ] `charts-canvas-theming.target-chart` — TargetChart (target progress bars)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/TargetChart.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/TargetCard.kt`, `uhabits-android/src/main/res/layout/show_habit_target.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/TargetWidgetTest.kt`
- **Notes:** Golden for the widget variant only: uhabits-android/src/androidTest/assets/views/widgets/TargetWidget/render.png (400x400px). The show-habit card is 300dp tall. There is no dedicated TargetChart unit test.

1. `charts-canvas-theming.target-chart#1` — TargetChart is a plain View drawing one labelled horizontal progress bar per row from three parallel lists: labels: List<String>, values: List<Double> and targets: List<Double>, all defaulting to empty.
2. `charts-canvas-theming.target-chart#2` — onDraw returns immediately when labels is empty.
3. `charts-canvas-theming.target-chart#3` — onMeasure: baseSize starts at the 20dp baseSize dimension; the measured height is labels.size * baseSize, except when layoutParams.height is MATCH_PARENT, in which case the height is the incoming spec size and baseSize becomes height / labels.size (when labels is non-empty).
4. `charts-canvas-theming.target-chart#4` — The block of rows is vertically centred: marginTop = (viewHeight - baseSize*labels.size) / 2.
5. `charts-canvas-theming.target-chart#5` — maxLabelSize is recomputed on every draw as the widest measureText(label) at tinyTextSize (10sp); the label gutter width is stop = maxLabelSize + 2*padding where padding = 4dp.
6. `charts-canvas-theming.target-chart#6` — The row label is drawn RIGHT-aligned in contrast60 at (rowLeft + stop - padding, rowCentreY - (descent+ascent)/2).
7. `charts-canvas-theming.target-chart#7` — The background bar is a round rect (radius 2dp) in contrast20 spanning x from rowLeft + stop + padding to rowRight - padding and y from rowTop + baseSize*0.05 to rowBottom - baseSize*0.05.
8. `charts-canvas-theming.target-chart#8` — percentage = values[row] / targets[row] when targets[row] > 0, otherwise 1.0; it is then clamped with min(1.0f, percentage) but is NOT clamped below, so negative values produce a negative completed width.
9. `charts-canvas-theming.target-chart#9` — completedWidth = percentage * barWidth, and if completedWidth is strictly between 0 and 2*round (2*2dp) it is bumped up to 2*round so a tiny amount of progress is still visible as a rounded pip; remainingWidth = barWidth - completedWidth.
10. `charts-canvas-theming.target-chart#10` — The completed portion is drawn as a round rect (radius 2dp) in the habit colour from the bar's left edge to left + completedWidth.
11. `charts-canvas-theming.target-chart#11` — The completed value text values[row].toShortString() is drawn centred inside the completed box in contrast0, but only when completedWidth > measureText(text) + 2*padding.
12. `charts-canvas-theming.target-chart#12` — The remaining value text (targets[row] - values[row]).toShortString() is drawn centred in the remaining region in contrast60, but only when remainingWidth > measureText(text) + 2*padding. Note the remaining text is not clamped at zero, so an over-target row shows a negative number when it fits.
13. `charts-canvas-theming.target-chart#13` — Colours come from styled resources: lowContrastTextColor = contrast20, mediumContrastTextColor = contrast60, highContrastReverseTextColor = contrast0.
14. `charts-canvas-theming.target-chart#14` — setValues, setLabels and setTargets each call requestLayout().

#### charts-canvas-theming.ring-view-android

- [ ] `charts-canvas-theming.ring-view-android` — RingView (Android progress ring widget)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/RingView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/AttributeSetUtils.kt`, `uhabits-android/src/main/res/layout/show_habit_overview.xml`, `.../layout/widget_checkmark.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HabitCardView.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/common/views/RingViewTest.kt`, `.../habits/show/views/OverviewCardViewTest.kt`
- **Notes:** Goldens: uhabits-android/src/androidTest/assets/views/common/RingView/{render,renderDifferentParams}.png (100x100dp with percentage 0.6, text "60%", palette colour 0, white background, thickness 3dp; and 200x200dp with percentage 0.25 and palette colour 5). PorterDuff CLEAR needs saveLayer + BlendMode.clear in Flutter.

1. `charts-canvas-theming.ring-view-android#1` — RingView is a square View: onMeasure sets diameter = max(1, min(measuredHeight, measuredWidth)) and reports (diameter, diameter) as the measured size; em is cached as paint.measureText("M") at the current text size.
2. `charts-canvas-theming.ring-view-android#2` — XML attribute defaults (namespace http://isoron.org/android): percentage=0f, precision=0.01f, color=0, backgroundColor=null (falls back to cardBgColor), inactiveColor=null (falls back to contrast100), thickness=0f (interpreted as dp), textSize = the smallTextSize dimension (14sp) converted through spToPixels, text="", enableFontAwesome=false. Unparseable float attributes fall back to the default rather than throwing.
3. `charts-canvas-theming.ring-view-android#3` — inactiveColor is always forced to 15% alpha at construction: setAlpha(inactiveColor, 0.15f).
4. `charts-canvas-theming.ring-view-android#4` — The filled angle is quantised by precision: angle = 360 * roundToLong(percentage / precision) * precision. With the default precision of 0.01 the ring snaps to 3.6-degree (1%) steps.
5. `charts-canvas-theming.ring-view-android#5` — Drawing order: the progress arc drawArc(rect, -90f, angle, useCenter=true) in the habit colour; then the remainder drawArc(rect, angle - 90f, 360 - angle, useCenter=true) in inactiveColor; then, only when thickness > 0, the rect is inset by thickness on all sides and a full 360-degree arc is drawn in backgroundColor (or with PorterDuff CLEAR when transparency is enabled) to punch the hole.
6. `charts-canvas-theming.ring-view-android#6` — The centre text is drawn only when thickness > 0, in the habit colour, at textSize, CENTER-aligned at (centreX, centreY + 0.4f*em) of the already-inset rect.
7. `charts-canvas-theming.ring-view-android#7` — When isStrokedTextEnabled the text paint switches to Paint.Style.STROKE with strokeWidth = textSize / 15f; when enableFontAwesome the text paint switches to the FontAwesome typeface.
8. `charts-canvas-theming.ring-view-android#8` — Transparency mode allocates an ARGB_8888 bitmap of diameter x diameter, erases it to Color.TRANSPARENT every frame, draws into it and then blits it onto the real canvas; the cache is reallocated on size change and the old bitmap is recycled.
9. `charts-canvas-theming.ring-view-android#9` — setColor, setPercentage, setPrecision, setText, setThickness and setBackgroundColor all call invalidate(); setTextSize, setIsStrokedTextEnabled and setIsTransparencyEnabled do not.
10. `charts-canvas-theming.ring-view-android#10` — Concrete usages: the show-habit overview ring is 30dp with thickness 5dp and textSize 12; the habit list card ring is 15dp with thickness 3dp and 8dp horizontal margins; the checkmark widget ring uses thickness 2dp, textSize 16 and enableFontAwesome=true.

#### charts-canvas-theming.notes-indicator

- [ ] `charts-canvas-theming.notes-indicator` — Notes indicator dot on entry buttons
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/CheckmarkButtonView.kt`, `.../views/NumberButtonView.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HistoryChart.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/EntryButtonViewTest.kt`
- **Notes:** The hard-coded 8f pixel radius means the dot does not scale with screen density — replicate as-is or the goldens shift.

1. `charts-canvas-theming.notes-indicator#1` — drawNotesIndicator(pNotesIndicator, canvas, color, size, notes) returns without drawing when notes.isBlank() is true (empty string or whitespace only).
2. `charts-canvas-theming.notes-indicator#2` — When drawn, it fills a circle of radius exactly 8f raw pixels (NOT dp-scaled) in the given colour at centre (view.width - 0.8f*size, 0.8f*size), i.e. inset from the top-right corner by 0.8 em.
3. `charts-canvas-theming.notes-indicator#3` — The same helper is shared by CheckmarkButtonView and NumberButtonView, with size = the respective view's cached em value.
4. `charts-canvas-theming.notes-indicator#4` — The core HistoryChart has its own, unrelated notes indicator: a circle of radius squareWidth/12 at (x + width - width/5, y + width/5) of each calendar square.

#### charts-canvas-theming.color-utils

- [x] `charts-canvas-theming.color-utils` — Android colour blending helpers
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/ColorUtils.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Merged duplicate id: `platform-glue.color-utils`. Direct Dart equivalents exist (Color, HSVColor); the truncation semantics are the only subtlety.

1. `charts-canvas-theming.color-utils#1` — ColorUtils.mixColors(color1, color2, amount) blends each of the four ARGB channels independently as ((c1 >> shift and 0xff) * amount + (c2 >> shift and 0xff) * (1 - amount)).toInt() and 0xff, then ORs the channels back together; amount therefore weights color1, not color2.
2. `charts-canvas-theming.color-utils#2` — ColorUtils.setAlpha(color, newAlpha) returns Color.argb((newAlpha*255).toInt(), red, green, blue) — truncating, not rounding, the alpha.
3. `charts-canvas-theming.color-utils#3` — ColorUtils.changeHue(color, delta) converts to HSV, adds delta to the hue using Kotlin's mod (always non-negative) against 360f, and converts back.
4. `charts-canvas-theming.color-utils#4` — ColorUtils.setMinValue(color, newValue) converts to HSV and raises the V component to max(v, newValue) without changing hue or saturation.
5. `charts-canvas-theming.color-utils#5` — These helpers are used by FrequencyChart's 4-step colour ramp and by RingView's inactive colour; they operate on packed Android ints, whereas the core Color.blendWith operates on normalised doubles and weights the OTHER colour — the two conventions are inverted and must not be conflated.
6. `charts-canvas-theming.color-utils#6` — mixColors: each channel result = (((color1 >> ch) & 0xff) * amount + ((color2 >> ch) & 0xff) * (1 - amount)).toInt() and 0xff shl ch — so amount=1.0 returns color1's channels and amount=0.0 returns color2's; the float multiply is truncated toward zero, not rounded (bit offsets 24 alpha, 16 red, 8 green, 0 blue).
7. `charts-canvas-theming.color-utils#7` — setAlpha(color, newAlpha: Float) returns Color.argb((newAlpha * 255).toInt(), red, green, blue) — the float is truncated, so 0.5f yields alpha 127.

#### charts-canvas-theming.chart-host-contracts

- [ ] `charts-canvas-theming.chart-host-contracts` — Chart hosting, sizing and refresh contracts
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/HabitChart.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/dialogs/HistoryEditorDialog.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/widgets/HistoryWidget.kt`, `.../widgets/views/GraphWidgetView.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/BarCardView.kt`, `uhabits-android/src/main/res/layout/show_habit_score.xml`, `.../show_habit_history.xml`, `.../show_habit_bar.xml`, `.../show_habit_frequency.xml`, `.../show_habit_streak.xml`, `.../show_habit_target.xml`, `uhabits-android/src/main/res/values/constants.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/widgets/HistoryWidgetTest.kt`, `.../ScoreWidgetTest.kt`, `.../FrequencyWidgetTest.kt`, `.../StreakWidgetTest.kt`, `.../TargetWidgetTest.kt`

1. `charts-canvas-theming.chart-host-contracts#1` — HabitChart is a two-method interface, setHabit(habit: Habit?) and refreshData(), implemented by the show-habit chart cards.
2. `charts-canvas-theming.chart-host-contracts#2` — Card chart heights are fixed in layout: the bar/history card chart is 220dp, the score chart is 220dp, the history calendar is 160dp, the frequency chart is 200dp, the target chart is 300dp, and the streak chart is WRAP_CONTENT (sized by StreakChart.onMeasure to streaks.size * 20dp).
3. `charts-canvas-theming.chart-host-contracts#3` — The history editor dialog builds a HistoryChart with padding = 10.0 and sizes the dialog to (screenWidth, min(screenHeight, 350dp)); it rebuilds series/defaultSquare/notesIndicators whenever a command finishes, and always builds its state with LightTheme() even though the chart itself is given the switcher's current theme.
4. `charts-canvas-theming.chart-host-contracts#4` — The history widget builds a HistoryChart with padding = 2.5 and WidgetTheme(); its default widget size is 250x250.
5. `charts-canvas-theming.chart-host-contracts#5` — The bar card calls resetDataOffset() on its AndroidDataView every time it receives new state, so changing the bucket spinner always snaps the chart back to today.
6. `charts-canvas-theming.chart-host-contracts#6` — GraphWidgetView wraps any chart View in a widget frame with 4dp top and 8dp left/right/bottom padding and a two-line centred white title at smallTextSize.
7. `charts-canvas-theming.chart-host-contracts#7` — Widget opacity is selectable from the fixed list 255, 204, 153, 102, 51, 0 (labelled 100%, 80%, 60%, 40%, 20%, 0%); when the preferred background alpha is >= 255 the graph widget sets its shadow alpha to 0x4F.

#### charts-canvas-theming.task-progress-bar

- [ ] `charts-canvas-theming.task-progress-bar` — TaskProgressBar background-work indicator
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/TaskProgressBar.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Flutter equivalent is a LinearProgressIndicator driven by a task-count stream with a 500 ms debounce.

1. `charts-canvas-theming.task-progress-bar#1` — TaskProgressBar is an indeterminate horizontal ProgressBar that starts with visibility GONE and isIndeterminate = true.
2. `charts-canvas-theming.task-progress-bar#2` — It registers itself as a TaskRunner.Listener on attach (and immediately calls update()) and unregisters on detach.
3. `charts-canvas-theming.task-progress-bar#3` — Both onTaskStarted and onTaskFinished call update().
4. `charts-canvas-theming.task-progress-bar#4` — update() posts a delayed callback with a 500 ms delay that sets visibility to GONE when runner.activeTaskCount == 0 and VISIBLE otherwise, and only assigns the visibility when it actually differs from the current one. The 500 ms delay is what prevents flicker for short tasks.

#### charts-canvas-theming.screenshot-baselines

- [ ] `charts-canvas-theming.screenshot-baselines` — Screenshot baseline assets and golden conventions
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/assets/test/views/CanvasTest.png`, `.../BarChart/base.png`, `.../HistoryChart/base.png`, `.../CheckmarkButton/explicit.png`, `.../NumberButton/render_above.png`, `.../HabitListHeader/light.png`, `.../Ring/draw1.png`, `uhabits-android/src/androidTest/assets/views/CanvasTest.png`, `.../common/ScoreChart/render.png`, `.../common/FrequencyChart/render.png`, `.../common/StreakChart/render.png`, `.../common/RingView/render.png`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/CanvasTest.kt`, `.../gui/ViewTestHelper.kt`, `.../ui/views/BarChartTest.kt`, `.../ui/views/HistoryChartTest.kt`, `uhabits-android/src/androidTest/java/org/isoron/platform/gui/AndroidCanvasTest.kt`, `.../uhabits/BaseViewTest.kt`
- **Notes:** These PNGs are the only executable spec for the exact pixel output of the charts and should be carried over as Flutter golden files (matchesGoldenFile) with a tolerant comparator mirroring Image.diff.

1. `charts-canvas-theming.screenshot-baselines#1` — Core (Canvas-based) baselines live under uhabits-core/assets/test/views/ and are rendered at pixelScale 2.0, so every PNG is exactly twice the logical size: CanvasTest.png 1000x800; BarChart/{base,offset,themeDark,themeWidget}.png 600x400; HistoryChart/{base,scroll,themeDark,themeWidget,weekday}.png 800x400 and HistoryChart/small.png 400x400; CheckmarkButton/{explicit,implicit,unchecked}.png 96x96; NumberButton/{render_above,render_below,render_zero}.png 96x96; HabitListHeader/light.png 1200x96; Ring/draw1.png 120x120.
2. `charts-canvas-theming.screenshot-baselines#2` — Only BarChart, HistoryChart and CanvasTest have live core tests; the CheckmarkButton, NumberButton, HabitListHeader and Ring baselines are currently orphaned and are the best available reference for porting those four core views.
3. `charts-canvas-theming.screenshot-baselines#3` — Android instrumentation baselines live under uhabits-android/src/androidTest/assets/views/ and are captured at density 2 (dp*2 = px): CanvasTest.png 1000x800; common/FrequencyChart/{render,renderDataOffset,renderTransparent}.png 600x200 and renderDifferentSize.png 400x400; common/RingView/render.png 200x200 and renderDifferentParams.png 400x400; common/ScoreChart/{render,renderDataOffset,renderMonthly,renderTransparent,renderYearly}.png 600x400 and renderDifferentSize.png 400x400; common/StreakChart/{render,renderTransparent}.png 600x200 and renderSmallSize.png 200x200.
4. `charts-canvas-theming.screenshot-baselines#4` — Additional baselines relevant to this domain cover the list cells (habits/list/CheckmarkButtonView/*.png and NumberButtonView/*.png at 96x96, CheckmarkPanelView/NumberPanelView at 384x96, HeaderView at 1200x96, HabitCardView at 800x100), the show-habit cards (habits/show/{FrequencyCard,HistoryCard,ScoreCard,StreakCard}/render.png at 800x600 and OverviewCard at 800x300) and the widgets (widgets/{FrequencyWidget,HistoryWidget,ScoreWidget,StreakWidget,TargetWidget}/render.png at 400x400, CheckmarkWidget at 150x200, CheckmarkWidgetView/{checked.png 200x250, large_size.png 600x600}).
5. `charts-canvas-theming.screenshot-baselines#5` — The android test fixtures use FIXED colours from PaletteUtils (the CSV palette, e.g. index 0 = #D32F2F, index 5 = #AFB42B) rather than the theme-resolved palette, so screenshots are theme-independent for the habit colour itself.
6. `charts-canvas-theming.screenshot-baselines#6` — Core tests use JavaLocalDateFormatter(Locale.US) and a fixed today of 2015-01-25, so month/weekday abbreviations in the goldens are English three-letter forms.
7. `charts-canvas-theming.screenshot-baselines#7` — On failure the core harness writes /tmp/failed/<path>, /tmp/failed/<path>.expected.png and /tmp/failed/<path>.diff.png; the Android harness writes the actual and .expected bitmaps into an external 'test-screenshots' directory.

## Domain: Platform glue (automation plugin, intents, manifest, DI, startup, localization)

#### platform-glue.manifest-components

- [ ] `platform-glue.manifest-components` — Declared app components (activities, aliases, receivers, services, provider)
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/build.gradle.kts`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Flutter has a single Activity by default. Every one of these components must be re-declared by hand in the Flutter app's AndroidManifest (and mostly re-implemented via platform channels). The activity-alias .MainActivity is the persisted launcher component name — renaming it breaks existing home-screen shortcuts. android:permission="false" on WidgetReceiver looks like a latent bug worth NOT reproducing.

1. `platform-glue.manifest-components#1` — The application element declares android:name=".HabitsApplication", android:allowBackup="true", android:backupAgent=".HabitsBackupAgent", android:icon="@mipmap/ic_launcher", android:label="@string/main_activity_title" ("Habits"), android:localeConfig="@xml/locales_config", android:supportsRtl="true", android:theme="@style/AppBaseTheme".
2. `platform-glue.manifest-components#2` — There is exactly one launcher entry point, and it is an <activity-alias> named ".MainActivity" with targetActivity=".activities.habits.list.ListHabitsActivity", exported=true, launchMode="singleTop", label="@string/main_activity_title", whose intent-filter is action android.intent.action.MAIN + category android.intent.category.LAUNCHER. ListHabitsActivity itself is declared separately (exported=true, launchMode="singleTop") with NO launcher intent-filter.
3. `platform-glue.manifest-components#3` — Exactly 8 activities are declared: EditHabitActivity (exported=true), ListHabitsActivity (exported=true, singleTop), ShowHabitActivity (not exported, label=@string/title_activity_show_habit), SettingsActivity (label=@string/settings), IntroActivity (label="", theme=Theme.AppCompat.Light.NoActionBar), AboutActivity (label=@string/about), SnoozeDelayPickerActivity, and automation/EditSettingActivity (exported=true). Plus 3 widget-configuration dialog activities: HabitPickerDialog, BooleanHabitPickerDialog, NumericalHabitPickerDialog.
4. `platform-glue.manifest-components#4` — EditHabitActivity, ShowHabitActivity, SettingsActivity and AboutActivity each declare meta-data android.support.PARENT_ACTIVITY = ".activities.habits.list.ListHabitsActivity", i.e. their Up button returns to the habit list.
5. `platform-glue.manifest-components#5` — SnoozeDelayPickerActivity is declared with android:excludeFromRecents="true", android:launchMode="singleInstance", android:taskAffinity="" and android:theme="@android:style/Theme.Translucent.NoTitleBar": it must appear as a transparent overlay outside the app task and never show in Recents.
6. `platform-glue.manifest-components#6` — The 3 widget picker dialogs (.widgets.activities.HabitPickerDialog, .BooleanHabitPickerDialog, .NumericalHabitPickerDialog) are exported=true, use theme Theme.AppCompat.Light.Dialog.Alert, and each declares an intent-filter for action android.appwidget.action.APPWIDGET_CONFIGURE.
7. `platform-glue.manifest-components#7` — Exactly 6 AppWidget provider receivers are declared, all exported=true with an APPWIDGET_UPDATE intent-filter and an android.appwidget.provider meta-data resource: CheckmarkWidgetProvider (label @string/checkmark), HistoryWidgetProvider (@string/history), ScoreWidgetProvider (@string/score), StreakWidgetProvider (@string/streaks), FrequencyWidgetProvider (@string/frequency), TargetWidgetProvider (@string/target).
8. `platform-glue.manifest-components#8` — One service is declared: .widgets.StackWidgetService with android:exported="false" and android:permission="android.permission.BIND_REMOTEVIEWS".
9. `platform-glue.manifest-components#9` — Three non-widget receivers are declared: .receivers.ReminderReceiver (exported=true, intent-filter android.intent.action.BOOT_COMPLETED), .receivers.WidgetReceiver (exported=true, android:permission="false" — a literal string, not a real permission, so the receiver is effectively unprotected), and .automation.FireSettingReceiver (exported=true, intent-filter com.twofortyfouram.locale.intent.action.FIRE_SETTING).
10. `platform-glue.manifest-components#10` — A FileProvider (androidx.core.content.FileProvider) is declared with android:authorities="org.isoron.uhabits", exported=false, grantUriPermissions=true and meta-data android.support.FILE_PROVIDER_PATHS = @xml/file_paths.
11. `platform-glue.manifest-components#11` — An application-level meta-data com.google.android.backup.api_key with value "AEdPqrEAAAAI6aeWncbnMNo8E5GWeZ44dlc5cQ7tCROwFhOtiw" is declared for Android Backup Service.
12. `platform-glue.manifest-components#12` — The applicationId / namespace is "org.isoron.uhabits"; versionCode = 20301, versionName = "2.3.1", minSdk = 28, targetSdk = 36, compileSdk = 36.

#### platform-glue.permissions

- [ ] `platform-glue.permissions` — Declared permissions and runtime notification permission flow
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** In Flutter this maps to permission_handler + a manual manifest edit; the once-per-activity guard must be reproduced or the app will loop on permission denial.

1. `platform-glue.permissions#1` — Exactly 5 <uses-permission> entries are declared, in this order: android.permission.POST_NOTIFICATIONS, android.permission.RECEIVE_BOOT_COMPLETED, android.permission.SCHEDULE_EXACT_ALARM, android.permission.USE_EXACT_ALARM, android.permission.VIBRATE.
2. `platform-glue.permissions#2` — No storage permissions (READ/WRITE_EXTERNAL_STORAGE) are declared; all file output goes through app-private external dirs or SAF/DocumentFile tree URIs.
3. `platform-glue.permissions#3` — POST_NOTIFICATIONS is requested lazily, not at startup: on every ListHabitsActivity.onResume, if reminderScheduler.hasHabitsWithReminders() is true AND SDK_INT >= 33 (TIRAMISU) AND checkSelfPermission(POST_NOTIFICATIONS) != PERMISSION_GRANTED, the permission is requested — but only once per activity instance, guarded by a boolean permissionAlreadyRequested, specifically to avoid an infinite onResume request loop when the user denies.
4. `platform-glue.permissions#4` — If SDK_INT < 33, reminders are scheduled directly (reminderScheduler.scheduleAll()) with no permission request.
5. `platform-glue.permissions#5` — If the permission request result is granted, reminderScheduler.scheduleAll() is called; if denied, the app logs "POST_NOTIFICATIONS denied" at INFO level and does nothing else (no dialog, no toast).
6. `platform-glue.permissions#6` — If there are no habits with reminders, the permission is never requested at all.

#### platform-glue.app-startup-order

- [ ] `platform-glue.app-startup-order` — Application startup sequence (HabitsApplication.onCreate)
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DatabaseUtils.kt`, `.../HabitsDatabaseOpener.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/JvmDates.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseAndroidTest.kt`
- **Notes:** The ordering matters: setToday() must happen before any habit recompute or widget/reminder work, because getToday() throws "getToday() called before setToday()" if unset.

1. `platform-glue.app-startup-order#1` — HabitsApplication.onCreate performs steps in this exact order: (1) if isTestMode(), delete the database file; (2) DatabaseUtils.initializeDatabase(context); (3) build the DI component; (4) write prefs.lastAppVersion = BuildConfig.VERSION_CODE; (5) setToday(computeToday(prefs.midnightDelayHours, 0)); (6) recompute every habit; (7) start the widget updater; (8) start the reminder scheduler; (9) start the notification tray; (10) run scheduleAll + updateWidgets on the task runner.
2. `platform-glue.app-startup-order#2` — isTestMode() returns true iff Class.forName("org.isoron.uhabits.BaseAndroidTest") succeeds; when true the database file is deleted at startup and the filename used is "test.db" instead of "uhabits.db".
3. `platform-glue.app-startup-order#3` — DatabaseUtils.initializeDatabase is wrapped in try/catch for UnsupportedDatabaseVersionException: on that exception the existing database file is renamed to its absolute path + ".invalid" and initializeDatabase is retried, so a too-new/too-old DB never crashes startup but silently starts a fresh empty database.
4. `platform-glue.app-startup-order#4` — The DI root is created as HabitsApplicationComponent::class.create(appContext = applicationContext, dbFile = DatabaseUtils.getDatabaseFile(this)) and stored in a static (companion) lateinit var HabitsApplication.component; the instance property `component` just returns that static.
5. `platform-glue.app-startup-order#5` — prefs.lastAppVersion is persisted as SharedPreferences int key "last_version" (default 0 when absent) and is set to BuildConfig.VERSION_CODE (20301) on every launch.
6. `platform-glue.app-startup-order#6` — The global "today" is set once at startup: setToday(computeToday(hourOffset = preferences.midnightDelayHours, minuteOffset = 0)). midnightDelayHours is 3 when SharedPreferences boolean "pref_midnight_delay" is true, otherwise 0.
7. `platform-glue.app-startup-order#7` — computeToday(hourOffset, minuteOffset) = LocalDate(daysSince2000) where daysSince2000 = floorDiv(System.currentTimeMillis() + timezoneOffset(now) - hourOffset*3600000 - minuteOffset*60000, 86400000) - 10957.
8. `platform-glue.app-startup-order#8` — Every habit in the habit list has recompute() called synchronously on the main thread during onCreate, before widgets/reminders start.
9. `platform-glue.app-startup-order#9` — widgetUpdater.startListening() and widgetUpdater.scheduleStartDayWidgetUpdate() are both called at startup; scheduleStartDayWidgetUpdate schedules an RTC alarm at DateUtils.getStartOfTomorrowWithOffset(midnightDelayHours, 0).
10. `platform-glue.app-startup-order#10` — reminderScheduler.startListening() and notificationTray.startListening() register them as CommandRunner listeners (notificationTray additionally registers as a Preferences listener).
11. `platform-glue.app-startup-order#11` — The final step runs asynchronously on the task runner: reminderScheduler.scheduleAll() followed by widgetUpdater.updateWidgets().
12. `platform-glue.app-startup-order#12` — onTerminate stops listening in the reverse-ish order: reminderScheduler.stopListening(), widgetUpdater.stopListening(), notificationTray.stopListening(), then super.onTerminate().

#### platform-glue.di-app-component

- [ ] `platform-glue.di-app-component` — Application-scope dependency graph (HabitsApplicationComponent)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/inject/HabitsApplicationComponent.kt`, `.../inject/AppContext.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/preferences/SharedPreferencesStorage.kt`, `.../io/AndroidLogging.kt`, `.../database/AndroidDatabaseOpener.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/HabitsApplicationTestComponent.kt`, `.../BaseAndroidTest.kt`
- **Notes:** Maps cleanly to get_it / riverpod in Dart. The only subtlety is the singleton-ness (@AppScope) and the lazy database.

1. `platform-glue.di-app-component#1` — The app component is a kotlin-inject @Component annotated @AppScope taking two constructor-provided bindings: @AppContext Context (the application context) and File dbFile.
2. `platform-glue.di-app-component#2` — It exposes exactly these singletons: commandRunner, context (@AppContext), genericImporter, habitCardListCache, habitList, intentFactory, intentParser, logging, midnightTimer, modelFactory, notificationTray, pendingIntentFactory, preferences, reminderScheduler, reminderController, taskRunner, widgetPreferences, widgetUpdater, plus a lazily-created AndroidDatabase `db`.
3. `platform-glue.di-app-component#3` — The AndroidDatabase is created lazily exactly once via `by lazy { AndroidDatabase(DatabaseUtils.openDatabase()) }`; DatabaseUtils.openDatabase() throws (checkNotNull) if initializeDatabase was not called first.
4. `platform-glue.di-app-component#4` — Bindings: Preferences is built from SharedPreferencesStorage; WidgetPreferences is built from the same SharedPreferencesStorage instance; ModelFactory = SQLModelFactory(db); HabitList = SQLiteHabitList; DatabaseOpener = AndroidDatabaseOpener; Logging = AndroidLogging; FileOpener = AndroidFileOpener(appContext.assets, appContext.filesDir).
5. `platform-glue.di-app-component#5` — TaskRunner = CoroutineTaskRunner(mainDispatcher = Dispatchers.Main, ioDispatcher = Dispatchers.IO).
6. `platform-glue.di-app-component#6` — ReminderScheduler is constructed as ReminderScheduler(commandRunner, habitList, IntentScheduler, widgetPreferences) — note the argument order differs from the @Provides parameter order.
7. `platform-glue.di-app-component#7` — NotificationTray is constructed as NotificationTray(taskRunner, commandRunner, preferences, AndroidNotificationTray).
8. `platform-glue.di-app-component#8` — @AppContext and @ActivityContext are kotlin-inject @Qualifier annotations applicable to PROPERTY_GETTER, FUNCTION, VALUE_PARAMETER and TYPE; they disambiguate the two Context bindings.
9. `platform-glue.di-app-component#9` — Every @Provides function is `open`, so tests can subclass the component and override individual bindings (HabitsApplicationTestComponent overrides taskRunner and additionally exposes intentScheduler).

#### platform-glue.di-activity-component

- [ ] `platform-glue.di-activity-component` — Activity-scope dependency graph (HabitsActivityComponent)
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/inject/HabitsActivityComponent.kt`, `.../inject/ActivityScope.kt`, `.../inject/ActivityContext.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`, `.../activities/HabitsDirFinder.kt`, `.../activities/habits/list/ListHabitsModule.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/HabitsActivityTestComponent.kt`
- **Notes:** In Flutter this becomes a per-route scope (e.g. a ProviderScope around the habit list page).

1. `platform-glue.di-activity-component#1` — HabitsActivityComponent is @ActivityScope @Component with parent = HabitsApplicationComponent and a constructor-provided @ActivityContext Context (the Activity).
2. `platform-glue.di-activity-component#2` — It exposes: colorPickerDialogFactory, habitCardListAdapter, listHabitsBehavior, listHabitsMenu, listHabitsRootView, listHabitsScreen, listHabitsSelectionMenu, themeSwitcher.
3. `platform-glue.di-activity-component#3` — ThemeSwitcher is bound @ActivityScope to AndroidThemeSwitcher(activityContext, preferences).
4. `platform-glue.di-activity-component#4` — Interface bindings inside the activity component: HabitCardListAdapter -> ListHabitsMenuBehavior.Adapter and -> ListHabitsSelectionMenuBehavior.Adapter; ListHabitsScreen -> ListHabitsBehavior.Screen, ListHabitsMenuBehavior.Screen and ListHabitsSelectionMenuBehavior.Screen; ListHabitsModule -> ListHabitsBehavior.BugReporter; HabitsDirFinder -> ListHabitsBehavior.DirFinder.
5. `platform-glue.di-activity-component#5` — ListHabitsActivity.onCreate creates this component with HabitsActivityComponent::class.create(parent = appComponent, activityContext = this), then immediately calls component.themeSwitcher.apply() BEFORE reading any views.
6. `platform-glue.di-activity-component#6` — The activity component is created fresh on each ListHabitsActivity.onCreate — nothing in it survives a configuration change.
7. `platform-glue.di-activity-component#7` — @ActivityScope is a kotlin-inject @Scope annotation documented as "objects that live as long as the activity is alive".

#### platform-glue.di-receiver-components

- [ ] `platform-glue.di-receiver-components` — Receiver-scope subcomponents
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReceiverScope.kt`, `.../receivers/WidgetReceiver.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/automation/FireSettingReceiver.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `platform-glue.di-receiver-components#1` — @ReceiverScope is a kotlin-inject @Scope used by two internal components, each created fresh on every broadcast receipt.
2. `platform-glue.di-receiver-components#2` — WidgetComponent is @ReceiverScope @Component(parent = HabitsApplicationComponent) exposing a single binding: widgetController: WidgetBehavior. WidgetReceiver.onReceive calls WidgetComponent::class.create(app.component) on every broadcast.
3. `platform-glue.di-receiver-components#3` — FireSettingReceiverComponent is @ReceiverScope @Component(parent = HabitsApplicationComponent) exposing the same single binding widgetController: WidgetBehavior. FireSettingReceiver.onReceive creates it per broadcast.
4. `platform-glue.di-receiver-components#4` — Both receivers reach the application graph via (context.applicationContext as HabitsApplication).component; if HabitsApplication has not run onCreate the static component is uninitialized and this throws.
5. `platform-glue.di-receiver-components#5` — A new WidgetBehavior instance is therefore created per broadcast; WidgetBehavior itself holds no mutable state, so this is safe.

#### platform-glue.tasker-action-constants

- [ ] `platform-glue.tasker-action-constants` — Tasker/Locale plugin action constants and extras contract
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/automation/FireSettingReceiver.kt`, `uhabits-android/src/main/AndroidManifest.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** No Flutter equivalent. Requires a native Android Activity + BroadcastReceiver in the Flutter app's android/ source set, bridged to Dart via a MethodChannel (or reimplemented entirely natively).

1. `platform-glue.tasker-action-constants#1` — Five integer action constants are defined and are part of the persisted plugin payload: ACTION_CHECK = 0, ACTION_UNCHECK = 1, ACTION_TOGGLE = 2, ACTION_INCREMENT = 3, ACTION_DECREMENT = 4.
2. `platform-glue.tasker-action-constants#2` — The bundle extra key is the literal string "com.twofortyfouram.locale.intent.extra.BUNDLE" (constant EXTRA_BUNDLE).
3. `platform-glue.tasker-action-constants#3` — The blurb extra key is the literal string "com.twofortyfouram.locale.intent.extra.BLURB" (constant EXTRA_STRING_BLURB).
4. `platform-glue.tasker-action-constants#4` — Inside the bundle, the action is stored under key "action" as an Int and the habit id under key "habit" as a Long.
5. `platform-glue.tasker-action-constants#5` — The edit Activity responds to intent action "com.twofortyfouram.locale.intent.action.EDIT_SETTING"; the fire receiver responds to "com.twofortyfouram.locale.intent.action.FIRE_SETTING".
6. `platform-glue.tasker-action-constants#6` — These string keys must be preserved byte-for-byte: existing Tasker/Locale tasks stored on the user's device contain them.

#### platform-glue.tasker-parse-intent

- [ ] `platform-glue.tasker-parse-intent` — Tasker setting intent parsing (SettingUtils.parseIntent)
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/automation/SettingUtils.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** The parsing logic itself is pure and portable; only the Bundle/Intent transport is Android-specific.

1. `platform-glue.tasker-parse-intent#1` — SettingUtils.parseIntent(intent, allHabits) returns null if intent.getBundleExtra("com.twofortyfouram.locale.intent.extra.BUNDLE") is null.
2. `platform-glue.tasker-parse-intent#2` — It reads action = bundle.getInt("action") — missing key yields 0, i.e. ACTION_CHECK.
3. `platform-glue.tasker-parse-intent#3` — It returns null if action < 0 or action > 4 (inclusive bounds check against the 5 valid actions).
4. `platform-glue.tasker-parse-intent#4` — It returns null if allHabits.getById(bundle.getLong("habit")) is null (habit deleted) — a missing "habit" key yields 0L which will normally not match any habit.
5. `platform-glue.tasker-parse-intent#5` — On success it returns Arguments(action, habit), a mutable holder with fields `action: Int` and `habit: Habit`.
6. `platform-glue.tasker-parse-intent#6` — The same parse function is used by both EditSettingActivity (to pre-populate the edit form) and FireSettingReceiver (to execute the action).

#### platform-glue.tasker-edit-setting-screen

- [ ] `platform-glue.tasker-edit-setting-screen` — Tasker plugin edit screen (EditSettingActivity / EditSettingRootView)
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/automation/EditSettingActivity.kt`, `.../automation/EditSettingRootView.kt`, `uhabits-android/src/main/res/layout/automation.xml`, `uhabits-android/src/main/res/values/constants.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Note the archived-habit inconsistency described in rule 1 — it is real current behavior. The screen must be a native Android Activity because Tasker launches it with startActivityForResult and reads setResult().

1. `platform-glue.tasker-edit-setting-screen#1` — EditSettingActivity.onCreate computes habits = habitList.getFiltered(HabitMatcher(isArchivedAllowed = false, isCompletedAllowed = true)) and passes only the *unfiltered* app.component.habitList to the root view — so the spinner actually lists ALL habits including archived ones; the filtered list is only used to resolve the incoming Arguments.
2. `platform-glue.tasker-edit-setting-screen#2` — The activity applies AndroidThemeSwitcher(this, preferences).apply() before inflating, so the plugin screen follows the app's light/dark setting.
3. `platform-glue.tasker-edit-setting-screen#3` — The toolbar title is @string/app_name ("Loop Habit Tracker"), toolbar color is PaletteColor(11) (blue #1976D2), and displayHomeAsUpEnabled = false.
4. `platform-glue.tasker-edit-setting-screen#4` — The habit spinner is populated with habit names in habit-list order using android.R.layout.simple_spinner_item, with simple_spinner_dropdown_item as the dropdown view.
5. `platform-glue.tasker-edit-setting-screen#5` — The action spinner content depends on the selected habit's type: numerical habits get R.array.actions_numerical = [Increment, Decrement]; yes/no habits get R.array.actions_yes_no = [Check, Uncheck, Toggle]. It is repopulated every time the habit spinner selection changes.
6. `platform-glue.tasker-edit-setting-screen#6` — mapSpinnerPositionToAction: for numerical habits, position 0 -> ACTION_INCREMENT (3) and any other position -> ACTION_DECREMENT (4); for boolean habits, 0 -> ACTION_CHECK (0), 1 -> ACTION_UNCHECK (1), anything else -> ACTION_TOGGLE (2).
7. `platform-glue.tasker-edit-setting-screen#7` — mapActionToSpinnerPosition: CHECK->0, UNCHECK->1, TOGGLE->2, INCREMENT->0, DECREMENT->1, anything else->0.
8. `platform-glue.tasker-edit-setting-screen#8` — When re-editing an existing plugin setting (args != null), the habit spinner is set to habitList.indexOf(args.habit), the action spinner is repopulated for that habit's type, then set to mapActionToSpinnerPosition(args.action).
9. `platform-glue.tasker-edit-setting-screen#9` — Pressing Save reads the habit at binding.habitSpinner.selectedItemPosition from the habit list and the action from the action spinner, then invokes the controller.
10. `platform-glue.tasker-edit-setting-screen#10` — The screen layout is a toolbar with an inline outlined MaterialButton labeled @string/save, over two form boxes labeled @string/habit and @string/action.

#### platform-glue.tasker-edit-setting-result

- [ ] `platform-glue.tasker-edit-setting-result` — Tasker plugin edit result (EditSettingController.onSave)
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/automation/EditSettingController.kt`
- **Kotlin tests:** none — write Dart test from rules

1. `platform-glue.tasker-edit-setting-result#1` — onSave(habit, action) returns immediately without setting any result if habit.id == null (unsaved habit).
2. `platform-glue.tasker-edit-setting-result#2` — The blurb is built as String.format("%s: %s", actionName, habit.name), e.g. "Check: Exercise".
3. `platform-glue.tasker-edit-setting-result#3` — actionName is the localized string for the action: ACTION_CHECK -> R.string.check ("Check"), ACTION_UNCHECK -> R.string.uncheck ("Uncheck"), ACTION_TOGGLE -> R.string.toggle ("Toggle"), ACTION_INCREMENT -> R.string.increment ("Increment"), ACTION_DECREMENT -> R.string.decrement ("Decrement"), and any other value -> the literal string "???".
4. `platform-glue.tasker-edit-setting-result#4` — The result Intent carries EXTRA_STRING_BLURB = the blurb string and EXTRA_BUNDLE = a Bundle containing int "action" and long "habit".
5. `platform-glue.tasker-edit-setting-result#5` — setResult(Activity.RESULT_OK, intent) is called followed by finish(); the activity never returns RESULT_CANCELED explicitly (back-press yields the platform default cancel).

#### platform-glue.tasker-fire-setting

- [ ] `platform-glue.tasker-fire-setting` — Tasker plugin execution (FireSettingReceiver)
- **Platform:** android-only · **Port risk:** high
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/automation/FireSettingReceiver.kt`, `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehavior.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehaviorTest.kt`
- **Notes:** WidgetBehaviorTest covers the five behaviors but with amount=100, not the 1000 used by the Tasker path.

1. `platform-glue.tasker-fire-setting#1` — FireSettingReceiver.onReceive resolves the app DI graph, parses the intent with SettingUtils.parseIntent(intent, habitList) and returns silently if parsing yields null.
2. `platform-glue.tasker-fire-setting#2` — The date used for the action is getToday() — the app's midnight-delay-adjusted today, not the raw system date.
3. `platform-glue.tasker-fire-setting#3` — ACTION_CHECK (0) calls WidgetBehavior.onAddRepetition(habit, today), which cancels the habit's notification and writes Entry.YES_MANUAL (value 2) preserving existing notes.
4. `platform-glue.tasker-fire-setting#4` — ACTION_UNCHECK (1) calls onRemoveRepetition(habit, today), which cancels the notification and writes Entry.NO (value 0) preserving notes.
5. `platform-glue.tasker-fire-setting#5` — ACTION_TOGGLE (2) calls onToggleRepetition(habit, today), which computes Entry.nextToggleValue(currentValue, isSkipEnabled = prefs.isSkipEnabled, areQuestionMarksEnabled = prefs.areQuestionMarksEnabled), writes it, then cancels the notification.
6. `platform-glue.tasker-fire-setting#6` — ACTION_INCREMENT (3) calls onIncrement(habit, today, 1000) — a hard-coded amount of 1000, i.e. exactly +1.0 unit since numerical values are stored scaled by 1000.
7. `platform-glue.tasker-fire-setting#7` — ACTION_DECREMENT (4) calls onDecrement(habit, today, 1000), i.e. exactly -1.0 unit; the result is NOT clamped at zero, so decrementing from 0 yields -1000.
8. `platform-glue.tasker-fire-setting#8` — Increment/decrement read the current value from habit.computedEntries (not originalEntries), while add/remove/toggle read from habit.originalEntries.
9. `platform-glue.tasker-fire-setting#9` — All five actions ultimately run a CreateRepetitionCommand(habitList, habit, date, newValue, notes) through the CommandRunner, so widgets, notifications and reminders all refresh through the normal listener chain.
10. `platform-glue.tasker-fire-setting#10` — The receiver holds a `lateinit var allHabits` field assigned on each onReceive; it does not persist across broadcasts.

#### platform-glue.habit-content-uri

- [ ] `platform-glue.habit-content-uri` — Habit content URI scheme
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt`, `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt`, `.../notifications/SnoozeDelayPickerActivity.kt`
- **Kotlin tests:** `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitTest.kt`
- **Notes:** HabitTest.kt line 120 asserts the exact URI string. Keeping this format is required for backward compatibility of existing widgets and Tasker tasks.

1. `platform-glue.habit-content-uri#1` — Habit.uriString is exactly "content://org.isoron.uhabits/habit/$id" — e.g. a habit with id 0 yields "content://org.isoron.uhabits/habit/0".
2. `platform-glue.habit-content-uri#2` — All habit-carrying intents put this URI in Intent.data, and the receiving side recovers the id with android.content.ContentUris.parseId(uri), i.e. by parsing the last path segment as a Long.
3. `platform-glue.habit-content-uri#3` — The manifest intent-filters for WidgetReceiver match data with android:scheme="content" and android:host="org.isoron.uhabits" (no path restriction) plus category android.intent.category.DEFAULT.
4. `platform-glue.habit-content-uri#4` — There are exactly 4 externally-matchable data intent-filters on WidgetReceiver, one per action: org.isoron.uhabits.ACTION_SET_NUMERICAL_VALUE, ACTION_TOGGLE_REPETITION, ACTION_ADD_REPETITION, ACTION_REMOVE_REPETITION.
5. `platform-glue.habit-content-uri#5` — Note the manifest advertises org.isoron.uhabits.ACTION_SET_NUMERICAL_VALUE but WidgetReceiver has no branch for it, so such a broadcast parses the checkmark data and then does nothing.
6. `platform-glue.habit-content-uri#6` — ShowHabitActivity.onCreate resolves its habit with habitList.getById(ContentUris.parseId(intent.data!!))!! and will crash with NPE if the data is missing or the habit was deleted.
7. `platform-glue.habit-content-uri#7` — SnoozeDelayPickerActivity finishes immediately if intent.data is null, and finishes if the habit id does not resolve.
8. `platform-glue.habit-content-uri#8` — There is no ContentProvider actually serving content://org.isoron.uhabits — the scheme is used purely as an opaque intent-addressing convention. The only real provider is the FileProvider registered on the same authority.

#### platform-glue.deep-link-edit-entry

- [ ] `platform-glue.deep-link-edit-entry` — ACTION_EDIT deep link into the habit list
- **Platform:** android-only · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/intents/PendingIntentFactory.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** This is the path a numerical widget uses to pop the value-entry dialog.

1. `platform-glue.deep-link-edit-entry#1` — ListHabitsActivity.ACTION_EDIT is the literal string "org.isoron.uhabits.ACTION_EDIT".
2. `platform-glue.deep-link-edit-entry#2` — parseIntents() runs at the end of every onResume, before super.onResume().
3. `platform-glue.deep-link-edit-entry#3` — If intent.action == ACTION_EDIT and both long extras "habit" and "timestamp" are present, the activity resolves the habit with habitList.getById(habitId)!! and calls listHabitsBehavior.onEdit(habit, LocalDate.fromUnixTime(timestampMillis), 0f, 0f) — the 0f,0f coordinates suppress the confetti animation.
4. `platform-glue.deep-link-edit-entry#4` — After parsing, `intent` is set to null so the same deep link is never handled twice on a subsequent resume.
5. `platform-glue.deep-link-edit-entry#5` — onNewIntent stores the new intent via setIntent(intent); because launchMode is singleTop, a second widget tap reuses the existing activity instance.
6. `platform-glue.deep-link-edit-entry#6` — If the habit id does not resolve, the non-null assertion throws (uncaught) — there is no graceful "habit not found" path on this route.

#### platform-glue.crash-handler

- [ ] `platform-glue.crash-handler` — Uncaught exception handler (BaseExceptionHandler)
- **Platform:** android-only · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/BaseExceptionHandler.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Flutter equivalent: FlutterError.onError + PlatformDispatcher.onError + runZonedGuarded, writing to the same Logs directory.

1. `platform-glue.crash-handler#1` — BaseExceptionHandler captures Thread.getDefaultUncaughtExceptionHandler() at construction time and stores it as originalHandler.
2. `platform-glue.crash-handler#2` — It is installed exactly once, in ListHabitsActivity.onCreate, via Thread.setDefaultUncaughtExceptionHandler(BaseExceptionHandler(this)) — after the DI component and views are built, before behavior.onStartup().
3. `platform-glue.crash-handler#3` — uncaughtException returns immediately (doing nothing, not even delegating) if either the throwable or the thread argument is null.
4. `platform-glue.crash-handler#4` — Otherwise it calls ex.printStackTrace(), then AndroidBugReporter(activity).dumpBugReportToFile(), each wrapped so that any Exception from the dump is caught and its stack trace printed.
5. `platform-glue.crash-handler#5` — Finally it delegates to originalHandler?.uncaughtException(thread, ex) so the platform's normal crash dialog / process kill still happens.
6. `platform-glue.crash-handler#6` — Because installation happens in onCreate of the list activity only, crashes occurring before that activity opens (e.g. in Application.onCreate or in a broadcast receiver) are NOT dumped to a log file.

#### platform-glue.dir-finder

- [ ] `platform-glue.dir-finder` — External storage directory resolution (AndroidDirFinder / FileUtils.getDir)
- **Platform:** android-only · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/AndroidDirFinder.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/FileUtils.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/HabitsDirFinder.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/database/AutoBackupTest.kt`
- **Notes:** path_provider's getExternalStorageDirectories covers this; the "first writable" rule and the silent-null failure mode must be preserved.

1. `platform-glue.dir-finder#1` — AndroidDirFinder.getFilesDir(relativePath) calls FileUtils.getDir(ContextCompat.getExternalFilesDirs(context, null), relativePath).
2. `platform-glue.dir-finder#2` — FileUtils.getDir picks the FIRST directory in the candidate array for which File.canWrite() is true; if none is writable it logs Log.e("FileUtils", "getDir: all potential parents are null or non-writable") and returns null.
3. `platform-glue.dir-finder#3` — It then builds File("<chosenDir.absolutePath>/<relativePath>/") and, if it does not exist, attempts mkdirs(); if creation fails it logs "getDir: chosen dir does not exist and cannot be created" and returns null.
4. `platform-glue.dir-finder#4` — FileUtils.getSDCardDir(relativePath) is a variant that uses only Environment.getExternalStorageDirectory() as the candidate parent.
5. `platform-glue.dir-finder#5` — Three well-known relative paths are used by the app: "Logs" (bug reports), "CSV" (CSV export), "Backups" (automatic database backups).
6. `platform-glue.dir-finder#6` — HabitsDirFinder implements both ShowHabitMenuPresenter.System and ListHabitsBehavior.DirFinder; getCSVOutputDir() returns JavaUserFile(androidDirFinder.getFilesDir("CSV")!!.toPath()) and will throw NPE if the CSV directory cannot be created.

#### platform-glue.localization-inventory

- [ ] `platform-glue.localization-inventory` — Localization inventory: locales, keys, plurals, formatted strings
- **Platform:** core · **Port risk:** medium
- **Source:** `uhabits-android/src/main/res/values/strings.xml`, `.../values/constants.xml`, `.../values/fontawesome.xml`, `.../values/pickers.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** For ARB: the 6 plurals become ICU {count, plural, ...} messages needing zero/two/few/many for ar/ru/pl/uk/hr/cs/sk/sl/sr/ro; x_times_per_y_days needs two named args; version_n needs a string arg. The 365 fontawesome glyphs and the 10 URLs should stay as constants, not localized resources.

1. `platform-glue.localization-inventory#1` — There are 47 translated locale resource directories plus the default `values` directory: af-ZA, ar-SA, bg-BG, ca-ES, cs-CZ, da-DK, de-DE, el-GR, eo-UY, es-ES, eu-ES, fa-IR, fi-FI, fr-FR, gu-IN, hi-IN, hr-HR, hu-HU, hy-AM, in-ID, is-IS, it-IT, iw-IL, ja-JP, ka-GE, ko-KR, ml-IN, nl-NL, no-NO, pl-PL, pt-BR, pt-PT, ro-RO, ru-RU, sk-SK, sl-SI, sr-CS, sr-SP, sv-SE, ta-IN, te-IN, tr-TR, ug-CN, uk-UA, vi-VN, zh-CN, zh-TW. Each locale directory contains exactly one file: strings.xml.
2. `platform-glue.localization-inventory#2` — The default res/values/strings.xml contains 195 named resources: 188 <string>, 6 <plurals>, and 1 <string-array> ("hints"). No translated locale defines any key that does not exist in the default file (zero obsolete keys).
3. `platform-glue.localization-inventory#3` — Exactly one string is marked translatable="false" in strings.xml: title_activity_show_habit (an empty string used as the ShowHabitActivity label).
4. `platform-glue.localization-inventory#4` — 10 strings are never translated in any complete locale, so a fully translated locale has 178 strings: checkmark_stack_widget, frequency_stack_widget, history_stack_widget, score_stack_widget, streaks_stack_widget, pref_animations_description, pref_animations_title, search, skip_day, title_activity_show_habit.
5. `platform-glue.localization-inventory#5` — There are exactly 6 plurals keys: toast_habits_changed, toast_habits_deleted, toast_habits_archived, toast_habits_unarchived, delete_habits_title, delete_habits_message. The default locale defines only quantity="one" and quantity="other" for each.
6. `platform-glue.localization-inventory#6` — Across all locales the plural quantity classes used are: other (226 items), one (190), few (58), many (42), two (18), zero (6). Only values-ar-rSA uses quantity="zero"; ARB must therefore support zero/one/two/few/many/other for Arabic and the Slavic locales.
7. `platform-glue.localization-inventory#7` — There are exactly 6 format-bearing strings, all positional-free Java format specifiers: version_n = "Version %s"; every_x_days = "Every %d days"; every_x_weeks = "Every %d weeks"; x_times_per_week = "%d times per week"; x_times_per_month = "%d times per month"; x_times_per_y_days = "%d times in %d days" (TWO arguments, order-sensitive — must become named placeholders in ARB).
8. `platform-glue.localization-inventory#8` — Five strings carry formatted="false" in strings.xml (checkmark_stack_widget, frequency_stack_widget, score_stack_widget, history_stack_widget, streaks_stack_widget) and four in constants.xml (feedbackURL, privacyPolicyURL, codeContributorsURL, syncBaseURL) because they contain literal % characters or are URL-encoded.
9. `platform-glue.localization-inventory#9` — Translation completeness by locale (count of <string> entries present): af-ZA 22, gu-IN 2, ug-CN 12, te-IN 36, hy-AM 66, no-NO 120, eo-UY 135, is-IS 146, pt-PT 162, hr-HR 167, sr-CS 171, ro-RO 172, eu-ES 176, ca-ES 177, da-DK 177, hu-HU/in-ID/sv-SE/uk-UA 183 (they additionally translate the 5 stack-widget strings), and all remaining locales 178.
10. `platform-glue.localization-inventory#10` — Plural coverage by locale is uneven: af-ZA, eo-UY, gu-IN, hy-AM, no-NO, pt-PT, te-IN and ug-CN define 0 plurals; ro-RO defines 1; is-IS 2; hr-HR 3; ca-ES 4; every other locale defines all 6.
11. `platform-glue.localization-inventory#11` — in-ID, sv-SE and uk-UA additionally translate the <string-array name="hints">; no other locale does.
12. `platform-glue.localization-inventory#12` — The default strings.xml root element carries tools:ignore="MissingTranslation", so missing translations do not fail the build; at runtime Android falls back to the default (English) value per key.
13. `platform-glue.localization-inventory#13` — res/values/fontawesome.xml holds 365 <string> resources, every one marked translatable="false" — they are FontAwesome glyph codepoints (e.g. fa_check = ) and must NOT be exported to ARB.
14. `platform-glue.localization-inventory#14` — res/values/constants.xml holds 10 URL/email <string> resources (helpURL, playStoreURL, feedbackURL, privacyPolicyURL, codeContributorsURL, sourceCodeURL, translateURL, bugReportTo, bugReportSubject, syncBaseURL) plus 7 arrays.
15. `platform-glue.localization-inventory#15` — res/values/pickers.xml holds 21 <string> resources but they are dimension/float constants for the date-time picker, all translatable="false" where declared as <item ... type="string">.

#### platform-glue.locale-config

- [ ] `platform-glue.locale-config` — Per-app language (locales_config.xml) and its drift from the resource dirs
- **Platform:** android-only · **Port risk:** medium
- **Source:** `uhabits-android/src/main/res/xml/locales_config.xml`, `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/src/main/res/xml/preferences.xml`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseAndroidTest.kt`
- **Notes:** In Flutter, supportedLocales replaces this; the gu/is/ka/ml omission and the sl-SL/sl-SI mismatch are current bugs that should be fixed rather than reproduced. (Merged duplicate id: `settings.localization.locales-config`.)

1. `platform-glue.locale-config#1` — android:localeConfig="@xml/locales_config" enables the Android 13+ per-app language picker in system settings.
2. `platform-glue.locale-config#2` — locales_config.xml lists exactly 44 <locale> entries, starting with "en" (which has no values-en directory; it is the default resource set).
3. `platform-glue.locale-config#3` — Four locales have translated resource directories but are MISSING from locales_config, so users cannot select them from the system per-app language picker even though the translations ship: gu-IN, is-IS, ka-GE, ml-IN.
4. `platform-glue.locale-config#4` — locales_config declares "sl-SL", but the resource directory is values-sl-rSI — the region subtag does not match, so the Slovenian entry in the picker does not resolve to the shipped Slovenian resources.
5. `platform-glue.locale-config#5` — Deprecated ISO codes are used throughout and must be preserved for Android resource resolution: "in-ID" for Indonesian (not id-ID) and "iw-IL" for Hebrew (not he-IL).
6. `platform-glue.locale-config#6` — Both Serbian scripts ship separately: sr-CS (Latin) and sr-SP (Cyrillic); both Chinese scripts ship separately: zh-CN (Simplified) and zh-TW (Traditional); both Portuguese variants ship: pt-BR and pt-PT.
7. `platform-glue.locale-config#7` — RTL support is enabled application-wide (android:supportsRtl="true") for ar-SA, fa-IR, iw-IL and ug-CN.
8. `platform-glue.locale-config#8` — Instrumentation tests force the locale to en/US via BaseAndroidTest.setLocale("en", "US") plus Locale.setDefault.
9. `platform-glue.locale-config#9` — res/xml/locales_config.xml declares the supported per-app locales, starting with "en" and including af-ZA, ar-SA, bg-BG, ca-ES, cs-CZ, da-DK, de-DE, el-GR, eo-UY, es-ES, eu-ES, fa-IR, fi-FI, fr-FR, hi-IN, hr-HR, hu-HU, hy-AM, in-ID, it-IT, iw-IL, ja-JP, ko-KR, nl-NL, no-NO, pl-PL, pt-BR and the remaining entries of that file.
10. `platform-glue.locale-config#10` — There is no in-app language-selection row in preferences.xml; language selection is delegated entirely to the Android 13+ per-app language system setting driven by this locale-config.
11. `platform-glue.locale-config#11` — All user-facing settings strings are localized resources except the Development category title "Development" and its row title "Enable developer mode", which are hard-coded English in preferences.xml.

#### platform-glue.localized-arrays

- [ ] `platform-glue.localized-arrays` — Localizable string arrays and their index contracts
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/res/values/constants.xml`, `uhabits-android/src/main/res/values/strings.xml`, `uhabits-android/src/main/res/xml/preferences.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** ARB has no array concept; each array becomes an explicit ordered list of message ids in Dart.

1. `platform-glue.localized-arrays#1` — snooze_picker_names has 8 entries in this order and must stay index-aligned with the integer array snooze_picker_values [15, 30, 60, 120, 240, 480, 1440, -1]: interval_15_minutes, interval_30_minutes, interval_1_hour, interval_2_hour, interval_4_hour, interval_8_hour, interval_24_hour, interval_custom.
2. `platform-glue.localized-arrays#2` — actions_yes_no is translatable="false" and has 3 entries in order: @string/check, @string/uncheck, @string/toggle (mapping to actions 0, 1, 2).
3. `platform-glue.localized-arrays#3` — actions_numerical is translatable="false" and has 2 entries in order: @string/increment, @string/decrement (mapping to actions 3, 4).
4. `platform-glue.localized-arrays#4` — strengthIntervalNames has 5 entries: day, week, month, quarter, year; strengthIntervalNamesWithoutDay has 4: week, month, quarter, year.
5. `platform-glue.localized-arrays#5` — widget_opacity_entries are ["100%", "80%", "60%", "40%", "20%", "0%"] index-aligned with widget_opacity_values [255, 204, 153, 102, 51, 0]; the default persisted value is the string "255".
6. `platform-glue.localized-arrays#6` — string-array "hints" contains exactly 2 items, referencing @string/hint_drag and @string/hint_landscape.
7. `platform-glue.localized-arrays#7` — interval_always_ask ("Always ask") is defined but is not referenced by the snooze_picker_names array.

#### platform-glue.translators-credits-generation

- [ ] `platform-glue.translators-credits-generation` — Auto-generated translator credits
- **Platform:** android-only · **Port risk:** medium
- **Source:** `gradle/translators.gradle.kts`, `build.gradle.kts`, `uhabits-android/build.gradle.kts`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** In a Flutter port this becomes a build-time script generating a Dart list; the CSV thresholds and name-normalisation rules are the load-bearing part.

1. `platform-glue.translators-credits-generation#1` — The Gradle task `updateTranslators` (wired as a dependency of compileLint) regenerates uhabits-android/src/main/res/layout/about_translators.xml from two CSV files at the repo root: translators-classic.csv (columns Language, Name) and translators-crowdin.csv (columns Languages, Name, "Winning (Words)", "Translated (Words)", "Approved (Words)").
2. `platform-glue.translators-credits-generation#2` — For Crowdin rows, only the first language before the first ";" is used, and it is mapped through a 35-entry English-name -> endonym table (e.g. "German" -> "Deutsch", "Japanese" -> "日本語", "Chinese Simplified" and "Chinese Traditional" both -> "中文", "Persian" and "Arabic" both -> "العَرَبِية‎", "Serbian (Cyrillic)" and "Serbian (Latin)" both -> "српски").
3. `platform-glue.translators-credits-generation#3` — A Crowdin translator name has any parenthesised suffix stripped by the regex " *\\(.*\\) *"; any name containing "REMOVED" is skipped entirely.
4. `platform-glue.translators-credits-generation#4` — A Crowdin row is skipped unless it passes the threshold: it is included only if Winning(Words) >= 10 OR Translated(Words) >= 100 OR Approved(Words) > 0.
5. `platform-glue.translators-credits-generation#5` — Duplicate names within the same language are skipped; each language's names list is kept sorted alphabetically, and languages are emitted in sorted-map (alphabetical) order.
6. `platform-glue.translators-credits-generation#6` — The generated file is only rewritten when its content actually differs, and carries the comment "This list is automatically generated, do not edit manually."
7. `platform-glue.translators-credits-generation#7` — The generated layout is a LinearLayout with style @style/Card and gravity center, a header TextView with @string/translators, then per language a TextView with style @style/About.Item.Language and per translator a TextView with style @style/About.Item.

#### platform-glue.time-and-date-formatting

- [ ] `platform-glue.time-and-date-formatting` — Locale-aware time and date formatting helpers
- **Platform:** core · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/DateExtensions.kt`, `uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateFormats.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/AndroidBugReporter.kt`
- **Kotlin tests:** `uhabits-core/src/jvmTest/java/org/isoron/platform/time/JavaLocalDateFormatterTest.kt`, `uhabits-core/src/jvmTest/java/org/isoron/platform/time/DateUtilsTest.kt`
- **Notes:** Dart's intl package covers skeletons; the UTC-forcing trick in formatTime must be replicated or times will shift.

1. `platform-glue.time-and-date-formatting#1` — formatTime(context, hours, minutes) converts to milliseconds as (hours * 60 + minutes) * 60 * 1000L, builds a Date from it, formats with android.text.format.DateFormat.getTimeFormat(context) and forces the formatter's TimeZone to UTC so the value is not shifted — the result therefore respects the user's 12h/24h system setting.
2. `platform-glue.time-and-date-formatting#2` — String.toSimpleDataFormat() treats the receiver as a skeleton, resolves it with DateFormat.getBestDateTimePattern(Locale.getDefault(), skeleton) and returns DateFormats.fromSkeleton(pattern, locale).
3. `platform-glue.time-and-date-formatting#3` — DateFormats.getBackupDateFormat() is fixed to the pattern "yyyy-MM-dd HHmmss" in Locale.US and is used both for backup filenames and for the alarm-scheduling log line.
4. `platform-glue.time-and-date-formatting#4` — Bug report log filenames use SimpleDateFormat("yyyy-MM-dd HHmmss", Locale.US) — the same pattern, constructed independently.

#### platform-glue.dimension-utils

- [ ] `platform-glue.dimension-utils` — Density conversion and resource dimension helpers (InterfaceUtils)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/InterfaceUtils.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseAndroidTest.kt`, `.../BaseViewTest.kt`
- **Notes:** Flutter's logical pixels remove most of this; the sp-vs-dp distinction maps to MediaQuery.textScaler.

1. `platform-glue.dimension-utils#1` — InterfaceUtils holds a nullable static `fixedResolution: Float`; when set (only by tests, via setFixedResolution) dpToPixels(dp) returns dp * fixedResolution and spToPixels(sp) returns sp * fixedResolution, bypassing the device metrics entirely.
2. `platform-glue.dimension-utils#2` — When fixedResolution is null, dpToPixels uses TypedValue.applyDimension(COMPLEX_UNIT_DIP, dp, displayMetrics) and spToPixels uses COMPLEX_UNIT_SP, so sp values honour the user's font-scale setting while dp values do not.
3. `platform-glue.dimension-utils#3` — getDimension(context, id) returns resources.getDimension(id); when fixedResolution is set it rescales as dim / displayMetrics.density * fixedResolution.
4. `platform-glue.dimension-utils#4` — getFontAwesome(context) lazily creates and caches a single static Typeface from the asset "fontawesome-webfont.ttf".
5. `platform-glue.dimension-utils#5` — setupEditorAction(parent, listener) walks the view tree depth-first and attaches the OnEditorActionListener to every TextView descendant (recursing into every ViewGroup).
6. `platform-glue.dimension-utils#6` — isLayoutRtl(view) returns ViewCompat.getLayoutDirection(view) == ViewCompat.LAYOUT_DIRECTION_RTL and NPEs on a null view (the parameter is force-unwrapped).
7. `platform-glue.dimension-utils#7` — Instrumentation tests fix the resolution at 2.0f (BaseAndroidTest.setResolution(2.0f)) so rendered-view screenshots are deterministic.

#### platform-glue.styled-resources

- [ ] `platform-glue.styled-resources` — Theme attribute resolution (StyledResources)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/StyledResources.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseAndroidTest.kt`
- **Notes:** Android theme attributes have no Flutter equivalent; a port replaces them with a Theme/ThemeExtension object.

1. `platform-glue.styled-resources#1` — StyledResources resolves a single @AttrRes id at a time through context.obtainStyledAttributes(intArrayOf(attrId)) and always recycles the TypedArray.
2. `platform-glue.styled-resources#2` — It supports getBoolean (default false), getDimension as getDimensionPixelSize (default 0), getColor (default 0), getDrawable, getFloat (default 0f), and getResource as getResourceId (default -1).
3. `platform-glue.styled-resources#3` — getPalette() resolves R.attr.palette to a resource id and returns context.resources.getIntArray of it; it throws RuntimeException("palette resource not found") if the resolved id is < 0.
4. `platform-glue.styled-resources#4` — A static nullable `fixedTheme: Int?` (set only by tests via setFixedTheme) makes every lookup use context.theme.obtainStyledAttributes(fixedTheme, attrs) instead of the context's current theme.
5. `platform-glue.styled-resources#5` — View.sres is an extension property returning StyledResources(context).

#### platform-glue.attribute-set-utils

- [ ] `platform-glue.attribute-set-utils` — Custom XML attribute parsing (AttributeSetUtils)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/AttributeSetUtils.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Only relevant if custom Android views are kept; a pure Flutter port drops this entirely.

1. `platform-glue.attribute-set-utils#1` — All lookups use the custom namespace constant ISORON_NAMESPACE = "http://isoron.org/android".
2. `platform-glue.attribute-set-utils#2` — getAttribute first tries attrs.getAttributeResourceValue(ns, name, 0); if that returns non-zero it resolves it via resources.getString(resId); otherwise it falls back to attrs.getAttributeValue(ns, name); otherwise it returns the supplied default.
3. `platform-glue.attribute-set-utils#3` — getBooleanAttribute parses the string with java.lang.Boolean.parseBoolean (so anything other than a case-insensitive "true" is false) and returns the default only when the attribute is entirely absent.
4. `platform-glue.attribute-set-utils#4` — getColorAttribute returns resources.getColor(resId) when a resource reference is present, otherwise the default; it never parses a literal color string.
5. `platform-glue.attribute-set-utils#5` — getFloatAttribute catches NumberFormatException and returns the default; getIntAttribute does NOT catch it and will throw on a malformed value.

#### platform-glue.window-insets

- [ ] `platform-glue.window-insets` — Edge-to-edge window inset handling
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Flutter's SafeArea / MediaQuery.viewInsets covers this; the max(systemBars, displayCutout) combination and the black root background are the details worth keeping.

1. `platform-glue.window-insets#1` — applyRootViewInsets() installs an OnApplyWindowInsetsListener that pads the view left/right by max(systemBars.left, displayCutout.left) and max(systemBars.right, displayCutout.right), leaves top and bottom at 0, and sets the view background to a solid ColorDrawable(Color.BLACK).
2. `platform-glue.window-insets#2` — applyBottomInset() pads only the bottom, by max(systemBars.bottom, ime.bottom) — so the view lifts above the on-screen keyboard.
3. `platform-glue.window-insets#3` — applyToolbarInsets() pads only the top, by max(systemBars.top, displayCutout.top).
4. `platform-glue.window-insets#4` — All three listeners return the original insets unconsumed, so child views still receive them.
5. `platform-glue.window-insets#5` — applyRootViewInsets is called on the root view of ListHabitsActivity, ShowHabitActivity, EditSettingActivity (Tasker) and AboutView; applyToolbarInsets is applied inside View.setupToolbar; applyBottomInset is applied to the settings RecyclerView and the About screen's inner layout.
6. `platform-glue.window-insets#6` — setupToolbar sets the Activity window statusBarColor to the same color as the toolbar background; the toolbar color is StyledResources.getColor(R.attr.colorPrimary) unless R.attr.useHabitColorAsPrimary is true, in which case it is theme.color(paletteColor).toInt(). Toolbar elevation is fixed at dpToPixels(2f).

#### platform-glue.transient-ui-helpers

- [ ] `platform-glue.transient-ui-helpers` — Snackbars, single-dialog tracking, and activity restart
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`, `.../utils/DialogUtils.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** SnackBar and showDialog cover most of this in Flutter; the 500 ms restart delay and 250 ms synthetic-touch keyboard hack should be replaced, not ported.

1. `platform-glue.transient-ui-helpers#1` — View.showMessage(msg) shows a Snackbar of LENGTH_SHORT and forces the text color of the view with id R.id.snackbar_text to Color.WHITE; it catches IllegalArgumentException (no suitable parent found) and returns silently.
2. `platform-glue.transient-ui-helpers#2` — Activity.showMessage(msg) delegates to the android.R.id.content view.
3. `platform-glue.transient-ui-helpers#3` — DialogUtils keeps two module-level WeakReferences: currentDialog and currentDialogFragment. dismissCurrentDialog() dismisses whichever is alive and clears both references.
4. `platform-glue.transient-ui-helpers#4` — Dialog.dismissCurrentAndShow() and DialogFragment.dismissCurrentAndShow(fm, tag) each dismiss the previously tracked dialog first, then record themselves and show — guaranteeing at most one tracked dialog at a time. The DialogFragment variant also calls fragmentManager.executePendingTransactions().
5. `platform-glue.transient-ui-helpers#5` — dismissCurrentDialog() is called from ListHabitsActivity.onPause and ShowHabitActivity.onPause so no dialog leaks across a lifecycle change.
6. `platform-glue.transient-ui-helpers#6` — Activity.restartWithFade(cls) posts a delayed Runnable of exactly 500 ms that calls finish(), overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out) and startActivity(Intent(this, cls)) — the delay is an explicit hack to let the options menu close first.
7. `platform-glue.transient-ui-helpers#7` — restartWithFade is triggered from ListHabitsActivity.onResume when prefs.theme == THEME_DARK and prefs.isPureBlackEnabled differs from the value captured at onCreate.
8. `platform-glue.transient-ui-helpers#8` — Dialog.dimBehind() adds FLAG_DIM_BEHIND and sets the dim amount to exactly 0.5f.
9. `platform-glue.transient-ui-helpers#9` — View.requestFocusWithKeyboard() posts a delayed Runnable of exactly 250 ms that synthesises an ACTION_DOWN followed by an ACTION_UP MotionEvent at coordinates (0,0) to force the soft keyboard open (a deliberate workaround for unreliable InputMethodManager behavior).

#### platform-glue.test-mode-and-fixtures

- [ ] `platform-glue.test-mode-and-fixtures` — Test-mode detection and instrumentation harness contracts
- **Platform:** android-only · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/DatabaseUtils.kt`, `.../receivers/ReminderReceiver.kt`, `.../receivers/WidgetReceiver.kt`
- **Kotlin tests:** `uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseAndroidTest.kt`, `.../HabitsApplicationTestComponent.kt`, `.../HabitsActivityTestComponent.kt`, `.../intents/IntentSchedulerTest.kt`, `uhabits-android/src/test/java/org/isoron/uhabits/BaseAndroidJVMTest.kt`
- **Notes:** The Class.forName test-mode probe is a hack that should be replaced by a build flavour / --dart-define in the port. Note there are NO existing tests anywhere in the repo covering the automation/Tasker package.

1. `platform-glue.test-mode-and-fixtures#1` — HabitsApplication.isTestMode() returns true iff Class.forName("org.isoron.uhabits.BaseAndroidTest") does not throw ClassNotFoundException.
2. `platform-glue.test-mode-and-fixtures#2` — When test mode is on, DatabaseUtils uses the filename "test.db" instead of "uhabits.db", and HabitsApplication deletes that file at startup so each instrumentation run begins from an empty database.
3. `platform-glue.test-mode-and-fixtures#3` — BaseAndroidTest.setUp builds a HabitsApplicationTestComponent (which subclasses HabitsApplicationComponent and additionally exposes intentScheduler), assigns it to the static HabitsApplication.component, then clears preferences, purges habits and creates one empty habit fixture.
4. `platform-glue.test-mode-and-fixtures#4` — BaseAndroidTest pins the environment: display density 2.0f, theme R.style.AppBaseTheme, locale en/US, and setToday(LocalDate(2015, 1, 25)).
5. `platform-glue.test-mode-and-fixtures#5` — HabitsActivityTestComponent mirrors HabitsActivityComponent's interface bindings but provides a mocked ListHabitsBehavior.
6. `platform-glue.test-mode-and-fixtures#6` — IntentSchedulerTest manipulates the real device clock through UiDevice shell commands (`service call alarm 3 s16 <tz>`, `setprop persist.sys.timezone`, `date <MMDDhhmmYYYY.ss>`, `date -u @<epochSeconds>`) and sleeps 1000 ms for events to settle; it saves and restores the system time around each test.
7. `platform-glue.test-mode-and-fixtures#7` — ReminderReceiver.lastReceivedIntent and WidgetReceiver.lastReceivedIntent (with their clearLastReceivedIntent() resets) exist purely so these tests can assert an alarm actually fired.

## Domain: Gap-found (behaviour discovered outside the original inventory)

#### time-picker.haptic-feedback

- [ ] `time-picker.haptic-feedback` — Radial time picker haptic feedback (vibration ticks)
- **Platform:** needs-native-per-platform · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/com/android/datetimepicker/HapticFeedbackController.java`, `uhabits-android/src/main/java/com/android/datetimepicker/time/RadialPickerLayout.java`, `.../time/TimePickerDialog.java`, `uhabits-android/src/main/res/layout/time_picker_dialog.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Reached from both reminder-time selection (EditHabitActivity) and the snooze custom-time picker (SnoozeDelayPickerActivity). The index entry time-picker.radial-dialog covers TimePickerDialog/RadialPickerLayout but never mentions vibration; HapticFeedbackController.java is referenced by no inventory entry. In Flutter this needs a plugin (HapticFeedback / Vibration) plus the system-setting gate and the 125 ms throttle, neither of which Flutter's built-in showTimePicker reproduces. (Two identical gap entries merged.)

1. `time-picker.haptic-feedback#1` — Haptic feedback is emitted only when the system setting Settings.System.HAPTIC_FEEDBACK_ENABLED reads 1; the fallback default when the setting is absent is 0, i.e. disabled.
2. `time-picker.haptic-feedback#2` — A ContentObserver registered on Settings.System.getUriFor(HAPTIC_FEEDBACK_ENABLED) re-reads the flag while the dialog is open, so toggling the system-wide haptics setting takes effect without reopening the picker.
3. `time-picker.haptic-feedback#3` — Each individual vibration lasts exactly 5 ms (VIBRATE_LENGTH_MS = 5).
4. `time-picker.haptic-feedback#4` — Vibrations are throttled: a new pulse fires only if at least 125 ms (VIBRATE_DELAY_MS) of SystemClock.uptimeMillis have elapsed since the previous pulse; otherwise the request is silently dropped, so dragging around the dial produces discrete ticks instead of one continuous buzz.
5. `time-picker.haptic-feedback#5` — The controller acquires the Vibrator service and registers the observer in TimePickerDialog.onResume, and releases the Vibrator plus unregisters the observer in onPause; tryVibrate is a no-op before start() and after stop().
6. `time-picker.haptic-feedback#6` — Vibration fires on: ACTION_DOWN inside the AM circle or the PM circle; ACTION_DOWN on a legal number position on the dial; every drag movement that changes the selected value to a *different* value (repeats over the same value do not re-fire); tapping the hour label; tapping the minute label; tapping the AM/PM label; and tapping Done when not finishing keyboard-entry mode.
7. `time-picker.haptic-feedback#7` — Tapping the Clear button (the 'Off' action that removes the reminder) does not vibrate.
8. `time-picker.haptic-feedback#8` — Reachable from the Reminder row of the habit editor (activity_edit_habit.xml -> reminderTimePicker -> vendored TimePickerDialog / time_picker_dialog.xml).
9. `time-picker.haptic-feedback#9` — Every time the radial selector lands on a new hour or minute value, and on each hour<->minute switch and AM/PM toggle, the picker calls tryVibrate().

#### time-picker.clock-face-rendering

- [ ] `time-picker.clock-face-rendering` — Radial clock-face rendering and dial hit geometry (CircleView, AmPmCirclesView, RadialTextsView, RadialSelectorView)
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/java/com/android/datetimepicker/time/CircleView.java`, `.../time/AmPmCirclesView.java`, `.../time/RadialTextsView.java`, `.../time/RadialSelectorView.java`, `uhabits-android/src/main/java/com/android/datetimepicker/Utils.java`, `uhabits-android/src/main/res/values/pickers.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** The index's time-picker.radial-dialog entry lists only TimePickerDialog.java and RadialPickerLayout.java as covered; the four custom Views that actually draw the clock face and the Utils constants they share (SELECTED_ALPHA = 51, FULL_ALPHA = 255, PULSE_ANIMATOR_DURATION = 544) are referenced by no inventory entry, so the port has no spec for what the dial looks like or where its touch targets are. res/values/pickers.xml is listed as covered but its multiplier values are only meaningful together with these consumers. Separately: the sibling package com.android.datetimepicker.date (AccessibleDateAnimator, DatePickerController, DatePickerDialog, DayPickerView, MonthAdapter, MonthView, SimpleDayPickerView, SimpleMonthAdapter, SimpleMonthView, TextViewWithCircularIndicator, YearPickerView) plus the layouts date_picker_view_animator.xml, date_picker_selected_date.xml and year_label_text_view.xml are unreachable dead code — nothing outside that package references DatePickerDialog — so they are deliberately excluded and need no port.

1. `time-picker.clock-face-rendering#1` — Clock face radius = min(width/2, height/2) * circle_radius_multiplier, which is 0.82 in 12-hour mode and 0.85 (circle_radius_multiplier_24HourMode) in 24-hour mode; 24-hour vs 12-hour is chosen by DateFormat.is24HourFormat(context).
2. `time-picker.clock-face-rendering#2` — In 12-hour mode the face's vertical center is shifted up by half the AM/PM circle radius (clockRadius * 0.19 / 2) to make room for the AM/PM circles; in 24-hour mode there is no shift and no AM/PM circles are drawn at all.
3. `time-picker.clock-face-rendering#3` — CircleView fills the face with the theme attribute R.attr.contrast0 and additionally paints a 2 px dot of the same color at the exact center.
4. `time-picker.clock-face-rendering#4` — AM/PM circle radius = clockRadius * ampm_circle_radius_multiplier (0.19); both share vertical center layoutYCenter - r/2 + clockRadius; AM center x = layoutXCenter - clockRadius + r, PM center x = layoutXCenter + clockRadius - r.
5. `time-picker.clock-face-rendering#5` — AM/PM label text size = amPmCircleRadius * 3 / 4, and the label strings come from java.text.DateFormatSymbols().getAmPmStrings()[0] and [1], so they follow the device locale rather than the app's translated strings.
6. `time-picker.clock-face-rendering#6` — The selected AM/PM circle (and the one currently pressed) is filled with the selection color at alpha 51 (Utils.SELECTED_ALPHA); the unselected one is filled with R.attr.contrast0 at alpha 255; text is drawn on top in white (mAmPmTextColor = Color.WHITE).
7. `time-picker.clock-face-rendering#7` — AM/PM hit test is circular: a touch registers as AM/PM when its distance to the respective center is <= amPmCircleRadius, otherwise it returns -1 and the touch falls through to the dial. Before the first layout pass (mDrawValuesReady false) it always returns -1.
8. `time-picker.clock-face-rendering#8` — Numbers ring geometry: 12-hour mode draws one ring at radius clockRadius * 0.81 with text size clockRadius * 0.17; 24-hour mode draws two rings, outer at radius 0.83 / text size 0.11 and inner at radius 0.60 / text size 0.14. The outer/normal ring uses the R.string.radial_numbers_typeface family and the inner ring uses R.string.sans_serif.
9. `time-picker.clock-face-rendering#9` — The 12 labels of each ring are placed on a precomputed 7-column x 7-row grid, 30 degrees apart, starting at the top (index 0) and proceeding clockwise.
10. `time-picker.clock-face-rendering#10` — Selection disc radius = clockRadius * selection_radius_multiplier (0.16) and it is drawn at alpha 51.
11. `time-picker.clock-face-rendering#11` — A solid dot of radius selectionRadius * 2 / 7 is drawn at full alpha in the middle of the selection only when the selected angle is not a multiple of 30 degrees (the selection does not land on a printed number) or when forceDrawDot is requested; when the dot is omitted, the center line is shortened by selectionRadius so it stops at the edge of the selection disc instead of crossing it.
12. `time-picker.clock-face-rendering#12` — The hand from the center to the selection is stroked at width 1 with full alpha.
13. `time-picker.clock-face-rendering#13` — getDegreesFromCoords returns degrees measured clockwise from 12 o'clock (0 at top, 90 right, 180 bottom, 270 left). With two rings and forceLegal=false, the touch must fall between (innerRadius - selectionRadius) and (outerRadius + selectionRadius), with the midpoint radius (inner+outer)/2 deciding which ring; anything outside returns -1 and the touch is ignored. With forceLegal=true it always snaps to whichever ring center is nearer.
14. `time-picker.clock-face-rendering#14` — With a single ring and forceLegal=false the touch is ignored (-1) when |distanceFromCenter - ringRadius| exceeds clockRadius * (1 - numbersRadiusMultiplier).
15. `time-picker.clock-face-rendering#15` — When TalkBack touch exploration is enabled (AccessibilityManager.isTouchExplorationEnabled), forceLegal is turned on, so any touch inside the dial selects the nearest number instead of being rejected.
16. `time-picker.clock-face-rendering#16` — Switching between the hour ring and the minute ring plays a 500 ms disappear animation on the outgoing ring and selector (animationRadiusMultiplier keyframes 1 at t=0 -> 1 +/- 0.05 at t=0.2 -> 1 +/- 0.3 at t=1, with alpha 1 -> 0), staggered against a 625 ms reappear animation on the incoming ones (flat at the end multiplier until delayPoint = 0.2 of the total, then back to 1, alpha 0 -> 1). The disappearsOut flag inverts the signs so the hours ring shrinks inward while the minutes ring grows outward.
17. `time-picker.clock-face-rendering#17` — Tapping the hour or minute label pulses that label: scaleX/scaleY keyframes 1 at t=0 -> 0.85 at t=0.275 -> 1.1 at t=0.69 -> 1 at t=1, over 544 ms (Utils.PULSE_ANIMATOR_DURATION).

#### time-picker.accessibility-announcements

- [ ] `time-picker.accessibility-announcements` — Time picker accessibility roles and spoken announcements
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/com/android/datetimepicker/AccessibleTextView.java`, `.../AccessibleLinearLayout.java`, `.../Utils.java`, `.../time/TimePickerDialog.java`, `uhabits-android/src/main/res/layout/time_header_label.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Only user-visible to screen-reader users, but it is real behavior with no inventory entry: the two Accessible* classes are referenced by no covered file, and no feature in the index mentions accessibility roles or announceForAccessibility anywhere in the app. In Flutter this maps to Semantics(button: true, ...) plus SemanticsService.announce.

1. `time-picker.accessibility-announcements#1` — The hour label, minute label and AM/PM label in the picker header are AccessibleTextView / AccessibleLinearLayout subclasses that override onInitializeAccessibilityEvent and onInitializeAccessibilityNodeInfo to report className android.widget.Button, so screen readers announce them as buttons rather than as static text.
2. `time-picker.accessibility-announcements#2` — Every state change speaks through View.announceForAccessibility on the dial: toggling AM/PM announces the locale AM or PM string; selecting an hour or a minute announces the new time; switching to the hour ring announces the 'select hours' string and switching to the minute ring announces the 'select minutes' string; a digit typed in keyboard-entry mode is announced formatted as "%d".
3. `time-picker.accessibility-announcements#3` — Announcements are a no-op when either the view or the text is null (Utils.tryAccessibilityAnnounce guards both).

#### settings.developer.sync-preference-rows

- [ ] `settings.developer.sync-preference-rows` — Sync server / Sync key / Encryption key rows in the hidden Development category
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/res/values/constants.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** settings.screen.developer-category covers the category's existence and gating, but these three keys are XML-only (androidx.preference writes them directly) and therefore absent from Preferences.kt and from settings.preferences.key-catalog. Port decision this settles: do not build any sync/encryption feature; either drop the rows or reproduce them as inert.

1. `settings.developer.sync-preference-rows#1` — The Development category (PreferenceCategory key devCategory) is hidden in SettingsFragment.onResume whenever prefs.isDeveloper is false; when the developer easter egg has been triggered it renders four rows, not one.
2. `settings.developer.sync-preference-rows#2` — Row 1 is the SwitchPreferenceCompat 'Enable developer mode' (key pref_developer, defaultValue false).
3. `settings.developer.sync-preference-rows#3` — Row 2 is an EditTextPreference titled 'Sync server' (key pref_sync_base_url) whose default value is @string/syncBaseURL = "https://sync.loophabits.org".
4. `settings.developer.sync-preference-rows#4` — Row 3 is 'Sync key' (key pref_sync_key, default ""); row 4 is 'Encryption key' (key pref_encryption_key, default "").
5. `settings.developer.sync-preference-rows#5` — Editing any of the three writes the string into the app's default SharedPreferences and, like every preference change, fires BackupManager.dataChanged("org.isoron.uhabits") plus a re-run of updateWeekdayPreference().
6. `settings.developer.sync-preference-rows#6` — No code in uhabits-android or uhabits-core ever reads pref_sync_base_url, pref_sync_key or pref_encryption_key: there is no sync feature in this fork, so the three rows are inert data-entry fields.
7. `settings.developer.sync-preference-rows#7` — The category title 'Development' and the four row titles are hardcoded English literals in preferences.xml (not in strings.xml), so they are never translated regardless of locale.

#### settings.reminder-sound-row-hidden

- [ ] `settings.reminder-sound-row-hidden` — Reminder sound row is force-hidden (ringtone picker unreachable)
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt`, `uhabits-android/src/main/res/xml/preferences.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/notifications/RingtoneManager.kt`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Corrects notifications.sound / settings.screen.reminder-category, which describe a ringtone-selection feature that the current build hides. A Flutter port should ship no sound-picker row and just use the platform default notification sound; if the row is ever wanted back, the stored key is pref_ringtone_uri with "" meaning silent.

1. `settings.reminder-sound-row-hidden#1` — preferences.xml declares a Preference titled 'Reminder sound' (key reminderSound) as the first row of the Reminder category, but SettingsFragment.onResume unconditionally executes findPreference("reminderSound").isVisible = false, so it is never rendered.
2. `settings.reminder-sound-row-hidden#2` — Because the row is invisible, onPreferenceTreeClick's showRingtonePicker() branch (ACTION_RINGTONE_PICKER, TYPE_NOTIFICATION, show-default and show-silent both true, request code 1) and updateRingtoneDescription() are dead paths; RingtoneManager.update() is never invoked.
3. `settings.reminder-sound-row-hidden#3` — Consequently the SharedPreferences key pref_ringtone_uri is never written, and RingtoneManager.getURI() always returns its fallback Settings.System.DEFAULT_NOTIFICATION_URI, so every reminder plays the system default notification sound. The 'silent' state (empty-string value, which would make getURI() return null and getName() return @string/none 'None') is unreachable through the UI.
4. `settings.reminder-sound-row-hidden#4` — The Reminder category therefore renders exactly two rows in this build: 'Make notifications sticky' (pref_sticky_notifications, default false) and 'Customize notifications', the latter creating the REMINDERS notification channel and then launching Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS with EXTRA_APP_PACKAGE = packageName and EXTRA_CHANNEL_ID = NotificationTray.REMINDERS_CHANNEL_ID.

#### app-identity.launcher-icon

- [ ] `app-identity.launcher-icon` — App launcher icon (adaptive + Android 13 themed/monochrome) and launcher label
- **Platform:** needs-native-per-platform · **Port risk:** low
- **Source:** `uhabits-android/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `uhabits-android/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png`, `.../mipmap-xxxhdpi/ic_launcher_monochrome.png`, `.../mipmap-xxxhdpi/ic_launcher.png`, `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/src/main/res/values/colors.xml`, `uhabits-android/src/main/res/values/strings.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** The index covers platform-glue.manifest-components (activities/receivers/provider) but nothing about the app's visual identity assets. A Flutter port must regenerate the adaptive background/foreground/monochrome layers for Android and an app icon for iOS, and must keep the launcher label ("Habits") distinct from the app name ("Loop Habit Tracker") — both are translated strings, so the launcher label changes with the per-app language setting.

1. `app-identity.launcher-icon#1` — AndroidManifest <application> declares android:icon="@mipmap/ic_launcher" and android:label="@string/main_activity_title"; the home-screen/launcher entry is therefore labelled "Habits" (localized per locale), NOT the store/about name "Loop Habit Tracker" (@string/app_name). ListHabitsActivity and the .MainActivity alias repeat the same label.
2. `app-identity.launcher-icon#2` — On API 26+ @mipmap/ic_launcher resolves to mipmap-anydpi-v26/ic_launcher.xml, an <adaptive-icon> with: background = flat colour @color/ic_launcher_background = #1976D2, foreground = @mipmap/ic_launcher_foreground, monochrome = @mipmap/ic_launcher_monochrome.
3. `app-identity.launcher-icon#3` — The <monochrome> layer is what makes the icon participate in Android 13+ themed icons (CHANGELOG 2.1.0, "Add support for Android 13 themed icons", #1497); a port that ships only a colour icon silently loses that behaviour. Adaptive-icon support itself dates to CHANGELOG 1.7.8.
4. `app-identity.launcher-icon#4` — ic_launcher_foreground.png and ic_launcher_monochrome.png ship at all five densities (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi); the legacy square ic_launcher.png ships only at mdpi, xhdpi, xxhdpi and xxxhdpi (hdpi is absent, so pre-API-26 hdpi devices get a rescaled bitmap).
5. `app-identity.launcher-icon#5` — No android:roundIcon and no <shortcuts> are declared, so launchers get no round variant and the app exposes no static/dynamic app shortcuts.

#### platform-glue.rtl-layout

- [ ] `platform-glue.rtl-layout` — Right-to-left (RTL) layout mirroring
- **Platform:** ui · **Port risk:** medium
- **Source:** `uhabits-android/src/main/AndroidManifest.xml`, `uhabits-android/src/main/java/org/isoron/uhabits/utils/InterfaceUtils.kt`, `.../utils/ViewExtensions.kt`, `uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HeaderView.kt`, `.../views/ButtonPanelView.kt`, `uhabits-android/src/main/res/xml/locales_config.xml`, `uhabits-android/src/main/res/layout/activity_edit_habit.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** The index has localization entries and header entries, but no entry states that the app is RTL-aware or how the RTL flag interacts with the reverse-days preference and the custom-drawn header. Flutter mirrors via Directionality by default, so the double-negation in updateScrollDirection and the manual header mirror must be re-derived rather than transliterated, or the header will end up mirrored twice.

1. `platform-glue.rtl-layout#1` — AndroidManifest <application android:supportsRtl="true"> — every screen mirrors automatically under an RTL locale. Four of the 44 locales in locales_config.xml are RTL: ar-SA, fa-IR, iw-IL (Hebrew) and ug-CN. CHANGELOG 1.7.1 lists "Fix layout for RTL languages such as Arabic" as shipped behaviour.
2. `platform-glue.rtl-layout#2` — RTL is detected per view, not from the Locale: InterfaceUtils.isLayoutRtl(view) returns ViewCompat.getLayoutDirection(view) == ViewCompat.LAYOUT_DIRECTION_RTL, exposed as the extension View.isRTL().
3. `platform-glue.rtl-layout#3` — HeaderView.updateScrollDirection(): direction starts at -1, is multiplied by -1 when Preferences.isCheckmarkSequenceReversed is true, and multiplied by -1 again when isRTL() is true. So in an RTL locale the swipe direction that pages back to older days is inverted, and enabling "reverse order of days" in an RTL locale cancels the inversion back to the LTR direction.
4. `platform-glue.rtl-layout#4` — HeaderView's Drawer positions each date column from the right edge (canvas.width - dp(3)) and then, when isRTL(), mirrors the rect horizontally with rect.set(canvas.width - rect.right, rect.top, canvas.width - rect.left, rect.bottom) — this manual mirror exists because the header is custom-drawn, whereas the entry buttons below it are a LinearLayout (ButtonPanelView) that Android mirrors automatically.
5. `platform-glue.rtl-layout#5` — ButtonPanelView adds its buttons in reversed order when Preferences.isCheckmarkSequenceReversed; being a LinearLayout it is then mirrored again by the system in RTL, so the effective column order is the composition of both.
6. `platform-glue.rtl-layout#6` — Mirroring is only partial by design: several layouts use android:layout_marginLeft/marginRight (e.g. the colour button in activity_edit_habit.xml) while others use marginStart/marginEnd (e.g. style FormLabel), so some paddings do not flip in RTL.

#### settings.theme.system-night-window-background

- [ ] `settings.theme.system-night-window-background` — Pre-theme window background follows the system night mode; force-dark opted out
- **Platform:** ui · **Port risk:** low
- **Source:** `uhabits-android/src/main/res/values-night/colors.xml`, `uhabits-android/src/main/res/values/colors.xml`, `uhabits-android/src/main/res/values/styles.xml`, `uhabits-android/src/main/AndroidManifest.xml`
- **Kotlin tests:** none — write Dart test from rules
- **Notes:** Distinct from settings.theme.theme-modes (the in-app automatic/light/dark preference) and from charts-canvas-theming.theme-variants (the theme token sets): this is the OS-level resource-qualifier path that paints the window before any app code runs, plus the force-dark opt-out. A Flutter port needs the equivalent native launch-background resource (values-night styles / LaunchScreen), otherwise dark-mode users get a light flash on every cold start.

1. `settings.theme.system-night-window-background#1` — The manifest-level theme is @style/AppBaseTheme (the light theme). It sets android:colorBackground=@color/color_background, and color_background is @color/grey_200 in values/colors.xml but @color/grey_900 in values-night/colors.xml — the only -night qualified resource file in the whole app.
2. `settings.theme.system-night-window-background#2` — The -night qualifier follows the SYSTEM dark-mode setting, which is independent of the app's own theme preference (automatic/light/dark). So the window background painted at launch, before an activity runs AndroidThemeSwitcher, is dark whenever the system is dark. This is the shipped fix for "Fix splash screen background color in dark mode" (CHANGELOG 2.2.0, #1888).
3. `settings.theme.system-night-window-background#3` — Consequence to preserve: with the in-app theme forced to Light while the system is in dark mode, launch briefly shows a grey_900 window and then flips to the light theme once the activity applies it (and symmetrically for the opposite combination). There is no androidx SplashScreen API in use and no dedicated splash theme.
4. `settings.theme.system-night-window-background#4` — AppBaseTheme also sets android:forceDarkAllowed=false (tools:targetApi=q), so Android never auto-darkens any screen on API 29+; every dark appearance must come from the app's own theme definitions (AppBaseThemeDark / PureBlack).
5. `settings.theme.system-night-window-background#5` — Note: commit 7e993e17 re-parented AppBaseThemeDark from ThemeOverlay.MaterialComponents.Dark.ActionBar to Theme.MaterialComponents.NoActionBar, so the dark theme is now a full theme rather than an overlay — dark styling no longer inherits any light-theme attributes it does not override.

## High-risk items

Every feature below is `portRisk: high`. Each needs a deliberate Flutter/native design decision before the box above it can be checked.

- `time.today-and-day-boundary` — Global 'today', midnight delay and day boundary — *needs-native-per-platform*: computeToday depends on the platform default timezone (JVM TimeZone / JS Intl). In Flutter this needs DateTime.now() plus timeZoneOffset, and a timer/lifecycle hook to roll the day over while the app is running or resumed.
- `persistence.android-opener` — Android database opener, creation, version guard and file bootstrap — *android-only*: SQLiteOpenHelper's onCreate/onUpgrade/onDowngrade lifecycle and WAL toggling have no exact Flutter equivalent; sqflite's onCreate/onUpgrade must be wired so that onCreate stamps version 8 and replays migrations 09..25.
- `persistence.android-prepared-statement` — AndroidDatabase PreparedStatement adapter — *android-only*: The NULL-becomes-empty-string quirk on the query path is a real behavioral wart; a Flutter port should decide explicitly whether to reproduce or fix it. No current query in the codebase binds NULL, so fixing it is safe.
- `persistence.android-backup-agent` — Android system backup agent — *android-only*: BackupAgentHelper has no Flutter equivalent at all. A port either keeps a thin Android-native agent or drops system backup and relies solely on the file-copy backups.
- `io.import-file-picker` — Import data: file picking, temp copy and user messages — *android-only*: ACTION_OPEN_DOCUMENT / SAF content URIs have no Flutter equivalent; needs file_picker plus per-platform handling.
- `io.export-db-backup` — Export full backup (.db) and its file naming — *android-only*: DocumentFile/SAF tree URIs and the '<filesDir>/../databases' layout are Android-specific.
- `io.auto-backup` — Automatic daily backup with rotation — *android-only*: Storage Access Framework (DocumentFile/tree URIs) and getExternalFilesDirs have no direct Flutter equivalent; needs path_provider + file_picker or a platform channel. The rotation/freshness algorithm itself is pure logic and portable. AutoBackupTest also asserts the produced name 'Loop Habits Backup 1970-02-10 000000.db' after DateUtils.setFixedLocalTime(40*DAY_LENGTH), even though DatabaseUtils.saveDatabaseCopy actually formats System.currentTimeMillis(); the source, not the test, is authoritative for the timestamp source.
- `io.public-backup-folder-pref` — Public backup folder preference — *android-only*: Storage Access Framework tree URIs and persistable permissions have no Flutter equivalent.
- `io.share-file-screen` — Sharing the exported file — *android-only*: FileProvider + ACTION_SEND maps roughly to share_plus in Flutter, but the content-URI passthrough and permission grant semantics differ. The "extendal-cache-path" typo is a real bug in the current manifest resource — the external cache directory is effectively not shareable.
- `io.bug-report-dump` — Bug report generation and log file dump — *android-only*: Reading logcat via Runtime.exec has no Flutter/iOS equivalent. `logcat -d` cannot be shelled out from Dart; on Flutter the log capture must be replaced by an in-process ring buffer. HabitsApplicationTest asserts a message printed via printStackTrace appears in getLogcat() output.
- `list-habits.confetti` — Confetti celebration animation — *ui*: Uses the nl.dionsegijn.konfetti Android library and Settings.Global.ANIMATOR_DURATION_SCALE; both need Flutter-native replacements.
- `list-habits.startup-lifecycle` — Startup, first run, resume/pause and midnight refresh — *needs-native-per-platform*: POST_NOTIFICATIONS permission flow, activity lifecycle and the ACTION_EDIT intent are Android-specific and need per-platform reimplementation.
- `show-habit.export-csv` — Export this habit as CSV from the show screen — *needs-native-per-platform*: FileProvider + ACTION_SEND has no direct Flutter equivalent; needs share_plus / path_provider and per-platform file sharing. Unit test testOnExport asserts exactly one file is written to the output dir.
- `show-habit.widget-refresh` — Widget refresh triggered by bucket spinner changes — *android-only*: App widgets / RemoteViews have no Flutter equivalent; requires a native home-screen widget implementation per platform.
- `number-dialog.popup` — NumberDialog (numerical entry popup with notes) — *needs-native-per-platform*: The keyboard-forcing hack and the SwiftKey/Samsung input-method sniffing are Android-specific and have no Flutter equivalent; decimal-separator handling must be reimplemented with Flutter's TextInputFormatter + intl.
- `time-picker.radial-dialog` — Vendored radial TimePickerDialog — *needs-native-per-platform*: This is a fork of the old AOSP datetimepicker (also containing an unused date/ package: DatePickerDialog, DayPickerView, MonthView, YearPickerView, etc. — none of it is referenced from this domain). Flutter's showTimePicker has no Clear button, so the 'Clear reminder' affordance must be added explicitly.
- `settings.preferences.sticky-notifications` — Sticky (non-dismissible) notifications — *needs-native-per-platform*: setOngoing and the reshow-on-dismiss workaround have no direct Flutter equivalent; flutter_local_notifications ongoing:true is the closest on Android and there is no iOS equivalent at all.
- `settings.preferences.widget-opacity` — Widget opacity — *needs-native-per-platform*: The preference itself is trivial, but it only means anything for Android home-screen widgets rendered through RemoteViews; Flutter has no cross-platform equivalent.
- `settings.screen.reminder-category` — Reminder settings rows — *needs-native-per-platform*: Ringtone picker, notification channels and the system channel-settings intent are Android-only; the row is currently hidden but the pref_ringtone_uri key is still read when posting reminders.
- `settings.screen.database-category` — Database settings rows (export, import, public backup folder) and result codes — *needs-native-per-platform*: Storage Access Framework tree URIs, persistable permissions and DocumentFile have no Flutter equivalent; a port needs a platform-specific folder picker.
- `settings.intro.slides` — First-run intro slides — *ui*: Built on the third-party AppIntro2 library (swipe pager, skip/next/done buttons, colour-crossfading background); a Flutter port must reimplement the pager, indicator and Skip/Done chrome by hand.
- `widgets.registration` — Six home-screen widget types are registered with the launcher — *android-only*: Flutter has no cross-platform home-screen widget API. Requires native AppWidgetProvider on Android and WidgetKit on iOS; each of the *_info.xml sizing/preview declarations has to be re-authored per platform. The `testIsInstalled` test in each *WidgetTest.kt asserts the provider is present in AppWidgetManager.installedProviders.
- `widgets.provider-lifecycle` — Widget provider update / delete / resize lifecycle — *android-only*: AppWidgetProvider callbacks (onUpdate/onDeleted/onAppWidgetOptionsChanged) have no Flutter equivalent.
- `widgets.dimensions` — Widget dimension resolution (portrait vs landscape) — *android-only*: BaseViewTest.convertToView(widget, w, h) sets WidgetDimensions(w, h, w, h) and applies portraitRemoteViews — this is how all the widget render tests size their subject.
- `widgets.remoteviews-rendering` — Widgets are rendered to a bitmap and shipped as RemoteViews — *android-only*: Rendering an Android View to a Bitmap and shipping it inside RemoteViews has no Flutter analogue. On iOS/WidgetKit the equivalent is a SwiftUI view; on Android a Flutter port would need home_widget + a native bitmap or Glance implementation.
- `widgets.checkmark` — Checkmark widget — *android-only*: CheckmarkWidgetTest asserts a real click on R.id.button toggles the entry YES_MANUAL -> SKIP -> NO with isSkipEnabled=true, and golden-renders uhabits-android/src/androidTest/assets/views/widgets/CheckmarkWidget/render.png at 150x200.
- `widgets.frequency` — Frequency widget — *android-only*: FrequencyWidgetTest builds the widget with DayOfWeek.SUNDAY at 400x400 and golden-renders uhabits-android/src/androidTest/assets/views/widgets/FrequencyWidget/render.png.
- `widgets.history` — History widget — *android-only*: Golden render at 400x400: uhabits-android/src/androidTest/assets/views/widgets/HistoryWidget/render.png.
- `widgets.score` — Score widget — *android-only*: Golden render at 400x400: uhabits-android/src/androidTest/assets/views/widgets/ScoreWidget/render.png.
- `widgets.streak` — Streak widget — *android-only*: Golden render at 400x400: uhabits-android/src/androidTest/assets/views/widgets/StreakWidget/render.png.
- `widgets.target` — Target widget — *android-only*: TargetWidgetTest uses a long numerical habit with PaletteColor(11) and Frequency.WEEKLY, relaxes similarityCutoff to 0.00025, and golden-renders uhabits-android/src/androidTest/assets/views/widgets/TargetWidget/render.png at 400x400.
- `widgets.empty` — Empty widget (stack loading placeholder) — *android-only*: Platform-specific (android-only); no direct Flutter equivalent — needs a native implementation or an explicit redesign.
- `widgets.stack` — Stack widget (multi-habit swipeable widget) — *android-only*: Creating new stack widgets was removed from the picker UI (commit 1df9cc76 'Widgets: Remove option to create StackWidgets'), but the rendering path is still live for widgets whose stored preference holds more than one habit id — legacy installs must keep working after a port.
- `widgets.stack-service` — StackWidgetService / RemoteViewsFactory item construction — *android-only*: Platform-specific (android-only); no direct Flutter equivalent — needs a native implementation or an explicit redesign.
- `widgets.config-picker` — Widget configuration flow: habit picker dialog — *android-only*: The @Ignore'd acceptance test WidgetTest.shouldCreateAndToggleCheckmarkWidget still clicks a 'Save' button, which no longer exists — it is stale.
- `widgets.updater` — WidgetUpdater: pushing updates when data changes — *android-only*: The listener + selective-refresh logic is portable; the AppWidgetManager broadcast and exact-alarm scheduling are not.
- `widgets.day-rollover` — Widgets redraw at the start of the next logical day — *android-only*: Merged duplicate id: `time.widget-midnight-update`.
- `widgets.error-states` — Widget error and empty states — *android-only*: WidgetSteps.verifyCheckmarkWidgetIsShown explicitly asserts that no view whose text starts with 'Habit deleted' is present.
- `reminders.reschedule-on-command` — Automatic rescheduling when the model changes — *core*: ReminderSchedulerTest covers schedule/scheduleAll/snooze but has NO test for the onCommandFinished filter — the two ignored command types are untested and easy to get wrong in a port. Alarm scheduling itself is AlarmManager-specific.
- `reminders.snooze-picker-ui` — Snooze delay picker dialog — *needs-native-per-platform*: Translucent single-instance activity launched from a notification action over the lock screen has no Flutter equivalent; on Flutter this needs a platform channel plus a native transparent activity, or a redesign (e.g. snooze sub-actions directly on the notification). Showing an activity over the lock screen from a notification action is not expressible in pure Flutter.
- `reminders.snooze-android12-gate` — Snooze action hidden on Android 12+ — *android-only*: Reason for the gate: Android 12 forbids notification trampolines that start an activity from a broadcast receiver.
- `notifications.actions` — Reminder notification action buttons — *ui*: WearableExtender / Pebble support and notification action semantics have no direct Flutter equivalent.
- `notifications.channel` — Notification channel creation — *android-only*: Platform-specific (android-only); no direct Flutter equivalent — needs a native implementation or an explicit redesign.
- `notifications.sound` — Reminder sound / ringtone selection — *android-only*: Platform-specific (android-only); no direct Flutter equivalent — needs a native implementation or an explicit redesign.
- `notifications.auto-cancel` — Automatic cancellation when the habit is entered or deleted — *needs-native-per-platform*: The listener logic is pure, but SystemTray.removeNotification/showNotification map onto Android NotificationManager semantics and the id-derivation must be replicated per platform in Flutter.
- `reminders.exact-alarm-scheduling` — Exact alarm scheduling and its refusal cases — *android-only*: Exact-alarm permission, setExactAndAllowWhileIdle and doze-bypass have no Flutter-portable equivalent; a port needs flutter_local_notifications with exact schedule mode plus its own permission flow, and the IGNORED-on-no-permission behaviour must be replicated (silently no alarm).
- `intents.actions-and-extras` — Exact intent actions, data URIs and extras — *android-only*: Platform-specific (android-only); no direct Flutter equivalent — needs a native implementation or an explicit redesign.
- `intents.pending-intent-request-codes` — PendingIntent construction (request codes, flags, templates) — *android-only*: Request-code collisions are intentional (only one pending add/toggle/remove exists at a time). RemoteViews template+fill-in intents have no Flutter analogue.
- `intents.reminder-receiver-dispatch` — ReminderReceiver dispatch and error handling — *android-only*: Merged duplicate id: `platform-glue.reminder-receiver`.
- `intents.widget-receiver-dispatch` — WidgetReceiver dispatch (widget taps and notification Yes/No handling) — *android-only*: Background broadcast delivery while the app is dead has no Flutter equivalent; needs a native receiver or WorkManager/AlarmManager bridge.
- `reminders.boot-reschedule` — Rescheduling reminders after reboot — *android-only*: Flutter needs a native boot receiver (or flutter_local_notifications' rescheduleAfterReboot) to reproduce this.
- `reminders.app-start-and-permission` — Rescheduling at app start and POST_NOTIFICATIONS permission flow — *android-only*: Platform-specific (android-only); no direct Flutter equivalent — needs a native implementation or an explicit redesign.
- `charts-canvas-theming.android-canvas-impl` — AndroidCanvas backend semantics — *needs-native-per-platform*: The 0.6*mHeight text-centring hack and the density-scaled units are the two things a Flutter Canvas port must replicate to keep existing screenshots matching.
- `charts-canvas-theming.android-view-host` — AndroidView chart host — *android-only*: In Flutter this becomes a CustomPaint/CustomPainter pair; there is no direct equivalent of the re-seeded mutable canvas object.
- `charts-canvas-theming.dataview-scrolling` — AndroidDataView horizontal scrolling and paging — *android-only*: Hosts BarChart and HistoryChart (show-habit cards, history widget and the history editor dialog). Flutter needs a custom gesture + physics simulation to reproduce the 'velocity/2' fling and the integer bucket snapping.
- `charts-canvas-theming.android-contrast-attrs` — Android styled-resource contrast tokens — *android-only*: The Flutter port needs a single ThemeData-like object exposing contrast0..contrast100 plus cardBg, because the two colour systems (core Theme vs Android attrs) currently disagree slightly (e.g. lowContrastTextColor 0xE0E0E0 vs contrast40 #D8D8D8).
- `charts-canvas-theming.scrollable-chart` — ScrollableChart paging base class (legacy Android charts) — *android-only*: Two independent scroll implementations coexist (this one for legacy Paint-based charts, AndroidDataView for core Canvas charts). Note direction is applied at fling/scroll time, and HeaderView uses direction -1 (or +1 when the checkmark sequence is reversed, flipped again under RTL) so that the list header scrolls in step with the checkmark panels.
- `charts-canvas-theming.task-progress-bar` — TaskProgressBar background-work indicator — *android-only*: Flutter equivalent is a LinearProgressIndicator driven by a task-count stream with a 500 ms debounce.
- `platform-glue.manifest-components` — Declared app components (activities, aliases, receivers, services, provider) — *android-only*: Flutter has a single Activity by default. Every one of these components must be re-declared by hand in the Flutter app's AndroidManifest (and mostly re-implemented via platform channels). The activity-alias .MainActivity is the persisted launcher component name — renaming it breaks existing home-screen shortcuts. android:permission="false" on WidgetReceiver looks like a latent bug worth NOT reproducing.
- `platform-glue.permissions` — Declared permissions and runtime notification permission flow — *android-only*: In Flutter this maps to permission_handler + a manual manifest edit; the once-per-activity guard must be reproduced or the app will loop on permission denial.
- `platform-glue.tasker-action-constants` — Tasker/Locale plugin action constants and extras contract — *android-only*: No Flutter equivalent. Requires a native Android Activity + BroadcastReceiver in the Flutter app's android/ source set, bridged to Dart via a MethodChannel (or reimplemented entirely natively).
- `platform-glue.tasker-edit-setting-screen` — Tasker plugin edit screen (EditSettingActivity / EditSettingRootView) — *android-only*: Note the archived-habit inconsistency described in rule 1 — it is real current behavior. The screen must be a native Android Activity because Tasker launches it with startActivityForResult and reads setResult().
- `platform-glue.tasker-edit-setting-result` — Tasker plugin edit result (EditSettingController.onSave) — *android-only*: Platform-specific (android-only); no direct Flutter equivalent — needs a native implementation or an explicit redesign.
- `platform-glue.tasker-fire-setting` — Tasker plugin execution (FireSettingReceiver) — *android-only*: WidgetBehaviorTest covers the five behaviors but with amount=100, not the 1000 used by the Tasker path.
---
