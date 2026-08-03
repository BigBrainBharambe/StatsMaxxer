import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/money/data/in_memory_transaction_repository.dart';
import 'package:stat_maxxer/features/money/data/in_memory_wishlist_repository.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';
import 'package:stat_maxxer/features/money/domain/wishlist_item.dart';

void main() {
  late InMemoryWishlistRepository wishlist;
  late InMemoryTransactionRepository money;

  setUp(() {
    wishlist = InMemoryWishlistRepository();
    money = InMemoryTransactionRepository();
  });

  tearDown(() {
    wishlist.dispose();
    money.dispose();
  });

  test('adds and deletes open wishlist items', () async {
    await wishlist.addItem(
      WishlistItem(
        id: 'w1',
        name: 'Headphones',
        notes: 'noise cancelling',
        estimatedPrice: 199.99,
        createdAt: DateTime(2026, 8, 1),
      ),
    );
    expect(await wishlist.getOpenItems(), hasLength(1));

    await wishlist.deleteItem('w1');
    expect(await wishlist.getOpenItems(), isEmpty);
  });

  test('rejects empty name and non-positive estimate', () async {
    expect(
      () => wishlist.addItem(
        WishlistItem(
          id: 'w1',
          name: '  ',
          createdAt: DateTime(2026, 8, 1),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => wishlist.addItem(
        WishlistItem(
          id: 'w2',
          name: 'Thing',
          estimatedPrice: 0,
          createdAt: DateTime(2026, 8, 1),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('markBought removes item from open list', () async {
    await wishlist.addItem(
      WishlistItem(
        id: 'w1',
        name: 'Keyboard',
        estimatedPrice: 80,
        createdAt: DateTime(2026, 8, 1),
      ),
    );

    await wishlist.markBought(
      id: 'w1',
      transactionId: 't1',
      boughtAt: DateTime(2026, 8, 2),
    );

    expect(await wishlist.getOpenItems(), isEmpty);
  });

  test('buy flow creates expense and clears wishlist item', () async {
    final item = WishlistItem(
      id: 'w1',
      name: 'Monitor',
      notes: '27 inch',
      estimatedPrice: 300,
      createdAt: DateTime(2026, 8, 1),
    );
    await wishlist.addItem(item);

    const txId = 'tx-1';
    final boughtOn = DateTime(2026, 8, 2, 14, 30);
    await money.addTransaction(
      MoneyTransaction(
        id: txId,
        amount: 289.5,
        type: TransactionType.expense,
        category: 'Shopping',
        date: boughtOn,
        note: item.notes,
        merchant: item.name,
      ),
    );
    await wishlist.markBought(
      id: item.id,
      transactionId: txId,
      boughtAt: boughtOn,
    );

    final txs = await money.getTransactions();
    expect(txs, hasLength(1));
    expect(txs.first.amount, 289.5);
    expect(txs.first.type, TransactionType.expense);
    expect(txs.first.merchant, 'Monitor');
    expect(txs.first.date, boughtOn);
    expect(await wishlist.getOpenItems(), isEmpty);
  });

  test('recurring payment keeps item open and advances next due', () async {
    final item = WishlistItem(
      id: 'rent',
      name: 'Rent',
      estimatedPrice: 1200,
      createdAt: DateTime(2026, 8, 1),
      isRecurring: true,
      recurrenceInterval: 1,
      recurrenceUnit: WishlistRecurrenceUnit.month,
      nextDue: DateTime(2026, 8, 1),
      targetType: TransactionType.expense,
    );
    await wishlist.addItem(item);

    final paidOn = DateTime(2026, 8, 1);
    const txId = 'tx-rent-1';
    await money.addTransaction(
      MoneyTransaction(
        id: txId,
        amount: 1200,
        type: TransactionType.expense,
        category: 'Rent',
        date: paidOn,
        merchant: item.name,
      ),
    );
    final nextDue = advanceWishlistDue(
      paidOn,
      interval: 1,
      unit: WishlistRecurrenceUnit.month,
    );
    await wishlist.recordRecurringPayment(
      id: item.id,
      transactionId: txId,
      nextDue: nextDue,
    );

    final open = await wishlist.getOpenItems();
    expect(open, hasLength(1));
    expect(open.first.nextDue, DateTime(2026, 9, 1));
    expect(open.first.transactionId, txId);
    expect(open.first.isBought, isFalse);
  });

  test('recurring investment target is stored', () async {
    await wishlist.addItem(
      WishlistItem(
        id: 'sip',
        name: 'Index fund SIP',
        estimatedPrice: 500,
        createdAt: DateTime(2026, 8, 1),
        isRecurring: true,
        recurrenceInterval: 1,
        recurrenceUnit: WishlistRecurrenceUnit.month,
        nextDue: DateTime(2026, 8, 5),
        targetType: TransactionType.investment,
      ),
    );
    final open = await wishlist.getOpenItems();
    expect(open.single.targetType, TransactionType.investment);
    expect(open.single.recurrenceSummary, 'Monthly');
  });

  test('rejects recurring without interval/unit', () async {
    expect(
      () => wishlist.addItem(
        WishlistItem(
          id: 'bad',
          name: 'Bad recurring',
          createdAt: DateTime(2026, 8, 1),
          isRecurring: true,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('advanceWishlistDue handles month overflow', () {
    final from = DateTime(2026, 1, 31);
    final next = advanceWishlistDue(
      from,
      interval: 1,
      unit: WishlistRecurrenceUnit.month,
    );
    expect(next, DateTime(2026, 2, 28));
  });

  test('watch emits open-item updates', () async {
    final events = <List<WishlistItem>>[];
    final sub = wishlist.watchOpenItems().listen(events.add);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.first, isEmpty);

    await wishlist.addItem(
      WishlistItem(
        id: 'w1',
        name: 'Cable',
        createdAt: DateTime(2026, 8, 1),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(events.last, hasLength(1));
    await sub.cancel();
  });
}
