/// Central place for the paper-trading backend config.
///
/// Point this at the real paper-trading API when available, e.g.:
///   flutter run --dart-define=PAPER_TRADE_BASE_URL=https://api.mytrading.com
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'PAPER_TRADE_BASE_URL',
    defaultValue: 'https://paper-trade.example.com/api',
  );

  /// Optional bearer token for authenticated endpoints.
  static const String authToken = String.fromEnvironment('PAPER_TRADE_TOKEN');

  static const Duration timeout = Duration(seconds: 15);
  static const Map<String, String> headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
}