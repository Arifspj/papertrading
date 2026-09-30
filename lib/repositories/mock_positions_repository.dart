import 'dart:async';

import '../models/mis_square_off.dart';
import '../models/position.dart';
import 'positions_repository.dart';


/// Seeded demo data matching the reference "Positions" design, so the app is
/// fully usable until the real paper-trading API is connected.
///
/// Expiries are resolved from the month and day written in each symbol, and
/// always land on today or later. That matters twice over: the demo book has to
/// survive its own retention rule on the day it is created, and it is what
/// makes the rule visible — the `01st OCT` rows expire tomorrow, so the next
/// morning's 07:00 sweep has something to do.
class MockPositionsRepository implements PositionsRepository {
  MockPositionsRepository({
    DateTime? now,
    Duration? latency,
    MisSquareOffPolicy policy = const MisSquareOffPolicy(),
  })  : _latency = latency ?? const Duration(milliseconds: 450),
        _policy = policy,
        _positions = List.of(_seed(now));


  /// Artificial latency that stands in for the network. Tests pass
  /// `Duration.zero`; a sweep across many dates is otherwise dominated by
  /// waiting rather than by the rule under test.
  final Duration _latency;

  static List<Position> _seed(DateTime? now) {
    final today = now ?? DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);

    /// Nearest [month]/[day] that is today or later, so a seeded row is never
    /// born already expired.
    DateTime upcoming(int month, int day) {
      for (var year = today.year; year <= today.year + 1; year++) {
        final d = DateTime(year, month, day);
        if (!d.isBefore(midnight)) return d;
      }
      return DateTime(today.year + 1, month, day);
    }

    /// Last Thursday of [month] — the NIFTY monthly expiry convention.
    DateTime monthlyExpiry(int month) {
      for (var year = today.year; year <= today.year + 1; year++) {
        var d = DateTime(year, month + 1, 0);
        while (d.weekday != DateTime.thursday) {
          d = d.subtract(const Duration(days: 1));
        }
        if (!d.isBefore(midnight)) return DateTime(d.year, d.month, d.day);
      }
      return DateTime(today.year + 1, month, 1);
    }

    // `SENSEX 01st OCT 72900 PE` -> 1 October, matching what HNICALLS reports
    // as `"expiry": "2026-10-01"` for that contract.
    final weekly = upcoming(DateTime.october, 1);
    final monthly = monthlyExpiry(DateTime.october);

    return [
      Position(
        id: 'pos-1',
        symbol: 'NIFTY OCT 22350 PE',
        quantity: -775,
        averagePrice: 7.00,
        lastTradedPrice: 0.05,
        pnl: 5446.25,
        product: 'NRML',
        segment: 'NFO',
        expiry: monthly,
      ),
      Position(
        id: 'pos-2',
        symbol: 'SENSEX 01st OCT 72900 PE',
        quantity: 1200,
        averagePrice: 98.25,
        lastTradedPrice: 438.15,
        pnl: 126390.25,
        product: 'MIS',
        segment: 'BFO',
        expiry: weekly,
      ),
      Position(
        id: 'pos-3',
        symbol: 'SENSEX 01st OCT 72900 CE',
        quantity: 300,
        averagePrice: 18.90,
        lastTradedPrice: 0.05,
        pnl: 23900.10,
        product: 'NRML',
        segment: 'BFO',
        expiry: weekly,
      ),
      Position(
        id: 'pos-4',
        symbol: 'NIFTY OCT 22350 PE',
        quantity: 0,
        averagePrice: 0.00,
        lastTradedPrice: 0.00,
        pnl: 5446.25,
        product: 'NRML',
        segment: 'NFO',
        expiry: monthly,
        // Closed earlier today: still on the book, gone after tomorrow's 07:00.
        closedAt: DateTime(today.year, today.month, today.day, 11, 30),
      ),
    ];
  }

  final List<Position> _positions;

  /// The 15:20 cut-off rule, kept as a field so a test can substitute the hour.
  final MisSquareOffPolicy _policy;

  @override
  Future<List<Position>> fetchPositions() async {
    await Future<void>.delayed(_latency);
    return List.of(_positions);
  }

  @override
  Future<PortfolioSummary> fetchPortfolio() async {
    await Future<void>.delayed(_latency);
    return PortfolioSummary.fromPositions(_positions);
  }

  @override
  Future<void> squareOff(String symbol) async {
    await Future<void>.delayed(_latency);
    final i = _positions.indexWhere((p) => p.symbol == symbol && !p.isClosed);
    if (i == -1) return;
    final p = _positions[i];
    // Stamped with the close time, because the retention rule counts the
    // morning *after* a square-off, not the morning of it.
    _positions[i] = p.copyWith(
      quantity: 0,
      averagePrice: 0,
      lastTradedPrice: p.lastTradedPrice,
      closedAt: DateTime.now(),
    );
    final closed = _positions.removeAt(i);
    _positions.add(closed);
  }

  @override
  Future<List<Position>> squareOffOpenMis({
    required DateTime at,
    required double Function(String symbol) ltpOf,
  }) async {
    await Future<void>.delayed(_latency);
    final due = _policy.dueForSquareOff(_positions, at);
    if (due.isEmpty) return List.of(_positions);

    final closedIds = <String>{};
    for (var i = 0; i < _positions.length; i++) {
      final p = _positions[i];
      if (!_policy.isDueForSquareOff(p, at)) continue;
      // Live price wins, the stored last-traded price is the fallback so a
      // silent feed still books a number rather than zero.
      final ltp = ltpOf(p.symbol);
      _positions[i] = _policy.squareOff(
        p,
        ltp > 0 ? ltp : p.lastTradedPrice,
        at,
      );
      closedIds.add(p.retentionKey);
    }

    // Squared-off rows move to the end, matching [squareOff], so the book reads
    // open lots first.
    final stillOpen = _positions.where((p) => !closedIds.contains(p.retentionKey)).toList();
    final justClosed =
        _positions.where((p) => closedIds.contains(p.retentionKey)).toList();
    _positions
      ..clear()
      ..addAll(stillOpen)
      ..addAll(justClosed);

    return List.of(_positions);
  }
}


