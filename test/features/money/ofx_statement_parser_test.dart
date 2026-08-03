import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';
import 'package:stat_maxxer/features/money/import/ofx_statement_parser.dart';

void main() {
  test('parses OFX statement transactions', () {
    const ofx = '''
OFXHEADER:100
DATA:OFXSGML
<OFX>
<BANKMSGSRSV1>
<STMTTRNRS>
<STMTRS>
<BANKTRANLIST>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20260718120000
<TRNAMT>-42.15
<FITID>ABC123
<NAME>WHOLE FOODS
<MEMO>GROCERY
</STMTTRN>
<STMTTRN>
<TRNTYPE>CREDIT
<DTPOSTED>20260719
<TRNAMT>1000.00
<FITID>PAY456
<NAME>ACME PAYROLL
</STMTTRN>
</BANKTRANLIST>
</STMTRS>
</STMTTRNRS>
</BANKMSGSRSV1>
</OFX>
''';
    final result = OfxStatementParser().parse(ofx);
    expect(result.rows, hasLength(2));

    final expense = result.rows[0];
    expect(expense.type, TransactionType.expense);
    expect(expense.amount, 42.15);
    expect(expense.date, DateTime(2026, 7, 18));
    expect(expense.description, 'WHOLE FOODS — GROCERY');
    expect(expense.externalId, 'ofx:ABC123');

    final income = result.rows[1];
    expect(income.type, TransactionType.income);
    expect(income.amount, 1000);
    expect(income.externalId, 'ofx:PAY456');
  });
}
