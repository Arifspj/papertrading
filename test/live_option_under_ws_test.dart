import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:paper_trade/models/market/live_quote.dart';
import 'package:paper_trade/services/live/live_market_controller.dart';
import 'package:paper_trade/services/live/market_stream.dart';

DateTime get _now => DateTime(2026, 10, 1, 10, 15);

/// A socket that connects, reports live and streams index frames. It knows
/// nothing about option premiums, exactly like the real HNICALLS feed.
class _FakeWs implements MarketStream {
  final controller = StreamController<StreamEvent>.broadcast();
  bool started = false;
  bool stopped = false;

  @override
  String get transportName => 'ws';

  @override
  bool get isSupported => true;

  @override
  Stream<StreamEvent> get events => controller.stream;

  @override
  Future<void> start() async {
    started = true;
    controller.add(StreamEvent(
      status: StreamStatus.live,
      quotes: [
        LiveQuote(
          symbol: 'NIFTY',
          instrument: 'NIFTY',
          ltp: 22716.2,
          change: 0,
          changePct: 0,
          at: _now,
          source: 'ws',
        ),
      ],
      transport: 'ws',
    ));
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

/// Stands in for the HTTP poller, so the test never touches the network.
class _FakePoll implements LiveOptionPoller {
  final controller = StreamController<StreamEvent>.broadcast();
  final List<String> tracked = [];
  int ticks = 0;

  @override
  String get transportName => 'poll';

  @override
  bool get isSupported => true;

  @override
  Stream<StreamEvent> get events => controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> tick() async {
    ticks++;
    final quotes = <LiveQuote>[
      for (final s in tracked)
        LiveQuote(
          symbol: s,
          instrument: s.split(' ').first,
          ltp: 390.0,
          change: 0,
          changePct: 0,
          at: _now,
          source: kContractLtpSource,
        ),
    ];
    controller.add(StreamEvent(
      status: StreamStatus.live,
      quotes: quotes,
      transport: 'poll',
    ));
  }

  @override
  bool trackSymbols(Iterable<String> symbols) {
    var changed = false;
    for (final s in symbols) {
      if (!tracked.contains(s)) {
        tracked.add(s);
        changed = true;
      }
    }
    return changed;
  }

  @override
  bool untrackSymbols(Iterable<String> symbols) {
    final before = tracked.length;
    tracked.removeWhere(symbols.contains);
    return tracked.length != before;
  }
}

void main() {
  test('option LTP arrives even when the socket is live', () async {
    final ws = _FakeWs();
    final poll = _FakePoll();
    final live = LiveMarketController(ws: ws, poll: poll, autoStart: false);
    addTearDown(() {
      live.dispose();
      ws.controller.close();
      poll.controller.close();
    });

    await live.start();
    await Future<void>.delayed(Duration.zero);

    // The socket is live and indices are showing.
    expect(live.quoteFor('NIFTY'), isNotNull);
    expect(live.status, StreamStatus.live);

    // A position row asks for its premium.
    live.trackSymbols(const ['SENSEX 72900 PE']);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // This is the regression: with a live socket the poller used to stay
    // switched off, so the option row kept its mock price forever.
    expect(poll.ticks, greaterThan(0),
        reason: 'tracking must pull a poll cycle even while ws is live');
    expect(live.quoteFor('SENSEX 72900 PE'), isNotNull,
        reason: 'tracked option contract never got a live price');
  });

  test('a poll gap does not downgrade a live socket', () async {
    final ws = _FakeWs();
    final poll = _FakePoll();
    final live = LiveMarketController(ws: ws, poll: poll, autoStart: false);
    addTearDown(() {
      live.dispose();
      ws.controller.close();
      poll.controller.close();
    });

    await live.start();
    await Future<void>.delayed(Duration.zero);
    expect(live.status, StreamStatus.live);

    poll.controller.add(const StreamEvent(
      status: StreamStatus.degraded,
      quotes: [],
      transport: 'poll',
    ));
    await Future<void>.delayed(Duration.zero);

    expect(live.status, StreamStatus.live,
        reason: 'the socket is the primary transport and is still live');
  });
}
