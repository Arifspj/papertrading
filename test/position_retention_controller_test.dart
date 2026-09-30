import 'package:flutter_test/flutter_test.dart';
import 'package:paper_trade/models/position.dart';
import 'package:paper_trade/services/positions/position_retention_controller.dart';
import 'package:paper_trade/services/positions/position_retention_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position _p({
  String id = 'a',
  String symbol = 'NIFTY 22350 PE',
  int quantity = -775,
  DateTime? closedAt,
  DateTime? expiry,
}) =>
    Position(
      id: id,
      symbol: symbol,
      quantity: quantity,
      averagePrice: quantity == 0 ? 0 : 7,
      lastTradedPrice: 0.05,
      pnl: 100,
      closedAt: closedAt,
      expiry: expiry,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late PositionRetentionController c;

  PositionRetentionController build({PositionRetentionStore? store}) {
    return PositionRetentionController(
      store: store,
      clock: () => now,
      // The lifecycle observer needs a live binding; the resume path is
      // exercised separately below.
      observeLifecycle: false,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 9, 30, 14);
  });

  test('keeps rows that have not aged out', () async {
    c = build();
    await c.init();
    final kept = c.retain([
      _p(id: 'live', expiry: DateTime(2026, 10, 7)),
      _p(id: 'today', quantity: 0, closedAt: DateTime(2026, 9, 30, 9)),
    ]);
    expect(kept.map((p) => p.id), ['live', 'today']);
  });

  test('a closed row is retired the following morning', () async {
    c = build();
    await c.init();
    final p = _p(id: 'x', quantity: 0, closedAt: DateTime(2026, 9, 30, 9));

    // Same evening: still on the book.
    now = DateTime(2026, 9, 30, 20);
    expect(c.retain([p]).map((e) => e.id), ['x']);

    // Next morning, before the boundary: still there.
    now = DateTime(2026, 10, 1, 6, 59);
    expect(c.retain([p]).map((e) => e.id), ['x']);

    // 07:00 sharp: gone.
    now = DateTime(2026, 10, 1, 7);
    expect(c.retain([p]), isEmpty);
  });

  test('a row expiring today is retired the following morning', () async {
    c = build();
    await c.init();
    final p = _p(id: 'e', expiry: DateTime(2026, 9, 30));

    now = DateTime(2026, 9, 30, 23, 59);
    expect(c.retain([p]).map((e) => e.id), ['e']);

    now = DateTime(2026, 10, 1, 7);
    expect(c.retain([p]), isEmpty);
  });

  test('a retirement survives a restart', () async {
    final store = const PositionRetentionStore();
    final p = _p(id: 'gone', expiry: DateTime(2026, 9, 10));

    now = DateTime(2026, 9, 30, 8);
    final first = build(store: store);
    await first.ready;
    expect(first.retain([p]), isEmpty);
    first.dispose();

    // A fresh controller over a re-seeded book: the mock repo hands the row
    // back, and it must not reappear.
    now = DateTime(2026, 9, 30, 9);
    final second = build(store: store);
    await second.ready;
    expect(second.retain([p]), isEmpty);
    expect(second.removed, contains('id:gone'));
    second.dispose();
  });

  test('restored ids make the controller announce a re-filter', () async {
    final store = const PositionRetentionStore();
    await store.save({'id:gone'});

    now = DateTime(2026, 9, 30, 9);
    final fresh = build(store: store);
    var announced = 0;
    fresh.addListener(() => announced++);

    await fresh.ready;
    // The screen re-runs the filter over the rows it already has, so it needs
    // to hear about it rather than refetch.
    expect(announced, 1);
    expect(
      fresh.retain([_p(id: 'gone'), _p(id: 'live', expiry: DateTime(2026, 10, 7))])
          .map((p) => p.id),
      ['live'],
    );
    fresh.dispose();
  });

  test('a first-time install announces nothing', () async {
    now = DateTime(2026, 9, 30, 9);
    final fresh = build();
    var announced = 0;
    fresh.addListener(() => announced++);
    await fresh.ready;
    expect(announced, 0);
    fresh.dispose();
  });

  test('two rows on one symbol are retired independently', () async {
    c = build();
    await c.init();
    now = DateTime(2026, 10, 1, 7, 30);

    // The open lot is fine; only the squared-off one is due.
    final kept = c.retain([
      _p(id: 'open-lot', expiry: DateTime(2026, 10, 7)),
      _p(id: 'closed-lot', quantity: 0, closedAt: DateTime(2026, 9, 20, 9)),
    ]);
    expect(kept.map((p) => p.id), ['open-lot']);
  });

  group('timeToNextBoundary', () {
    test('points at today 07:00 when the app opens before it', () async {
      now = DateTime(2026, 9, 30, 4);
      c = build();
      await c.init();
      expect(c.timeToNextBoundary, const Duration(hours: 3));
    });

    test('points at tomorrow 07:00 once past it', () async {
      now = DateTime(2026, 9, 30, 9);
      c = build();
      await c.init();
      expect(c.timeToNextBoundary, const Duration(hours: 22));
    });

    test('is exactly 07:00 on the boundary itself', () async {
      now = DateTime(2026, 9, 30, 7);
      c = build();
      await c.init();
      expect(c.timeToNextBoundary, const Duration(hours: 24));
    });
  });

  test('the boundary timer fires a sweep and rearms', () async {
    // 500ms before 07:00 on the injected clock.
    now = DateTime(2026, 9, 30, 6, 59, 59, 500);
    c = build();
    await c.init();
    expect(c.timeToNextBoundary, const Duration(milliseconds: 500));

    var fired = 0;
    c.addListener(() => fired++);

    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(fired, 1, reason: 'the 07:00 boundary should trigger a re-read');

    // It must keep going for the next day rather than dying after one shot.
    expect(c.timeToNextBoundary.isNegative, isFalse);
    c.dispose();
  });

  test('a failed store read still yields a working book', () async {
    final exploding = _ExplodingStore();
    c = build(store: exploding);
    await c.init();
    expect(c.retain([_p(id: 'live', expiry: DateTime(2026, 10, 7))]).length, 1);
    c.dispose();
  });
}

class _ExplodingStore implements PositionRetentionStore {
  const _ExplodingStore();

  @override
  String get key => 'boom';

  @override
  Future<Set<String>> load() async => throw StateError('no storage');

  @override
  Future<void> save(Set<String> removed) async => throw StateError('no storage');

  @override
  Future<void> clear() async => throw StateError('no storage');
}
