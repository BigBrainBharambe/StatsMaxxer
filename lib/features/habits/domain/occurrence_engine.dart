import '../../../core/utils/date_utils.dart';
import 'habit.dart';

/// Expands a [HabitSchedule] into concrete due dates within a range.
class OccurrenceEngine {
  const OccurrenceEngine();

  /// Inclusive [from], exclusive [to] date-only bounds.
  List<DateTime> dueDatesInRange({
    required HabitSchedule schedule,
    required DateTime from,
    required DateTime to,
    DateTime? anchor,
  }) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    if (!end.isAfter(start)) return const [];

    final base = dateOnly(anchor ?? start);
    final results = <DateTime>[];

    switch (schedule.unit) {
      case ScheduleUnit.day:
        results.addAll(_everyNDays(schedule.interval, start, end, base));
      case ScheduleUnit.week:
        results.addAll(_weekly(schedule, start, end, base));
      case ScheduleUnit.month:
        results.addAll(_monthly(schedule, start, end, base));
      case ScheduleUnit.year:
        results.addAll(_yearly(schedule, start, end, base));
    }

    return results;
  }

  bool isDueOn({
    required HabitSchedule schedule,
    required DateTime day,
    DateTime? anchor,
  }) {
    final d = dateOnly(day);
    final dates = dueDatesInRange(
      schedule: schedule,
      from: d,
      to: d.add(const Duration(days: 1)),
      anchor: anchor,
    );
    return dates.any((x) => isSameDay(x, d));
  }

  List<DateTime> _everyNDays(
    int interval,
    DateTime start,
    DateTime end,
    DateTime anchor,
  ) {
    final n = interval < 1 ? 1 : interval;
    var cursor = anchor;
    // Walk back to on/before start
    while (cursor.isAfter(start)) {
      cursor = cursor.subtract(Duration(days: n));
    }
    while (cursor.isBefore(start)) {
      cursor = cursor.add(Duration(days: n));
    }
    final out = <DateTime>[];
    while (cursor.isBefore(end)) {
      out.add(cursor);
      cursor = cursor.add(Duration(days: n));
    }
    return out;
  }

  List<DateTime> _weekly(
    HabitSchedule schedule,
    DateTime start,
    DateTime end,
    DateTime anchor,
  ) {
    final n = schedule.interval < 1 ? 1 : schedule.interval;
    final days = schedule.weekdays.isEmpty
        ? <int>[anchor.weekday]
        : (List<int>.from(schedule.weekdays)..sort());

    // Anchor week: Monday of anchor week
    final anchorWeekStart = daysAgo(anchor, anchor.weekday - 1);
    final out = <DateTime>[];

    // Find first week start on/before range that aligns with interval
    var weekStart = daysAgo(start, start.weekday - 1);
    while (true) {
      final weekIndex =
          weekStart.difference(anchorWeekStart).inDays ~/ 7;
      if (weekIndex >= 0 && weekIndex % n == 0) break;
      if (weekStart.isBefore(anchorWeekStart) &&
          ((anchorWeekStart.difference(weekStart).inDays ~/ 7) % n == 0)) {
        break;
      }
      weekStart = weekStart.subtract(const Duration(days: 7));
      // Safety
      if (weekStart.isBefore(anchorWeekStart.subtract(const Duration(days: 400)))) {
        weekStart = anchorWeekStart;
        break;
      }
    }

    // Simpler approach: iterate each day in range and filter
    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      if (!days.contains(d.weekday)) continue;
      final thisWeekStart = daysAgo(d, d.weekday - 1);
      final weeks =
          thisWeekStart.difference(anchorWeekStart).inDays ~/ 7;
      if (weeks < 0) continue;
      if (weeks % n == 0) {
        out.add(d);
      }
    }
    return out;
  }

  List<DateTime> _monthly(
    HabitSchedule schedule,
    DateTime start,
    DateTime end,
    DateTime anchor,
  ) {
    final n = schedule.interval < 1 ? 1 : schedule.interval;
    final monthDays = schedule.monthDays.isEmpty
        ? <int>[anchor.day]
        : (List<int>.from(schedule.monthDays)..sort());

    final out = <DateTime>[];
    var year = start.year;
    var month = start.month;

    while (true) {
      final monthsFromAnchor =
          (year - anchor.year) * 12 + (month - anchor.month);
      if (monthsFromAnchor >= 0 && monthsFromAnchor % n == 0) {
        for (final day in monthDays) {
          final lastDay = DateTime(year, month + 1, 0).day;
          if (day < 1 || day > lastDay) continue;
          final d = DateTime(year, month, day);
          if (!d.isBefore(start) && d.isBefore(end)) {
            out.add(d);
          }
        }
      }
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
      if (DateTime(year, month).isAfter(end)) break;
    }
    return out;
  }

  List<DateTime> _yearly(
    HabitSchedule schedule,
    DateTime start,
    DateTime end,
    DateTime anchor,
  ) {
    final n = schedule.interval < 1 ? 1 : schedule.interval;
    final m = schedule.month ?? anchor.month;
    final d = schedule.day ?? anchor.day;
    final out = <DateTime>[];

    for (var year = start.year; year <= end.year; year++) {
      final years = year - anchor.year;
      if (years < 0) continue;
      if (years % n != 0) continue;
      final lastDay = DateTime(year, m + 1, 0).day;
      if (d < 1 || d > lastDay) continue;
      final date = DateTime(year, m, d);
      if (!date.isBefore(start) && date.isBefore(end)) {
        out.add(date);
      }
    }
    return out;
  }
}
