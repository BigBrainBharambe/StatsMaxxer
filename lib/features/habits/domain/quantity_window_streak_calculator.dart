import '../../../core/utils/date_utils.dart';
import 'habit_quantity_log.dart';
import 'quantity_window_goal.dart';
import 'streak_calculator.dart';

class QuantityWindowProgress {
  const QuantityWindowProgress({
    required this.currentQuantity,
    required this.target,
    required this.met,
    required this.label,
  });

  final num currentQuantity;
  final num target;
  final bool met;
  final String label;
}

/// Streak + progress for [QuantityWindowGoal] habits.
///
/// ## Window semantics
///
/// **Hours** — rolling wall-clock window ending at [now] (progress) or at
/// end-of-day / [now] for historical success-day checks.
///
/// **Days / weeks** — calendar-day windows. A window of size N days ending on
/// calendar day D includes logs whose `dateOnly` is in
/// `[D - (N-1), D]` inclusive. Weeks use `N * 7` calendar days.
///
/// ## Success day
///
/// Calendar day D is a *success day* when the quantity in the window ending on
/// D meets the goal comparator/target. For today, the window ends at [now]
/// (hour goals) or includes today's logs so far (day/week goals).
///
/// ## Streak
///
/// Walk calendar days from today backward:
/// - If today is not yet a success, skip it (in-progress, like pending dues).
/// - Each prior success day increments the streak.
/// - The first non-success day breaks the current streak.
/// - Best streak is the longest run of consecutive success days overall
///   (from habit creation through today).
class QuantityWindowStreakCalculator {
  const QuantityWindowStreakCalculator();

  QuantityWindowProgress progress({
    required QuantityWindowGoal goal,
    required List<HabitQuantityLog> logs,
    required DateTime now,
  }) {
    final qty = _quantityInWindowEnding(goal: goal, logs: logs, end: now);
    return QuantityWindowProgress(
      currentQuantity: qty,
      target: goal.target,
      met: goal.comparator.evaluate(qty, goal.target),
      label: goal.progressLabel(qty),
    );
  }

  StreakResult calculate({
    required QuantityWindowGoal goal,
    required List<HabitQuantityLog> logs,
    required DateTime now,
    DateTime? since,
  }) {
    final today = dateOnly(now);
    final start = dateOnly(since ?? today);
    if (start.isAfter(today)) {
      return const StreakResult(current: 0, best: 0);
    }

    final successDays = <DateTime>{};
    for (var d = start; !d.isAfter(today); d = dateOnly(d.add(const Duration(days: 1)))) {
      final day = dateOnly(d);
      final end = isSameDay(day, today) ? now : _endOfDay(day);
      if (_isSuccessAt(goal: goal, logs: logs, day: day, end: end)) {
        successDays.add(day);
      }
    }

    final current = _currentStreak(successDays, today);
    final best = _bestStreak(successDays, start, today);
    // Retro logs can reconnect success days; keep best ≥ current.
    return StreakResult(
      current: current,
      best: best < current ? current : best,
    );
  }

  bool isSuccessDay({
    required QuantityWindowGoal goal,
    required List<HabitQuantityLog> logs,
    required DateTime day,
    required DateTime now,
  }) {
    final d = dateOnly(day);
    final end = isSameDay(d, dateOnly(now)) ? now : _endOfDay(d);
    return _isSuccessAt(goal: goal, logs: logs, day: d, end: end);
  }

  /// Sum of log quantities whose calendar day equals [day].
  num quantityLoggedOnDay({
    required List<HabitQuantityLog> logs,
    required DateTime day,
  }) {
    final d = dateOnly(day);
    num sum = 0;
    for (final log in logs) {
      if (isSameDay(log.loggedAt, d)) sum += log.quantity;
    }
    return sum;
  }

  bool _isSuccessAt({
    required QuantityWindowGoal goal,
    required List<HabitQuantityLog> logs,
    required DateTime day,
    required DateTime end,
  }) {
    final qty = goal.windowUnit == QuantityWindowUnit.hour
        ? _quantityInRollingWindow(
            logs: logs,
            end: end,
            duration: goal.rollingDuration,
          )
        : _quantityInCalendarWindow(
            logs: logs,
            endDay: dateOnly(day),
            daySpan: goal.calendarDaySpan,
          );
    return goal.comparator.evaluate(qty, goal.target);
  }

  num _quantityInWindowEnding({
    required QuantityWindowGoal goal,
    required List<HabitQuantityLog> logs,
    required DateTime end,
  }) {
    if (goal.windowUnit == QuantityWindowUnit.hour) {
      return _quantityInRollingWindow(
        logs: logs,
        end: end,
        duration: goal.rollingDuration,
      );
    }
    return _quantityInCalendarWindow(
      logs: logs,
      endDay: dateOnly(end),
      daySpan: goal.calendarDaySpan,
    );
  }

  num _quantityInRollingWindow({
    required List<HabitQuantityLog> logs,
    required DateTime end,
    required Duration duration,
  }) {
    final start = end.subtract(duration);
    num sum = 0;
    for (final log in logs) {
      // Half-open [start, end]: include logs at `end` for "as of now" progress.
      if (!log.loggedAt.isBefore(start) && !log.loggedAt.isAfter(end)) {
        sum += log.quantity;
      }
    }
    return sum;
  }

  num _quantityInCalendarWindow({
    required List<HabitQuantityLog> logs,
    required DateTime endDay,
    required int daySpan,
  }) {
    final startDay = endDay.subtract(Duration(days: daySpan - 1));
    num sum = 0;
    for (final log in logs) {
      final d = dateOnly(log.loggedAt);
      if (!d.isBefore(startDay) && !d.isAfter(endDay)) {
        sum += log.quantity;
      }
    }
    return sum;
  }

  int _currentStreak(Set<DateTime> successDays, DateTime today) {
    var day = dateOnly(today);
    // In-progress today: skip if not yet successful (mirrors pending due).
    if (!successDays.contains(day)) {
      day = dateOnly(day.subtract(const Duration(days: 1)));
    }
    var streak = 0;
    while (successDays.contains(day)) {
      streak++;
      day = dateOnly(day.subtract(const Duration(days: 1)));
    }
    return streak;
  }

  int _bestStreak(Set<DateTime> successDays, DateTime start, DateTime today) {
    var best = 0;
    var run = 0;
    for (var d = dateOnly(start);
        !d.isAfter(today);
        d = dateOnly(d.add(const Duration(days: 1)))) {
      if (successDays.contains(d)) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  DateTime _endOfDay(DateTime day) {
    final d = dateOnly(day);
    return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
  }
}
