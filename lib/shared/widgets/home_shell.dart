import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/habits/presentation/habits_screen.dart';
import '../../features/money/presentation/analytics_screen.dart';
import '../../features/money/presentation/money_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'hud_widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    HabitsScreen(),
    MoneyScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final ext = StatThemeExtension.of(context);

    final nav = NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.check_circle_outline),
          selectedIcon: const Icon(Icons.check_circle),
          label: ext.isCyber ? 'HABITS' : 'Habits',
        ),
        NavigationDestination(
          icon: const Icon(Icons.payments_outlined),
          selectedIcon: const Icon(Icons.payments),
          label: ext.isCyber ? 'LEDGER' : 'Money',
        ),
        NavigationDestination(
          icon: const Icon(Icons.bar_chart_outlined),
          selectedIcon: const Icon(Icons.bar_chart),
          label: ext.isCyber ? 'NET' : 'Analytics',
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: ext.isCyber ? 'SYS' : 'Settings',
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: HudGridBackground(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: ext.useHudChrome
                ? Border.all(color: CyberPalette.mintBorder)
                : null,
          ),
          child: IndexedStack(
            index: _index,
            children: _pages,
          ),
        ),
      ),
      bottomNavigationBar: ext.useHudChrome
          ? Container(
              decoration: const BoxDecoration(
                color: CyberPalette.black,
                border: Border(
                  top: BorderSide(color: CyberPalette.mintBorder),
                ),
              ),
              child: nav,
            )
          : nav,
    );
  }
}
