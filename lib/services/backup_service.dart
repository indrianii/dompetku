import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../db/db_helper.dart';

/// Backup / restore ke file .json lokal (lewat Storage Access Framework,
/// sehingga tidak perlu izin storage maupun internet).
class BackupService {
  /// Return path/URI file jika berhasil, null jika dibatalkan.
  static Future<String?> backup() async {
    final data = await DbHelper.instance.dumpAll();
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return FilePicker.platform.saveFile(
      dialogTitle: 'Simpan backup',
      fileName: 'dompetku_backup_$stamp.json',
      bytes: bytes,
    );
  }

  /// Return true jika data berhasil dipulihkan, false jika dibatalkan.
  static Future<bool> restore() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.any, withData: true, allowMultiple: false);
    if (res == null || res.files.isEmpty) return false;
    final bytes = res.files.single.bytes;
    if (bytes == null) throw const FormatException('File tidak dapat dibaca.');
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format backup tidak valid.');
    }
    await DbHelper.instance.restoreAll(decoded);
    return true;
  }
}
