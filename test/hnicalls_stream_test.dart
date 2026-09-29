import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:paper_trade/core/api/hnicalls_client.dart';
import 'package:paper_trade/core/api/hnicalls_config.dart';
import 'package:paper_trade/models/market/live_quote.dart';
import 'package:paper_trade/services/live/hnicalls_polling_stream.dart';
import 'package:paper_trade/services/live/live_market_controller.dart';
import 'package:paper_trade/services/live/market_stream.dart';

/// A transport the tests drive by hand.
class FakeStream implements MarketStream {
  final _controller = StreamController<StreamEvent>.broadcast();
  bool started = false;
  bool stopped = false;
  int ticks = 0;

  @override
  String get transportName => 'fake';

  @override
  bool get isSupported => true;

  @override
  Stream<StreamEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    started = true;
    push(StreamStatus.connecting);
  }

  @override
  Future<void> stop() async {
    stopped = true;
    await _controller.close();
  }

  void push(StreamStatus status, {List<LiveQuote> quotes = const [], String? message}) {
    if (_controller.isClosed) return;
    _controller.add(
      StreamEvent(status: status, quotes: quotes, message: message, transport: 'fake'),
    );
  }
}

/// An unsupported (WS-not-configured) transport, to exercise the polling path.
class DisabledStream extends FakeStream {
  @override
  bool get isSupported => false;

  @override
  String get transportName => 'disabled';
}

void main() {
  group('HnicallsClient', () {
    test('fetchIndexQuotes maps smallList and moversList', () async {
      final client = HnicallsClient(
        client: MockClient((req) async {
          expect(req.url.toString(), endsWith('/ticker_app'));
          expect(req.headers['Accept'], 'application/json');
          return http.Response('''
          {"status":"success","updated":"2026-09-29T13:33:37.143Z",
           "smallList":[{"symbol":"NIFTY","ltp":22716.2,"pct_change":-0.28,
                         "prev_close":22780.25}],
           "moversList":[{"symbol":"MANKIND","ltp":2549.9,"pct_change":4.69,
                         "prev_close":2995}]}
          ''', 200);
        }),
      );
      final quotes = await client.fetchIndexQuotes();
      expect(quotes.length, 2);
      final nifty = quotes.firstWhere((q) => q.symbol == 'NIFTY');
      expect(nifty.ltp, 22716.2);
      expect(nifty.change, closeTo(-64.05, 0.01));
      expect(nifty.changePct, -0.28);
      expect(nifty.source, 'poll:ticker');
    });

    test('fetchAnalysis lowercases nothing and adds ?type=monthly', () async {
      late Uri seen;
      final client = HnicallsClient(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response(
            '{"status":"success","instrument":"NIFTY","spotPrice":22716.2}',
            200,
          );
        }),
      );
      await client.fetchAnalysis('NIFTY', expiry: HnExpiryType.monthly);
      expect(seen.path, contains('/analysis/NIFTY'));
      expect(seen.queryParameters['type'], 'monthly');
    });

    test('fetchOptionChain requires a lowercase instrument', () async {
      late Uri seen;
      final client = HnicallsClient(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response('{"status":"success","data":[]}', 200);
        }),
      );
      await client.fetchOptionChain('NIFTY');
      expect(seen.path, endsWith('/option-chain/nifty'));
    });

    test('option LTP uses the monthly segment when asked', () async {
      late Uri seen;
      final client = HnicallsClient(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response('{"ltp":340.74}', 200);
        }),
      );
      final ltp = await client.fetchOptionLtp(
        'NIFTY',
        22700,
        'CE',
        expiry: HnExpiryType.monthly,
      );
      // Lower-case: that is the form the live route answers on, and it matches
      // the sibling `/option-chain/{instrument}` route.
      expect(seen.path, endsWith('/ltp/nifty/monthly/22700/ce'));
      expect(ltp, 340.74);
    });

    test('fetchObservations pulls the observation strings', () async {
      final client = HnicallsClient(
        client: MockClient((req) async => http.Response(
              '[{"observation":"NIFTY 22700 ATM LTP Rs.340.74 [ATM]"}]',
              200,
            )),
      );
      final obs = await client.fetchObservations();
      expect(obs.single, contains('NIFTY 22700 ATM'));
    });

    test('throws HnicallsException with the status on a 500', () async {
      final client = HnicallsClient(
        client: MockClient((req) async => http.Response('upstream down', 500)),
      );
      await expectLater(
        client.fetchOptionChain('nifty'),
        throwsA(
          isA<HnicallsException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'upstream down'),
        ),
      );
    });
  });

  group('LiveMarketController', () {
    final quote = LiveQuote(
      symbol: 'NIFTY 22700 CE',
      instrument: 'NIFTY',
      ltp: 340.74,
      change: 12.5,
      changePct: 3.8,
      at: DateTime(2026, 9, 29),
      source: 'ws',
    );

    test('switches to polling when the socket delivers nothing', () async {
      final ws = FakeStream();
      final poll = FakeStream();
      final c = LiveMarketController(
        client: HnicallsClient(client: MockClient((_) async => http.Response('{}', 200))),
        ws: ws,
        poll: poll,
        wsGracePeriod: const Duration(milliseconds: 60),
        autoStart: false,
      );
      await c.start();
      expect(ws.started, isTrue);
      expect(c.status, StreamStatus.connecting);

      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(ws.stopped, isTrue);
      expect(poll.started, isTrue);
      expect(c.transportName, 'fake');
    });

    test('stays on the socket once it delivers a quote', () async {
      final ws = FakeStream();
      final poll = FakeStream();
      final c = LiveMarketController(
        client: HnicallsClient(client: MockClient((_) async => http.Response('{}', 200))),
        ws: ws,
        poll: poll,
        wsGracePeriod: const Duration(milliseconds: 60),
        autoStart: false,
      );
      await c.start();
      ws.push(StreamStatus.live, quotes: [quote]);
      await Future<void>.delayed(const Duration(milliseconds: 140));

      // The socket keeps ownership of the status...
      expect(ws.stopped, isFalse);
      expect(c.isLive, isTrue);
      expect(c.quoteFor('NIFTY 22700 CE')?.ltp, 340.74);

      // ...but the poller also runs, because the socket has no feed for option
      // premiums. It used to stay shut here, which left every option row on its
      // mock price while the indices looked perfectly live.
      expect(poll.started, isTrue);
    });


    test('does not fall back when the socket is unsupported', () async {
      final poll = FakeStream();
      final c = LiveMarketController(
        client: HnicallsClient(client: MockClient((_) async => http.Response('{}', 200))),
        ws: DisabledStream(),
        poll: poll,
        autoStart: false,
      );
      await c.start();
      expect(poll.started, isTrue);
      expect(c.transportName, 'fake');
    });

    test('refresh() only ticks an active polling transport', () async {
      final poll = FakeStream();
      final c = LiveMarketController(
        client: HnicallsClient(client: MockClient((_) async => http.Response('{}', 200))),
        ws: DisabledStream(),
        poll: poll,
        autoStart: false,
      );
      await c.start();
      await c.refresh();
      expect(poll.ticks, 0); // FakeStream, not a polling stream
    });
  });

  group('HnicallsPollingStream', () {
    test('emits live quotes from the working endpoints', () async {
      final client = HnicallsClient(
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/ticker_app')) {
            return http.Response(
              '{"status":"success","updated":"2026-09-29T13:33:37.143Z",'
              '"smallList":[{"symbol":"NIFTY","ltp":22716.2,"pct_change":-0.28,'
              '"prev_close":22780.25}],"moversList":[]}',
              200,
            );
          }
          if (path.contains('/analysis/')) {
            return http.Response(
              '{"status":"success","instrument":"NIFTY","spotPrice":22716.2,'
              '"strike":22700,"premium":340.74,"option_type":"NEUTRAL"}',
              200,
            );
          }
          return http.Response('{}', 500);
        }),
      );
      final stream = HnicallsPollingStream(
        client: client,
        instruments: const ['NIFTY'],
        interval: const Duration(hours: 1),
      );
      final events = <StreamEvent>[];
      final sub = stream.events.listen(events.add);
      await stream.start();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await sub.cancel();
      await stream.stop();

      final live = events.where((e) => e.quotes.isNotEmpty).toList();
      expect(live, isNotEmpty);
      final symbols = live.last.quotes.map((q) => q.symbol).toSet();
      expect(symbols, containsAll(<String>['NIFTY', 'NIFTY 22700']));
    });

    test('reports degraded when every feed fails', () async {
      final client = HnicallsClient(
        client: MockClient((_) async => http.Response('down', 500)),
      );
      final stream = HnicallsPollingStream(
        client: client,
        instruments: const ['NIFTY'],
        interval: const Duration(hours: 1),
      );
      final events = <StreamEvent>[];
      final sub = stream.events.listen(events.add);
      await stream.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      await stream.stop();

      expect(events.last.status, StreamStatus.degraded);
      expect(events.last.quotes, isEmpty);
    });

    /// Serves the ticker, a two-strike NIFTY chain, and single-contract LTPs.
    HnicallsClient contractClient({
      bool chainWorks = true,
    }) {
      return HnicallsClient(
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/ticker_app')) {
            return http.Response(
              '{"status":"success","updated":"2026-09-29T13:33:37.143Z",'
              '"smallList":[{"symbol":"NIFTY","ltp":22716.2,"pct_change":-0.28,'
              '"prev_close":22780.25}],"moversList":[]}',
              200,
            );
          }
          if (path.contains('/analysis/')) {
            return http.Response(
              '{"status":"success","instrument":"NIFTY","spotPrice":22716.2,'
              '"strike":22700,"premium":340.74,"option_type":"NEUTRAL"}',
              200,
            );
          }
          if (path.contains('/option-chain/')) {
            if (!chainWorks) return http.Response('upstream down', 500);
            return http.Response(
              '{"status":"success","instrument":"NIFTY","spot_price":22716.2,'
              '"expiry":"2026-09-29","data":['
              '{"STRIKE":22700,"CALL_LTP":16.25,"PUT_LTP":340.74,'
              '"CALL_OI":100,"PUT_OI":200,"CALL_VOL":11,"PUT_VOL":22},'
              '{"STRIKE":22350,"CALL_LTP":4.5,"PUT_LTP":900.0,'
              '"CALL_OI":50,"PUT_OI":60,"CALL_VOL":1,"PUT_VOL":2}]}',
              200,
            );
          }
          if (path.contains('/ltp/')) {
            return http.Response('{"status":"success","ltp":7.25}', 200);
          }
          return http.Response('{}', 500);
        }),
      );
    }

    test('resolves tracked strikes from the option chain', () async {
      final stream = HnicallsPollingStream(
        client: contractClient(),
        instruments: const [],
        interval: const Duration(hours: 1),
      );
      stream.trackSymbols(const ['NIFTY OCT 22350 PE', 'NIFTY 22700 CE']);
      final events = <StreamEvent>[];
      final sub = stream.events.listen(events.add);
      await stream.start();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await sub.cancel();
      await stream.stop();

      final live = events.where((e) => e.quotes.isNotEmpty).toList();
      final bySymbol = {
        for (final q in live.last.quotes) q.symbol: q,
      };
      // The chain answered both, so no per-contract call was needed.
      expect(bySymbol['NIFTY 22350 PE']?.ltp, 900.0);
      expect(bySymbol['NIFTY 22700 CE']?.ltp, 16.25);
      expect(bySymbol['NIFTY 22350 PE']?.source, kContractLtpSource);
    });

    test('falls back to the single-contract route when the chain is down',
        () async {
      final stream = HnicallsPollingStream(
        client: contractClient(chainWorks: false),
        instruments: const [],
        interval: const Duration(hours: 1),
      );
      stream.trackSymbols(const ['NIFTY OCT 22350 PE']);
      final events = <StreamEvent>[];
      final sub = stream.events.listen(events.add);
      await stream.start();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await sub.cancel();
      await stream.stop();

      final live = events.where((e) => e.quotes.isNotEmpty).toList();
      final contract =
          live.last.quotes.where((q) => q.source == kContractLtpSource).toList();
      expect(contract, hasLength(1));
      expect(contract.single.symbol, 'NIFTY 22350 PE');
      expect(contract.single.ltp, 7.25);
    });

    test('ignores symbols with no upstream feed', () async {
      final stream = HnicallsPollingStream(
        client: contractClient(),
        instruments: const [],
        interval: const Duration(hours: 1),
      );
      // Cash, futures and an unknown index cannot be priced from a chain.
      expect(stream.trackSymbols(const ['NIFTY', 'NIFTY NOV FUT', 'RELIANCE']),
          isFalse);
      expect(stream.trackSymbols(const ['NIFTY OCT 22350 PE']), isTrue);
      expect(stream.trackSymbols(const ['NIFTY OCT 22350 PE']), isFalse,
          reason: 're-tracking the same row must not cost another request');
      expect(stream.untrackSymbols(const ['NIFTY OCT 22350 PE']), isTrue);
      expect(stream.untrackSymbols(const ['NIFTY OCT 22350 PE']), isFalse);
    });
  });
}
