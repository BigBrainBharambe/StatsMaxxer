import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/hud_widgets.dart';
import 'add_habit_sheet.dart';
import 'habits_calendar_view.dart';
import 'habits_providers.dart';
import 'habits_today_view.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        ref.read(habitsTabIndexProvider.notifier).setIndex(_tabs.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(habitActionsProvider).syncAllHabits();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(topStreakProvider);
    final ext = StatThemeExtension.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(ext.isCyber ? 'STATMAXXER' : 'Habits'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: streak.when(
              data: (s) {
                if (ext.isCyber) {
                  return HudChip(
                    label: 'STREAK_${s.toString().padLeft(2, '0')}',
                    color: CyberPalette.mint,
                  );
                }
                return Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: s > 0
                          ? Colors.orange.shade700
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$s',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: ext.isCyber ? 'TODAY' : 'Today'),
            Tab(text: ext.isCyber ? 'CAL' : 'Calendar'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'habits_fab',
        onPressed: () => showAddHabitSheet(context),
        icon: const Icon(Icons.add),
        label: Text(ext.isCyber ? 'NEW_QUEST' : 'Add habit'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          HabitsTodayView(),
          HabitsCalendarView(),
        ],
      ),
    );
  }
}
