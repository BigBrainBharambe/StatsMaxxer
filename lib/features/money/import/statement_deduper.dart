import '../domain/transaction.dart';
import 'statement_parse_utils.dart';
import 'statement_row.dart';

enum DedupStatus { isNew, likelyDuplicate, alreadyImported }

class DedupedStatementRow {
  const DedupedStatementRow({
    required this.row,
    required this.status,
    this.matchedTransaction,
    this.selected = true,
    this.category = 'Other',
  });

  final StatementRow row;
  final DedupStatus status;
  final MoneyTransaction? matchedTransaction;
  final bool selected;
  final String category;

  bool get defaultSelected => status == DedupStatus.isNew;

  DedupedStatementRow copyWith({
    DedupStatus? status,
    MoneyTransaction? matchedTransaction,
    bool? selected,
    String? category,
  }) {
    return DedupedStatementRow(
      row: row,
      status: status ?? this.status,
      matchedTransaction: matchedTransaction ?? this.matchedTransaction,
      selected: selected ?? this.selected,
      category: category ?? this.category,
    );
  }
}

class StatementDeduper {
  List<DedupedStatementRow> match({
    required List<StatementRow> rows,
    required List<MoneyTransaction> existing,
  }) {
    final byExternalId = <String, MoneyTransaction>{};
    for (final tx in existing) {
      final id = tx.externalId;
      if (id != null && id.isNotEmpty) {
        byExternalId[id] = tx;
      }
    }

    return rows.map((row) {
      final ext = row.externalId;
      if (ext != null && ext.isNotEmpty && byExternalId.containsKey(ext)) {
        return DedupedStatementRow(
          row: row,
          status: DedupStatus.alreadyImported,
          matchedTransaction: byExternalId[ext],
          selected: false,
        );
      }

      final match = _findLikelyMatch(row, existing);
      if (match != null) {
        return DedupedStatementRow(
          row: row,
          status: DedupStatus.likelyDuplicate,
          matchedTransaction: match,
          selected: false,
        );
      }

      return DedupedStatementRow(
        row: row,
        status: DedupStatus.isNew,
        selected: true,
      );
    }).toList();
  }

  MoneyTransaction? _findLikelyMatch(
    StatementRow row,
    List<MoneyTransaction> existing,
  ) {
    final rowDesc = normalizeDescription(row.description);
    final rowTokens = rowDesc.split(' ').where((t) => t.length > 1).toSet();

    for (final tx in existing) {
      if (!_sameDay(tx.date, row.date)) continue;
      if ((tx.amount - row.amount).abs() > 0.01) continue;
      if (tx.type != row.type) continue;

      final existingDesc = normalizeDescription(
        [
          tx.merchant,
          tx.note,
          tx.category,
        ].where((s) => s.trim().isNotEmpty).join(' '),
      );
      if (existingDesc.isEmpty && rowDesc.isEmpty) return tx;
      if (_descriptionsOverlap(rowDesc, rowTokens, existingDesc)) {
        return tx;
      }
    }
    return null;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _descriptionsOverlap(
    String rowDesc,
    Set<String> rowTokens,
    String existingDesc,
  ) {
    if (rowDesc.isEmpty || existingDesc.isEmpty) return false;
    if (rowDesc == existingDesc) return true;
    if (rowDesc.contains(existingDesc) || existingDesc.contains(rowDesc)) {
      return true;
    }
    final existingTokens =
        existingDesc.split(' ').where((t) => t.length > 1).toSet();
    if (rowTokens.isEmpty || existingTokens.isEmpty) return false;

    // Shared brand-like token (e.g. "starbucks" in note vs statement desc).
    final significantRow = rowTokens.where((t) => t.length >= 4).toSet();
    final significantExisting =
        existingTokens.where((t) => t.length >= 4).toSet();
    if (significantRow.intersection(significantExisting).isNotEmpty) {
      return true;
    }

    final intersection = rowTokens.intersection(existingTokens);
    final union = rowTokens.union(existingTokens);
    return intersection.length / union.length >= 0.4;
  }
}
