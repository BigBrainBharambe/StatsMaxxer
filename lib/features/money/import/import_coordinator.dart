import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../domain/transaction.dart';
import '../domain/transaction_repository.dart';
import 'csv_statement_parser.dart';
import 'ofx_statement_parser.dart';
import 'pdf_statement_parser.dart';
import 'statement_deduper.dart';
import 'statement_row.dart';

class ImportCommitResult {
  const ImportCommitResult({
    required this.imported,
    required this.skipped,
  });

  final int imported;
  final int skipped;
}

class ImportCoordinator {
  ImportCoordinator(
    this._repository, {
    CsvStatementParser? csvParser,
    OfxStatementParser? ofxParser,
    PdfStatementParser? pdfParser,
    StatementDeduper? deduper,
    Uuid? uuid,
  })  : _csvParser = csvParser ?? CsvStatementParser(),
        _ofxParser = ofxParser ?? OfxStatementParser(),
        _pdfParser = pdfParser ?? PdfStatementParser(),
        _deduper = deduper ?? StatementDeduper(),
        _uuid = uuid ?? const Uuid();

  final TransactionRepository _repository;
  final CsvStatementParser _csvParser;
  final OfxStatementParser _ofxParser;
  final PdfStatementParser _pdfParser;
  final StatementDeduper _deduper;
  final Uuid _uuid;

  StatementParseResult parseFile({
    required String fileName,
    required Uint8List bytes,
    String? password,
  }) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.ofx') || lower.endsWith('.qfx')) {
      return _ofxParser.parse(utf8.decode(bytes, allowMalformed: true));
    }
    if (lower.endsWith('.pdf')) {
      return _pdfParser.parseBytes(bytes, password: password);
    }
    // Default / .csv
    return _csvParser.parse(utf8.decode(bytes, allowMalformed: true));
  }

  Future<List<DedupedStatementRow>> preparePreview(
    StatementParseResult parsed,
  ) async {
    final existing = await _repository.getTransactions();
    return _deduper.match(rows: parsed.rows, existing: existing);
  }

  Future<ImportCommitResult> commit(List<DedupedStatementRow> rows) async {
    final selected = rows.where((r) => r.selected).toList();
    final skipped = rows.length - selected.length;
    if (selected.isEmpty) {
      return ImportCommitResult(imported: 0, skipped: skipped);
    }

    final transactions = selected.map((item) {
      final row = item.row;
      return MoneyTransaction(
        id: _uuid.v4(),
        amount: row.amount,
        type: row.type,
        category: item.category.trim().isEmpty ? 'Other' : item.category.trim(),
        date: row.date,
        merchant: row.description.trim(),
        externalId: row.externalId,
        source: TransactionSource.import,
      );
    }).toList();

    final imported = await _repository.addTransactions(transactions);
    return ImportCommitResult(imported: imported, skipped: skipped);
  }
}
