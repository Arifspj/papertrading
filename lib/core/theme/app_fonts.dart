import 'package:flutter/material.dart';

/// Font families follow the system stack (Segoe UI / Roboto) like the
/// reference HTML. Numbers use tabular figures for aligned digit columns.
class AppFonts {
  static const String? display = null;
  static const String? mono = null;
}

class AppText {
  static const TextStyle heroPnl = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );
  static const TextStyle symbol = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
  static const TextStyle symbolLg = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
  static const TextStyle cardPnl = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle monoValue = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle monoValueBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  static const TextStyle micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
}