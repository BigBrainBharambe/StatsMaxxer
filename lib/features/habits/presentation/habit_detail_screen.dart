import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_utils.dart';
import '../domain/habit.dart';
import '../domain/habit_retro_rules.dart';
import 'habit_delete.dart';
import 'habits_providers.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = ref
        .watch(habitsProvider)
        .asData
        ?.value
        .where((h) => h.id == habitId)
        .firstOrNull;
    final occAsync = ref.watch(habitOccurrencesProvider(habitId));
    final logsAsync = ref.watch(habitQuantityLogsProvider(habitId));
    final streak = ref.watch(habitStreakProvider(habitId));
    final progress = ref.watch(habitQuantityProgressProvider(habitId));
    final color = Color(
      habit?.colorValue ??
          Theme.of(context).colorScheme.primary.toARGB32(),
    );
    final isQuantity = habit?.isQuantityGoal == true;
    final today = dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(habit?.name ?? 'Habit'),
        actions: [
          if (habit != null) ...[
            IconButton(
              tooltip: 'Delete habit',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final removed = await confirmAndDeleteHabit(
                  context: context,
                  ref: ref,
                  habitId: habitId,
                  habitName: habit.name,
                );
                if (removed && context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'archive') {
                  await ref.read(habitActionsProvider).archiveHabit(habitId);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: isQuantity && habit != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'log_past_$habitId',
                  tooltip: 'Log for a past day',
                  onPressed: () => _logQuantityForDate(context, ref, habit),
                  child: const Icon(Icons.event),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'log_now_$habitId',
                  onPressed: () => _logQuantityNow(context, ref, habit),
                  icon: const Icon(Icons.add),
                  label: const Text('+1'),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (habit != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(habitIconData(habit.iconName), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      switch (habit.kind) {
                        HabitKind.adhoc => 'Ad-hoc',
                        HabitKind.quantity =>
                          habit.quantityGoal?.summary ?? 'Quantity goal',
                        HabitKind.repeatable =>
                          habit.schedule?.summary ?? 'Repeatable',
                      },
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (isQuantity)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Use the calendar icon to log a past day (up to 7 days before creation).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: streak.when(
              data: (s) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (isQuantity)
                    progress.when(
                      data: (p) => _StatChip(
                        label: 'Progress',
                        value: p == null
                            ? '—'
                            : '${_fmt(p.currentQuantity)}/${_fmt(p.target)}',
                      ),
                      loading: () => const SizedBox(
                        width: 48,
                        child: LinearProgressIndicator(),
                      ),
                      error: (_, _) => const _StatChip(
                        label: 'Progress',
                        value: '—',
                      ),
                    ),
                  _StatChip(label: 'Current', value: '${s.current}'),
                  _StatChip(label: 'Best', value: '${s.best}'),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ),
          if (isQuantity)
            progress.when(
              data: (p) => p == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          p.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          Expanded(
            child: isQuantity
                ? logsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (logs) {
                      if (logs.isEmpty) {
                        return const Center(
                          child: Text('No logs yet. Tap +1 to start.'),
                        );
                      }
                      final fmt = DateFormat.yMMMd().add_jm();
                      return ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return ListTile(
                            title: Text(fmt.format(log.loggedAt)),
                            subtitle: Text('+${_fmt(log.quantity)}'),
                            trailing: IconButton(
                              tooltip: 'Remove log',
                              icon: const Icon(Icons.undo),
                              onPressed: () => ref
                                  .read(habitActionsProvider)
                                  .deleteQuantityLog(log.id),
                            ),
                          );
                        },
                      );
                    },
                  )
                : occAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (occurrences) {
                      if (occurrences.isEmpty) {
                        return const Center(
                          child: Text('No occurrences yet.'),
                        );
                      }
                      final fmt = DateFormat.yMMMd().add_jm();
                      return ListView.builder(
                        itemCount: occurrences.length,
                        itemBuilder: (context, index) {
                          final o = occurrences[index];
                          final allowed = habit == null ||
                              isRetroDateAllowed(habit.createdAt, o.dueAt);
                          final isFuture = dateOnly(o.dueAt).isAfter(today);
                          return ListTile(
                            title: Text(fmt.format(o.dueAt)),
                            subtitle: Text(
                              [
                                o.status.name,
                                if (!allowed) 'outside retro window',
                                if (isFuture) 'future (not in streak yet)',
                              ].join(' · '),
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                if ((o.isPending ||
                                        o.isMissed ||
                                        o.isSkipped) &&
                                    !isFuture) ...[
                                  if (o.isPending)
                                    TextButton(
                                      onPressed: () => ref
                                          .read(habitActionsProvider)
                                          .skipOccurrence(o.id),
                                      child: const Text('Skip'),
                                    ),
                                  if (o.isSkipped)
                                    TextButton(
                                      onPressed: () => ref
                                          .read(habitActionsProvider)
                                          .uncompleteOccurrence(o.id),
                                      child: const Text('Unskip'),
                                    ),
                                  FilledButton(
                                    onPressed: () => _completeOccurrence(
                                      context,
                                      ref,
                                      o.id,
                                      allowed: allowed,
                                    ),
                                    child: const Text('Done'),
                                  ),
                                ] else if (o.isCompleted)
                                  IconButton(
                                    tooltip: 'Undo',
                                    icon: const Icon(Icons.undo),
                                    onPressed: () => ref
                                        .read(habitActionsProvider)
                                        .uncompleteOccurrence(o.id),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOccurrence(
    BuildContext context,
    WidgetRef ref,
    String occurrenceId, {
    required bool allowed,
  }) async {
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(HabitRetroWindowException().message)),
      );
      return;
    }
    try {
      await ref.read(habitActionsProvider).completeOccurrence(occurrenceId);
    } on HabitRetroWindowException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _logQuantityNow(
    BuildContext context,
    WidgetRef ref,
    Habit? habit,
  ) async {
    try {
      await ref.read(habitActionsProvider).logQuantity(habitId: habitId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+1 ${habit?.quantityGoal?.unitLabel ?? 'logged'}',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } on HabitRetroWindowException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _logQuantityForDate(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) async {
    final now = DateTime.now();
    final first = earliestRetroDate(habit.createdAt);
    final last = dateOnly(now);
    if (first.isAfter(last)) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: last,
      firstDate: first,
      lastDate: last,
      helpText: 'Log for date',
    );
    if (picked == null || !context.mounted) return;

    try {
      await ref.read(habitActionsProvider).logQuantity(
            habitId: habitId,
            at: DateTime(picked.year, picked.month, picked.day, 12),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+1 ${habit.quantityGoal?.unitLabel ?? 'logged'} on ${DateFormat.yMMMd().format(picked)}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on HabitRetroWindowException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

String _fmt(num n) {
  if (n is int || n == n.roundToDouble()) return n.round().toString();
  return n.toString();
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}
