import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trade/models/position.dart';
import 'package:paper_trade/models/position_retention.dart';
import 'package:paper_trade/repositories/mock_positions_repository.dart';

void main() {
  const r = PositionRetention();

  /// The demo book has to survive its own cleanup rule on the day it is built,
  /// whatever today's date happens to be when the app starts.
  test('the seeded book is never born already expired', () async {
    for (final day in <int>[1, 15, 28, 29, 30, 31]) {
      for (final month in <int>[1, 2, 3, 6, 9, 10, 12]) {
        // Sweep 09:00 on that date and again at 23:59.
        for (final hour in <int>[9, 23]) {
          final now = DateTime(2026, month, day, hour);
          final repo = MockPositionsRepository(now: now, latency: Duration.zero);
          final positions = await repo.fetchPositions();
          expect(
            positions,
            isNotEmpty,
            reason: 'seed vanished on ${now.toIso8601String()}',
          );
          final kept = r.retain(positions, now);
          expect(
            kept.length,
            positions.length,
            reason: 'seed aged out immediately on ${now.toIso8601String()}: '
                'kept ${kept.map((p) => p.id).toList()} of '
                '${positions.map((p) => p.id).toList()}',
          );
        }
      }
    }
  });

  test('the seeded closed row is due the following morning', () async {
    final now = DateTime(2026, 9, 30, 14);
    final repo = MockPositionsRepository(now: now, latency: Duration.zero);
    final positions = await repo.fetchPositions();

    final closed = positions.where((Position p) => p.isClosed).toList();
    expect(closed, hasLength(1));
    expect(r.purgeAt(closed.single, now), DateTime(2026, 10, 1, 7));

    // And it is gone by the boundary the next morning.
    expect(r.retain(positions, DateTime(2026, 10, 1, 7)).map((p) => p.id),
        isNot(contains(closed.single.id)));
  });

  test('every seeded row carries a unique id', () async {
    final positions = await MockPositionsRepository(latency: Duration.zero).fetchPositions();
    final ids = positions.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
    expect(ids.every((id) => id.isNotEmpty), isTrue);
  });

  test('a square-off stamps the close time', () async {
    final repo = MockPositionsRepository(now: DateTime(2026, 9, 30, 14), latency: Duration.zero);
    expect((await repo.fetchPositions()).any((p) => p.isClosed), isTrue);

    await repo.squareOff('SENSEX 01st OCT 72900 PE');
    final after = await repo.fetchPositions();
    final squared = after.firstWhere((p) => p.symbol == 'SENSEX 01st OCT 72900 PE');

    expect(squared.isClosed, isTrue);
    expect(squared.closedAt, isNotNull);
    // The rule counts the morning *after* a close, never the morning of it.
    expect(r.purgeAt(squared, DateTime(2026, 9, 30, 14))!.isAfter(DateTime(2026, 9, 30, 14)),
        isTrue);
  });

  test('a square-off keeps the id, so retention can key off it', () async {
    final repo = MockPositionsRepository(latency: Duration.zero);
    final before = (await repo.fetchPositions())
        .firstWhere((p) => p.symbol == 'SENSEX 01st OCT 72900 CE');

    await repo.squareOff('SENSEX 01st OCT 72900 CE');
    final after = (await repo.fetchPositions())
        .firstWhere((p) => p.symbol == 'SENSEX 01st OCT 72900 CE');

    expect(after.retentionKey, before.retentionKey);
  });

  test('square-off does not eat the already-closed row of the same symbol', () async {
    final repo = MockPositionsRepository(latency: Duration.zero);
    final before = await repo.fetchPositions();
    // Two rows share `NIFTY OCT 22350 PE`; only the open one may be squared.
    final niftyOpen = before.firstWhere(
      (p) => p.symbol == 'NIFTY OCT 22350 PE' && !p.isClosed,
    );

    await repo.squareOff('NIFTY OCT 22350 PE');
    final after = await repo.fetchPositions();
    final nifty = after.where((p) => p.symbol == 'NIFTY OCT 22350 PE').toList();

    expect(nifty, hasLength(2));
    expect(nifty.where((p) => p.isClosed), hasLength(2));
    expect(nifty.map((p) => p.id), contains(niftyOpen.id));
  });
}

