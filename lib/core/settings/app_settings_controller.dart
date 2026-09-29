import 'package:flutter/foundation.dart';

/// User-facing app preferences that are not part of the trading theme.
///
/// Kept in memory (like [ThemeController]) so the app has no persistence
/// dependency; the trade-off is that the flag resets on a cold start.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({bool tickerEnabled = true})
      : _tickerEnabled = tickerEnabled;

  bool _tickerEnabled;

  /// Show the scrolling market ticker under the app header.
  bool get tickerEnabled => _tickerEnabled;

  set tickerEnabled(bool value) {
    if (_tickerEnabled == value) return;
    _tickerEnabled = value;
    notifyListeners();
  }

  void toggleTicker() => tickerEnabled = !_tickerEnabled;
}
