import 'dart:async';

import '../domain/transaction.dart';
import '../domain/transaction_repository.dart';

class InMemoryTransactionRepository implements TransactionRepository {
  final Map<String, MoneyTransaction> _transactions = {};
  final Set<String> _externalIds = {};
  final _controller = StreamController<List<MoneyTransaction>>.broadcast();

  void _emit() {
    _controller.add(_sorted());
  }

  List<MoneyTransaction> _sorted() {
    return _transactions.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Stream<List<MoneyTransaction>> watchTransactions() async* {
    yield _sorted();
    yield* _controller.stream;
  }

  @override
  Future<List<MoneyTransaction>> getTransactions() async => _sorted();

  @override
  Future<void> addTransaction(MoneyTransaction transaction) async {
    if (transaction.amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }
    final ext = transaction.externalId;
    if (ext != null && ext.isNotEmpty && _externalIds.contains(ext)) {
      return;
    }
    _transactions[transaction.id] = transaction;
    if (ext != null && ext.isNotEmpty) {
      _externalIds.add(ext);
    }
    _emit();
  }

  @override
  Future<int> addTransactions(List<MoneyTransaction> transactions) async {
    var inserted = 0;
    for (final tx in transactions) {
      if (tx.amount <= 0) {
        throw ArgumentError('Amount must be greater than zero');
      }
      final ext = tx.externalId;
      if (ext != null && ext.isNotEmpty && _externalIds.contains(ext)) {
        continue;
      }
      if (_transactions.containsKey(tx.id)) {
        continue;
      }
      _transactions[tx.id] = tx;
      if (ext != null && ext.isNotEmpty) {
        _externalIds.add(ext);
      }
      inserted++;
    }
    if (inserted > 0) _emit();
    return inserted;
  }

  @override
  Future<void> updateTransaction(MoneyTransaction transaction) async {
    if (transaction.amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }
    final existing = _transactions[transaction.id];
    if (existing == null) {
      throw StateError('Transaction ${transaction.id} not found');
    }
    // Keep external-id uniqueness consistent if the id changes on the row.
    final oldExt = existing.externalId;
    final newExt = transaction.externalId;
    if (oldExt != null &&
        oldExt.isNotEmpty &&
        (newExt == null || newExt.isEmpty || newExt != oldExt)) {
      _externalIds.remove(oldExt);
    }
    if (newExt != null &&
        newExt.isNotEmpty &&
        newExt != oldExt &&
        _externalIds.contains(newExt)) {
      throw StateError('Duplicate external id: $newExt');
    }
    _transactions[transaction.id] = transaction;
    if (newExt != null && newExt.isNotEmpty) {
      _externalIds.add(newExt);
    }
    _emit();
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final removed = _transactions.remove(id);
    if (removed?.externalId != null && removed!.externalId!.isNotEmpty) {
      _externalIds.remove(removed.externalId);
    }
    _emit();
  }

  void dispose() {
    _controller.close();
  }
}
