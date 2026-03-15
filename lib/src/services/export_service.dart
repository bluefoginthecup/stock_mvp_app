// lib/src/services/export_service.dart

import 'dart:convert';
import 'dart:io';

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

    final foldersPayload = {
      'version': 1,
      'folders': folders
          .map((f) => {
        'id': f.id,
        'name': f.name,
        if (f.parentId != null) 'parentId': f.parentId,
        if (f.depth != null) 'depth': f.depth,
        if (f.order != null) 'order': f.order,
      })
          .toList(),
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
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'stockapp.db');

    final file = File(dbPath);

    if (!await file.exists()) {
      throw Exception('DB 파일이 없습니다');
    }

    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final exportPath = p.join(dir.path, 'stockapp_backup_$stamp.db');

    final backup = await file.copy(exportPath);

    await Share.shareXFiles(
      [XFile(backup.path)],
      subject: 'StockApp DB Backup',
    );
  }
  Future<void> importDatabase() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );

    if (result == null) return;

    final path = result.files.single.path;
    if (path == null) return;

    final backupFile = File(path);

    final db = AppDatabase();
    await db.close();

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'stockapp.db');

    await backupFile.copy(dbPath);
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