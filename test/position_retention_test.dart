import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trade/models/position.dart';
import 'package:paper_trade/models/position_retention.dart';

/// 30 Sep 2026, 14:00 IST.
final _now = DateTime(2026, 9, 30, 14);

Position _open({
  String id = 'a',
  String symbol = 'NIFTY 22350 PE',
  DateTime? expiry,
}) =>
    Position(
      id: id,
      symbol: symbol,
      quantity: -775,
      averagePrice: 7,
      lastTradedPrice: 0.05,
      pnl: 100,
      expiry: expiry,
    );

Position _closed({
  String id = 'a',
  String symbol = 'NIFTY 22350 PE',
  DateTime? closedAt,
  DateTime? expiry,
}) =>
    Position(
      id: id,
      symbol: symbol,
      quantity: 0,
      averagePrice: 0,
      lastTradedPrice: 0,
      pnl: 100,
      closedAt: closedAt,
      expiry: expiry,
    );

void main() {
  const r = PositionRetention();

  group('nextMorning', () {
    test('is 07:00 the following calendar day', () {
      expect(r.nextMorning(DateTime(2026, 9, 30, 14)), DateTime(2026, 10, 1, 7));
    });

    test('rolls over a month boundary', () {
      expect(r.nextMorning(DateTime(2026, 9, 30, 23, 59)),
          DateTime(2026, 10, 1, 7));
    });

    test('rolls over a year boundary', () {
      expect(r.nextMorning(DateTime(2026, 12, 31, 6)),
          DateTime(2027, 1, 1, 7));
    });
  });

  group('closed positions', () {
    test('survive the rest of the day they were closed', () {
      final p = _closed(closedAt: DateTime(2026, 9, 30, 14, 30));
      expect(r.purgeAt(p, _now), DateTime(2026, 10, 1, 7));
      expect(r.isPurgeable(p, DateTime(2026, 9, 30, 23, 59)), isFalse);
    });

    test('go at 07:00 the next morning', () {
      final p = _closed(closedAt: DateTime(2026, 9, 30, 14, 30));
      expect(r.isPurgeable(p, DateTime(2026, 10, 1, 6, 59, 59)), isFalse);
      expect(r.isPurgeable(p, DateTime(2026, 10, 1, 7)), isTrue);
    });

    test('a close with no timestamp waits a morning, not a moment', () {
      final p = _closed();
      expect(r.purgeAt(p, _now), DateTime(2026, 10, 1, 7));
      expect(r.isPurgeable(p, _now), isFalse);
    });

    test('an open position has no close trigger', () {
      expect(r.purgeAt(_open(), _now), isNull);
    });
  });

  group('expiry', () {
    test('a contract expiring today goes at 07:00 tomorrow', () {
      final p = _open(expiry: DateTime(2026, 9, 30));
      expect(r.purgeAt(p, _now), DateTime(2026, 10, 1, 7));
      expect(r.isPurgeable(p, DateTime(2026, 9, 30, 20)), isFalse);
      expect(r.isPurgeable(p, DateTime(2026, 10, 1, 7)), isTrue);
    });

    test('an open contract whose expiry has passed also goes', () {
      final p = _open(expiry: DateTime(2026, 9, 24));
      expect(r.purgeAt(p, _now), DateTime(2026, 9, 25, 7));
      expect(r.isPurgeable(p, _now), isTrue);
    });

    test('an expiry time-of-day does not shift the boundary', () {
      final p = _open(expiry: DateTime(2026, 9, 30, 15, 30));
      expect(r.purgeAt(p, _now), DateTime(2026, 10, 1, 7));
    });

    test('a non-expiring instrument never ages out on expiry', () {
      expect(r.purgeAt(_open(), _now), isNull);
      expect(r.isPurgeable(_open(), DateTime(2030, 1, 1, 7)), isFalse);
    });
  });

  group('earliest trigger wins', () {
    test('closed today beats an expiry next week', () {
      final p = _closed(
        closedAt: DateTime(2026, 9, 30, 9),
        expiry: DateTime(2026, 10, 7),
      );
      expect(r.purgeAt(p, _now), DateTime(2026, 10, 1, 7));
    });

    test('an expiry already past beats a fresh close timestamp', () {
      final p = _closed(
        closedAt: DateTime(2026, 9, 30, 9),
        expiry: DateTime(2026, 9, 10),
      );
      expect(r.purgeAt(p, _now), DateTime(2026, 9, 11, 7));
    });
  });

  group('retain', () {
    test('keeps everything that has not aged out', () {
      final kept = r.retain([
        _open(id: 'live', expiry: DateTime(2026, 10, 7)),
        _closed(id: 'today', closedAt: DateTime(2026, 9, 30, 9)),
      ], _now);
      expect(kept.map((p) => p.id), ['live', 'today']);
    });

    test('drops the aged-out rows and keeps the rest', () {
      final kept = r.retain([
        _open(id: 'live', expiry: DateTime(2026, 10, 7)),
        _closed(id: 'old', closedAt: DateTime(2026, 9, 20, 9)),
        _open(id: 'expired', expiry: DateTime(2026, 9, 10)),
      ], _now);
      expect(kept.map((p) => p.id), ['live']);
    });

    test('two rows sharing a symbol are judged independently', () {
      // The book really does hold `NIFTY OCT 22350 PE` twice: an open lot and a
      // squared-off one. Expiry-based cleanup must not take the open row with
      // it, and the closed row must not take the open one.
      final kept = r.retain([
        _open(id: 'open-lot', expiry: DateTime(2026, 10, 7)),
        _closed(id: 'closed-lot', closedAt: DateTime(2026, 9, 20, 9)),
      ], _now);
      expect(kept.map((p) => p.id), ['open-lot']);
    });
  });

  group('retentionKey', () {
    test('keys off the id when there is one', () {
      expect(_open(id: 'pos-1').retentionKey, 'id:pos-1');
    });

    test('falls back to the symbol, prefixed so it cannot collide', () {
      final p = Position(
        symbol: 'NIFTY 22350 PE',
        quantity: 1,
        averagePrice: 1,
        lastTradedPrice: 1,
        pnl: 0,
      );
      expect(p.retentionKey, 'sym:NIFTY 22350 PE');
    });
  });

  group('fromJson', () {
    test('reads a date-only expiry', () {
      final p = Position.fromJson({
        'id': 'x',
        'symbol': 'NIFTY 22350 PE',
        'expiry': '2026-10-01',
      });
      expect(p.expiry, DateTime(2026, 10, 1));
    });

    test('reads the alternative expiry keys brokers use', () {
      expect(
        Position.fromJson({'symbol': 'a', 'expiryDate': '2026-10-01'}).expiry,
        DateTime(2026, 10, 1),
      );
      expect(
        Position.fromJson({'symbol': 'a', 'expiry_date': '2026-10-01'}).expiry,
        DateTime(2026, 10, 1),
      );
    });

    test('reads an exit timestamp', () {
      expect(
        Position.fromJson({'symbol': 'a', 'exitTime': '2026-09-30T14:05:00Z'})
            .closedAt,
        DateTime.parse('2026-09-30T14:05:00Z'),
      );
    });

    test('reads epoch millis and seconds', () {
      final ms = DateTime(2026, 9, 30, 14).millisecondsSinceEpoch;
      expect(Position.fromJson({'symbol': 'a', 'expiry': ms}).expiry,
          DateTime(2026, 9, 30, 14));
      expect(
        Position.fromJson({'symbol': 'a', 'expiry': ms ~/ 1000}).expiry,
        DateTime(2026, 9, 30, 14),
      );
    });

    test('treats a missing or junk date as non-expiring', () {
      expect(Position.fromJson({'symbol': 'a'}).expiry, isNull);
      expect(Position.fromJson({'symbol': 'a', 'expiry': ''}).expiry, isNull);
      expect(
          Position.fromJson({'symbol': 'a', 'expiry': 'not-a-date'}).expiry, isNull);
      expect(Position.fromJson({'symbol': 'a', 'expiry': 'null'}).expiry, isNull);
    });

    test('an unparsable expiry must not fake a long-lived position', () {
      // Guards the failure mode this rule depends on: a mis-parse would make a
      // dead contract look like it never expires.
      final p = Position.fromJson({'symbol': 'a', 'expiry': '31-02-2026'});
      expect(p.expiry, isNull);
    });
  });
}
