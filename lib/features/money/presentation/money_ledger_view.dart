import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/hud_widgets.dart';
import '../domain/transaction.dart';
import 'add_transaction_sheet.dart';
import 'money_format.dart';
import 'money_providers.dart';

/// Ledger list + income/expense/invest/save summary (Money tab body).
class MoneyLedgerView extends ConsumerWidget {
  const MoneyLedgerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    final totals = ref.watch(periodTotalsProvider);
    final currency = ref.watch(moneyFormatProvider);

    return Column(
      children: [
        totals.when(
          data: (t) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Income',
                        value: currency.format(t.income),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Expense',
                        value: currency.format(t.expense),
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Net',
                        value: currency.format(t.net),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (t.investment > 0 || t.saving > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Invest',
                          value: currency.format(t.investment),
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Saving',
                          value: currency.format(t.saving),
                          color: Colors.amber.shade800,
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        Expanded(
          child: txsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (txs) {
              if (txs.isEmpty) {
                return const Center(
                  child: Text(
                    'No transactions yet.\nTap + to add one, or Import a statement.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final dateFmt = DateFormat.yMMMd();
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: txs.length,
                itemBuilder: (context, index) {
                  final tx = txs[index];
                  return _LedgerTile(
                    transaction: tx,
                    currency: currency,
                    dateFmt: dateFmt,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LedgerTile extends ConsumerWidget {
  const _LedgerTile({
    required this.transaction,
    required this.currency,
    required this.dateFmt,
  });

  final MoneyTransaction transaction;
  final NumberFormat currency;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = transaction;
    final style = _typeStyle(tx.type);
    final ext = StatThemeExtension.of(context);

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      confirmDismiss: (_) => confirmDeleteTransaction(context: context),
      onDismissed: (_) {
        ref.read(transactionActionsProvider).delete(tx.id);
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: style.color.withValues(alpha: 0.15),
          child: Icon(style.icon, color: style.color),
        ),
        title: Text(
          tx.merchant.isNotEmpty ? tx.merchant : tx.category,
        ),
        subtitle: Text(
          [
            dateFmt.format(tx.date),
            tx.type.label,
            if (tx.merchant.isNotEmpty) tx.category,
            if (tx.note.isNotEmpty) tx.note,
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${style.sign}${currency.format(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: style.color,
              ),
            ),
            PopupMenuButton<_LedgerAction>(
              onSelected: (action) async {
                switch (action) {
                  case _LedgerAction.edit:
                    await showEditTransactionSheet(
                      context,
                      transaction: tx,
                    );
                  case _LedgerAction.delete:
                    final ok =
                        await confirmDeleteTransaction(context: context);
                    if (ok && context.mounted) {
                      await ref
                          .read(transactionActionsProvider)
                          .delete(tx.id);
                    }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _LedgerAction.edit,
                  child: Text(ext.isCyber ? 'EDIT' : 'Edit'),
                ),
                PopupMenuItem(
                  value: _LedgerAction.delete,
                  child: Text(ext.isCyber ? 'DELETE' : 'Delete'),
                ),
              ],
            ),
          ],
        ),
        onTap: () => showEditTransactionSheet(context, transaction: tx),
        onLongPress: () => showEditTransactionSheet(context, transaction: tx),
      ),
    );
  }
}

enum _LedgerAction { edit, delete }

({Color color, IconData icon, String sign}) _typeStyle(TransactionType type) {
  switch (type) {
    case TransactionType.income:
      return (color: Colors.green, icon: Icons.arrow_downward, sign: '+');
    case TransactionType.expense:
      return (color: Colors.red, icon: Icons.arrow_upward, sign: '-');
    case TransactionType.investment:
      return (color: Colors.teal, icon: Icons.trending_up, sign: '-');
    case TransactionType.saving:
      return (
        color: Colors.amber.shade800,
        icon: Icons.savings_outlined,
        sign: '-'
      );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ext = StatThemeExtension.of(context);
    return HudPanel(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(
            ext.isCyber ? label.toUpperCase() : label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: ext.isCyber ? 1.2 : null,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (ext.isCyber
                    ? ext.mono
                    : Theme.of(context).textTheme.titleSmall)
                ?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              shadows: ext.isCyber
                  ? [
                      Shadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
