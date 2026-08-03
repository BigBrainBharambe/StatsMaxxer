import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/widgets/home_screen_widget_snapshot.dart';

void main() {
  test('habits progress line formats done/total', () {
    expect(
      HomeScreenWidgetSnapshot.habitsProgressLine(done: 3, total: 5),
      '3/5 done',
    );
    expect(
      HomeScreenWidgetSnapshot.habitsProgressLine(done: 0, total: 0),
      'No habits yet',
    );
  });

  test('streak and money lines are labeled', () {
    expect(
      HomeScreenWidgetSnapshot.streakLineFor(12),
      'Top streak: 12',
    );
    expect(
      HomeScreenWidgetSnapshot.moneyLineFor(r'$42.00'),
      r'Net: $42.00',
    );
  });
}
