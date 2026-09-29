import 'dart:async';

import '../../core/api/hnicalls_client.dart';
import '../../core/api/hnicalls_config.dart';
import '../../models/market/live_quote.dart';
import 'market_stream.dart';

/// HTTP-polling transport — the one that actually delivers data today.
///
/// Verified working endpoints (probed Sept 2026):
///   * `/api/public/api/ticker_app`  -> index LTP + change %
///   * `/api/observation/`           -> ATM option premium text feed
///   * `/api/analysis/{instrument}`  -> ATM strike, premium, PCR, max pain
///
/// `/option-chain/*` and `/ltp/*` are polled only when [watchOptionLtp] is on;
/// they currently answer 500 upstream, so failures are swallowed and reported
/// as `degraded` instead of killing the stream.
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

  @override
  String get transportName => 'poll';

  @override
  bool get isSupported => true;

  @override
  Stream<StreamEvent> get events => _controller.stream;

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
