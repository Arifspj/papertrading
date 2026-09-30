import '../../core/api/hnicalls_client.dart';
import '../../core/api/hnicalls_config.dart';
import '../../models/market/option_analysis.dart';
import '../../models/market/option_ladder.dart';

/// Loads the option contracts available to add to the watchlist.
///
/// The chain route is the source of truth — it is the only call that returns
/// every strike *and* its premium in one request. It is also the flakier route
/// upstream, answering `500 Failed to fetch option chain from Upstox` whenever
/// their own token or market-hours check fails, while `/analysis` keeps
/// answering. So a failed chain falls back to a ladder built around the ATM
/// strike analysis reports: the symbols are still real and still addable, they
/// just arrive without premiums and fill in from the live poller.
class OptionSymbolService {
  OptionSymbolService({
    required this.client,
    this.instruments = const ['NIFTY', 'SENSEX', 'BANKNIFTY', 'FINNIFTY'],
  });

  final HnicallsClient client;
  final List<String> instruments;

  List<String> get supportedInstruments =>
      instruments.where(HnicallsApiConfig.isKnownInstrument).toList(growable: false);

  /// Loads the ladder for [instrument].
  ///
  /// [preferChain] is set false to force the ATM fallback, which the picker
  /// uses to offer a usable ladder straight away rather than showing an error
  /// while the chain route is down.
  Future<OptionLadder> load(String instrument, {bool preferChain = true}) async {
    final inst = instrument.toUpperCase();

    if (preferChain) {
      try {
        final chain = await client.fetchOptionChain(inst);
        if (chain.isSuccess && !chain.isEmpty) {
          return OptionLadder.fromChain(instrument: inst, chain: chain);
        }
      } catch (_) {
        // Fall through to the ATM ladder below.
      }
    }

    return _atmLadder(inst);
  }

  /// The ATM-based fallback, used when the chain route is unavailable.
  Future<OptionLadder> _atmLadder(String instrument) async {
    OptionAnalysis? analysis;
    try {
      analysis = await client.fetchAnalysis(instrument);
    } catch (_) {
      analysis = null;
    }
    if (analysis == null || !analysis.isSuccess || analysis.strike <= 0) {
      return OptionLadder(
        instrument: instrument,
        contracts: const [],
        source: OptionLadderSource.atmLadder,
      );
    }
    return OptionLadder.aroundAtm(
      instrument: instrument,
      atmStrike: analysis.strike,
      spotPrice: analysis.spotPrice,
      expiry: analysis.expiryDate,
    );
  }
}
