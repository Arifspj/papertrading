import 'package:flutter/material.dart';

import '../../../core/theme/cyber_colors.dart';
import '../../positions/widgets/order_pad_sheet.dart';

/// Weekly-option aware symbol line with superscript and "W" badge:
/// "SENSEX 01st [W] OCT 72900 PE". Reused in watchlist rows, search results
/// and the order pad title.
class WatchSymbolLine extends StatelessWidget {
  final String symbol;
  final bool isWeekly;
  final double fontSize;

  const WatchSymbolLine({
    super.key,
    required this.symbol,
    this.isWeekly = false,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final parts = SymbolParts.parse(symbol);
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: TradePalette.slate900,
      height: 1.3,
    );
    final badge = (fontSize * 14 / 15).clamp(12.0, 16.0);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: parts.head),
          if (parts.suffix != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Transform.translate(
                offset: const Offset(0, -2),
                child: Text(
                  parts.suffix!,
                  style: TextStyle(
                    fontSize: fontSize * 0.67,
                    fontWeight: FontWeight.w600,
                    color: TradePalette.slate500,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          if (isWeekly)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                width: badge,
                height: badge,
                margin: const EdgeInsets.symmetric(horizontal: 2),
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
          TextSpan(text: parts.tail),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}