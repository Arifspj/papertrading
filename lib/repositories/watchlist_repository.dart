import '../core/utils/symbol_formatter.dart';
import '../models/watchlist.dart';

/// Contract for watchlist quote data.
abstract class WatchlistRepository {
  Future<List<WatchItem>> fetchWatchlist();

  /// Catalog symbols matching [query] (already-added ones are included so the
  /// search sheet can show them as "Added"). Matching runs against the raw
  /// symbol and the unified [SymbolParts] form, so `01st`, `01` and `24OCT`
  /// style queries all resolve.
  List<WatchItem> searchSymbols(String query);

  bool isAdded(String symbol);

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
      symbol: 'SENSEX 01st OCT 72900 PE',
      lastPrice: 438.15,
      change: 339.90,
      changePct: 345.95,
      segment: 'BFO',
    ),
    WatchItem(
      symbol: 'SENSEX 01st OCT 72900 CE',
      lastPrice: 0.05,
      change: -18.85,
      changePct: -99.74,
      segment: 'BFO',
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
    ),
    WatchItem(
      symbol: 'NIFTY 24OCT 22400 PE',
      lastPrice: 86.50,
      change: -12.10,
      changePct: -12.27,
      segment: 'NFO',
    ),
    WatchItem(
      symbol: 'BANKNIFTY 23OCT 51200 CE',
      lastPrice: 345.80,
      change: 42.60,
      changePct: 14.05,
      segment: 'NFO',
    ),
    WatchItem(
      symbol: 'BANKNIFTY 23OCT 50800 PE',
      lastPrice: 210.15,
      change: -28.40,
      changePct: -11.90,
      segment: 'NFO',
    ),
    WatchItem(
      symbol: 'SENSEX 01st OCT 72900 CE',
      lastPrice: 391.05,
      change: 290.20,
      changePct: 287.75,
      segment: 'BFO',
    ),
    WatchItem(
      symbol: 'SENSEX 01st OCT 72500 PE',
      lastPrice: 118.40,
      change: -45.60,
      changePct: -27.80,
      segment: 'BFO',
    ),
    WatchItem(
      symbol: 'FINNIFTY 29th 23900 CE',
      lastPrice: 95.20,
      change: 8.75,
      changePct: 10.12,
      segment: 'NFO',
    ),
    WatchItem(
      symbol: 'NIFTY NOV FUT',
      lastPrice: 22580.00,
      change: 65.40,
      changePct: 0.29,
      segment: 'NFO',
    ),
    WatchItem(
      symbol: 'BANKNIFTY NOV FUT',
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
    final q = _compact(query);
    if (q.isEmpty) return List.of(_catalog);
    return _catalog
        .where((e) =>
            _compact(e.symbol).contains(q) ||
            _compact(_displayForm(e.symbol)).contains(q))
        .toList();
  }

  @override
  bool isAdded(String symbol) => _items.any((e) => e.symbol == symbol);

  @override
  Future<void> addItem(WatchItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!isAdded(item.symbol)) {
      _items.add(item);
    }
  }

  /// How the unified renderer displays a symbol, e.g. `SENSEX 01st OCT ...`.
  static String _displayForm(String symbol) {
    final p = SymbolParts.parse(symbol);
    return [
      p.underlying,
      if (p.day != null) p.day!,
      if (p.ordinal != null) p.ordinal!,
      if (p.month != null) p.month!,
      if (p.strike != null) p.strike!,
      if (p.instrumentType != null) p.instrumentType!,
    ].join(' ');
  }

  /// Lower-case alphanumeric-only form so spacing/format never blocks a match.
  static String _compact(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}