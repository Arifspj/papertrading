import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:paper_trade/core/api/hnicalls_client.dart';
import 'package:paper_trade/models/market/option_analysis.dart';
import 'package:paper_trade/models/market/option_chain.dart';

/// Captures the real payloads probed from HNICALLS (Sept 2026).
const _analysisJson = '''
{
  "analyzedAt":"2026-09-29T13:39:43.176982",
  "call_oi_chg":0,
  "confidence":"LOW",
  "expiryDate":"2026-09-29",
  "factors":[],
  "instrument":"NIFTY",
  "iv_skew":-0.08,
  "lot_size":65,
  "max_pain":22700,
  "observation":"NIFTY 22700 ATM LTP Rs.340.74 [ATM]",
  "oi_signal":"Bearish",
  "option_type":"NEUTRAL",
  "pcr":0.95,
  "premium":340.74,
  "put_oi_chg":0,
  "resistance":[23150,23600],
  "score":-5,
  "sentiment":"NEUTRAL",
  "sentiment_emoji":"\ud83d\udfe1",
  "source":"fallback_api",
  "spotPrice":22716.2,
  "status":"success",
  "strike":22700,
  "support":[22250,21800]
}
''';

void main() {
  group('OptionAnalysis', () {
    final analysis = OptionAnalysis.fromJson(
      jsonDecode(_analysisJson) as Map<String, dynamic>,
    );

    test('parses the live /analysis payload', () {
      expect(analysis.isSuccess, isTrue);
      expect(analysis.instrument, 'NIFTY');
      expect(analysis.spotPrice, 22716.2);
      expect(analysis.strike, 22700);
      expect(analysis.premium, 340.74);
      expect(analysis.lotSize, 65);
      expect(analysis.pcr, 0.95);
      expect(analysis.maxPain, 22700);
      expect(analysis.ivSkew, -0.08);
      expect(analysis.sentiment, 'NEUTRAL');
      expect(analysis.oiSignal, 'Bearish');
      expect(analysis.expiryDate, DateTime(2026, 9, 29));
      expect(analysis.support, [22250.0, 21800.0]);
      expect(analysis.resistance, [23150.0, 23600.0]);
      expect(analysis.factors, isEmpty);
    });

    test('exposes the ATM option as a live-quote symbol', () {
      final atm = analysis.atmOption;
      expect(atm, isNotNull);
      expect(atm!.symbol, 'NIFTY 22700');
      expect(atm.ltp, 340.74);
    });

    test('maps option_type CALL / PUT to CE / PE', () {
      final call = OptionAnalysis.fromJson({
        'status': 'success',
        'instrument': 'NIFTY',
        'strike': 22700,
        'premium': 340.74,
        'option_type': 'CALL',
      }).atmOption;
      final put = OptionAnalysis.fromJson({
        'status': 'success',
        'instrument': 'NIFTY',
        'strike': 22700,
        'premium': 340.74,
        'option_type': 'PUT',
      }).atmOption;
      expect(call!.symbol, 'NIFTY 22700 CE');
      expect(put!.symbol, 'NIFTY 22700 PE');
    });

    test('tolerates a minimal payload', () {
      final a = OptionAnalysis.fromJson({'status': 'success'});
      expect(a.isSuccess, isTrue);
      expect(a.spotPrice, 0);
      expect(a.atmOption, isNull);
    });
  });

  group('OptionChain', () {
    Map<String, dynamic> chain({String shape = 'list'}) {
      final rows = [
        {
          'STRIKE': 22800,
          'CALL_LTP': 120.5,
          'PUT_LTP': 640.25,
          'CALL_OI': 120000,
          'PUT_OI': 95000,
          'CALL_IV': 14.2,
          'PUT_IV': 15.9,
        },
        {
          'STRIKE': 22700,
          'CALL_LTP': 340.74,
          'PUT_LTP': 340.74,
          'CALL_OI': 210000,
          'PUT_OI': 199500,
          'CALL_IV': 14.0,
          'PUT_IV': 14.0,
        },
        {
          'STRIKE': 22600,
          'CALL_LTP': 520.0,
          'PUT_LTP': 190.0,
          'CALL_OI': 80000,
          'PUT_OI': 140000,
          'CALL_IV': 13.4,
          'PUT_IV': 14.6,
        },
      ];
      return {
        'status': 'success',
        'spot_price': 22716.2,
        'expiry': '2026-09-29',
        'data': shape == 'list' ? rows : {'data': rows},
      };
    }

    test('parses the list form and sorts by strike', () {
      final c = OptionChain.fromJson(chain());
      expect(c.isSuccess, isTrue);
      expect(c.isEmpty, isFalse);
      expect(c.rows.map((r) => r.strike), [22600, 22700, 22800]);
      expect(c.rows[1].callLtp, 340.74);
      expect(c.spotPrice, 22716.2);
    });

    test('parses the wrapped-map form', () {
      final c = OptionChain.fromJson(chain(shape: 'map'));
      expect(c.rows.length, 3);
    });

    test('derives ATM, PCR, max pain and IV skew', () {
      final c = OptionChain.fromJson(chain());
      expect(c.atmRow?.strike, 22700);
      expect(c.totalCallOi, 410000);
      expect(c.totalPutOi, 434500);
      expect(c.pcr, closeTo(1.0598, 0.0001));
      expect(c.ivSkew, closeTo(0.0, 0.0001));
    });

    test('finds the LTP of a tracked contract', () {
      final c = OptionChain.fromJson(chain());
      expect(c.ltpFor(22600, isCall: true), 520.0);
      expect(c.ltpFor(22600, isCall: false), 190.0);
      expect(c.ltpFor(99999, isCall: true), isNull);
      expect(c.rowFor(22800)?.putOi, 95000);
    });

    test('handles an empty chain', () {
      final c = OptionChain.fromJson({'status': 'success', 'data': []});
      expect(c.isEmpty, isTrue);
      expect(c.atmRow, isNull);
      expect(c.pcr, 0);
    });
  });

  group('json coercion', () {
    test('reads strings and comma-formatted numbers', () {
      final c = OptionChain.fromJson({
        'status': 'success',
        'spot_price': '22,716.20',
        'data': [
          {
            'strike': '22700',
            'CALL_LTP': '340.74',
            'PUT_LTP': 190.5,
          }
        ],
      });
      expect(c.spotPrice, 22716.2);
      expect(c.rows.single.strike, 22700);
      expect(c.rows.single.callLtp, 340.74);
    });
  });

  group('HnicallsException', () {
    test('surfaces the upstream status and body', () {
      final e = HnicallsException('boom', statusCode: 500, url: 'https://x');
      expect(e.toString(), contains('500'));
      expect(e.toString(), contains('boom'));
    });
  });
}
