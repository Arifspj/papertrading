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

/// A polling transport that can price specific contracts on demand.
///
/// The socket cannot do this: HNICALLS pushes index frames over the websocket
/// but has no socket feed for option premiums, so the controller keeps one of
/// these running alongside the socket. Without the interface the controller
/// had to test for the concrete poll class, which made the option path
/// impossible to exercise in a test.
abstract interface class LiveOptionPoller implements MarketStream {
  /// Polls these canonical option symbols (e.g. `SENSEX 72900 PE`) from now
  /// on. Returns true when at least one new symbol was added.
  bool trackSymbols(Iterable<String> symbols);

  /// Stops polling [symbols]. Returns true when at least one was removed.
  bool untrackSymbols(Iterable<String> symbols);

  /// Pulls one cycle now instead of waiting for the interval.
  Future<void> tick();
}
