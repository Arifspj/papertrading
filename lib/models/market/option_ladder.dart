import '../../core/utils/symbol_formatter.dart';
import '../market/option_chain.dart';

/// One tradable contract offered by the option-chain picker.
class OptionContract {
  /// Canonical symbol, e.g. `NIFTY 01st OCT 22600 CE`.
  ///
  /// Built with the expiry tokens in place so [SymbolParts.parse] recovers the
  /// same `apiSymbol` the live poller keys its quotes on. Without those tokens
  /// a symbol added from here would never pick up an LTP.
  final String symbol;

  final String instrument;
  final int strike;
  final bool isCall;

  /// Last traded premium. Zero when the chain was unavailable, in which case
  /// the row renders as "—" rather than a fake price.
  final double ltp;

  const OptionContract({
    required this.symbol,
    required this.instrument,
    required this.strike,
    required this.isCall,
    this.ltp = 0,
  });

  String get optionType => isCall ? 'CE' : 'PE';
}

/// Where a ladder's strikes came from, so the picker can show that a
/// synthesised ladder is not real chain data.
enum OptionLadderSource {
  /// Real strike ladder from `/api/option-chain/{instrument}`.
  chain,

  /// Built around the ATM strike reported by `/api/analysis/{instrument}`,
  /// because the chain route was unavailable.
  atmLadder,
}

/// The contracts available to add for one underlying.
class OptionLadder {
  final String instrument;
  final List<OptionContract> contracts;
  final OptionLadderSource source;

  /// Spot and ATM as upstream reported them, when known.
  final double spotPrice;
  final int atmStrike;
  final DateTime? expiry;

  const OptionLadder({
    required this.instrument,
    required this.contracts,
    required this.source,
    this.spotPrice = 0,
    this.atmStrike = 0,
    this.expiry,
  });

  bool get isEmpty => contracts.isEmpty;
  bool get hasPrices => contracts.any((c) => c.ltp > 0);

  /// How many strikes either side of the ATM a synthesised ladder covers.
  static const atmSpan = 5;

  /// Index strike gaps. A synthesised ladder needs an interval because there is
  /// no chain to read one from.
  static const Map<String, int> strikeStep = {
    'NIFTY': 50,
    'BANKNIFTY': 100,
    'FINNIFTY': 50,
    'SENSEX': 100,
    'MIDCPNIFTY': 25,
  };

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  /// Strikes either side of [atmStrike] on [step], snapped to the step grid.
  static List<int> strikesAround(int atmStrike, int step, {int span = atmSpan}) {
    if (atmStrike <= 0 || step <= 0) return const [];
    final first = ((atmStrike / step).round()) * step;
    return [
      for (var i = -span; i <= span; i++)
        if (first + i * step > 0) first + i * step,
    ];
  }

  /// Strikes either side of the ATM for [instrument], using its known step.
  static List<int> strikesAroundFor(String instrument, int atmStrike) =>
      strikesAround(atmStrike, strikeStep[instrument.toUpperCase()] ?? 50);

  /// `NIFTY 01st OCT 22600 CE`.
  ///
  /// The day is zero-padded to match the canonical symbols the rest of the app
  /// uses (`SENSEX 01st OCT 72900 PE`), so a symbol added here is byte-identical
  /// to the one the poller resolves for the same contract.
  ///
  /// Falls back to a month-less `NIFTY 22600 CE` when the expiry is unknown,
  /// which still parses to the right API symbol — it just loses the display
  /// tokens.
  static String symbolFor(
    String instrument,
    DateTime? expiry,
    int strike,
    bool isCall,
  ) {
    final type = isCall ? 'CE' : 'PE';
    final inst = instrument.toUpperCase();
    if (expiry == null) return '$inst $strike $type';
    final day = expiry.day.toString().padLeft(2, '0');
    final month = _months[(expiry.month - 1).clamp(0, 11)];
    return '$inst $day${SymbolParts.ordinalSuffix(expiry.day)} '
        '$month $strike $type';
  }

  /// Build a ladder around the ATM, for when the chain route is unavailable.
  ///
  /// Premiums are left unknown rather than guessed: a row with no price shows
  /// "—" and fills in as soon as the poller can price it.
  factory OptionLadder.aroundAtm({
    required String instrument,
    required int atmStrike,
    double spotPrice = 0,
    DateTime? expiry,
  }) {
    final inst = instrument.toUpperCase();
    return OptionLadder(
      instrument: inst,
      contracts: [
        for (final strike in strikesAroundFor(inst, atmStrike))
          for (final isCall in const [true, false])
            OptionContract(
              symbol: symbolFor(inst, expiry, strike, isCall),
              instrument: inst,
              strike: strike,
              isCall: isCall,
            ),
      ],
      source: OptionLadderSource.atmLadder,
      spotPrice: spotPrice,
      atmStrike: atmStrike,
      expiry: expiry,
    );
  }

  /// Build a ladder from a real option chain, carrying each contract's premium.
  factory OptionLadder.fromChain({
    required String instrument,
    required OptionChain chain,
  }) {
    final inst = instrument.toUpperCase();
    final expiry = chain.expiry;
    return OptionLadder(
      instrument: inst,
      contracts: [
        for (final row in chain.rows)
          if (row.strike > 0)
            for (final isCall in const [true, false])
              OptionContract(
                symbol: symbolFor(inst, expiry, row.strike, isCall),
                instrument: inst,
                strike: row.strike,
                isCall: isCall,
                ltp: isCall ? row.callLtp : row.putLtp,
              ),
      ],
      source: OptionLadderSource.chain,
      spotPrice: chain.spotPrice,
      atmStrike: chain.atmRow?.strike ?? 0,
      expiry: expiry,
    );
  }
}
