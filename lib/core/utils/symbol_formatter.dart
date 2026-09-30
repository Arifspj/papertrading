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

  /// Day of expiry, e.g. `01` or `24`. Options only. Null for monthly.
  final String? day;

  /// Ordinal suffix of the day, e.g. `st`, `th`. Rendered as a superscript.
  /// Inferred from the day number when the source omits it (`24OCT` -> `th`).
  final String? ordinal;

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
    this.ordinal,
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
  static const _monthOrder = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  static final _day = RegExp(r'^(\d{1,2})(st|nd|rd|th)?$');
  static final _dayMonth = RegExp(r'^(\d{1,2})([A-Z]{3})$');
  static final _month = RegExp(r'^([A-Z]{3})$');
  static final _number = RegExp(r'^\d+(\.\d+)?$');

  /// English ordinal suffix for a day number: 1st, 2nd, 3rd, 4th ... 21st,
  /// 22nd, 23rd, 24th, with 11/12/13 taking "th".
  static String ordinalSuffix(int day) {
    if (day % 100 >= 11 && day % 100 <= 13) return 'th';
    return switch (day % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }

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
    String? ordinal;
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
        day ??= d.group(1);
        ordinal ??= d.group(2);
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
    // Expiry day (and its ordinal) only exists for option contracts; futures
    // are always month-only.
    if (!isOption) {
      day = null;
      ordinal = null;
    } else if (day != null && ordinal == null) {
      ordinal = ordinalSuffix(int.parse(day));
    }
    final kind = day != null && isOption
        ? ExpiryKind.weekly
        : month != null
        ? ExpiryKind.monthly
        : ExpiryKind.none;

    return SymbolParts(
      raw: symbol,
      underlying: tokens.join(' '),
      day: day,
      ordinal: ordinal,
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

  /// Bare instrument for market-data APIs, e.g. `NIFTY`, `BANKNIFTY`, `SENSEX`.
  /// Empty when the symbol is not an index-style derivative.
  String get apiInstrument =>
      isOption || isFuture ? underlying.toUpperCase() : '';

  /// Numeric strike, or null for futures/cash symbols.
  int? get strikeValue {
    final s = strike;
    if (s == null) return null;
    final d = double.tryParse(s);
    if (d == null) return null;
    return d.round();
  }

  /// `CE` / `PE` / `FUT`, ready for the `/ltp/{instrument}/{strike}/{type}` API.
  String get apiOptionType => instrumentType ?? '';

  /// The contract's expiry as `yyyy-MM-dd`, or null when the symbol carries no
  /// usable expiry tokens.
  ///
  /// Upstream prices a contract per expiry and the `/ltp/*` route is keyed on
  /// it, so a month/day pair has to be resolved to a real calendar date. That
  /// pair repeats every year, so this returns the next occurrence on or after
  /// [now], which keeps a symbol pinned to its own expiry rather than silently
  /// rolling onto a contract that already expired.
  String? expiryStamp({DateTime? now}) {
    final m = month;
    final d = day;
    if (m == null || d == null) return null;
    final monthIndex = _monthOrder.indexOf(m.toUpperCase());
    if (monthIndex < 0) return null;
    final dayValue = int.tryParse(d);
    if (dayValue == null || dayValue < 1 || dayValue > 31) return null;

    final ref = now ?? DateTime.now();
    // Compared at day granularity, not by instant: on the expiry day itself
    // `candidate` is equal to (not after) the reference, and an `isAfter` test
    // would wrongly push it a whole year out.
    final refDay = DateTime(ref.year, ref.month, ref.day);
    for (var year = ref.year; year <= ref.year + 1; year++) {
      final candidate = DateTime(year, monthIndex + 1, dayValue);
      if (candidate.month != monthIndex + 1) continue; // e.g. 31 Feb
      if (!candidate.isBefore(refDay)) {
        return '${candidate.year.toString().padLeft(4, '0')}-'
            '${candidate.month.toString().padLeft(2, '0')}-'
            '${candidate.day.toString().padLeft(2, '0')}';
      }
    }
    return null;
  }

  /// Canonical API symbol used to match a live quote to this instrument,
  /// e.g. `NIFTY 22700 CE` (no expiry tokens — the API keys on these).
  String get apiSymbol {
    final i = apiInstrument;
    if (i.isEmpty) return raw.toUpperCase();
    final k = strikeValue;
    if (k == null) return i;
    final t = apiOptionType;
    return t.isEmpty ? '$i $k' : '$i $k $t';
  }
}
