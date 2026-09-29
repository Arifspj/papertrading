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

  /// The polling transport is subscribed alongside the socket rather than
  /// instead of it. HNICALLS pushes index frames over the websocket but has no
  /// socket feed for option premiums, so the only way a tracked option contract
  /// ever gets a price is the HTTP poll. When this subscription used to be the
  /// fallback alone, a healthy socket locked the poll out and every option row
  /// sat on its mock price.
  StreamSubscription<StreamEvent>? _pollSub;
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
      _sub = _ws.events.listen(_onPrimaryEvent);
      await _ws.start();
      _fallbackTimer = Timer(wsGracePeriod, _fallbackToPolling);
      await _startPollAlongside();
    } else {
      await _fallbackToPolling();
    }
  }

  /// Bring the HTTP poll up next to the socket so option contracts keep a live
  /// price. It stays the secondary transport: the socket keeps the status.
  Future<void> _startPollAlongside() async {
    await _pollSub?.cancel();
    _pollSub = _poll.events.listen(_onSecondaryEvent);
    await _poll.start();
  }

  LiveOptionPoller? get _poller {
    final p = _poll;
    return p is LiveOptionPoller ? p : null;
  }

  Future<void> _fallbackToPolling() async {
    if (_wsDelivered || _status == StreamStatus.live) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    await _sub?.cancel();
    if (_active != null) await _ws.stop();
    // The poller may already be running as the sidecar; drop that subscription
    // so it is not driven twice (and does not end up with two poll timers).
    await _pollSub?.cancel();
    _pollSub = null;
    _active = _poll;
    _sub = _poll.events.listen(_onPrimaryEvent);
    await _poll.start();
  }

  /// Events from whichever transport currently owns the status.
  void _onPrimaryEvent(StreamEvent event) => _applyEvent(event, isPrimary: true);

  /// Events from the poller while the socket is primary. Prices are merged in,
  /// but the status is left alone: a momentary gap in the option poll must not
  /// report the whole app as degraded while the socket is still streaming
  /// indices. Identity decides the role, not the transport name, because a
  /// test double can share a name with the real thing.
  void _onSecondaryEvent(StreamEvent event) =>
      _applyEvent(event, isPrimary: false);

  void _applyEvent(StreamEvent event, {required bool isPrimary}) {
    if (event.status == StreamStatus.live && event.quotes.isNotEmpty) {
      _wsDelivered = true;
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
    }
    if (isPrimary) {
      _status = event.status;
      _message = event.message;
    }
    for (final q in event.quotes) {
      _quotes[q.symbol] = q;
      if (q.source == kTickerQuoteSource) _tickerQuotes[q.symbol] = q;
    }
    // A cycle that came back with nothing means the feed is gone, not that the
    // last prices are still good. Drop the ticker rows so the header strip
    // disappears, and let it come back on the next successful poll.
    if (isPrimary &&
        event.quotes.isEmpty &&
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

  /// Pull one poll cycle immediately. This talks to the poll transport
  /// directly rather than to the active one: while the socket is primary the
  /// poll is the only source of option premiums, and waiting for the active
  /// transport to be the poller meant a tracked contract never got a price.
  Future<void> refresh() async {
    await _poller?.tick();
  }

  /// Ask for live premiums for the contracts the UI is showing.
  ///
  /// Safe to call on every rebuild with the full list; only genuinely new
  /// symbols cost anything, and the first change pulls a cycle straight away so
  /// a freshly added row does not sit on its mock price for 15 seconds.
  void trackSymbols(Iterable<String> symbols) {
    final poll = _poller;
    if (poll == null) return;
    if (poll.trackSymbols(symbols)) unawaited(refresh());
  }

  void untrackSymbols(Iterable<String> symbols) {
    final poll = _poller;
    if (poll == null) return;
    if (poll.untrackSymbols(symbols)) unawaited(refresh());
  }

  Future<void> _teardown() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _pollSub?.cancel();
    _pollSub = null;
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
