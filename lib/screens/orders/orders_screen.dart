import 'package:flutter/material.dart';

import '../../core/icons/lucide_icons.dart';

import '../../widgets/simple_tab_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleTabScreen(
      title: 'Orders',
      icon: LucideIcons.fileText,
      message: 'Your buy / sell orders will appear here.',
    );
  }
}
