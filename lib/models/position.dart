enum PositionSide { long, short }

/// A single open (unrealized) position.
class Position {
  /// Stable per-row identity. The symbol is *not* unique — a book legitimately
  /// holds `NIFTY OCT 22350 PE` twice (an open lot and a squared-off one) — so
  /// retention has to key off this instead of the symbol.
  final String id;
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
  /// Contract expiry as a date. HNICALLS reports this on the option chain
  /// (`"expiry": "2026-10-01"`); null for non-expiring instruments.
  final DateTime? expiry;
  /// When the position was squared off. Null while the position is open.
  final DateTime? closedAt;

  const Position({
    required this.symbol,
    this.id = '',
    this.quantity = 0,
    this.averagePrice = 0,
    this.lastTradedPrice = 0,
    this.pnl = 0,
    this.instrumentType = '',
    this.product = 'NRML',
    this.segment = '',
    this.expiry,
    this.closedAt,
  });

  /// What retention uses as a removal key. Falls back to the symbol only when
  /// the source gave no id, which is worse than nothing but still better than
  /// dropping every row with that symbol.
  String get retentionKey => id.isEmpty ? 'sym:$symbol' : 'id:$id';

  PositionSide get side => quantity > 0 ? PositionSide.long : PositionSide.short;

  /// A closed position (squared off) is shown as Qty 0 / Avg 0.00.
  bool get isClosed => quantity == 0 && averagePrice == 0;

  Position copyWith({
    String? id,
    String? symbol,
    int? quantity,
    double? averagePrice,
    double? lastTradedPrice,
    double? pnl,
    String? instrumentType,
    String? product,
    String? segment,
    DateTime? expiry,
    DateTime? closedAt,
  }) {
    return Position(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      quantity: quantity ?? this.quantity,
      averagePrice: averagePrice ?? this.averagePrice,
      lastTradedPrice: lastTradedPrice ?? this.lastTradedPrice,
      pnl: pnl ?? this.pnl,
      instrumentType: instrumentType ?? this.instrumentType,
      product: product ?? this.product,
      segment: segment ?? this.segment,
      expiry: expiry ?? this.expiry,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  /// Per-unit move % relative to entry (flipped for shorts).
  double get pnlPct {
    final base = (lastTradedPrice - averagePrice) / averagePrice * 100;
    return side == PositionSide.long ? base : -base;
  }

  bool get isProfit => pnl > 0;
  bool get isLoss => pnl < 0;

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: asString(json['id'] ?? json['positionId'] ?? json['tradeId']),
      symbol: json['symbol'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      averagePrice: (json['averagePrice'] as num?)?.toDouble() ?? 0,
      lastTradedPrice: (json['lastTradedPrice'] as num?)?.toDouble() ?? 0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0,
      instrumentType: json['instrumentType'] as String? ?? '',
      product: json['product'] as String? ?? 'NRML',
      segment: json['segment'] as String? ?? '',
      expiry: _dateFrom(json['expiry'] ?? json['expiryDate'] ?? json['expiry_date']),
      closedAt: _dateFrom(
        json['closedAt'] ??
            json['closed_at'] ??
            json['exitTime'] ??
            json['exit_time'] ??
            json['squareOffTime'],
      ),
    );
  }

  /// Accepts `2026-10-01`, an ISO timestamp, or epoch millis. Brokers send all
  /// three, and a mis-parse here would silently make every position look
  /// non-expiring.
  static DateTime? _dateFrom(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      final v = raw.toInt();
      // Ten-digit values are seconds, thirteen-digit are millis.
      final ms = v.abs() < 100000000000 ? v * 1000 : v;
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return d.millisecondsSinceEpoch == 0 ? null : d;
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static String asString(Object? raw) {
    final s = raw?.toString().trim() ?? '';
    return s.isEmpty || s == 'null' ? '' : s;
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
      // Realised + floating P&L: squared-off positions stay in the total.
      total += p.pnl;
      if (p.isClosed) continue;
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