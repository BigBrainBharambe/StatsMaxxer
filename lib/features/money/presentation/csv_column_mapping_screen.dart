import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/csv_statement_parser.dart';
import '../import/statement_row.dart';
import 'import_preview_screen.dart';
import 'money_providers.dart';

class CsvColumnMappingScreen extends ConsumerStatefulWidget {
  const CsvColumnMappingScreen({
    super.key,
    required this.headers,
    required this.dataRows,
  });

  final List<String> headers;
  final List<List<String>> dataRows;

  @override
  ConsumerState<CsvColumnMappingScreen> createState() =>
      _CsvColumnMappingScreenState();
}

class _CsvColumnMappingScreenState
    extends ConsumerState<CsvColumnMappingScreen> {
  int? _dateIndex;
  int? _descriptionIndex;
  int? _amountIndex;
  int? _debitIndex;
  int? _creditIndex;
  bool _useSplitAmount = false;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < widget.headers.length; i++)
        DropdownMenuItem(value: i, child: Text(widget.headers[i])),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Map CSV columns')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Could not auto-detect columns. Map date, description, and amount fields.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _dateIndex,
            decoration: const InputDecoration(
              labelText: 'Date column',
              border: OutlineInputBorder(),
            ),
            items: items,
            onChanged: (v) => setState(() => _dateIndex = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _descriptionIndex,
            decoration: const InputDecoration(
              labelText: 'Description column',
              border: OutlineInputBorder(),
            ),
            items: items,
            onChanged: (v) => setState(() => _descriptionIndex = v),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Separate debit / credit columns'),
            value: _useSplitAmount,
            onChanged: (v) => setState(() => _useSplitAmount = v),
          ),
          if (!_useSplitAmount)
            DropdownButtonFormField<int>(
              initialValue: _amountIndex,
              decoration: const InputDecoration(
                labelText: 'Amount column',
                border: OutlineInputBorder(),
              ),
              items: items,
              onChanged: (v) => setState(() => _amountIndex = v),
            )
          else ...[
            DropdownButtonFormField<int>(
              initialValue: _debitIndex,
              decoration: const InputDecoration(
                labelText: 'Debit column',
                border: OutlineInputBorder(),
              ),
              items: items,
              onChanged: (v) => setState(() => _debitIndex = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _creditIndex,
              decoration: const InputDecoration(
                labelText: 'Credit column',
                border: OutlineInputBorder(),
              ),
              items: items,
              onChanged: (v) => setState(() => _creditIndex = v),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _continue,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _continue() async {
    if (_dateIndex == null || _descriptionIndex == null) {
      _showError('Select date and description columns.');
      return;
    }
    if (!_useSplitAmount && _amountIndex == null) {
      _showError('Select an amount column.');
      return;
    }
    if (_useSplitAmount && _debitIndex == null && _creditIndex == null) {
      _showError('Select debit and/or credit columns.');
      return;
    }

    final mapping = CsvColumnMapping(
      dateIndex: _dateIndex!,
      descriptionIndex: _descriptionIndex!,
      amountIndex: _useSplitAmount ? null : _amountIndex,
      debitIndex: _useSplitAmount ? _debitIndex : null,
      creditIndex: _useSplitAmount ? _creditIndex : null,
    );

    final rows = CsvStatementParser().mapRows(widget.dataRows, mapping);
    if (rows.isEmpty) {
      _showError('No transactions found with that mapping.');
      return;
    }

    final coordinator = ref.read(importCoordinatorProvider);
    final preview = await coordinator.preparePreview(
      StatementParseResult(rows: rows, format: StatementFormat.csv),
    );

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ImportPreviewScreen(rows: preview),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
