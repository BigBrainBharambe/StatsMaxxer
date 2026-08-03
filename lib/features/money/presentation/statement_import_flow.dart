import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/pdf_password_exception.dart';
import 'csv_column_mapping_screen.dart';
import 'import_preview_screen.dart';
import 'money_providers.dart';

Future<void> startStatementImport(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['csv', 'ofx', 'qfx', 'pdf'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  if (!context.mounted) return;

  final file = result.files.single;
  Uint8List? bytes = file.bytes;
  if (bytes == null && !kIsWeb && file.path != null) {
    bytes = await File(file.path!).readAsBytes();
  }
  if (!context.mounted) return;

  if (bytes == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not read the selected file.')),
    );
    return;
  }

  await _openImportFlow(
    context: context,
    ref: ref,
    fileName: file.name,
    bytes: bytes,
  );
}

Future<String?> _askImportPassword(
  BuildContext context, {
  String? errorText,
}) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Statement password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'If the file is encrypted, enter the password. '
                'Leave blank if it is not protected.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Unlock'),
            ),
          ],
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _openImportFlow({
  required BuildContext context,
  required WidgetRef ref,
  required String fileName,
  required Uint8List bytes,
}) async {
  final coordinator = ref.read(importCoordinatorProvider);
  String? passwordError;

  while (true) {
    if (!context.mounted) return;
    final password = await _askImportPassword(
      context,
      errorText: passwordError,
    );
    if (password == null) return;
    if (!context.mounted) return;

    try {
      final parsed = coordinator.parseFile(
        fileName: fileName,
        bytes: bytes,
        password: password,
      );

      if (parsed.needsColumnMapping) {
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CsvColumnMappingScreen(
              headers: parsed.csvHeaders,
              dataRows: parsed.csvDataRows,
            ),
          ),
        );
        return;
      }

      if (parsed.rows.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parsed.warning ?? 'No transactions found in file.'),
          ),
        );
        return;
      }

      final preview = await coordinator.preparePreview(parsed);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImportPreviewScreen(
            rows: preview,
            warning: parsed.warning,
          ),
        ),
      );
      return;
    } on PdfPasswordException {
      passwordError = 'Incorrect password. Try again.';
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to parse statement: $e')),
      );
      return;
    }
  }
}
