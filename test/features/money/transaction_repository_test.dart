import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/money/data/in_memory_transaction_repository.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';

void main() {
  late InMemoryTransactionRepository repo;

  setUp(() {
    repo = InMemoryTransactionRepository();
  });

  tearDown(() {
    repo.dispose();
  });

  test('adds and deletes transactions', () async {
    await repo.addTransaction(
      MoneyTransaction(
        id: 't1',
        amount: 12.5,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 7, 18),
      ),
    );
    expect(await repo.getTransactions(), hasLength(1));

    await repo.deleteTransaction('t1');
    expect(await repo.getTransactions(), isEmpty);
  });

  test('rejects non-positive amounts', () async {
    expect(
      () => repo.addTransaction(
        MoneyTransaction(
          id: 't1',
          amount: 0,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime(2026, 7, 18),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('watch emits updates', () async {
    final events = <List<MoneyTransaction>>[];
    final sub = repo.watchTransactions().listen(events.add);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.first, isEmpty);

    await repo.addTransaction(
      MoneyTransaction(
        id: 't1',
        amount: 100,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime(2026, 7, 18),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(events.last, hasLength(1));
    await sub.cancel();
  });

  test('batch add skips duplicate external ids', () async {
    await repo.addTransaction(
      MoneyTransaction(
        id: 't1',
        amount: 10,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 7, 18),
        externalId: 'ext-1',
        source: TransactionSource.import,
      ),
    );

    final inserted = await repo.addTransactions([
      MoneyTransaction(
        id: 't2',
        amount: 10,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 7, 18),
        externalId: 'ext-1',
        merchant: 'Cafe',
        source: TransactionSource.import,
      ),
      MoneyTransaction(
        id: 't3',
        amount: 20,
        type: TransactionType.expense,
        category: 'Transport',
        date: DateTime(2026, 7, 19),
        externalId: 'ext-2',
        merchant: 'Uber',
        source: TransactionSource.import,
      ),
    ]);

    expect(inserted, 1);
    final all = await repo.getTransactions();
    expect(all, hasLength(2));
    expect(all.map((t) => t.id), containsAll(['t1', 't3']));
  });

  test('stores investment and saving types', () async {
    await repo.addTransaction(
      MoneyTransaction(
        id: 'inv',
        amount: 500,
        type: TransactionType.investment,
        category: 'Investment',
        date: DateTime(2026, 8, 1),
      ),
    );
    await repo.addTransaction(
      MoneyTransaction(
        id: 'sav',
        amount: 200,
        type: TransactionType.saving,
        category: 'Savings',
        date: DateTime(2026, 8, 2),
      ),
    );
    final all = await repo.getTransactions();
    expect(all.map((t) => t.type), containsAll([
      TransactionType.investment,
      TransactionType.saving,
    ]));
  });

  test('updates an existing transaction', () async {
    await repo.addTransaction(
      MoneyTransaction(
        id: 't1',
        amount: 10,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 7, 18),
        note: 'old',
        merchant: 'Cafe',
      ),
    );

    await repo.updateTransaction(
      MoneyTransaction(
        id: 't1',
        amount: 40,
        type: TransactionType.saving,
        category: 'Savings',
        date: DateTime(2026, 8, 2),
        note: 'new',
        merchant: 'Bank',
      ),
    );

    final updated = (await repo.getTransactions()).single;
    expect(updated.amount, 40);
    expect(updated.type, TransactionType.saving);
    expect(updated.category, 'Savings');
    expect(updated.note, 'new');
    expect(updated.merchant, 'Bank');
    expect(updated.date, DateTime(2026, 8, 2));
  });
}
