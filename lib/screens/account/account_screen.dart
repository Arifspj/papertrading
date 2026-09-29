import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../widgets/simple_tab_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleTabScreen(
      title: 'Account',
      icon: LucideIcons.user,
      message: 'Profile, funds & demo balance will appear here.',
    );
  }
}