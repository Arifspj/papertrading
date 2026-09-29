import 'package:flutter/material.dart';

import '../../../core/theme/cyber_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/position.dart';
import '../../../widgets/scale_fit.dart';

/// A single position row inside the rounded portfolio panel, matching the
/// reference "Positions" card: a Qty/Avg line with product tag, then the
/// symbol/segment (left) and P&L/LTP (right).
class PositionCard extends StatelessWidget {
  final Position position;
  final VoidCallback onTap;

  const PositionCard({super.key, required this.position, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = position;
    final closed = p.isClosed;

    final qtyColor = closed
        ? TradePalette.slate600
        : p.quantity > 0
        ? TradePalette.qtyLong
        : TradePalette.qtyShort;

    final pnlColor = p.pnl < 0
        ? TradePalette.negativeRed
        : TradePalette.positiveGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: ScaleFit(
                      alignment: Alignment.centerLeft,
                      child: _QtyAvgRow(p: p, qtyColor: qtyColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ProductTag(product: p.product, dimmed: closed),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SymbolTitle(symbol: p.symbol, dimmed: closed),
                        if (p.segment.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(p.segment, style: _segmentStyle),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: ScaleFit(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatSigned(p.pnl),
                            style: _pnlStyle.copyWith(color: pnlColor),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('LTP', style: _ltpLabelStyle),
                              const SizedBox(width: 4),
                              Text(
                                formatPlain(p.lastTradedPrice),
                                style: _ltpValueStyle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Weekly-option aware symbol title: renders "01" + superscript "st" and a
/// circular "W" badge for symbols like "SENSEX 01st W OCT 72900 PE".
class _SymbolTitle extends StatelessWidget {
  final String symbol;
  final bool dimmed;

  const _SymbolTitle({required this.symbol, required this.dimmed});

  static final RegExp _weekly = RegExp(r'^(.+\d+)(st|nd|rd|th)\s+W\s+(.+)$');

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 14,
      fontWeight: dimmed ? FontWeight.w400 : FontWeight.w500,
      letterSpacing: 0.1,
      color: dimmed ? TradePalette.slate400 : TradePalette.slate900,
      height: 1.2,
    );

    final m = _weekly.firstMatch(symbol);
    if (m == null) {
      return Text(
        symbol,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: m.group(1)),
          TextSpan(
            text: m.group(2),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: TradePalette.slate500,
            ),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: TradePalette.weekBadge,
                shape: BoxShape.circle,
              ),
              child: const Text(
                'W',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          TextSpan(text: m.group(3)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// NRML (purple) / MIS (red, 60% opacity) product chip with square corners.
class ProductTag extends StatelessWidget {
  final String product;
  final bool dimmed;

  const ProductTag({super.key, required this.product, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final isMis = product.toUpperCase() == 'MIS';
    final bg = isMis ? TradePalette.red50 : TradePalette.nrmlBg;
    final fg = isMis ? TradePalette.misText : TradePalette.nrmlText;
    final alpha = dimmed ? 0.6 : (isMis ? 0.6 : 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg.withValues(alpha: alpha)),
      child: Text(
        product,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg.withValues(alpha: alpha),
        ),
      ),
    );
  }
}

const _segmentStyle = TextStyle(
  fontSize: 10,
  color: TradePalette.slate400,
  fontFeatures: [FontFeature.tabularFigures()],
);
const _pnlStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  fontFeatures: [FontFeature.tabularFigures()],
);
const _ltpLabelStyle = TextStyle(
  fontSize: 10,
  color: TradePalette.slate400,
  fontFeatures: [FontFeature.tabularFigures()],
);
const _ltpValueStyle = TextStyle(
  fontSize: 10,
  color: TradePalette.slate600,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _QtyAvgRow extends StatelessWidget {
  final Position p;
  final Color qtyColor;

  const _QtyAvgRow({required this.p, required this.qtyColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Qty.', style: _labelStyle),
        const SizedBox(width: 6),
        Text(
          formatQty(p.quantity.toDouble()),
          style: _labelStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: qtyColor,
          ),
        ),
        const SizedBox(width: 6),
        const Text('Avg.', style: _labelStyle),
        const SizedBox(width: 6),
        Text(
          formatPlain(p.averagePrice),
          style: _labelStyle.copyWith(color: TradePalette.slate700),
        ),
      ],
    );
  }
}

const _labelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: TradePalette.slate400,
  fontFeatures: [FontFeature.tabularFigures()],
);
