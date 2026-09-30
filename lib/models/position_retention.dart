import '../models/position.dart';

/// Book-retention rule, kept free of clocks, IO and widgets so the cutoff
/// arithmetic can be tested directly.
///
/// A position leaves the book at **07:00 the morning after** either of these:
///
///  * it was squared off (`closedAt`), or
///  * its contract expired (`expiry`).
///
/// Whichever trigger comes first wins. Positions stay visible for the rest of
/// the day they close or expire, so the user can still see the trade they
/// just made; the cleanup happens on the next morning's boundary.
class PositionRetention {
  const PositionRetention({this.cleanupHour = 7});

  /// Local hour of the morning boundary. 07:00 IST, before the 09:15 open, so
  /// a stale row is gone before the day's first quote lands.
  final int cleanupHour;

  /// The morning boundary following [anchor]: 07:00 on the next calendar day.
  DateTime nextMorning(DateTime anchor) =>
      DateTime(anchor.year, anchor.month, anchor.day + 1, cleanupHour);

  /// When [p] is due for removal, or null when it has no trigger at all.
  ///
  /// A closed position with no `closedAt` is anchored to [now] rather than
  /// treated as immediately stale. Brokers routinely square off without sending
  /// an exit timestamp, and dropping those rows on sight would hide trades the
  /// user has not had a chance to read yet.
  DateTime? purgeAt(Position p, DateTime now) {
    final triggers = <DateTime>[];

    if (p.isClosed) {
      // A closed position with no `closedAt` is anchored to [now] rather than
      // treated as immediately stale. Brokers routinely square off without
      // sending an exit timestamp, and dropping those rows on sight would hide
      // trades the user has not had a chance to read yet.
      triggers.add(nextMorning(p.closedAt ?? now));
    }

    final expiry = p.expiry;
    if (expiry != null) {
      // An expiry is a calendar date, so anchor on its own day rather than
      // inheriting whatever time of day the payload happened to carry.
      triggers.add(nextMorning(DateTime(expiry.year, expiry.month, expiry.day)));
    }

    if (triggers.isEmpty) return null;
    return triggers.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Whether [p] should be gone as of [now].
  bool isPurgeable(Position p, DateTime now) {
    final due = purgeAt(p, now);
    return due != null && !now.isBefore(due);
  }

  /// The subset of [positions] that should still be on screen.
  List<Position> retain(List<Position> positions, DateTime now) => [
        for (final p in positions)
          if (!isPurgeable(p, now)) p,
      ];
}
