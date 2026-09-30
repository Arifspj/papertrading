import '../core/api/trading_api.dart';
import '../models/position.dart';

/// Contract the UI talks to. Swap the implementation depending on whether
/// the real backend is ready or we are running on seeded demo data.
abstract class PositionsRepository {
  Future<PortfolioSummary> fetchPortfolio();
  Future<List<Position>> fetchPositions();
  Future<void> squareOff(String symbol);

  /// Squares off every open MIS position at the 15:20 cut-off, as a broker
  /// does before the close, and returns the resulting book.
  ///
  /// [at] is the cut-off instant, [ltpOf] resolves a live price per symbol.
  /// Returns the book unchanged when there was nothing to close, so the caller
  /// can treat an identical result as "no change".
  Future<List<Position>> squareOffOpenMis({
    required DateTime at,
    required double Function(String symbol) ltpOf,
  });
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

  /// A real broker squares off intraday positions itself, so this app has
  /// nothing to do — it just displays whatever the API reports. Only the paper
  /// trading simulator needs to act on the 15:20 rule.
  @override
  Future<List<Position>> squareOffOpenMis({
    required DateTime at,
    required double Function(String symbol) ltpOf,
  }) async {
    return _api.fetchPositions();
  }
}
