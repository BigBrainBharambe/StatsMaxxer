import 'dart:async';

import '../domain/transaction.dart';
import '../domain/wishlist_item.dart';
import '../domain/wishlist_repository.dart';

class InMemoryWishlistRepository implements WishlistRepository {
  final Map<String, WishlistItem> _items = {};
  final _controller = StreamController<List<WishlistItem>>.broadcast();

  void _emit() {
    _controller.add(_openSorted());
  }

  List<WishlistItem> _openSorted() {
    return _items.values.where((i) => !i.isBought).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
  Stream<List<WishlistItem>> watchOpenItems() async* {
    yield _openSorted();
    yield* _controller.stream;
  }

  @override
  Future<List<WishlistItem>> getOpenItems() async => _openSorted();

  @override
  Future<void> addItem(WishlistItem item) async {
    _validate(item);
    _items[item.id] = item;
    _emit();
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.remove(id);
    _emit();
  }

  @override
  Future<void> markBought({
    required String id,
    required String transactionId,
    required DateTime boughtAt,
  }) async {
    final existing = _items[id];
    if (existing == null) return;
    _items[id] = existing.copyWith(
      boughtAt: boughtAt,
      transactionId: transactionId,
    );
    _emit();
  }

  @override
  Future<void> recordRecurringPayment({
    required String id,
    required String transactionId,
    required DateTime nextDue,
  }) async {
    final existing = _items[id];
    if (existing == null) return;
    _items[id] = existing.copyWith(
      transactionId: transactionId,
      nextDue: nextDue,
    );
    _emit();
  }

  void dispose() {
    _controller.close();
  }
}
