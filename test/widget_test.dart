import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:paper_trade/main.dart';

void main() {
  testWidgets('App boots and shows the Positions screen', (tester) async {
    await tester.pumpWidget(const CyberPulseApp());
    await tester.pumpAndSettle();

    expect(find.text('Portfolio'), findsNothing);
    expect(find.text('Total P&L'), findsOneWidget);
    expect(find.text('NIFTY OCT 22350 PE'), findsNWidgets(2));
    expect(find.text('NRML'), findsWidgets);
    expect(find.text('Square Off'), findsNothing);
  });

  testWidgets('Position search filters the list', (tester) async {
    await tester.pumpWidget(const CyberPulseApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.search).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SENSEX');
    await tester.pumpAndSettle();

    expect(find.text('2 of 4 positions'), findsOneWidget);
  });

  testWidgets('Position filter narrows the list', (tester) async {
    await tester.pumpWidget(const CyberPulseApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.slidersHorizontal).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Short'));
    await tester.pumpAndSettle();

    // Only the NIFTY short survives the "Short" filter (closed row is hidden).
    expect(find.text('1 of 4 positions'), findsOneWidget);
  });

  testWidgets('Theme toggle exists in settings', (tester) async {
    await tester.pumpWidget(const CyberPulseApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('TRADING THEME'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('White'), findsOneWidget);
  });
}