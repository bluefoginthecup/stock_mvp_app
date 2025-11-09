// Explorer-style Stock browser: L1 (roots) -> L2 -> L3 -> Items
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/common/ui.dart';

import '../../models/folder_node.dart';
import '../../models/item.dart';
import '../../repos/inmem_repo.dart';
import 'sheet_new_folder.dart';
import 'stock_new_item_sheet.dart';
import '../../ui/common/search_field.dart';
import '../../ui/common/path_picker.dart';
import '../../ui/common/entity_actions.dart';
import 'stock_item_detail_screen.dart';
import '../../utils/item_presentation.dart';
import '../../services/export_service.dart';
import '../../ui/common/qty_set_sheet.dart';
import '../../repos/repo_interfaces.dart';

import 'widgets/item_selection_controller.dart';
import 'widgets/stock_item_select_tile.dart';
import 'widgets/stock_multi_select_bar.dart';
import '../../providers/cart_manager.dart';
import '../../screens/cart/cart_screen.dart';

class StockBrowserScreen extends StatefulWidget {
  final bool showLowStockOnly;
  const StockBrowserScreen({super.key, this.showLowStockOnly = false});

  @override
  State<StockBrowserScreen> createState() => _StockBrowserScreenState();
}

   ///  장바구니 담기 고정 바 시작 ///
const double _kSelectBarHeight = 36.0;

class _SelectBarHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  const _SelectBarHeader({required this.child, this.height = _kSelectBarHeight});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      elevation: 2,

      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(height: height, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _SelectBarHeader old) =>
      old.child != child || old.height != height;
}

  /// 고정바 끝 ///

class _StockBrowserScreenState extends State<StockBrowserScreen> {
  Timer? _debounce;
  String? _l1Id;
  String? _l2Id;
  String? _l3Id;
  final _searchC = TextEditingController();
  bool _lowOnly = false;

  String? get _selectedId => _l3Id ?? _l2Id ?? _l1Id;
  int get _selectedDepth =>
      _l3Id != null ? 3 : _l2Id != null ? 2 : _l1Id != null ? 1 : 0;

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

  void _debouncedRebuild() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  List<Item> _applyLowStockFilter(List<Item> items) {
    return items.where((it) => it.minQty > 0 && it.qty <= it.minQty).toList();
  }

  Future<void> _createFolder() async {
    final repo = context.read<InMemoryRepo>();
    final sid = _selectedId;
    if (sid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 상위 폴더를 선택하세요.')),
      );
      return;
    }
    final name = await showNewFolderSheet(context);
    if (name == null || name.trim().isEmpty) return;
    await repo.createFolderNode(parentId: sid, name: name.trim());
    if (mounted) setState(() {});
  }

  Future<void> _createItem() async {
    final repo = context.read<InMemoryRepo>();
    if (_selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 상위 폴더를 선택하세요.')),
      );
      return;
    }

    final chain = _buildPathChain(repo, _selectedId!);
    final created = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StockNewItemSheet(pathIds: chain),
    );
    if (created == null) return;

    await repo.createItemUnderPath(pathIds: chain, item: created);
    if (mounted) setState(() {});
  }

  List<String> _buildPathChain(InMemoryRepo repo, String selectedId) {
    final chain = <String>[];
    var cur = repo.folderById(selectedId);
    while (cur != null) {
      chain.insert(0, cur.id);
      cur = (cur.parentId != null) ? repo.folderById(cur.parentId!) : null;
    }
    return chain;
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
      segs.addAll([
        const Text(' > '),
        TextButton(
          onPressed: () => setState(() {
            _l2Id = null;
            _l3Id = null;
          }),
          child: Text(nameOf(_l1Id)),
        ),
      ]);
    }
    if (_l2Id != null) {
      segs.addAll([
        const Text(' > '),
        TextButton(
          onPressed: () => setState(() => _l3Id = null),
          child: Text(nameOf(_l2Id)),
        ),
      ]);
    }
    if (_l3Id != null) {
      segs.addAll([const Text(' > '), Text(nameOf(_l3Id))]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: segs),
    );
  }

  // ───────────────────────── Data loader (중첩 3항 제거) ─────────────────────────
  Future<Object?> _loadData(
      InMemoryRepo repo, {
        required bool hasKeyword,
        required bool lowOnly,
        required int depth,
        required String? l1,
        required String? l2,
        required String? l3,
        required String keyword,
      }) async {
    if (hasKeyword) {
      return repo.searchAll(
        l1: l1,
        l2: l2,
        l3: l3,
        keyword: keyword,
        recursive: true,
      );
    }

    if (lowOnly) {
      if (depth == 0) {
        return _applyLowStockFilter(repo.allItems().toList());
      } else {
        final folders = await repo.listFolderChildren(_selectedId);
        final items = await repo.listItemsByFolderPath(
          l1: l1,
          l2: l2,
          l3: l3,
          recursive: true,
        );
        return [folders, items];
      }
    }

    if (depth == 0) {
      return repo.listFolderChildren(null);
    } else {
      final folders = await repo.listFolderChildren(_selectedId);
      final items = await repo.listItemsByFolderPath(
        l1: l1,
        l2: l2,
        l3: l3,
        recursive: false,
      );
      return [folders, items];
    }
  }

  // ───────────────────────── Sliver builders ─────────────────────────
  SliverList _buildFolderSliver(List<FolderNode> nodes) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, i) => _buildFolderTile(nodes[i]),
        childCount: nodes.length,
      ),
    );
  }

  Widget _buildFolderTile(FolderNode n) {
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
        final action = await showEntityActionsSheet(
          context,
          moveLabel: '폴더 이동',
        );
        if (action == null) return;

        final repo = context.read<InMemoryRepo>();
        switch (action) {
          case EntityAction.rename:
            final newName =
            await showNewFolderSheet(context, initial: n.name);
            if (newName != null && newName.trim().isNotEmpty) {
              await repo.renameFolderNode(id: n.id, newName: newName.trim());
              if (!mounted) return;
              setState(() {});
            }
            break;

          case EntityAction.move:
            final dest = await showPathPicker(
              context,
              childrenProvider: folderChildrenProvider(repo),
              title: '폴더 이동..',
              maxDepth: 2,
            );
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
            if (ok == true) {
              try {
                await repo.deleteFolderNode(n.id);
                if (!mounted) return;
                setState(() {});
              } catch (e, st) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('삭제 실패: $e')),
                );
                // ignore: avoid_print
                print('삭제실패: $e\n$st');
              }
            }
            break;
        }
      },
    );
  }
  SliverList _buildItemSliver(List<Item> items) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, i) {
          // ✅ 여기서 읽으면 Provider 스코프 안의 컨텍스트라 안전
          final sel = context.watch<ItemSelectionController>();
          final it = items[i];
          final picked = sel.selected.contains(it.id);

          return StockItemSelectTile(
            item: it,
            selectionMode: sel.selectionMode,
            selected: picked,
            onTap: () async {
              if (sel.selectionMode) {
                sel.toggle(it.id);
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockItemDetailScreen(itemId: it.id),
                  ),
                );
              }
            },
            onLongPress: () async {
              final itemRepo = context.read<ItemRepo>();

              await runQtySetFlow(
                context,
                currentQty: it.qty,
                unit: it.unit,
                minQtyHint: it.minQty,
                apply: (delta, newQty) async {
                  await itemRepo.adjustQty(
                    itemId: it.id,
                    delta: delta,
                    refType: 'MANUAL',
                    note: 'Browser:setQty ${it.qty} → $newQty',
                  );
                },
                onSuccess: () async {
                  // 브라우저 화면 리프레시 필요 시 여기에
                },
                successMessage: context.t.btn_save,
                errorPrefix: context.t.common_error,
              );
            },


            onTogglePick: () => sel.toggle(it.id),
          );
        },
        childCount: items.length,
      ),
    );
  }


  SliverToBoxAdapter _sliverHeader(String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<InMemoryRepo>();
    final repo = context.read<InMemoryRepo>();
    final depth = _selectedDepth;
    final hasKeyword = _searchC.text.trim().isNotEmpty;
    final sel = context.watch<ItemSelectionController>();


    return ChangeNotifierProvider(
      create: (_) => ItemSelectionController(),
      child: Builder(builder: (context) {
        final sel = context.watch<ItemSelectionController>();

        return Scaffold(
          appBar: AppBar(
            title: const Text('재고 브라우저'),
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'JSON 내보내기',
                onPressed: () async {
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

              IconButton(
                icon: const Icon(Icons.shopping_cart),
                tooltip: '장바구니 보기',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              ),
              Builder(builder: (_) {
                final repo = context.watch<InMemoryRepo>();
                return PopupMenuButton<FolderSortMode>(
                  tooltip: '정렬',
                  icon: const Icon(Icons.sort),
                  initialValue: repo.sortMode,
                  onSelected: (m) => context.read<InMemoryRepo>().setSortMode(m),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: FolderSortMode.name,   child: Text('이름순')),
                    PopupMenuItem(value: FolderSortMode.manual, child: Text('사용자순')),
                  ],
                );
              }),
            ],
          ),
          body: Column(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  spacing: 2,
                  mainAxisAlignment: MainAxisAlignment.start, // 💡 왼쪽 정렬

                  children: [
                    // ✅ 멀티선택 토글 (필터 왼쪽)
                    IconButton(
                      tooltip: sel.selectionMode ? '선택 취소' : '멀티 선택',
                      icon: Icon(sel.selectionMode ? Icons.close : Icons.checklist),
                      onPressed: sel.selectionMode ? sel.exit : sel.enter,
                      style: IconButton.styleFrom(
                        // 연보라 톤(테마 연계) — FAB와 톤 맞추기
                        minimumSize: const Size(40, 36), // 칩 높이와 비슷하게
                        padding: const EdgeInsets.all(8),
                      ),
                    ),


                    FilterChip(
                      label: const Text('필터:임계치'),
                      selected: _lowOnly,
                      onSelected: (v) => setState(() => _lowOnly = v),
                      avatar:
                      const Icon(Icons.warning_amber_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ───────────────────────── Content (Slivers + overlay) ─────────────────────────
              Expanded(
                child: FutureBuilder<Object?>(
                  future: _loadData(
                    repo,
                    hasKeyword: hasKeyword,
                    lowOnly: _lowOnly,
                    depth: depth,
                    l1: _l1Id,
                    l2: _l2Id,
                    l3: _l3Id,
                    keyword: _searchC.text,
                  ),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('오류: ${snap.error}'));
                    }

                    // 현재 화면에 실제로 표시되는 아이템 집합 (선택바 용)
                    List<Item> currentItems = [];
                    final slivers = <Widget>[];

                    if (depth == 0 && _lowOnly && !hasKeyword) {
                      final items = (snap.data as List<Item>);
                      if (items.isEmpty) {
                        return const Center(
                            child: Text('임계치 이하 아이템이 없습니다.'));
                      }
                      currentItems = items;
                      slivers.add(_buildItemSliver(items));
                      slivers.add(const SliverToBoxAdapter(
                          child: SizedBox(height: 80)));
                    } else if (hasKeyword) {
                      final (folders, items) =
                      snap.data as (List<FolderNode>, List<Item>);
                      final filtered = _lowOnly ? _applyLowStockFilter(items) : items;

                      if (folders.isEmpty && filtered.isEmpty) {
                        return const Center(child: Text('검색 결과가 없습니다.'));
                      }

                      if (folders.isNotEmpty) {
                        slivers.addAll([
                          _sliverHeader('📁 폴더'),
                          _buildFolderSliver(folders),
                        ]);
                      }
                      if (filtered.isNotEmpty) {
                        currentItems = filtered;
                        slivers.addAll([
                          _sliverHeader('📦 아이템'),
                          _buildItemSliver(filtered),
                        ]);
                      }
                      slivers.add(
                          const SliverToBoxAdapter(child: SizedBox(height: 80)));
                    } else if (depth == 0) {
                      final folders = snap.data as List<FolderNode>;
                      if (folders.isEmpty) {
                        return const Center(
                            child: Text('하위 폴더가 없습니다.  버튼으로 추가하세요.'));
                      }
                      slivers.add(_buildFolderSliver(folders));
                      slivers.add(const SliverToBoxAdapter(
                          child: SizedBox(height: 80)));
                    } else {
                      final result = snap.data as List<Object>;
                      final folders = result[0] as List<FolderNode>;
                      final items = result[1] as List<Item>;
                      final filtered = _lowOnly ? _applyLowStockFilter(items) : items;

                      if (folders.isEmpty && filtered.isEmpty) {
                        return const Center(
                          child: Text('하위 폴더나 아이템이 없습니다.  버튼으로 추가하세요.'),
                        );
                      }

                      if (folders.isNotEmpty) {
                        slivers.add(_buildFolderSliver(folders));
                      }
                      if (filtered.isNotEmpty) {
                        currentItems = filtered;
                        slivers.add(_buildItemSliver(filtered));
                      }
                      slivers.add(
                          const SliverToBoxAdapter(child: SizedBox(height: 80)));
                    }

                    // 선택 모드일 때 상단 고정 헤더를 끼운 슬리버 배열로 교체
                    final sliversWithSelectBar = <Widget>[
                      if (sel.selectionMode)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SelectBarHeader(
                            height: _kSelectBarHeight,
                            child: StockMultiSelectBar(
                              selectedCount: sel.selected.length,
                              totalCount: currentItems.length,
                              onAddToCart: () async {
                                final qty = await _askQty(context);
                                if (qty == null) return;

                                final byId = { for (final it in currentItems) it.id: it };
                                final cart = context.read<CartManager>();

                                for (final id in sel.selected) {
                                  final it = byId[id];
                                  if (it != null) {
                                    cart.addFromItem(it, qty: qty);
                                  }
                                }

                                if (!mounted) return;ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating, // 💡 floating으로 바꿔 높이 줄이기
                                    margin: const EdgeInsets.all(12), // 선택: 살짝 띄워서 가볍게
                                    content: Text(
                                      '장바구니에 ${sel.selected.length}개 담았어요 (×${qty.toStringAsFixed(0)})',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    action: SnackBarAction(
                                      label: '보기', // 💡 한 글자만 남겨 더 슬림하게
                                      textColor: Theme.of(context).colorScheme.onPrimary,
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const CartScreen()),
                                        );
                                      },
                                    ),
                                  ),
                                );

                                sel.exit();
                              },onMove: () async {
                              final sel = context.read<ItemSelectionController>(); // 선택된 아이템
                              final repo = context.read<InMemoryRepo>();

                              // 기존에 쓰던 경로 선택기 사용
                              final dest = await showPathPicker(
                                context,
                                childrenProvider: folderChildrenProvider(repo),
                                title: '아이템 이동..',
                                maxDepth: 3, // 필요시 2로 낮춰도 됨
                              );

                              if (dest == null || dest.isEmpty || !context.mounted) return;

                              // 배치 이동 (repo에 moveItemsToPath가 있어야 함)
                              final moved = await repo.moveItemsToPath(
                                itemIds: sel.selected.toList(),
                                pathIds: dest, // [L1], [L1,L2], [L1,L2,L3]
                              );

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('아이템 $moved개 이동')),
                              );
                              sel.clear();
                            },

                              onSelectAll: () => sel.selectAll(currentItems.map((e) => e.id)),
                              onClear: sel.exit,
                            ),
                          ),
                        ),
                      ...slivers, // ← 기존에 너가 구성하던 SliverList/SliverGrid/폴더/아이템 목록들
                    ];

// Stack 제거, 바로 스크롤 뷰 반환
                    return CustomScrollView(slivers: sliversWithSelectBar);

                  },
                ),
              ),
            ],
          ),
          floatingActionButton: Builder(builder: (_) {
            final isLeaf = _selectedDepth >= 3;
            return FloatingActionButton(
              heroTag: 'fab-stock',
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
                        title:
                        Text(isLeaf ? '새 폴더 (소분류에서는 불가)' : '새 폴더'),
                        enabled: !isLeaf,
                        onTap: isLeaf
                            ? null
                            : () => Navigator.pop(context, 'folder'),
                      ),
                    ]),
                  ),
                );
                if (act == 'folder') await _createFolder();
                if (act == 'item') await _createItem();
              },
              child: const Icon(Icons.add),
            );
          }),
        );
      }),
    );
  }

  // PathPicker용 provider
  ChildrenProvider folderChildrenProvider(InMemoryRepo repo) {
    return (String? parentId) async {
      final folders = await repo.listFolderChildren(parentId);
      return folders.map((f) => PathNode(f.id, f.name)).toList();
    };
  }

  Future<double?> _askQty(BuildContext context) async {
    final c = TextEditingController(text: '1');
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('발주 수량(공통)'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '수량'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(c.text.trim());
              Navigator.pop(ctx, (v == null || v <= 0) ? 1.0 : v);
            },
            child: const Text('담기'),
          ),
        ],
      ),
    );
  }
}
