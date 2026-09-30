import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/mis_square_off.dart';
import '../../models/position.dart';
import '../../repositories/positions_repository.dart';

/// Closes out intraday (MIS) positions at 15:20, the way a broker squares off
/// before the session ends.
///
/// Same three moments a Flutter app can observe, because a dead process cannot
/// wake itself at 15:20:
///
///  * app start and every resume, as a catch-up sweep,
///  * a timer for the cut-off itself while the app is open.
///
/// [ltpOf] resolves the live price so the frozen P&L books what the market
/// actually said, not a stale seed value.
class MisAutoSquareOffController extends ChangeNotifier
    with WidgetsBindingObserver {
  MisAutoSquareOffController({
    required PositionsRepository repository,
    required double Function(String symbol) ltpOf,
    MisSquareOffPolicy? policy,
    DateTime Function()? clock,
    this.observeLifecycle = true,
  })  : _repository = repository,
        _ltpOf = ltpOf,
        _policy = policy ?? const MisSquareOffPolicy(),
        _clock = clock ?? DateTime.now {
    ready = init();
  }

  final PositionsRepository _repository;
  final double Function(String symbol) _ltpOf;
  final MisSquareOffPolicy _policy;
  final DateTime Function() _clock;
  final bool observeLifecycle;

  Timer? _cutoffTimer;
  bool _sweeping = false;
  int _sweeps = 0;
  int _closed = 0;

  /// Resolves once the first catch-up sweep has run.
  late final Future<void> ready;

  /// How many positions this controller has squared off, for diagnostics.
  int get closedCount => _closed;

  /// How many sweeps have run, including the ones that found nothing.
  int get sweepCount => _sweeps;

  Future<void> init() async {
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _armCutoffTimer();
    await sweep();
  }

  /// Squares off anything due right now. Safe to call at any time: it no-ops
  /// before the cut-off, and once a position is closed it is no longer a
  /// candidate, so repeated sweeps are harmless.
  ///
  /// The due check runs against the current book *before* asking the repository
  /// to act, so a sweep that has nothing to do neither calls through nor
  /// announces a change. Announcing unconditionally would make the positions
  /// list re-read on every resume and every cut-off tick.
  Future<void> sweep() async {
    if (_sweeping) return;
    _sweeping = true;
    _sweeps++;
    try {
      final now = _clock();
      if (!_policy.isDue(now)) return;
      final cutoff = _policy.cutoffOn(now);

      final before = await _repository.fetchPositions();
      final due = _policy.dueForSquareOff(before, now);
      if (due.isEmpty) return;

      await _repository.squareOffOpenMis(at: cutoff, ltpOf: _ltpOf);
      _closed += due.length;
      // The list on screen no longer matches the book, so ask for a re-read.
      notifyListeners();
    } finally {
      _sweeping = false;
    }
  }

  /// Time left until today's 15:20. Zero once it has passed.
  Duration get timeToCutoff {
    final now = _clock();
    final cutoff = _policy.cutoffOn(now);
    if (!now.isBefore(cutoff)) return Duration.zero;
    return cutoff.difference(now);
  }

  void _armCutoffTimer() {
    _cutoffTimer?.cancel();
    final wait = timeToCutoff;
    // Already past today's cut-off: nothing to schedule today. The next sweep
    // happens on resume or on tomorrow's timer.
    if (wait == Duration.zero) return;
    _cutoffTimer = Timer(wait, () {
      unawaited(sweep());
      _armCutoffTimer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The app was likely backgrounded across the cut-off.
    unawaited(sweep());
    _armCutoffTimer();
  }

  @override
  void dispose() {
    _cutoffTimer?.cancel();
    if (observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// The positions a cut-off sweep would close, for callers that want to show
/// what is about to happen without performing it.
List<Position> pendingMisSquareOff(
  MisSquareOffPolicy policy,
  List<Position> positions,
  DateTime now,
) =>
    policy.dueForSquareOff(positions, now);
