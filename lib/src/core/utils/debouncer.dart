import 'dart:async';

/// Delay applied to the address autocomplete fields before querying Places.
///
/// Shared with the tests, which must advance the clock past it: a pending
/// [Timer] schedules no frame, so `pumpAndSettle` alone never crosses it.
const kAddressSearchDebounce = Duration(milliseconds: 350);

/// Runs an action only once the caller stops asking for it.
///
/// Each [run] cancels the pending action and re-arms the delay, so a burst of
/// keystrokes produces a single execution, with the LAST argument.
class Debouncer {
  Debouncer({this.delay = kAddressSearchDebounce});

  final Duration delay;
  Timer? _timer;

  /// Schedules [action], replacing any previously scheduled one.
  ///
  /// [action] may be asynchronous: the returned future is deliberately dropped
  /// here, once, rather than at each call site, because a debounced action has
  /// nobody left to await it (`unawaited_futures` is on, analysis_options.yaml).
  void run(FutureOr<void> Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(Future.sync(action)));
  }

  /// Drops the pending action, if any. Safe to call when nothing is scheduled.
  void cancel() => _timer?.cancel();

  /// Call from the owner's `dispose()`: a timer left in flight would fire on a
  /// unmounted State, and would fail the test binding's pending-timer check.
  void dispose() => cancel();
}
