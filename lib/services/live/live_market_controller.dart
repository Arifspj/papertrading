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

  /// A quote for a canonical symbol, or null while nothing has arrived yet.
  LiveQuote? quoteFor(String symbol) => _quotes[symbol];

  Future<void> start() async {    await _teardown();
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
    var changed = false;
    for (final q in event.quotes) {
      if (_quotes[q.symbol] != q) {
        _quotes[q.symbol] = q;
        changed = true;
      }
    }
    if (changed || event.status != _status) notifyListeners();
    notifyListeners();
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
