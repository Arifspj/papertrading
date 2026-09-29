import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'hnicalls_config.dart';
import 'json_utils.dart';
import '../../models/market/live_quote.dart';
import '../../models/market/option_analysis.dart';
import '../../models/market/option_chain.dart';

/// Thrown when HNICALLS answers with a non-2xx status or an unparsable body.
class HnicallsException implements Exception {
  final int? statusCode;
  final String message;
  final String? url;

  const HnicallsException(this.message, {this.statusCode, this.url});

  @override
  String toString() =>
      'HnicallsException($statusCode): $message${url == null ? '' : ' <- $url'}';
}

/// Thin, dependency-light client for the HNICALLS market-data API.
///
/// Verified live (Sept 2026): `/analysis/{instrument}`, `/observation/`,
/// `/ticker_app`. `/option-chain/*` and `/ltp/*` are implemented because they
/// exist, but currently answer `500` upstream — the stream treats those as
/// "unavailable" instead of failing hard.
class HnicallsClient {
  HnicallsClient({http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  void close() => _client.close();

  Uri _uri(String base, String path, [Map<String, String>? query]) {
    final cleaned = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$base/$cleaned').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    Duration? timeout,
  }) async {
    final res = await _client
        .get(uri, headers: HnicallsApiConfig.authHeaders)
        .timeout(timeout ?? this.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HnicallsException(
        res.body.isEmpty ? 'request failed' : res.body,
        statusCode: res.statusCode,
        url: '$uri',
      );
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw HnicallsException('unexpected body shape', url: '$uri');
  }

  Future<List<dynamic>> _getJsonList(Uri uri, {Duration? timeout}) async {
    final res = await _client
        .get(uri, headers: HnicallsApiConfig.authHeaders)
        .timeout(timeout ?? this.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HnicallsException(
        res.body.isEmpty ? 'request failed' : res.body,
        statusCode: res.statusCode,
        url: '$uri',
      );
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is List) return decoded;
    if (decoded is Map) return [decoded];
    throw HnicallsException('unexpected body shape', url: '$uri');
  }

  // ---------------------------------------------------------------- market

  /// `GET /api/analysis/{instrument}[?type=monthly]`
  Future<OptionAnalysis> fetchAnalysis(
    String instrument, {
    HnExpiryType expiry = HnExpiryType.weekly,
    bool lowercase = false,
  }) async {
    final symbol = lowercase ? instrument.toLowerCase() : instrument.toUpperCase();
    final uri = _uri(
      HnicallsApiConfig.marketBase,
      'analysis/$symbol',
      expiry == HnExpiryType.monthly ? {'type': 'monthly'} : null,
    );
    return OptionAnalysis.fromJson(await _getJson(uri));
  }

  /// `GET /api/option-chain/{instrument}[?type=monthly]`
  ///
  /// The instrument must be **lower-case** — the upstream route is
  /// case-sensitive (`/option-chain/NIFTY` fails).
  Future<OptionChain> fetchOptionChain(
    String instrument, {
    HnExpiryType expiry = HnExpiryType.weekly,
  }) async {
    final uri = _uri(
      HnicallsApiConfig.marketBase,
      'option-chain/${instrument.toLowerCase()}',
      expiry == HnExpiryType.monthly ? {'type': 'monthly'} : null,
    );
    return OptionChain.fromJson(await _getJson(uri, timeout: const Duration(seconds: 20)));
  }

  /// `GET /api/ltp/{instrument}/{strike}/{CE|PE}` (weekly)
  /// `GET /api/ltp/{instrument}/monthly/{strike}/{CE|PE}` (monthly)
  ///
  /// Used as a fallback when the whole option chain is unavailable. The
  /// upstream route is case-insensitive, but lower-case matches the documented
  /// form and the `/option-chain/*` sibling route.
  Future<double?> fetchOptionLtp(
    String instrument,
    int strike,
    String optionType, {
    HnExpiryType expiry = HnExpiryType.weekly,
  }) async {
    final segment = optionType.toLowerCase();
    final path = expiry == HnExpiryType.monthly
        ? 'ltp/${instrument.toLowerCase()}/monthly/$strike/$segment'
        : 'ltp/${instrument.toLowerCase()}/$strike/$segment';
    final json = await _getJson(
      _uri(HnicallsApiConfig.marketBase, path),
      timeout: const Duration(seconds: 8),
    );
    // Upstream has been seen to answer `ltp`, `premium` or `LTP`.
    return asDouble(json['ltp'] ?? json['premium'] ?? json['LTP']);
  }

  /// `GET /api/observation/` — free-form text feed, e.g.
  /// `"NIFTY 22700 ATM LTP Rs.340.74 [ATM]"`.
  Future<List<String>> fetchObservations() async {
    final list = await _getJsonList(
      _uri(HnicallsApiConfig.marketBase, 'observation/'),
    );
    return list
        .whereType<Map>()
        .map((e) => asString(e['observation']))
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  // ---------------------------------------------------------------- public

  /// `GET /api/public/api/ticker_app` — index quotes + movers.
  Future<List<LiveQuote>> fetchIndexQuotes() async {
    final json = await _getJson(_uri(HnicallsApiConfig.publicBase, 'ticker_app'));
    final now = DateTime.now();
    final quotes = <LiveQuote>[];
    for (final key in const ['smallList', 'moversList']) {
      final rows = json[key];
      if (rows is! List) continue;
      for (final row in rows.whereType<Map>()) {
        final symbol = asString(row['symbol']);
        final ltp = asDoubleOr(row['ltp'], 0);
        if (symbol.isEmpty || ltp == 0) continue;
        quotes.add(
          LiveQuote(
            symbol: symbol,
            instrument: symbol,
            ltp: ltp,
            change: ltp - asDoubleOr(row['prev_close'], ltp),
            changePct: asDoubleOr(row['pct_change'], 0),
            at: DateTime.tryParse(asString(json['updated'])) ?? now,
            source: kTickerQuoteSource,
          ),
        );
      }
    }
    return quotes;
  }

  /// `GET /api/public/api/obs` — same text feed as `/observation/`.
  Future<List<String>> fetchPublicObservations() async {
    final list = await _getJsonList(_uri(HnicallsApiConfig.publicBase, 'obs'));
    return list
        .whereType<Map>()
        .map((e) => asString(e['observation']))
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// `GET /api/public/api/btst` — buy-tomorrow short-term calls.
  Future<List<Map<String, dynamic>>> fetchBtst() async {
    final list = await _getJsonList(_uri(HnicallsApiConfig.publicBase, 'btst'));
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// `GET /api/public/api/future` — futures calls.
  Future<List<Map<String, dynamic>>> fetchFutures() async {
    final list = await _getJsonList(_uri(HnicallsApiConfig.publicBase, 'future'));
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// `GET /api/public/api/multibagger` — stock picks.
  Future<List<Map<String, dynamic>>> fetchMultibagger() async {
    final list = await _getJsonList(
      _uri(HnicallsApiConfig.publicBase, 'multibagger'),
    );
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// `GET /api/public/api/ipos`
  Future<Map<String, dynamic>> fetchIpos() async {
    final json = await _getJson(_uri(HnicallsApiConfig.publicBase, 'ipos'));
    return json['stocks'] is List
        ? {'stocks': json['stocks']}
        : json;
  }
}
