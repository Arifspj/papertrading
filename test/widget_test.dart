import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trade/main.dart';

void main() {
  testWidgets('App boots and shows the Positions screen', (tester) async {
    await tester.pumpWidget(const CyberPulseApp());
    await tester.pumpAndSettle();

    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Total P&L'), findsOneWidget);
    expect(find.text('NIFTY OCT 22350 PE'), findsNWidgets(2));
    expect(find.text('NRML'), findsWidgets);
    expect(find.text('Square Off'), findsNothing);
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