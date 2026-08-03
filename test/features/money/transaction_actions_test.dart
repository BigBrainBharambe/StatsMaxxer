import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/core/providers.dart';
import 'package:stat_maxxer/features/money/data/in_memory_transaction_repository.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';
import 'package:stat_maxxer/features/money/presentation/money_providers.dart';

void main() {
  late InMemoryTransactionRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = InMemoryTransactionRepository();
    container = ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    repo.dispose();
  });

  test('update changes amount type category date note merchant', () async {
    await repo.addTransaction(
      MoneyTransaction(
        id: 't1',
        amount: 10,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 7, 18),
        note: 'lunch',
        merchant: 'Cafe',
      ),
    );

    await container.read(transactionActionsProvider).update(
          existing: (await repo.getTransactions()).single,
          amount: 25.5,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime(2026, 8, 1),
          note: 'bonus',
          merchant: 'Acme',
        );

    final updated = (await repo.getTransactions()).single;
    expect(updated.id, 't1');
    expect(updated.amount, 25.5);
    expect(updated.type, TransactionType.income);
    expect(updated.category, 'Salary');
    expect(updated.date, DateTime(2026, 8, 1));
    expect(updated.note, 'bonus');
    expect(updated.merchant, 'Acme');
  });

  test('delete removes transaction via actions', () async {
    await container.read(transactionActionsProvider).add(
          amount: 12,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime(2026, 7, 18),
        );
    final id = (await repo.getTransactions()).single.id;

    await container.read(transactionActionsProvider).delete(id);
    expect(await repo.getTransactions(), isEmpty);
  });

  test('update rejects non-positive amount', () async {
    final existing = MoneyTransaction(
      id: 't1',
      amount: 10,
      type: TransactionType.expense,
      category: 'Food',
      date: DateTime(2026, 7, 18),
    );
    await repo.addTransaction(existing);

    expect(
      () => container.read(transactionActionsProvider).update(
            existing: existing,
            amount: 0,
            type: TransactionType.expense,
            category: 'Food',
            date: DateTime(2026, 7, 18),
          ),
      throwsArgumentError,
    );
  });
}
