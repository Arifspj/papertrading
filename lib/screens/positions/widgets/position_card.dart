import 'package:flutter/material.dart';

import '../../../core/theme/cyber_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/market/live_quote.dart';
import '../../../models/position.dart';
import '../../../widgets/instrument_title.dart';
import '../../../widgets/scale_fit.dart';

/// A single position row inside the rounded portfolio panel, matching the
/// reference "Positions" card: a Qty/Avg line with product tag, then the
/// symbol/segment (left) and P&L/LTP (right).
class PositionCard extends StatelessWidget {
  final Position position;

  /// Live quote for this contract, when the feed has one. Falls back to the
  /// position's stored price so the row is never blank.
  final LiveQuote? live;

  final VoidCallback onTap;

  const PositionCard({
    super.key,
    required this.position,
    required this.onTap,
    this.live,
  });

  @override
  Widget build(BuildContext context) {
    final p = position;
    final closed = p.isClosed;

    // A live price only counts once it is a real number; the chain can hand
    // back a zero for a strike that has no premium.
    final ltp = (live != null && live!.ltp > 0)
        ? live!.ltp
        : p.lastTradedPrice;

    // A closed row shows its realised P&L as booked, never recomputed. Both
    // `quantity` and `averagePrice` are zeroed on a square-off, so
    // re-pricing one from the live mark would collapse to 0 and throw away the
    // result the user actually locked in. The LTP beside it still ticks: the
    // row stays tracked until retention removes it the next morning.
    final pnl = closed
        ? p.pnl
        : live != null && ltp > 0
        ? (ltp - p.averagePrice) * p.quantity
        : p.pnl;

    final qtyColor = closed
        ? TradePalette.slate600
        : p.quantity > 0
        ? TradePalette.qtyLong
        : TradePalette.qtyShort;

    final pnlColor = pnl < 0
        ? TradePalette.negativeRed
        : TradePalette.positiveGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InstrumentTitle(
                          symbol: p.symbol,
                          fontSize: 16,
                          fontWeight: closed
                              ? FontWeight.w400
                              : FontWeight.w600,
                          color: closed
                              ? TradePalette.slate400
                              : TradePalette.slate900,
                          letterSpacing: 0.1,
                        ),
                        if (p.segment.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(p.segment, style: _segmentStyle),
                        ],                      ],
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
                            formatSigned(pnl),
                            style: _pnlStyle.copyWith(
                              color: pnlColor.withValues(
                                alpha: closed ? 0.8 : 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('LTP', style: _ltpLabelStyle),
                              const SizedBox(width: 4),
                              Text(
                                formatPlain(ltp),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg.withValues(alpha: alpha)),
      child: Text(
        product,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg.withValues(alpha: alpha),
        ),
      ),
    );
  }
}

const _segmentStyle = TextStyle(
  fontSize: 11.5,
  color: TradePalette.slate400,
  fontFeatures: [FontFeature.tabularFigures()],
);
const _pnlStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  fontFeatures: [FontFeature.tabularFigures()],
);
const _ltpLabelStyle = TextStyle(
  fontSize: 11.5,
  color: TradePalette.slate400,
  fontFeatures: [FontFeature.tabularFigures()],
);
const _ltpValueStyle = TextStyle(
  fontSize: 12.5,
  color: TradePalette.slate600,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _QtyAvgRow extends StatelessWidget {
  final Position p;
  final Color qtyColor;

  const _QtyAvgRow({required this.p, required this.qtyColor});

  @override
  Widget build(BuildContext context) {
    final closed = p.isClosed;
    return Row(
      children: [
        const Text('Qty.', style: _labelStyle),
        const SizedBox(width: 6),
        Transform.translate(
          offset: closed ? const Offset(0, 1) : Offset.zero,
          child: Text(
            formatQty(p.quantity.toDouble()),
            style: _labelStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: qtyColor.withValues(alpha: closed ? 0.6 : 1),
            ),
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
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: TradePalette.slate400,
  fontFeatures: [FontFeature.tabularFigures()],
);
