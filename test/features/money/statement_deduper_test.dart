import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';
import 'package:stat_maxxer/features/money/import/statement_deduper.dart';
import 'package:stat_maxxer/features/money/import/statement_row.dart';

void main() {
  late StatementDeduper deduper;

  setUp(() {
    deduper = StatementDeduper();
  });

  test('marks exact externalId as already imported', () {
    final existing = [
      MoneyTransaction(
        id: '1',
        amount: 10,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 7, 18),
        externalId: 'ofx:ABC',
        merchant: 'Cafe',
      ),
    ];
    final rows = [
      StatementRow(
        date: DateTime(2026, 7, 18),
        amount: 10,
        type: TransactionType.expense,
        description: 'Cafe',
        externalId: 'ofx:ABC',
      ),
    ];

    final result = deduper.match(rows: rows, existing: existing);
    expect(result.single.status, DedupStatus.alreadyImported);
    expect(result.single.selected, isFalse);
  });

  test('marks likely duplicate by date amount and description', () {
    final existing = [
      MoneyTransaction(
        id: '1',
        amount: 12.5,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 7, 18),
        note: 'Starbucks downtown',
      ),
    ];
    final rows = [
      StatementRow(
        date: DateTime(2026, 7, 18),
        amount: 12.5,
        type: TransactionType.expense,
        description: 'STARBUCKS STORE 99',
        externalId: 'fp1',
      ),
    ];

    final result = deduper.match(rows: rows, existing: existing);
    expect(result.single.status, DedupStatus.likelyDuplicate);
    expect(result.single.selected, isFalse);
    expect(result.single.matchedTransaction?.id, '1');
  });

  test('marks unmatched rows as new', () {
    final existing = [
      MoneyTransaction(
        id: '1',
        amount: 50,
        type: TransactionType.expense,
        category: 'Rent',
        date: DateTime(2026, 7, 1),
        merchant: 'Landlord',
      ),
    ];
    final rows = [
      StatementRow(
        date: DateTime(2026, 7, 18),
        amount: 12.5,
        type: TransactionType.expense,
        description: 'Uber Trip',
        externalId: 'fp2',
      ),
    ];

    final result = deduper.match(rows: rows, existing: existing);
    expect(result.single.status, DedupStatus.isNew);
    expect(result.single.selected, isTrue);
  });
}
