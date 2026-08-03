import '../domain/habit.dart';
import '../domain/habit_occurrence.dart';

typedef NotificationTapCallback = void Function(String? payload);

/// Habit reminder scheduler.
///
/// Desktop Windows builds omit `flutter_local_notifications` because that
/// plugin requires the Visual Studio C++ ATL headers. This implementation is a
/// safe no-op that keeps the habit reminder API intact; wire a mobile-backed
/// implementation when targeting Android/iOS with ATL-capable tooling.
class HabitNotificationScheduler {
  bool _initialized = false;
  NotificationTapCallback? onTap;

  Future<void> initialize({NotificationTapCallback? onNotificationTap}) async {
    if (_initialized) return;
    onTap = onNotificationTap;
    _initialized = true;
  }

  Future<void> cancelHabit(String habitId) async {}

  Future<void> rescheduleHabit({
    required Habit habit,
    required List<HabitOccurrence> upcomingPending,
  }) async {
    if (!_initialized) await initialize();
    // No-op on this platform build: reminders are stored on the habit and
    // shown in-app via Today's quest list.
  }
}
