import '../domain/transaction.dart';

class StatementRow {
  const StatementRow({
    required this.date,
    required this.amount,
    required this.type,
    required this.description,
    this.externalId,
  });

  final DateTime date;
  final double amount;
  final TransactionType type;
  final String description;
  final String? externalId;
}

enum StatementFormat { csv, ofx, pdf }

class StatementParseResult {
  const StatementParseResult({
    required this.rows,
    required this.format,
    this.needsColumnMapping = false,
    this.csvHeaders = const [],
    this.csvDataRows = const [],
    this.warning,
  });

  final List<StatementRow> rows;
  final StatementFormat format;
  final bool needsColumnMapping;
  final List<String> csvHeaders;
  final List<List<String>> csvDataRows;
  final String? warning;
}
