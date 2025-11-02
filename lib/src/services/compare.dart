// lib/src/services/export_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../repos/inmem_repo.dart';
import '../models/item.dart';
import '../models/folder_node.dart';

class ExportService {
  final InMemoryRepo repo;
  ExportService({required this.repo});

  /// ✅ 폴더 + 아이템을 둘 다 JSON으로 내보내기
  Future<void> exportEditedJson() async {
    // 1️⃣ 데이터 수집
    final List<Item> items = repo.allItems();
    final List<FolderNode> folders = repo.allFolders();

    // 2️⃣ JSON 페이로드 구성
    final itemsPayload = {
      'version': 1,
      'items': items.map((it) => it.toJson()).toList(),
    };
    final foldersPayload = {
      'version': 1,
      'folders': folders.map((f) => {
        'id': f.id,
        'name': f.name,
        if (f.parentId != null) 'parentId': f.parentId,
        if (f.depth != null) 'depth': f.depth,
        if (f.order != null) 'order': f.order,
      }).toList(),
    };

    // 3️⃣ 파일로 저장
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final itemsPath = '${dir.path}/items_edited_$stamp.json';
    final foldersPath = '${dir.path}/folders_edited_$stamp.json';

    await File(itemsPath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(itemsPayload));
    await File(foldersPath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(foldersPayload));

    // 4️⃣ OS 공유 시트 열기 (메일, 에어드랍 등)
    await Share.shareXFiles(
      [
        XFile(itemsPath, mimeType: 'application/json'),
        XFile(foldersPath, mimeType: 'application/json'),
      ],
      subject: '재고 내보내기 $stamp',
      text: '앱에서 편집된 폴더/아이템 데이터입니다.',
    );
  }
}
