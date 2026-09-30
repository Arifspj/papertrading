import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/hnicalls_client.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'repositories/mock_positions_repository.dart';
import 'repositories/positions_repository.dart';
import 'repositories/watchlist_repository.dart';
import 'screens/shell_screen.dart';
import 'services/live/live_market_controller.dart';
import 'services/live/option_symbol_service.dart';
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
  /// [clock] drives the 07:00 retention and 15:20 square-off cut-offs. It is a
  /// parameter so tests can pin the time of day; leaving it null means the
  /// device clock, which is what production wants.
  const CyberPulseApp({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final clock = this.clock;
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
          // Backs the watchlist "add" picker's option chain tab. Shares the
          // default HnicallsClient so it goes through the same timeouts and
          // error folding as the live poller.
          Provider<OptionSymbolService>(
            create: (_) => OptionSymbolService(client: HnicallsClient()),
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
            create: (_) => PositionRetentionController(clock: clock),
          ),
          // Squares off intraday positions at 15:20, the way a broker does just
          // before the close, so a day never ends holding a MIS position.
          ChangeNotifierProvider<MisAutoSquareOffController>(
            create: (context) => MisAutoSquareOffController(
              repository: context.read<PositionsRepository>(),
              ltpOf: (symbol) =>
                  context.read<LiveMarketController>().quoteFor(symbol)?.ltp ?? 0,
              clock: clock,
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