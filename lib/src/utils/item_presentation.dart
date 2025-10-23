import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item.dart';
import '../repos/repo_interfaces.dart';
import '../repos/inmem_repo.dart';


/// ─────────────────────────────────────────────────────────────
/// item_presentation.dart
///
/// 🧭 공통 아이템 표시·검색 유틸
/// - 아이템 이름에 경로(폴더명) 정보를 붙이거나 경로명으로 검색할 수 있게 하는 공통 로직.
/// - 주문, 입출고, 작업 등 여러 화면에서 동일한 라벨/검색 규칙을 사용하기 위해 만듦.
///
/// 포함 내용:
///   • _norm / _bestName : 문자열 정규화 + 표시용 이름 선택
///   • buildShortLabel / buildFullBreadcrumb : 경로 기반 이름 조립
///   • matchesItemOrPath : 이름·SKU·ID·폴더명·displayName 검색 매칭
///   • ItemPathProvider 인터페이스 : 경로명 제공 표준화
///   • RepoItemPathFacade : InMemoryRepo용 어댑터
///   • ItemPresentationService : 비동기 라벨 생성 서비스
///   • ItemLabel 위젯 : UI에서 비동기 라벨 표시
/// ─────────────────────────────────────────────────────────────

/// 소문자/트림 + null-safe 정규화
String _norm(String? text) {
  if (text == null) return '';
  return text.trim().toLowerCase();
}

/// displayName이 있으면 우선, 없으면 name 사용
String _bestName(Item item) {
  final dn = item.displayName?.trim();
  if (dn != null && dn.isNotEmpty) return dn;
  return item.name;
}

/// ['완제품','사계절','루앙 그레이'] 같은 경로명들에서 짧은 라벨 생성
/// 예) tag = 가장 깊은 경로명(있으면) → "[루앙 그레이] 티슈커버"
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
/// 예) "완제품 › 사계절 › 루앙 그레이 › 티슈커버"
String buildFullBreadcrumb({
  required String itemName,
  required List<String> pathNames,
  String sep = ' › ',
}) {
  final prefix = pathNames.join(sep);
  return prefix.isEmpty ? itemName : '$prefix$sep$itemName';
}

/// 이름/sku/경로/디스플레이명/ID까지 키워드 매칭
bool matchesItemOrPath({
  required Item item,
  required List<String> pathNames, // 예: ["완제품", "사계절", "루앙 그레이"]
  required String keyword,
}) {
  final k = _norm(keyword);
  if (k.isEmpty) return true;

  // 1) 단일 키워드 빠른 매칭 (OR)
  if (_norm(item.displayName).contains(k)) return true; // displayName 우선
  if (_norm(item.name).contains(k)) return true;
  if (_norm(item.sku).contains(k)) return true;
  if (_norm(item.id).contains(k)) return true; // 운영 편의를 위한 선택적 허용

  for (final name in pathNames) {
    if (_norm(name).contains(k)) return true; // 폴더명(루앙, 사계절 등)
  }

  // 2) (선택) 공백 분리 토큰 AND 매칭: "루앙 티슈" 같이 두 단어 모두 포함 시 통과
  final tokens = k.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.length >= 2) {
    final haystack = [
      _norm(item.displayName),
      _norm(item.name),
      _norm(item.sku),
      _norm(item.id),
      ...pathNames.map(_norm),
    ].join(' ');
    final ok = tokens.every((t) => haystack.contains(t));
    if (ok) return true;
  }

  return false;
}

/// 아이템 경로명을 제공하는 얇은 인터페이스
abstract class ItemPathProvider {
  /// 아이템의 경로명 리스트를 반환 (예: ["완제품","사계절","루앙 그레이"])
  Future<List<String>> itemPathNames(String itemId);
}

/// InMemoryRepo를 ItemPathProvider로 노출하기 위한 간단한 퍼사드
class RepoItemPathFacade implements ItemPathProvider {
  final InMemoryRepo _repo;
  RepoItemPathFacade(this._repo);

  @override
  Future<List<String>> itemPathNames(String itemId) {
    // InMemoryRepo에 구현되어 있는 경로명 조회 API 이름에 맞춰 호출하세요.
    // 예: return _repo.itemPathNames(itemId);
    // or: return _repo.pathNamesFor(itemId);
    return _repo.itemPathNames(itemId);
  }
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
    return buildShortLabel(itemName: _bestName(item), pathNames: names);
  }

  Future<String> fullLabel(String itemId, {String sep = ' › '}) async {
    final item = await items.getItem(itemId);
    if (item == null) return '(삭제됨)';
    final names = await paths.itemPathNames(itemId);
    return buildFullBreadcrumb(itemName: _bestName(item), pathNames: names, sep: sep);
  }
}

/// 어디서나 쓰는 라벨 위젯
class ItemLabel extends StatelessWidget {
  final String itemId;
  final bool full;                 // true면 breadcrumb, false면 [태그] 이름
  final int? maxLines;             // 표시 줄 수 (null=제한없음)
  final bool softWrap;             // 자동 줄바꿈
  final TextOverflow? overflow;    // 말줄임/잘림
  final TextStyle? style;          // 텍스트 스타일
  final String separator;          // 브레드크럼 구분자 (full=true일 때)
  final VoidCallback? onTap;

  const ItemLabel({
    super.key,
    required this.itemId,
    this.full = false,
    this.maxLines = 2,
    this.softWrap = true,
    this.overflow = TextOverflow.ellipsis,
    this.style,
    this.separator = ' › ',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final svc = ItemPresentationService(
      items: context.read<ItemRepo>(),
      paths: context.read<ItemPathProvider>(),
    );
    return FutureBuilder<String>(
      future: full ? svc.fullLabel(itemId, sep: separator) : svc.shortLabel(itemId),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final label = Text(
                     snap.data!,
                     style: style,
                     maxLines: maxLines,
                     softWrap: softWrap,
                     overflow: overflow,
                   );
               // onTap이 주어졌을 때만 클릭 가능하게
               return onTap == null
                   ? label
                   : InkWell(
                       onTap: onTap,
                       child: label,
                     );
      },
    );
  }
}
