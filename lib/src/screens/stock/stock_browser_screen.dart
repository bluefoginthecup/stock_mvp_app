// Explorer-style Stock browser: L1 (roots) -> L2 -> L3 -> Items
import 'dart:async'; // Timer 디바운스용
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/common/ui.dart';

import '../../models/folder_node.dart';
import '../../models/item.dart';
import '../../repos/inmem_repo.dart';
import 'sheet_new_folder.dart';
import 'stock_new_item_sheet.dart';
import '../../ui/common/search_field.dart'; // 공용 검색 위젯
import '../../ui/common/path_picker.dart'; // 파일 최상단 import 필요
import '../../ui/common/entity_actions.dart';
import 'stock_item_detail_screen.dart';
import '../../utils/item_presentation.dart';
import '../../services/export_service.dart';
import '../../ui/common/qty_set_sheet.dart';   // ✅ 공통 바텀시트
import '../../repos/repo_interfaces.dart';     // ✅ ItemRepo.adjustQty 사용



class StockBrowserScreen extends StatefulWidget {
    final bool showLowStockOnly; // ✅ 신규: 임계치 이하 필터 초기값
    const StockBrowserScreen({
      super.key,
      this.showLowStockOnly = false,
    });

  @override
  State<StockBrowserScreen> createState() => _StockBrowserScreenState();
}

class _StockBrowserScreenState extends State<StockBrowserScreen> {
  Timer? _debounce;
  String? _l1Id;
  String? _l2Id;
  String? _l3Id; // L3 선택 시 아이템 표시
  final _searchC = TextEditingController();
  bool _lowOnly = false; // ✅ 현재 "임계치 이하만" 보기 상태

  // ───────────────────────── Common helpers ─────────────────────────
  String? get _selectedId => _l3Id ?? _l2Id ?? _l1Id;

  int get _selectedDepth =>
      _l3Id != null ? 3 : _l2Id != null ? 2 : _l1Id != null ? 1 : 0;

  FolderNode? _selectedFolder(InMemoryRepo repo) =>
      (_selectedId == null) ? null : repo.folderById(_selectedId!);

  List<String> _buildPathChain(InMemoryRepo repo, String selectedId) {
    final chain = <String>[];
    var cur = repo.folderById(selectedId);
    while (cur != null) {
      chain.insert(0, cur.id); // [L1,(L2),(L3)]
      cur = (cur.parentId != null) ? repo.folderById(cur.parentId!) : null;
    }
    return chain;
  }

  bool _snackIfNoParentOrLeaf(BuildContext ctx, InMemoryRepo repo,
      {required bool allowLeaf}) {
    final sid = _selectedId;
    if (sid == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('먼저 상위 폴더를 선택하세요.')),
      );
      return true; // blocked
    }
    final parent = repo.folderById(sid);
    if (!allowLeaf && parent != null && parent.depth >= 3) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('소분류 아래에는 폴더를 만들 수 없습니다.')),
      );
      return true; // blocked
    }
    return false; // ok
  }

  void _debouncedRebuild() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }
  // ──────────────────────────────────────────────────────────────────

  @override
    void initState() {
        super.initState();
        _lowOnly = widget.showLowStockOnly;
      }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _createFolder() async {
    final repo = context.read<InMemoryRepo>();
    if (_snackIfNoParentOrLeaf(context, repo, allowLeaf: false)) return;

    final name = await showNewFolderSheet(context);
    if (name == null || name.trim().isEmpty) return;

    await repo.createFolderNode(parentId: _selectedId!, name: name.trim());
    if (!mounted) return;
    setState(() {});
  }

  // 유연형: 현재(선택) 폴더 아래 어디서든 아이템 생성
  Future<void> _createItem() async {
    final repo = context.read<InMemoryRepo>();
    if (_snackIfNoParentOrLeaf(context, repo, allowLeaf: true)) return;

    final chain = _buildPathChain(repo, _selectedId!);
    // 디버그 확인용
    // print('[createItem] path chain = $chain');

    final created = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StockNewItemSheet(pathIds: chain),
    );
    if (created == null) return;

    await repo.createItemUnderPath(pathIds: chain, item: created);
    if (!mounted) return;
    setState(() {});
  }

  Widget _breadcrumb() {
    final repo = context.read<InMemoryRepo>();
    String nameOf(String? id) =>
        id == null ? '' : (repo.folderById(id)?.name ?? '(삭제됨)');

    final segs = <Widget>[
      TextButton(
        onPressed: () => setState(() {
          _l1Id = null;
          _l2Id = null;
          _l3Id = null;
        }),
        child: const Text('대분류'),
      ),
    ];

    if (_l1Id != null) {
      segs.add(const Text(' > '));
      segs.add(
        TextButton(
          onPressed: () => setState(() {
            _l2Id = null;
            _l3Id = null;
          }),
          child: Text(nameOf(_l1Id)),
        ),
      );
    }
    if (_l2Id != null) {
      segs.add(const Text(' > '));
      segs.add(
        TextButton(
          onPressed: () => setState(() {
            _l3Id = null;
          }),
          child: Text(nameOf(_l2Id)),
        ),
      );
    }
    if (_l3Id != null) {
      segs.add(const Text(' > '));
      segs.add(Text(nameOf(_l3Id)));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: segs),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<InMemoryRepo>();
    final repo = context.read<InMemoryRepo>();

    final depth = _selectedDepth;
    final hasKeyword = _searchC.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('재고 브라우저'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'JSON 내보내기',
            onPressed: () async {
              final repo = context.read<InMemoryRepo>();
              final svc = ExportService(repo: repo);
              try {
                await svc.exportEditedJson();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('폴더/아이템 JSON 내보내기 완료')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('내보내기 실패: $e')),
                );
              }
            },
          ),
        ],

      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.all(12), child: _breadcrumb()),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: AppSearchField(
              controller: _searchC,
              hint: '폴더명 / 아이템명 / SKU 검색',
              onChanged: (_) => _debouncedRebuild(),
            ),
          ),
    // ✅ 상단에 필터칩 UI (AppBar 토글과 동일 기능)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('필터:임계치'),
                      selected: _lowOnly,
                      onSelected: (v) => setState(() => _lowOnly = v),
                      avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                    ),
                  ],
                ),
              ),
          const Divider(height: 1),

          // 검색어가 있을 땐 폴더+아이템 동시 검색
          Expanded(
            child: FutureBuilder<Object?>(
              future: hasKeyword
                  ? repo.searchAll(
                l1: _l1Id,
                l2: _l2Id,
                l3: _l3Id,
                keyword: _searchC.text,
                recursive: true,
              )
                  : (

                      // ✅ _lowOnly면: 루트=전역 아이템 필터 / L1~L3=재귀적으로 아이템 모으기
                      _lowOnly
                          ? (
                              depth == 0
                                  // 루트토글: 전역 아이템 중 임계치 이하만
                                  ? Future.value(
                                      _applyLowStockFilter(repo.allItems().toList()),
                                    )
                                  // L1/L2/L3토글: 하위 전부 재귀로 아이템 수집
                                  : Future.wait([
                                      repo.listFolderChildren(_selectedId),
                                      repo.listItemsByFolderPath(
                                        l1: _l1Id,
                                        l2: _l2Id,
                                        l3: _l3Id,
                                        keyword: null,
                                        recursive: true, // ✅ 재귀 ON
                                      ),
                                    ])
                            )
                          : (
                              depth == 0
                                  // 루트(기본): 폴더만
                                  ? repo.listFolderChildren(null)
                                  // L1/L2/L3(기본): 폴더 +  직속 아이템
                                  : Future.wait([
                                      repo.listFolderChildren(_selectedId),
                                      repo.listItemsByFolderPath(
                                        l1: _l1Id,
                                        l2: _l2Id,
                                        l3: _l3Id,
                                        keyword: null,
                                        recursive: false, // 직속만
                                      ),
                                    ])
                            )
              ),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('오류: ${snap.error}'));
                }

                // ✅ 루트(depth==0) + 토글: 전역 임계치 이하 아이템만 평평하게 표시
                                if (depth == 0 && _lowOnly) {
                                  final items = (snap.data as List<Item>);
                                  if (items.isEmpty) {
                                    return const Center(child: Text('임계치 이하 아이템이 없습니다.'));
                                  }
                                  return ListView(children: [_buildItemList(items)]);
                                }


                // 🔍 검색 결과 모드 (Dart 3 레코드 사용)
                if (hasKeyword) {
                  final (folders, items) =
                  snap.data as (List<FolderNode>, List<Item>);
    final filteredItems = _lowOnly
                         ? _applyLowStockFilter(items)
                          : items;
                      if (folders.isEmpty && filteredItems.isEmpty) {

    return const Center(child: Text('검색 결과가 없습니다.'));
                  }
                  return ListView(
                    children: [
                      if (folders.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('📁 폴더',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      if (folders.isNotEmpty) _buildFolderList(folders),
                        if (filteredItems.isNotEmpty)

                          const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('📦 아이템',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      if (filteredItems.isNotEmpty) _buildItemList(filteredItems),
                    ],
                  );
                }

                // 📁 depth==0 (루트) → 폴더만 표시
                if (depth == 0) {
                  final folders = snap.data as List<FolderNode>;
                  if (folders.isEmpty) {
                    return const Center(
                        child: Text('하위 폴더가 없습니다.  버튼으로 추가하세요.'));
                  }
                  return _buildFolderList(folders);
                }
// 📦 L1/L2/L3 → 폴더 + 직속 아이템
                final result = snap.data as List<Object>;
                final folders = result[0] as List<FolderNode>;
                final items = result[1] as List<Item>;

                final filteredItems = _lowOnly
                    ? _applyLowStockFilter(items)
                    : items;

                if (folders.isEmpty && filteredItems.isEmpty) {
                  return const Center(
                    child: Text('하위 폴더나 아이템이 없습니다.  버튼으로 추가하세요.'),
                  );
                }

                return ListView(
                  children: [
                    if (folders.isNotEmpty) _buildFolderList(folders),
                    if (filteredItems.isNotEmpty) _buildItemList(filteredItems),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      // floating button: 현재 폴더에 아이템/폴더 추가
      floatingActionButton: Builder(
        builder: (_) {
          final isLeaf = _selectedDepth >= 3;
          return FloatingActionButton(
            onPressed: () async {
              final act = await showModalBottomSheet<String>(
                context: context,
                builder: (_) => SafeArea(
                  child: Wrap(children: [
                    ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: const Text('새 아이템'),
                      onTap: () => Navigator.pop(context, 'item'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.create_new_folder),
                      title: Text(isLeaf ? '새 폴더 (소분류에서는 불가)' : '새 폴더'),
                      enabled: !isLeaf, // L3에서는 비활성화
                      onTap: isLeaf ? null : () => Navigator.pop(context, 'folder'),
                    ),
                  ]),
                ),
              );

              if (act == 'folder') {
                await _createFolder();
                return;
              }
              if (act == 'item') {
                await _createItem();
                return;
              }
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  // ───────────────────────── Helper UIs ─────────────────────────
   // ✅ 공통: 임계치 이하 필터
    List<Item> _applyLowStockFilter(List<Item> items) {
        return items.where((it) => it.minQty > 0 && it.qty <= it.minQty).toList();
      }

  Widget _buildFolderList(List<FolderNode> nodes) {
    final repo = context.read<InMemoryRepo>();
    return Column(
      children: nodes.map((n) {
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(n.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            setState(() {
              if (_l1Id == null) {
                _l1Id = n.id;
              } else if (_l2Id == null) {
                _l2Id = n.id;
              } else {
                _l3Id = n.id;
              }
            });
          },
          onLongPress: () async {
            // 공통 액션 시트(이름변경/이동/삭제)
            final action = await showEntityActionsSheet(
              context,
              moveLabel: '폴더 이동',
            );
            if (action == null) return;

            final repo = context.read<InMemoryRepo>();

            switch (action) {
              case EntityAction.rename:
                final newName = await showNewFolderSheet(context, initial: n.name);
                if (newName != null && newName.trim().isNotEmpty) {
                  await repo.renameFolderNode(id: n.id, newName: newName.trim());
                  if (!mounted) return;
                  setState(() {});
                }
                break;

              case EntityAction.move:
              // 트리 선택 → 통합 이동 API
                final dest = await showPathPicker(
                  context,
                  childrenProvider: folderChildrenProvider(repo),
                  title: '폴더 이동..',
                  maxDepth: 2, // ✅ 폴더는 L2까지만 선택 허용
                ); // dest = [L1] | [L1,L2] | [L1,L2,L3]
                if (dest != null && dest.isNotEmpty) {
                  try {
                    await repo.moveEntityToPath(
                      MoveRequest(kind: EntityKind.folder, id: n.id, pathIds: dest),
                    );
                    if (!mounted) return;
                    setState(() {});
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('이동 실패: $e')),
                    );
                  }
                }
                break;

              case EntityAction.delete:
                final ok = await showDeleteConfirm(
                  context,
                  message: '"${n.name}" 폴더를 삭제하시겠어요?',
                );
                if (ok) {
                  try {
                    await repo.deleteFolderNode(n.id);
                    if (!mounted) return;
                    setState(() {});
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('삭제 실패: $e')),
                    );
                  }
                }
                break;
            }
          },


        );
      }).toList(),
    );
  }

  Widget _buildItemList(List<Item> items) {
    final repo = context.read<InMemoryRepo>(); // ✅ 추가
    return Column(
      children: items.map((it) {
        final low = it.minQty > 0 && it.qty <= it.minQty;
        return ListTile(
          leading:
          Icon(low ? Icons.warning_amber_rounded : Icons.inventory_2),
          isThreeLine: true,
          title: ItemLabel(
            itemId: it.id,
            full: false, // 전체 경로 포함 (false면 [루앙 그레이] 커버 형식)
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: low ? Colors.red : null,
              fontWeight: FontWeight.w600,
            ),
          ),

          subtitle: FutureBuilder<List<String>>(
               future: repo.itemPathNames(it.id),
               builder: (_, snap) {
             final path = (snap.data ?? const []);
             final pathStr = path.isEmpty ? '' : ' • ${path.join(' / ')}';
             return Text('${it.sku} • ${it.unit}$pathStr');
           },
         ),
            // ✅ 우측: 수량 표시 + more(액션 시트) 버튼
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text('${it.qty}'),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: '아이템 작업',
                        onPressed: () async {
                          final action = await showEntityActionsSheet(context);
                          if (action == null) return;

                          switch (action) {
                            case EntityAction.rename:
                              final newName = await showRenameDialog(
                                context,
                                initial: it.name,
                                title: '아이템 이름 변경',
                              );
                              if (newName != null &&
                                  newName.isNotEmpty &&
                                  newName != it.name) {
                                await repo.renameItem(id: it.id, newName: newName);
                                if (!mounted) return;
                                setState(() {});
                              }
                              break;

                            case EntityAction.move:
                              final dest = await showPathPicker(
                                context,
                                childrenProvider: folderChildrenProvider(repo),
                                title: '아이템 이동',
                              );
                              if (dest != null && dest.isNotEmpty) {
                                await repo.moveEntityToPath(
                                  MoveRequest(kind: EntityKind.item, id: it.id, pathIds: dest),
                                );
                                if (!mounted) return;
                                setState(() {});
                              }
                              break;

                            case EntityAction.delete:
                              final ok = await showDeleteConfirm(
                                context,
                                message: '"${it.name}"을(를) 삭제하시겠어요?',
                              );
                              if (ok) {
                                await repo.deleteItem(it.id);
                                if (!mounted) return;
                                setState(() {});
                              }
                              break;
                          }
                        },
                      ),
                    ],
                  ),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StockItemDetailScreen(itemId: it.id),
              ),
            );
          },

                      // ✅ 롱프레스 = 공통 바텀시트 플로우
                      onLongPress: () => _openQtyChangeSheetFor(it),
        );
      }).toList(),
    );
  }


    // ───────────────────────── 수량 강제변경: 공통 플로우 호출 ─────────────────────────
    Future<void> _openQtyChangeSheetFor(Item item) async {
        final itemRepo = context.read<ItemRepo>();
        await runQtySetFlow(
          context,
          currentQty: item.qty,
          unit: item.unit,
          minQtyHint: item.minQty,
          apply: (delta, newQty) async {
            await itemRepo.adjustQty(
              itemId: item.id,
              delta: delta,
              refType: 'MANUAL',
              note: 'Browser:setQty ${item.qty} → $newQty',
            );
          },
          onSuccess: () => setState(() {}),       // 목록 갱신
          successMessage: context.t.btn_save,     // 로컬라이즈 키
          errorPrefix: context.t.common_error,
        );
      }

  // ───────────────────────── Folder Children Provider ─────────────────────────


  ChildrenProvider folderChildrenProvider(InMemoryRepo repo) {
    return (String? parentId) async {
      final folders = await repo.listFolderChildren(parentId);
      return folders.map((f) => PathNode(f.id, f.name)).toList();
    };
  }

}
