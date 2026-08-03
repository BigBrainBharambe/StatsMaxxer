import 'dart:convert';

import 'quantity_window_goal.dart';

enum HabitKind {
  adhoc,
  repeatable,

  /// Track quantity over a time window (e.g. >3 glasses in 24 hours).
  quantity,
}

enum ScheduleUnit { day, week, month, year }

class HabitSchedule {
  const HabitSchedule({
    this.interval = 1,
    this.unit = ScheduleUnit.day,
    this.weekdays = const [],
    this.monthDays = const [],
    this.month,
    this.day,
  });

  /// Every N units (minimum 1).
  final int interval;
  final ScheduleUnit unit;

  /// DateTime.weekday values (1=Mon … 7=Sun). Used when [unit] is week.
  final List<int> weekdays;

  /// Days of month 1–31. Used when [unit] is month.
  final List<int> monthDays;

  /// Month 1–12 and day for yearly schedules.
  final int? month;
  final int? day;

  static HabitSchedule daily() => const HabitSchedule();

  factory HabitSchedule.fromJson(Map<String, dynamic> json) {
    return HabitSchedule(
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      unit: ScheduleUnit.values.firstWhere(
        (u) => u.name == json['unit'],
        orElse: () => ScheduleUnit.day,
      ),
      weekdays: (json['weekdays'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      monthDays: (json['monthDays'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      month: (json['month'] as num?)?.toInt(),
      day: (json['day'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'interval': interval,
        'unit': unit.name,
        if (weekdays.isNotEmpty) 'weekdays': weekdays,
        if (monthDays.isNotEmpty) 'monthDays': monthDays,
        if (month != null) 'month': month,
        if (day != null) 'day': day,
      };

  String encode() => jsonEncode(toJson());

  static HabitSchedule? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return HabitSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  String get summary {
    final n = interval < 1 ? 1 : interval;
    switch (unit) {
      case ScheduleUnit.day:
        return n == 1 ? 'Every day' : 'Every $n days';
      case ScheduleUnit.week:
        final days = weekdays.isEmpty
            ? 'week'
            : weekdays.map(_weekdayLabel).join('/');
        return n == 1 ? 'Every $days' : 'Every $n weeks · $days';
      case ScheduleUnit.month:
        final md = monthDays.isEmpty ? 'month' : 'day ${monthDays.join(', ')}';
        return n == 1 ? 'Monthly · $md' : 'Every $n months · $md';
      case ScheduleUnit.year:
        if (month != null && day != null) {
          return n == 1
              ? 'Yearly · $month/$day'
              : 'Every $n years · $month/$day';
        }
        return n == 1 ? 'Yearly' : 'Every $n years';
    }
  }

  static String _weekdayLabel(int d) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (d < 1 || d > 7) return '?';
    return labels[d - 1];
  }
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.createdAt,
    this.archived = false,
    this.kind = HabitKind.repeatable,
    this.schedule,
    this.quantityGoal,
    this.reminderTimeMinutes,
    this.colorValue,
    this.iconName = 'fitness_center',
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool archived;
  final HabitKind kind;
  final HabitSchedule? schedule;

  /// Present when [kind] is [HabitKind.quantity].
  final QuantityWindowGoal? quantityGoal;

  final int? reminderTimeMinutes;
  final int? colorValue;
  final String iconName;

  bool get isQuantityGoal =>
      kind == HabitKind.quantity && quantityGoal != null;

  Habit copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    bool? archived,
    HabitKind? kind,
    HabitSchedule? schedule,
    QuantityWindowGoal? quantityGoal,
    int? reminderTimeMinutes,
    int? colorValue,
    String? iconName,
    bool clearReminder = false,
    bool clearSchedule = false,
    bool clearQuantityGoal = false,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
      kind: kind ?? this.kind,
      schedule: clearSchedule ? null : (schedule ?? this.schedule),
      quantityGoal:
          clearQuantityGoal ? null : (quantityGoal ?? this.quantityGoal),
      reminderTimeMinutes: clearReminder
          ? null
          : (reminderTimeMinutes ?? this.reminderTimeMinutes),
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
    );
  }
}
