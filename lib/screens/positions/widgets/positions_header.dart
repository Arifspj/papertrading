import 'package:flutter/material.dart';

import '../../../core/theme/cyber_colors.dart';

/// Portfolio header: Holdings / Positions tabs with an active bottom
/// underline, mirroring the reference light-trading layout.
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: 'Holdings',
              count: holdingsCount,
              selected: selectedTab == 0,
              showCount: false,
              contentAlign: MainAxisAlignment.end,
              onTap: () => onTabSelected(0),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _Tab(
              label: 'Positions',
              count: openCount,
              selected: selectedTab == 1,
              contentAlign: MainAxisAlignment.start,
              onTap: () => onTabSelected(1),
            ),
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
  final bool showCount;
  final MainAxisAlignment contentAlign;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.contentAlign,
    required this.onTap,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? TradePalette.primary : TradePalette.slate600;
    final pillColor =
        selected ? TradePalette.primary.withValues(alpha: 0.8) : TradePalette.slate500;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: contentAlign,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: selected ? 25 : 0,
                      height: 2,
                      decoration: BoxDecoration(
                        color:
                            selected ? TradePalette.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                if (showCount && count > 0) ...[
                    const SizedBox(width: 6),
                    Transform.translate(
                      offset: const Offset(0, 1),
                      child: Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pillColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
