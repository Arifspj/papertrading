import 'package:flutter/material.dart';

/// Controls light / dark / system theming across the app.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode != ThemeMode.light;

  set mode(ThemeMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  void toggle() {
    mode = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}