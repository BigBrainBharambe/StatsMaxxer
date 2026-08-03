import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/transaction.dart';
import 'money_providers.dart';

Future<void> showAddTransactionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const AddTransactionSheet(),
  );
}

Future<void> showEditTransactionSheet(
  BuildContext context, {
  required MoneyTransaction transaction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => AddTransactionSheet(existing: transaction),
  );
}

Future<bool> confirmDeleteTransaction({
  required BuildContext context,
}) async {
  final ext = StatThemeExtension.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            ext.isCyber ? 'DELETE_TRANSACTION?' : 'Delete transaction?',
          ),
          content: Text(
            ext.isCyber
                ? 'REMOVE THIS ENTRY PERMANENTLY?'
                : 'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(ext.isCyber ? 'CANCEL' : 'Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(ext.isCyber ? 'DELETE' : 'Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key, this.existing});

  final MoneyTransaction? existing;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _merchantController;
  late final TextEditingController _customCategoryController;
  late TransactionType _type;
  late String _category;
  late DateTime _date;
  late bool _useCustomCategory;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing != null ? _formatAmount(existing.amount) : '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _merchantController =
        TextEditingController(text: existing?.merchant ?? '');
    final category = existing?.category ?? defaultCategories.first;
    _useCustomCategory = existing != null &&
        !defaultCategories.contains(existing.category);
    _customCategoryController = TextEditingController(
      text: _useCustomCategory ? category : '',
    );
    _type = existing?.type ?? TransactionType.expense;
    _category = _useCustomCategory
        ? defaultCategories.first
        : (defaultCategories.contains(category)
            ? category
            : defaultCategories.first);
    _date = existing?.date ?? DateTime.now();
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _merchantController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing ? 'Edit transaction' : 'Add transaction',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('Type', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in TransactionType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() {
                      _type = t;
                      if (t == TransactionType.investment &&
                          !_useCustomCategory) {
                        _category = 'Investment';
                      } else if (t == TransactionType.saving &&
                          !_useCustomCategory) {
                        _category = 'Savings';
                      } else if (t == TransactionType.income &&
                          !_useCustomCategory) {
                        _category = 'Salary';
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (!_useCustomCategory)
              DropdownButtonFormField<String>(
                key: ValueKey('category-$_category'),
                initialValue: defaultCategories.contains(_category)
                    ? _category
                    : defaultCategories.first,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in defaultCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              )
            else
              TextField(
                controller: _customCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Custom category',
                  border: OutlineInputBorder(),
                ),
              ),
            TextButton(
              onPressed: () {
                setState(() => _useCustomCategory = !_useCustomCategory);
              },
              child: Text(
                _useCustomCategory
                    ? 'Use preset category'
                    : 'Use custom category',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(
                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(
              controller: _merchantController,
              decoration: const InputDecoration(
                labelText: 'Merchant (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEditing ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount greater than 0')),
      );
      return;
    }
    final category = _useCustomCategory
        ? _customCategoryController.text
        : _category;
    final actions = ref.read(transactionActionsProvider);
    try {
      final existing = widget.existing;
      if (existing != null) {
        await actions.update(
          existing: existing,
          amount: amount,
          type: _type,
          category: category,
          date: _date,
          note: _noteController.text,
          merchant: _merchantController.text,
        );
      } else {
        await actions.add(
          amount: amount,
          type: _type,
          category: category,
          date: _date,
          note: _noteController.text,
          merchant: _merchantController.text,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }
}
