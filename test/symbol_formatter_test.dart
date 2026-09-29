import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trade/core/utils/symbol_formatter.dart';

void main() {
  group('SymbolParts.parse', () {
    test('weekly option: day present -> weekly kind', () {
      final p = SymbolParts.parse('SENSEX 01st OCT 72900 PE');
      expect(p.underlying, 'SENSEX');
      expect(p.day, '01st');
      expect(p.month, 'OCT');
      expect(p.strike, '72900');
      expect(p.instrumentType, 'PE');
      expect(p.kind, ExpiryKind.weekly);
      expect(p.isWeekly, isTrue);
      expect(p.instrumentLabel, 'Options (PE)');
    });

    test('monthly option: no day -> monthly kind, no badge', () {
      final p = SymbolParts.parse('NIFTY OCT 22350 PE');
      expect(p.underlying, 'NIFTY');
      expect(p.day, isNull);
      expect(p.month, 'OCT');
      expect(p.strike, '22350');
      expect(p.kind, ExpiryKind.monthly);
      expect(p.isWeekly, isFalse);
    });

    test('day+month token (24OCT) splits into day and month', () {
      final p = SymbolParts.parse('NIFTY 24OCT 22500 CE');
      expect(p.day, '24');
      expect(p.month, 'OCT');
      expect(p.isWeekly, isTrue);
    });

    test('legacy standalone W token is dropped', () {
      final p = SymbolParts.parse('SENSEX 01st W OCT 72900 PE');
      expect(p.underlying, 'SENSEX');
      expect(p.month, 'OCT');
      expect(p.isWeekly, isTrue);
    });

    test('futures never carry the weekly tag', () {
      final p = SymbolParts.parse('NIFTY NOV FUT');
      expect(p.instrumentType, 'FUT');
      expect(p.isFuture, isTrue);
      expect(p.kind, ExpiryKind.monthly);
      expect(p.instrumentLabel, 'Futures');
    });

    test('cash symbol has no expiry', () {
      final p = SymbolParts.parse('NIFTY');
      expect(p.underlying, 'NIFTY');
      expect(p.kind, ExpiryKind.none);
      expect(p.instrumentLabel, 'Equity');
    });
  });
}