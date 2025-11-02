// lib/src/services/export_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../repos/inmem_repo.dart';
import '../models/item.dart';

class ExportService {
  final InMemoryRepo repo;
  ExportService({required this.repo});

  /// 현재 앱 상태의 아이템만 덤프 → items_edited.json 저장 → 공유
  Future<void> exportItemsEditedJson() async {
    // InMemoryRepo에 이게 없다면 values.toList()로 대체하거나 allItems() 추가해줘.
    final List<Item> items = repo.allItems();

    final payload = {
      'version': 1,
      'items': items.map((it) => it.toJson()).toList(), // <-- item.dart 수정 불필요
    };

    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final path = '${dir.path}/items_edited_$stamp.json';

    await File(path).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/json')],
      subject: 'items_edited $stamp',
      text: '앱에서 편집된 아이템 데이터입니다.',
    );
  }
}
