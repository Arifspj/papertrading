import 'package:flutter/material.dart';

import '../core/icons/lucide_icons.dart';

import '../core/theme/app_fonts.dart';
import '../core/theme/cyber_colors.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final String href;

  const _NavItem(this.icon, this.label, this.href);
}

const _items = [
  _NavItem(LucideIcons.bookmark, 'Watchlist', '#watchlist'),
  _NavItem(LucideIcons.fileText, 'Orders', '#orders'),
  _NavItem(LucideIcons.briefcase, 'Positions', '#positions'),
  _NavItem(LucideIcons.settings, 'Settings', '#settings'),
  _NavItem(LucideIcons.user, 'Account', '#account'),
];

/// Flat white bottom navigation, active tab highlighted in #2563EB
/// (mirrors the reference light-trading layout).
class CyberNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const CyberNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: TradePalette.slate200)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: _items[i],
                    active: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? TradePalette.activeNav : TradePalette.slate500;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 20, color: color),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                style: AppText.micro.copyWith(
                  fontSize: 10,
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
