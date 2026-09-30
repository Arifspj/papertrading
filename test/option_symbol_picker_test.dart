import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paper_trade/core/api/hnicalls_client.dart';
import 'package:paper_trade/core/utils/symbol_formatter.dart';
import 'package:paper_trade/models/market/option_analysis.dart';
import 'package:paper_trade/models/market/option_ladder.dart';
import 'package:paper_trade/services/live/option_symbol_service.dart';

void main() {
  group('SymbolParts.expiryStamp', () {
    test('resolves a future month/day in the same year', () {
      final parts = SymbolParts.parse('NIFTY 01st OCT 22600 CE');
      expect(parts.expiryStamp(now: DateTime(2026, 9, 30)), '2026-10-01');
    });

    test('rolls to next year when the day has already passed', () {
      // Same month/day pair every year, so an already-gone expiry has to move
      // forward rather than resolve to a date in the past.
      final parts = SymbolParts.parse('NIFTY 01st OCT 22600 CE');
      expect(parts.expiryStamp(now: DateTime(2026, 10, 2)), '2027-10-01');
    });

    test('treats the expiry day itself as still valid', () {
      final parts = SymbolParts.parse('SENSEX 01st OCT 72900 PE');
      expect(parts.expiryStamp(now: DateTime(2026, 10, 1)), '2026-10-01');
    });

    test('reads the day with an ordinal suffix and the month upper-cased', () {
      final parts = SymbolParts.parse('NIFTY 25th NOV 22700 CE');
      expect(parts.expiryStamp(now: DateTime(2026, 9, 30)), '2026-11-25');
    });

    test('is null when the symbol carries no expiry', () {
      expect(SymbolParts.parse('NIFTY 22600 CE').expiryStamp(), isNull);
    });

    test('is null for an unknown month', () {
      final parts = SymbolParts.parse('NIFTY 01st FOO 22600 CE');
      expect(parts.expiryStamp(), isNull);
    });
  });

  group('OptionAnalysis.atmOption', () {
    OptionAnalysis build(String type) => OptionAnalysis(
          status: 'success',
          instrument: 'NIFTY',
          strike: 22600,
          premium: 339.31,
          optionType: type,
        );

    test('is null for a NEUTRAL side instead of guessing CE or PE', () {
      // Upstream answers NEUTRAL most of the time. A premium cannot be keyed
      // on a contract without a side, and picking one prices the wrong leg.
      expect(build('NEUTRAL').atmOption, isNull);
    });

    test('is null for an unrecognised side', () {
      expect(build('').atmOption, isNull);
    });

    test('emits a typed symbol when the side is known', () {
      final call = build('CALL').atmOption;
      expect(call!.symbol, 'NIFTY 22600 CE');
      expect(call.ltp, 339.31);
      expect(build('PUT').atmOption!.symbol, 'NIFTY 22600 PE');
    });

    test('does not report premium minus strike as a change', () {
      // 339.31 - 22600 is -22260, which is not a change in anything.
      final atm = build('CALL').atmOption!;
      expect(atm.change, 0);
      expect(atm.changePct, 0);
    });
  });

  group('OptionLadder', () {
    test('strikes snap to the step grid either side of the ATM', () {
      final strikes = OptionLadder.strikesAround(22620, 50);
      expect(strikes.length, 11);
      expect(strikes.first, 22350);
      expect(strikes.last, 22850);
      expect(strikes, contains(22600));
    });

    test('uses the per-index step', () {
      // SENSEX gaps by 100, NIFTY by 50, so the same ±5 span covers a wider
      // band on SENSEX.
      expect(
        OptionLadder.strikesAroundFor('SENSEX', 72480),
        contains(72500),
      );
      expect(
        OptionLadder.strikesAroundFor('SENSEX', 72480).last,
        73000,
      );
      expect(
        OptionLadder.strikesAroundFor('NIFTY', 22620).last,
        22850,
      );
    });

    test('returns nothing for a non-positive ATM or step', () {
      expect(OptionLadder.strikesAround(0, 50), isEmpty);
      expect(OptionLadder.strikesAround(22600, 0), isEmpty);
    });

    test('ATM ladder symbols carry the expiry tokens', () {
      final ladder = OptionLadder.aroundAtm(
        instrument: 'nifty',
        atmStrike: 22600,
        expiry: DateTime(2026, 10, 1),
      );
      expect(ladder.source, OptionLadderSource.atmLadder);
      expect(ladder.isEmpty, isFalse);
      expect(ladder.hasPrices, isFalse);
      expect(
        ladder.contracts.map((c) => c.symbol),
        contains('NIFTY 01st OCT 22600 CE'),
      );
    });

    test('ATM ladder still parses to the canonical API symbol', () {
      // The whole point of the expiry tokens: a symbol added from the picker
      // has to match the key the live poller quotes under.
      final ladder = OptionLadder.aroundAtm(
        instrument: 'SENSEX',
        atmStrike: 72500,
        expiry: DateTime(2026, 10, 1),
      );
      for (final c in ladder.contracts) {
        final parts = SymbolParts.parse(c.symbol);
        expect(parts.underlying, 'SENSEX');
        expect(parts.strikeValue, isNotNull);
        expect(parts.instrumentType, c.optionType);
        expect(parts.apiSymbol, endsWith('${c.strike} ${c.optionType}'));
        expect(c.symbol.endsWith(' ${c.optionType}'), isTrue);
      }
      expect(
        ladder.contracts.map((c) => c.symbol).toSet().length,
        ladder.contracts.length,
        reason: 'every contract symbol is distinct',
      );
    });

    test('renders a 1st, 2nd, 3rd and 11th-31st suffix', () {
      for (final d in const [1, 2, 3, 11, 21, 31]) {
        final day = d.toString().padLeft(2, '0');
        expect(
          OptionLadder.symbolFor('NIFTY', DateTime(2026, 10, d), 22600, true),
          'NIFTY $day${SymbolParts.ordinalSuffix(d)} OCT 22600 CE',
        );
      }
    });

    test('falls back to a month-less symbol with no expiry', () {
      expect(
        OptionLadder.symbolFor('NIFTY', null, 22600, false),
        'NIFTY 22600 PE',
      );
    });
  });

  group('index LTP key match', () {
    // The watchlist and position cards resolve a live quote through
    // `quoteFor(SymbolParts.parse(symbol).apiSymbol)`, and the ticker feed keys
    // on the bare uppercase index name. These have to line up exactly or an
    // index row silently keeps its seeded price forever.
    test('a bare index symbol keys the same as the ticker feed', () {
      expect(SymbolParts.parse('NIFTY').apiSymbol, 'NIFTY');
      expect(SymbolParts.parse('SENSEX').apiSymbol, 'SENSEX');
      expect(SymbolParts.parse('BANKNIFTY').apiSymbol, 'BANKNIFTY');
    });

    test('a generated contract keys the same as the LTP route', () {
      // `SENSEX 01st OCT 72900 PE` -> `SENSEX 72900 PE`, which is the path the
      // `/ltp/sensex/72900/pe` route is called for.
      final parts = SymbolParts.parse('SENSEX 01st OCT 72900 PE');
      expect(parts.apiSymbol, 'SENSEX 72900 PE');
      expect(parts.apiInstrument, 'SENSEX');
      expect(parts.apiOptionType, 'PE');
      expect(parts.strikeValue, 72900);
    });

    test('every generated ladder contract keys uniquely', () {
      final ladder = OptionLadder.aroundAtm(
        instrument: 'NIFTY',
        atmStrike: 22600,
        expiry: DateTime(2026, 10, 1),
      );
      final keys = ladder.contracts
          .map((c) => SymbolParts.parse(c.symbol).apiSymbol)
          .toList();
      expect(keys.toSet().length, keys.length);
      expect(keys, contains('NIFTY 22600 CE'));
      expect(keys, contains('NIFTY 22600 PE'));
    });
  });

  group('OptionSymbolService', () {
    /// Serves the chain from [chainBody] and the analysis from a fixed ATM.
    HnicallsClient clientWhere({
      required String chainBody,
      int chainStatus = 200,
    }) {
      return HnicallsClient(
        client: MockClient((req) async {
          if (req.url.path.contains('/option-chain/')) {
            return http.Response(chainBody, chainStatus);
          }
          if (req.url.path.contains('/analysis/')) {
            return http.Response(
              '{"status":"success","instrument":"${req.url.pathSegments.last}",'
              '"spotPrice":22620.45,"strike":22600,"premium":339.31,'
              '"optionType":"NEUTRAL","expiryDate":"2026-09-30",'
              '"lotSize":65,"atmRow":null}',
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
    }

    test('prefers the real chain and carries its premiums', () async {
      final service = OptionSymbolService(
        client: clientWhere(
          chainBody: '''
          {"status":"success","spot_price":22620.45,"expiry":"2026-10-01",
           "expiry_type":"WEEKLY","lot_size":65,
           "data":[
             {"STRIKE":22600,"CALL_LTP":339.31,"CALL_OI":1200,
              "PUT_LTP":310.5,"PUT_OI":900},
             {"STRIKE":22700,"CALL_LTP":210.0,"CALL_OI":800,
              "PUT_LTP":250.0,"PUT_OI":700}
           ]}
          ''',
        ),
      );
      final ladder = await service.load('NIFTY');
      expect(ladder.source, OptionLadderSource.chain);
      expect(ladder.hasPrices, isTrue);
      expect(ladder.spotPrice, 22620.45);
      expect(ladder.contracts.length, 4);
      expect(
        ladder.contracts.map((c) => c.symbol),
        containsAll(<String>[
          'NIFTY 01st OCT 22600 CE',
          'NIFTY 01st OCT 22600 PE',
          'NIFTY 01st OCT 22700 CE',
          'NIFTY 01st OCT 22700 PE',
        ]),
      );
      // Premiums come off the matching leg, not swapped.
      final call = ladder.contracts
          .firstWhere((c) => c.symbol == 'NIFTY 01st OCT 22600 CE');
      final put = ladder.contracts
          .firstWhere((c) => c.symbol == 'NIFTY 01st OCT 22600 PE');
      expect(call.ltp, 339.31);
      expect(put.ltp, 310.5);
    });

    test('falls back to an ATM ladder when the chain 500s', () async {
      // The chain route is the one that breaks upstream; analysis keeps
      // answering, so the picker still offers addable contracts.
      final service = OptionSymbolService(
        client: clientWhere(
          chainBody: '{"error":"Failed to fetch option chain from Upstox"}',
          chainStatus: 500,
        ),
      );
      final ladder = await service.load('NIFTY');
      expect(ladder.source, OptionLadderSource.atmLadder);
      expect(ladder.atmStrike, 22600);
      expect(ladder.spotPrice, 22620.45);
      expect(ladder.contracts, isNotEmpty);
      expect(ladder.hasPrices, isFalse);
      // The fallback is built from the analysis expiry, so the symbols still
      // line up with the contract the poller will quote.
      expect(
        ladder.contracts.map((c) => c.symbol),
        contains('NIFTY 30th SEP 22600 CE'),
      );
    });

    test('falls back when the chain route is missing entirely', () async {
      final service = OptionSymbolService(
        client: HnicallsClient(
          client: MockClient((req) async {
            if (req.url.path.contains('/analysis/')) {
              return http.Response(
                '{"status":"success","instrument":"SENSEX",'
                '"spotPrice":72480.29,"strike":72500,"premium":1087.2,'
                '"optionType":"NEUTRAL","expiryDate":"2026-09-30",'
                '"lotSize":20,"atmRow":null}',
                200,
              );
            }
            return http.Response('Not Found', 404);
          }),
        ),
      );
      final ladder = await service.load('SENSEX');
      expect(ladder.source, OptionLadderSource.atmLadder);
      expect(ladder.instrument, 'SENSEX');
      expect(
        ladder.contracts.map((c) => c.symbol),
        contains('SENSEX 30th SEP 72500 CE'),
      );
    });

    test('an empty ladder when neither route can price anything', () async {
      final service = OptionSymbolService(
        client: HnicallsClient(
          client: MockClient((_) async => http.Response('{}', 500)),
        ),
      );
      final ladder = await service.load('NIFTY');
      expect(ladder.isEmpty, isTrue);
    });

    test('an empty chain body is not treated as a real ladder', () async {
      final service = OptionSymbolService(
        client: clientWhere(
          chainBody: '{"status":"success","data":[]}',
        ),
      );
      final ladder = await service.load('NIFTY');
      expect(ladder.source, OptionLadderSource.atmLadder);
    });

    test('only offers instruments upstream knows', () {
      final service = OptionSymbolService(
        client: clientWhere(chainBody: '{}'),
        instruments: const ['NIFTY', 'SENSEX', 'NOT_AN_INDEX'],
      );
      expect(service.supportedInstruments, const ['NIFTY', 'SENSEX']);
    });
  });
}
