import 'package:flutter/material.dart';

import '../core/theme/app_fonts.dart';
import '../core/theme/cyber_colors.dart';

/// Simple skeleton for tabs not yet built out.
class SimpleTabScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const SimpleTabScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cyber;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(
              title,
              style: AppText.title.copyWith(color: c.textPrimary),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(icon, size: 26, color: c.textMuted),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppText.symbol.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Coming soon',
                      style: AppText.micro.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}