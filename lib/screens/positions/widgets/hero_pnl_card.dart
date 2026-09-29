import 'package:flutter/material.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/cyber_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/position.dart';

/// Centered white "Total P&L" summary card, floating above the slate-100
/// backdrop before the rounded portfolio panel.
class HeroPnlCard extends StatelessWidget {
  final PortfolioSummary summary;

  const HeroPnlCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final value = formatSigned(summary.totalPnl);
    final isProfit = summary.totalPnl >= 0;

    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: TradePalette.slate200.withValues(alpha: 0.8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 30,
            spreadRadius: -4,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 12,
            spreadRadius: -2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total P&L',
            style: AppText.micro.copyWith(
              color: TradePalette.slate500,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.heroPnl.copyWith(
              color: isProfit ? TradePalette.positiveGreen : TradePalette.negativeRed,
            ),
          ),
        ],
      ),
    );
  }
}