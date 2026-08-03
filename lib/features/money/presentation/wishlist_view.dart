import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/transaction.dart';
import '../domain/wishlist_item.dart';
import 'money_format.dart';
import 'money_providers.dart';
import 'wishlist_sheets.dart';

class WishlistView extends ConsumerWidget {
  const WishlistView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(wishlistItemsProvider);
    final currency = ref.watch(moneyFormatProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'Wishlist is empty.\nTap + to add a one-time buy or recurring bill.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _WishlistTile(
              item: item,
              currency: currency,
            );
          },
        );
      },
    );
  }
}

class _WishlistTile extends ConsumerWidget {
  const _WishlistTile({
    required this.item,
    required this.currency,
  });

  final WishlistItem item;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat.yMMMd();
    final subtitleParts = <String>[
      if (item.isRecurring) item.recurrenceSummary,
      if (item.isRecurring && item.nextDue != null)
        'Due ${dateFmt.format(item.nextDue!)}',
      if (item.targetType != TransactionType.expense) item.targetType.label,
      if (item.estimatedPrice != null)
        '~${currency.format(item.estimatedPrice)}',
      if (item.notes.isNotEmpty) item.notes,
    ];

    final leadingColor = item.isRecurring
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;

    return Dismissible(
      key: ValueKey(item.id),
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
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  item.isRecurring
                      ? 'Delete recurring item?'
                      : 'Remove from wishlist?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        ref.read(wishlistActionsProvider).delete(item.id);
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: leadingColor.withValues(alpha: 0.15),
          child: Icon(
            item.isRecurring
                ? Icons.autorenew
                : Icons.shopping_bag_outlined,
            color: leadingColor,
          ),
        ),
        title: Text(item.name),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: FilledButton.tonal(
          onPressed: () => showBuyWishlistItemSheet(context, item),
          child: Text(item.isRecurring ? 'Pay' : 'Bought'),
        ),
      ),
    );
  }
}
