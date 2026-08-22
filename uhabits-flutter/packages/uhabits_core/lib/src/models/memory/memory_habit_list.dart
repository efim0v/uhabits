import '../../time/local_date.dart';
import '../habit.dart';
import '../habit_list.dart';
import '../habit_matcher.dart';
import '../model_observable.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/memory/MemoryHabitList.kt
///
/// In-memory implementation of [HabitList].
///
/// Kotlin annotates most members `@Synchronized`; a Dart isolate is single
/// threaded, so there is no lock to port.
class MemoryHabitList extends HabitList {
  MemoryHabitList() : super() {
    _comparator = _getComposedComparatorByOrder(_primaryOrder, _secondaryOrder);
  }

  /// The filtered (child) constructor.
  ///
  /// Kotlin sets `comparator` from the argument and then assigns
  /// `primaryOrder` / `secondaryOrder` from the parent — whose setters rebuild
  /// the comparator — so the argument is effectively overwritten.
  MemoryHabitList.filtered(
    super.matcher,
    Comparator<Habit>? comparator,
    MemoryHabitList parent,
  ) : super.filtered() {
    _parent = parent;
    _comparator = comparator;
    primaryOrder = parent.primaryOrder;
    secondaryOrder = parent.secondaryOrder;
    parent.observable.addListener(ModelObservableListener(_loadFromParent));
    _loadFromParent();
  }

  final List<Habit> _list = <Habit>[];

  HabitListOrder _primaryOrder = HabitListOrder.byPosition;
  HabitListOrder _secondaryOrder = HabitListOrder.byNameAsc;
  Comparator<Habit>? _comparator;
  MemoryHabitList? _parent;

  @override
  HabitListOrder get primaryOrder => _primaryOrder;

  @override
  set primaryOrder(HabitListOrder value) {
    _primaryOrder = value;
    _comparator = _getComposedComparatorByOrder(_primaryOrder, _secondaryOrder);
    resort();
  }

  @override
  HabitListOrder get secondaryOrder => _secondaryOrder;

  @override
  set secondaryOrder(HabitListOrder value) {
    _secondaryOrder = value;
    _comparator = _getComposedComparatorByOrder(_primaryOrder, _secondaryOrder);
    resort();
  }

  @override
  void add(Habit habit) {
    _throwIfHasParent();
    if (_list.contains(habit)) throw ArgumentError('habit already added');
    final id = habit.id;
    if (id != null && getById(id) != null) throw Exception('duplicate id');
    if (id == null) habit.id = _list.length;
    _list.add(habit);
    resort();
  }

  @override
  Habit? getById(int id) {
    for (final h in _list) {
      if (h.id == null) throw StateError('Required value was null.');
      if (h.id == id) return h;
    }
    return null;
  }

  @override
  Habit? getByUUID(String? uuid) {
    for (final h in _list) {
      if (h.uuid! == uuid) return h;
    }
    return null;
  }

  @override
  Habit getByPosition(int position) {
    return _list[position];
  }

  @override
  HabitList getFiltered(HabitMatcher? matcher) {
    return MemoryHabitList.filtered(matcher!, _comparator, this);
  }

  Comparator<Habit> _getComposedComparatorByOrder(
    HabitListOrder firstOrder,
    HabitListOrder? secondOrder,
  ) {
    return (Habit h1, Habit h2) {
      final firstResult = _getComparatorByOrder(firstOrder)(h1, h2);
      if (firstResult != 0 || secondOrder == null) {
        return firstResult;
      }
      return _getComparatorByOrder(secondOrder)(h1, h2);
    };
  }

  Comparator<Habit> _getComparatorByOrder(HabitListOrder order) {
    int nameComparatorAsc(Habit habit1, Habit habit2) =>
        habit1.name.compareTo(habit2.name);
    int nameComparatorDesc(Habit h1, Habit h2) => nameComparatorAsc(h2, h1);
    int colorComparatorAsc(Habit h1, Habit h2) => h1.color.compareTo(h2.color);
    int colorComparatorDesc(Habit h1, Habit h2) => colorComparatorAsc(h2, h1);
    // Upstream names this comparator DESC while comparing habit1 to habit2
    // ascending; the inversion is intentional here, see the parity ledger.
    int scoreComparatorDesc(Habit habit1, Habit habit2) {
      final today = getToday();
      return habit1.scores[today].value.compareTo(habit2.scores[today].value);
    }

    int scoreComparatorAsc(Habit h1, Habit h2) => scoreComparatorDesc(h2, h1);
    int positionComparator(Habit habit1, Habit habit2) =>
        habit1.position.compareTo(habit2.position);
    int statusComparatorDesc(Habit h1, Habit h2) {
      if (h1.isCompletedToday() != h2.isCompletedToday()) {
        return h1.isCompletedToday() ? -1 : 1;
      }
      if (h1.isNumerical != h2.isNumerical) {
        return h1.isNumerical ? -1 : 1;
      }
      final today = getToday();
      final v1 = h1.computedEntries.get(today).value;
      final v2 = h2.computedEntries.get(today).value;
      return v2.compareTo(v1);
    }

    int statusComparatorAsc(Habit h1, Habit h2) => statusComparatorDesc(h2, h1);
    switch (order) {
      case HabitListOrder.byPosition:
        return positionComparator;
      case HabitListOrder.byNameAsc:
        return nameComparatorAsc;
      case HabitListOrder.byNameDesc:
        return nameComparatorDesc;
      case HabitListOrder.byColorAsc:
        return colorComparatorAsc;
      case HabitListOrder.byColorDesc:
        return colorComparatorDesc;
      case HabitListOrder.byScoreDesc:
        return scoreComparatorDesc;
      case HabitListOrder.byScoreAsc:
        return scoreComparatorAsc;
      case HabitListOrder.byStatusDesc:
        return statusComparatorDesc;
      case HabitListOrder.byStatusAsc:
        return statusComparatorAsc;
    }
  }

  @override
  int indexOf(Habit h) {
    return _list.indexOf(h);
  }

  @override
  Iterator<Habit> get iterator {
    return _list.toList().iterator;
  }

  @override
  void remove(Habit h) {
    _throwIfHasParent();
    _list.remove(h);
    observable.notifyListeners();
  }

  @override
  void reorder(Habit from, Habit to) {
    _throwIfHasParent();
    if (primaryOrder != HabitListOrder.byPosition) {
      throw StateError('cannot reorder automatically sorted list');
    }
    if (indexOf(from) < 0) {
      throw ArgumentError('list does not contain (from) habit');
    }
    final toPos = indexOf(to);
    if (toPos < 0) throw ArgumentError('list does not contain (to) habit');
    _list.remove(from);
    _list.insert(toPos, from);
    var position = 0;
    for (final h in _list) {
      h.position = position++;
    }
    observable.notifyListeners();
  }

  @override
  int size() {
    return _list.length;
  }

  @override
  void update(List<Habit> habits) {
    resort();
  }

  void _throwIfHasParent() {
    if (_parent != null) {
      throw StateError('Filtered lists cannot be modified directly. '
          'You should modify the parent list instead.');
    }
  }

  void _loadFromParent() {
    final parent = _parent;
    if (parent == null) throw StateError('Required value was null.');
    _list.clear();
    for (final h in parent) {
      if (filter.matches(h)) _list.add(h);
    }
    resort();
  }

  @override
  void resort() {
    final comparator = _comparator;
    if (comparator != null) _list.sort(comparator);
    observable.notifyListeners();
  }
}
