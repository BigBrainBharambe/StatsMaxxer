import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../domain/money_analytics.dart';
import '../domain/transaction.dart';
import '../domain/wishlist_item.dart';
import '../import/import_coordinator.dart';

const _uuid = Uuid();
const _analytics = MoneyAnalytics();

enum AnalyticsPeriod { weekdays, month, year }

final transactionsProvider = StreamProvider<List<MoneyTransaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchTransactions();
});

final wishlistItemsProvider = StreamProvider<List<WishlistItem>>((ref) {
  return ref.watch(wishlistRepositoryProvider).watchOpenItems();
});

final moneyTabIndexProvider =
    NotifierProvider<MoneyTabIndexNotifier, int>(MoneyTabIndexNotifier.new);

class MoneyTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final analyticsPeriodProvider =
    NotifierProvider<AnalyticsPeriodNotifier, AnalyticsPeriod>(
  AnalyticsPeriodNotifier.new,
);

class AnalyticsPeriodNotifier extends Notifier<AnalyticsPeriod> {
  @override
  AnalyticsPeriod build() => AnalyticsPeriod.weekdays;

  void setPeriod(AnalyticsPeriod period) => state = period;
}

final selectedYearProvider =
    NotifierProvider<SelectedYearNotifier, int>(SelectedYearNotifier.new);

class SelectedYearNotifier extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void setYear(int year) => state = year;
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, DateTime>(SelectedMonthNotifier.new);

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void setMonth(DateTime month) => state = DateTime(month.year, month.month);
}

final periodTotalsProvider = Provider<AsyncValue<PeriodTotals>>((ref) {
  final txs = ref.watch(transactionsProvider);
  return txs.whenData(_analytics.totals);
});

final weekdayAnalyticsProvider =
    Provider<AsyncValue<List<WeekdayTotal>>>((ref) {
  final txs = ref.watch(transactionsProvider);
  final now = DateTime.now();
  final start = now.subtract(Duration(days: now.weekday - 1));
  final end = start.add(const Duration(days: 6));
  return txs.whenData(
    (list) => _analytics.byWeekday(
      list,
      from: DateTime(start.year, start.month, start.day),
      to: DateTime(end.year, end.month, end.day),
    ),
  );
});

final monthDayAnalyticsProvider =
    Provider<AsyncValue<List<DayTotal>>>((ref) {
  final txs = ref.watch(transactionsProvider);
  final month = ref.watch(selectedMonthProvider);
  return txs.whenData(
    (list) => _analytics.byDayInMonth(
      list,
      year: month.year,
      month: month.month,
    ),
  );
});

final yearMonthAnalyticsProvider =
    Provider<AsyncValue<List<MonthTotal>>>((ref) {
  final txs = ref.watch(transactionsProvider);
  final year = ref.watch(selectedYearProvider);
  return txs.whenData(
    (list) => _analytics.byMonthInYear(list, year: year),
  );
});

class TransactionActions {
  TransactionActions(this._ref);

  final Ref _ref;

  Future<void> add({
    required double amount,
    required TransactionType type,
    required String category,
    required DateTime date,
    String note = '',
    String merchant = '',
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }
    final trimmedCategory = category.trim().isEmpty ? 'Other' : category.trim();
    await _ref.read(transactionRepositoryProvider).addTransaction(
          MoneyTransaction(
            id: _uuid.v4(),
            amount: amount,
            type: type,
            category: trimmedCategory,
            date: date,
            note: note.trim(),
            merchant: merchant.trim(),
            source: TransactionSource.manual,
          ),
        );
  }

  Future<void> update({
    required MoneyTransaction existing,
    required double amount,
    required TransactionType type,
    required String category,
    required DateTime date,
    String note = '',
    String merchant = '',
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }
    final trimmedCategory = category.trim().isEmpty ? 'Other' : category.trim();
    await _ref.read(transactionRepositoryProvider).updateTransaction(
          existing.copyWith(
            amount: amount,
            type: type,
            category: trimmedCategory,
            date: date,
            note: note.trim(),
            merchant: merchant.trim(),
          ),
        );
  }

  Future<void> delete(String id) async {
    await _ref.read(transactionRepositoryProvider).deleteTransaction(id);
  }
}

final transactionActionsProvider =
    Provider<TransactionActions>((ref) => TransactionActions(ref));

class WishlistActions {
  WishlistActions(this._ref);

  final Ref _ref;

  Future<void> add({
    required String name,
    String notes = '',
    double? estimatedPrice,
    bool isRecurring = false,
    int? recurrenceInterval,
    WishlistRecurrenceUnit? recurrenceUnit,
    DateTime? nextDue,
    TransactionType targetType = TransactionType.expense,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Name must not be empty');
    }
    if (estimatedPrice != null && estimatedPrice <= 0) {
      throw ArgumentError('Estimated price must be greater than zero');
    }
    if (isRecurring) {
      final interval = recurrenceInterval ?? 0;
      if (interval < 1) {
        throw ArgumentError('Recurrence interval must be at least 1');
      }
      if (recurrenceUnit == null) {
        throw ArgumentError('Recurrence unit is required for recurring items');
      }
    }
    if (!TransactionTypeX.wishlistTargets.contains(targetType)) {
      throw ArgumentError('Invalid wishlist target type');
    }
    await _ref.read(wishlistRepositoryProvider).addItem(
          WishlistItem(
            id: _uuid.v4(),
            name: trimmed,
            notes: notes.trim(),
            estimatedPrice: estimatedPrice,
            createdAt: DateTime.now(),
            isRecurring: isRecurring,
            recurrenceInterval: isRecurring ? recurrenceInterval : null,
            recurrenceUnit: isRecurring ? recurrenceUnit : null,
            nextDue: isRecurring ? (nextDue ?? DateTime.now()) : null,
            targetType: targetType,
          ),
        );
  }

  Future<void> delete(String id) async {
    await _ref.read(wishlistRepositoryProvider).deleteItem(id);
  }

  /// Creates a ledger transaction from a wishlist item.
  /// One-shot items are marked bought; recurring items stay open with next due advanced.
  Future<void> buy({
    required WishlistItem item,
    required double amount,
    required String category,
    required DateTime boughtOn,
    String note = '',
    TransactionType? type,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }
    final txType = type ?? item.targetType;
    if (!TransactionTypeX.wishlistTargets.contains(txType)) {
      throw ArgumentError('Invalid transaction type for wishlist buy');
    }
    final trimmedCategory =
        category.trim().isEmpty ? 'Shopping' : category.trim();
    final txId = _uuid.v4();
    final noteText = note.trim().isNotEmpty
        ? note.trim()
        : (item.notes.isNotEmpty ? item.notes : item.name);

    await _ref.read(transactionRepositoryProvider).addTransaction(
          MoneyTransaction(
            id: txId,
            amount: amount,
            type: txType,
            category: trimmedCategory,
            date: boughtOn,
            note: noteText,
            merchant: item.name,
            source: TransactionSource.manual,
          ),
        );

    if (item.isRecurring) {
      final interval = item.recurrenceInterval ?? 1;
      final unit = item.recurrenceUnit ?? WishlistRecurrenceUnit.month;
      final nextDue = advanceWishlistDue(
        boughtOn,
        interval: interval,
        unit: unit,
      );
      await _ref.read(wishlistRepositoryProvider).recordRecurringPayment(
            id: item.id,
            transactionId: txId,
            nextDue: nextDue,
          );
    } else {
      await _ref.read(wishlistRepositoryProvider).markBought(
            id: item.id,
            transactionId: txId,
            boughtAt: boughtOn,
          );
    }
  }
}

final wishlistActionsProvider =
    Provider<WishlistActions>((ref) => WishlistActions(ref));

final importCoordinatorProvider = Provider<ImportCoordinator>((ref) {
  return ImportCoordinator(ref.watch(transactionRepositoryProvider));
});
