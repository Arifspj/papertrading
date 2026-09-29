import '../models/watchlist.dart';

/// Contract for watchlist quote data.
abstract class WatchlistRepository {
  Future<List<WatchItem>> fetchWatchlist();

  /// Symbols matching [query] that are not already on the watchlist.
  List<WatchItem> searchSymbols(String query);

  Future<void> addItem(WatchItem item);
}

/// Seeded demo quotes matching the reference "Watchlist" design. Mutable so
/// items added via search persist while the app session is alive.
class MockWatchlistRepository implements WatchlistRepository {
  static const _seed = [
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

  static const _catalog = [
    ..._seed,
    WatchItem(
      symbol: 'NIFTY 24OCT 22500 CE',
      lastPrice: 142.30,
      change: 18.45,
      changePct: 14.88,
      segment: 'NFO',
      isWeekly: true,
    ),
    WatchItem(
      symbol: 'NIFTY 24OCT 22400 PE',
      lastPrice: 86.50,
      change: -12.10,
      changePct: -12.27,
      segment: 'NFO',
      isWeekly: true,
    ),
    WatchItem(
      symbol: 'BANKNIFTY 23OCT 51200 CE',
      lastPrice: 345.80,
      change: 42.60,
      changePct: 14.05,
      segment: 'NFO',
      isWeekly: true,
    ),
    WatchItem(
      symbol: 'BANKNIFTY 23OCT 50800 PE',
      lastPrice: 210.15,
      change: -28.40,
      changePct: -11.90,
      segment: 'NFO',
      isWeekly: true,
    ),
    WatchItem(
      symbol: 'SENSEX 01st OCT 72900 CE',
      lastPrice: 391.05,
      change: 290.20,
      changePct: 287.75,
      segment: 'BFO',
      isWeekly: true,
    ),
    WatchItem(
      symbol: 'SENSEX 01st OCT 72500 PE',
      lastPrice: 118.40,
      change: -45.60,
      changePct: -27.80,
      segment: 'BFO',
      isWeekly: true,
    ),
    WatchItem(
      symbol: 'FINNIFTY 29th 23900 CE',
      lastPrice: 95.20,
      change: 8.75,
      changePct: 10.12,
      segment: 'NFO',
      isWeekly: true,
    ),
    WatchItem(
      symbol: 'NIFTY 28NOV FUT',
      lastPrice: 22580.00,
      change: 65.40,
      changePct: 0.29,
      segment: 'NFO',
    ),
    WatchItem(
      symbol: 'BANKNIFTY 28NOV FUT',
      lastPrice: 51450.00,
      change: -112.30,
      changePct: -0.22,
      segment: 'NFO',
    ),
    WatchItem(
      symbol: 'NIFTY',
      lastPrice: 22765.80,
      change: 128.35,
      changePct: 0.57,
      segment: 'NSE',
    ),
    WatchItem(
      symbol: 'BANKNIFTY',
      lastPrice: 51622.55,
      change: -154.20,
      changePct: -0.30,
      segment: 'NSE',
    ),
  ];

  final List<WatchItem> _items = List.of(_seed);

  @override
  Future<List<WatchItem>> fetchWatchlist() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return List.of(_items);
  }

  @override
  List<WatchItem> searchSymbols(String query) {
    final q = query.trim().toLowerCase();
    final added = _items.map((e) => e.symbol.toLowerCase()).toSet();
    return _catalog
        .where((e) {
          final symbol = e.symbol.toLowerCase();
          if (added.contains(symbol)) return false;
          return q.isEmpty || symbol.contains(q);
        })
        .toList();
  }

  @override
  Future<void> addItem(WatchItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!_items.any((e) => e.symbol == item.symbol)) {
      _items.add(item);
    }
  }
}