enum PositionSide { long, short }

/// A single open (unrealized) position.
class Position {
  final String symbol;
  /// Signed quantity. Negative => short, positive => long.
  final int quantity;
  final double averagePrice;
  final double lastTradedPrice;
  /// Explicit unrealised P&L in INR.
  final double pnl;
  /// Optional instrument tag e.g. "FUT", "CE", "PE", "EQ".
  final String instrumentType;
  /// Product type e.g. "NRML", "MIS" (drives the tag chip in the UI).
  final String product;
  /// Segment label e.g. "NFO", "BFO".
  final String segment;

  const Position({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
    required this.lastTradedPrice,
    required this.pnl,
    this.instrumentType = '',
    this.product = 'NRML',
    this.segment = '',
  });

  PositionSide get side => quantity > 0 ? PositionSide.long : PositionSide.short;

  /// A closed position (squared off) is shown as Qty 0 / Avg 0.00.
  bool get isClosed => quantity == 0 && averagePrice == 0;

  /// Per-unit move % relative to entry (flipped for shorts).
  double get pnlPct {
    final base = (lastTradedPrice - averagePrice) / averagePrice * 100;
    return side == PositionSide.long ? base : -base;
  }

  bool get isProfit => pnl > 0;
  bool get isLoss => pnl < 0;

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      symbol: json['symbol'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      averagePrice: (json['averagePrice'] as num?)?.toDouble() ?? 0,
      lastTradedPrice: (json['lastTradedPrice'] as num?)?.toDouble() ?? 0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0,
      instrumentType: json['instrumentType'] as String? ?? '',
      product: json['product'] as String? ?? 'NRML',
      segment: json['segment'] as String? ?? '',
    );
  }
}

/// Overall paper-trading book summary.
class PortfolioSummary {
  final double totalPnl;
  final int openPositions;
  final int longPositions;
  final int shortPositions;
  final int winPositions;
  final int lossPositions;

  const PortfolioSummary({
    required this.totalPnl,
    required this.openPositions,
    required this.longPositions,
    required this.shortPositions,
    required this.winPositions,
    required this.lossPositions,
  });

  factory PortfolioSummary.fromPositions(List<Position> positions) {
    var total = 0.0;
    var long = 0;
    var short = 0;
    var win = 0;
    var loss = 0;
    for (final p in positions) {
      if (p.isClosed) continue;
      total += p.pnl;
      if (p.side == PositionSide.long) {
        long++;
      } else {
        short++;
      }
      if (p.isProfit) {
        win++;
      } else if (p.isLoss) {
        loss++;
      }
    }
    return PortfolioSummary(
      totalPnl: total,
      openPositions: positions.length,
      longPositions: long,
      shortPositions: short,
      winPositions: win,
      lossPositions: loss,
    );
  }
}

enum PositionFilter { all, long, short, profit, loss }

extension PositionFilterX on PositionFilter {
  String get label => switch (this) {
        PositionFilter.all => 'All',
        PositionFilter.long => 'Long',
        PositionFilter.short => 'Short',
        PositionFilter.profit => 'Profit',
        PositionFilter.loss => 'Loss',
      };
}

bool positionMatches(Position p, PositionFilter f, String query) {
  final symbolFiltered =
      query.trim().isEmpty || p.symbol.toLowerCase().contains(query.trim().toLowerCase());
  if (!symbolFiltered) return false;

  if (p.isClosed) return f == PositionFilter.all;

  return switch (f) {
    PositionFilter.all => true,
    PositionFilter.long => p.side == PositionSide.long,
    PositionFilter.short => p.side == PositionSide.short,
    PositionFilter.profit => p.isProfit,
    PositionFilter.loss => p.isLoss,
  };
}