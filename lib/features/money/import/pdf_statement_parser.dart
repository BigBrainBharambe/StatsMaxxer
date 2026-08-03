import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../domain/transaction.dart';
import 'pdf_password_exception.dart';
import 'statement_parse_utils.dart';
import 'statement_row.dart';

/// Adaptive PDF/text statement parser for varied bank layouts (incl. SBI).
///
/// Strategies (tried in order, best score wins):
/// 1. Debit/credit column style (Indian banks: date + narration + debit + credit + balance)
/// 2. Signed single-amount trailing style (US cards)
/// 3. Multi-space / pipe tabular split
class PdfStatementTextParser {
  static final _leadingDate = RegExp(
    r'^\s*'
    r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'
    r'|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}'
    r'|\d{1,2}-[A-Za-z]{3}-\d{2,4}'
    r'|\d{4}[-/]\d{1,2}[-/]\d{1,2})',
  );

  StatementParseResult parseText(String text) {
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00a0', ' ');
    final rawLines = normalized.split('\n');
    final merged = _mergeContinuationLines(rawLines);

    final debitCredit = _parseDebitCreditStyle(merged);
    final trailing = _parseTrailingAmountStyle(merged);
    final tabular = _parseTabularStyle(merged);

    final candidates = [debitCredit, trailing, tabular];
    candidates.sort((a, b) => b.rows.length.compareTo(a.rows.length));
    final best = candidates.first;

    String? warning;
    if (best.rows.isEmpty) {
      warning =
          'No transactions found. Use a text-based PDF from net banking (not a scan). '
          'SBI/YONO downloads usually work after entering the statement password.';
    } else if (best.rows.length < 3) {
      warning =
          'Few transactions detected — layout may be unusual. Review the preview carefully.';
    } else if (best.strategy == 'debit_credit') {
      warning = 'Parsed using debit/credit columns (common for SBI and Indian banks).';
    }

    return StatementParseResult(
      rows: best.rows,
      format: StatementFormat.pdf,
      warning: warning,
    );
  }

  /// Join narration wrap lines (no leading date) onto the previous txn line.
  List<String> _mergeContinuationLines(List<String> lines) {
    final out = <String>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (_leadingDate.hasMatch(line) || out.isEmpty) {
        out.add(line);
      } else if (looksLikeBalanceOrHeaderRow(line)) {
        out.add(line);
      } else {
        // Continuation of narration
        out[out.length - 1] = '${out.last} $line';
      }
    }
    return out;
  }

  _ParseAttempt _parseDebitCreditStyle(List<String> lines) {
    final rows = <StatementRow>[];
    for (final line in lines) {
      if (looksLikeBalanceOrHeaderRow(line)) continue;
      final dateMatch = _leadingDate.firstMatch(line);
      if (dateMatch == null) continue;
      final date = parseFlexibleDate(dateMatch.group(1)!, preferDayFirst: true);
      if (date == null) continue;

      final rest = line.substring(dateMatch.end).trim();
      // Drop a second value-date if present at start of rest
      var body = rest;
      final secondDate = _leadingDate.firstMatch(rest);
      if (secondDate != null && secondDate.start == 0) {
        body = rest.substring(secondDate.end).trim();
      }

      final amounts = extractMoneyValues(body);
      if (amounts.isEmpty) continue;

      // Strip amount tokens from the right to leave narration
      var narration = body;
      for (final m in moneyTokenPattern.allMatches(body).toList().reversed) {
        if (m.end > narration.length - 40 || amounts.length <= 3) {
          // remove trailing money tokens
        }
      }
      narration = _stripTrailingMoney(body).trim();
      narration = narration.replaceAll(RegExp(r'\s+'), ' ');
      if (narration.length < 2) continue;
      if (_isNonTransactionNarration(narration)) continue;

      TransactionType? type;
      double? amount;

      if (amounts.length >= 3) {
        // debit, credit, balance — one of debit/credit often 0/absent as empty
        // When PDF collapses empty cells, we may only see 2 numbers: amount+balance
        final a = amounts[amounts.length - 3];
        final b = amounts[amounts.length - 2];
        // Heuristic: if one is zero-like missing, use the non-zero among first two of last three
        if (a != 0 && b == 0) {
          type = TransactionType.expense;
          amount = a.abs();
        } else if (b != 0 && a == 0) {
          type = TransactionType.income;
          amount = b.abs();
        } else if (a != 0 && b != 0) {
          // Ambiguous: prefer debit as expense if narration says ATM/UPI TO etc.
          if (_looksLikeCredit(narration)) {
            type = TransactionType.income;
            amount = b.abs();
          } else {
            type = TransactionType.expense;
            amount = a.abs();
          }
        }
      } else if (amounts.length == 2) {
        // amount + balance (empty debit or credit collapsed)
        amount = amounts[0].abs();
        type = _inferType(narration, amounts[0]);
      } else {
        amount = amounts.first.abs();
        type = _inferType(narration, amounts.first);
      }

      if (type == null || amount == null || amount <= 0) continue;
      rows.add(_row(date, amount, type, narration));
    }
    return _ParseAttempt('debit_credit', rows);
  }

  _ParseAttempt _parseTrailingAmountStyle(List<String> lines) {
    final rows = <StatementRow>[];
    final pattern = RegExp(
      r'^\s*'
      r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}|\d{4}[-/]\d{1,2}[-/]\d{1,2})'
      r'\s+(.+?)\s+'
      r'([+-]?(?:₹|Rs\.?\s*)?[0-9,]+\.\d{2})\s*$',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (looksLikeBalanceOrHeaderRow(line)) continue;
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      final date = parseFlexibleDate(match.group(1)!, preferDayFirst: true);
      final description = match.group(2)!.trim();
      final amountRaw = parseAmount(match.group(3)!);
      if (date == null ||
          description.length < 2 ||
          amountRaw == null ||
          amountRaw == 0) {
        continue;
      }
      if (_isNonTransactionNarration(description)) continue;
      final type = _inferType(description, amountRaw);
      rows.add(_row(date, amountRaw.abs(), type, description));
    }
    return _ParseAttempt('trailing', rows);
  }

  _ParseAttempt _parseTabularStyle(List<String> lines) {
    final rows = <StatementRow>[];
    for (final line in lines) {
      if (looksLikeBalanceOrHeaderRow(line)) continue;
      final parts = line
          .split(RegExp(r'\s{2,}|\t|\|'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.length < 3) continue;

      final date = parseFlexibleDate(parts.first, preferDayFirst: true);
      if (date == null) continue;

      final moneyParts = <double>[];
      final textParts = <String>[];
      for (final p in parts.skip(1)) {
        final v = parseAmount(p);
        if (v != null && moneyTokenPattern.hasMatch(p) && !_looksLikeRefOnly(p)) {
          moneyParts.add(v);
        } else if (parseFlexibleDate(p, preferDayFirst: true) == null) {
          textParts.add(p);
        }
      }
      if (moneyParts.isEmpty || textParts.isEmpty) continue;
      final narration = textParts.join(' ');
      if (_isNonTransactionNarration(narration)) continue;

      TransactionType type;
      double amount;
      if (moneyParts.length >= 2) {
        final debit = moneyParts[0];
        final credit = moneyParts.length >= 2 ? moneyParts[1] : 0.0;
        // If we have balance as third, ignore it
        if (debit != 0 && (credit == 0 || moneyParts.length >= 3)) {
          // classic debit/credit/balance OR amount/balance
          if (moneyParts.length >= 3) {
            if (debit != 0 && credit == 0) {
              type = TransactionType.expense;
              amount = debit.abs();
            } else if (credit != 0 && debit == 0) {
              type = TransactionType.income;
              amount = credit.abs();
            } else {
              type = _inferType(narration, debit);
              amount = debit.abs();
            }
          } else {
            type = _inferType(narration, debit);
            amount = debit.abs();
          }
        } else if (credit != 0) {
          type = TransactionType.income;
          amount = credit.abs();
        } else {
          type = _inferType(narration, debit);
          amount = debit.abs();
        }
      } else {
        type = _inferType(narration, moneyParts.first);
        amount = moneyParts.first.abs();
      }
      if (amount <= 0) continue;
      rows.add(_row(date, amount, type, narration));
    }
    return _ParseAttempt('tabular', rows);
  }

  String _stripTrailingMoney(String body) {
    var result = body.trimRight();
    while (true) {
      final matches = moneyTokenPattern.allMatches(result).toList();
      if (matches.isEmpty) break;
      final last = matches.last;
      // Only strip if near the end
      if (result.length - last.end > 3) break;
      result = result.substring(0, last.start).trimRight();
    }
    return result;
  }

  bool _looksLikeRefOnly(String p) {
    return RegExp(r'^[A-Z0-9]{8,}$').hasMatch(p) && !p.contains('.');
  }

  bool _isNonTransactionNarration(String narration) {
    final lower = narration.toLowerCase();
    return lower.contains('opening balance') ||
        lower.contains('closing balance') ||
        lower.contains('brought forward') ||
        lower.contains('carried forward');
  }

  bool _looksLikeCredit(String narration) {
    final lower = narration.toLowerCase();
    // Avoid bare "by transfer" — SBI uses it for both debit and credit UPI.
    const hints = [
      'by clearing',
      'salary',
      'interest credit',
      'int. credit',
      'interest paid',
      'refund',
      'neft-cr',
      'imps-cr',
      'rtgs-cr',
      'upi/cr',
      'credit interest',
      'cash deposit',
      'deposit by',
      'bulk posting-cr',
      'ach-cr',
      'inward clearing',
    ];
    if (hints.any(lower.contains)) return true;
    if (RegExp(r'\bcr\b').hasMatch(lower) && !lower.contains('credit card')) {
      return true;
    }
    // Income-ish BY TRANSFER without UPI merchant spend markers
    if (lower.contains('by transfer') &&
        (lower.contains('salary') ||
            lower.contains('payroll') ||
            lower.contains('dividend') ||
            lower.contains('pension') ||
            lower.contains('interest'))) {
      return true;
    }
    return false;
  }

  TransactionType _inferType(String description, double signedAmount) {
    if (signedAmount < 0) return TransactionType.expense;
    if (_looksLikeCredit(description)) return TransactionType.income;
    final lower = description.toLowerCase();
    const expenseHints = [
      'atm',
      'pos',
      'upi',
      'neft',
      'imps',
      'rtgs',
      'to transfer',
      'withdrawal',
      'purchase',
      'debit',
      'emi',
      'charges',
      'fee',
      'ach-',
    ];
    for (final h in expenseHints) {
      if (lower.contains(h)) return TransactionType.expense;
    }
    // Indian bank statements: positive amount without credit hint → usually debit
    return TransactionType.expense;
  }

  StatementRow _row(
    DateTime date,
    double amount,
    TransactionType type,
    String description,
  ) {
    return StatementRow(
      date: date,
      amount: amount,
      type: type,
      description: description,
      externalId: fingerprintForRow(
        date: date,
        amount: amount,
        type: type,
        description: description,
      ),
    );
  }
}

class _ParseAttempt {
  _ParseAttempt(this.strategy, this.rows);
  final String strategy;
  final List<StatementRow> rows;
}

class PdfStatementParser {
  PdfStatementParser([PdfStatementTextParser? textParser])
      : _textParser = textParser ?? PdfStatementTextParser();

  final PdfStatementTextParser _textParser;

  StatementParseResult parseBytes(List<int> bytes, {String? password}) {
    final text = extractText(bytes, password: password);
    return _textParser.parseText(text);
  }

  String extractText(List<int> bytes, {String? password}) {
    final PdfDocument document;
    try {
      document = PdfDocument(
        inputBytes: bytes,
        password: password == null || password.isEmpty ? '' : password,
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('password') ||
          msg.contains('encrypt') ||
          msg.contains('decrypt') ||
          msg.contains('owner') ||
          msg.contains('cannot open')) {
        throw const PdfPasswordException();
      }
      rethrow;
    }
    try {
      final buffer = StringBuffer();
      final extractor = PdfTextExtractor(document);
      for (var i = 0; i < document.pages.count; i++) {
        final pageText =
            extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (pageText.trim().isNotEmpty) {
          buffer.writeln(pageText);
        }
      }
      return buffer.toString();
    } finally {
      document.dispose();
    }
  }
}
