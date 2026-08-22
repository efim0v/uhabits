/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ModelObservable.kt
///
/// A ModelObservable allows objects to subscribe themselves to it and receive
/// notifications whenever the model is changed.
///
/// The Kotlin methods carry `@Synchronized`; a Dart isolate runs single
/// threaded, so there is no lock to port.
class ModelObservable {
  /// Creates a new ModelObservable with no listeners.
  ModelObservable();

  final List<ModelObservableListener> _listeners = <ModelObservableListener>[];

  /// Adds the given listener to the observable.
  ///
  /// The same listener may be added more than once, in which case it is
  /// notified once per registration.
  void addListener(ModelObservableListener l) {
    _listeners.add(l);
  }

  /// Notifies every listener that the model has changed.
  ///
  /// Only models should call this method.
  void notifyListeners() {
    for (final l in _listeners) {
      l.onModelChange();
    }
  }

  /// Removes the given listener.
  ///
  /// The listener will no longer be notified when the model changes. If the
  /// given listener is not subscribed to this observable, does nothing. If it
  /// is subscribed more than once, only the first registration is removed.
  void removeListener(ModelObservableListener l) {
    _listeners.remove(l);
  }
}

/// Port of `ModelObservable.Listener`. Dart has no nested classes, so the
/// Kotlin inner interface becomes a top-level one.
///
/// Interface implemented by objects that want to be notified when the model
/// changes. Kotlin declares it as a `fun interface`, so a bare lambda is a
/// valid Listener there; the default constructor below is the Dart equivalent
/// of that SAM conversion.
abstract interface class ModelObservableListener {
  /// Wraps a plain callback as a listener.
  factory ModelObservableListener(void Function() onModelChange) =
      _CallbackModelObservableListener;

  /// Called whenever the model associated to this observable has been
  /// modified.
  void onModelChange();
}

class _CallbackModelObservableListener implements ModelObservableListener {
  _CallbackModelObservableListener(this._callback);

  final void Function() _callback;

  @override
  void onModelChange() => _callback();
}
