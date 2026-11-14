import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CsvBuilder {
  CsvBuilder(this.header);

  final List<String> header;
  final List<List<Object?>> _rows = [];

  void addRow(List<Object?> values) => _rows.add(values);

  String build() {
    final buffer = StringBuffer();
    buffer.writeln(header.map(_escape).join(','));
    for (final row in _rows) {
      buffer.writeln(row.map(_escape).join(','));
    }
    return buffer.toString();
  }

  String _escape(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}

Future<void> shareText({
  required String text,
  String? subject,
}) async {
  await SharePlus.instance.share(
    ShareParams(text: text, subject: subject),
  );
}

Future<void> shareCsvFile({
  required String fileName,
  required String content,
  required String subject,
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: subject,
    ),
  );
}
