enum TransactionType { income, expense, investment, saving }

enum TransactionSource { manual, import }

extension TransactionTypeX on TransactionType {
  String get label => switch (this) {
        TransactionType.income => 'Income',
        TransactionType.expense => 'Expense',
        TransactionType.investment => 'Investment',
        TransactionType.saving => 'Saving',
      };

  /// Money leaving the spending pot (expense / investment / saving).
  bool get isOutbound =>
      this == TransactionType.expense ||
      this == TransactionType.investment ||
      this == TransactionType.saving;

  /// Types allowed when logging a wishlist purchase / recurring payment.
  static const wishlistTargets = [
    TransactionType.expense,
    TransactionType.investment,
    TransactionType.saving,
  ];

  static TransactionType parse(String raw) {
    return TransactionType.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => TransactionType.expense,
    );
  }
}

class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
    this.merchant = '',
    this.externalId,
    this.source = TransactionSource.manual,
  });

  final String id;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String note;
  final String merchant;
  final String? externalId;
  final TransactionSource source;

  MoneyTransaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? note,
    String? merchant,
    String? externalId,
    TransactionSource? source,
    bool clearExternalId = false,
  }) {
    return MoneyTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      merchant: merchant ?? this.merchant,
      externalId: clearExternalId ? null : (externalId ?? this.externalId),
      source: source ?? this.source,
    );
  }
}

const defaultCategories = [
  'Food',
  'Transport',
  'Rent',
  'Salary',
  'Shopping',
  'Investment',
  'Savings',
  'Other',
];
