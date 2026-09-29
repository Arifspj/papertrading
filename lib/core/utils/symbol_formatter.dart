/// Unified symbol parsing + display rules shared by every page.
///
/// Canonical raw form: `UNDERLYING [DAY] [MONTH] [STRIKE] [TYPE]`
///   * Weekly  : a day is present  -> `NIFTY 24OCT 22500 CE`  (W badge)
///   * Monthly : only a month      -> `NIFTY OCT 22350 PE`     (no badge)
///   * Futures : month only        -> `NIFTY NOV FUT`
///   * Cash    : nothing           -> `NIFTY`
///
/// A standalone `W` token in the source (`SENSEX 01st W OCT 72900 PE`) is
/// legacy and simply dropped; the day alone decides the weekly tag.
enum ExpiryKind { none, weekly, monthly }

class SymbolParts {
  final String raw;
  final String underlying;

  /// Day of expiry, e.g. `01st` or `24`. Null for monthly contracts.
  final String? day;

  /// Month of expiry, e.g. `OCT`.
  final String? month;

  /// Strike price, e.g. `22350`.
  final String? strike;

  /// `CE`, `PE`, `FUT` or null for cash/indices.
  final String? instrumentType;

  final ExpiryKind kind;

  const SymbolParts({
    required this.raw,
    required this.underlying,
    this.day,
    this.month,
    this.strike,
    this.instrumentType,
    required this.kind,
  });

  bool get isWeekly => kind == ExpiryKind.weekly;
  bool get isMonthly => kind == ExpiryKind.monthly;
  bool get isOption => instrumentType == 'CE' || instrumentType == 'PE';
  bool get isFuture => instrumentType == 'FUT';

  static const _months = {
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  };
  static final _day = RegExp(r'^(\d{1,2})(st|nd|rd|th)?$');
  static final _dayMonth = RegExp(r'^(\d{1,2})([A-Z]{3})$');
  static final _month = RegExp(r'^([A-Z]{3})$');
  static final _number = RegExp(r'^\d+(\.\d+)?$');

  factory SymbolParts.parse(String symbol) {
    final tokens = symbol
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && t != 'W')
        .toList();

    String? instrument;
    if (tokens.isNotEmpty && const {'CE', 'PE', 'FUT'}.contains(tokens.last)) {
      instrument = tokens.removeLast();
    }

    String? strike;
    if (tokens.isNotEmpty && _number.hasMatch(tokens.last)) {
      strike = tokens.removeLast();
    }

    String? day;
    String? month;
    for (final t in tokens.toList()) {
      final dayMonth = _dayMonth.firstMatch(t);
      if (dayMonth != null) {
        day ??= dayMonth.group(1);
        month ??= dayMonth.group(2);
        tokens.remove(t);
        continue;
      }
      final d = _day.firstMatch(t);
      if (d != null && d.group(1) != strike) {
        day ??= t;
        tokens.remove(t);
        continue;
      }
      final m = _month.firstMatch(t);
      if (m != null && _months.contains(t)) {
        month ??= t;
        tokens.remove(t);
      }
    }

    final isOption = instrument == 'CE' || instrument == 'PE';
    final kind = day != null && isOption
        ? ExpiryKind.weekly
        : month != null
        ? ExpiryKind.monthly
        : ExpiryKind.none;

    return SymbolParts(
      raw: symbol,
      underlying: tokens.join(' '),
      day: day,
      month: month,
      strike: strike,
      instrumentType: instrument,
      kind: kind,
    );
  }

  /// Human label for the instrument type, e.g. `Options (CE)` / `Futures`.
  String get instrumentLabel {
    if (isOption) return 'Options ($instrumentType)';
    if (isFuture) return 'Futures';
    return 'Equity';
  }
}
