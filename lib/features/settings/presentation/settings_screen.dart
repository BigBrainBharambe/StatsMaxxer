import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feature_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../sync/presentation/drive_sync_settings_section.dart';
import '../domain/app_currency.dart';
import 'currency_provider.dart';
import 'theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final style = ref.watch(visualStyleProvider);
    final currencyCode = ref.watch(currencyCodeProvider);
    final isCyber = style == VisualStyle.cyber;

    return Scaffold(
      appBar: AppBar(title: Text(isCyber ? 'SETTINGS' : 'Settings')),
      body: ListView(
        children: [
          ListTile(
            title: Text(isCyber ? 'VISUAL STYLE' : 'Visual style'),
            subtitle: Text(
              isCyber
                  ? 'CLASSIC MATERIAL OR CYBER HUD'
                  : 'Classic Material or Cyber HUD',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<VisualStyle>(
              segments: const [
                ButtonSegment(
                  value: VisualStyle.classic,
                  label: Text('Classic'),
                  icon: Icon(Icons.palette_outlined),
                ),
                ButtonSegment(
                  value: VisualStyle.cyber,
                  label: Text('Cyber'),
                  icon: Icon(Icons.memory),
                ),
              ],
              selected: {style},
              onSelectionChanged: (value) {
                ref.read(visualStyleProvider.notifier).setStyle(value.first);
              },
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text(isCyber ? 'APPEARANCE' : 'Appearance'),
            subtitle: Text(
              isCyber
                  ? 'LIGHT / DARK APPLY TO CLASSIC STYLE'
                  : 'Choose light, dark, or system theme',
            ),
          ),
          if (isCyber)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Cyber HUD is dark-only. Switch to Classic to use light mode.',
              ),
            )
          else
            RadioGroup<ThemeMode>(
              groupValue: themeMode,
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text('System'),
                    value: ThemeMode.system,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Light'),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Dark'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(isCyber ? 'CURRENCY' : 'Currency'),
            subtitle: Text(
              isCyber
                  ? 'SYMBOL USED FOR MONEY AMOUNTS'
                  : 'Symbol used for money amounts',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DropdownButtonFormField<String>(
              key: ValueKey('currency-$currencyCode'),
              initialValue: currencyCode,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in AppCurrency.supported)
                  DropdownMenuItem(
                    value: c.code,
                    child: Text(
                      '${c.code} (${c.symbol}) — ${c.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(currencyCodeProvider.notifier)
                      .setCurrencyCode(value);
                }
              },
            ),
          ),
          if (FeatureFlags.enableGdriveSync) const DriveSyncSettingsSection(),
          const Divider(),
          ListTile(
            title: Text(isCyber ? 'HOME SCREEN WIDGET' : 'Home screen widget'),
            subtitle: Text(
              isCyber
                  ? 'ANDROID: LONG-PRESS HOME → WIDGETS → STATMAXXER\n'
                      'SHOWS TODAY HABITS, TOP STREAK, MONEY NET\n'
                      'UPDATES WHEN YOU OPEN THE APP (LOCAL DATA ONLY)'
                  : 'Android: long-press home → Widgets → StatMaxxer Today. '
                      'Shows today’s habit progress, top streak, and money net '
                      'from local data (no OCR). Updates when you open the app. '
                      'iOS WidgetKit needs an App Group — see docs/home_screen_widgets.md.',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }
}
