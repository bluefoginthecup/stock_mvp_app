import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

enum BackupFileDeliveryMode {
  saved,
  shared,
}

class BackupFileDeliveryResult {
  final BackupFileDeliveryMode mode;
  final String? savedPath;

  const BackupFileDeliveryResult({
    required this.mode,
    this.savedPath,
  });

  String message(String label) {
    switch (mode) {
      case BackupFileDeliveryMode.saved:
        return '$label 저장 완료: $savedPath';
      case BackupFileDeliveryMode.shared:
        return '$label 공유 완료';
    }
  }
}

class BackupFileDeliveryService {
  const BackupFileDeliveryService();

  Future<BackupFileDeliveryResult?> deliverBackupFile({
    required File file,
    required String fileName,
    required String subject,
    required List<String> allowedExtensions,
  }) async {
    if (_usesSaveDialog) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '백업 파일 저장',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (outputPath == null) return null;

      final target = File(outputPath);
      if (!p.equals(file.path, target.path)) {
        await target.parent.create(recursive: true);
        await file.copy(target.path);
      }

      return BackupFileDeliveryResult(
        mode: BackupFileDeliveryMode.saved,
        savedPath: target.path,
      );
    }

    await Share.shareXFiles(
      [XFile(file.path, name: fileName)],
      subject: subject,
    );
    return const BackupFileDeliveryResult(
      mode: BackupFileDeliveryMode.shared,
    );
  }

  bool get _usesSaveDialog {
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }
}
