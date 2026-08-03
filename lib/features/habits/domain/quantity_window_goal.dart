import 'dart:convert';

/// How logged quantity is compared against [QuantityWindowGoal.target].
enum QuantityComparator {
  gt,
  gte,
  lt,
  lte;

  String get symbol => switch (this) {
        QuantityComparator.gt => '>',
        QuantityComparator.gte => '≥',
        QuantityComparator.lt => '<',
        QuantityComparator.lte => '≤',
      };

  bool evaluate(num actual, num target) => switch (this) {
        QuantityComparator.gt => actual > target,
        QuantityComparator.gte => actual >= target,
        QuantityComparator.lt => actual < target,
        QuantityComparator.lte => actual <= target,
      };
}

/// Length unit for a quantity-window goal.
///
/// - [hour]: rolling wall-clock duration
/// - [day] / [week]: calendar-day windows (week = 7 calendar days)
enum QuantityWindowUnit { hour, day, week }

/// Goal rule: track quantity over a time window, e.g. ">3 glasses in 24 hours".
class QuantityWindowGoal {
  const QuantityWindowGoal({
    this.comparator = QuantityComparator.gt,
    required this.target,
    this.unitLabel = '',
    this.windowSize = 1,
    this.windowUnit = QuantityWindowUnit.day,
  });

  final QuantityComparator comparator;

  /// Threshold compared via [comparator].
  final num target;

  /// Short label for what is counted (e.g. "glasses", "workouts").
  final String unitLabel;

  /// Window length; minimum 1.
  final int windowSize;

  final QuantityWindowUnit windowUnit;

  int get safeWindowSize => windowSize < 1 ? 1 : windowSize;

  /// Calendar days spanned by [day]/[week] windows (for day-based evaluation).
  int get calendarDaySpan {
    switch (windowUnit) {
      case QuantityWindowUnit.hour:
        return 1;
      case QuantityWindowUnit.day:
        return safeWindowSize;
      case QuantityWindowUnit.week:
        return safeWindowSize * 7;
    }
  }

  Duration get rollingDuration {
    switch (windowUnit) {
      case QuantityWindowUnit.hour:
        return Duration(hours: safeWindowSize);
      case QuantityWindowUnit.day:
        return Duration(days: safeWindowSize);
      case QuantityWindowUnit.week:
        return Duration(days: safeWindowSize * 7);
    }
  }

  factory QuantityWindowGoal.fromJson(Map<String, dynamic> json) {
    return QuantityWindowGoal(
      comparator: QuantityComparator.values.firstWhere(
        (c) => c.name == json['comparator'],
        orElse: () => QuantityComparator.gt,
      ),
      target: (json['target'] as num?) ?? 1,
      unitLabel: (json['unitLabel'] as String?) ?? '',
      windowSize: (json['windowSize'] as num?)?.toInt() ?? 1,
      windowUnit: QuantityWindowUnit.values.firstWhere(
        (u) => u.name == json['windowUnit'],
        orElse: () => QuantityWindowUnit.day,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'comparator': comparator.name,
        'target': target,
        'unitLabel': unitLabel,
        'windowSize': safeWindowSize,
        'windowUnit': windowUnit.name,
      };

  String encode() => jsonEncode(toJson());

  static QuantityWindowGoal? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return QuantityWindowGoal.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Human-readable rule, e.g. ">3 glasses / 24 hours".
  String get summary {
    final label = unitLabel.trim().isEmpty ? 'units' : unitLabel.trim();
    final size = safeWindowSize;
    final window = switch (windowUnit) {
      QuantityWindowUnit.hour => size == 1 ? '1 hour' : '$size hours',
      QuantityWindowUnit.day => size == 1 ? '1 day' : '$size days',
      QuantityWindowUnit.week => size == 1 ? '1 week' : '$size weeks',
    };
    return '${comparator.symbol}$target $label / $window';
  }

  /// Progress line like "2/3 glasses in last 24h".
  String progressLabel(num current) {
    final label = unitLabel.trim().isEmpty ? '' : ' ${unitLabel.trim()}';
    final size = safeWindowSize;
    final window = switch (windowUnit) {
      QuantityWindowUnit.hour => 'last ${size}h',
      QuantityWindowUnit.day => size == 1 ? 'today' : 'last $size days',
      QuantityWindowUnit.week => size == 1 ? 'this week' : 'last $size weeks',
    };
    final cur = _fmt(current);
    final tgt = _fmt(target);
    return '$cur/$tgt$label in $window';
  }

  static String _fmt(num n) {
    if (n is int || n == n.roundToDouble()) return n.round().toString();
    return n.toString();
  }

  QuantityWindowGoal copyWith({
    QuantityComparator? comparator,
    num? target,
    String? unitLabel,
    int? windowSize,
    QuantityWindowUnit? windowUnit,
  }) {
    return QuantityWindowGoal(
      comparator: comparator ?? this.comparator,
      target: target ?? this.target,
      unitLabel: unitLabel ?? this.unitLabel,
      windowSize: windowSize ?? this.windowSize,
      windowUnit: windowUnit ?? this.windowUnit,
    );
  }
}
