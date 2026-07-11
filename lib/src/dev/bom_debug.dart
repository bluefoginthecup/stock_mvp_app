// lib/src/dev/bom_debug.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repos/repo_interfaces.dart';
import '../models/bom.dart';
import '../models/item.dart';

class BomDebug {
  /// 전체 아이템을 훑어서 finished/semi 레시피를 콘솔로 출력
  static Future<void> dumpAllBomsToConsole(BuildContext context) async {
    final itemRepo = context.read<ItemRepo>();

    // 아이템 전부 조회 (필요시 폴더/키워드로 좁혀도 됨)
    final List<Item> items = await itemRepo.listItems();

    // 결과를 한 번에 모아서 pretty-print (debugPrint 길이 제한 회피)
    final out = <Map<String, dynamic>>[];

    for (final it in items) {
      // 1) Finished 레시피
      try {
        final List<BomRow> fRows = itemRepo.finishedBomOf(it.id);
        if (fRows.isNotEmpty) {
          out.add({
            'root': 'finished',
            'parentItemId': it.id,
            'parentName': it.name,
            'rows': fRows.map(_rowToMap).toList(),
          });
        }
      } catch (_) {
        // repo 구현에 따라 없을 수 있음 - 무시
      }

      // 2) Semi 레시피
      try {
        final List<BomRow> sRows = itemRepo.semiBomOf(it.id);
        if (sRows.isNotEmpty) {
          out.add({
            'root': 'semi',
            'parentItemId': it.id,
            'parentName': it.name,
            'rows': sRows.map(_rowToMap).toList(),
          });
        }
      } catch (_) {
        // repo 구현에 따라 없을 수 있음 - 무시
      }
    }

    if (out.isEmpty) {
      debugPrint('[BOM-DUMP] No BOMs found.');
      return;
    }

    final jsonStr = const JsonEncoder.withIndent('  ').convert(out);
    // wrapWidth로 긴 줄도 보기 좋게
    debugPrint('===== BOM DUMP START =====', wrapWidth: 120);
    _chunkedDebugPrint(jsonStr);
    debugPrint('=====  BOM DUMP END  =====', wrapWidth: 120);
  }

  /// 단일 아이템의 레시피만 출력하고 싶을 때
  static Future<void> dumpItemBomsToConsole(BuildContext context, String itemId) async {
    final itemRepo = context.read<ItemRepo>();
    final item = await itemRepo.getItem(itemId);

    final result = <Map<String, dynamic>>[];

    try {
      final fRows = itemRepo.finishedBomOf(itemId);
      if (fRows.isNotEmpty) {
        result.add({
          'root': 'finished',
          'parentItemId': itemId,
          'parentName': item?.name,
          'rows': fRows.map(_rowToMap).toList(),
        });
      }
    } catch (_) {}
    try {
      final sRows = itemRepo.semiBomOf(itemId);
      if (sRows.isNotEmpty) {
        result.add({
          'root': 'semi',
          'parentItemId': itemId,
          'parentName': item?.name,
          'rows': sRows.map(_rowToMap).toList(),
        });
      }
    } catch (_) {}

    if (result.isEmpty) {
      debugPrint('[BOM-DUMP] No BOMs for $itemId');
      return;
    }
    final jsonStr = const JsonEncoder.withIndent('  ').convert(result);
    debugPrint('===== BOM DUMP for $itemId START =====', wrapWidth: 120);
    _chunkedDebugPrint(jsonStr);
    debugPrint('=====  BOM DUMP for $itemId END   =====', wrapWidth: 120);
  }

  // ───────────────────────── helpers ─────────────────────────

  static Map<String, dynamic> _rowToMap(BomRow r) {
    // Enum.name 사용 (Dart 2.17+). 더 안전하게 가려면 extension의 toString 로직 써도 됨.
    final root = r.root.name; // 'finished' | 'semi'
    final kind = r.kind.name; // 'semi' | 'raw' | 'sub'

    return {
      'root': root,
      'parentItemId': r.parentItemId,
      'componentItemId': r.componentItemId,
      'kind': kind,
      'qtyPer': r.qtyPer,
      'wastePct': r.wastePct,
      // 필요 시 파생치도 함께 찍어보자 (부모 1개 기준 필요수량)
      'needFor(1)': r.needFor(1),
    };
  }

  /// debugPrint가 아주 긴 문자열을 중간에 잘라버리는 걸 방지하기 위해 chunking
  static void _chunkedDebugPrint(String big, {int chunk = 800}) {
    for (var i = 0; i < big.length; i += chunk) {
      final end = (i + chunk < big.length) ? i + chunk : big.length;
      debugPrint(big.substring(i, end), wrapWidth: 160);
    }
  }
}
