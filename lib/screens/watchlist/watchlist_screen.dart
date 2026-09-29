import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../widgets/simple_tab_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleTabScreen(
      title: 'Watchlist',
      icon: LucideIcons.bookmark,
      message: 'Your market watchlist will appear here.',
    );
  }
}