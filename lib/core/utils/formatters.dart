import 'package:intl/intl.dart';

/// Indian lakh/crore grouping (matches reference HTML): 1,26,390.25
final NumberFormat _amount = NumberFormat('#,##,##0.00', 'en_IN');
/// Plain 2-decimal, no grouping: 98.25
final NumberFormat _plain = NumberFormat('0.00', 'en_US');
/// Plain integer from double when whole.
final NumberFormat _plainInt = NumberFormat('0', 'en_US');

/// 1234.5 -> "1,234.50"
String formatAmount(double value) => _amount.format(value);

/// 1234.5 -> "1234.50" (no comma separators)
String formatPlain(double value) => _plain.format(value);

/// Signed amount: 1234.5 -> "+1,234.50", -12 -> "-12.00"
String formatSigned(double value) {
  final abs = _amount.format(value.abs());
  return value < 0 ? '-$abs' : '+$abs';
}

/// Indian grouped integer (used for qty of large values).
String formatIndianInt(int value) => _amount.format(value.toDouble());

/// 2.5 -> "2.5" but 50 -> "50"
String formatQty(double value) =>
    value == value.roundToDouble() ? _plainInt.format(value) : _plain.format(value);