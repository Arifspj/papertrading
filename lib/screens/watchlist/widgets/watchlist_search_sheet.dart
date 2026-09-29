import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/cyber_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/watchlist.dart';
import '../../../repositories/watchlist_repository.dart';
import 'watch_symbol_line.dart';

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
  final _ctrl = TextEditingController();
  List<WatchItem> _results = const [];

  @override
  void initState() {
    super.initState();
    _repo = context.read<WatchlistRepository>();
    _results = _repo.searchSymbols('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add(WatchItem item) async {
    await _repo.addItem(item);
    if (!mounted) return;
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
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
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        'No symbols found',
                        style: TextStyle(
                          fontSize: 13,
                          color: TradePalette.slate400,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, i) => const Divider(
                        color: TradePalette.slate100,
                        height: 1,
                      ),
                      itemBuilder: (context, i) {
                        final item = _results[i];
                        return _ResultRow(
                          item: item,
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

class _ResultRow extends StatelessWidget {
  final WatchItem item;
  final VoidCallback onAdd;

  const _ResultRow({required this.item, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final gain = item.isGain;
    final color =
        gain ? TradePalette.positiveGreen : TradePalette.negativeRed;
    return InkWell(
      onTap: onAdd,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WatchSymbolLine(
                    symbol: item.symbol,
                    isWeekly: item.isWeekly,
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
                  formatAmount(item.lastPrice),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
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
            ),
            const SizedBox(width: 10),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: item.isWeekly
                    ? TradePalette.weekBadge
                    : TradePalette.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                LucideIcons.plus,
                size: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}