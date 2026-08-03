import 'transaction.dart';

/// Interval unit for recurring wishlist expenses.
enum WishlistRecurrenceUnit { day, week, month }

extension WishlistRecurrenceUnitX on WishlistRecurrenceUnit {
  String get label => switch (this) {
        WishlistRecurrenceUnit.day => 'days',
        WishlistRecurrenceUnit.week => 'weeks',
        WishlistRecurrenceUnit.month => 'months',
      };

  static WishlistRecurrenceUnit parse(String? raw) {
    return WishlistRecurrenceUnit.values.firstWhere(
      (u) => u.name == raw,
      orElse: () => WishlistRecurrenceUnit.month,
    );
  }
}

/// Advances [from] by [interval] [unit]s (clamps day-of-month overflow).
DateTime advanceWishlistDue(
  DateTime from, {
  required int interval,
  required WishlistRecurrenceUnit unit,
}) {
  final n = interval < 1 ? 1 : interval;
  switch (unit) {
    case WishlistRecurrenceUnit.day:
      return from.add(Duration(days: n));
    case WishlistRecurrenceUnit.week:
      return from.add(Duration(days: 7 * n));
    case WishlistRecurrenceUnit.month:
      final targetMonth = from.month + n;
      final year = from.year + (targetMonth - 1) ~/ 12;
      final month = ((targetMonth - 1) % 12) + 1;
      final lastDay = DateTime(year, month + 1, 0).day;
      final day = from.day > lastDay ? lastDay : from.day;
      return DateTime(
        year,
        month,
        day,
        from.hour,
        from.minute,
        from.second,
        from.millisecond,
      );
  }
}

class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.name,
    required this.createdAt,
    this.notes = '',
    this.estimatedPrice,
    this.boughtAt,
    this.transactionId,
    this.isRecurring = false,
    this.recurrenceInterval,
    this.recurrenceUnit,
    this.nextDue,
    this.targetType = TransactionType.expense,
  });

  final String id;
  final String name;
  final String notes;
  final double? estimatedPrice;
  final DateTime createdAt;
  final DateTime? boughtAt;
  final String? transactionId;

  /// When true, paying keeps the item open and advances [nextDue].
  final bool isRecurring;
  final int? recurrenceInterval;
  final WishlistRecurrenceUnit? recurrenceUnit;
  final DateTime? nextDue;

  /// Ledger type created on pay (expense / investment / saving).
  final TransactionType targetType;

  bool get isBought => boughtAt != null;

  String get recurrenceSummary {
    if (!isRecurring) return '';
    final interval = recurrenceInterval ?? 1;
    final unit = recurrenceUnit ?? WishlistRecurrenceUnit.month;
    if (interval == 1) {
      return switch (unit) {
        WishlistRecurrenceUnit.day => 'Daily',
        WishlistRecurrenceUnit.week => 'Weekly',
        WishlistRecurrenceUnit.month => 'Monthly',
      };
    }
    return 'Every $interval ${unit.label}';
  }

  WishlistItem copyWith({
    String? id,
    String? name,
    String? notes,
    double? estimatedPrice,
    DateTime? createdAt,
    DateTime? boughtAt,
    String? transactionId,
    bool? isRecurring,
    int? recurrenceInterval,
    WishlistRecurrenceUnit? recurrenceUnit,
    DateTime? nextDue,
    TransactionType? targetType,
    bool clearEstimatedPrice = false,
    bool clearBoughtAt = false,
    bool clearTransactionId = false,
    bool clearRecurrenceInterval = false,
    bool clearRecurrenceUnit = false,
    bool clearNextDue = false,
  }) {
    return WishlistItem(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      estimatedPrice: clearEstimatedPrice
          ? null
          : (estimatedPrice ?? this.estimatedPrice),
      createdAt: createdAt ?? this.createdAt,
      boughtAt: clearBoughtAt ? null : (boughtAt ?? this.boughtAt),
      transactionId:
          clearTransactionId ? null : (transactionId ?? this.transactionId),
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceInterval: clearRecurrenceInterval
          ? null
          : (recurrenceInterval ?? this.recurrenceInterval),
      recurrenceUnit: clearRecurrenceUnit
          ? null
          : (recurrenceUnit ?? this.recurrenceUnit),
      nextDue: clearNextDue ? null : (nextDue ?? this.nextDue),
      targetType: targetType ?? this.targetType,
    );
  }
}
