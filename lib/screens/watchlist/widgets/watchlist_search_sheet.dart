import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/icons/lucide_icons.dart';

import '../../../core/theme/cyber_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/market/option_ladder.dart';
import '../../../models/watchlist.dart';
import '../../../repositories/watchlist_repository.dart';
import '../../../services/live/option_symbol_service.dart';
import '../../../widgets/instrument_title.dart';

const _sheetBg = Color(0xFFF4F6F8);

/// Search-and-add bottom sheet. Live-filters the watchlist symbol catalog and
/// returns the chosen [WatchItem] (already added to the repository).
Future<WatchItem?> showWatchlistSearchSheet(BuildContext context) {
  return showModalBottomSheet<WatchItem>(
    context: context,
    backgroundColor: _sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    isScrollControlled: true,
    builder: (_) => const _SearchSheet(),
  );
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet();

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late final WatchlistRepository _repo;
  late final OptionSymbolService _options;
  final _ctrl = TextEditingController();
  List<WatchItem> _results = const [];

  /// The live option ladder, once an instrument has been picked.
  OptionLadder? _ladder;
  bool _loadingLadder = false;
  String? _ladderError;
  String? _instrument;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WatchlistRepository>();
    _options = context.read<OptionSymbolService>();
    _results = _repo.searchSymbols('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Loads the option ladder for [instrument] and shows it in the results.
  ///
  /// The ladder is shown even when the chain route failed: the ATM fallback
  /// still produces real, addable symbols, and saying so is more useful than an
  /// empty error.
  Future<void> _loadLadder(String instrument) async {
    setState(() {
      _instrument = instrument;
      _loadingLadder = true;
      _ladderError = null;
      _ladder = null;
    });

    OptionLadder ladder;
    try {
      ladder = await _options.load(instrument);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLadder = false;
        _ladderError = 'Could not load $instrument options';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadingLadder = false;
      _ladder = ladder.isEmpty ? null : ladder;
      _ladderError = ladder.isEmpty ? 'No $instrument option contracts found' : null;
    });
  }

  Future<void> _add(WatchItem item) async {
    await _repo.addItem(item);
    if (!mounted) return;
    Navigator.of(context).pop(item);
  }

  /// The ladder as addable rows, highest strike first with each call/put pair
  /// kept adjacent, so the strikes nearest the top are one tap away.
  List<WatchItem> _ladderRows(OptionLadder ladder) {
    final contracts = [...ladder.contracts]
      ..sort((a, b) {
        final byStrike = b.strike.compareTo(a.strike);
        return byStrike != 0 ? byStrike : (a.isCall ? -1 : 1);
      });
    return [
      for (final c in contracts)
        WatchItem(
          symbol: c.symbol,
          lastPrice: c.ltp,
          change: 0,
          changePct: 0,
          segment: ladder.instrument == 'SENSEX' ? 'BFO' : 'NFO',
        ),
    ];
  }

  /// Ladder rows first, then the static catalog.
  ///
  /// A row already in the catalog is dropped from the ladder side so the same
  /// contract is never offered twice.
  List<WatchItem> _visible() {
    final q = _ctrl.text.trim().toLowerCase();
    final out = <WatchItem>[];
    final seen = <String>{};
    if (_ladder != null) {
      for (final row in _ladderRows(_ladder!)) {
        if (q.isNotEmpty && !row.symbol.toLowerCase().contains(q)) continue;
        if (seen.add(row.symbol)) out.add(row);
      }
    }
    for (final row in _results) {
      if (seen.add(row.symbol)) out.add(row);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final rows = _visible();
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TradePalette.slate200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Text(
                'Search & add',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: TradePalette.slate900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) =>
                    setState(() => _results = _repo.searchSymbols(v)),
                style: const TextStyle(
                  fontSize: 14,
                  color: TradePalette.slate900,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. infy, nifty, weekly otm',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: TradePalette.slate400,
                  ),
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    size: 18,
                    color: TradePalette.slate400,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: TradePalette.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: TradePalette.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _InstrumentPicker(
              instruments: _options.supportedInstruments,
              selected: _instrument,
              onSelect: _loadLadder,
            ),
            if (_loadingLadder)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_ladderError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  _ladderError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: TradePalette.slate500,
                  ),
                ),
              )
            else if (_ladder != null)
              _LadderHeader(ladder: _ladder!),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        _loadingLadder ? 'Loading options…' : 'No symbols found',
                        style: TextStyle(
                          fontSize: 13,
                          color: TradePalette.slate400,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, i) => const Divider(
                        color: TradePalette.slate100,
                        height: 1,
                      ),
                      itemBuilder: (context, i) {
                        final item = rows[i];
                        return _ResultRow(
                          item: item,
                          added: _repo.isAdded(item.symbol),
                          onAdd: () => _add(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstrumentPicker extends StatelessWidget {
  final List<String> instruments;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _InstrumentPicker({
    required this.instruments,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: instruments.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final name = instruments[i];
          final active = name == selected;
          return InkWell(
            // Keyed so a tap is unambiguous: the ladder header repeats the
            // instrument name as plain text right below this row.
            key: ValueKey('ladder-instrument-$name'),
            onTap: () => onSelect(name),
            borderRadius: BorderRadius.circular(17),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? TradePalette.primary : Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: active ? TradePalette.primary : TradePalette.slate200,
                ),
              ),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : TradePalette.slate700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Strip above the results saying where the ladder came from.
///
/// Worth its own line: a ladder built from the ATM strike has no premiums,
/// and saying so stops those rows being read as a complete chain.
class _LadderHeader extends StatelessWidget {
  final OptionLadder ladder;

  const _LadderHeader({required this.ladder});

  @override
  Widget build(BuildContext context) {
    final synthesised = ladder.source == OptionLadderSource.atmLadder;
    final spot = ladder.spotPrice > 0 ? formatAmount(ladder.spotPrice) : '—';
    return Padding(
      key: const ValueKey('ladder-header'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: Row(
        children: [
          Text(
            ladder.instrument,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: TradePalette.slate900,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ladder.expiry != null
                ? '${ladder.expiry!.day.toString().padLeft(2, '0')} '
                    '${_months[ladder.expiry!.month - 1]}'
                : 'expiry —',
            style: const TextStyle(
              fontSize: 11,
              color: TradePalette.slate500,
            ),
          ),
          if (ladder.atmStrike > 0) ...[
            const SizedBox(width: 8),
            Text(
              'ATM ${ladder.atmStrike}',
              style: const TextStyle(
                fontSize: 11,
                color: TradePalette.slate500,
              ),
            ),
          ],
          const SizedBox(width: 8),
          Text(
            'Spot $spot',
            style: const TextStyle(
              fontSize: 11,
              color: TradePalette.slate500,
            ),
          ),
          const Spacer(),
          if (synthesised)
            const Text(
              'ATM ladder',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: TradePalette.slate400,
              ),
            ),
        ],
      ),
    );
  }
}

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

class _ResultRow extends StatelessWidget {
  final WatchItem item;
  final bool added;
  final VoidCallback onAdd;

  const _ResultRow({
    required this.item,
    required this.added,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final gain = item.isGain;
    final color =
        gain ? TradePalette.positiveGreen : TradePalette.negativeRed;
    // A synthesised ladder row has no premium yet; show a dash rather than a
    // 0.00 that would read like the contract is worth nothing.
    final priced = item.lastPrice > 0;
    return Opacity(
      opacity: added ? 0.5 : 1,
      child: InkWell(
        onTap: added ? null : onAdd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InstrumentTitle(
                      symbol: item.symbol,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.segment,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: TradePalette.slate400,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    priced ? formatAmount(item.lastPrice) : '—',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: priced ? color : TradePalette.slate400,
                    ),
                  ),
                  if (priced) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${gain ? '+' : '-'}${formatAmount(item.change.abs())} '
                      '(${gain ? '+' : '-'}${formatPlain(item.changePct.abs())}%)',
                      style: const TextStyle(
                        fontSize: 10,
                        color: TradePalette.slate500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 10),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: added
                      ? TradePalette.slate300
                      : TradePalette.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  added ? LucideIcons.check : LucideIcons.plus,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
