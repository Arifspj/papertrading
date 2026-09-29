import 'package:flutter/material.dart';

import '../core/theme/cyber_colors.dart';
import '../core/utils/symbol_formatter.dart';

/// The single symbol renderer used on every page (position card, watchlist
/// row, search result, order pad).
///
///   * Weekly  -> `SENSEX 01ˢᵗ [W] OCT 72900 PE` (only the ordinal is raised)
///   * Monthly -> `NIFTY OCT 22350 PE`             (month, no badge)
class InstrumentTitle extends StatelessWidget {
  final String symbol;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final double letterSpacing;

  const InstrumentTitle({
    super.key,
    required this.symbol,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w600,
    this.color = TradePalette.slate900,
    this.letterSpacing = -0.2,
  });

  @override
  Widget build(BuildContext context) {
    final p = SymbolParts.parse(symbol);
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: 1.3,
    );
    final badge = (fontSize * 14 / 15).clamp(12.0, 16.0);

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: p.day != null ? '${p.underlying} ${p.day}' : p.underlying),
          if (p.ordinal != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Transform.translate(
                offset: Offset(0, -(fontSize * 0.2 + 3)),
                child: Text(
                  p.ordinal!,
                  style: TextStyle(
                    fontSize: fontSize * 0.62,
                    fontWeight: FontWeight.w600,
                    color: TradePalette.slate500,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          if (p.isWeekly)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                width: badge,
                height: badge,
                margin: const EdgeInsets.only(left: 4, right: 2),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: TradePalette.weekBadge,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  'W',
                  style: TextStyle(
                    fontSize: badge * 0.64,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          if (p.month != null) TextSpan(text: ' ${p.month}'),
          if (p.strike != null) TextSpan(text: ' ${p.strike}'),
          if (p.instrumentType != null) TextSpan(text: ' ${p.instrumentType}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
