import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/habits/domain/habit_retro_rules.dart';

void main() {
  group('habit retro window', () {
    final created = DateTime(2026, 7, 18, 15, 30);

    test('earliestRetroDate is createdAt date minus 7 days inclusive', () {
      expect(earliestRetroDate(created), DateTime(2026, 7, 11));
    });

    test('allows the earliest day and creation day', () {
      expect(isRetroDateAllowed(created, DateTime(2026, 7, 11)), isTrue);
      expect(isRetroDateAllowed(created, DateTime(2026, 7, 18)), isTrue);
      expect(isRetroDateAllowed(created, DateTime(2026, 7, 20)), isTrue);
    });

    test('rejects more than 7 days before creation', () {
      expect(isRetroDateAllowed(created, DateTime(2026, 7, 10)), isFalse);
      expect(
        () => ensureRetroDateAllowed(created, DateTime(2026, 7, 10)),
        throwsA(isA<HabitRetroWindowException>()),
      );
    });
  });
}
