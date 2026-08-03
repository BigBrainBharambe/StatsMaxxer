import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stat_maxxer/app.dart';
import 'package:stat_maxxer/core/providers.dart';
import 'package:stat_maxxer/features/habits/data/in_memory_habit_repository.dart';
import 'package:stat_maxxer/features/money/data/in_memory_transaction_repository.dart';
import 'package:stat_maxxer/features/money/data/in_memory_wishlist_repository.dart';
import 'package:stat_maxxer/features/settings/presentation/theme_provider.dart';

Future<ProviderContainer> createTestContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final habits = InMemoryHabitRepository();
  final money = InMemoryTransactionRepository();
  final wishlist = InMemoryWishlistRepository();

  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      habitRepositoryProvider.overrideWithValue(habits),
      transactionRepositoryProvider.overrideWithValue(money),
      wishlistRepositoryProvider.overrideWithValue(wishlist),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('can add a repeatable habit and complete today', (tester) async {
    final container = await createTestContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StatMaxxerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('All clear'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Exercise');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsWidgets);
  });

  testWidgets('can add and delete a money transaction', (tester) async {
    final container = await createTestContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StatMaxxerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No transactions yet'),
      findsOneWidget,
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '42.5');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);

    await tester.drag(find.text('Food'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No transactions yet'),
      findsOneWidget,
    );
  });

  testWidgets('can add wishlist item and mark as bought', (tester) async {
    final container = await createTestContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StatMaxxerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Wishlist'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wishlist is empty'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add wishlist item'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Headphones');
    await tester.enterText(fields.at(1), '99.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Headphones'), findsOneWidget);
    expect(find.text('Bought'), findsOneWidget);

    await tester.tap(find.text('Bought'));
    await tester.pumpAndSettle();

    expect(find.text('Mark as bought'), findsOneWidget);
    await tester.tap(find.text('Add to ledger'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wishlist is empty'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Money'));
    await tester.pumpAndSettle();

    expect(find.text('Headphones'), findsOneWidget);
  });

  testWidgets('theme setting switches to dark mode', (tester) async {
    final container = await createTestContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StatMaxxerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
  });
}
