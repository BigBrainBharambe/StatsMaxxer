import 'wishlist_item.dart';

abstract class WishlistRepository {
  /// Open (not yet bought) items, newest first.
  /// Recurring items stay open after payment.
  Stream<List<WishlistItem>> watchOpenItems();

  Future<List<WishlistItem>> getOpenItems();

  Future<void> addItem(WishlistItem item);

  Future<void> deleteItem(String id);

  /// Marks a one-shot item as bought and links it to a ledger transaction.
  Future<void> markBought({
    required String id,
    required String transactionId,
    required DateTime boughtAt,
  });

  /// Records payment on a recurring item: keeps it open, advances next due.
  Future<void> recordRecurringPayment({
    required String id,
    required String transactionId,
    required DateTime nextDue,
  });
}
