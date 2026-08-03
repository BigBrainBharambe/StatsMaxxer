import 'transaction.dart';

abstract class TransactionRepository {
  Stream<List<MoneyTransaction>> watchTransactions();
  Future<List<MoneyTransaction>> getTransactions();
  Future<void> addTransaction(MoneyTransaction transaction);
  Future<int> addTransactions(List<MoneyTransaction> transactions);
  Future<void> updateTransaction(MoneyTransaction transaction);
  Future<void> deleteTransaction(String id);
}
