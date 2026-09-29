import 'dart:async';

import '../models/position.dart';
import 'positions_repository.dart';

/// Seeded demo data matching the reference "Positions" design, so the app is
/// fully usable until the real paper-trading API is connected.
class MockPositionsRepository implements PositionsRepository {
  MockPositionsRepository() : _positions = List.of(_seed);

  static const _seed = [
    Position(
      symbol: 'NIFTY OCT 22350 PE',
      quantity: -775,
      averagePrice: 7.00,
      lastTradedPrice: 0.05,
      pnl: 5446.25,
      product: 'NRML',
      segment: 'NFO',
    ),
    Position(
      symbol: 'SENSEX 01st OCT 72900 PE',
      quantity: 1200,
      averagePrice: 98.25,
      lastTradedPrice: 438.15,
      pnl: 126390.25,
      product: 'MIS',
      segment: 'BFO',
    ),
    Position(
      symbol: 'SENSEX 01st OCT 72900 CE',
      quantity: 300,
      averagePrice: 18.90,
      lastTradedPrice: 0.05,
      pnl: 23900.10,
      product: 'NRML',
      segment: 'BFO',
    ),
    Position(
      symbol: 'NIFTY OCT 22350 PE',
      quantity: 0,
      averagePrice: 0.00,
      lastTradedPrice: 0.00,
      pnl: 5446.25,
      product: 'NRML',
      segment: 'NFO',
    ),
  ];

  final List<Position> _positions;

  @override
  Future<List<Position>> fetchPositions() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return List.of(_positions);
  }

  @override
  Future<PortfolioSummary> fetchPortfolio() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return PortfolioSummary.fromPositions(_positions);
  }

  @override
  Future<void> squareOff(String symbol) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final i = _positions.indexWhere((p) => p.symbol == symbol && !p.isClosed);
    if (i == -1) return;
    final p = _positions[i];
    _positions[i] = Position(
      symbol: p.symbol,
      quantity: 0,
      averagePrice: 0,
      lastTradedPrice: p.lastTradedPrice,
      pnl: p.pnl,
      instrumentType: p.instrumentType,
      product: p.product,
      segment: p.segment,
    );
    final closed = _positions.removeAt(i);
    _positions.add(closed);
  }
}