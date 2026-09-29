import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trade/models/position.dart';
import 'package:paper_trade/screens/positions/widgets/order_pad_sheet.dart';

Position _position({String symbol = 'NIFTY 28 OCT 22700 CE', int qty = 65}) {
  return Position(
    symbol: symbol,
    quantity: qty,
    averagePrice: 100,
    lastTradedPrice: 120,
    pnl: (120 - 100) * qty.toDouble(),    product: 'NRML',
    segment: 'NFO',
  );
}

void main() {
  Future<void> openPad(
    WidgetTester tester, {
    String symbol = 'NIFTY 28 OCT 22700 CE',
    int qty = 65,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOrderPadSheet(
                context,
                position: _position(symbol: symbol, qty: qty),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('seeds one lot for a NIFTY option and allows it', (tester) async {
    await openPad(tester);
    expect(find.text('Lot 65'), findsOneWidget);
    expect(find.text('Swipe to Sell'), findsOneWidget);
  });

  testWidgets('defaults to Sell for an open long position', (tester) async {
    await openPad(tester);
    expect(find.text('Swipe to Buy'), findsNothing);
  });

  testWidgets('rejects a quantity that is not a whole number of lots',
      (tester) async {
    await openPad(tester);

    final qtyField = find.byType(TextField).first;
    await tester.enterText(qtyField, '110');
    await tester.pumpAndSettle();

    // Sell/Buy is blocked with an explanation instead of confirming.
    expect(find.text('Swipe to Sell'), findsNothing);
    // Shown twice: under the qty field and in the sticky footer banner.
    expect(
      find.text('Lot size 65 — use a multiple of 65 (nearest 65)'),
      findsNWidgets(2),
    );
  });

  testWidgets('rejects a quantity below one lot', (tester) async {
    await openPad(tester);

    final qtyField = find.byType(TextField).first;
    await tester.enterText(qtyField, '20');
    await tester.pumpAndSettle();

    expect(find.text('Swipe to Sell'), findsNothing);
    expect(find.textContaining('nearest 65'), findsWidgets);
  });

  testWidgets('accepts a larger exact multiple of the lot', (tester) async {
    await openPad(tester);

    final qtyField = find.byType(TextField).first;
    await tester.enterText(qtyField, '130');
    await tester.pumpAndSettle();

    expect(find.text('Swipe to Sell'), findsOneWidget);
    expect(find.textContaining('nearest'), findsNothing);
  });

  testWidgets('quick multiplier chips fill a whole number of lots',
      (tester) async {
    await openPad(tester);

    await tester.tap(find.text('3x'));
    await tester.pumpAndSettle();

    expect(find.text('Swipe to Sell'), findsOneWidget);
    expect(find.text('3x'), findsOneWidget);
  });

  testWidgets('uses the SENSEX lot size for SENSEX contracts', (tester) async {
    await openPad(tester, symbol: 'SENSEX 01st OCT 72900 PE', qty: 20);
    expect(find.text('Lot 20'), findsOneWidget);
  });

  testWidgets('falls back to one share for a cash symbol', (tester) async {
    await openPad(tester, symbol: 'TATAMOTORS', qty: 1);
    expect(find.text('Lot 1'), findsOneWidget);
  });

  testWidgets('shows the lot size and its effective month in the More section',
      (tester) async {
    await openPad(tester);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Lot size'), findsOneWidget);
    expect(find.text('65 units'), findsOneWidget);
    expect(find.text('Nov 2026'), findsOneWidget);
  });
}
