import 'package:csv/csv.dart';

import '../domain/transaction.dart';
import 'statement_parse_utils.dart';
import 'statement_row.dart';

class CsvColumnMapping {
  const CsvColumnMapping({
    required this.dateIndex,
    required this.descriptionIndex,
    this.amountIndex,
    this.debitIndex,
    this.creditIndex,
  });

  final int dateIndex;
  final int descriptionIndex;
  final int? amountIndex;
  final int? debitIndex;
  final int? creditIndex;
}

class CsvStatementParser {
  static const _dateHeaders = {
    'date',
    'posted date',
    'posting date',
    'transaction date',
    'trans date',
    'txn date',
    'txn. date',
    'value date',
    'tran date',
  };

  static const _descriptionHeaders = {
    'description',
    'desc',
    'memo',
    'payee',
    'name',
    'merchant',
    'details',
    'narrative',
    'narration',
    'particulars',
    'remarks',
    'transaction remarks',
    'transaction details',
  };

  static const _amountHeaders = {
    'amount',
    'transaction amount',
    'amt',
    'value',
    'txn amount',
  };

  static const _debitHeaders = {
    'debit',
    'withdrawal',
    'withdrawals',
    'money out',
    'out',
    'debit amount',
    'withdrawal amt.',
    'withdrawal amt',
    'dr amount',
    'dr',
  };

  static const _creditHeaders = {
    'credit',
    'deposit',
    'deposits',
    'money in',
    'in',
    'credit amount',
    'deposit amt.',
    'deposit amt',
    'cr amount',
    'cr',
  };

  StatementParseResult parse(String content) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));

    if (rows.isEmpty) {
      return const StatementParseResult(
        rows: [],
        format: StatementFormat.csv,
        warning: 'CSV file is empty.',
      );
    }

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows
        .skip(1)
        .map((r) => r.map((e) => e.toString()).toList())
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .toList();

    final mapping = detectMapping(headers);
    if (mapping == null) {
      return StatementParseResult(
        rows: const [],
        format: StatementFormat.csv,
        needsColumnMapping: true,
        csvHeaders: headers,
        csvDataRows: dataRows,
      );
    }

    return StatementParseResult(
      rows: mapRows(dataRows, mapping),
      format: StatementFormat.csv,
      csvHeaders: headers,
      csvDataRows: dataRows,
    );
  }

  CsvColumnMapping? detectMapping(List<String> headers) {
    final normalized = headers.map((h) => h.toLowerCase().trim()).toList();

    int? find(Set<String> candidates) {
      for (var i = 0; i < normalized.length; i++) {
        if (candidates.contains(normalized[i])) return i;
      }
      // Fuzzy only for longer labels (avoid matching "in"/"cr" inside other words)
      for (var i = 0; i < normalized.length; i++) {
        final header = normalized[i];
        for (final c in candidates) {
          if (c.length < 4) continue;
          if (header.contains(c) || (header.length >= 4 && c.contains(header))) {
            return i;
          }
        }
      }
      return null;
    }

    final dateIndex = find(_dateHeaders);
    final descriptionIndex = find(_descriptionHeaders);
    final amountIndex = find(_amountHeaders);
    final debitIndex = find(_debitHeaders);
    final creditIndex = find(_creditHeaders);

    if (dateIndex == null || descriptionIndex == null) return null;
    if (amountIndex == null && debitIndex == null && creditIndex == null) {
      return null;
    }

    return CsvColumnMapping(
      dateIndex: dateIndex,
      descriptionIndex: descriptionIndex,
      amountIndex: amountIndex,
      debitIndex: debitIndex,
      creditIndex: creditIndex,
    );
  }

  List<StatementRow> mapRows(
    List<List<String>> dataRows,
    CsvColumnMapping mapping,
  ) {
    final result = <StatementRow>[];
    for (final row in dataRows) {
      String cell(int index) =>
          index < row.length ? row[index].trim() : '';

      final date =
          parseFlexibleDate(cell(mapping.dateIndex), preferDayFirst: true);
      if (date == null) continue;

      final description = cell(mapping.descriptionIndex);
      if (description.isEmpty) continue;

      TransactionType? type;
      double? amount;

      if (mapping.amountIndex != null) {
        final raw = parseAmount(cell(mapping.amountIndex!));
        if (raw == null || raw == 0) continue;
        type = raw < 0 ? TransactionType.expense : TransactionType.income;
        amount = raw.abs();
      } else {
        final debit = mapping.debitIndex != null
            ? parseAmount(cell(mapping.debitIndex!))
            : null;
        final credit = mapping.creditIndex != null
            ? parseAmount(cell(mapping.creditIndex!))
            : null;
        if (debit != null && debit != 0) {
          type = TransactionType.expense;
          amount = debit.abs();
        } else if (credit != null && credit != 0) {
          type = TransactionType.income;
          amount = credit.abs();
        }
      }

      if (type == null || amount == null || amount <= 0) continue;

      final externalId = fingerprintForRow(
        date: date,
        amount: amount,
        type: type,
        description: description,
      );

      result.add(
        StatementRow(
          date: date,
          amount: amount,
          type: type,
          description: description,
          externalId: externalId,
        ),
      );
    }
    return result;
  }
}
