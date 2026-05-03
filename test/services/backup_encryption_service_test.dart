import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockapp_mvp/src/services/backup_encryption_service.dart';

void main() {
  group('BackupEncryptionService', () {
    late Directory tempDir;
    late BackupEncryptionService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('stockapp_encrypt_test_');
      service = const BackupEncryptionService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('round-trips zip bytes with password and recovery key', () async {
      final originalZip = await _createTestZip(tempDir);
      final originalBytes = await originalZip.readAsBytes();
      final encryptedFile = File('${originalZip.path}.stockbackup');

      final encrypted = await service.encryptZip(
        zipFile: originalZip,
        outputFile: encryptedFile,
        password: 'correct horse battery staple',
        recoveryKey: 'STOCK-ABCD-EFGH-IJKL-MNOP-QRST-UVWX',
      );

      expect(await encrypted.file.exists(), isTrue);
      expect(encrypted.header['algorithm'], 'AES-256-GCM');
      expect(encrypted.header['kdf'], 'PBKDF2-HMAC-SHA256');

      final passwordDecrypted = await service.decryptToZip(
        encryptedFile: encrypted.file,
        outputFile: File('${tempDir.path}/password_restore.zip'),
        password: 'correct horse battery staple',
      );
      expect(await passwordDecrypted.file.readAsBytes(), originalBytes);

      final recoveryDecrypted = await service.decryptToZip(
        encryptedFile: encrypted.file,
        outputFile: File('${tempDir.path}/recovery_restore.zip'),
        recoveryKey: 'STOCK-ABCD-EFGH-IJKL-MNOP-QRST-UVWX',
      );
      expect(await recoveryDecrypted.file.readAsBytes(), originalBytes);
    });

    test('fails with wrong password and wrong recovery key', () async {
      final originalZip = await _createTestZip(tempDir);
      final encrypted = await service.encryptZip(
        zipFile: originalZip,
        password: 'correct-password',
        recoveryKey: 'STOCK-2222-3333-4444-5555-6666-7777',
      );

      await expectLater(
        service.decryptToZip(
          encryptedFile: encrypted.file,
          outputFile: File('${tempDir.path}/wrong_password.zip'),
          password: 'wrong-password',
        ),
        throwsA(isA<BackupEncryptionException>()),
      );

      await expectLater(
        service.decryptToZip(
          encryptedFile: encrypted.file,
          outputFile: File('${tempDir.path}/wrong_recovery.zip'),
          recoveryKey: 'STOCK-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
        ),
        throwsA(isA<BackupEncryptionException>()),
      );
    });
  });
}

Future<File> _createTestZip(Directory tempDir) async {
  final sourceDir = Directory('${tempDir.path}/source');
  await sourceDir.create(recursive: true);
  await File('${sourceDir.path}/manifest.json').writeAsString(
    '{"backupId":"test","dbSchemaVersion":1}',
    flush: true,
  );
  await File('${sourceDir.path}/stockapp.db').writeAsBytes(
    List<int>.generate(4096, (index) => index % 251),
    flush: true,
  );

  final zipFile = File('${tempDir.path}/stockapp_full_backup_test.zip');
  final encoder = ZipFileEncoder();
  encoder.create(zipFile.path);
  try {
    await encoder.addFile(File('${sourceDir.path}/manifest.json'));
    await encoder.addFile(File('${sourceDir.path}/stockapp.db'));
  } finally {
    await encoder.close();
  }
  return zipFile;
}
