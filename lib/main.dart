import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'repositories/mock_positions_repository.dart';
import 'repositories/positions_repository.dart';
import 'repositories/watchlist_repository.dart';
import 'screens/shell_screen.dart';
import 'services/live/live_market_controller.dart';
import 'services/positions/mis_auto_square_off_controller.dart';
import 'services/positions/position_retention_controller.dart';

/// CyberPulse — paper trading terminal.
///
/// Data source:
///  - Today: [MockPositionsRepository] (seeded demo book).
///  - When the real backend is ready, swap the provider below for
///    `HttpPositionsRepository()` and set `PAPER_TRADE_BASE_URL`.
///
/// Market data:
///  - [LiveMarketController] pulls HNICALLS (ticker_app / analysis / observation)
///    and pushes it into the Watchlist. See `docs/live_stream.md`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CyberPulseApp());
}

class CyberPulseApp extends StatelessWidget {
  const CyberPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: MultiProvider(
        providers: [
          Provider<PositionsRepository>(
            create: (_) => MockPositionsRepository(),
          ),
          Provider<WatchlistRepository>(
            create: (_) => MockWatchlistRepository(),
          ),
          ChangeNotifierProvider<LiveMarketController>(
            create: (_) => LiveMarketController(),
          ),
          ChangeNotifierProvider<AppSettingsController>(
            create: (_) => AppSettingsController(),
          ),
          // Squares off and expired rows leave the book at 07:00 the next
          // morning. Driven on fetch, on resume, and by a 07:00 timer, since a
          // dead Flutter process cannot wake itself.
          ChangeNotifierProvider<PositionRetentionController>(
            create: (_) => PositionRetentionController(),
          ),
          // Squares off intraday positions at 15:20, the way a broker does just
          // before the close, so a day never ends holding a MIS position.
          ChangeNotifierProvider<MisAutoSquareOffController>(
            create: (context) => MisAutoSquareOffController(
              repository: context.read<PositionsRepository>(),
              ltpOf: (symbol) =>
                  context.read<LiveMarketController>().quoteFor(symbol)?.ltp ?? 0,
            ),
          ),
        ],
        child: Consumer<ThemeController>(
          builder: (context, theme, _) {
            return MaterialApp(
              title: 'CyberPulse Paper Trading',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: theme.mode,
              home: const ShellScreen(),
            );
          },
        ),
      ),
    );
  }
}