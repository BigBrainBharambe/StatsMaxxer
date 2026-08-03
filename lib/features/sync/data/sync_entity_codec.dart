import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_occurrence.dart';
import '../../habits/domain/habit_quantity_log.dart';
import '../../habits/domain/quantity_window_goal.dart';
import '../../money/domain/transaction.dart';
import '../../money/domain/wishlist_item.dart';

/// JSON maps for sync shards (ISO-8601 timestamps, local-naive as stored).
abstract final class SyncEntityCodec {
  static String encodeDate(DateTime d) => d.toIso8601String();

  static DateTime decodeDate(Object? raw) {
    if (raw is DateTime) return raw;
    return DateTime.parse(raw as String);
  }

  static Map<String, dynamic> habitToJson(Habit h) => {
        'id': h.id,
        'name': h.name,
        'createdAt': encodeDate(h.createdAt),
        'archived': h.archived,
        'kind': h.kind.name,
        if (h.schedule != null) 'schedule': h.schedule!.toJson(),
        if (h.quantityGoal != null) 'quantityGoal': h.quantityGoal!.toJson(),
        if (h.reminderTimeMinutes != null)
          'reminderTimeMinutes': h.reminderTimeMinutes,
        if (h.colorValue != null) 'colorValue': h.colorValue,
        'iconName': h.iconName,
      };

  static Habit habitFromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: decodeDate(json['createdAt']),
      archived: json['archived'] as bool? ?? false,
      kind: HabitKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => HabitKind.repeatable,
      ),
      schedule: json['schedule'] is Map
          ? HabitSchedule.fromJson(
              Map<String, dynamic>.from(json['schedule'] as Map),
            )
          : null,
      quantityGoal: json['quantityGoal'] is Map
          ? QuantityWindowGoal.fromJson(
              Map<String, dynamic>.from(json['quantityGoal'] as Map),
            )
          : null,
      reminderTimeMinutes: (json['reminderTimeMinutes'] as num?)?.toInt(),
      colorValue: (json['colorValue'] as num?)?.toInt(),
      iconName: json['iconName'] as String? ?? 'fitness_center',
    );
  }

  static Map<String, dynamic> occurrenceToJson(HabitOccurrence o) => {
        'id': o.id,
        'habitId': o.habitId,
        'dueAt': encodeDate(o.dueAt),
        'status': o.status.name,
        if (o.completedAt != null) 'completedAt': encodeDate(o.completedAt!),
      };

  static HabitOccurrence occurrenceFromJson(Map<String, dynamic> json) {
    return HabitOccurrence(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      dueAt: decodeDate(json['dueAt']),
      status: OccurrenceStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OccurrenceStatus.pending,
      ),
      completedAt: json['completedAt'] == null
          ? null
          : decodeDate(json['completedAt']),
    );
  }

  static Map<String, dynamic> quantityToJson(HabitQuantityLog log) => {
        'id': log.id,
        'habitId': log.habitId,
        'loggedAt': encodeDate(log.loggedAt),
        'quantity': log.quantity,
      };

  static HabitQuantityLog quantityFromJson(Map<String, dynamic> json) {
    return HabitQuantityLog(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      loggedAt: decodeDate(json['loggedAt']),
      quantity: (json['quantity'] as num?) ?? 1,
    );
  }

  static Map<String, dynamic> transactionToJson(MoneyTransaction t) => {
        'id': t.id,
        'amount': t.amount,
        'type': t.type.name,
        'category': t.category,
        'date': encodeDate(t.date),
        'note': t.note,
        'merchant': t.merchant,
        if (t.externalId != null) 'externalId': t.externalId,
        'source': t.source.name,
      };

  static MoneyTransaction transactionFromJson(Map<String, dynamic> json) {
    return MoneyTransaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionTypeX.parse(json['type'] as String? ?? 'expense'),
      category: json['category'] as String? ?? 'Other',
      date: decodeDate(json['date']),
      note: json['note'] as String? ?? '',
      merchant: json['merchant'] as String? ?? '',
      externalId: json['externalId'] as String?,
      source: (json['source'] as String?) == 'import'
          ? TransactionSource.import
          : TransactionSource.manual,
    );
  }

  static Map<String, dynamic> wishlistToJson(WishlistItem item) => {
        'id': item.id,
        'name': item.name,
        'notes': item.notes,
        if (item.estimatedPrice != null) 'estimatedPrice': item.estimatedPrice,
        'createdAt': encodeDate(item.createdAt),
        if (item.boughtAt != null) 'boughtAt': encodeDate(item.boughtAt!),
        if (item.transactionId != null) 'transactionId': item.transactionId,
        'isRecurring': item.isRecurring,
        if (item.recurrenceInterval != null)
          'recurrenceInterval': item.recurrenceInterval,
        if (item.recurrenceUnit != null)
          'recurrenceUnit': item.recurrenceUnit!.name,
        if (item.nextDue != null) 'nextDue': encodeDate(item.nextDue!),
        'targetType': item.targetType.name,
      };

  static WishlistItem wishlistFromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String? ?? '',
      estimatedPrice: (json['estimatedPrice'] as num?)?.toDouble(),
      createdAt: decodeDate(json['createdAt']),
      boughtAt:
          json['boughtAt'] == null ? null : decodeDate(json['boughtAt']),
      transactionId: json['transactionId'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrenceInterval: (json['recurrenceInterval'] as num?)?.toInt(),
      recurrenceUnit: json['recurrenceUnit'] == null
          ? null
          : WishlistRecurrenceUnitX.parse(json['recurrenceUnit'] as String?),
      nextDue: json['nextDue'] == null ? null : decodeDate(json['nextDue']),
      targetType: TransactionTypeX.parse(json['targetType'] as String? ?? 'expense'),
    );
  }

  static Map<String, dynamic> settingsToJson({
    required String themeMode,
    required String visualStyle,
    required String currencyCode,
  }) =>
      {
        'themeMode': themeMode,
        'visualStyle': visualStyle,
        'currencyCode': currencyCode,
      };
}
