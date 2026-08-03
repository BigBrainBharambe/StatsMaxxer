import '../../../core/utils/date_utils.dart';

/// How many calendar days before [Habit.createdAt] may be retro-marked.
const int kHabitRetroDaysBeforeCreation = 7;

/// Thrown when a complete/log targets a day before the allowed retro window.
class HabitRetroWindowException implements Exception {
  HabitRetroWindowException([
    this.message =
        'You can only mark or log this habit from 7 days before it was created onward.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Earliest calendar day (inclusive) that may be completed or logged for a
/// habit created on [createdAt].
DateTime earliestRetroDate(DateTime createdAt) {
  return dateOnly(createdAt)
      .subtract(const Duration(days: kHabitRetroDaysBeforeCreation));
}

/// Whether [day] is on or after [earliestRetroDate] for [createdAt].
bool isRetroDateAllowed(DateTime createdAt, DateTime day) {
  return !dateOnly(day).isBefore(earliestRetroDate(createdAt));
}

/// Throws [HabitRetroWindowException] when [day] is before the retro window.
void ensureRetroDateAllowed(DateTime createdAt, DateTime day) {
  if (!isRetroDateAllowed(createdAt, day)) {
    throw HabitRetroWindowException();
  }
}
