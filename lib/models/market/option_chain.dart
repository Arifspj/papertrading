import '../../core/api/json_utils.dart';

class OptionChainRow {
  final int strike;
  final double callLtp;
  final double putLtp;
  final double callOi;
  final double putOi;
  final double callOiChg;
  final double putOiChg;
  final double callIv;
  final double putIv;
  final double callDelta;
  final double putDelta;
  final double callGamma;
  final double putGamma;
  final double callTheta;
  final double putTheta;
  final double callVega;
  final double putVega;
  final double callVolume;
  final double putVolume;

  const OptionChainRow({
    required this.strike,
    this.callLtp = 0,
    this.putLtp = 0,
    this.callOi = 0,
    this.putOi = 0,
    this.callOiChg = 0,
    this.putOiChg = 0,
    this.callIv = 0,
    this.putIv = 0,
    this.callDelta = 0,
    this.putDelta = 0,
    this.callGamma = 0,
    this.putGamma = 0,
    this.callTheta = 0,
    this.putTheta = 0,
    this.callVega = 0,
    this.putVega = 0,
    this.callVolume = 0,
    this.putVolume = 0,
  });

  factory OptionChainRow.fromJson(Map<String, dynamic> j) => OptionChainRow(
        strike: asInt(j['STRIKE'] ?? j['strike']),
        callLtp: asDoubleOr(j['CALL_LTP'], 0),
        putLtp: asDoubleOr(j['PUT_LTP'], 0),
        callOi: asDoubleOr(j['CALL_OI'], 0),
        putOi: asDoubleOr(j['PUT_OI'], 0),
        callOiChg: asDoubleOr(j['CALL_OI_CHG'], 0),
        putOiChg: asDoubleOr(j['PUT_OI_CHG'], 0),
        callIv: asDoubleOr(j['CALL_IV'], 0),
        putIv: asDoubleOr(j['PUT_IV'], 0),
        callDelta: asDoubleOr(j['CALL_DELTA'], 0),
        putDelta: asDoubleOr(j['PUT_DELTA'], 0),
        callGamma: asDoubleOr(j['CALL_GAMMA'], 0),
        putGamma: asDoubleOr(j['PUT_GAMMA'], 0),
        callTheta: asDoubleOr(j['CALL_THETA'], 0),
        putTheta: asDoubleOr(j['PUT_THETA'], 0),
        callVega: asDoubleOr(j['CALL_VEGA'], 0),
        putVega: asDoubleOr(j['PUT_VEGA'], 0),
        callVolume: asDoubleOr(j['CALL_VOLUME'], 0),
        putVolume: asDoubleOr(j['PUT_VOLUME'], 0),
      );
}

/// `GET /api/option-chain/{instrument}` — full strike ladder plus the derived
/// metrics the UI needs (ATM, PCR, max pain, IV skew).
class OptionChain {
  final String status;
  final double spotPrice;
  final DateTime? expiry;
  final List<OptionChainRow> rows;

  const OptionChain({
    required this.status,
    this.spotPrice = 0,
    this.expiry,
    this.rows = const [],
  });

  bool get isSuccess => status.toLowerCase() == 'success';
  bool get isEmpty => rows.isEmpty;

  double get totalCallOi => rows.fold(0.0, (s, r) => s + r.callOi);
  double get totalPutOi => rows.fold(0.0, (s, r) => s + r.putOi);
  double get pcr => totalCallOi == 0 ? 0 : totalPutOi / totalCallOi;

  /// Strike closest to spot.
  OptionChainRow? get atmRow {
    if (rows.isEmpty) return null;
    var best = rows.first;
    var bestDist = (best.strike - spotPrice).abs();
    for (final r in rows) {
      final d = (r.strike - spotPrice).abs();
      if (d < bestDist) {
        best = r;
        bestDist = d;
      }
    }
    return best;
  }

  /// Strike where total call OI equals total put OI.
  OptionChainRow? get maxPainRow {
    if (rows.isEmpty) return null;
    OptionChainRow? best;
    var bestGap = double.infinity;
    for (final r in rows) {
      final gap = (r.callOi - r.putOi).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = r;
      }
    }
    return best;
  }

  /// Put IV − call IV at ATM.
  double get ivSkew {
    final atm = atmRow;
    if (atm == null) return 0;
    return atm.putIv - atm.callIv;
  }

  /// HNICALLS returns `data` either as a list or as a map wrapping a list.
  factory OptionChain.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final list = raw is List
        ? raw
        : raw is Map
            ? (raw['data'] ?? raw['chain'] ?? raw['rows'])
            : null;
    final rows = (list is List)
        ? list
            .whereType<Map>()
            .map((e) => OptionChainRow.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false)
        : const <OptionChainRow>[];
    rows.sort((a, b) => a.strike.compareTo(b.strike));
    return OptionChain(
      status: asString(json['status']),
      spotPrice: asDoubleOr(json['spot_price'], 0),
      expiry: DateTime.tryParse(asString(json['expiry'])),
      rows: rows,
    );
  }

  /// Best LTP for a contract the watchlist is tracking, or null.
  double? ltpFor(int strike, {required bool isCall}) {
    for (final r in rows) {
      if (r.strike != strike) continue;
      final v = isCall ? r.callLtp : r.putLtp;
      if (v > 0) return v;
    }
    return null;
  }

  OptionChainRow? rowFor(int strike) {
    for (final r in rows) {
      if (r.strike == strike) return r;
    }
    return null;
  }
}
