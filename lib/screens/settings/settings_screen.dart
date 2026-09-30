import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/icons/lucide_icons.dart';

import '../../core/api/api_config.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/cyber_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../widgets/scale_fit.dart';

/// Settings tab — trading theme (dark/white/system) + paper-trading API info.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cyber;
    final theme = context.watch<ThemeController>();
    final settings = context.watch<AppSettingsController>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
        children: [
          Text('Settings', style: AppText.title.copyWith(color: c.textPrimary)),
          const SizedBox(height: 20),

          _SectionTitle(
            c: c,
            icon: LucideIcons.palette,
            title: 'Trading Theme',
          ),
          const SizedBox(height: 10),
          _Card(
            c: c,
            child: Column(
              children: [
                _ThemeRow(
                  c: c,
                  icon: LucideIcons.moon,
                  label: 'Dark',
                  subtitle: 'CyberPulse night mode',
                  selected: theme.mode == ThemeMode.dark,
                  onTap: () => theme.mode = ThemeMode.dark,
                ),
                Divider(height: 1, color: c.border),
                _ThemeRow(
                  c: c,
                  icon: LucideIcons.sun,
                  label: 'White',
                  subtitle: 'Clean daylight terminal',
                  selected: theme.mode == ThemeMode.light,
                  onTap: () => theme.mode = ThemeMode.light,
                ),
                Divider(height: 1, color: c.border),
                _ThemeRow(
                  c: c,
                  icon: LucideIcons.cpu,
                  label: 'System',
                  subtitle: 'Follow device setting',
                  selected: theme.mode == ThemeMode.system,
                  onTap: () => theme.mode = ThemeMode.system,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle(
            c: c,
            icon: LucideIcons.activity,
            title: 'Market Feed',
          ),
          const SizedBox(height: 10),
          _Card(
            c: c,
            child: _ToggleRow(
              c: c,
              icon: LucideIcons.chartNoAxesColumnIncreasing,
              label: 'Live ticker',
              subtitle: 'Scrolling quotes under the app header',
              value: settings.tickerEnabled,
              onChanged: (v) => settings.tickerEnabled = v,
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle(
            c: c,
            icon: LucideIcons.link,
            title: 'Paper Trading API',
          ),
          const SizedBox(height: 10),
          _Card(
            c: c,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ApiConfig.baseUrl.contains('example.com')
                            ? c.textMuted
                            : c.positive,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ApiConfig.baseUrl.contains('example.com')
                          ? 'Not connected'
                          : 'Connected',
                      style: AppText.micro.copyWith(
                        color: ApiConfig.baseUrl.contains('example.com')
                            ? c.textMuted
                            : c.positive,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  ApiConfig.baseUrl,
                  style: AppText.monoValueBold.copyWith(
                    color: c.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Point the app at your live paper-trading server with:\n'
                  'flutter run --dart-define=PAPER_TRADE_BASE_URL=…',
                  style: AppText.micro.copyWith(
                    color: c.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle(c: c, icon: LucideIcons.info, title: 'App'),
          const SizedBox(height: 10),
          _Card(
            c: c,
            child: Row(
              children: [
                Text(
                  'Version',
                  style: AppText.micro.copyWith(color: c.textMuted),
                ),
                Flexible(
                  child: ScaleFit(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'CyberPulse 1.0.0',
                      style: AppText.monoValueBold.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final CyberColors c;
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.c,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: c.positive),
        const SizedBox(width: 8),
        Flexible(
          child: ScaleFit(
            alignment: Alignment.centerLeft,
            child: Text(
              title.toUpperCase(),
              style: AppText.label.copyWith(color: c.textMuted, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final CyberColors c;
  final Widget child;

  const _Card({required this.c, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: const [BoxShadow(color: Colors.transparent)],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final CyberColors c;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: value ? c.positiveSoft : c.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: value ? c.borderActive : c.border,
                ),
              ),
              child: Icon(
                icon,
                size: 16,
                color: value ? c.positive : c.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.micro.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AppText.micro.copyWith(
                      color: c.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: c.positive,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final CyberColors c;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? c.positiveSoft : c.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: selected ? c.borderActive : c.border),
              ),
              child: Icon(
                icon,
                size: 16,
                color: selected ? c.positive : c.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.micro.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AppText.micro.copyWith(
                      color: c.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              size: 18,
              color: selected ? c.positive : c.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
