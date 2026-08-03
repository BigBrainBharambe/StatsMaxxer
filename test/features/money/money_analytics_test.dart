import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/money/domain/money_analytics.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';

void main() {
  const analytics = MoneyAnalytics();

  MoneyTransaction tx({
    required double amount,
    required TransactionType type,
    required DateTime date,
    String category = 'Other',
  }) {
    return MoneyTransaction(
      id: '${date.toIso8601String()}-$amount-$type',
      amount: amount,
      type: type,
      category: category,
      date: date,
    );
  }

  group('MoneyAnalytics', () {
    test('computes period income expense and net', () {
      final result = analytics.totals([
        tx(amount: 1000, type: TransactionType.income, date: DateTime(2026, 7, 1)),
        tx(amount: 200, type: TransactionType.expense, date: DateTime(2026, 7, 2)),
        tx(amount: 50, type: TransactionType.expense, date: DateTime(2026, 7, 3)),
      ]);
      expect(result.income, 1000);
      expect(result.expense, 250);
      expect(result.net, 750);
    });

    test('separates investment and saving from expense', () {
      final result = analytics.totals([
        tx(amount: 2000, type: TransactionType.income, date: DateTime(2026, 7, 1)),
        tx(amount: 100, type: TransactionType.expense, date: DateTime(2026, 7, 2)),
        tx(amount: 400, type: TransactionType.investment, date: DateTime(2026, 7, 3)),
        tx(amount: 200, type: TransactionType.saving, date: DateTime(2026, 7, 4)),
      ]);
      expect(result.income, 2000);
      expect(result.expense, 100);
      expect(result.investment, 400);
      expect(result.saving, 200);
      expect(result.net, 1900);
    });

    test('aggregates by weekday within range', () {
      final result = analytics.byWeekday(
        [
          // Monday
          tx(amount: 10, type: TransactionType.expense, date: DateTime(2026, 7, 13)),
          tx(amount: 5, type: TransactionType.expense, date: DateTime(2026, 7, 13)),
          // Wednesday
          tx(amount: 100, type: TransactionType.income, date: DateTime(2026, 7, 15)),
          // Outside range
          tx(amount: 999, type: TransactionType.expense, date: DateTime(2026, 6, 1)),
        ],
        from: DateTime(2026, 7, 13),
        to: DateTime(2026, 7, 19),
      );

      expect(result.length, 7);
      expect(result[0].weekday, DateTime.monday);
      expect(result[0].expense, 15);
      expect(result[2].weekday, DateTime.wednesday);
      expect(result[2].income, 100);
      expect(result[1].expense, 0);
    });

    test('aggregates by day within a month', () {
      final result = analytics.byDayInMonth(
        [
          tx(amount: 20, type: TransactionType.expense, date: DateTime(2026, 7, 1)),
          tx(amount: 30, type: TransactionType.expense, date: DateTime(2026, 7, 1)),
          tx(amount: 500, type: TransactionType.income, date: DateTime(2026, 7, 18)),
          tx(amount: 1, type: TransactionType.expense, date: DateTime(2026, 6, 18)),
        ],
        year: 2026,
        month: 7,
      );

      expect(result.length, 31);
      expect(result[0].expense, 50);
      expect(result[17].income, 500);
      expect(result[17].net, 500);
    });

    test('aggregates by month within a year', () {
      final result = analytics.byMonthInYear(
        [
          tx(amount: 100, type: TransactionType.expense, date: DateTime(2026, 1, 5)),
          tx(amount: 200, type: TransactionType.income, date: DateTime(2026, 7, 5)),
          tx(amount: 50, type: TransactionType.expense, date: DateTime(2026, 7, 10)),
          tx(amount: 10, type: TransactionType.expense, date: DateTime(2025, 7, 10)),
        ],
        year: 2026,
      );

      expect(result.length, 12);
      expect(result[0].expense, 100);
      expect(result[6].income, 200);
      expect(result[6].expense, 50);
      expect(result[6].net, 150);
    });
  });
}
