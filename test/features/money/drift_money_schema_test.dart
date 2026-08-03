import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/core/database/app_database.dart';
import 'package:stat_maxxer/features/money/data/drift_transaction_repository.dart';
import 'package:stat_maxxer/features/money/data/drift_wishlist_repository.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';
import 'package:stat_maxxer/features/money/domain/wishlist_item.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('schemaVersion is 6', () {
    expect(db.schemaVersion, 6);
  });

  test('persists investment and saving transaction types', () async {
    final repo = DriftTransactionRepository(db);
    await repo.addTransaction(
      MoneyTransaction(
        id: 'inv-1',
        amount: 250,
        type: TransactionType.investment,
        category: 'Investment',
        date: DateTime(2026, 8, 1),
      ),
    );
    await repo.addTransaction(
      MoneyTransaction(
        id: 'sav-1',
        amount: 100,
        type: TransactionType.saving,
        category: 'Savings',
        date: DateTime(2026, 8, 2),
      ),
    );

    final txs = await repo.getTransactions();
    expect(
      txs.map((t) => t.type),
      containsAll([TransactionType.investment, TransactionType.saving]),
    );
  });

  test('recurring wishlist survives payment and advances next due', () async {
    final wishlist = DriftWishlistRepository(db);
    final money = DriftTransactionRepository(db);

    await wishlist.addItem(
      WishlistItem(
        id: 'rent',
        name: 'Rent',
        estimatedPrice: 1200,
        createdAt: DateTime(2026, 8, 1),
        isRecurring: true,
        recurrenceInterval: 1,
        recurrenceUnit: WishlistRecurrenceUnit.month,
        nextDue: DateTime(2026, 8, 1),
        targetType: TransactionType.expense,
      ),
    );

    final paidOn = DateTime(2026, 8, 1);
    await money.addTransaction(
      MoneyTransaction(
        id: 'tx-rent',
        amount: 1200,
        type: TransactionType.expense,
        category: 'Rent',
        date: paidOn,
        merchant: 'Rent',
      ),
    );
    await wishlist.recordRecurringPayment(
      id: 'rent',
      transactionId: 'tx-rent',
      nextDue: advanceWishlistDue(
        paidOn,
        interval: 1,
        unit: WishlistRecurrenceUnit.month,
      ),
    );

    final open = await wishlist.getOpenItems();
    expect(open, hasLength(1));
    expect(open.single.nextDue, DateTime(2026, 9, 1));
    expect(open.single.isRecurring, isTrue);
  });
}
