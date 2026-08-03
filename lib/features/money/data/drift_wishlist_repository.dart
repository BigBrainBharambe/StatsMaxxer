import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/transaction.dart';
import '../domain/wishlist_item.dart';
import '../domain/wishlist_repository.dart';

class DriftWishlistRepository implements WishlistRepository {
  DriftWishlistRepository(this._db);

  final AppDatabase _db;

  WishlistItem _map(WishlistItemRow row) {
    final target = TransactionTypeX.parse(row.targetType);
    final safeTarget = TransactionTypeX.wishlistTargets.contains(target)
        ? target
        : TransactionType.expense;
    return WishlistItem(
      id: row.id,
      name: row.name,
      notes: row.notes,
      estimatedPrice: row.estimatedPrice,
      createdAt: row.createdAt,
      boughtAt: row.boughtAt,
      transactionId: row.transactionId,
      isRecurring: row.isRecurring,
      recurrenceInterval: row.recurrenceInterval,
      recurrenceUnit: row.recurrenceUnit == null
          ? null
          : WishlistRecurrenceUnitX.parse(row.recurrenceUnit),
      nextDue: row.nextDue,
      targetType: safeTarget,
    );
  }

  WishlistItemsCompanion _companion(WishlistItem item) {
    return WishlistItemsCompanion.insert(
      id: item.id,
      name: item.name,
      notes: Value(item.notes),
      estimatedPrice: Value(item.estimatedPrice),
      createdAt: item.createdAt,
      boughtAt: Value(item.boughtAt),
      transactionId: Value(item.transactionId),
      isRecurring: Value(item.isRecurring),
      recurrenceInterval: Value(item.recurrenceInterval),
      recurrenceUnit: Value(item.recurrenceUnit?.name),
      nextDue: Value(item.nextDue),
      targetType: Value(item.targetType.name),
    );
  }

  void _validate(WishlistItem item) {
    if (item.name.trim().isEmpty) {
      throw ArgumentError('Name must not be empty');
    }
    final price = item.estimatedPrice;
    if (price != null && price <= 0) {
      throw ArgumentError('Estimated price must be greater than zero');
    }
    if (item.isRecurring) {
      final interval = item.recurrenceInterval ?? 0;
      if (interval < 1) {
        throw ArgumentError('Recurrence interval must be at least 1');
      }
      if (item.recurrenceUnit == null) {
        throw ArgumentError('Recurrence unit is required for recurring items');
      }
      if (!TransactionTypeX.wishlistTargets.contains(item.targetType)) {
        throw ArgumentError('Invalid wishlist target type');
      }
    }
  }

  @override
  Stream<List<WishlistItem>> watchOpenItems() {
    final query = _db.select(_db.wishlistItems)
      ..where((t) => t.boughtAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<List<WishlistItem>> getOpenItems() async {
    final rows = await (_db.select(_db.wishlistItems)
          ..where((t) => t.boughtAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<void> addItem(WishlistItem item) async {
    _validate(item);
    await _db.into(_db.wishlistItems).insert(_companion(item));
  }

  @override
  Future<void> deleteItem(String id) async {
    await (_db.delete(_db.wishlistItems)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> markBought({
    required String id,
    required String transactionId,
    required DateTime boughtAt,
  }) async {
    await (_db.update(_db.wishlistItems)..where((t) => t.id.equals(id))).write(
      WishlistItemsCompanion(
        boughtAt: Value(boughtAt),
        transactionId: Value(transactionId),
      ),
    );
  }

  @override
  Future<void> recordRecurringPayment({
    required String id,
    required String transactionId,
    required DateTime nextDue,
  }) async {
    await (_db.update(_db.wishlistItems)..where((t) => t.id.equals(id))).write(
      WishlistItemsCompanion(
        transactionId: Value(transactionId),
        nextDue: Value(nextDue),
      ),
    );
  }
}
