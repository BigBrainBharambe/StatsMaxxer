import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

import '../domain/transaction.dart';

String normalizeDescription(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String fingerprintForRow({
  required DateTime date,
  required double amount,
  required TransactionType type,
  required String description,
}) {
  final day =
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final payload =
      '$day|${amount.toStringAsFixed(2)}|${type.name}|${normalizeDescription(description)}';
  return sha1.convert(utf8.encode(payload)).toString();
}

/// Prefer day-first (Indian bank) when ambiguous like 01/03/2026.
DateTime? parseFlexibleDate(String raw, {bool preferDayFirst = true}) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final iso = DateTime.tryParse(value);
  if (iso != null && !value.contains('/')) {
    return DateTime(iso.year, iso.month, iso.day);
  }

  final slash = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$');
  final slashMatch = slash.firstMatch(value);
  if (slashMatch != null) {
    var a = int.parse(slashMatch.group(1)!);
    var b = int.parse(slashMatch.group(2)!);
    var y = int.parse(slashMatch.group(3)!);
    if (y < 100) y += 2000;
    late int day;
    late int month;
    if (a > 12 && b <= 12) {
      day = a;
      month = b;
    } else if (b > 12 && a <= 12) {
      month = a;
      day = b;
    } else if (preferDayFirst) {
      day = a;
      month = b;
    } else {
      month = a;
      day = b;
    }
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(y, month, day);
    }
  }

  const patterns = [
    'dd MMM yyyy',
    'd MMM yyyy',
    'dd-MMM-yyyy',
    'd-MMM-yyyy',
    'MMM d, yyyy',
    'MMMM d, yyyy',
    'yyyy-MM-dd',
  ];

  for (final pattern in patterns) {
    try {
      final parsed = DateFormat(pattern).parseStrict(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } on FormatException {
      continue;
    }
  }

  final ofx = RegExp(r'^(\d{4})(\d{2})(\d{2})');
  final match = ofx.firstMatch(value);
  if (match != null) {
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  return null;
}

/// Handles US commas, Indian lakhs (`1,23,456.00`), ₹ / Rs prefixes.
double? parseAmount(String raw) {
  var cleaned = raw.trim();
  if (cleaned.isEmpty || cleaned == '-' || cleaned == '--') return null;
  cleaned = cleaned
      .replaceAll('₹', '')
      .replaceAll(RegExp(r'Rs\.?\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'INR\s*', caseSensitive: false), '')
      .replaceAll(',', '')
      .replaceAll(' ', '')
      .trim();
  if (cleaned.startsWith('(') && cleaned.endsWith(')')) {
    cleaned = '-${cleaned.substring(1, cleaned.length - 1)}';
  }
  if (cleaned.endsWith('DR') || cleaned.endsWith('Dr')) {
    cleaned = '-${cleaned.substring(0, cleaned.length - 2)}';
  }
  if (cleaned.endsWith('CR') || cleaned.endsWith('Cr')) {
    cleaned = cleaned.substring(0, cleaned.length - 2);
  }
  return double.tryParse(cleaned);
}

/// Prefers real money tokens (decimals / commas / currency) so UPI refs aren't
/// treated as amounts.
final moneyTokenPattern = RegExp(
  r'(?:'
  r'(?:₹|Rs\.?\s*|INR\s*)[+-]?'
  r'(?:\d{1,3}(?:,\d{2})+,\d{3}|\d{1,3}(?:,\d{3})+|\d+)'
  r'(?:\.\d{1,2})?'
  r'|'
  r'(?<![A-Za-z0-9])[+-]?'
  r'(?:\d{1,3}(?:,\d{2})+,\d{3}|\d{1,3}(?:,\d{3})+|\d+)'
  r'\.\d{2}'
  r'(?:\s*(?:Dr|DR|Cr|CR))?'
  r'(?![A-Za-z0-9])'
  r'|'
  r'(?<![A-Za-z0-9])[+-]?'
  r'(?:\d{1,3}(?:,\d{2})+,\d{3}|\d{1,3}(?:,\d{3})+)'
  r'(?:\.\d{1,2})?'
  r'(?:\s*(?:Dr|DR|Cr|CR))?'
  r'(?![A-Za-z0-9])'
  r')',
  caseSensitive: false,
);

List<double> extractMoneyValues(String line) {
  final values = <double>[];
  for (final m in moneyTokenPattern.allMatches(line)) {
    final v = parseAmount(m.group(0)!);
    if (v != null) values.add(v);
  }
  return values;
}

bool looksLikeBalanceOrHeaderRow(String line) {
  final lower = line.toLowerCase();
  const skip = [
    'opening balance',
    'closing balance',
    'brought forward',
    'carried forward',
    'b/f',
    'c/f',
    'txn date',
    'value date',
    'transaction date',
    'narration',
    'particulars',
    'debit',
    'credit',
    'balance',
    'page total',
    'account statement',
    'statement of account',
    'branch code',
    'ifs code',
    'ifsc',
    'customer no',
  ];
  // Pure header lines (short + keyword)
  for (final s in skip) {
    if (lower == s || (lower.contains(s) && extractMoneyValues(line).isEmpty)) {
      return true;
    }
  }
  if (lower.contains('opening balance') || lower.contains('closing balance')) {
    return true;
  }
  return false;
}
