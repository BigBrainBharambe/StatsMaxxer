import '../../../core/utils/date_utils.dart';
import 'habit_occurrence.dart';
import 'occurrence_day_collapse.dart';

class StreakResult {
  const StreakResult({required this.current, required this.best});

  final int current;
  final int best;
}

/// Streaks from due occurrences only (one effective status per calendar day).
///
/// - [OccurrenceStatus.completed] counts toward streak
/// - [OccurrenceStatus.skipped] is ignored (does not break, does not count)
/// - [OccurrenceStatus.missed] breaks the current streak
/// - Pending today does not break; pending past should be marked missed first
///
/// Same calendar day may have duplicate rows (e.g. midnight migrate + reminder
/// re-sync). Those collapse with priority:
/// completed > skipped > missed > pending.
class StreakCalculator {
  const StreakCalculator();

  StreakResult calculate(
    List<HabitOccurrence> occurrences, {
    required DateTime today,
  }) {
    final todayDate = dateOnly(today);
    final relevant = occurrences
        .where((o) => !dateOnly(o.dueAt).isAfter(todayDate))
        .toList();

    if (relevant.isEmpty) {
      return const StreakResult(current: 0, best: 0);
    }

    final collapsed = collapseOccurrencesByCalendarDay(relevant);
    final current = _currentStreak(collapsed, todayDate);
    final best = _bestStreak(collapsed);
    // Retro completes can reconnect an ending run; keep best ≥ current.
    return StreakResult(
      current: current,
      best: best < current ? current : best,
    );
  }

  int _currentStreak(List<HabitOccurrence> sortedAsc, DateTime today) {
    // Walk newest → oldest
    final desc = sortedAsc.reversed.toList();
    var i = 0;

    // If the latest due (today or most recent) is still pending today, skip it
    if (desc.isNotEmpty) {
      final latest = desc.first;
      if (latest.status == OccurrenceStatus.pending &&
          isSameDay(latest.dueAt, today)) {
        i = 1;
      }
    }

    var streak = 0;
    for (; i < desc.length; i++) {
      final o = desc[i];
      if (o.status == OccurrenceStatus.skipped) continue;
      if (o.status == OccurrenceStatus.completed) {
        streak++;
        continue;
      }
      // missed or past pending — breaks current (retro complete of a miss
      // reconnects once status becomes completed).
      break;
    }
    return streak;
  }

  int _bestStreak(List<HabitOccurrence> sortedAsc) {
    var best = 0;
    var run = 0;
    for (final o in sortedAsc) {
      if (o.status == OccurrenceStatus.skipped) continue;
      if (o.status == OccurrenceStatus.completed) {
        run++;
        if (run > best) best = run;
      } else {
        // missed / pending: gap. Retro-marking a miss to completed rejoins runs.
        run = 0;
      }
    }
    return best;
  }
}
