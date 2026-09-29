import '../../models/market/live_quote.dart';

enum StreamStatus {
  idle,
  connecting,
  live,

  /// Connected but the upstream feed answered errors (e.g. HTTP 500).
  degraded,

  disconnected,
  failed,
}

/// One push from a market data transport.
class StreamEvent {
  final StreamStatus status;
  final List<LiveQuote> quotes;
  final String? message;
  final String transport;

  const StreamEvent({
    required this.status,
    this.quotes = const [],
    this.message,
    required this.transport,
  });

  StreamEvent copyWith({
    StreamStatus? status,
    List<LiveQuote>? quotes,
    String? message,
  }) =>
      StreamEvent(
        status: status ?? this.status,
        quotes: quotes ?? this.quotes,
        message: message ?? this.message,
        transport: transport,
      );
}

/// A source of live quotes. Implementations are transports (WebSocket or
/// polling) and are interchangeable behind [LiveMarketController].
abstract class MarketStream {
  /// Human name shown in the UI, e.g. `websocket` or `poll`.
  String get transportName;

  /// Whether this transport can currently deliver data.
  bool get isSupported;

  /// Emits status changes and quote batches. Single-subscription.
  Stream<StreamEvent> get events;

  /// Start streaming. [onTick] style orchestration is the caller's job.
  Future<void> start();

  Future<void> stop();
}
