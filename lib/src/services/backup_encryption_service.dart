import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

class BackupEncryptionException implements Exception {
  final String message;
  final Object? cause;

  const BackupEncryptionException(this.message, {this.cause});

  @override
  String toString() => message;
}

class EncryptedBackupFile {
  final File file;
  final Map<String, Object?> header;

  const EncryptedBackupFile({
    required this.file,
    required this.header,
  });
}

class DecryptedBackupFile {
  final File file;
  final Map<String, Object?> header;

  const DecryptedBackupFile({
    required this.file,
    required this.header,
  });
}

class BackupEncryptionService {
  static const int encryptionVersion = 1;
  static const int kdfIterations = 210000;
  static const String encryptedExtension = '.stockbackup';
  static const String _magic = 'STOCKAPP_ENCRYPTED_BACKUP\n';

  const BackupEncryptionService();

  AesGcm get _aesGcm => AesGcm.with256bits();
  Pbkdf2 get _pbkdf2 => Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: kdfIterations,
        bits: 256,
      );

  Future<EncryptedBackupFile> encryptZip({
    required File zipFile,
    File? outputFile,
    required String password,
    required String recoveryKey,
  }) {
    return encryptFile(
      inputFile: zipFile,
      outputFile: outputFile ?? File('${zipFile.path}$encryptedExtension'),
      password: password,
      recoveryKey: recoveryKey,
    );
  }

  Future<DecryptedBackupFile> decryptToZip({
    required File encryptedFile,
    File? outputFile,
    String? password,
    String? recoveryKey,
  }) {
    final fallbackName = p.basenameWithoutExtension(encryptedFile.path);
    return decryptFile(
      encryptedFile: encryptedFile,
      outputFile: outputFile ??
          File(
              p.join(encryptedFile.parent.path, '$fallbackName.decrypted.zip')),
      password: password,
      recoveryKey: recoveryKey,
    );
  }

  Future<EncryptedBackupFile> encryptFile({
    required File inputFile,
    required File outputFile,
    required String password,
    required String recoveryKey,
  }) async {
    _validateSecret(password, label: '비밀번호');
    _validateSecret(recoveryKey, label: '복구키');

    final inputBytes = await inputFile.readAsBytes();
    final dataKeyBytes = _randomBytes(32);
    final dataKey = SecretKey(dataKeyBytes);

    final payloadNonce = _randomBytes(12);
    final payloadBox = await _aesGcm.encrypt(
      inputBytes,
      secretKey: dataKey,
      nonce: payloadNonce,
    );

    final passwordWrap = await _wrapDataKey(
      dataKeyBytes: dataKeyBytes,
      secret: password,
    );
    final recoveryWrap = await _wrapDataKey(
      dataKeyBytes: dataKeyBytes,
      secret: recoveryKey,
    );

    final stat = await inputFile.stat();
    final header = <String, Object?>{
      'encryptionVersion': encryptionVersion,
      'algorithm': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'kdfIterations': kdfIterations,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'originalFileName': p.basename(inputFile.path),
      'originalSizeBytes': stat.size,
      'passwordWrappedKey': passwordWrap,
      'recoveryWrappedKey': recoveryWrap,
      'payload': {
        'nonce': base64Encode(payloadNonce),
        'mac': base64Encode(payloadBox.mac.bytes),
      },
    };

    await outputFile.parent.create(recursive: true);
    await _writeEncryptedFile(
      outputFile: outputFile,
      header: header,
      cipherText: payloadBox.cipherText,
    );

    return EncryptedBackupFile(file: outputFile, header: header);
  }

  Future<DecryptedBackupFile> decryptFile({
    required File encryptedFile,
    required File outputFile,
    String? password,
    String? recoveryKey,
  }) async {
    if ((password == null || password.isEmpty) &&
        (recoveryKey == null || recoveryKey.isEmpty)) {
      throw const BackupEncryptionException('비밀번호 또는 복구키가 필요합니다.');
    }

    final envelope = await _readEncryptedFile(encryptedFile);
    final header = envelope.header;
    _validateHeader(header);

    final dataKeyBytes = await _unwrapDataKey(
      header: header,
      password: password,
      recoveryKey: recoveryKey,
    );
    final payload = _mapValue(header['payload'], 'payload');
    final secretBox = SecretBox(
      envelope.cipherText,
      nonce: _base64Value(payload['nonce'], 'payload.nonce'),
      mac: Mac(_base64Value(payload['mac'], 'payload.mac')),
    );

    try {
      final plainBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(dataKeyBytes),
      );
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(plainBytes, flush: true);
      return DecryptedBackupFile(file: outputFile, header: header);
    } on SecretBoxAuthenticationError catch (e) {
      throw BackupEncryptionException(
        '백업 파일 인증에 실패했습니다. 파일이 손상되었거나 암호가 올바르지 않습니다.',
        cause: e,
      );
    }
  }

  Future<Map<String, Object?>> readHeader(File encryptedFile) async {
    final envelope = await _readEncryptedFile(encryptedFile);
    _validateHeader(envelope.header);
    return envelope.header;
  }

  Future<Map<String, Object?>> _wrapDataKey({
    required List<int> dataKeyBytes,
    required String secret,
  }) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final wrappingKey = await _deriveWrappingKey(secret: secret, salt: salt);
    final box = await _aesGcm.encrypt(
      dataKeyBytes,
      secretKey: wrappingKey,
      nonce: nonce,
    );
    return {
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<List<int>> _unwrapDataKey({
    required Map<String, Object?> header,
    String? password,
    String? recoveryKey,
  }) async {
    final attempts = <_UnwrapAttempt>[
      if (password != null && password.isNotEmpty)
        _UnwrapAttempt('passwordWrappedKey', password),
      if (recoveryKey != null && recoveryKey.isNotEmpty)
        _UnwrapAttempt('recoveryWrappedKey', recoveryKey),
    ];

    for (final attempt in attempts) {
      try {
        final wrapped = _mapValue(header[attempt.headerKey], attempt.headerKey);
        final salt = _base64Value(wrapped['salt'], '${attempt.headerKey}.salt');
        final nonce =
            _base64Value(wrapped['nonce'], '${attempt.headerKey}.nonce');
        final cipherText = _base64Value(
          wrapped['cipherText'],
          '${attempt.headerKey}.cipherText',
        );
        final mac = _base64Value(wrapped['mac'], '${attempt.headerKey}.mac');
        final wrappingKey = await _deriveWrappingKey(
          secret: attempt.secret,
          salt: salt,
        );
        return await _aesGcm.decrypt(
          SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
          secretKey: wrappingKey,
        );
      } on Object {
        continue;
      }
    }

    throw const BackupEncryptionException('비밀번호 또는 복구키가 올바르지 않습니다.');
  }

  Future<SecretKey> _deriveWrappingKey({
    required String secret,
    required List<int> salt,
  }) {
    return _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: salt,
    );
  }

  Future<void> _writeEncryptedFile({
    required File outputFile,
    required Map<String, Object?> header,
    required List<int> cipherText,
  }) async {
    final headerBytes = utf8.encode(jsonEncode(header));
    final headerLength = ByteData(4)..setUint32(0, headerBytes.length);
    final sink = outputFile.openWrite();
    try {
      sink.add(utf8.encode(_magic));
      sink.add(headerLength.buffer.asUint8List());
      sink.add(headerBytes);
      sink.add(cipherText);
    } finally {
      await sink.close();
    }
  }

  Future<_EncryptedEnvelope> _readEncryptedFile(File encryptedFile) async {
    final bytes = await encryptedFile.readAsBytes();
    final magicBytes = utf8.encode(_magic);
    if (bytes.length < magicBytes.length + 4) {
      throw const BackupEncryptionException('암호화 백업 파일 형식이 올바르지 않습니다.');
    }

    for (var i = 0; i < magicBytes.length; i += 1) {
      if (bytes[i] != magicBytes[i]) {
        throw const BackupEncryptionException('암호화 백업 파일이 아닙니다.');
      }
    }

    final headerLengthOffset = magicBytes.length;
    final headerLength = ByteData.sublistView(
      bytes,
      headerLengthOffset,
      headerLengthOffset + 4,
    ).getUint32(0);
    final headerStart = headerLengthOffset + 4;
    final headerEnd = headerStart + headerLength;
    if (headerEnd > bytes.length) {
      throw const BackupEncryptionException('암호화 백업 header가 손상되었습니다.');
    }

    final decoded =
        jsonDecode(utf8.decode(bytes.sublist(headerStart, headerEnd)));
    if (decoded is! Map) {
      throw const BackupEncryptionException('암호화 백업 header 형식이 올바르지 않습니다.');
    }

    return _EncryptedEnvelope(
      header: Map<String, Object?>.from(decoded),
      cipherText: bytes.sublist(headerEnd),
    );
  }

  void _validateHeader(Map<String, Object?> header) {
    final version = header['encryptionVersion'];
    if (version != encryptionVersion) {
      throw BackupEncryptionException(
        '지원하지 않는 백업 암호화 버전입니다: $version',
      );
    }
    if (header['algorithm'] != 'AES-256-GCM') {
      throw BackupEncryptionException(
        '지원하지 않는 암호화 알고리즘입니다: ${header['algorithm']}',
      );
    }
    if (header['kdf'] != 'PBKDF2-HMAC-SHA256') {
      throw BackupEncryptionException(
        '지원하지 않는 키 생성 방식입니다: ${header['kdf']}',
      );
    }
  }

  Map<String, Object?> _mapValue(Object? value, String label) {
    if (value is Map) return Map<String, Object?>.from(value);
    throw BackupEncryptionException('$label 값이 올바르지 않습니다.');
  }

  List<int> _base64Value(Object? value, String label) {
    if (value is String && value.isNotEmpty) {
      try {
        return base64Decode(value);
      } catch (_) {
        throw BackupEncryptionException('$label 값이 base64 형식이 아닙니다.');
      }
    }
    throw BackupEncryptionException('$label 값이 없습니다.');
  }

  void _validateSecret(String value, {required String label}) {
    if (value.trim().isEmpty) {
      throw BackupEncryptionException('$label 값이 비어 있습니다.');
    }
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

class _EncryptedEnvelope {
  final Map<String, Object?> header;
  final List<int> cipherText;

  const _EncryptedEnvelope({
    required this.header,
    required this.cipherText,
  });
}

class _UnwrapAttempt {
  final String headerKey;
  final String secret;

  const _UnwrapAttempt(this.headerKey, this.secret);
}
