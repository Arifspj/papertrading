import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/cyber_colors.dart';
import '../../models/position.dart';
import '../../repositories/positions_repository.dart';
import '../../widgets/scale_fit.dart';
import 'widgets/hero_pnl_card.dart';
import 'widgets/position_card.dart';
import 'widgets/position_detail_sheet.dart';
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
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  Object? _error;
  List<Position> _all = const [];
  List<Position> _visible = const [];
  PortfolioSummary? _summary;
  bool _searching = false;
  PositionFilter _filter = PositionFilter.all;
  int _selectedTab = 1; // Positions tab is active by default

  @override
  void initState() {
    super.initState();
    _repo = context.read<PositionsRepository>();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
      setState(() {
        _all = positions;
        _summary = summary;
        _loading = false;
      });
      _applyVisible();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
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
    final squaredOff = await showPositionDetailSheet(context, position: p);
    if (squaredOff == true) {
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
            const IosStatusBar(),
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
                Container(
                  height: 120,
                  width: double.infinity,
                  color: TradePalette.slate100,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 44),
                  child: _PortfolioPanel(
                    searching: _searching,
                    filtered: _filter != PositionFilter.all,
                    onSearchPressed: _toggleSearch,
                    onFilterPressed: _openFilter,
                    searchController: _searchCtrl,
                    children: _buildPanelChildren(c),
                  ),
                ),
                if (_summary != null) HeroPnlCard(summary: _summary!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPanelChildren(CyberColors c) {
    if (_visible.isEmpty) {
      return const [_EmptyState()];
    }
    return [
      for (var i = 0; i < _visible.length; i++) ...[
        PositionCard(
          position: _visible[i],
          onTap: () => _openPosition(_visible[i]),
        ),
        if (i < _visible.length - 1)
          const Divider(color: TradePalette.slate100, height: 1),
      ],
    ];
  }
}

/// White rounded-t-3xl panel containing the toolbar + position list.
class _PortfolioPanel extends StatelessWidget {
  final bool searching;
  final bool filtered;
  final VoidCallback onSearchPressed;
  final VoidCallback onFilterPressed;
  final TextEditingController searchController;
  final List<Widget> children;

  const _PortfolioPanel({
    required this.searching,
    required this.filtered,
    required this.onSearchPressed,
    required this.onFilterPressed,
    required this.searchController,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(64)),
        border: Border(
          top: BorderSide(color: TradePalette.slate200.withValues(alpha: 0.7)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(0, 56, 0, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Toolbar(
              searching: searching,
              filtered: filtered,
              onSearchPressed: onSearchPressed,
              onFilterPressed: onFilterPressed,
            ),
          ),
          if (searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SearchField(controller: searchController),
            ),
          const SizedBox(height: 8),
          ...children,
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
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TradePalette.uLogo,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'U',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'U Analyze',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TradePalette.uLogo,
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
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? TradePalette.greenLight : TradePalette.slate100,
              border: Border.all(
                color: active
                    ? TradePalette.greenBorder
                    : TradePalette.slate200,
              ),
            ),
            child: Icon(
              icon,
              size: 15,
              color: active
                  ? TradePalette.positiveGreen
                  : TradePalette.slate600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
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
          color: TradePalette.slate400,
        ),
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
