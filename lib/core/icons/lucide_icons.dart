import 'package:flutter/widgets.dart';

/// The Lucide glyphs this app uses, declared here instead of pulled from
/// `lucide_icons_flutter`.
///
/// That package ships every icon in the set as one `const` table in a single
/// ~13 MB `lucide_icons.dart`. The web debug compiler has to initialise the
/// whole table, and it does so lazily on first use, which is why a hot reload
/// could blow the stack and take the Dart compiler down with it. The font
/// itself is only ~0.85 MB, so the glyphs are cheap; the Dart table was the
/// entire cost.
///
/// Codepoints and the `Lucide` family name match the package exactly, and
/// `assets/fonts/lucide.ttf` is the same file it shipped, so every icon renders
/// identically. Adding an icon means adding its codepoint here, in decimal to
/// match upstream and stay diffable against it.
abstract final class LucideIcons {
  static const IconData activity = IconData(57400, fontFamily: 'Lucide');
  static const IconData bookmark = IconData(57440, fontFamily: 'Lucide');
  static const IconData briefcase = IconData(57442, fontFamily: 'Lucide');
  static const IconData chartNoAxesColumnIncreasing = IconData(
    57450,
    fontFamily: 'Lucide',
  );
  static const IconData check = IconData(57452, fontFamily: 'Lucide');
  static const IconData checkCircle2 = IconData(57894, fontFamily: 'Lucide');
  static const IconData chevronDown = IconData(57453, fontFamily: 'Lucide');
  static const IconData chevronLeft = IconData(57454, fontFamily: 'Lucide');
  static const IconData chevronRight = IconData(57455, fontFamily: 'Lucide');
  static const IconData chevronUp = IconData(57456, fontFamily: 'Lucide');
  static const IconData circle = IconData(57462, fontFamily: 'Lucide');
  static const IconData circleAlert = IconData(57463, fontFamily: 'Lucide');
  static const IconData circleX = IconData(57476, fontFamily: 'Lucide');
  static const IconData cpu = IconData(57513, fontFamily: 'Lucide');
  static const IconData ellipsisVertical = IconData(57527, fontFamily: 'Lucide');
  static const IconData fileText = IconData(57548, fontFamily: 'Lucide');
  static const IconData inbox = IconData(57591, fontFamily: 'Lucide');
  static const IconData info = IconData(57593, fontFamily: 'Lucide');
  static const IconData link = IconData(57602, fontFamily: 'Lucide');
  static const IconData loader2 = IconData(57610, fontFamily: 'Lucide');
  static const IconData moon = IconData(57630, fontFamily: 'Lucide');
  static const IconData palette = IconData(57821, fontFamily: 'Lucide');
  static const IconData pencil = IconData(57849, fontFamily: 'Lucide');
  static const IconData plus = IconData(57661, fontFamily: 'Lucide');
  static const IconData refreshCw = IconData(57669, fontFamily: 'Lucide');
  static const IconData search = IconData(57681, fontFamily: 'Lucide');
  static const IconData settings = IconData(57684, fontFamily: 'Lucide');
  static const IconData slidersHorizontal = IconData(58010, fontFamily: 'Lucide');
  static const IconData sun = IconData(57720, fontFamily: 'Lucide');
  static const IconData user = IconData(57759, fontFamily: 'Lucide');
  static const IconData wifiOff = IconData(57775, fontFamily: 'Lucide');
  static const IconData x = IconData(57778, fontFamily: 'Lucide');
}
