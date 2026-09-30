import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/cyber_colors.dart';
import '../../models/position.dart';
import '../../repositories/positions_repository.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/symbol_formatter.dart';
import '../../services/live/live_market_controller.dart';
import '../../services/positions/position_retention_controller.dart';
import '../../widgets/scale_fit.dart';
import 'widgets/position_card.dart';
import 'widgets/order_pad_sheet.dart';
import 'widgets/position_filter_sheet.dart';
import 'widgets/positions_header.dart';

/// Positions tab — hero P&L + live list inside the rounded white panel,
/// mirroring the reference light-trading layout.
class PositionsScreen extends StatefulWidget {
  const PositionsScreen({super.key});

  @override
  State<PositionsScreen> createState() => _PositionsScreenState();
}

class _PositionsScreenState extends State<PositionsScreen> {
  late final PositionsRepository _repo;

  /// Cached because [dispose] runs after the element is deactivated, where
  /// looking an ancestor up through `context` is no longer safe.
  late final LiveMarketController _live;

  final _searchCtrl = TextEditingController();

  bool _loading = true;
  Object? _error;
  List<Position> _all = const [];
  List<Position> _visible = const [];
  PortfolioSummary? _summary;
  bool _searching = false;
  PositionFilter _filter = PositionFilter.all;
  int _selectedTab = 1; // Positions tab is active by default

  /// API symbols the live feed is currently polling for this book.
  Set<String> _trackedApiSymbols = {};

  /// Rows exactly as the repository reported them, before retention.
  List<Position> _raw = const [];

  /// The repository's own summary, used untouched when nothing was retired.
  PortfolioSummary? _repoSummary;

  /// Drops closed and expired rows at 07:00 the following morning.
  late final PositionRetentionController _retention;

  @override
  void initState() {
    super.initState();
    _repo = context.read<PositionsRepository>();
    _live = context.read<LiveMarketController>();
    _retention = context.read<PositionRetentionController>();
    // Fires when the 07:00 boundary is crossed while the app is open, or on
    // resume after being backgrounded overnight.
    _retention.addListener(_onRetentionSweep);
    _load();
  }

  /// Re-reads the book when retention says the cutoff may have passed, and
  /// re-filters immediately when the persisted ids arrive. `_applyRetention`
  /// works on the rows already in hand, so the sweep costs no extra fetch.
  void _onRetentionSweep() {
    if (!mounted) return;
    if (_raw.isEmpty) {
      _load();
      return;
    }
    _applyRetention();
  }

  @override
  void dispose() {
    _retention.removeListener(_onRetentionSweep);
    _searchCtrl.dispose();
    if (_trackedApiSymbols.isNotEmpty) {
      _live.untrackSymbols(_trackedApiSymbols);
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final positions = await _repo.fetchPositions();
      final summary = await _repo.fetchPortfolio();
      if (!mounted) return;
      _raw = positions;
      _repoSummary = summary;
      _applyRetention();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Re-runs the retention rule over the rows the repo handed us.
  ///
  /// Deliberately does not block on the retention store: the persisted ids load
  /// asynchronously, and gating the first paint on a storage round trip would
  /// stall the screen whenever storage is slow or unavailable. Instead the
  /// controller notifies when the ids land and this runs again over the same
  /// [_raw] list, so nothing has to be re-fetched.
  void _applyRetention() {
    final positions = _retention.retain(_raw);
    final dropped = _raw.length != positions.length;
    setState(() {
      _all = positions;
      // When rows were retired, the repo's summary still counts them. Rebuild
      // from what is on screen so the header count and the hero P&L agree with
      // the list.
      _summary = dropped ? PortfolioSummary.fromPositions(positions) : _repoSummary;
    });
    _applyVisible();
    _syncTracked();
  }

  /// Point the live feed at every open row in the book. [PositionCard] reads
  /// the resulting quotes to replace its static LTP and P&L.
  void _syncTracked() {
    if (!mounted) return;
    final wanted =
        _all.map((p) => SymbolParts.parse(p.symbol).apiSymbol).toSet();
    _live.untrackSymbols(_trackedApiSymbols.difference(wanted));
    _live.trackSymbols(wanted);
    _trackedApiSymbols = wanted;
  }

  void _applyVisible() {
    final query = _searchCtrl.text;
    setState(() {
      _visible = _all
          .where((p) => positionMatches(p, _filter, query))
          .toList(growable: false);
    });
  }

  void _toggleSearch() {
    if (_searching) _searchCtrl.clear();
    setState(() => _searching = !_searching);
    _applyVisible();
  }

  Future<void> _openFilter() async {
    final picked = await showPositionsFilterSheet(context, current: _filter);
    if (picked == null || picked == _filter) return;
    setState(() => _filter = picked);
    _applyVisible();
  }

  Future<void> _openPosition(Position p) async {
    final action = await showOrderPadSheet(context, position: p);
    if (action == null) return;
    if (action == OrderPadAction.buy) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${p.symbol} added back (demo)'),
            backgroundColor: context.cyber.surface,
          ),
        );
      _load();
      return;
    }
    await _repo.squareOff(p.symbol);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${p.symbol} squared off (demo)'),
          backgroundColor: context.cyber.surface,
        ),
      );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cyber;
    final openCount =
        _summary?.openPositions ?? _all.where((p) => !p.isClosed).length;

    return Container(
      color: TradePalette.slate100,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PortfolioHeader(
              openCount: openCount,
              holdingsCount: openCount,
              selectedTab: _selectedTab,
              onTabSelected: (i) => setState(() => _selectedTab = i),
            ),
            Expanded(child: _buildBody(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CyberColors c) {
    if (_loading && _all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _all.isEmpty) {
      return _ErrorView(error: _error!, onRetry: _load);
    }

    return ColoredBox(
      color: Colors.white,
      child: RefreshIndicator(
        color: TradePalette.primary,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: SizedBox.expand(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (_summary != null)
                  Container(
                    width: double.infinity,
                    height: 140,
                    color: TradePalette.slate100,
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 44),
                  child: _PortfolioPanel(
                    searching: _searching,
                    filter: _filter,
                    onSearchPressed: _toggleSearch,
                    onFilterPressed: _openFilter,
                    onFilterCleared: () {
                      setState(() => _filter = PositionFilter.all);
                      _applyVisible();
                    },
                    onQueryChanged: _applyVisible,
                    searchController: _searchCtrl,
                    resultCount: _visible.length,
                    totalCount: _all.length,
                    children: _buildPanelChildren(c),
                  ),
                ),
                if (_summary != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 23.5),
                      child: Consumer<LiveMarketController>(
                        builder: (context, live, _) => _HeroCard(
                          // Re-priced on every tick so the headline total moves
                          // with the same live marks the rows below use.
                          totalPnl: _liveTotalPnl(live),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Total P&L re-priced on live marks.
  ///
  /// Mirrors [PositionCard] exactly — same "a live price only counts if it is
  /// greater than zero" rule and the same `(ltp - avg) * qty` maths — so the
  /// headline can never disagree with the sum of the rows it sits above. Any
  /// position without a live quote contributes its booked P&L, which means the
  /// total degrades gracefully instead of blanking while the feed catches up.
  double _liveTotalPnl(LiveMarketController live) {
    var total = 0.0;
    var priced = 0;
    for (final p in _all) {
      if (p.isClosed) {
        total += p.pnl;
        priced++;
        continue;
      }
      final quote = live.quoteFor(SymbolParts.parse(p.symbol).apiSymbol);
      if (quote != null && quote.ltp > 0) {
        total += (quote.ltp - p.averagePrice) * p.quantity;
        priced++;
      } else {
        total += p.pnl;
      }
    }
    // Nothing to add up yet: let the repository's figure stand rather than
    // showing a misleading zero.
    return priced == 0 ? (_summary?.totalPnl ?? 0) : total;
  }

  List<Widget> _buildPanelChildren(CyberColors c) {
    if (_visible.isEmpty) {
      return const [_EmptyState()];
    }
    return [
      Consumer<LiveMarketController>(
        builder: (context, live, _) => Column(
          children: [
            for (var i = 0; i < _visible.length; i++) ...[
              PositionCard(
                position: _visible[i],
                live: live.quoteFor(
                  SymbolParts.parse(_visible[i].symbol).apiSymbol,
                ),
                onTap: () => _openPosition(_visible[i]),
              ),
              if (i < _visible.length - 1)
                const Divider(color: TradePalette.slate100, height: 1),
            ],
          ],
        ),
      ),
    ];
  }
}

/// White rounded-t-3xl panel containing the toolbar + position list.
class _PortfolioPanel extends StatelessWidget {
  final bool searching;
  final PositionFilter filter;
  final VoidCallback onSearchPressed;
  final VoidCallback onFilterPressed;
  final VoidCallback onFilterCleared;
  final VoidCallback onQueryChanged;
  final TextEditingController searchController;
  final int resultCount;
  final int totalCount;
  final List<Widget> children;

  const _PortfolioPanel({
    required this.searching,
    required this.filter,
    required this.onSearchPressed,
    required this.onFilterPressed,
    required this.onFilterCleared,
    required this.onQueryChanged,
    required this.searchController,
    required this.resultCount,
    required this.totalCount,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final filterActive = filter != PositionFilter.all;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(64)),
        border: Border(
          top: BorderSide(color: TradePalette.slate200.withValues(alpha: 0.7)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(0, 50, 0, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: TradePalette.slate200),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: _Toolbar(
              searching: searching,
              filtered: filterActive,
              onSearchPressed: onSearchPressed,
              onFilterPressed: onFilterPressed,
            ),
          ),
          if (searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SearchField(
                controller: searchController,
                onChanged: (_) => onQueryChanged(),
                onClear: onSearchPressed,
              ),
            ),
          if (searching || filterActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _ResultMeta(
                resultCount: resultCount,
                totalCount: totalCount,
                filter: filter,
                onFilterCleared: onFilterCleared,
              ),
            ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// "3 of 4 positions" plus a removable chip for the active filter.
class _ResultMeta extends StatelessWidget {
  final int resultCount;
  final int totalCount;
  final PositionFilter filter;
  final VoidCallback onFilterCleared;

  const _ResultMeta({
    required this.resultCount,
    required this.totalCount,
    required this.filter,
    required this.onFilterCleared,
  });

  @override
  Widget build(BuildContext context) {
    final filterActive = filter != PositionFilter.all;
    return Row(
      children: [
        Text(
          '$resultCount of $totalCount positions',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: TradePalette.slate400,
          ),
        ),
        const Spacer(),
        if (filterActive)
          GestureDetector(
            onTap: onFilterCleared,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 3, 6, 3),
              decoration: BoxDecoration(
                color: TradePalette.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter.label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: TradePalette.slate700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.x,
                    size: 11,
                    color: TradePalette.slate500,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-width square white box behind the Total P&L block, inset 20px from
/// each side on the slate-100 backdrop, flowing into the white panel below.
class _HeroCard extends StatelessWidget {
  /// Live-marked total, already summed by the screen. Falls back to the
  /// repository's booked figure when the feed has nothing for any row.
  final double totalPnl;

  const _HeroCard({required this.totalPnl});

  @override
  Widget build(BuildContext context) {
    final value = formatSigned(totalPnl);
    final isProfit = totalPnl >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: TradePalette.slate200.withValues(alpha: 0.8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 30,
            spreadRadius: -4,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 12,
            spreadRadius: -2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total P&L',
            style: AppText.micro.copyWith(
              color: TradePalette.slate500,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              height: 1.1,
              color: isProfit
                  ? TradePalette.positiveGreen
                  : TradePalette.negativeRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final bool searching;
  final bool filtered;
  final VoidCallback onSearchPressed;
  final VoidCallback onFilterPressed;

  const _Toolbar({
    required this.searching,
    required this.filtered,
    required this.onSearchPressed,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToolAction(
          icon: searching ? LucideIcons.x : LucideIcons.search,
          tooltip: searching ? 'Close search' : 'Search positions',
          onTap: onSearchPressed,
        ),
        const SizedBox(width: 8),
        _ToolAction(
          icon: LucideIcons.slidersHorizontal,
          tooltip: 'Filter positions',
          active: filtered,
          onTap: onFilterPressed,
        ),
        Flexible(
          child: ScaleFit(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Analyze',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TradePalette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  LucideIcons.loader2,
                  size: 14,
                  color: TradePalette.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TradePalette.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _ToolAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: Ink(
            width: 46,
            height: 34,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active
                      ? TradePalette.slate900
                      : TradePalette.primary,
                ),
                const SizedBox(height: 2),
                Container(
                  width: active ? 4 : 0,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TradePalette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () => setState(() {});
    widget.controller.addListener(_listener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return TextField(
      controller: widget.controller,
      autofocus: true,
      onChanged: widget.onChanged,
      style: AppText.monoValue.copyWith(
        color: TradePalette.slate900,
        fontSize: 13,
      ),
      cursorColor: TradePalette.primary,
      decoration: InputDecoration(
        hintText: 'Search by symbol…',
        hintStyle: AppText.micro.copyWith(color: TradePalette.slate400),
        prefixIcon: Icon(
          LucideIcons.search,
          size: 15,
          color: TradePalette.primary,
        ),
        suffixIcon: hasText
            ? IconButton(
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
                icon: const Icon(
                  LucideIcons.circleX,
                  size: 15,
                  color: TradePalette.slate500,
                ),
              )
            : null,
        filled: true,
        fillColor: TradePalette.slate100,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.inbox, size: 30, color: TradePalette.slate400),
            SizedBox(height: 10),
            Text(
              'No positions found',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TradePalette.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.wifiOff,
              size: 32,
              color: TradePalette.negativeRed,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load positions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: TradePalette.slate900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.micro.copyWith(color: TradePalette.slate500),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: TradePalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
