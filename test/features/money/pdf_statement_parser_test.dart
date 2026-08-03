import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';
import 'package:stat_maxxer/features/money/import/pdf_statement_parser.dart';
import 'package:stat_maxxer/features/money/import/statement_parse_utils.dart';

void main() {
  group('Indian / SBI-style parsing', () {
    test('prefers day-first dates', () {
      expect(parseFlexibleDate('01/03/2026'), DateTime(2026, 3, 1));
      expect(parseFlexibleDate('15 Mar 2024'), DateTime(2024, 3, 15));
      expect(parseFlexibleDate('15-Mar-2024'), DateTime(2024, 3, 15));
    });

    test('parses Indian lakh commas and rupee prefix', () {
      expect(parseAmount('1,23,456.00'), 123456);
      expect(parseAmount('₹349.00'), 349);
      expect(parseAmount('Rs. 2,000.00'), 2000);
      expect(parseAmount('24,651.00'), 24651);
    });

    test('parses SBI-like debit credit balance lines', () {
      const text = '''
Account Statement
Txn Date Value Date Narration Debit Credit Balance
01/03/2026 01/03/2026 BY TRANSFER-UPI/412876543/SWIGGY/HDFC 349.00  24,651.00
02/03/2026 02/03/2026 NEFT-ABCDEF12345-RENT PAYMENT-RAJESH K 15,000.00  9,651.00
05/03/2026 05/03/2026 BY TRANSFER-SALARY MAR 2026  45,000.00 54,651.00
07/03/2026 07/03/2026 ATM-SBI-BRANCH/DELHI 2,000.00  52,651.00
Opening Balance
''';
      final result = PdfStatementTextParser().parseText(text);
      expect(result.rows.length, greaterThanOrEqualTo(4));

      final swiggy = result.rows.firstWhere(
        (r) => r.description.toUpperCase().contains('SWIGGY'),
      );
      expect(swiggy.amount, 349);
      expect(swiggy.type, TransactionType.expense);
      expect(swiggy.date, DateTime(2026, 3, 1));

      final salary = result.rows.firstWhere(
        (r) => r.description.toUpperCase().contains('SALARY'),
      );
      expect(salary.amount, 45000);
      expect(salary.type, TransactionType.income);
    });

    test('merges wrapped narration lines', () {
      const text = '''
01/03/2026 UPI-MERCHANT-PAYMENT
REF123456789
349.00 10,000.00
''';
      final result = PdfStatementTextParser().parseText(text);
      expect(result.rows, isNotEmpty);
      expect(
        result.rows.first.description.toUpperCase(),
        contains('UPI-MERCHANT-PAYMENT'),
      );
      expect(result.rows.first.description, contains('REF123456789'));
    });
  });

  test('parses statement-like western trailing amount lines', () {
    const text = '''
07/18/2026 STARBUCKS STORE 123 -5.75
2026-07-19 Direct Deposit Payroll 1800.00
''';
    final result = PdfStatementTextParser().parseText(text);
    expect(result.rows.length, greaterThanOrEqualTo(2));
  });
}
