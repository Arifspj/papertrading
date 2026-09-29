import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trade/core/market/lot_sizes.dart';
import 'package:paper_trade/repositories/watchlist_repository.dart';

void main() {
  late WatchlistRepository repo;

  setUp(() {
    repo = MockWatchlistRepository();
  });

  test('empty query exposes the whole F&O universe', () {
    final all = repo.searchSymbols('');
    final symbols = all.map((e) => e.symbol).toSet();

    for (final underlying in LotSizes.fnoUnderlyings) {
      expect(symbols, contains(underlying), reason: underlying);
    }
    expect(symbols.length, greaterThanOrEqualTo(190));
  });

  test('index underlyings are marked as cash segment, stocks as NFO', () {
    final bySymbol = {
      for (final item in repo.searchSymbols('')) item.symbol: item,
    };

    expect(bySymbol['NIFTY']!.segment, 'NSE');
    expect(bySymbol['SENSEX']!.segment, 'NSE');
    expect(bySymbol['RELIANCE']!.segment, 'NFO');
    expect(bySymbol['TCS']!.segment, 'NFO');
  });

  test('F&O universe rows carry no invented price', () {
    final bySymbol = {
      for (final item in repo.searchSymbols('')) item.symbol: item,
    };

    expect(bySymbol['TCS']!.lastPrice, 0);
    expect(bySymbol['TCS']!.change, 0);
    expect(bySymbol['TCS']!.changePct, 0);
  });

  test('query matches an FNO underlying', () {
    final results = repo.searchSymbols('reliance').map((e) => e.symbol).toList();
    expect(results, contains('RELIANCE'));
    expect(results, isNot(contains('TCS')));
  });

  test('query matches an index alias such as bankex', () {
    final results = repo.searchSymbols('bankex').map((e) => e.symbol).toList();
    expect(results, contains('BANKNIFTY'));
  });

  test('every searchable F&O underlying resolves to a lot size', () {
    for (final symbol in LotSizes.fnoUnderlyings) {
      expect(LotSizes.forInstrument(symbol), isNotNull, reason: symbol);
    }
  });
}
