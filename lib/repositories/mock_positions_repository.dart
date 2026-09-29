import 'dart:async';

import '../models/position.dart';
import 'positions_repository.dart';

/// Seeded demo data matching the reference "Positions" design, so the app is
/// fully usable until the real paper-trading API is connected.
class MockPositionsRepository implements PositionsRepository {
  static const _positions = [
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
      symbol: 'SENSEX 01st W OCT 72900 PE',
      quantity: 1200,
      averagePrice: 98.25,
      lastTradedPrice: 438.15,
      pnl: 126390.25,
      product: 'MIS',
      segment: 'BFO',
    ),
    Position(
      symbol: 'SENSEX 01st W OCT 72900 CE',
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
    // no-op: no live trade executed in demo mode
  }
}