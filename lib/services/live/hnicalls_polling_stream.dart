import 'dart:async';

import '../../core/api/hnicalls_client.dart';
import '../../core/api/hnicalls_config.dart';
import '../../core/utils/symbol_formatter.dart';
import '../../models/market/live_quote.dart';
import '../../models/market/option_chain.dart';
import 'market_stream.dart';

/// HTTP-polling transport — the one that actually delivers data today.
///
/// Verified working endpoints (probed Sept 2026):
///   * `/api/public/api/ticker_app`  -> index LTP + change %
///   * `/api/option-chain/{index}`   -> every strike's CE/PE LTP in one call
///   * `/api/ltp/{index}/{strike}/{CE|PE}` -> single contract LTP
///   * `/api/observation/`           -> ATM option premium text feed
///   * `/api/analysis/{instrument}`  -> ATM strike, premium, PCR, max pain
///
/// Contracts the watchlist or positions book shows are registered through
/// [trackSymbols]. One chain call per underlying then covers all of its
/// strikes, so adding rows to a list costs no extra requests.
class HnicallsPollingStream implements MarketStream {
  HnicallsPollingStream({
    required this.client,
    this.instruments = const ['NIFTY', 'BANKNIFTY', 'SENSEX', 'FINNIFTY'],
    this.interval = const Duration(seconds: 15),
    this.watchOptionLtp = false,
  });

  final HnicallsClient client;
  final List<String> instruments;
  final Duration interval;

  /// Also poll `/ltp/{instrument}/{strike}/{CE|PE}` for tracked contracts.
  final bool watchOptionLtp;

  final _controller = StreamController<StreamEvent>.broadcast();
  Timer? _timer;
  bool _stopped = false;
  bool _inFlight = false;

  /// Canonical API symbols the UI is showing, e.g. `NIFTY 22350 PE`.
  final _tracked = <String>{};

  /// The same symbols split by underlying so one chain call serves them all.
  final Map<String, List<SymbolParts>> _trackedByUnderlying = {};

  /// Register symbols whose LTP the UI needs. Non-derivative and unknown
  /// symbols are ignored — there is no upstream feed for them.
  ///
  /// Returns true when the tracked set changed, so the caller can pull a fresh
  /// cycle instead of waiting for the next interval.
  bool trackSymbols(Iterable<String> symbols) {
    var changed = false;
    for (final symbol in symbols) {
      final parts = SymbolParts.parse(symbol);
      final underlying = parts.apiInstrument;
      // Only index options can be priced from the chain. Cash, futures and
      // anything unparseable keep whatever price they already show.
      if (!parts.isOption || underlying.isEmpty) continue;
      if (parts.strikeValue == null) continue;
      if (_tracked.add(parts.apiSymbol)) changed = true;
      (_trackedByUnderlying[underlying] ??= []).removeWhere(
        (p) => p.apiSymbol == parts.apiSymbol,
      );
      _trackedByUnderlying[underlying]!.add(parts);
    }
    return changed;
  }

  /// Stop polling for [symbols] (a watchlist row was deleted, a book emptied).
  bool untrackSymbols(Iterable<String> symbols) {
    var changed = false;
    for (final symbol in symbols) {
      final parts = SymbolParts.parse(symbol);
      final underlying = parts.apiInstrument;
      if (!_tracked.remove(parts.apiSymbol)) continue;
      changed = true;
      final list = _trackedByUnderlying[underlying];
      if (list == null) continue;
      list.removeWhere((p) => p.apiSymbol == parts.apiSymbol);
      if (list.isEmpty) _trackedByUnderlying.remove(underlying);
    }
    return changed;
  }

  void clearTrackedSymbols() {
    _tracked.clear();
    _trackedByUnderlying.clear();
  }

  @override
  String get transportName => 'poll';

  @override
  bool get isSupported => true;

  @override
  Stream<StreamEvent> get events => _controller.stream;

  /// Fetches the chain, retrying once.
  ///
  /// Upstream's chain route fails intermittently (a 500 while the same minute's
  /// ticker call is fine), and it has been observed recovering within the same
  /// session. One cheap retry turns a good share of those into real data
  /// instead of a row stuck on its seeded price.
  Future<OptionChain> _chainWithRetry(String underlying) async {
    try {
      return await client.fetchOptionChain(underlying);
    } catch (_) {
      return client.fetchOptionChain(underlying);
    }
  }

  @override
  Future<void> start() async {
    _stopped = false;
    _emit(const StreamEvent(status: StreamStatus.connecting, transport: 'poll'));
    unawaited(tick());
    _timer = Timer.periodic(interval, (_) => tick());
  }

  /// One poll cycle. Safe to call manually (pull-to-refresh).
  Future<void> tick() async {
    if (_stopped || _inFlight) return;
    _inFlight = true;
    final quotes = <LiveQuote>[];
    var failures = 0;

    try {
      quotes.addAll(await client.fetchIndexQuotes());
    } catch (_) {
      failures++;
    }

    for (final instrument in instruments) {
      if (!HnicallsApiConfig.isKnownInstrument(instrument)) continue;
      try {
        final a = await client.fetchAnalysis(instrument);
        if (!a.isSuccess) {
          failures++;
          continue;
        }
        final spot = LiveQuote(
          symbol: a.instrument,
          instrument: a.instrument,
          ltp: a.spotPrice,
          change: 0,
          changePct: 0,
          at: a.analyzedAt ?? DateTime.now(),
          source: 'poll:analysis',
        );
        quotes.add(spot);
        final atm = a.atmOption;
        if (atm != null) {
          quotes.add(
            LiveQuote(
              symbol: atm.symbol,
              instrument: a.instrument,
              ltp: atm.ltp,
              change: atm.change,
              changePct: atm.changePct,
              at: a.analyzedAt ?? DateTime.now(),
              source: 'poll:analysis',
            ),
          );
        }
      } catch (_) {
        failures++;
      }
    }

    if (watchOptionLtp) {
      for (final instrument in instruments) {
        try {
          final chain = await client.fetchOptionChain(instrument);
          if (chain.isEmpty) {
            failures++;
            continue;
          }
          final atm = chain.atmRow;
          if (atm != null) {
            quotes.add(
              LiveQuote(
                symbol: '${instrument.toUpperCase()} ${atm.strike} CE',
                instrument: instrument.toUpperCase(),
                ltp: atm.callLtp,
                change: 0,
                changePct: 0,
                at: chain.expiry ?? DateTime.now(),
                source: 'poll:chain',
              ),
            );
          }
        } catch (_) {
          failures++;
        }
      }
    }

    // One chain call per underlying covers every tracked strike, so the whole
    // watchlist/book costs a handful of requests instead of one per row.
    //
    // This block must stay last: the analysis poll above writes the ATM
    // contract under the same symbol, and the chain is the authoritative price
    // for a strike the UI actually shows.
    for (final entry in _trackedByUnderlying.entries) {
      final underlying = entry.key;
      if (!HnicallsApiConfig.isKnownInstrument(underlying)) continue;
      var chainFailed = false;
      OptionChain? chain;
      try {
        chain = await _chainWithRetry(underlying);
        if (chain.isEmpty) {
          failures++;
          chainFailed = true;
        }
      } catch (_) {
        failures++;
        chainFailed = true;
      }
      final at = chain?.expiry ?? DateTime.now();
      for (final parts in entry.value) {
        final strike = parts.strikeValue;
        if (strike == null) continue;
        final ltp =
            chain?.ltpFor(strike, isCall: parts.instrumentType == 'CE');
        if (ltp == null || ltp <= 0) continue;
        quotes.add(
          LiveQuote(
            symbol: parts.apiSymbol,
            instrument: underlying,
            ltp: ltp,
            change: 0,
            changePct: 0,
            at: at,
            source: kContractLtpSource,
          ),
        );
      }
      // The chain covers every strike, but it is the flakier of the two
      // endpoints upstream. Anything it could not answer falls back to the
      // single-contract route so one bad response does not blank the list.
      for (final parts in entry.value) {
        final strike = parts.strikeValue;
        if (strike == null) continue;
        if (quotes.any((q) => q.symbol == parts.apiSymbol)) continue;
        try {
          final ltp = await client.fetchOptionLtp(
            underlying,
            strike,
            parts.instrumentType!,
          );
          if (ltp == null || ltp <= 0) continue;
          quotes.add(
            LiveQuote(
              symbol: parts.apiSymbol,
              instrument: underlying,
              ltp: ltp,
              change: 0,
              changePct: 0,
              at: DateTime.now(),
              source: kContractLtpSource,
            ),
          );
        } catch (_) {
          if (chainFailed) failures++;
        }
      }
    }

    _inFlight = false;
    if (_stopped) return;

    if (quotes.isEmpty) {
      _emit(
        StreamEvent(
          status: StreamStatus.degraded,
          message: failures > 0 ? 'all feeds failed ($failures)' : 'no data',
          transport: transportName,
        ),
      );
      return;
    }
    _emit(
      StreamEvent(
        status: failures == 0 ? StreamStatus.live : StreamStatus.degraded,
        quotes: quotes,
        message: failures == 0 ? null : '$failures feed(s) failed',
        transport: transportName,
      ),
    );
  }

  void _emit(StreamEvent e) {
    if (!_controller.isClosed) _controller.add(e);
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    await _controller.close();
  }
}
