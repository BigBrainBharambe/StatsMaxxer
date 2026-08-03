import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/transaction.dart';
import '../domain/wishlist_item.dart';
import 'money_providers.dart';

Future<void> showAddWishlistItemSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const AddWishlistItemSheet(),
  );
}

class AddWishlistItemSheet extends ConsumerStatefulWidget {
  const AddWishlistItemSheet({super.key});

  @override
  ConsumerState<AddWishlistItemSheet> createState() =>
      _AddWishlistItemSheetState();
}

class _AddWishlistItemSheetState extends ConsumerState<AddWishlistItemSheet> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _priceController = TextEditingController();
  final _customIntervalController = TextEditingController(text: '1');

  bool _isRecurring = false;
  /// Preset: weekly / monthly / custom days.
  _RecurrencePreset _preset = _RecurrencePreset.monthly;
  DateTime _nextDue = DateTime.now();
  TransactionType _targetType = TransactionType.expense;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _priceController.dispose();
    _customIntervalController.dispose();
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
              'Add wishlist item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Estimated price (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recurring expense'),
              subtitle: const Text(
                'Stay on the list after each payment; next due advances',
              ),
              value: _isRecurring,
              onChanged: (v) => setState(() => _isRecurring = v),
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 4),
              Text('Interval', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final preset in _RecurrencePreset.values)
                    ChoiceChip(
                      label: Text(preset.label),
                      selected: _preset == preset,
                      onSelected: (_) => setState(() => _preset = preset),
                    ),
                ],
              ),
              if (_preset == _RecurrencePreset.customDays) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customIntervalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Every N days',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Next due'),
                subtitle: Text(_formatDate(_nextDue)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _nextDue,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    setState(() => _nextDue = picked);
                  }
                },
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Ledger type when paid',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in TransactionTypeX.wishlistTargets)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _targetType == t,
                    onSelected: (_) => setState(() => _targetType = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name')),
      );
      return;
    }

    double? price;
    final priceText = _priceController.text.trim();
    if (priceText.isNotEmpty) {
      price = double.tryParse(priceText);
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid estimated price greater than 0'),
          ),
        );
        return;
      }
    }

    int? interval;
    WishlistRecurrenceUnit? unit;
    if (_isRecurring) {
      switch (_preset) {
        case _RecurrencePreset.weekly:
          interval = 1;
          unit = WishlistRecurrenceUnit.week;
        case _RecurrencePreset.monthly:
          interval = 1;
          unit = WishlistRecurrenceUnit.month;
        case _RecurrencePreset.customDays:
          interval = int.tryParse(_customIntervalController.text.trim());
          unit = WishlistRecurrenceUnit.day;
          if (interval == null || interval < 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enter a valid interval of at least 1 day'),
              ),
            );
            return;
          }
      }
    }

    try {
      await ref.read(wishlistActionsProvider).add(
            name: name,
            notes: _notesController.text,
            estimatedPrice: price,
            isRecurring: _isRecurring,
            recurrenceInterval: interval,
            recurrenceUnit: unit,
            nextDue: _isRecurring ? _nextDue : null,
            targetType: _targetType,
          );
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

enum _RecurrencePreset { weekly, monthly, customDays }

extension on _RecurrencePreset {
  String get label => switch (this) {
        _RecurrencePreset.weekly => 'Weekly',
        _RecurrencePreset.monthly => 'Monthly',
        _RecurrencePreset.customDays => 'Custom days',
      };
}

Future<void> showBuyWishlistItemSheet(
  BuildContext context,
  WishlistItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => BuyWishlistItemSheet(item: item),
  );
}

class BuyWishlistItemSheet extends ConsumerStatefulWidget {
  const BuyWishlistItemSheet({super.key, required this.item});

  final WishlistItem item;

  @override
  ConsumerState<BuyWishlistItemSheet> createState() =>
      _BuyWishlistItemSheetState();
}

class _BuyWishlistItemSheetState extends ConsumerState<BuyWishlistItemSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  final _customCategoryController = TextEditingController();
  String _category = 'Shopping';
  DateTime _boughtOn = DateTime.now();
  bool _useCustomCategory = false;
  late TransactionType _type;

  @override
  void initState() {
    super.initState();
    final estimate = widget.item.estimatedPrice;
    _amountController = TextEditingController(
      text: estimate != null ? estimate.toString() : '',
    );
    _noteController = TextEditingController(text: widget.item.notes);
    _type = widget.item.targetType;
    if (_type == TransactionType.investment) {
      _category = 'Investment';
    } else if (_type == TransactionType.saving) {
      _category = 'Savings';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isRecurring = widget.item.isRecurring;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isRecurring ? 'Log payment' : 'Mark as bought',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.item.name,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (isRecurring) ...[
              const SizedBox(height: 4),
              Text(
                'Recurring · stays on wishlist after payment',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Type', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in TransactionTypeX.wishlistTargets)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              autofocus: widget.item.estimatedPrice == null,
            ),
            const SizedBox(height: 12),
            if (!_useCustomCategory)
              DropdownButtonFormField<String>(
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
              title: Text(isRecurring ? 'Paid on' : 'Bought on'),
              subtitle: Text(
                '${_boughtOn.year}-${_boughtOn.month.toString().padLeft(2, '0')}-${_boughtOn.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _boughtOn,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  final now = DateTime.now();
                  setState(() {
                    _boughtOn = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      now.hour,
                      now.minute,
                      now.second,
                    );
                  });
                }
              },
            ),
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
              child: const Text('Add to ledger'),
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
    final category =
        _useCustomCategory ? _customCategoryController.text : _category;
    try {
      await ref.read(wishlistActionsProvider).buy(
            item: widget.item,
            amount: amount,
            category: category,
            boughtOn: _boughtOn,
            note: _noteController.text,
            type: _type,
          );
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
