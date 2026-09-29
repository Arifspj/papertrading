import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/cyber_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/watchlist.dart';
import '../../repositories/watchlist_repository.dart';
import '../positions/widgets/order_pad_sheet.dart';

const _headerBg = Color(0xFFF8FAFF);

/// Kite-style Watchlist: grey-ish header (title, search, tab strip) over a
/// white, divided quote list. Mirrors the reference "Watchlist" screen.
class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  late final WatchlistRepository _repo;
  List<WatchItem> _items = const [];
  bool _loading = true;
  int _tab = 0;

  static const _tabs = [
    'Watchlist 1',
    'Watchlist 2',
    'Watchlist 3',
    'Watchlist 4',
    'NIFTY 50',
    'BANKNIFTY',
  ];

  @override
  void initState() {
    super.initState();
    _repo = context.read<WatchlistRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.fetchWatchlist();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: _headerBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _titleRow(),
                  _searchBar(),
                  _tabStrip(),
                  const Divider(color: TradePalette.slate100, height: 1),
                ],
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          const Text(
            'Watchlist',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: TradePalette.slate900,
            ),
          ),
          const SizedBox(width: 4),
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: TradePalette.slate700,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Text(
              '${_items.length} / 50',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: TradePalette.activeNav,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TradePalette.slate200),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.search,
              size: 16,
              color: TradePalette.slate400,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Search & add (e.g. infy, nifty, weekly otm)',
                style: TextStyle(
                  fontSize: 13,
                  color: TradePalette.slate400,
                ),
              ),
            ),
            const Icon(
              LucideIcons.slidersHorizontal,
              size: 16,
              color: TradePalette.slate500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabStrip() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        separatorBuilder: (_, i) => const SizedBox(width: 24),
        itemBuilder: (context, i) {
          final active = i == _tab;
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _tabs[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? TradePalette.activeNav
                        : TradePalette.slate500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: active ? 28 : 0,
                  height: 2,
                  decoration: BoxDecoration(
                    color: TradePalette.activeNav,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _items.length,
      separatorBuilder: (_, i) =>
          const Divider(color: TradePalette.slate100, height: 1),
      itemBuilder: (context, i) => _WatchRow(item: _items[i]),
    );
  }
}

/// One quote row: symbol + W badge (left) and price + change (right).
class _WatchRow extends StatelessWidget {
  final WatchItem item;

  const _WatchRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final gain = item.isGain;
    final priceColor =
        gain ? TradePalette.positiveGreen : TradePalette.negativeRed;
    final changeText =
        '${gain ? '+' : '-'}${formatAmount(item.change.abs())} '
        '(${gain ? '+' : '-'}${formatPlain(item.changePct.abs())}%)';

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SymbolLine(item: item),
                  const SizedBox(height: 2),
                  Text(
                    item.segment,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: TradePalette.slate400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatAmount(item.lastPrice),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: priceColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  changeText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: TradePalette.slate500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Weekly-option aware symbol line with superscript and "W" badge.
class _SymbolLine extends StatelessWidget {
  final WatchItem item;

  const _SymbolLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final parts = SymbolParts.parse(item.symbol);
    final base = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: TradePalette.slate900,
      height: 1.3,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: parts.head),
          if (parts.suffix != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Transform.translate(
                offset: const Offset(0, -2),
                child: Text(
                  parts.suffix!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: TradePalette.slate500,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          if (item.isWeekly)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: TradePalette.weekBadge,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'W',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          TextSpan(text: parts.tail),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}