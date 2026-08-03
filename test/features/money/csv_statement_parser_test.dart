import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/money/import/csv_statement_parser.dart';

void main() {
  late CsvStatementParser parser;

  setUp(() {
    parser = CsvStatementParser();
  });

  test('parses amount column csv', () {
    const csv = '''
Date,Description,Amount
2026-07-18,Coffee Shop,-4.50
07/19/2026,Payroll Direct Deposit,2500.00
''';
    final result = parser.parse(csv);
    expect(result.needsColumnMapping, isFalse);
    expect(result.rows, hasLength(2));
    expect(result.rows[0].description, 'Coffee Shop');
    expect(result.rows[0].amount, 4.5);
    expect(result.rows[0].type.name, 'expense');
    expect(result.rows[1].type.name, 'income');
    expect(result.rows[1].amount, 2500);
    expect(result.rows[0].externalId, isNotNull);
  });

  test('parses debit credit columns', () {
    const csv = '''
Transaction Date,Payee,Debit,Credit
07/18/2026,Uber,12.00,
07/18/2026,Refund,,5.00
''';
    final result = parser.parse(csv);
    expect(result.rows, hasLength(2));
    expect(result.rows[0].type.name, 'expense');
    expect(result.rows[0].amount, 12);
    expect(result.rows[1].type.name, 'income');
    expect(result.rows[1].amount, 5);
  });

  test('requests mapping when headers unknown', () {
    const csv = '''
ColA,ColB,ColC
a,b,c
''';
    final result = parser.parse(csv);
    expect(result.needsColumnMapping, isTrue);
    expect(result.csvHeaders, ['ColA', 'ColB', 'ColC']);
    expect(result.rows, isEmpty);
  });
}
