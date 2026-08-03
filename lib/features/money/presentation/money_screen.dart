import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'add_transaction_sheet.dart';
import 'money_ledger_view.dart';
import 'money_providers.dart';
import 'statement_import_flow.dart';
import 'wishlist_sheets.dart';
import 'wishlist_view.dart';

class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        ref.read(moneyTabIndexProvider.notifier).setIndex(_tabs.index);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = StatThemeExtension.of(context);

    return ListenableBuilder(
      listenable: _tabs,
      builder: (context, _) {
        final onLedger = _tabs.index == 0;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(ext.isCyber ? 'LEDGER' : 'Money'),
            actions: [
              if (onLedger)
                IconButton(
                  tooltip: 'Import statement',
                  icon: const Icon(Icons.upload_file),
                  onPressed: () => startStatementImport(context, ref),
                ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: ext.isCyber ? 'LEDGER' : 'Money'),
                Tab(text: ext.isCyber ? 'WISH' : 'Wishlist'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: onLedger ? 'money_fab' : 'wishlist_fab',
            onPressed: () {
              if (onLedger) {
                showAddTransactionSheet(context);
              } else {
                showAddWishlistItemSheet(context);
              }
            },
            child: const Icon(Icons.add),
          ),
          body: TabBarView(
            controller: _tabs,
            children: const [
              MoneyLedgerView(),
              WishlistView(),
            ],
          ),
        );
      },
    );
  }
}
