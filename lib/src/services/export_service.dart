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
import '../models/item.dart';
import '../models/folder_node.dart';
import '../db/app_database.dart';

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



    final folderMap = {
      for (final f in folders) f.id: f
    };

    final foldersPayload = {
      'version': 1,
      'folders': folders.map((f) {
        final parent = folderMap[f.parentId];

        return {
          'id': f.id,
          'name': f.name,
          if (f.parentId != null) 'parentId': f.parentId,
          if (parent != null) 'parentName': parent.name, // ⭐ 여기
          if (f.depth != null) 'depth': f.depth,
          if (f.order != null) 'order': f.order,
        };
      }).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());

    final itemsPath = '${dir.path}/items_$stamp.json';
    final foldersPath = '${dir.path}/folders_$stamp.json';

    await File(itemsPath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(itemsPayload));

    await File(foldersPath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(foldersPayload));

    await Share.shareXFiles(
      [
        XFile(itemsPath),
        XFile(foldersPath),
      ],
      subject: 'StockApp Export $stamp',
    );
  }

  Future<void> exportDatabase() async {

    final db = AppDatabase(); // 현재 DB instance

    final dir = await getApplicationSupportDirectory();

    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());

    final exportPath = p.join(dir.path, 'stockapp_backup_$stamp.db');

    // 🔥 SQLite 공식 백업
    await db.customStatement("VACUUM INTO '$exportPath'");

    await Share.shareXFiles(
      [XFile(exportPath)],
      subject: 'StockApp DB Backup',
    );
  }

  Future<bool> importDatabase() async {

    debugPrint("🟡 importDatabase() 시작");

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );

    if (result == null) return false;

    final path = result.files.single.path;

    if (path == null) return false;

    final backupFile = File(path);

    await AppDatabase.closeInstance();

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'stockapp.db');

    final dbFile = File(dbPath);
    final wal = File('$dbPath-wal');
    final shm = File('$dbPath-shm');

    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();
    if (await dbFile.exists()) await dbFile.delete();

    await backupFile.copy(dbPath);

    debugPrint("🟢 DB 복원 완료");

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