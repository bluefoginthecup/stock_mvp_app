import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item.dart';
import '../repos/repo_interfaces.dart';

/// ─────────────────────────────────────────────────────────────
/// 공통 유틸(라벨 빌더 & 검색 매처) + 경로 Provider + 서비스 +(선택) 위젯
/// ─────────────────────────────────────────────────────────────
/// // ─────────────────────────────────────────────────────────────
// // item_presentation.dart
// //
// // 🧭 공통 아이템 표시·검색 유틸
// // - 아이템 이름에 경로(폴더명) 정보를 붙이거나 경로명으로 검색할 수 있게 하는 공통 로직.
// // - 주문, 입출고, 작업 등 여러 화면에서 동일한 라벨/검색 규칙을 사용하기 위해 만듦.
// //
// // 포함 내용:
// //   • buildShortLabel / buildFullBreadcrumb : 경로 기반 이름 조립
// //   • matchesItemOrPath : 이름·SKU·폴더명까지 검색 매칭
// //   • ItemPathProvider 인터페이스 : 경로명 제공 표준화
// //   • ItemPresentationService : 라벨 생성 서비스
// //   • ItemLabel 위젯 : UI에서 비동기 라벨 표시용
// // ─────────────────────────────────────────────────────────────

String _norm(String s) => s.trim().toLowerCase();

/// ['Finished','사계절','루앙'] 같은 경로명들에서 짧은 라벨 생성
String buildShortLabel({
  required String itemName,
  required List<String> pathNames,
}) {
  final tag = (pathNames.length >= 3)
      ? pathNames[2]
      : (pathNames.length >= 2)
      ? pathNames[1]
      : (pathNames.isNotEmpty ? pathNames[0] : '');
  return tag.isEmpty ? itemName : '[$tag] $itemName';
}

/// 전체 브레드크럼 라벨
String buildFullBreadcrumb({
  required String itemName,
  required List<String> pathNames,
  String sep = ' › ',
}) {
  final prefix = pathNames.join(sep);
  return prefix.isEmpty ? itemName : '$prefix$sep$itemName';
}

/// 이름/sku/경로명까지 키워드 매칭
bool matchesItemOrPath({
  required Item item,
  required List<String> pathNames,
  required String keyword,
}) {
  final k = _norm(keyword);
  if (k.isEmpty) return true;
  if (_norm(item.name).contains(k)) return true;
  if (_norm(item.sku).contains(k)) return true;
  for (final name in pathNames) {
    if (_norm(name).contains(k)) return true; // 폴더명(예: 루앙, 사계절 등)
  }
  return false;
}

/// 아이템 경로명을 제공하는 얇은 인터페이스
abstract class ItemPathProvider {
  Future<List<String>> itemPathNames(String itemId);
}

/// 라벨 프레젠테이션 서비스 (UI에서 비동기 라벨을 쉽게 얻도록)
class ItemPresentationService {
  final ItemRepo items;
  final ItemPathProvider paths;
  ItemPresentationService({required this.items, required this.paths});

  Future<String> shortLabel(String itemId) async {
    final item = await items.getItem(itemId);
    if (item == null) return '(삭제됨)';
    final names = await paths.itemPathNames(itemId);
    return buildShortLabel(itemName: item.name, pathNames: names);
  }

  Future<String> fullLabel(String itemId, {String sep = ' › '}) async {
    final item = await items.getItem(itemId);
    if (item == null) return '(삭제됨)';
    final names = await paths.itemPathNames(itemId);
    return buildFullBreadcrumb(itemName: item.name, pathNames: names, sep: sep);
  }
}

/// (선택) 어디서나 쓰는 라벨 위젯
class ItemLabel extends StatelessWidget {
  final String itemId;
  final bool full; // true면 breadcrumb, false면 [태그] 이름
  const ItemLabel({super.key, required this.itemId, this.full = false});

  @override
  Widget build(BuildContext context) {
    final svc = ItemPresentationService(
      items: context.read<ItemRepo>(),
      paths: context.read<ItemPathProvider>(),
    );
    return FutureBuilder<String>(
      future: full ? svc.fullLabel(itemId) : svc.shortLabel(itemId),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return Text(snap.data!);
      },
    );
  }
}
