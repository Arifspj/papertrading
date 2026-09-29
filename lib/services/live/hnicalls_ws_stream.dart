import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api/hnicalls_config.dart';
import '../../core/api/json_utils.dart';
import '../../models/market/live_quote.dart';
import 'market_stream.dart';

/// WebSocket transport for HNICALLS.
///
/// Protocol (as advertised on their `/websocket` page): connect to
/// `wss://api.hnicalls.com/ws/v1`, then send a subscribe frame; the server
/// replies with tick frames on the subscribed channels and expects periodic
/// heartbeats. The exact frame names are not documented, so this client is
/// deliberately forgiving: it accepts several payload shapes, tolerates
/// silent servers, and reports `degraded` rather than throwing.
///
/// Reality check (probed Sept 2026): the endpoint answers **404**, so
/// [LiveMarketController][controller] transparently falls back to polling.
/// Point `--dart-define=HNICALLS_WS_URL=...` at a real server to enable it.
class HnicallsWebSocketStream implements MarketStream {
  HnicallsWebSocketStream({
    this.url = HnicallsApiConfig.wsUrl,
    this.channels = const ['ticker', 'analysis', 'observations'],
    this.heartbeat = const Duration(seconds: 20),
    this.reconnectBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(seconds: 30),
  });

  final String url;
  final List<String> channels;
  final Duration heartbeat;
  final Duration reconnectBackoff;
  final Duration maxBackoff;

  final _controller = StreamController<StreamEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _stopped = false;
  int _attempt = 0;

  @override
  String get transportName => 'websocket';

  @override
  bool get isSupported => url.isNotEmpty && url.startsWith('ws');

  @override
  Stream<StreamEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    _stopped = false;
    _connect();
  }

  void _connect() {
    if (_stopped) return;
    _emit(const StreamEvent(status: StreamStatus.connecting, transport: 'websocket'));
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      // A failed handshake (e.g. HNICALLS answering 404) surfaces here as well
      // as on the stream. Nothing awaits `ready`, so without a handler its
      // error would escape as an unhandled zone error and take the app down.
      // The stream's onError below is the real handler.
      unawaited(channel.ready.then<void>((_) {}, onError: (Object _) {}));
      _sub = channel.stream.listen(
        _onMessage,
        onError: (Object e) => _scheduleReconnect('socket error: $e'),
        onDone: () => _scheduleReconnect('socket closed by server'),
        cancelOnError: true,
      );
      _attempt = 0;
      _sendSubscribe();
      _startHeartbeat();
    } catch (e) {
      _scheduleReconnect('connect failed: $e');
    }
  }

  void _sendSubscribe() {
    _send({
      'action': 'subscribe',
      'channels': channels,
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeat, (_) {
      _send({'action': 'ping', 'ts': DateTime.now().toUtc().toIso8601String()});
    });
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (_) {
      // Sink already closed; the onDone handler will schedule a reconnect.
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) json = decoded;
      if (decoded is Map) json = decoded.cast<String, dynamic>();
    } catch (_) {
      // Not JSON — ignore, the feed may send plain text.
      return;
    }
    if (json == null) return;

    final quotes = _parseQuotes(json);
    if (quotes.isEmpty) {
      if (asString(json['type']) == 'error' || json['error'] != null) {
        _emit(
          StreamEvent(
            status: StreamStatus.degraded,
            message: asString(json['error'], 'feed error'),
            transport: transportName,
          ),
        );
      }
      return;
    }
    _emit(
      StreamEvent(
        status: StreamStatus.live,
        quotes: quotes,
        transport: transportName,
      ),
    );
  }

  /// Accepts the shapes HNICALLS is documented to use as well as the shapes
  /// their HTTP endpoints return, so the same frames can be replayed locally.
  List<LiveQuote> _parseQuotes(Map<String, dynamic> json) {
    final now = DateTime.now();
    final out = <LiveQuote>[];

    Object? payload = json['quotes'] ?? json['data'] ?? json['ticker'];
    if (payload is Map) payload = [payload];
    if (payload is! List) return out;

    for (final item in payload.whereType<Map>()) {
      final m = item.cast<String, dynamic>();
      final symbol = asString(m['symbol'] ?? m['tradingsymbol'] ?? m['instrument']);
      final ltp = asDouble(m['ltp'] ?? m['last_price'] ?? m['premium'] ?? m['price']);
      if (symbol.isEmpty || ltp == null) continue;
      final prev = asDouble(m['prev_close'] ?? m['previous_close']);
      final pct = asDouble(m['pct_change'] ?? m['change_percent']);
      out.add(
        LiveQuote(
          symbol: symbol,
          instrument: asString(m['instrument'], symbol),
          ltp: ltp,
          change: asDouble(m['change']) ??
              (prev != null ? ltp - prev : 0),
          changePct: pct ?? (prev != null && prev != 0 ? (ltp - prev) / prev * 100 : 0),
          at: DateTime.tryParse(asString(m['timestamp'])) ?? now,
          source: 'ws',
        ),
      );
    }
    return out;
  }

  void _scheduleReconnect(String reason) {
    _heartbeatTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    _channel = null;
    if (_stopped) return;

    _attempt++;
    final delayMs =
        (reconnectBackoff.inMilliseconds * _attempt).clamp(
      reconnectBackoff.inMilliseconds,
      maxBackoff.inMilliseconds,
    );
    _emit(
      StreamEvent(
        status: StreamStatus.connecting,
        message: '$reason — retry in ${delayMs ~/ 1000}s',
        transport: transportName,
      ),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), _connect);
  }

  void _emit(StreamEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    await _controller.close();
  }
}
