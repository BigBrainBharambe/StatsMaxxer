import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/habits/presentation/habits_providers.dart';
import 'features/settings/presentation/theme_provider.dart';
import 'features/widgets/home_screen_widget_providers.dart';
import 'features/widgets/home_screen_widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const _Bootstrap(),
    ),
  );
}

class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap();

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final scheduler = ref.read(habitNotificationSchedulerProvider);
      await scheduler.initialize(
        onNotificationTap: (payload) {
          if (payload == null || payload.isEmpty) return;
          try {
            final map = jsonDecode(payload) as Map<String, dynamic>;
            final occurrenceId = map['occurrenceId'] as String?;
            ref.read(habitsTabIndexProvider.notifier).setIndex(0);
            ref
                .read(highlightedOccurrenceIdProvider.notifier)
                .setId(occurrenceId);
          } catch (_) {}
        },
      );
      await ref.read(habitActionsProvider).syncAllHabits();
      unawaited(_pushHomeWidget());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pushHomeWidget());
    }
  }

  Future<void> _pushHomeWidget() async {
    final snapshot = ref.read(homeScreenWidgetSnapshotProvider);
    await HomeScreenWidgetSync.push(snapshot);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeScreenWidgetSnapshotProvider, (_, next) {
      unawaited(HomeScreenWidgetSync.push(next));
    });
    return const StatMaxxerApp();
  }
}
