import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/hnicalls_client.dart';
import '../../models/market/live_quote.dart';
import 'hnicalls_polling_stream.dart';
import 'hnicalls_ws_stream.dart';
import 'market_stream.dart';

/// Single entry point the UI talks to.
///
/// Prefers the WebSocket transport; if the socket cannot deliver quotes within
/// [wsGracePeriod] it silently switches to HTTP polling and keeps the latest
/// quote map warm. Callers only ever see [quotes] and [status].
class LiveMarketController extends ChangeNotifier {
  /// [ws] and [poll] accept any [MarketStream], so tests can inject fakes.
  LiveMarketController({
    HnicallsClient? client,
    MarketStream? ws,
    MarketStream? poll,
    this.autoStart = true,
    this.wsGracePeriod = const Duration(seconds: 6),
  })  : _client = client ?? HnicallsClient(),
        _ws = ws ?? HnicallsWebSocketStream(),
        _poll =
            poll ??
            HnicallsPollingStream(
              client: client ?? HnicallsClient(),
              interval: const Duration(seconds: 15),
            ) {
    if (autoStart) {
      // ChangeNotifierProvider builds this before any widget listens, so kick
      // the network off in a microtask instead of blocking the first frame.
      scheduleMicrotask(start);
    }
  }

  final HnicallsClient _client;
  final MarketStream _ws;
  final MarketStream _poll;
  final bool autoStart;
  final Duration wsGracePeriod;

  final Map<String, LiveQuote> _quotes = {};
  StreamSubscription<StreamEvent>? _sub;
  StreamStatus _status = StreamStatus.idle;
  MarketStream? _active;
  String? _message;
  Timer? _fallbackTimer;
  bool _wsDelivered = false;

  Map<String, LiveQuote> get quotes => Map.unmodifiable(_quotes);
  StreamStatus get status => _status;
  String? get message => _message;
  bool get isLive => _status == StreamStatus.live;
  String get transportName => _active?.transportName ?? 'none';

  /// Quotes suitable for the header ticker: real prices from the ticker feed
  /// only, one entry per symbol, sorted for a stable marquee.
  ///
  /// Cash rows the watchlist seeds with a placeholder price are dropped, so
  /// the strip never shows a stale zero. A quote only counts once a price has
  /// actually arrived. Option LTP and chain prices are deliberately excluded
  /// so they cannot leak into the header.
  List<LiveQuote> get tickerQuotes {
    final seen = <String>{};
    final out = <LiveQuote>[];
    for (final q in _quotes.values) {
      if (q.source != kTickerQuoteSource) continue;
      if (q.ltp == 0 || !seen.add(q.symbol)) continue;
      out.add(q);
    }
    out.sort((a, b) => a.symbol.compareTo(b.symbol));
    return out;
  }

  /// Whether there is anything worth showing in the header ticker. The header
  /// hides its ticker strip entirely while this is false.
  bool get hasTickerData => tickerQuotes.isNotEmpty;

  /// Drop the cached ticker quotes and tell listeners, so a feed outage
  /// collapses the header strip instead of leaving stale prices on screen.
  ///
  /// Only the ticker feed is cleared; option LTP and chain quotes stay warm.
  void clearTickerQuotes() {
    if (_dropTickerQuotes()) notifyListeners();
  }

  /// A quote for a canonical symbol, or null while nothing has arrived yet.
  LiveQuote? quoteFor(String symbol) => _quotes[symbol];

  Future<void> start() async {
    await _teardown();
    _quotes.clear();
    _wsDelivered = false;
    if (_ws.isSupported) {
      _active = _ws;
      _sub = _ws.events.listen(_onEvent);
      await _ws.start();
      _fallbackTimer = Timer(wsGracePeriod, _fallbackToPolling);
    } else {
      await _fallbackToPolling();
    }
  }

  Future<void> _fallbackToPolling() async {
    if (_wsDelivered || _status == StreamStatus.live) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    await _sub?.cancel();
    if (_active != null) await _ws.stop();
    _active = _poll;
    _sub = _poll.events.listen(_onEvent);
    await _poll.start();
  }

  void _onEvent(StreamEvent event) {
    if (event.status == StreamStatus.live && event.quotes.isNotEmpty) {
      _wsDelivered = true;
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
    }
    _status = event.status;
    _message = event.message;
    for (final q in event.quotes) {
      _quotes[q.symbol] = q;
    }
    // A cycle that came back with nothing means the feed is gone, not that the
    // last prices are still good. Drop the ticker rows so the header strip
    // disappears, and let it come back on the next successful poll.
    if (event.quotes.isEmpty &&
        event.status == StreamStatus.degraded) {
      _dropTickerQuotes();
    }
    notifyListeners();
  }

  /// Removes the ticker rows and reports whether anything was actually dropped.
  bool _dropTickerQuotes() {
    final stale = _quotes.values
        .where((q) => q.source == kTickerQuoteSource)
        .map((q) => q.symbol)
        .toSet();
    if (stale.isEmpty) return false;
    for (final symbol in stale) {
      _quotes.remove(symbol);
    }
    return true;
  }

  /// Pull one cycle from the active polling transport (no-op on WebSocket).
  Future<void> refresh() async {
    if (_active is HnicallsPollingStream) {
      await (_active! as HnicallsPollingStream).tick();
    }
  }

  Future<void> _teardown() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    await _sub?.cancel();
    _sub = null;
    _active = null;
  }

  @override
  void dispose() {
    unawaited(_teardown());
    unawaited(_ws.stop());
    unawaited(_poll.stop());
    _client.close();
    super.dispose();
  }
}
