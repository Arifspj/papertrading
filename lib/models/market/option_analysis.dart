import '../../core/api/json_utils.dart';

class AnalysisFactor {
  final String name;
  final String impact;
  final String signal;

  const AnalysisFactor({
    required this.name,
    required this.impact,
    required this.signal,
  });

  factory AnalysisFactor.fromJson(Map<String, dynamic> json) => AnalysisFactor(
        name: asString(json['name']),
        impact: asString(json['impact']),
        signal: asString(json['signal']),
      );
}

/// `GET /api/analysis/{instrument}` — ATM snapshot + PCR / max-pain / skew.
class OptionAnalysis {
  final String status;
  final String instrument;
  final DateTime? analyzedAt;
  final DateTime? expiryDate;
  final String? expiryType;
  final double spotPrice;
  final int strike;
  final double premium;
  final String optionType;
  final int lotSize;
  final double pcr;
  final double pcrChange;
  final String pcrStage;
  final String pcrAction;
  final String pcrSentiment;
  final double? maxPain;
  final double totalCallOi;
  final double totalPutOi;
  final double callOiChg;
  final double putOiChg;
  final double? ivSkew;
  final double? delta;
  final double? gamma;
  final double? theta;
  final double? vega;
  final List<double> support;
  final List<double> resistance;
  final String sentiment;
  final String confidence;
  final double score;
  final String oiSignal;
  final String observation;
  final String source;
  final List<AnalysisFactor> factors;

  const OptionAnalysis({
    required this.status,
    required this.instrument,
    this.analyzedAt,
    this.expiryDate,
    this.expiryType,
    this.spotPrice = 0,
    this.strike = 0,
    this.premium = 0,
    this.optionType = 'NEUTRAL',
    this.lotSize = 0,
    this.pcr = 0,
    this.pcrChange = 0,
    this.pcrStage = '',
    this.pcrAction = '',
    this.pcrSentiment = '',
    this.maxPain,
    this.totalCallOi = 0,
    this.totalPutOi = 0,
    this.callOiChg = 0,
    this.putOiChg = 0,
    this.ivSkew,
    this.delta,
    this.gamma,
    this.theta,
    this.vega,
    this.support = const [],
    this.resistance = const [],
    this.sentiment = '',
    this.confidence = '',
    this.score = 0,
    this.oiSignal = '',
    this.observation = '',
    this.source = '',
    this.factors = const [],
  });

  bool get isSuccess => status.toLowerCase() == 'success';

  factory OptionAnalysis.fromJson(Map<String, dynamic> json) {
    final factors = (json['factors'] as List?)
            ?.whereType<Map>()
            .map((f) => AnalysisFactor.fromJson(f.cast<String, dynamic>()))
            .toList(growable: false) ??
        const <AnalysisFactor>[];
    return OptionAnalysis(
      status: asString(json['status']),
      instrument: asString(json['instrument']),
      analyzedAt: DateTime.tryParse(asString(json['analyzedAt'])),
      expiryDate: DateTime.tryParse(asString(json['expiryDate'])),
      expiryType: json['expiryType'] as String?,
      spotPrice: asDoubleOr(json['spotPrice'], 0),
      strike: asInt(json['strike']),
      premium: asDoubleOr(json['premium'], 0),
      optionType: asString(json['option_type'], 'NEUTRAL'),
      lotSize: asInt(json['lot_size']),
      pcr: asDoubleOr(json['pcr'], 0),
      pcrChange: asDoubleOr(json['pcr_change'], 0),
      pcrStage: asString(json['pcr_stage']),
      pcrAction: asString(json['pcr_action']),
      pcrSentiment: asString(json['pcr_sentiment']),
      maxPain: asDouble(json['max_pain']),
      totalCallOi: asDoubleOr(json['total_call_oi'], 0),
      totalPutOi: asDoubleOr(json['total_put_oi'], 0),
      callOiChg: asDoubleOr(json['call_oi_chg'], 0),
      putOiChg: asDoubleOr(json['put_oi_chg'], 0),
      ivSkew: asDouble(json['iv_skew']),
      delta: asDouble(json['delta']),
      gamma: asDouble(json['gamma']),
      theta: asDouble(json['theta']),
      vega: asDouble(json['vega']),
      support: asDoubleList(json['support']),
      resistance: asDoubleList(json['resistance']),
      sentiment: asString(json['sentiment']),
      confidence: asString(json['confidence']),
      score: asDoubleOr(json['score'], 0),
      oiSignal: asString(json['oi_signal']),
      observation: asString(json['observation']),
      source: asString(json['source']),
      factors: factors,
    );
  }

  /// The ATM contract described by this analysis, as a live-quote payload.
  ///
  /// `option_type` decides the suffix: `CALL` → `CE`, `PUT` → `PE`, and
  /// `NEUTRAL` (their "at-the-money, no directional lean" value) → no suffix.
  /// The ATM contract this analysis is describing, or null when the side is
  /// unknown.
  ///
  /// Upstream answers `option_type: "NEUTRAL"` most of the time, which does not
  /// say whether the premium belongs to the call or the put. Emitting a quote
  /// anyway would need a side to key it on, and inventing one would price the
  /// wrong contract — so this stays null unless `CALL`/`PUT` is actually given.
  ///
  /// `change` and `changePct` are always zero: analysis reports no previous
  /// close for the contract. They used to be derived as `premium - strike`,
  /// which is not a change at all (a 22600 strike with a 339 premium reported
  /// -22260, or -99.5%).
  ({String symbol, double ltp, double change, double changePct})? get atmOption {
    if (instrument.isEmpty || strike == 0) return null;
    final type = switch (optionType.toUpperCase()) {
      'CALL' => 'CE',
      'PUT' => 'PE',
      _ => '',
    };
    if (type.isEmpty) return null;
    return (
      symbol: '$instrument $strike $type',
      ltp: premium,
      change: 0,
      changePct: 0,
    );
  }
}
