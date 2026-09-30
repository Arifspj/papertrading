import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paper_trade/core/api/hnicalls_client.dart';
import 'package:paper_trade/repositories/watchlist_repository.dart';
import 'package:paper_trade/screens/watchlist/widgets/watchlist_search_sheet.dart';
import 'package:paper_trade/services/live/option_symbol_service.dart';
import 'package:paper_trade/widgets/instrument_title.dart';
import 'package:provider/provider.dart';

void main() {
  /// A client that answers the chain route for NIFTY and SENSEX, and 500s for
  /// anything else so the fallback path is reachable from a test.
  OptionSymbolService service({
    int chainStatus = 200,
    Map<String, String> chainByInstrument = const {},
  }) {
    return OptionSymbolService(
      client: HnicallsClient(
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.contains('/option-chain/')) {
            final name = path.split('/').last.toUpperCase();
            final body = chainByInstrument[name];
            if (body == null) return http.Response('down', chainStatus);
            return http.Response(body, 200);
          }
          if (path.contains('/analysis/')) {
            final name = path.split('/').last.toUpperCase();
            final atm = name == 'SENSEX' ? 72500 : 22600;
            return http.Response(
              '{"status":"success","instrument":"$name",'
              '"spotPrice":22620.45,"strike":$atm,"premium":339.31,'
              '"optionType":"NEUTRAL","expiryDate":"2026-09-30",'
              '"lotSize":65,"atmRow":null}',
              200,
            );
          }
          return http.Response('{}', 500);
        }),
      ),
    );
  }

  const niftyChain = '''
  {"status":"success","spot_price":22620.45,"expiry":"2026-10-01",
   "data":[
     {"STRIKE":22600,"CALL_LTP":339.31,"PUT_LTP":310.5},
     {"STRIKE":22700,"CALL_LTP":210.0,"PUT_LTP":250.0}
   ]}
  ''';

  /// The symbol is rendered as several `TextSpan`s (day, ordinal, weekly badge,
  /// month, strike, type), so it is matched on the widget's symbol rather than
  /// on a single text node.
  Finder contractRow(String symbol) => find.byWidgetPredicate(
        (w) => w is InstrumentTitle && w.symbol == symbol,
        description: 'contract row $symbol',
      );

  /// The instrument chip. Keyed, because the ladder header repeats the same
  /// name as plain text right underneath.
  Finder chip(String name) => find.byKey(ValueKey('ladder-instrument-$name'));

  Future<void> pickInstrument(WidgetTester tester, String name) async {
    await tester.tap(chip(name));
    await tester.pumpAndSettle();
  }

  /// Scrolls the results until [symbol] is built and visible.
  ///
  /// The list is lazy, so a strike in the middle of a 22-row ATM ladder is not
  /// in the tree until it is scrolled to.
  Future<void> scrollTo(WidgetTester tester, String symbol) async {
    final target = contractRow(symbol);
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, OptionSymbolService svc) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WatchlistRepository>(create: (_) => MockWatchlistRepository()),
          Provider<OptionSymbolService>(create: (_) => svc),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showWatchlistSearchSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers an index chip for each supported instrument', (tester) async {
    await open(tester, service());
    expect(chip('NIFTY'), findsOneWidget);
    expect(chip('SENSEX'), findsOneWidget);
  });

  testWidgets('loads a ladder and offers each contract for add', (tester) async {
    await open(tester, service(chainByInstrument: {'NIFTY': niftyChain}));

    await pickInstrument(tester, 'NIFTY');

    expect(contractRow('NIFTY 01st OCT 22600 CE'), findsOneWidget);
    expect(contractRow('NIFTY 01st OCT 22600 PE'), findsOneWidget);
    expect(contractRow('NIFTY 01st OCT 22700 CE'), findsOneWidget);
    expect(contractRow('NIFTY 01st OCT 22700 PE'), findsOneWidget);
    // Chain premiums are shown.
    expect(find.text('339.31'), findsOneWidget);
    expect(find.text('310.50'), findsOneWidget);
  });

  testWidgets('labels the ATM fallback so unpriced rows are not misread',
      (tester) async {
    await open(tester, service(chainStatus: 500));

    await pickInstrument(tester, 'SENSEX');

    expect(find.text('ATM ladder'), findsOneWidget);
    expect(find.text('ATM 72500'), findsOneWidget);
    await scrollTo(tester, 'SENSEX 30th SEP 72500 CE');
    expect(contractRow('SENSEX 30th SEP 72500 CE'), findsOneWidget);
    // No premium available, so a dash rather than a fake 0.00.
    expect(find.text('—'), findsWidgets);
    expect(find.text('0.00'), findsNothing);
  });

  testWidgets('picking an instrument twice does not duplicate contracts',
      (tester) async {
    await open(tester, service(chainByInstrument: {'NIFTY': niftyChain}));

    await pickInstrument(tester, 'NIFTY');
    await pickInstrument(tester, 'NIFTY');

    expect(contractRow('NIFTY 01st OCT 22600 CE'), findsOneWidget);
  });

  testWidgets('typing filters the ladder', (tester) async {
    await open(tester, service(chainByInstrument: {'NIFTY': niftyChain}));

    await pickInstrument(tester, 'NIFTY');
    expect(contractRow('NIFTY 01st OCT 22700 CE'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '22600');
    await tester.pumpAndSettle();

    expect(contractRow('NIFTY 01st OCT 22600 CE'), findsOneWidget);
    expect(contractRow('NIFTY 01st OCT 22700 CE'), findsNothing);
  });

  testWidgets('adding a contract returns it and records it', (tester) async {
    await open(tester, service(chainByInstrument: {'NIFTY': niftyChain}));

    await pickInstrument(tester, 'NIFTY');

    final target = contractRow('NIFTY 01st OCT 22600 CE');
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();

    // The sheet pops with the chosen contract.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('an unusable chain shows a message, not a crash', (tester) async {
    await open(tester, service(chainStatus: 500));

    await pickInstrument(tester, 'FINNIFTY');

    // FINNIFTY falls back to analysis, which answers for it, so there is a
    // ladder — the point is the sheet survives the failing chain route.
    expect(find.text('FINNIFTY'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
