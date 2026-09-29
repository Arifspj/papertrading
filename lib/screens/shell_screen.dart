import 'package:flutter/material.dart';

import '../core/theme/cyber_colors.dart';
import '../screens/account/account_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/positions/positions_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/watchlist/watchlist_screen.dart';
import '../widgets/cyber_nav_bar.dart';

/// Root scaffold hosting the 5-tab navigation shell, constrained to a
/// centered 440px mobile viewport like the reference design.
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
    return Scaffold(
      backgroundColor: TradePalette.slate100,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: IndexedStack(index: _index, children: _tabs),
        ),
      ),
      bottomNavigationBar: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: CyberNavBar(
            currentIndex: _index,
            onSelect: (i) => setState(() => _index = i),
          ),
        ),
      ),
    );
  }
}