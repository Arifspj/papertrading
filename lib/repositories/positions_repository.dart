import '../core/api/trading_api.dart';
import '../models/position.dart';

/// Contract the UI talks to. Swap the implementation depending on whether
/// the real backend is ready or we are running on seeded demo data.
abstract class PositionsRepository {
  Future<PortfolioSummary> fetchPortfolio();
  Future<List<Position>> fetchPositions();
  Future<void> squareOff(String symbol);
}

/// Live implementation -> talks to the paper-trading API.
class HttpPositionsRepository implements PositionsRepository {
  final TradingApi _api;

  HttpPositionsRepository({TradingApi? api}) : _api = api ?? TradingApi();

  @override
  Future<List<Position>> fetchPositions() => _api.fetchPositions();

  @override
  Future<PortfolioSummary> fetchPortfolio() => _api.fetchPortfolio();

  @override
  Future<void> squareOff(String symbol) => _api.squareOff(symbol);
}