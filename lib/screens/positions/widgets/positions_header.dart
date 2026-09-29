import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/cyber_colors.dart';
import '../../../widgets/scale_fit.dart';

/// iOS-style status bar shown above the portfolio header.
class IosStatusBar extends StatelessWidget {
  const IosStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: TradePalette.slate100,
      child: Row(
        children: [
          const Text(
            '20:47',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TradePalette.slate900,
            ),
          ),
          Flexible(
            child: ScaleFit(
              alignment: Alignment.centerRight,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.signalHigh,
                    size: 14,
                    color: TradePalette.slate900,
                  ),
                  SizedBox(width: 5),
                  Text(
                    '5G',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: TradePalette.slate900,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    LucideIcons.batteryFull,
                    size: 16,
                    color: TradePalette.slate900,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '100%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: TradePalette.slate900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Portfolio header: title + Holdings / Positions tabs with an active
/// bottom underline, mirroring the reference light-trading layout.
class PortfolioHeader extends StatelessWidget {
  final int openCount;
  final int holdingsCount;
  final int selectedTab; // 0 => Holdings, 1 => Positions
  final ValueChanged<int> onTabSelected;

  const PortfolioHeader({
    super.key,
    required this.openCount,
    required this.holdingsCount,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TradePalette.slate100,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.chevronLeft,
                size: 22,
                color: TradePalette.slate900,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ScaleFit(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Portfolio',
                    style: AppText.title.copyWith(color: TradePalette.slate900),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Tab(
                  label: 'Holdings',
                  count: holdingsCount,
                  selected: selectedTab == 0,
                  onTap: () => onTabSelected(0),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _Tab(
                  label: 'Positions',
                  count: openCount,
                  selected: selectedTab == 1,
                  onTap: () => onTabSelected(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? TradePalette.primary
                        : TradePalette.slate500,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($count)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? TradePalette.primary
                        : TradePalette.slate400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: selected ? TradePalette.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
