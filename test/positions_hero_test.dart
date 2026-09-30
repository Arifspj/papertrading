import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:paper_trade/core/settings/app_settings_controller.dart';
import 'package:paper_trade/core/theme/app_theme.dart';
import 'package:paper_trade/core/theme/theme_controller.dart';
import 'package:paper_trade/core/utils/formatters.dart';
import 'package:paper_trade/models/market/live_quote.dart';
import 'package:paper_trade/models/position.dart';
import 'package:paper_trade/models/watchlist.dart';
import 'package:paper_trade/repositories/positions_repository.dart';
import 'package:paper_trade/repositories/watchlist_repository.dart';
import 'package:paper_trade/screens/positions/positions_screen.dart';
import 'package:paper_trade/services/live/live_market_controller.dart';
import 'package:paper_trade/services/live/market_stream.dart';
import 'package:paper_trade/services/positions/mis_auto_square_off_controller.dart';
import 'package:paper_trade/services/positions/position_retention_controller.dart';

class _FakeStream implements MarketStream {
  final _controller = StreamController<StreamEvent>.broadcast();

  @override
  String get transportName => 'fake';
  @override
  bool get isSupported => true;
  @override
  Stream<StreamEvent> get events => _controller.stream;
  @override
  Future<void> start() async => _controller.add(
        const StreamEvent(status: StreamStatus.connecting, transport: 'fake'),
      );
  @override
  Future<void> stop() async => _controller.close();

  void push(List<LiveQuote> quotes) {
    if (_controller.isClosed) return;
    _controller.add(StreamEvent(
      status: StreamStatus.live,
      quotes: quotes,
      transport: 'fake',
    ));
  }
}

Position _open(String symbol, double avg, int qty, double ltp, double pnl) =>
    Position(
      symbol: symbol,
      segment: 'NFO',
      product: 'NRML',
      quantity: qty,
      averagePrice: avg,
      lastTradedPrice: ltp,
      pnl: pnl,
    );

/// A closed row: [Position.isClosed] is quantity == 0 && averagePrice == 0.
Position _closed(String symbol, double pnl) => Position(
      symbol: symbol,
      segment: 'NFO',
      product: 'NRML',
      quantity: 0,
      averagePrice: 0,
      lastTradedPrice: 0,
      pnl: pnl,
    );

class _Repo implements PositionsRepository {
  _Repo(this._positions);
  final List<Position> _positions;

  @override
  Future<List<Position>> fetchPositions() async => _positions;

  @override
  Future<PortfolioSummary> fetchPortfolio() async =>
      PortfolioSummary.fromPositions(_positions);

  @override
  Future<void> squareOff(String symbol) async {}

  // The 15:20 rule is exercised in its own suite; the hero tests supply an
  // inert book.
  @override
  Future<List<Position>> squareOffOpenMis({
    required DateTime at,
    required double Function(String symbol) ltpOf,
  }) async =>
      _positions;
}

class _Watch implements WatchlistRepository {
  @override
  Future<List<WatchItem>> fetchWatchlist() async => const [];
  @override
  List<WatchItem> searchSymbols(String query) => const [];
  @override
  bool isAdded(String symbol) => false;
  @override
  Future<void> addItem(WatchItem item) async {}
}

LiveQuote _q(String symbol, double ltp) => LiveQuote(
      symbol: symbol,
      instrument: symbol,
      ltp: ltp,
      change: 0,
      changePct: 0,
      at: DateTime(2026, 11),
      source: kContractLtpSource,
    );

void main() {
  late _FakeStream stream;
  late LiveMarketController controller;

  setUp(() async {
    // The screen is dense and scrollable; the default 800x600 test surface
    // makes its vertical Column overflow.
    TestWidgetsFlutterBinding.ensureInitialized();
    stream = _FakeStream();
    controller = LiveMarketController(
      ws: stream,
      poll: stream,
      autoStart: false,
      wsGracePeriod: const Duration(minutes: 5),
    );
    await controller.start();
  });

  tearDown(() => controller.dispose());

  /// 10:00 on a trading day: before both the 15:20 square-off and the 07:00
  /// retention boundary, so the seeded book is left alone regardless of when the
  /// suite runs.
  DateTime pinnedClock() => DateTime(2026, 9, 30, 10);

  Widget host(PositionsRepository repo) => MultiProvider(

        providers: [
          ChangeNotifierProvider<LiveMarketController>.value(value: controller),
          ChangeNotifierProvider<AppSettingsController>.value(
            value: AppSettingsController(),
          ),
          ChangeNotifierProvider<ThemeController>.value(
            value: ThemeController(),
          ),
          Provider<PositionsRepository>.value(value: repo),
          Provider<WatchlistRepository>.value(value: _Watch()),
          ChangeNotifierProvider<PositionRetentionController>(
    create: (_) => PositionRetentionController(observeLifecycle: false, clock: pinnedClock),

          ),
          ChangeNotifierProvider<MisAutoSquareOffController>(
            create: (_) => MisAutoSquareOffController(
              repository: repo,
              ltpOf: (_) => 0,
              observeLifecycle: false,
              clock: pinnedClock,

            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PositionsScreen()),
        ),
      );

  /// The screen loads asynchronously and the stream delivers in a microtask,
  /// so give both several frames before asserting.
  Future<void> settle(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('hero total re-prices on live marks', (tester) async {
    await tester.pumpWidget(host(_Repo([
      _open('SENSEX 72900 PE', 340, -20, 300, 800),
      _open('SENSEX 72900 CE', 250, 20, 260, 200),
    ])));
    await settle(tester);

    // Booked total is 800 + 200 = 1000.
    expect(find.text(formatSigned(1000)), findsOneWidget);

    stream.push([
      _q('SENSEX 72900 PE', 390),
      _q('SENSEX 72900 CE', 284.3),
    ]);
    await settle(tester);

    // PE short: (390-340) * -20 = -1000. CE long: (284.3-250) * 20 = +686.
    expect(find.text(formatSigned(-314)), findsOneWidget);
  });

  testWidgets('rows without a live quote keep their booked pnl', (tester) async {
    await tester.pumpWidget(host(_Repo([
      _open('SENSEX 72900 PE', 340, -20, 300, 800),
      _open('RELIANCE', 100, 10, 110, 100),
    ])));
    await settle(tester);

    stream.push([_q('SENSEX 72900 PE', 360)]);
    await settle(tester);

    // PE short: (360-340) * -20 = -400, cash row has no feed so keeps 100.
    expect(find.text(formatSigned(-300)), findsOneWidget);
  });

  testWidgets('falls back to the booked total when nothing is live',
      (tester) async {
    await tester.pumpWidget(host(_Repo([
      _open('RELIANCE', 100, 10, 110, 100),
      _open('TCS', 50, 4, 55, 20),
    ])));
    await settle(tester);

    expect(find.text(formatSigned(120)), findsOneWidget);
  });

  testWidgets('closed positions contribute realised pnl and are not repriced',
      (tester) async {
    await tester.pumpWidget(host(_Repo([
      _closed('NIFTY 22000 PE', 100),
      _open('SENSEX 72900 CE', 250, 20, 260, 200),
    ])));
    await settle(tester);

    stream.push([_q('SENSEX 72900 CE', 300)]);
    await settle(tester);

    // Realised 100 + (300-250) * 20 = 1000. Total 1100.
    expect(find.text(formatSigned(1100)), findsOneWidget);
  });
}
