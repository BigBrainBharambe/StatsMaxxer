class HabitQuantityLog {
  const HabitQuantityLog({
    required this.id,
    required this.habitId,
    required this.loggedAt,
    this.quantity = 1,
  });

  final String id;
  final String habitId;
  final DateTime loggedAt;

  /// Amount added in this log entry (usually 1).
  final num quantity;

  HabitQuantityLog copyWith({
    String? id,
    String? habitId,
    DateTime? loggedAt,
    num? quantity,
  }) {
    return HabitQuantityLog(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      loggedAt: loggedAt ?? this.loggedAt,
      quantity: quantity ?? this.quantity,
    );
  }
}
