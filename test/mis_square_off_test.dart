import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trade/models/mis_square_off.dart';
import 'package:paper_trade/models/position.dart';
import 'package:paper_trade/models/position_retention.dart';
import 'package:paper_trade/repositories/mock_positions_repository.dart';
import 'package:paper_trade/services/positions/mis_auto_square_off_controller.dart';

Position _p({
  String id = 'a',
  String symbol = 'SENSEX 72900 PE',
  String product = 'MIS',
  int quantity = 1200,
  double average = 100,
  double ltp = 150,
  double pnl = 0,
  DateTime? closedAt,
  DateTime? expiry,
}) =>
    Position(
      id: id,
      symbol: symbol,
      quantity: quantity,
      averagePrice: average,
      lastTradedPrice: ltp,
      pnl: pnl,
      product: product,
      closedAt: closedAt,
      expiry: expiry,
    );

void main() {
  const p = MisSquareOffPolicy();

  group('cut-off', () {
    test('is 15:20 local', () {
      expect(p.cutoffOn(DateTime(2026, 9, 30, 9)), DateTime(2026, 9, 30, 15, 20));
    });

    test('is not due in the morning', () {
      expect(p.isDue(DateTime(2026, 9, 30, 9, 15)), isFalse);
      expect(p.isDue(DateTime(2026, 9, 30, 15, 19, 59)), isFalse);
    });

    test('is due from 15:20 sharp', () {
      expect(p.isDue(DateTime(2026, 9, 30, 15, 20)), isTrue);
      expect(p.isDue(DateTime(2026, 9, 30, 15, 20, 1)), isTrue);
      expect(p.isDue(DateTime(2026, 9, 30, 23, 59)), isTrue);
    });
  });

  group('who is due', () {
    final after = DateTime(2026, 9, 30, 16);

    test('an open MIS row', () {
      expect(p.isDueForSquareOff(_p(product: 'MIS'), after), isTrue);
    });

    test('product matching ignores case', () {
      expect(p.isDueForSquareOff(_p(product: 'mis'), after), isTrue);
    });

    test('an NRML carry is left alone', () {
      expect(p.isDueForSquareOff(_p(product: 'NRML'), after), isFalse);
    });

    test('an already-closed row is not closed twice', () {
      final closed = _p(quantity: 0, average: 0, closedAt: DateTime(2026, 9, 30, 11));
      expect(p.isDueForSquareOff(closed, after), isFalse);
    });

    test('nothing is due before the cut-off', () {
      expect(p.isDueForSquareOff(_p(), DateTime(2026, 9, 30, 11, 30)), isFalse);
    });

    test('dueForSquareOff lists only the intraday rows', () {
      final due = p.dueForSquareOff(
        [_p(id: 'm1', product: 'MIS'), _p(id: 'n1', product: 'NRML')],
        after,
      );
      expect(due.map((e) => e.id), ['m1']);
    });
  });

  group('realised P&L', () {
    test('a long gains when the price rises', () {
      expect(MisSquareOffPolicy.realisedPnl(_p(quantity: 1200, average: 100, ltp: 150), 150),
          60000);
    });

    test('a long loses when the price falls', () {
      expect(MisSquareOffPolicy.realisedPnl(_p(quantity: 1200, average: 100, ltp: 80), 80),
          -24000);
    });

    test('a short profits when the price falls, without a special case', () {
      // (0.05 - 7) * -775
      expect(MisSquareOffPolicy.realisedPnl(_p(quantity: -775, average: 7, ltp: 0.05), 0.05),
          closeTo(5386.25, 0.01));
    });
  });

  group('squareOff', () {
    test('zeroes qty and avg and freezes realised pnl', () {
      final out = p.squareOff(
        _p(quantity: 1200, average: 100, ltp: 0, pnl: 999),
        150,
        DateTime(2026, 9, 30, 15, 20),
      );
      expect(out.isClosed, isTrue);
      expect(out.quantity, 0);
      expect(out.averagePrice, 0);
      expect(out.pnl, 60000);
      // The stale booked figure is replaced, not kept.
      expect(out.pnl, isNot(999));
    });

    test('stamps the cut-off, not the moment the sweep ran', () {
      final out = p.squareOff(_p(), 150, DateTime(2026, 9, 30, 15, 20));
      expect(out.closedAt, DateTime(2026, 9, 30, 15, 20));
    });

    test('keeps the closing price as the row fallback', () {
      final out = p.squareOff(_p(), 150, DateTime(2026, 9, 30, 15, 20));
      expect(out.lastTradedPrice, 150);
    });

    test('keeps the id so retention can key off it', () {
      final before = _p(id: 'pos-2');
      expect(p.squareOff(before, 150, DateTime(2026, 9, 30, 15, 20)).retentionKey,
          before.retentionKey);
    });
  });

  group('the 15:20 rule feeds the 07:00 rule', () {
    test('a row squared at 15:20 leaves the book the next morning', () {
      final retention = const PositionRetention();
      final at = DateTime(2026, 9, 30, 15, 20);
      final squared = p.squareOff(_p(), 150, at);

      // Still on the book for the rest of the evening.
      expect(retention.isPurgeable(squared, DateTime(2026, 9, 30, 23, 59)), isFalse);
      // Gone at 07:00 next morning, which is the retention cut-off.
      expect(retention.purgeAt(squared, at), DateTime(2026, 10, 1, 7));
      expect(retention.isPurgeable(squared, DateTime(2026, 10, 1, 7)), isTrue);
    });

    test('end to end: square at 15:20, retire at 07:00', () async {
      const retention = PositionRetention();
      final repo = MockPositionsRepository(
        now: DateTime(2026, 9, 30, 9),
        latency: Duration.zero,
      );
      // The seeded MIS row: `SENSEX 01st OCT 72900 PE`, product MIS.
      final before = await repo.fetchPositions();
      final mis = before.firstWhere((p) => p.product == 'MIS' && !p.isClosed);

      final book = await repo.squareOffOpenMis(
        at: DateTime(2026, 9, 30, 15, 20),
        ltpOf: (_) => 120,
      );
      final squared = book.firstWhere((p) => p.id == mis.id);

      expect(squared.isClosed, isTrue);
      expect(squared.quantity, 0);
      expect(squared.averagePrice, 0);
      expect(squared.closedAt, DateTime(2026, 9, 30, 15, 20));

      // 15:20 tonight: still listed.
      expect(
        retention.retain(book, DateTime(2026, 9, 30, 15, 21)).map((e) => e.id),
        contains(mis.id),
      );
      // 07:00 tomorrow: gone.
      expect(
        retention.retain(book, DateTime(2026, 10, 1, 7)).map((e) => e.id),
        isNot(contains(mis.id)),
      );
    });
  });

  group('repository squareOffOpenMis', () {
    test('leaves NRML rows open', () async {
      final repo = MockPositionsRepository(
        now: DateTime(2026, 9, 30, 9),
        latency: Duration.zero,
      );
      final book = await repo.squareOffOpenMis(
        at: DateTime(2026, 9, 30, 15, 20),
        ltpOf: (_) => 120,
      );
      final nrml = book.where((p) => p.product == 'NRML');
      expect(nrml.any((p) => !p.isClosed), isTrue,
          reason: 'carry positions must survive the intraday cut-off');
    });

    test('uses the live price, not the stale seed price', () async {
      final repo = MockPositionsRepository(
        now: DateTime(2026, 9, 30, 9),
        latency: Duration.zero,
      );
      final mis = (await repo.fetchPositions())
          .firstWhere((p) => p.product == 'MIS' && !p.isClosed);

      final book = await repo.squareOffOpenMis(
        at: DateTime(2026, 9, 30, 15, 20),
        ltpOf: (_) => 200,
      );
      final squared = book.firstWhere((p) => p.id == mis.id);
      expect(squared.pnl, (200 - mis.averagePrice) * mis.quantity);
      expect(squared.pnl, isNot(mis.pnl));
    });

    test('falls back to the stored price when the feed is silent', () async {
      final repo = MockPositionsRepository(
        now: DateTime(2026, 9, 30, 9),
        latency: Duration.zero,
      );
      final mis = (await repo.fetchPositions())
          .firstWhere((p) => p.product == 'MIS' && !p.isClosed);

      final book = await repo.squareOffOpenMis(
        at: DateTime(2026, 9, 30, 15, 20),
        ltpOf: (_) => 0,
      );
      final squared = book.firstWhere((p) => p.id == mis.id);
      // A zero must not book a zero P&L.
      expect(squared.pnl, (mis.lastTradedPrice - mis.averagePrice) * mis.quantity);
    });

    test('is idempotent', () async {
      final repo = MockPositionsRepository(
        now: DateTime(2026, 9, 30, 9),
        latency: Duration.zero,
      );
      final at = DateTime(2026, 9, 30, 15, 20);
      final first = await repo.squareOffOpenMis(at: at, ltpOf: (_) => 200);
      final second = await repo.squareOffOpenMis(at: at, ltpOf: (_) => 999);

      final a = first.map((p) => '${p.id}:${p.pnl}:${p.quantity}').toList();
      final b = second.map((p) => '${p.id}:${p.pnl}:${p.quantity}').toList();
      expect(b, a, reason: 'a second sweep must not re-close or re-price');
    });

    test('moves squared rows to the end, keeping open lots first', () async {
      final repo = MockPositionsRepository(
        now: DateTime(2026, 9, 30, 9),
        latency: Duration.zero,
      );
      final book = await repo.squareOffOpenMis(
        at: DateTime(2026, 9, 30, 15, 20),
        ltpOf: (_) => 120,
      );
      final closedAt = book.indexWhere((p) => p.isClosed);
      final openAfter = book.skip(closedAt).where((p) => !p.isClosed);
      expect(openAfter, isEmpty);
    });
  });

  group('controller', () {
    late DateTime now;

    MisAutoSquareOffController build(
      MockPositionsRepository repo, {
      double Function(String)? ltpOf,
    }) =>
        MisAutoSquareOffController(
          repository: repo,
          ltpOf: ltpOf ?? (_) => 200,
          clock: () => now,
          observeLifecycle: false,
        );

    setUp(() => now = DateTime(2026, 9, 30, 9));

    test('does nothing in the morning', () async {
      final repo = MockPositionsRepository(now: now, latency: Duration.zero);
      final before = await repo.fetchPositions();
      final c = build(repo);
      await c.ready;
      final after = await repo.fetchPositions();

      expect(after.where((p) => p.isClosed).length,
          before.where((p) => p.isClosed).length);
      expect(c.closedCount, 0,
          reason: 'this controller closed nothing before the cut-off');
      c.dispose();
    });

    test('catches up when the app opens after the cut-off', () async {
      now = DateTime(2026, 9, 30, 20);
      final repo = MockPositionsRepository(
        now: DateTime(2026, 9, 30, 9),
        latency: Duration.zero,
      );
      final c = build(repo);
      await c.ready;

      final book = await repo.fetchPositions();
      final mis = book.firstWhere((p) => p.product == 'MIS');
      expect(mis.isClosed, isTrue,
          reason: 'a session must not end holding an intraday position');
      expect(mis.closedAt, DateTime(2026, 9, 30, 15, 20),
          reason: 'stamped with the cut-off, not 20:00');
      c.dispose();
    });

    test('announces the change so the list re-reads', () async {
      now = DateTime(2026, 9, 30, 20);
      final repo = MockPositionsRepository(
        now: DateTime(2026, 9, 30, 9),
        latency: Duration.zero,
      );
      final c = build(repo);
      var announced = 0;
      c.addListener(() => announced++);
      await c.ready;
      expect(announced, 1);
      c.dispose();
    });

    test('stays quiet on a second sweep with nothing to do', () async {
      now = DateTime(2026, 9, 30, 20);
      final repo = MockPositionsRepository(
        now: DateTime(2026, 9, 30, 9),
        latency: Duration.zero,
      );
      final c = build(repo);
      await c.ready;

      var announced = 0;
      c.addListener(() => announced++);
      await c.sweep();
      expect(announced, 0);
      expect(c.sweepCount, 2);
      c.dispose();
    });

    test('re-arms the timer for tomorrow once the cut-off has passed', () async {
      now = DateTime(2026, 9, 30, 20);
      final repo = MockPositionsRepository(latency: Duration.zero);
      final c = build(repo);
      await c.ready;
      expect(c.timeToCutoff, Duration.zero);
      c.dispose();
    });

    test('counts down to the cut-off during the day', () async {
      now = DateTime(2026, 9, 30, 15, 10);
      final repo = MockPositionsRepository(latency: Duration.zero);
      final c = build(repo);
      await c.ready;
      expect(c.timeToCutoff, const Duration(minutes: 10));
      c.dispose();
    });

    test('fires at the cut-off while the app is open', () async {
      // A clock that actually advances, because the timer fires on real time
      // while the cut-off is judged against this one.
      final start = DateTime(2026, 9, 30, 15, 19, 59, 400);
      final watch = Stopwatch()..start();
      DateTime advancing() => start.add(watch.elapsed);

      final repo = MockPositionsRepository(
        now: DateTime(2026, 9, 30, 9),
        latency: Duration.zero,
      );
      final c = MisAutoSquareOffController(
        repository: repo,
        ltpOf: (_) => 200,
        clock: advancing,
        observeLifecycle: false,
      );
      await c.ready;
      // Before the cut-off nothing is closed.
      expect(
        (await repo.fetchPositions())
            .where((p) => p.product == 'MIS')
            .every((p) => !p.isClosed),
        isTrue,
      );

      await Future<void>.delayed(const Duration(milliseconds: 800));

      final mis = (await repo.fetchPositions()).firstWhere((p) => p.product == 'MIS');
      expect(mis.isClosed, isTrue, reason: 'the 15:20 timer should have fired');
      expect(mis.closedAt, DateTime(2026, 9, 30, 15, 20));
      c.dispose();
    });
  });

  group('pendingMisSquareOff', () {
    test('reports what a sweep would close without doing it', () {
      final due = pendingMisSquareOff(
        p,
        [_p(id: 'm', product: 'MIS'), _p(id: 'n', product: 'NRML')],
        DateTime(2026, 9, 30, 16),
      );
      expect(due.map((e) => e.id), ['m']);
    });
  });
}
