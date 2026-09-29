import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trade/core/market/lot_sizes.dart';

void main() {
  group('LotSizes.forSymbol', () {
    test('resolves index option symbols', () {
      expect(LotSizes.forSymbol('NIFTY 24 OCT 22700 CE'), 65);
      expect(LotSizes.forSymbol('BANKNIFTY 28 OCT 54000 CE'), 30);
      expect(LotSizes.forSymbol('FINNIFTY 28 OCT 26500 CE'), 60);
      expect(LotSizes.forSymbol('MIDCPNIFTY 28 OCT 13500 PE'), 120);
    });

    test('resolves SENSEX with its own lot size', () {
      expect(LotSizes.forSymbol('SENSEX 01st OCT 72900 PE'), 20);
    });

    test('resolves stock futures and options', () {
      expect(LotSizes.forSymbol('RELIANCE 28 OCT 3000 FUT'), 500);
      expect(LotSizes.forSymbol('RELIANCE 28 OCT 3000 CE'), 500);
    });

    test('resolves symbols with ampersands and hyphens', () {
      expect(LotSizes.forSymbol('M&M 28 OCT 3000 CE'), 200);
      expect(LotSizes.forSymbol('BAJAJ-AUTO 28 OCT 4200 CE'), 75);
      expect(LotSizes.forSymbol('NAM-INDIA 28 OCT 1200 CE'), 625);
      expect(LotSizes.forSymbol('GVT&D 28 OCT 250 CE'), 125);
      expect(LotSizes.forSymbol('LT 28 OCT 3800 FUT'), 175);
    });

    test('handles broker-style compact symbols', () {
      expect(LotSizes.forInstrument('NIFTY25NOV22700CE'), 65);
      expect(LotSizes.forInstrument('RELIANCE25NOVFUT'), 500);
      expect(LotSizes.forInstrument('SENSEX25NOV72900PE'), 20);
    });

    test('maps index aliases', () {
      expect(LotSizes.forInstrument('NIFTYBANK'), 30);
      expect(LotSizes.forInstrument('BANKEX'), 30);
      expect(LotSizes.forInstrument('NIFTYIT'), 60);
      expect(LotSizes.forInstrument('NIFTYNXT50'), 120);
      expect(LotSizes.forInstrument('NIFTY50'), 65);
      expect(LotSizes.forInstrument('L&T'), 175);
    });

    test('returns null for symbols outside the F&O table', () {
      expect(LotSizes.forSymbol('TATAMOTORS 28 OCT 900 CE'), isNull);
      expect(LotSizes.forSymbol(''), isNull);
      // BAJAJHLDNG is listed without a lot size in the circular.
      expect(LotSizes.forSymbol('BAJAJHLDNG 28 OCT 1200 CE'), isNull);
      expect(LotSizes.noLotSymbols, contains('BAJAJHLDNG'));
    });
  });

  group('LotSizes table integrity', () {
    test('covers the November 2026 circular', () {
      expect(LotSizes.asOf, DateTime(2026, 11));
      expect(LotSizes.asOfLabel, 'Nov 2026');
      expect(LotSizes.indexLots, {
        'NIFTY': 65,
        'BANKNIFTY': 30,
        'FINNIFTY': 60,
        'SENSEX': 20,
        'MIDCPNIFTY': 120,
      });
      expect(LotSizes.stockLots.length, greaterThan(180));
      expect(LotSizes.stockLots['SUZLON'], 12700);
      expect(LotSizes.stockLots['TCS'], 225);
      expect(LotSizes.stockLots['ZYDUSLIFE'], 900);
    });

    test('every lot size is a positive integer', () {
      for (final entry in LotSizes.all.entries) {
        expect(entry.value, greaterThan(0), reason: entry.key);
      }
    });

    test('noLotSymbols are absent from the lot table', () {
      for (final symbol in LotSizes.noLotSymbols) {
        expect(LotSizes.stockLots.containsKey(symbol), isFalse, reason: symbol);
      }
    });

    test('aliases point at real symbols', () {
      for (final entry in LotSizes.aliases.entries) {
        if (entry.key == entry.value) continue;
        expect(
          LotSizes.all.containsKey(entry.value),
          isTrue,
          reason: '${entry.key} -> ${entry.value}',
        );
      }
    });
  });

  group('LotSizes quantity validation', () {
    test('accepts whole multiples only', () {
      expect(LotSizes.isValidQty(20, 20), isTrue);
      expect(LotSizes.isValidQty(40, 20), isTrue);
      expect(LotSizes.isValidQty(60, 20), isTrue);
      expect(LotSizes.isValidQty(110, 20), isFalse);
      expect(LotSizes.isValidQty(10, 20), isFalse);
      expect(LotSizes.isValidQty(0, 20), isFalse);
      expect(LotSizes.isValidQty(-20, 20), isFalse);
      expect(LotSizes.isValidQty(65, 65), isTrue);
      expect(LotSizes.isValidQty(130, 65), isTrue);
    });

    test('rejects zero lot sizes', () {
      expect(LotSizes.isValidQty(10, 0), isFalse);
      expect(LotSizes.lotsFor(10, 0), isNull);
      expect(LotSizes.nearestValidQty(10, 0), 0);
    });

    test('counts lots', () {
      expect(LotSizes.lotsFor(65, 65), 1);
      expect(LotSizes.lotsFor(390, 65), 6);
      expect(LotSizes.lotsFor(110, 20), isNull);
    });

    test('nearest valid qty rounds down by default', () {
      expect(LotSizes.nearestValidQty(110, 20), 100);
      expect(LotSizes.nearestValidQty(110, 20, roundUp: true), 120);
      expect(LotSizes.nearestValidQty(19, 20), 0);
      expect(LotSizes.nearestValidQty(19, 20, roundUp: true), 20);
      expect(LotSizes.nearestValidQty(0, 20), 0);
    });

    test('validation message is null when valid', () {
      expect(LotSizes.validationMessage(100, 20), isNull);
      expect(LotSizes.validationMessage(0, 20), isNotNull);
    });

    test('validation message explains the lot size and nearest fix', () {
      final msg = LotSizes.validationMessage(110, 20);
      expect(msg, contains('20'));
      expect(msg, contains('100'));
    });

    test('validation message flags an unknown lot size', () {
      expect(LotSizes.validationMessage(10, 0), 'Lot size unavailable for this symbol');
    });
  });

  group('LotSizes.forSymbolOrDefault', () {
    test('falls back for cash instruments', () {
      expect(LotSizes.forSymbolOrDefault('TATAMOTORS 28 OCT 900 CE'), 1);
      expect(LotSizes.forSymbol('TATAMOTORS'), isNull);
    });

    test('keeps the real lot when known', () {
      expect(LotSizes.forSymbolOrDefault('NIFTY 28 OCT 22700 CE'), 65);
    });
  });
}
