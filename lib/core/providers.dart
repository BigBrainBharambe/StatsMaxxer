import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/habits/data/drift_habit_repository.dart';
import '../features/habits/domain/habit_repository.dart';
import '../features/money/data/drift_transaction_repository.dart';
import '../features/money/data/drift_wishlist_repository.dart';
import '../features/money/domain/transaction_repository.dart';
import '../features/money/domain/wishlist_repository.dart';
import 'database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return DriftHabitRepository(ref.watch(appDatabaseProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return DriftTransactionRepository(ref.watch(appDatabaseProvider));
});

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return DriftWishlistRepository(ref.watch(appDatabaseProvider));
});
