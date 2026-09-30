import 'position.dart';

/// Paper-trading stand-in for the broker's intraday auto-square-off.
///
/// A real broker closes every open MIS position shortly before the session
/// ends, so a day cannot be left holding an intraday position. This app does
/// the same at **15:20 local time**: quantity goes to 0, average goes to 0, the
/// realised P&L is frozen onto the position, and the row stays in the book
/// (with its LTP still live) until the 07:00 retention sweep removes it the
/// next morning.
///
/// The policy is pure — no clock, no IO — so the cut-off arithmetic can be
/// tested directly.
class MisSquareOffPolicy {
  const MisSquareOffPolicy({
    this.hour = 15,
    this.minute = 20,
  });

  final int hour;
  final int minute;

  /// 15:20 on [day]'s date.
  DateTime cutoffOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  /// Whether [now] is at or past today's cut-off. Before it, an MIS position is
  /// legitimately open and must be left alone.
  bool isDue(DateTime now) => !now.isBefore(cutoffOn(now));

  Duration get timeToCutoffFromMidnight =>
      Duration(hours: hour, minutes: minute);

  /// Whether [p] is one the cut-off has to close: still open, still intraday.
  bool isDueForSquareOff(Position p, DateTime now) =>
      !p.isClosed && p.product.toUpperCase() == 'MIS' && isDue(now);

  /// The open MIS positions in [positions] that are due right now.
  List<Position> dueForSquareOff(List<Position> positions, DateTime now) =>
      [for (final p in positions) if (isDueForSquareOff(p, now)) p];

  /// Realised P&L for [p] at [ltp].
  ///
  /// Signed the same way the rest of the app is: a short that gains money has a
  /// negative quantity, and the arithmetic below produces a positive result for
  /// it without a special case.
  static double realisedPnl(Position p, double ltp) =>
      (ltp - p.averagePrice) * p.quantity;

  /// [p] as it looks immediately after being squared off at [ltp].
  ///
  /// [closedAt] is stamped with the cut-off, not `DateTime.now()`, so the
  /// retention rule counts the next morning from 15:20 rather than from
  /// whenever the sweep happened to run.
  Position squareOff(Position p, double ltp, DateTime closedAt) {
    final realised = realisedPnl(p, ltp);
    return p.copyWith(
      quantity: 0,
      averagePrice: 0,
      // Keep the closing price so the row's LTP has a sane floor if the live
      // feed is silent.
      lastTradedPrice: ltp,
      pnl: realised,
      closedAt: closedAt,
    );
  }
}
