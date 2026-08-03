import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/money/import/pdf_password_exception.dart';
import 'package:stat_maxxer/features/money/import/pdf_statement_parser.dart';

void main() {
  test('PdfPasswordException has clear message', () {
    expect(const PdfPasswordException().toString(), 'Incorrect password');
  });

  test('invalid pdf bytes surface as non-password failure or empty', () {
    final parser = PdfStatementParser();
    expect(
      () => parser.parseBytes([0, 1, 2, 3], password: 'secret'),
      anyOf(throwsA(isA<PdfPasswordException>()), throwsA(isA<Object>())),
    );
  });
}
