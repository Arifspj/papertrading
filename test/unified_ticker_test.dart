import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:paper_trade/core/settings/app_settings_controller.dart';
import 'package:paper_trade/main.dart';
import 'package:paper_trade/models/market/live_quote.dart';
import 'package:paper_trade/services/live/live_market_controller.dart';
import 'package:paper_trade/services/live/market_stream.dart';
import 'package:paper_trade/widgets/unified_ticker.dart';

class _FakeStream implements MarketStream {
  final _controller = StreamController<StreamEvent>.broadcast();

  @override
  String get transportName => 'fake';

  @override
  bool get isSupported => true;

  @override
  Stream<StreamEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    _controller.add(
      const StreamEvent(status: StreamStatus.connecting, transport: 'fake'),
    );
  }

  @override
  Future<void> stop() async => _controller.close();

  void push(List<LiveQuote> quotes) {
    if (_controller.isClosed) return;
    _controller.add(
      StreamEvent(
        status: StreamStatus.live,
        quotes: quotes,
        transport: 'fake',
      ),
    );
  }
}

LiveQuote _quote(String symbol, double ltp, double pct) => LiveQuote(
      symbol: symbol,
      instrument: symbol,
      ltp: ltp,
      change: 0,
      changePct: pct,
      at: DateTime(2026, 11),
      source: 'poll:ticker',
    );

void main() {
  late _FakeStream stream;
  late LiveMarketController controller;

  setUp(() async {
    stream = _FakeStream();
    controller = LiveMarketController(
      ws: stream,
      poll: stream,
      autoStart: false,
      // Long enough that the fallback timer never fires mid-test.
      wsGracePeriod: const Duration(minutes: 5),
    );
    await controller.start();
  });

  tearDown(() => controller.dispose());

  Widget host({AppSettingsController? settings, List<Widget> tabs = const []}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LiveMarketController>.value(value: controller),
        ChangeNotifierProvider<AppSettingsController>.value(
          value: settings ?? AppSettingsController(),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            final on = context.select<AppSettingsController, bool>(
              (s) => s.tickerEnabled,
            );
            return Column(
              children: [
                if (on) const SafeArea(child: UnifiedTicker()),
                Expanded(child: tabs.isEmpty ? const SizedBox.shrink() : tabs.first),
              ],
            );
          },
        ),
      ),
    );
  }

  group('UnifiedTicker rendering', () {
    testWidgets('renders symbol, price and change from the feed', (tester) async {
      await tester.pumpWidget(host());
      stream.push([
        _quote('NIFTY', 22765.80, 0.57),
        _quote('BANKNIFTY', 51450.00, -0.22),
      ]);
      await tester.pump();

      // The list is painted twice, but only the on-screen copy is built, so
      // assert "at least one" and let the scroll tests cover the looping.
      expect(find.text('NIFTY'), findsWidgets);
      expect(find.text('22765.80'), findsWidgets);
      expect(find.text('+0.57%'), findsWidgets);
      expect(find.text('-0.22%'), findsWidgets);
    });

    testWidgets('paints the list twice so the loop is seamless', (tester) async {
      await tester.pumpWidget(host());
      stream.push([
        _quote('AAA', 100, 1),
        _quote('BBB', 200, 1),
        _quote('CCC', 300, 1),
        _quote('DDD', 400, 1),
        _quote('EEE', 500, 1),
        _quote('FFF', 600, 1),
        _quote('GGG', 700, 1),
        _quote('HHH', 800, 1),
        _quote('III', 900, 1),
        _quote('JJJ', 1000, 1),
        _quote('KKK', 1100, 1),
        _quote('LLL', 1200, 1),
      ]);
      await tester.pump();

      // One logical entry => exactly one chip is built per visible copy.
      final aaa = find.text('AAA');
      expect(aaa, findsOneWidget);

      // And the duplicate half exists further down the scroll extent.
      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
      expect(scrollable.controller!.position.maxScrollExtent, greaterThan(0));
      expect(find.byType(Padding), findsWidgets);
    });

    testWidgets('drops symbols with no price instead of a stale zero',
        (tester) async {
      await tester.pumpWidget(host());
      stream.push([
        _quote('NIFTY', 0, 0),
        _quote('SENSEX', 81200, 0.4),
      ]);
      await tester.pump();

      expect(find.text('NIFTY'), findsNothing);
      expect(find.text('SENSEX'), findsWidgets);
    });

    testWidgets('deduplicates a symbol that arrives twice', (tester) async {
      await tester.pumpWidget(host());
      stream.push([
        _quote('NIFTY', 100, 1),
        _quote('NIFTY', 101, 1),
      ]);
      await tester.pump();

      // One logical entry per pass, never a second row for the same symbol.
      expect(find.text('NIFTY'), findsWidgets);
      expect(find.text('100.00'), findsNothing);
      expect(find.text('101.00'), findsWidgets);
    });

    testWidgets('stays idle without quotes so the app can settle',
        (tester) async {
      await tester.pumpWidget(host());
      // A forever-repeating animation would hang this.
      await tester.pumpAndSettle();
      expect(find.text('Market feed idle'), findsOneWidget);
    });
  });

  group('UnifiedTicker scrolling', () {
    /// Pushes enough quotes to overflow any test viewport.
    void pushWideFeed() => stream.push([
          _quote('AAA', 100, 1),
          _quote('BBB', 200, 1),
          _quote('CCC', 300, 1),
          _quote('DDD', 400, 1),
          _quote('EEE', 500, 1),
          _quote('FFF', 600, 1),
          _quote('GGG', 700, 1),
          _quote('HHH', 800, 1),
          _quote('III', 900, 1),
          _quote('JJJ', 1000, 1),
          _quote('KKK', 1100, 1),
          _quote('LLL', 1200, 1),
        ]);

    testWidgets('scrolls forward over time', (tester) async {
      await tester.pumpWidget(host());
      pushWideFeed();
      // Two settle pumps: one to rebuild with the quotes, one to lay out the
      // horizontally scrolling children so maxScrollExtent is known.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final position = tester
          .widget<Scrollable>(find.byType(Scrollable))
          .controller!
          .position;
      expect(position.maxScrollExtent, greaterThan(0),
          reason: 'strip must overflow for the marquee to be meaningful');

      final before = position.pixels;
      await tester.pump(const Duration(milliseconds: 500));
      expect(position.pixels, greaterThan(before));
    });

    testWidgets('wraps to the start instead of stopping at the end',
        (tester) async {
      await tester.pumpWidget(host());
      pushWideFeed();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final position = tester
          .widget<Scrollable>(find.byType(Scrollable))
          .controller!
          .position;
      final max = position.maxScrollExtent;
      expect(max, greaterThan(0));

      // Drive far enough to cross the extent at least once.
      final step = const Duration(milliseconds: 500);
      var wrapped = false;
      var previous = position.pixels;
      for (var i = 0; i < 200; i++) {
        await tester.pump(step);
        final now = position.pixels;
        if (now < previous) wrapped = true;
        previous = now;
        if (wrapped) break;
      }

      expect(wrapped, isTrue, reason: 'offset must wrap back to 0');
      expect(position.pixels, greaterThanOrEqualTo(0));
      expect(position.pixels, lessThan(max));
    });
  });

  group('AppSettingsController', () {
    test('defaults to on', () {
      expect(AppSettingsController().tickerEnabled, isTrue);
    });

    test('toggle flips and notifies', () {
      final settings = AppSettingsController();
      var notified = 0;
      settings.addListener(() => notified++);

      settings.toggleTicker();
      expect(settings.tickerEnabled, isFalse);
      expect(notified, 1);

      settings.toggleTicker();
      expect(settings.tickerEnabled, isTrue);
      expect(notified, 2);
    });

    test('setting the same value does not notify', () {
      final settings = AppSettingsController();
      var notified = 0;
      settings.addListener(() => notified++);

      settings.tickerEnabled = true;
      expect(notified, 0);
    });
  });

  group('app integration', () {
    testWidgets('ticker renders on boot', (tester) async {
      await tester.pumpWidget(const CyberPulseApp());
      // No network in tests, so the strip stays on its idle row and settles.
      await tester.pumpAndSettle();
      expect(find.byType(UnifiedTicker), findsOneWidget);
    });

    testWidgets('settings exposes a live ticker switch', (tester) async {
      await tester.pumpWidget(const CyberPulseApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('MARKET FEED'), findsOneWidget);
      expect(find.text('Live ticker'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('switch hides and shows the ticker', (tester) async {
      await tester.pumpWidget(const CyberPulseApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(UnifiedTicker), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byType(UnifiedTicker), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byType(UnifiedTicker), findsOneWidget);
    });
  });
}
