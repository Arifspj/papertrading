import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/cyber_colors.dart';
import '../../../models/position.dart';

/// Bottom-sheet filter picker for the positions list.
Future<PositionFilter?> showPositionsFilterSheet(
  BuildContext context, {
  required PositionFilter current,
}) {
  return showModalBottomSheet<PositionFilter>(
    context: context,
    builder: (_) => _Sheet(current: current),
  );
}

class _Sheet extends StatelessWidget {
  final PositionFilter current;

  const _Sheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final c = context.cyber;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Filter Positions',
              style: AppText.title.copyWith(color: c.textPrimary, fontSize: 19),
            ),
            const SizedBox(height: 6),
            Text(
              'Narrow down by direction or P&L',
              style: AppText.micro.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final f in PositionFilter.values)
                  _FilterChip(
                    label: f.label,
                    selected: f == current,
                    onTap: () => Navigator.of(context).pop(f),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cyber;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c.positiveSoft : c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? c.borderActive : c.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(LucideIcons.check, size: 14, color: c.positive),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppText.micro.copyWith(
                  color: selected ? c.positive : c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}