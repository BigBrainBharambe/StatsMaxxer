import '../../../core/utils/date_utils.dart';
import 'transaction.dart';

class PeriodTotals {
  const PeriodTotals({
    required this.income,
    required this.expense,
    this.investment = 0,
    this.saving = 0,
  });

  final double income;
  final double expense;
  final double investment;
  final double saving;

  /// Cashflow net: income minus consumptive expenses (not invest/save).
  double get net => income - expense;
}

class DayTotal {
  const DayTotal({
    required this.date,
    required this.income,
    required this.expense,
    this.investment = 0,
    this.saving = 0,
  });

  final DateTime date;
  final double income;
  final double expense;
  final double investment;
  final double saving;

  double get net => income - expense;
}

class WeekdayTotal {
  const WeekdayTotal({
    required this.weekday,
    required this.income,
    required this.expense,
    this.investment = 0,
    this.saving = 0,
  });

  /// Dart weekday: Monday = 1 ... Sunday = 7
  final int weekday;
  final double income;
  final double expense;
  final double investment;
  final double saving;

  double get net => income - expense;
}

class MonthTotal {
  const MonthTotal({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    this.investment = 0,
    this.saving = 0,
  });

  final int year;
  final int month;
  final double income;
  final double expense;
  final double investment;
  final double saving;

  double get net => income - expense;
}

typedef _Bucket = ({
  double income,
  double expense,
  double investment,
  double saving,
});

_Bucket _emptyBucket() =>
    (income: 0.0, expense: 0.0, investment: 0.0, saving: 0.0);

_Bucket _addToBucket(_Bucket current, MoneyTransaction tx) {
  switch (tx.type) {
    case TransactionType.income:
      return (
        income: current.income + tx.amount,
        expense: current.expense,
        investment: current.investment,
        saving: current.saving,
      );
    case TransactionType.expense:
      return (
        income: current.income,
        expense: current.expense + tx.amount,
        investment: current.investment,
        saving: current.saving,
      );
    case TransactionType.investment:
      return (
        income: current.income,
        expense: current.expense,
        investment: current.investment + tx.amount,
        saving: current.saving,
      );
    case TransactionType.saving:
      return (
        income: current.income,
        expense: current.expense,
        investment: current.investment,
        saving: current.saving + tx.amount,
      );
  }
}

class MoneyAnalytics {
  const MoneyAnalytics();

  PeriodTotals totals(List<MoneyTransaction> transactions) {
    var bucket = _emptyBucket();
    for (final tx in transactions) {
      bucket = _addToBucket(bucket, tx);
    }
    return PeriodTotals(
      income: bucket.income,
      expense: bucket.expense,
      investment: bucket.investment,
      saving: bucket.saving,
    );
  }

  List<WeekdayTotal> byWeekday(
    List<MoneyTransaction> transactions, {
    required DateTime from,
    required DateTime to,
  }) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    final filtered = transactions.where((tx) {
      final d = dateOnly(tx.date);
      return !d.isBefore(start) && !d.isAfter(end);
    });

    final map = <int, _Bucket>{
      for (var w = 1; w <= 7; w++) w: _emptyBucket(),
    };

    for (final tx in filtered) {
      final weekday = dateOnly(tx.date).weekday;
      map[weekday] = _addToBucket(map[weekday]!, tx);
    }

    return [
      for (var w = 1; w <= 7; w++)
        WeekdayTotal(
          weekday: w,
          income: map[w]!.income,
          expense: map[w]!.expense,
          investment: map[w]!.investment,
          saving: map[w]!.saving,
        ),
    ];
  }

  List<DayTotal> byDayInMonth(
    List<MoneyTransaction> transactions, {
    required int year,
    required int month,
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final map = <int, _Bucket>{
      for (var d = 1; d <= daysInMonth; d++) d: _emptyBucket(),
    };

    for (final tx in transactions) {
      final d = dateOnly(tx.date);
      if (d.year != year || d.month != month) continue;
      map[d.day] = _addToBucket(map[d.day]!, tx);
    }

    return [
      for (var d = 1; d <= daysInMonth; d++)
        DayTotal(
          date: DateTime(year, month, d),
          income: map[d]!.income,
          expense: map[d]!.expense,
          investment: map[d]!.investment,
          saving: map[d]!.saving,
        ),
    ];
  }

  List<MonthTotal> byMonthInYear(
    List<MoneyTransaction> transactions, {
    required int year,
  }) {
    final map = <int, _Bucket>{
      for (var m = 1; m <= 12; m++) m: _emptyBucket(),
    };

    for (final tx in transactions) {
      final d = dateOnly(tx.date);
      if (d.year != year) continue;
      map[d.month] = _addToBucket(map[d.month]!, tx);
    }

    return [
      for (var m = 1; m <= 12; m++)
        MonthTotal(
          year: year,
          month: m,
          income: map[m]!.income,
          expense: map[m]!.expense,
          investment: map[m]!.investment,
          saving: map[m]!.saving,
        ),
    ];
  }
}
