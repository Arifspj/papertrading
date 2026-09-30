import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:paper_trade/core/icons/lucide_icons.dart';

/// The glyphs are declared in-project rather than imported from
/// `lucide_icons_flutter`, whose single 13 MB `const` table is what used to
/// overflow the web debug compiler and kill hot reload. That makes these
/// values hand-maintained, so they need a guard: a duplicated or edited
/// codepoint does not fail to build, it silently renders the wrong icon.
void main() {
  final icons = <String, IconData>{
    'activity': LucideIcons.activity,
    'bookmark': LucideIcons.bookmark,
    'briefcase': LucideIcons.briefcase,
    'chartNoAxesColumnIncreasing': LucideIcons.chartNoAxesColumnIncreasing,
    'check': LucideIcons.check,
    'checkCircle2': LucideIcons.checkCircle2,
    'chevronDown': LucideIcons.chevronDown,
    'chevronLeft': LucideIcons.chevronLeft,
    'chevronRight': LucideIcons.chevronRight,
    'chevronUp': LucideIcons.chevronUp,
    'circle': LucideIcons.circle,
    'circleAlert': LucideIcons.circleAlert,
    'circleX': LucideIcons.circleX,
    'cpu': LucideIcons.cpu,
    'ellipsisVertical': LucideIcons.ellipsisVertical,
    'fileText': LucideIcons.fileText,
    'inbox': LucideIcons.inbox,
    'info': LucideIcons.info,
    'link': LucideIcons.link,
    'loader2': LucideIcons.loader2,
    'moon': LucideIcons.moon,
    'palette': LucideIcons.palette,
    'pencil': LucideIcons.pencil,
    'plus': LucideIcons.plus,
    'refreshCw': LucideIcons.refreshCw,
    'search': LucideIcons.search,
    'settings': LucideIcons.settings,
    'slidersHorizontal': LucideIcons.slidersHorizontal,
    'sun': LucideIcons.sun,
    'user': LucideIcons.user,
    'wifiOff': LucideIcons.wifiOff,
    'x': LucideIcons.x,
  };

  test('every icon resolves against the bundled Lucide font', () {
    for (final e in icons.entries) {
      expect(e.value.fontFamily, 'Lucide', reason: e.key);
      expect(e.value.fontPackage, isNull, reason: '${e.key} must not be resolved '
          'through the dropped package');
      // Lucide keeps its glyphs in the private use area. Anything outside it
      // is a transcription slip, not an icon.
      expect(
        e.value.codePoint,
        inInclusiveRange(0xE000, 0xF8FF),
        reason: '${e.key} is outside the private use area',
      );
    }
  });

  test('no two icons share a codepoint', () {
    final seen = <int, String>{};
    for (final e in icons.entries) {
      final clash = seen[e.value.codePoint];
      expect(clash, isNull,
          reason: '${e.key} and $clash both map to '
              '0x${e.value.codePoint.toRadixString(16)}');
      seen[e.value.codePoint] = e.key;
    }
    expect(seen.length, icons.length);
  });

  test('the set is exactly the icons the app uses', () {
    // If a screen starts using a new glyph, add it here in the same change,
    // otherwise it will be missing from the font check.
    expect(icons.length, 32);
  });
}
