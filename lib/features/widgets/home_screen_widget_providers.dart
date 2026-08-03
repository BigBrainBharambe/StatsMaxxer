import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../habits/domain/habit_occurrence.dart';
import '../habits/presentation/habits_providers.dart';
import '../money/presentation/money_format.dart';
import '../money/presentation/money_providers.dart';
import 'home_screen_widget_snapshot.dart';

/// Derives widget text from existing habit/money providers (no schema changes).
final homeScreenWidgetSnapshotProvider =
    Provider<HomeScreenWidgetSnapshot>((ref) {
  final questsAsync = ref.watch(todayQuestsProvider);
  final topStreak = ref.watch(topStreakProvider).asData?.value;
  final totals = ref.watch(periodTotalsProvider).asData?.value;
  final format = ref.watch(moneyFormatProvider);

  final quests = questsAsync.asData?.value;
  if (quests == null) {
    return HomeScreenWidgetSnapshot.empty;
  }

  var done = 0;
  for (final q in quests) {
    if (q.isQuantity) {
      final met = ref
              .watch(habitQuantityProgressProvider(q.habit.id))
              .asData
              ?.value
              ?.met ==
          true;
      if (met) done++;
    } else if (q.occurrence?.status == OccurrenceStatus.completed) {
      done++;
    }
  }

  return HomeScreenWidgetSnapshot(
    title: 'Today',
    habitsLine: HomeScreenWidgetSnapshot.habitsProgressLine(
      done: done,
      total: quests.length,
    ),
    streakLine: HomeScreenWidgetSnapshot.streakLineFor(topStreak ?? 0),
    moneyLine: HomeScreenWidgetSnapshot.moneyLineFor(
      totals == null ? '—' : format.format(totals.net),
    ),
  );
});
