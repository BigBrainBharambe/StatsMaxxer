import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_utils.dart';
import '../domain/habit.dart';
import '../domain/habit_occurrence.dart';
import '../domain/habit_quantity_log.dart';
import '../domain/habit_retro_rules.dart';
import '../domain/quantity_window_streak_calculator.dart';
import 'habits_providers.dart';

const _qtyStreakCalc = QuantityWindowStreakCalculator();

class HabitsCalendarView extends ConsumerWidget {
  const HabitsCalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(calendarMonthProvider);
    final filterId = ref.watch(calendarFilterHabitIdProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final occAsync = ref.watch(allOccurrencesProvider);
    final logsAsync = ref.watch(allQuantityLogsProvider);
    final monthLabel = DateFormat.yMMMM().format(month);
    final now = DateTime.now();
    final today = dateOnly(now);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () =>
                    ref.read(calendarMonthProvider.notifier).prev(),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(calendarMonthProvider.notifier).next(),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        habitsAsync.when(
          data: (habits) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: filterId == null,
                  onSelected: (_) => ref
                      .read(calendarFilterHabitIdProvider.notifier)
                      .setHabitId(null),
                ),
                const SizedBox(width: 8),
                for (final h in habits) ...[
                  FilterChip(
                    label: Text(h.name),
                    selected: filterId == h.id,
                    onSelected: (_) => ref
                        .read(calendarFilterHabitIdProvider.notifier)
                        .setHabitId(h.id),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          loading: () => const SizedBox(height: 48),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: Text('M', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('T', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('W', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('T', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('F', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('S', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('S', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (occAsync.isLoading || logsAsync.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (occAsync.hasError) {
                return Center(child: Text('${occAsync.error}'));
              }
              if (logsAsync.hasError) {
                return Center(child: Text('${logsAsync.error}'));
              }

              final habits = habitsAsync.asData?.value ?? const <Habit>[];
              final occurrences = occAsync.requireValue;
              final logs = logsAsync.requireValue;

              final byDay = <DateTime, List<HabitOccurrence>>{};
              for (final o in occurrences) {
                if (filterId != null && o.habitId != filterId) continue;
                final d = dateOnly(o.dueAt);
                byDay.putIfAbsent(d, () => []).add(o);
              }

              final qtyByDay = <DateTime, List<QuantityCalendarDayMark>>{};
              for (final habit in habits) {
                if (habit.archived || !habit.isQuantityGoal) continue;
                if (filterId != null && habit.id != filterId) continue;
                final goal = habit.quantityGoal;
                if (goal == null) continue;
                final habitLogs =
                    logs.where((l) => l.habitId == habit.id).toList();
                // Mark every day that has logs or is a success day in range.
                final days = <DateTime>{};
                for (final l in habitLogs) {
                  days.add(dateOnly(l.loggedAt));
                }
                for (final day in days) {
                  final logged = _qtyStreakCalc.quantityLoggedOnDay(
                    logs: habitLogs,
                    day: day,
                  );
                  final success = _qtyStreakCalc.isSuccessDay(
                    goal: goal,
                    logs: habitLogs,
                    day: day,
                    now: now,
                  );
                  if (logged <= 0 && !success) continue;
                  qtyByDay.putIfAbsent(day, () => []).add(
                        QuantityCalendarDayMark(
                          habit: habit,
                          loggedQuantity: logged,
                          success: success,
                        ),
                      );
                }
              }

              final first = DateTime(month.year, month.month, 1);
              final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
              final leading = first.weekday - 1; // Mon-first
              final cells = leading + daysInMonth;
              final rows = (cells / 7).ceil();

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: rows * 7,
                itemBuilder: (context, index) {
                  final dayNum = index - leading + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final day = DateTime(month.year, month.month, dayNum);
                  final list = byDay[day] ?? const <HabitOccurrence>[];
                  final qtyMarks =
                      qtyByDay[day] ?? const <QuantityCalendarDayMark>[];
                  final hasCompleted = list.any(
                        (o) => o.status == OccurrenceStatus.completed,
                      ) ||
                      qtyMarks.any((m) => m.success);
                  final hasPending =
                      list.any((o) => o.status == OccurrenceStatus.pending);
                  final hasMissed =
                      list.any((o) => o.status == OccurrenceStatus.missed);
                  final hasLoggedQty =
                      qtyMarks.any((m) => m.hasLog && !m.success);
                  final isToday = isSameDay(day, today);
                  final canInteract = _dayCanInteract(
                    day: day,
                    today: today,
                    list: list,
                    qtyMarks: qtyMarks,
                    habits: habits,
                    filterId: filterId,
                  );

                  Color? bg;
                  if (hasCompleted) {
                    bg = Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.25);
                  } else if (hasMissed) {
                    bg = Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.18);
                  } else if (hasPending || hasLoggedQty) {
                    bg = Theme.of(context)
                        .colorScheme
                        .tertiary
                        .withValues(alpha: 0.2);
                  }

                  final scheme = Theme.of(context).colorScheme;
                  final dots = <Color>[
                    for (final o in list.take(3))
                      switch (o.status) {
                        OccurrenceStatus.completed => scheme.primary,
                        OccurrenceStatus.missed => scheme.error,
                        OccurrenceStatus.pending => scheme.tertiary,
                        OccurrenceStatus.skipped => scheme.outline,
                      },
                    for (final m
                        in qtyMarks.take((3 - list.length).clamp(0, 3)))
                      m.success ? scheme.primary : scheme.secondary,
                  ];

                  return Material(
                    color: bg ??
                        scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: canInteract
                          ? () => _showDaySheet(
                                context,
                                ref,
                                day,
                                list,
                                habits: habits,
                                logs: logs,
                                filterId: filterId,
                              )
                          : null,
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '$dayNum',
                              style: TextStyle(
                                fontWeight:
                                    isToday ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (dots.isNotEmpty)
                            Positioned(
                              bottom: 4,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final color in dots.take(3))
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Days with occurrences/logs, or empty retro-eligible days for quantity habits.
  bool _dayCanInteract({
    required DateTime day,
    required DateTime today,
    required List<HabitOccurrence> list,
    required List<QuantityCalendarDayMark> qtyMarks,
    required List<Habit> habits,
    required String? filterId,
  }) {
    if (list.isNotEmpty || qtyMarks.isNotEmpty) return true;
    if (dateOnly(day).isAfter(today)) return false;
    return _qtyHabitsForDay(
      habits: habits,
      day: day,
      filterId: filterId,
    ).isNotEmpty;
  }

  List<Habit> _qtyHabitsForDay({
    required List<Habit> habits,
    required DateTime day,
    required String? filterId,
  }) {
    return habits.where((h) {
      if (h.archived || !h.isQuantityGoal) return false;
      if (filterId != null && h.id != filterId) return false;
      return isRetroDateAllowed(h.createdAt, day);
    }).toList();
  }

  Future<void> _showDaySheet(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    List<HabitOccurrence> list, {
    required List<Habit> habits,
    required List<HabitQuantityLog> logs,
    required String? filterId,
  }) async {
    final byId = {for (final h in habits) h.id: h};
    final today = dateOnly(DateTime.now());
    final isFutureDay = dateOnly(day).isAfter(today);
    final now = DateTime.now();
    final qtyHabits = _qtyHabitsForDay(
      habits: habits,
      day: day,
      filterId: filterId,
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(DateFormat.yMMMEd().format(day)),
              subtitle: Text(
                [
                  if (list.isNotEmpty) '${list.length} scheduled',
                  if (qtyHabits.isNotEmpty) '${qtyHabits.length} quantity',
                ].join(' · '),
              ),
            ),
            for (final o in list)
              ListTile(
                title: Text(byId[o.habitId]?.name ?? 'Habit'),
                subtitle: Text(
                  isFutureDay
                      ? '${o.status.name} · future (not in streak yet)'
                      : o.status.name,
                ),
                trailing: o.isCompleted
                    ? IconButton(
                        tooltip: 'Undo',
                        icon: const Icon(Icons.undo),
                        onPressed: () {
                          ref
                              .read(habitActionsProvider)
                              .uncompleteOccurrence(o.id);
                          Navigator.pop(context);
                        },
                      )
                    : isFutureDay
                        ? null
                        : FilledButton(
                            onPressed: () async {
                              final habit = byId[o.habitId];
                              if (habit != null &&
                                  !isRetroDateAllowed(
                                    habit.createdAt,
                                    o.dueAt,
                                  )) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        HabitRetroWindowException().message,
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              try {
                                await ref
                                    .read(habitActionsProvider)
                                    .completeOccurrence(o.id);
                                if (context.mounted) Navigator.pop(context);
                              } on HabitRetroWindowException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message)),
                                  );
                                }
                              }
                            },
                            child: const Text('Done'),
                          ),
              ),
            for (final habit in qtyHabits)
              Builder(
                builder: (context) {
                  final goal = habit.quantityGoal!;
                  final habitLogs =
                      logs.where((l) => l.habitId == habit.id).toList();
                  final logged = _qtyStreakCalc.quantityLoggedOnDay(
                    logs: habitLogs,
                    day: day,
                  );
                  final success = _qtyStreakCalc.isSuccessDay(
                    goal: goal,
                    logs: habitLogs,
                    day: day,
                    now: now,
                  );
                  final unit = goal.unitLabel.trim().isEmpty
                      ? 'logged'
                      : goal.unitLabel.trim();
                  return ListTile(
                    title: Text(habit.name),
                    subtitle: Text(
                      [
                        if (logged > 0)
                          '${_fmtQty(logged)} $unit this day'
                        else
                          'No logs this day',
                        if (success) 'goal met',
                        if (!success && logged > 0) 'in progress',
                      ].join(' · '),
                    ),
                    trailing: isFutureDay
                        ? null
                        : FilledButton(
                            onPressed: () async {
                              try {
                                await ref.read(habitActionsProvider).logQuantity(
                                      habitId: habit.id,
                                      at: DateTime(
                                        day.year,
                                        day.month,
                                        day.day,
                                        12,
                                      ),
                                    );
                                if (context.mounted) Navigator.pop(context);
                              } on HabitRetroWindowException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message)),
                                  );
                                }
                              }
                            },
                            child: const Text('+1'),
                          ),
                  );
                },
              ),
            if (list.isEmpty && qtyHabits.isEmpty)
              const ListTile(
                title: Text('Nothing to update for this day'),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

String _fmtQty(num n) {
  if (n is int || n == n.roundToDouble()) return n.round().toString();
  return n.toString();
}
