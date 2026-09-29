import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/cyber_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/symbol_formatter.dart';
import '../../models/market/live_quote.dart';
import '../../models/watchlist.dart';
import '../../repositories/watchlist_repository.dart';
import '../../services/live/live_market_controller.dart';
import '../../services/live/market_stream.dart';
import '../../widgets/instrument_title.dart';
import '../positions/widgets/order_pad_sheet.dart';
import 'widgets/watchlist_search_sheet.dart';

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

  Future<void> _openSearch() async {
    final added = await showWatchlistSearchSheet(context);
    if (!mounted || added == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${added.symbol} added to Watchlist')),
    );
    _load();
  }

  Future<void> _openOrderPad(WatchItem item) async {
    final action = await showWatchOrderPadSheet(
      context,
      symbol: item.symbol,
      segment: item.segment,
      lastPrice: item.lastPrice,
      change: item.change,
    );
    if (!mounted || action == null) return;
    final label = action == OrderPadAction.buy ? 'Buy' : 'Sell';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label order placed for ${item.symbol} (demo)')),
    );
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

  /// Live badge: dot colour + transport name, driven by the stream status.
  Widget _liveChip() {
    return Consumer<LiveMarketController>(
      builder: (context, live, _) {
        final color = switch (live.status) {
          StreamStatus.live => TradePalette.positiveGreen,
          StreamStatus.connecting => TradePalette.amber,
          StreamStatus.degraded => TradePalette.amber,
          _ => TradePalette.slate400,
        };
        final label = switch (live.status) {
          StreamStatus.live => 'LIVE · ${live.transportName}',
          StreamStatus.connecting => 'CONNECTING',
          StreamStatus.degraded => 'DEGRADED',
          StreamStatus.disconnected => 'OFFLINE',
          StreamStatus.failed => 'OFFLINE',
          StreamStatus.idle => 'IDLE',
        };
        return GestureDetector(
          onTap: live.refresh,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
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
          _liveChip(),
          const SizedBox(width: 12),
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
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _openSearch,
          borderRadius: BorderRadius.circular(10),
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
    return Consumer<LiveMarketController>(
      builder: (context, live, _) {
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _items.length,
          separatorBuilder: (_, i) =>
              const Divider(color: TradePalette.slate100, height: 1),
          itemBuilder: (context, i) {
            final item = _items[i];
            return _WatchRow(
              item: item,
              live: live.quoteFor(SymbolParts.parse(item.symbol).apiSymbol),
              onTap: () => _openOrderPad(item),
            );
          },
        );
      },
    );
  }
}

/// One quote row: symbol + W badge (left) and price + change (right).
class _WatchRow extends StatelessWidget {
  final WatchItem item;

  /// Live quote from HNICALLS. When present it replaces the seeded mock price.
  final LiveQuote? live;

  final VoidCallback onTap;

  const _WatchRow({required this.item, required this.onTap, this.live});

  @override
  Widget build(BuildContext context) {
    final price = live?.ltp ?? item.lastPrice;
    final change = live?.change ?? item.change;
    final changePct = live?.changePct ?? item.changePct;
    final gain = change >= 0;
    final priceColor =
        gain ? TradePalette.positiveGreen : TradePalette.negativeRed;
    final changeText =
        '${gain ? '+' : '-'}${formatAmount(change.abs())} '
        '(${gain ? '+' : '-'}${formatPlain(changePct.abs())}%)';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InstrumentTitle(symbol: item.symbol),
                  const SizedBox(height: 2),
                  Text(
                    live == null ? item.segment : '${item.segment} · live',
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
                  formatAmount(price),
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