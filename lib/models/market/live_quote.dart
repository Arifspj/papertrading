/// Identifies quotes that came from the shared `ticker_app` feed, which is the
/// only source the header marquee is allowed to render.
const kTickerQuoteSource = 'poll:ticker';

/// Identifies per-contract option premiums resolved from the option chain for
/// the rows the watchlist and positions book are currently showing.
const kContractLtpSource = 'poll:contract';

/// One normalised quote pushed by the live stream.
class LiveQuote {
  /// Canonical app symbol, e.g. `NIFTY 22700 CE` or `NIFTY`.
  final String symbol;

  /// Bare instrument for index/futures quotes, e.g. `NIFTY`.
  final String instrument;

  final double ltp;
  final double change;
  final double changePct;
  final DateTime at;

  /// `ws`, `poll:ltp`, `poll:ticker`, `poll:analysis`…
  final String source;

  const LiveQuote({
    required this.symbol,
    required this.instrument,
    required this.ltp,
    required this.change,
    required this.changePct,
    required this.at,
    required this.source,
  });

  bool get isGain => change >= 0;

  @override
  bool operator ==(Object other) =>
      other is LiveQuote &&
      other.symbol == symbol &&
      other.ltp == ltp &&
      other.changePct == changePct;

  @override
  int get hashCode => Object.hash(symbol, ltp, changePct);
}
