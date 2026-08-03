import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'money_format.dart';
import 'money_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analyticsPeriodProvider);
    final totals = ref.watch(periodTotalsProvider);
    final currency = ref.watch(compactMoneyFormatProvider);
    final money = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          totals.when(
            data: (t) => Text(
              'Net ${money.format(t.net)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AnalyticsPeriod>(
            segments: const [
              ButtonSegment(
                value: AnalyticsPeriod.weekdays,
                label: Text('Week'),
              ),
              ButtonSegment(
                value: AnalyticsPeriod.month,
                label: Text('Month'),
              ),
              ButtonSegment(
                value: AnalyticsPeriod.year,
                label: Text('Year'),
              ),
            ],
            selected: {period},
            onSelectionChanged: (value) {
              ref.read(analyticsPeriodProvider.notifier).setPeriod(value.first);
            },
          ),
          const SizedBox(height: 16),
          if (period == AnalyticsPeriod.month) _MonthPicker(),
          if (period == AnalyticsPeriod.year) _YearPicker(),
          const SizedBox(height: 8),
          Text(
            switch (period) {
              AnalyticsPeriod.weekdays => 'Spending by weekday (this week)',
              AnalyticsPeriod.month => 'Daily totals this month',
              AnalyticsPeriod.year => 'Monthly totals this year',
            },
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: switch (period) {
              AnalyticsPeriod.weekdays => _WeekdayChart(currency: currency),
              AnalyticsPeriod.month => _MonthDayChart(currency: currency),
              AnalyticsPeriod.year => _YearMonthChart(currency: currency),
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Expense bars · Income as secondary · Invest/Save excluded from expense',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MonthPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    return Row(
      children: [
        IconButton(
          onPressed: () {
            ref.read(selectedMonthProvider.notifier).setMonth(
                  DateTime(month.year, month.month - 1),
                );
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(DateFormat.yMMMM().format(month)),
          ),
        ),
        IconButton(
          onPressed: () {
            ref.read(selectedMonthProvider.notifier).setMonth(
                  DateTime(month.year, month.month + 1),
                );
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _YearPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(selectedYearProvider);
    return Row(
      children: [
        IconButton(
          onPressed: () =>
              ref.read(selectedYearProvider.notifier).setYear(year - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(child: Center(child: Text('$year'))),
        IconButton(
          onPressed: () =>
              ref.read(selectedYearProvider.notifier).setYear(year + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WeekdayChart extends ConsumerWidget {
  const _WeekdayChart({required this.currency});

  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(weekdayAnalyticsProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
      data: (days) {
        return _DualBarChart(
          labels: AnalyticsScreen._weekdayLabels,
          expenses: days.map((d) => d.expense).toList(),
          incomes: days.map((d) => d.income).toList(),
          currency: currency,
        );
      },
    );
  }
}

class _MonthDayChart extends ConsumerWidget {
  const _MonthDayChart({required this.currency});

  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(monthDayAnalyticsProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
      data: (days) {
        return _DualBarChart(
          labels: days.map((d) => '${d.date.day}').toList(),
          expenses: days.map((d) => d.expense).toList(),
          incomes: days.map((d) => d.income).toList(),
          currency: currency,
          rotateLabels: true,
        );
      },
    );
  }
}

class _YearMonthChart extends ConsumerWidget {
  const _YearMonthChart({required this.currency});

  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(yearMonthAnalyticsProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
      data: (months) {
        return _DualBarChart(
          labels: AnalyticsScreen._monthLabels,
          expenses: months.map((m) => m.expense).toList(),
          incomes: months.map((m) => m.income).toList(),
          currency: currency,
        );
      },
    );
  }
}

class _DualBarChart extends StatelessWidget {
  const _DualBarChart({
    required this.labels,
    required this.expenses,
    required this.incomes,
    required this.currency,
    this.rotateLabels = false,
  });

  final List<String> labels;
  final List<double> expenses;
  final List<double> incomes;
  final NumberFormat currency;
  final bool rotateLabels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = [
      ...expenses,
      ...incomes,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? 'Expense' : 'Income';
              return BarTooltipItem(
                '$label\n${currency.format(rod.toY)}',
                TextStyle(color: scheme.onInverseSurface),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                currency.format(value),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: rotateLabels ? 36 : 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                // Skip some day labels when crowded
                if (rotateLabels && labels.length > 15 && i % 2 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barGroups: [
          for (var i = 0; i < labels.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                BarChartRodData(
                  toY: expenses[i],
                  color: scheme.error,
                  width: labels.length > 20 ? 3 : 6,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: incomes[i],
                  color: scheme.tertiary,
                  width: labels.length > 20 ? 3 : 6,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
