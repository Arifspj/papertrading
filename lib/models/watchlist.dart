/// A single quote row in the market watchlist.
///
/// Weekly/monthly tagging is derived from [symbol] by `SymbolParts`, so the
/// same string always renders identically on every page.
class WatchItem {
  final String symbol;
  final double lastPrice;
  final double change;
  final double changePct;
  final String segment;

  const WatchItem({
    required this.symbol,
    required this.lastPrice,
    required this.change,
    required this.changePct,
    required this.segment,
  });

  bool get isGain => change >= 0;

  factory WatchItem.fromJson(Map<String, dynamic> json) {
    return WatchItem(
      symbol: json['symbol'] as String? ?? '',
      lastPrice: (json['lastPrice'] as num?)?.toDouble() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      changePct: (json['changePct'] as num?)?.toDouble() ?? 0,
      segment: json['segment'] as String? ?? '',
    );
  }
}