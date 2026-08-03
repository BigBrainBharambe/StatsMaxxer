import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/hud_widgets.dart';
import '../domain/habit.dart';
import 'habit_delete.dart';
import 'habit_detail_screen.dart';
import 'habits_providers.dart';

class HabitsTodayView extends ConsumerWidget {
  const HabitsTodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(todayQuestsProvider);
    final highlighted = ref.watch(highlightedOccurrenceIdProvider);
    final ext = StatThemeExtension.of(context);

    return questsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (quests) {
        if (quests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.celebration_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ext.isCyber ? 'ALL CLEAR // TODAY' : 'All clear for today',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a habit or check the calendar for what’s coming up.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: quests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final quest = quests[index];
            if (quest.isQuantity) {
              return _QuantityQuestTile(
                quest: quest,
                ext: ext,
              );
            }
            return _OccurrenceQuestTile(
              quest: quest,
              highlighted: highlighted,
              ext: ext,
            );
          },
        );
      },
    );
  }
}

class _QuantityQuestTile extends ConsumerWidget {
  const _QuantityQuestTile({
    required this.quest,
    required this.ext,
  });

  final TodayQuest quest;
  final StatThemeExtension ext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = quest.habit;
    final streak = ref.watch(habitStreakProvider(habit.id));
    final progress = ref.watch(habitQuantityProgressProvider(habit.id));
    final color = Color(
      habit.colorValue ?? Theme.of(context).colorScheme.primary.toARGB32(),
    );
    final met = progress.asData?.value?.met == true;
    final progressLabel = progress.asData?.value?.label ??
        habit.quantityGoal?.summary ??
        '';

    return HudPanel(
      highlighted: !met,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HabitDetailScreen(habitId: habit.id),
          ),
        );
      },
      onLongPress: () async {
        final removed = await confirmAndDeleteHabit(
          context: context,
          ref: ref,
          habitId: habit.id,
          habitName: habit.name,
        );
        if (removed && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ext.isCyber
                    ? 'DELETED // ${habit.name.toUpperCase()}'
                    : 'Removed ${habit.name}',
              ),
            ),
          );
        }
      },
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(habitIconData(habit.iconName), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ext.isCyber
                      ? habit.name.toUpperCase().replaceAll(' ', '_')
                      : habit.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    progressLabel,
                    streak.when(
                      data: (s) => ext.isCyber
                          ? 'STRK_${s.current.toString().padLeft(2, '0')}'
                          : '🔥 ${s.current}',
                      loading: () => '',
                      error: (_, _) => '',
                    ),
                  ].where((s) => s.isNotEmpty).join(
                        ext.isCyber ? ' // ' : ' · ',
                      ),
                  style: (ext.isCyber
                          ? ext.mono
                          : Theme.of(context).textTheme.bodySmall)
                      ?.copyWith(
                    fontSize: 11,
                    color: ext.isCyber ? CyberPalette.mintDim : null,
                  ),
                ),
                if (met)
                  Text(
                    ext.isCyber ? 'GOAL_MET' : 'Goal met',
                    style: TextStyle(
                      color: ext.isCyber
                          ? CyberPalette.mint
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          if (met)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.check_circle,
                color: ext.isCyber ? CyberPalette.mint : color,
                size: 28,
              ),
            ),
          DecoratedBox(
            decoration: ext.isCyber
                ? const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x7700FF9C),
                        blurRadius: 14,
                      ),
                    ],
                  )
                : const BoxDecoration(),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ext.isCyber ? CyberPalette.mint : color,
                foregroundColor: ext.isCyber ? CyberPalette.black : null,
              ),
              onPressed: () async {
                await ref.read(habitActionsProvider).logQuantity(
                      habitId: habit.id,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ext.isCyber
                            ? 'LOGGED +1 // ${habit.name.toUpperCase()}'
                            : '+1 ${habit.quantityGoal?.unitLabel ?? 'logged'}',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
              child: const Text('+1'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OccurrenceQuestTile extends ConsumerWidget {
  const _OccurrenceQuestTile({
    required this.quest,
    required this.highlighted,
    required this.ext,
  });

  final TodayQuest quest;
  final String? highlighted;
  final StatThemeExtension ext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occ = quest.occurrence!;
    final habit = quest.habit;
    final streak = ref.watch(habitStreakProvider(habit.id));
    final isHighlight = highlighted == occ.id;
    final color = Color(
      habit.colorValue ?? Theme.of(context).colorScheme.primary.toARGB32(),
    );

    return AnimatedScale(
      scale: isHighlight ? 1.02 : 1,
      duration: const Duration(milliseconds: 250),
      child: HudPanel(
        highlighted: isHighlight || occ.isPending,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HabitDetailScreen(habitId: habit.id),
            ),
          );
        },
        onLongPress: () async {
          final removed = await confirmAndDeleteHabit(
            context: context,
            ref: ref,
            habitId: habit.id,
            habitName: habit.name,
          );
          if (removed && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ext.isCyber
                      ? 'DELETED // ${habit.name.toUpperCase()}'
                      : 'Removed ${habit.name}',
                ),
              ),
            );
          }
        },
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(
                habitIconData(habit.iconName),
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ext.isCyber
                        ? habit.name.toUpperCase().replaceAll(' ', '_')
                        : habit.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (habit.schedule != null)
                        ext.isCyber
                            ? habit.schedule!.summary.toUpperCase()
                            : habit.schedule!.summary,
                      if (habit.kind == HabitKind.adhoc)
                        ext.isCyber ? 'ADHOC' : 'One-time',
                      streak.when(
                        data: (s) => ext.isCyber
                            ? 'STRK_${s.current.toString().padLeft(2, '0')}'
                            : '🔥 ${s.current}',
                        loading: () => '',
                        error: (_, _) => '',
                      ),
                    ].where((s) => s.isNotEmpty).join(
                          ext.isCyber ? ' // ' : ' · ',
                        ),
                    style: (ext.isCyber
                            ? ext.mono
                            : Theme.of(context).textTheme.bodySmall)
                        ?.copyWith(
                      fontSize: 11,
                      color: ext.isCyber ? CyberPalette.mintDim : null,
                    ),
                  ),
                  if (occ.isMissed)
                    Text(
                      ext.isCyber ? 'MISSED' : 'Missed',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            if (occ.isCompleted)
              IconButton(
                tooltip: 'Undo',
                icon: Icon(
                  Icons.check_circle,
                  color: ext.isCyber ? CyberPalette.mint : color,
                  size: 36,
                  shadows: ext.isCyber
                      ? const [
                          Shadow(
                            color: Color(0x8800FF9C),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                onPressed: () => ref
                    .read(habitActionsProvider)
                    .uncompleteOccurrence(occ.id),
              )
            else if (occ.isSkipped)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => ref
                        .read(habitActionsProvider)
                        .uncompleteOccurrence(occ.id),
                    child: Text(ext.isCyber ? 'UNSKIP' : 'Unskip'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ext.isCyber ? CyberPalette.mint : color,
                      foregroundColor: ext.isCyber ? CyberPalette.black : null,
                    ),
                    onPressed: () async {
                      await ref
                          .read(habitActionsProvider)
                          .completeOccurrence(occ.id);
                    },
                    child: Text(ext.isCyber ? 'CONFIRM' : 'Done'),
                  ),
                ],
              )
            else ...[
              if (occ.isPending)
                TextButton(
                  onPressed: () =>
                      ref.read(habitActionsProvider).skipOccurrence(occ.id),
                  child: Text(ext.isCyber ? 'SKIP' : 'Skip'),
                ),
              DecoratedBox(
                decoration: ext.isCyber
                    ? const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x7700FF9C),
                            blurRadius: 14,
                          ),
                        ],
                      )
                    : const BoxDecoration(),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ext.isCyber ? CyberPalette.mint : color,
                    foregroundColor: ext.isCyber ? CyberPalette.black : null,
                  ),
                  onPressed: () async {
                    await ref
                        .read(habitActionsProvider)
                        .completeOccurrence(occ.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ext.isCyber
                                ? 'QUEST COMPLETE // ${habit.name.toUpperCase()}'
                                : 'Nice! ${habit.name} done.',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: Text(ext.isCyber ? 'CONFIRM' : 'Done'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
