/// Runtime configuration for the HNICALLS market-data API.
///
/// Every value can be overridden at build time, e.g.
///   flutter run --dart-define=HNICALLS_API_BASE=https://api.hnicalls.com/api
///   flutter run --dart-define=HNICALLS_PUBLIC_BASE=https://hnicalls.com/api/public/api
///   flutter run --dart-define=HNICALLS_WS_URL=wss://api.hnicalls.com/ws/v1
///
/// The market API is public and needs **no API key / no auth header**. If you
/// later get a key, put it in `HnicallsApiConfig.authHeaders` and it will be
/// attached to every request.
class HnicallsApiConfig {
  const HnicallsApiConfig._();

  /// Direct market API: analysis, option-chain, ltp, observation.
  static const String marketBase = String.fromEnvironment(
    'HNICALLS_API_BASE',
    defaultValue: 'https://api.hnicalls.com/api',
  );

  /// Public app API: ticker, obs, btst, future, multibagger, ipos.
  static const String publicBase = String.fromEnvironment(
    'HNICALLS_PUBLIC_BASE',
    defaultValue: 'https://hnicalls.com/api/public/api',
  );

  /// WebSocket endpoint, opt-in only.
  ///
  /// HNICALLS' marketing page advertises `wss://api.hnicalls.com/ws/v1` but it
  /// answers `404` (probed Sept 2026), so it is **empty by default** and the
  /// app goes straight to HTTP polling. Pass
  /// `--dart-define=HNICALLS_WS_URL=wss://...` to try a real server.
  static const String wsUrl = String.fromEnvironment('HNICALLS_WS_URL');

  /// Optional bearer token. Empty by default (public endpoints need none).
  static const String apiKey = String.fromEnvironment('HNICALLS_API_KEY');

  static Map<String, String> get authHeaders => {
        'Accept': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        if (apiKey.isNotEmpty) 'x-api-key': apiKey,
      };

  /// Index instruments that have weekly expiries.
  static const Set<String> indexInstruments = {
    'NIFTY',
    'BANKNIFTY',
    'FINNIFTY',
    'SENSEX',
  };

  /// Stocks traded in the F&O segment (no weekly expiry -> always monthly).
  static const List<String> fnoStocks = [
    'ANGELONE',
    'COFORGE',
    'KPITTECH',
    'ASTRAL',
  ];

  static bool isKnownInstrument(String instrument) =>
      indexInstruments.contains(instrument.toUpperCase()) ||
      fnoStocks.contains(instrument.toUpperCase());
}

/// Which expiry class to request. HNICALLS has no date-based expiry selector,
/// so this is the only knob (`?type=monthly`).
enum HnExpiryType { weekly, monthly }

extension HnExpiryTypeX on HnExpiryType {
  /// `null` for weekly: the API then returns the nearest weekly expiry, which
  /// is what the index clients rely on.
  String? get query => this == HnExpiryType.monthly ? '?type=monthly' : null;
}
