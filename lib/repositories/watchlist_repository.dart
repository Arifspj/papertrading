import '../models/watchlist.dart';

/// Contract for watchlist quote data.
abstract class WatchlistRepository {
  Future<List<WatchItem>> fetchWatchlist();
}

/// Seeded demo quotes matching the reference "Watchlist" design.
class MockWatchlistRepository implements WatchlistRepository {
  static const _items = [
    WatchItem(
      symbol: 'NIFTY OCT 22350 PE',
      lastPrice: 0.05,
      change: -6.95,
      changePct: -99.29,
      segment: 'NFO',
    ),
    WatchItem(
      symbol: 'SENSEX 01st W OCT 72900 PE',
      lastPrice: 438.15,
      change: 339.90,
      changePct: 345.95,
      segment: 'BFO',
      isWeekly: true,
    ),
    WatchItem(
      symbol: 'SENSEX 01st W OCT 72900 CE',
      lastPrice: 0.05,
      change: -18.85,
      changePct: -99.74,
      segment: 'BFO',
      isWeekly: true,
    ),
  ];

  @override
  Future<List<WatchItem>> fetchWatchlist() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return List.of(_items);
  }
}