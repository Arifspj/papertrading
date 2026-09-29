import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/cyber_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/position.dart';

/// Modal detail sheet for a tapped position with a Square-off action.
/// Returns `true` when the user confirms square-off.
Future<bool?> showPositionDetailSheet(
  BuildContext context, {
  required Position position,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.cyber.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _PositionDetailSheet(position: position),
  );
}

class _PositionDetailSheet extends StatefulWidget {
  final Position position;

  const _PositionDetailSheet({required this.position});

  @override
  State<_PositionDetailSheet> createState() => _PositionDetailSheetState();
}

class _PositionDetailSheetState extends State<_PositionDetailSheet> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final c = context.cyber;
    final p = widget.position;
    final pnlColor = p.isLoss
        ? c.negative
        : p.isProfit
            ? c.positive
            : c.textSecondary;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(LucideIcons.briefcase, size: 18, color: c.positive),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.symbol.copyWith(color: c.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(LucideIcons.x, size: 18, color: c.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _cell(c, 'Qty', formatQty(p.quantity.toDouble()),
                    color: p.side == PositionSide.short ? c.negative : c.cyan),
                _cell(c, 'Avg', formatPlain(p.averagePrice)),
                _cell(c, 'LTP', formatPlain(p.lastTradedPrice)),
                _cell(c, 'P&L', formatSigned(p.pnl), color: pnlColor),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _confirming
                  ? null
                  : () async {
                      setState(() => _confirming = true);
                      await Future<void>.delayed(const Duration(milliseconds: 500));
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: c.negative,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: c.negative.withValues(alpha: 0.6),
              ),
              icon: _confirming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.xCircle, size: 18),
              label: Text(_confirming ? 'Squaring off…' : 'Square Off'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(CyberColors c, String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.micro.copyWith(color: c.textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.monoValueBold.copyWith(
              color: color ?? c.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}