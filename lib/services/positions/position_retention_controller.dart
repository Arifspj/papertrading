import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/position.dart';
import '../../models/position_retention.dart';
import 'position_retention_store.dart';

/// Applies the book-retention rule and keeps the retired rows retired.
///
/// Flutter cannot run anything at 07:00 if the process is dead, so the cleanup
/// is driven from the three moments the app can actually observe:
///
///  * every fetch, via [retain],
///  * app resume, because a phone left face-up overnight crosses the boundary
///    without a single event,
///  * a timer for the 07:00 boundary itself, for an app left open.
class PositionRetentionController extends ChangeNotifier
    with WidgetsBindingObserver {
  PositionRetentionController({
    PositionRetention? policy,
    PositionRetentionStore? store,
    DateTime Function()? clock,
    this.observeLifecycle = true,
  })  : _policy = policy ?? const PositionRetention(),
        _store = store ?? const PositionRetentionStore(),
        _clock = clock ?? DateTime.now {
    // Kicked off here so callers can await [ready] instead of racing the
    // persisted ids on their first fetch.
    ready = init();
  }

    final PositionRetention _policy;
    final PositionRetentionStore _store;
    final DateTime Function() _clock;
    final bool observeLifecycle;

  final Set<String> _removed = <String>{};
  Timer? _boundaryTimer;
  bool _loaded = false;

  /// Completes once the persisted ids are in memory. Await this before the
  /// first [retain], otherwise a restart would briefly show yesterday's
  /// retired rows.
  late final Future<void> ready;

  /// Ids this controller has retired. Exposed so the UI can explain a missing
  /// row instead of just making it vanish.
  Set<String> get removed => Set.unmodifiable(_removed);

  /// Loads the persisted ids and arms the boundary timer. Safe to call twice.
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    var restored = 0;
    try {
      final stored = await _store.load();
      _removed.addAll(stored);
      restored = stored.length;
    } catch (_) {
      // A failed read must not block the book; the worst case is that today's
      // already-retired rows reappear until the next sweep.
    }
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _armBoundaryTimer();
    // Anything the caller showed before the ids landed has to be re-filtered.
    if (restored > 0) notifyListeners();
  }

  /// Filters [positions] down to the ones that should be on screen, retiring and
  /// persisting anything that has passed its cutoff.
  List<Position> retain(List<Position> positions) {
    final now = _clock();
    final kept = <Position>[];
    final newlyRemoved = <String>{};

    for (final p in positions) {
      if (_removed.contains(p.retentionKey)) continue;
      if (_policy.isPurgeable(p, now)) {
        newlyRemoved.add(p.retentionKey);
        continue;
      }
      kept.add(p);
    }

    if (newlyRemoved.isNotEmpty) {
      _removed.addAll(newlyRemoved);
      // Fire and forget: a failed write only costs us the reminder, never the
      // in-memory filter that already happened.
      unawaited(_persist());
    }
    return kept;
  }

  Future<void> _persist() async {
    try {
      await _store.save(_removed);
    } catch (_) {
      // ignore
    }
  }

  /// How long until the next 07:00 boundary.
  Duration get timeToNextBoundary {
    final now = _clock();
    var next = DateTime(now.year, now.month, now.day, _policy.cleanupHour);
    if (!next.isAfter(now)) {
      next = DateTime(now.year, now.month, now.day + 1, _policy.cleanupHour);
    }
    return next.difference(now);
  }

  void _armBoundaryTimer() {
    _boundaryTimer?.cancel();
    // At most 24h out, comfortably inside the 32-bit Timer range.
    _boundaryTimer = Timer(timeToNextBoundary, () {
      // Something may have crossed the cutoff while the app sat open.
      notifyListeners();
      _armBoundaryTimer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Time passed unseen while the app was backgrounded; a row can have aged
    // out without the boundary timer having a chance to fire.
    notifyListeners();
    _armBoundaryTimer();
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    if (observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
