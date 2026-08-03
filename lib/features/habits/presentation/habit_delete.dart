import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'habits_providers.dart';

Future<bool> confirmAndDeleteHabit({
  required BuildContext context,
  required WidgetRef ref,
  required String habitId,
  required String habitName,
}) async {
  final ext = StatThemeExtension.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(ext.isCyber ? 'DELETE_HABIT?' : 'Delete habit?'),
      content: Text(
        ext.isCyber
            ? 'REMOVE "$habitName" PERMANENTLY?'
            : 'Remove "$habitName" and all its history?',
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
  );
  if (ok != true) return false;
  await ref.read(habitActionsProvider).deleteHabit(habitId);
  return true;
}
