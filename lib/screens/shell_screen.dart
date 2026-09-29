import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/settings/app_settings_controller.dart';
import '../core/theme/cyber_colors.dart';
import '../screens/account/account_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/positions/positions_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/watchlist/watchlist_screen.dart';
import '../services/live/live_market_controller.dart';
import '../widgets/cyber_nav_bar.dart';
import '../widgets/unified_ticker.dart';

/// Root scaffold hosting the 5-tab navigation shell, full-bleed across the
/// browser window so the panels and cards span edge-to-edge.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 2; // Positions tab is the initial screen

  static final _tabs = [
    const WatchlistScreen(),
    const OrdersScreen(),
    const PositionsScreen(),
    const SettingsScreen(),
    const AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Three conditions for the strip: the user wants it, the feed has real
    // prices, and only then does it take over the top safe-area inset.
    final enabled =
        context.select<AppSettingsController, bool>((s) => s.tickerEnabled);
    final hasData =
        context.select<LiveMarketController, bool>((c) => c.hasTickerData);
    final showTicker = enabled && hasData;

    return Scaffold(
      backgroundColor: TradePalette.slate100,
      body: Column(
        children: [
          if (showTicker)
            // The ticker strip consumes the top inset, so the tabs below get
            // it removed and do not double-pad under the status bar.
            const SafeArea(bottom: false, child: UnifiedTicker()),
          Expanded(child: showTicker ? _withoutTopInset(_body()) : _body()),
        ],
      ),
      bottomNavigationBar: CyberNavBar(
        currentIndex: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }

  Widget _body() => IndexedStack(index: _index, children: _tabs);

  /// Drops the top safe-area inset for the tabs, since the ticker took it.
  Widget _withoutTopInset(Widget child) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(padding: mq.padding.copyWith(top: 0)),
      child: child,
    );
  }
}