// lib/src/services/export_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../repos/repo_interfaces.dart';
import '../models/folder_node.dart';
import '../db/app_database.dart';
import 'app_path_service.dart';
import 'backup_file_delivery_service.dart';

class ExportService {
  final ItemRepo itemRepo;
  final FolderTreeRepo folderRepo;

  ExportService({
    required this.itemRepo,
    required this.folderRepo,
  });

  /// JSON export
  Future<void> exportEditedJson() async {
    final items = await itemRepo.listItems();
    final folders = await _collectAllFolders();

    final itemsPayload = {
      'version': 1,
      'items': items.map((it) => it.toJson()).toList(),
    };

    final folderMap = {for (final f in folders) f.id: f};

    final foldersPayload = {
      'version': 1,
      'folders': folders.map((f) {
        final parent = folderMap[f.parentId];

        return {
          'id': f.id,
          'name': f.name,
          if (f.parentId != null) 'parentId': f.parentId,
          if (parent != null) 'parentName': parent.name, // ⭐ 여기
          'depth': f.depth,
          'order': f.order,
        };
      }).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());

    final itemsPath = '${dir.path}/items_$stamp.json';
    final foldersPath = '${dir.path}/folders_$stamp.json';

    await File(itemsPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(itemsPayload));

    await File(foldersPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(foldersPayload));

    await Share.shareXFiles(
      [
        XFile(itemsPath),
        XFile(foldersPath),
      ],
      subject: 'StockApp Export $stamp',
    );
  }

  Future<String> exportDatabase() async {
    final db = AppDatabase(); // 현재 DB instance

    final dir = await const AppPathService().userSupportDirectory();

    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());

    final exportPath = p.join(dir.path, 'stockapp_backup_$stamp.db');

    // 🔥 SQLite 공식 백업
    await db.customStatement("VACUUM INTO '$exportPath'");

    final deliveryResult =
        await const BackupFileDeliveryService().deliverBackupFile(
      file: File(exportPath),
      fileName: p.basename(exportPath),
      subject: 'StockApp DB Backup',
      allowedExtensions: const ['db'],
    );
    return deliveryResult?.message('DB 백업') ?? 'DB 백업 저장이 취소되었습니다';
  }

  Future<bool> importDatabase() async {
    debugPrint("🟡 importDatabase() 시작");

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null) return false;

    final path = result.files.single.path;

    if (path == null) return false;

    final backupFile = File(path);

    await AppDatabase.closeInstance();

    final dbFile = await const AppPathService().stockDatabaseFile();
    final wal = File('${dbFile.path}-wal');
    final shm = File('${dbFile.path}-shm');

    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();
    if (await dbFile.exists()) await dbFile.delete();

    await dbFile.parent.create(recursive: true);
    await backupFile.copy(dbFile.path);

    debugPrint("🟢 DB 복원 완료");

    // 🔥 DB 재생성 (싱글톤 다시 초기화)
    AppDatabase(); // 새로 생성해야 함
    debugPrint("🟢 DB 재오픈 완료");

    return true;
  }

  Future<List<FolderNode>> _collectAllFolders() async {
    final result = <FolderNode>[];

    Future<void> dfs(String? parentId) async {
      final children = await folderRepo.listFolderChildren(parentId);
      result.addAll(children);

      for (final c in children) {
        await dfs(c.id);
      }
    }

    await dfs(null);
    return result;
  }
}
