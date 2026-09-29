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

  /// The header ticker's own view of the world. Kept apart from [_quotes] so a
  /// same-symbol quote from another feed (the analysis spot price) cannot
  /// silently remove an index from the strip.
  final Map<String, LiveQuote> _tickerQuotes = {};
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
  /// The ticker keeps its own map, because the analysis poll writes the same
  /// index symbols (NIFTY, SENSEX…) under a different source and would
  /// otherwise evict the ticker prices from the shared one.
  List<LiveQuote> get tickerQuotes {
    final out = _tickerQuotes.values
        .where((q) => q.ltp != 0)
        .toList(growable: false);
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
    _tickerQuotes.clear();
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
      if (q.source == kTickerQuoteSource) _tickerQuotes[q.symbol] = q;
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
    if (_tickerQuotes.isEmpty) return false;
    _tickerQuotes.clear();
    _quotes.removeWhere((_, q) => q.source == kTickerQuoteSource);
    return true;
  }

  /// Pull one cycle from the active polling transport (no-op on WebSocket).
  Future<void> refresh() async {
    if (_active is HnicallsPollingStream) {
      await (_active! as HnicallsPollingStream).tick();
    }
  }

  /// Ask for live premiums for the contracts the UI is showing.
  ///
  /// Safe to call on every rebuild with the full list; only genuinely new
  /// symbols cost anything, and the first change pulls a cycle straight away so
  /// a freshly added row does not sit on its mock price for 15 seconds.
  void trackSymbols(Iterable<String> symbols) {
    final poll = _poll;
    if (poll is! HnicallsPollingStream) return;
    if (poll.trackSymbols(symbols)) unawaited(refresh());
  }

  void untrackSymbols(Iterable<String> symbols) {
    final poll = _poll;
    if (poll is! HnicallsPollingStream) return;
    if (poll.untrackSymbols(symbols)) unawaited(refresh());
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
