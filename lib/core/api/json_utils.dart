double? asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '').trim());
}

double asDoubleOr(Object? v, double fallback) => asDouble(v) ?? fallback;

int asInt(Object? v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

String asString(Object? v, [String fallback = '']) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

List<double> asDoubleList(Object? v) {
  if (v is List) {
    return v.map(asDouble).whereType<double>().toList(growable: false);
  }
  return const [];
}
