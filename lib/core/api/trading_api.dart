import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/position.dart';
import 'api_config.dart';

/// Thrown for any backend communication failure.
class TradingApiException implements Exception {
  final String message;
  final int? statusCode;

  const TradingApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode == null ? message : '[$statusCode] $message';
}

/// Low-level HTTP client for the paper-trading backend.
///
/// Currently only wired to the positions endpoints. Add methods here as the
/// API gets extended (orders, watchlist, account, etc).
class TradingApi {
  final http.Client _client;
  final String _baseUrl;

  TradingApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Map<String, String> get _headers {
    final h = Map<String, String>.from(ApiConfig.headers);
    if (ApiConfig.authToken.isNotEmpty) {
      h['Authorization'] = 'Bearer ${ApiConfig.authToken}';
    }
    return h;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  Future<List<Position>> fetchPositions() async {
    final res = await _client
        .get(_uri('/positions'), headers: _headers)
        .timeout(ApiConfig.timeout);
    final body = _decode(res);
    final list = body['positions'] as List<dynamic>? ?? body as List<dynamic>;
    return list
        .map((e) => Position.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PortfolioSummary> fetchPortfolio() async {
    final res = await _client
        .get(_uri('/portfolio'), headers: _headers)
        .timeout(ApiConfig.timeout);
    final body = _decode(res);
    return PortfolioSummary(
      totalPnl: (body['totalPnl'] as num?)?.toDouble() ?? 0,
      openPositions: (body['openPositions'] as num?)?.toInt() ?? 0,
      longPositions: (body['longPositions'] as num?)?.toInt() ?? 0,
      shortPositions: (body['shortPositions'] as num?)?.toInt() ?? 0,
      winPositions: (body['winPositions'] as num?)?.toInt() ?? 0,
      lossPositions: (body['lossPositions'] as num?)?.toInt() ?? 0,
    );
  }

  /// Square off (close) a position.
  Future<void> squareOff(String symbol) async {
    final res = await _client
        .delete(_uri('/positions/$symbol'), headers: _headers)
        .timeout(ApiConfig.timeout);
    _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TradingApiException(
        'Server returned ${res.statusCode}: ${res.body}',
        statusCode: res.statusCode,
      );
    }
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const TradingApiException('Malformed JSON from server');
    }
  }
}