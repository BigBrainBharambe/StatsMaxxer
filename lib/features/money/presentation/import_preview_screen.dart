import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/hud_widgets.dart';
import '../domain/transaction.dart';
import '../import/statement_deduper.dart';
import 'money_format.dart';
import 'money_providers.dart';

class ImportPreviewScreen extends ConsumerStatefulWidget {
  const ImportPreviewScreen({
    super.key,
    required this.rows,
    this.warning,
  });

  final List<DedupedStatementRow> rows;
  final String? warning;

  @override
  ConsumerState<ImportPreviewScreen> createState() =>
      _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends ConsumerState<ImportPreviewScreen> {
  late List<DedupedStatementRow> _rows;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _rows = List.of(widget.rows);
  }

  int get _selectedCount => _rows.where((r) => r.selected).length;

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(moneyFormatProvider);
    final dateFmt = DateFormat.yMMMd();
    final newCount =
        _rows.where((r) => r.status == DedupStatus.isNew).length;
    final likelyCount =
        _rows.where((r) => r.status == DedupStatus.likelyDuplicate).length;
    final alreadyCount =
        _rows.where((r) => r.status == DedupStatus.alreadyImported).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import preview'),
        actions: [
          TextButton(
            onPressed: _rows.isEmpty
                ? null
                : () {
                    setState(() {
                      _rows = [
                        for (final r in _rows)
                          r.copyWith(selected: r.status == DedupStatus.isNew),
                      ];
                    });
                  },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.warning != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(widget.warning!),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '$_selectedCount selected · $newCount new · $likelyCount likely duplicates · $alreadyCount already imported',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: _rows.isEmpty
                ? const Center(child: Text('No transactions to import.'))
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final item = _rows[index];
                      final row = item.row;
                      final isIncome = row.type == TransactionType.income;
                      return CheckboxListTile(
                        value: item.selected,
                        onChanged: (value) {
                          setState(() {
                            _rows[index] =
                                item.copyWith(selected: value ?? false);
                          });
                        },
                        secondary: CircleAvatar(
                          backgroundColor: isIncome
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          child: Icon(
                            isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(row.description),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${dateFmt.format(row.date)} · ${isIncome ? '+' : '-'}${currency.format(row.amount)}',
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _StatusChip(status: item.status),
                                DropdownButton<String>(
                                  value: defaultCategories.contains(item.category)
                                      ? item.category
                                      : 'Other',
                                  underline: const SizedBox.shrink(),
                                  items: [
                                    for (final c in defaultCategories)
                                      DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _rows[index] =
                                          item.copyWith(category: value);
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (item.matchedTransaction != null)
                              Text(
                                'Matches: ${item.matchedTransaction!.merchant.isNotEmpty ? item.matchedTransaction!.merchant : item.matchedTransaction!.category}'
                                ' (${currency.format(item.matchedTransaction!.amount)})',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _importing || _selectedCount == 0 ? null : _import,
                  child: _importing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Import $_selectedCount'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final result =
          await ref.read(importCoordinatorProvider).commit(_rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.imported}. Skipped ${result.skipped}.',
          ),
        ),
      );
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final DedupStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DedupStatus.isNew => ('New', Colors.green.shade700),
      DedupStatus.likelyDuplicate =>
        ('Likely duplicate', Colors.orange.shade800),
      DedupStatus.alreadyImported =>
        ('Already imported', Colors.grey.shade700),
    };
    return HudChip(label: label, color: color);
  }
}
