import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:paper_trade/core/theme/app_theme.dart';
import 'package:paper_trade/core/utils/formatters.dart';
import 'package:paper_trade/models/market/live_quote.dart';
import 'package:paper_trade/models/position.dart';
import 'package:paper_trade/screens/positions/widgets/position_card.dart';

Position _row({
  int quantity = 1200,
  double average = 98.25,
  double last = 438.15,
  double pnl = 126390.25,
  DateTime? closedAt,
}) =>
    Position(
      id: 'pos-2',
      symbol: 'SENSEX 01st OCT 72900 PE',
      quantity: quantity,
      averagePrice: average,
      lastTradedPrice: last,
      pnl: pnl,
      product: 'MIS',
      segment: 'BFO',
      closedAt: closedAt,
    );

LiveQuote _live(double ltp) => LiveQuote(
      symbol: 'SENSEX 01st OCT 72900 PE',
      instrument: 'SENSEX',
      ltp: ltp,
      change: 0,
      changePct: 0,
      at: DateTime(2026, 10, 1, 15, 20),
      source: kContractLtpSource,
    );

Widget host(Position p, {LiveQuote? live}) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: PositionCard(position: p, live: live, onTap: () {}),
      ),
    );

void main() {
  testWidgets('an open row re-prices on the live mark', (tester) async {
    // (150 - 100) * 1200 = 60000
    final p = _row(quantity: 1200, average: 100, last: 0, pnl: 0);
    await tester.pumpWidget(host(p, live: _live(150)));
    expect(find.text(formatSigned(60000)), findsOneWidget);
  });

  testWidgets('a closed row keeps its booked P&L, not a recomputed zero',
      (tester) async {
    // The regression: a square-off zeroes quantity and average, so re-pricing
    // the row from the live mark collapses to 0 and throws away the realised
    // result.
    final p = _row(
      quantity: 0,
      average: 0,
      last: 438.15,
      pnl: 126390.25,
      closedAt: DateTime(2026, 9, 30, 15, 20),
    );
    await tester.pumpWidget(host(p, live: _live(438.15)));

    expect(find.text(formatSigned(126390.25)), findsOneWidget);
    expect(find.text(formatSigned(0)), findsNothing);
  });

  testWidgets('a closed row still shows the live LTP', (tester) async {
    // The requirement after the 15:20 square-off: P&L frozen, LTP still ticking.
    final p = _row(
      quantity: 0,
      average: 0,
      last: 438.15,
      pnl: 126390.25,
      closedAt: DateTime(2026, 9, 30, 15, 20),
    );
    await tester.pumpWidget(host(p, live: _live(512.75)));

    expect(find.text('LTP'), findsOneWidget);
    expect(find.text(formatPlain(512.75)), findsOneWidget);
    expect(find.text(formatSigned(126390.25)), findsOneWidget);
  });

  testWidgets('a closed row falls back to its stored price when the feed is silent',
      (tester) async {
    final p = _row(
      quantity: 0,
      average: 0,
      last: 438.15,
      pnl: 126390.25,
      closedAt: DateTime(2026, 9, 30, 15, 20),
    );
    await tester.pumpWidget(host(p));
    expect(find.text(formatPlain(438.15)), findsOneWidget);
    expect(find.text(formatSigned(126390.25)), findsOneWidget);
  });

  testWidgets('a live price of zero is ignored rather than booked', (tester) async {
    // The chain hands back 0 for a strike with no premium; that must not read
    // as a real price and wipe the row's P&L.
    final p = _row(quantity: 1200, average: 100, last: 120, pnl: 24000);
    await tester.pumpWidget(host(p, live: _live(0)));
    expect(find.text(formatPlain(120)), findsOneWidget);
    expect(find.text(formatSigned(24000)), findsOneWidget);
  });
}

