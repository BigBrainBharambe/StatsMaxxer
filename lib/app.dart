import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/settings/presentation/theme_provider.dart';
import 'shared/widgets/home_shell.dart';

class StatMaxxerApp extends ConsumerWidget {
  const StatMaxxerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final style = ref.watch(visualStyleProvider);

    if (style == VisualStyle.cyber) {
      return MaterialApp(
        title: 'StatMaxxer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.cyber(),
        darkTheme: AppTheme.cyber(),
        themeMode: ThemeMode.dark,
        home: const HomeShell(),
      );
    }

    return MaterialApp(
      title: 'StatMaxxer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.classicLight(),
      darkTheme: AppTheme.classicDark(),
      themeMode: themeMode,
      home: const HomeShell(),
    );
  }
}
