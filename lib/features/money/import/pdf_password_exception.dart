class PdfPasswordException implements Exception {
  const PdfPasswordException([this.message = 'Incorrect password']);

  final String message;

  @override
  String toString() => message;
}
