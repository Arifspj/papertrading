import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:paper_trade/core/api/hnicalls_client.dart';
import 'package:paper_trade/services/live/hnicalls_polling_stream.dart';
import 'package:paper_trade/services/live/market_stream.dart';

/// Every upstream call takes [delay], so a sequential poll costs
/// (calls x delay) and a parallel one costs roughly [delay]. The assertions
/// below pin the poll to the parallel figure.
HnicallsClient slowClient(Duration delay) {
  return HnicallsClient(
    client: MockClient((req) async {
      await Future<void>.delayed(delay);
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
        final inst = path.split('/').last.toUpperCase();
        return http.Response(
          '{"status":"success","instrument":"$inst","spotPrice":100,'
          '"strike":100,"premium":10,"option_type":"NEUTRAL"}',
          200,
        );
      }
      if (path.contains('/option-chain/')) {
        return http.Response('upstream down', 500);
      }
      if (path.contains('/ltp/')) {
        return http.Response('{"ltp": 42.5}', 200);
      }
      return http.Response('{}', 404);
    }),
  );
}

Future<StreamEvent> firstEvent(HnicallsPollingStream s) {
  final c = StreamController<StreamEvent>();
  late StreamSubscription<StreamEvent> sub;
  sub = s.events.listen((e) {
    if (e.quotes.isNotEmpty) {
      c.add(e);
      sub.cancel();
      s.stop();
    }
  });
  return c.stream.first;
}

void main() {
  test('four analyses are fetched in parallel, not one after another',
      () async {
    const delay = Duration(milliseconds: 300);
    const instruments = ['NIFTY', 'BANKNIFTY', 'SENSEX', 'FINNIFTY'];
    final stream = HnicallsPollingStream(
      client: slowClient(delay),
      instruments: instruments,
    );
    final sw = Stopwatch()..start();
    stream.start();
    await firstEvent(stream);
    sw.stop();

    // Sequential would be ticker + 4 analyses = 5 x 300ms = 1500ms.
    // Parallel is ticker + slowest analysis, so 2 x 300ms = 600ms.
    expect(sw.elapsedMilliseconds, lessThan(1200),
        reason: 'took ${sw.elapsedMilliseconds}ms');
  });

  test('per-contract fallbacks are fetched in parallel', () async {
    const delay = Duration(milliseconds: 300);

    Future<int> timeFor(List<String> tracked) async {
      final stream = HnicallsPollingStream(
        client: slowClient(delay),
        instruments: const [],
      )..trackSymbols(tracked);
      final sw = Stopwatch()..start();
      stream.start();
      await firstEvent(stream);
      sw.stop();
      return sw.elapsedMilliseconds;
    }

    final one = await timeFor(const ['NIFTY 22350 PE']);
    final four = await timeFor(const [
      'NIFTY 22350 PE',
      'NIFTY 22350 CE',
      'NIFTY 22500 PE',
      'SENSEX 72900 PE',
    ]);

    // Going from one tracked contract to four adds requests but no extra
    // round trips, because the /ltp calls share one parallel batch. If they
    // were issued sequentially this would be roughly 4x the one-contract time.
    expect(four, lessThan(one * 2), reason: 'one=${one}ms four=${four}ms');
  });
}

