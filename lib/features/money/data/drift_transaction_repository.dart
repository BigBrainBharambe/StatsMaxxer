import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/transaction.dart';
import '../domain/transaction_repository.dart';

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db);

  final AppDatabase _db;

  MoneyTransaction _map(TransactionRow row) => MoneyTransaction(
        id: row.id,
        amount: row.amount,
        type: TransactionTypeX.parse(row.type),
        category: row.category,
        note: row.note,
        merchant: row.merchant,
        externalId: row.externalId,
        source: row.source == 'import'
            ? TransactionSource.import
            : TransactionSource.manual,
        date: row.date,
      );

  TransactionsCompanion _companion(MoneyTransaction transaction) {
    return TransactionsCompanion.insert(
      id: transaction.id,
      amount: transaction.amount,
      type: transaction.type.name,
      category: transaction.category,
      note: Value(transaction.note),
      merchant: Value(transaction.merchant),
      externalId: Value(transaction.externalId),
      source: Value(
        transaction.source == TransactionSource.import ? 'import' : 'manual',
      ),
      date: transaction.date,
    );
  }

  void _validate(MoneyTransaction transaction) {
    if (transaction.amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }
  }

  @override
  Stream<List<MoneyTransaction>> watchTransactions() {
    final query = _db.select(_db.transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<List<MoneyTransaction>> getTransactions() async {
    final rows = await (_db.select(_db.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<void> addTransaction(MoneyTransaction transaction) async {
    _validate(transaction);
    await _db.into(_db.transactions).insert(_companion(transaction));
  }

  @override
  Future<int> addTransactions(List<MoneyTransaction> transactions) async {
    if (transactions.isEmpty) return 0;
    for (final tx in transactions) {
      _validate(tx);
    }

    final before = (await getTransactions()).length;
    await _db.batch((batch) {
      for (final tx in transactions) {
        batch.insert(
          _db.transactions,
          _companion(tx),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
    final after = (await getTransactions()).length;
    return after - before;
  }

  @override
  Future<void> updateTransaction(MoneyTransaction transaction) async {
    _validate(transaction);
    final updated = await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(transaction.id)))
        .write(
      TransactionsCompanion(
        amount: Value(transaction.amount),
        type: Value(transaction.type.name),
        category: Value(transaction.category),
        note: Value(transaction.note),
        merchant: Value(transaction.merchant),
        externalId: Value(transaction.externalId),
        source: Value(
          transaction.source == TransactionSource.import ? 'import' : 'manual',
        ),
        date: Value(transaction.date),
      ),
    );
    if (updated == 0) {
      throw StateError('Transaction ${transaction.id} not found');
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }
}
