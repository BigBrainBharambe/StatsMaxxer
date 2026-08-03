enum OccurrenceStatus { pending, completed, skipped, missed }

class HabitOccurrence {
  const HabitOccurrence({
    required this.id,
    required this.habitId,
    required this.dueAt,
    required this.status,
    this.completedAt,
  });

  final String id;
  final String habitId;
  final DateTime dueAt;
  final OccurrenceStatus status;
  final DateTime? completedAt;

  bool get isPending => status == OccurrenceStatus.pending;
  bool get isCompleted => status == OccurrenceStatus.completed;
  bool get isSkipped => status == OccurrenceStatus.skipped;
  bool get isMissed => status == OccurrenceStatus.missed;

  HabitOccurrence copyWith({
    String? id,
    String? habitId,
    DateTime? dueAt,
    OccurrenceStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return HabitOccurrence(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      dueAt: dueAt ?? this.dueAt,
      status: status ?? this.status,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}
