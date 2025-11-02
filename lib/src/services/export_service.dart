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

  /// 앱 현재 상태를 folders_edited.json, items_edited.json으로 덤프하고
  /// OS 공유 시트(메일 등)로 보낸다.
  Future<void> exportAndShareEditedJson() async {
    // 1) 스냅샷
    final foldersPayload = _buildFoldersPayload();
    final itemsPayload   = _buildItemsPayload();

    // 2) 파일 저장 위치
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now()); // Asia/Seoul 기기시간 사용
    final foldersPath = '${dir.path}/folders_edited_$stamp.json';
    final itemsPath   = '${dir.path}/items_edited_$stamp.json';

    // 3) 파일로 기록 (UTF-8, pretty)
    await File(foldersPath).writeAsString(const JsonEncoder.withIndent('  ').convert(foldersPayload));
    await File(itemsPath).writeAsString(const JsonEncoder.withIndent('  ').convert(itemsPayload));

    // 4) 공유(메일앱 포함)
    await Share.shareXFiles(
      [
        XFile(foldersPath, mimeType: 'application/json'),
        XFile(itemsPath,   mimeType: 'application/json'),
      ],
      subject: '재고 내보내기 $stamp',
      text: '앱에서 편집된 폴더/아이템 데이터입니다.',
    );
  }

  /// folders.json 호환 형태:
  /// { "version": 1, "folders": [ { id,name,parentId,depth,order } ... ] }
  Map<String, dynamic> _buildFoldersPayload() {
    final List<FolderNode> all = repo.allFolders(); // <- InMemoryRepo에 목록 리더가 있다고 가정
    final list = all.map((f) => {
      'id': f.id,
      'name': f.name,
      'parentId': f.parentId,
      'depth': f.depth,
      'order': f.order,
    }).toList();

    return {
      'version': 1,
      'folders': list,
    };
  }

  /// items.json 호환 형태:
  /// { "version": 1, "items": [ { id, sku, name?, displayName?, folder, subfolder, subsubfolder, unit, minQty, qty, attrs?, ... } ] }
  ///
  /// ⚠️ 스키마는 너가 이미 임포트에 쓰는 필드들 그대로 유지.
  Map<String, dynamic> _buildItemsPayload() {
    final List<Item> all = repo.allItems(); // <- InMemoryRepo에서 전체 아이템 접근
    final list = all.map((it) {
      // 앱 내부의 최신 상태(편집 반영)를 그대로 싣는다.
      // folder, subfolder, subsubfolder는 Item이 직접 갖고 있는 값(또는 path 파생값)을 사용.
      return {
        'id': it.id,
        'sku': it.sku,
        'name': it.name,                 // 필요 없으면 빼도 됨
        'displayName': it.displayName,   // 필요 없으면 빼도 됨
        'folder': it.folder,             // 또는 it.path[0] 식으로 변환
        'subfolder': it.subfolder,
        'subsubfolder': it.subsubfolder,
        'unit': it.unit,
        'minQty': it.minQty,
        'qty': it.qty,                   // 현재 앱 재고 수량(편집 반영)
        // 아래는 있으면 포함, 없으면 생략
        if (it.attrs?.design != null || it.attrs?.form != null || it.attrs?.size != null)
          'attrs': {
            if (it.attrs?.design != null) 'design': it.attrs!.design,
            if (it.attrs?.form != null)   'form': it.attrs!.form,
            if (it.attrs?.size != null)   'size': it.attrs!.size,
          },
        // seed 전용으로만 쓰던 값이 앱 운영에도 의미 있으면 내보내기 유지
        if (it.seedQty != null) 'seed_qty': it.seedQty,
        if (it.unitIn != null) 'unit_in': it.unitIn,
        if (it.unitOut != null) 'unit_out': it.unitOut,
        if (it.conversionRate != null) 'conversion_rate': it.conversionRate,
      };
    }).toList();

    return {
      'version': 1,
      'items': list,
    };
  }
}
