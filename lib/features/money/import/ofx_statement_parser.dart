import '../domain/transaction.dart';
import 'statement_parse_utils.dart';
import 'statement_row.dart';

class OfxStatementParser {
  StatementParseResult parse(String content) {
    final blocks = _extractTransactionBlocks(content);
    final rows = <StatementRow>[];

    for (final block in blocks) {
      final amountRaw = _tagValue(block, 'TRNAMT');
      final dateRaw = _tagValue(block, 'DTPOSTED') ?? _tagValue(block, 'DTUSER');
      final fitId = _tagValue(block, 'FITID');
      final name = _tagValue(block, 'NAME') ?? '';
      final memo = _tagValue(block, 'MEMO') ?? '';
      final trnType = (_tagValue(block, 'TRNTYPE') ?? '').toUpperCase();

      final amountParsed = amountRaw == null ? null : parseAmount(amountRaw);
      final date = dateRaw == null ? null : parseFlexibleDate(dateRaw);
      if (amountParsed == null || amountParsed == 0 || date == null) continue;

      final description = [
        name.trim(),
        memo.trim(),
      ].where((s) => s.isNotEmpty).join(' — ');
      if (description.isEmpty) continue;

      TransactionType type;
      if (trnType.contains('CREDIT') || trnType == 'DEP' || trnType == 'DIRECTDEP') {
        type = TransactionType.income;
      } else if (trnType.contains('DEBIT') ||
          trnType == 'POS' ||
          trnType == 'ATM' ||
          trnType == 'CHECK' ||
          trnType == 'PAYMENT' ||
          trnType == 'WITHDRAWAL') {
        type = TransactionType.expense;
      } else {
        type = amountParsed < 0
            ? TransactionType.expense
            : TransactionType.income;
      }

      final amount = amountParsed.abs();
      final externalId = (fitId != null && fitId.isNotEmpty)
          ? 'ofx:$fitId'
          : fingerprintForRow(
              date: date,
              amount: amount,
              type: type,
              description: description,
            );

      rows.add(
        StatementRow(
          date: date,
          amount: amount,
          type: type,
          description: description,
          externalId: externalId,
        ),
      );
    }

    return StatementParseResult(
      rows: rows,
      format: StatementFormat.ofx,
      warning: rows.isEmpty
          ? 'No transactions found in OFX/QFX file.'
          : null,
    );
  }

  List<String> _extractTransactionBlocks(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = <String>[];
    final startRegex = RegExp(r'<STMTTRN>', caseSensitive: false);
    final endRegex = RegExp(r'</STMTTRN>', caseSensitive: false);

    var searchFrom = 0;
    while (true) {
      final start = startRegex.firstMatch(normalized.substring(searchFrom));
      if (start == null) break;
      final startIndex = searchFrom + start.end;
      final end = endRegex.firstMatch(normalized.substring(startIndex));
      if (end == null) {
        // SGML-style OFX without closing tags: read until next STMTTRN or end
        final next = startRegex.firstMatch(normalized.substring(startIndex));
        final endIndex = next == null
            ? normalized.length
            : startIndex + next.start;
        blocks.add(normalized.substring(startIndex, endIndex));
        searchFrom = endIndex;
      } else {
        blocks.add(normalized.substring(startIndex, startIndex + end.start));
        searchFrom = startIndex + end.end;
      }
    }
    return blocks;
  }

  String? _tagValue(String block, String tag) {
    final regex = RegExp(
      '<$tag>([^<\\n\\r]*)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(block);
    if (match == null) return null;
    return match.group(1)?.trim();
  }
}
