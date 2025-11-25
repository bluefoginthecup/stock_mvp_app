// lib/src/screens/stock/stock_browser_actions.part.dart

part of 'stock_browser_screen.dart';



// ───────────────────────── 삭제 에러 메시지 매핑 ─────────────────────────
String _friendlyDeleteError(Object e) {
  final s = e.toString();
  if (s.contains('subfolders')) return '하위 폴더가 있어서 삭제할 수 없습니다.';
  if (s.contains('referenced by items')) return '아이템이 포함되어 있어서 삭제할 수 없습니다.';
  return '삭제할 수 없습니다: $s';
}

// ───────────────────────── 폴더 삭제(에러=스낵바) ─────────────────────────
Future<void> _tryDeleteFolder(
    BuildContext context, FolderNode n, VoidCallback onRefresh) async {
  final repo = context.read<FolderTreeRepo>();
  try {
    await repo.deleteFolderNode(n.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('폴더가 삭제되었습니다.')));
    onRefresh();
  } on StateError catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_friendlyDeleteError(e))));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_friendlyDeleteError(e))));
  }
}

// ───────────────────────── 새 폴더 생성 ─────────────────────────
Future<void> _createFolder(
    BuildContext context, FolderTreeRepo repo, String? parentId) async {
  if (parentId == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('먼저 상위 폴더를 선택하세요.')));
    return;
  }
  final name = await showNewFolderSheet(context);
  if (name == null || name.trim().isEmpty) return;
  await repo.createFolderNode(parentId: parentId, name: name.trim());
}

// ───────────────────────── 새 아이템 생성 ─────────────────────────
Future<void> _createItem(
    BuildContext context, String? selectedId, FolderTreeRepo folderRepo, ItemRepo itemRepo) async {
  if (selectedId == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('먼저 상위 폴더를 선택하세요.')));
    return;
  }

  final chain = await _buildPathChain(folderRepo, selectedId);

      // 호환 모드: 레거시(Item) 또는 신규(_NewItemResult) 모두 수용
      final result = await showModalBottomSheet<dynamic>(

  context: context,
    isScrollControlled: true,
    builder: (_) => StockNewItemSheet(pathIds: chain),
  );
  if (result == null) return;

    // 레거시(Item) → 임시로 초기 chain 사용, 신규(_NewItemResult) → 시트가 준 pathIds 사용
    late final NewItemResult resolved;
    if (result is NewItemResult) {
      resolved = result;
    } else if (result is Item) {
      resolved = NewItemResult(result, chain);
    } else {
      debugPrint('[NEW][ERROR] unexpected result type: ${result.runtimeType}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알 수 없는 반환 타입입니다. 아이템 생성이 취소되었습니다.')),
        );
      }
      return;
    }

    // 항상 ID 기반 API로 저장 (문자열 경로 금지)
    final l1 = resolved.pathIds.isNotEmpty ? resolved.pathIds[0] : null;
    final l2 = resolved.pathIds.length > 1 ? resolved.pathIds[1] : null;
    final l3 = resolved.pathIds.length > 2 ? resolved.pathIds[2] : null;


  final dyn = itemRepo as dynamic;
    try {
      if (dyn.upsertItemWithPath is Function) {
        await dyn.upsertItemWithPath(resolved.item, l1, l2, l3);
      } else {
        // 경로 기반 API가 없다면 사용자에게 안내
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('경로 기반 저장 API가 없어 아이템을 생성할 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('아이템 생성 실패: $e')),
        );
      }
    }
}

// ───────────────────────── 경로 체인 빌드 ─────────────────────────
Future<List<String>> _buildPathChain(
    FolderTreeRepo repo, String selectedId) async {
  final chain = <String>[];
  String? curId = selectedId;
  while (curId != null) {
    final cur = await repo.folderById(curId);
    if (cur == null) break;
    chain.insert(0, cur.id);
    curId = cur.parentId;
  }
  return chain;
}

// ───────────────────────── 폴더 이름 위젯 ─────────────────────────
Widget folderName(BuildContext context, String id) {
  final repo = context.read<FolderTreeRepo>();
  return FutureBuilder<FolderNode?>(
    future: repo.folderById(id),
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const SizedBox(width: 48, height: 16, child: LinearProgressIndicator());
      }
      final node = snap.data;
      return Text(node?.name ?? '(삭제됨)');
    },
  );
}
