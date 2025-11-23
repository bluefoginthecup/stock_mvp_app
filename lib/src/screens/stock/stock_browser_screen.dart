// Explorer-style Stock browser: L1 (roots) -> L2 -> L3 -> Items
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/common/ui.dart';

import '../../models/folder_node.dart';
import '../../models/item.dart';
// import '../../repos/inmem_repo.dart'; // ❌ 더 이상 직접 의존 안 함
import 'sheet_new_folder.dart';
import 'stock_new_item_sheet.dart';
import '../../ui/common/search_field.dart';
import '../../ui/common/path_picker.dart';
import '../../ui/common/entity_actions.dart';
import 'stock_item_detail_screen.dart';
import '../../services/export_service.dart';
import '../../ui/common/qty_set_sheet.dart';
import '../../repos/repo_interfaces.dart'; // ✅ ItemRepo, FolderTreeRepo, MoveRequest, FolderSortMode, EntityKind

import 'widgets/item_selection_controller.dart';
import 'widgets/stock_item_select_tile.dart';
import 'widgets/stock_multi_select_bar.dart';
import '../../providers/cart_manager.dart';
import '../../screens/cart/cart_screen.dart';

import '../../db/app_database.dart';

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
  bool _showFavoriteOnly = false;

  // ───────────────────────── 삭제 에러 메시지 매핑 ─────────────────────────
  String _friendlyDeleteError(Object e) {
    final s = e.toString();
    if (s.contains('subfolders')) return '하위 폴더가 있어서 삭제할 수 없습니다.';
    if (s.contains('referenced by items')) return '아이템이 포함되어 있어서 삭제할 수 없습니다.';
    return '삭제할 수 없습니다: $s';
  }

  // ───────────────────────── 폴더 삭제(에러=스낵바) ─────────────────────────
  Future<void> _tryDeleteFolder(FolderNode n) async {
    final repo = context.read<FolderTreeRepo>();
    try {
      await repo.deleteFolderNode(n.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('폴더가 삭제되었습니다.')),
      );
      setState(() {}); // 목록 갱신
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyDeleteError(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyDeleteError(e))),
      );
    }
  }

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

  // ✅ 공통 필터: 임계치 + 즐겨찾기
    List<Item> _applyFilters(List<Item> items) {
        var filtered = items;
        if (_lowOnly) {
          filtered = filtered.where((it) => it.minQty > 0 && it.qty <= it.minQty).toList();
        }
        if (_showFavoriteOnly) {
          // isFavorite 없을 수도 있으니 == true 로 안전하게
          filtered = filtered.where((it) => it.isFavorite == true).toList();
        }
        return filtered;
      }

  Future<void> _createFolder() async {
    final repo = context.read<FolderTreeRepo>();
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
    final folderRepo = context.read<FolderTreeRepo>();
    final itemRepo = context.read<ItemRepo>();

    if (_selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 상위 폴더를 선택하세요.')),
      );
      return;
    }

    final chain = await _buildPathChain(folderRepo, _selectedId!);
    final created = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StockNewItemSheet(pathIds: chain),
    );
    if (created == null) return;


    // 표준: 새 Item은 이미 folder/subfolder/subsubfolder가 채워져 옴 → upsertItem만 호출
    await itemRepo.upsertItem(created);
    if (mounted) setState(() {});
  }

  Future<List<String>> _buildPathChain(FolderTreeRepo repo, String selectedId) async {
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

  Widget _folderName(String id) {
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


  Widget _breadcrumb() {
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
          child: _folderName(_l1Id!),
        ),
      ]);
    }
    if (_l2Id != null) {
      segs.addAll([
        const Text(' > '),
        TextButton(
          onPressed: () => setState(() => _l3Id = null),
          child: _folderName(_l2Id!),
        ),
      ]);
    }
    if (_l3Id != null) {
      segs.addAll([const Text(' > '), _folderName(_l3Id!)]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: segs),
    );
  }


  // ───────────────────────── Data loader ─────────────────────────

  Future<(List<FolderNode>, List<Item>)> _loadData(
      FolderTreeRepo folderRepo,
      ItemRepo itemRepo, {
        required bool hasKeyword,
        required bool lowOnly,
        required bool favOnly,
        required int depth,
        required String? l1,
        required String? l2,
        required String? l3,
        required String keyword,
      }) async {
    // 🔍 검색 모드: 폴더 + 아이템 동시 검색
    if (hasKeyword) {
      return await folderRepo.searchAll(
        l1: l1,
        l2: l2,
        l3: l3,
        keyword: keyword,
        recursive: true,
      );
    }

    // 🔻 임계치 또는 즐겨찾기 ON이면: 루트에서도 "아이템 모드"
        if (lowOnly || favOnly) {
          if (depth == 0) {
            final items = await itemRepo.listItems(); // 전체 아이템
            return (<FolderNode>[], items);
          } else {
            final folders = await folderRepo.listFolderChildren(_selectedId);
            final items = await (itemRepo as dynamic).listItemsByFolderPath(
              l1: l1,
              l2: l2,
              l3: l3,
              recursive: true,
            ) as List<Item>;
            return (folders, items);
          }
        }

    // 일반 모드
    if (depth == 0) {
      // L1 루트 목록
      final folders = await folderRepo.listFolderChildren(null);
      return (folders, <Item>[]);
    } else {
      final folders = await folderRepo.listFolderChildren(_selectedId);
      final items = await (itemRepo as dynamic).listItemsByFolderPath(
        l1: l1,
        l2: l2,
        l3: l3,
        recursive: false,
      ) as List<Item>;
      return (folders, items);
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

        final repo = context.read<FolderTreeRepo>();
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
              await _tryDeleteFolder(n);
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
                  // 필요하면 새로고침 로직 추가
                },
                successMessage: context.t.btn_save,
                errorPrefix: context.t.common_error,
              );
            },
            onTogglePick: () => sel.toggle(it.id),
            onToggleFavorite: () async {
                 final repo = context.read<ItemRepo>();
                 final next = !(it.isFavorite == true);

                 // 🔎 시작 로그
                 debugPrint('[Browser] ⭐ toggle start: id=${it.id}, was=${it.isFavorite}, next=$next');
                 try {
                   // 정석: 인터페이스 메서드 호출
                   await repo.setFavorite(itemId: it.id, value: next);
                   debugPrint('[Browser] ⭐ setFavorite OK (saved=$next)');

                   // 저장 직후 재조회로 실제 반영 확인
                   final fresh = await repo.getItem(it.id);
                   debugPrint('[Browser] ⭐ re-read → isFavorite=${fresh?.isFavorite}');
                 } catch (e, st) {
                   debugPrint('[Browser][ERR] setFavorite failed: $e\n$st');
                 }


                 // DB에서 직접 다시 읽어 확인
                 final db = context.read<AppDatabase>();
                 final rawRow = await (db.select(db.items)
                   ..where((t) => t.id.equals(it.id)))
                     .getSingle();

                 debugPrint('[Browser] ⭐ DB reread → isFavorite=${rawRow.isFavorite}');


                 if (!context.mounted) return;
                 setState(() {}); // 리스트 즉시 갱신
               },

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
    // FolderTreeRepo 변경 알림에 반응해서 전체 빌드
    context.watch<FolderTreeRepo>();
    final folderRepo = context.read<FolderTreeRepo>();
    final itemRepo = context.read<ItemRepo>();
    final depth = _selectedDepth;
    final hasKeyword = _searchC.text.trim().isNotEmpty;

    return ChangeNotifierProvider(
      create: (_) => ItemSelectionController(),
      child: Builder(builder: (context) {
        final sel = context.watch<ItemSelectionController>();

        return Scaffold(
          appBar: AppBar(
            title: const Text('재고 브라우저'),
            actions: [
              IconButton(
                icon: const Icon(Icons.bug_report),
                onPressed: () async {
                  final db = context.read<AppDatabase>(); // drift database
                  final row = await (db.select(db.items)
                    ..where((t) => t.id.equals('it_F_rouen_gray_cc_50')))
                      .getSingle();

                  debugPrint('DEBUG ITEM ROW → $row');
                },
              ),
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'JSON 내보내기',
                onPressed: () async {
                  final svc = ExportService(
                    itemRepo: itemRepo,
                    folderRepo: folderRepo,
                  );
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
                final repo = context.watch<FolderTreeRepo>();
                return PopupMenuButton<FolderSortMode>(
                  tooltip: '정렬',
                  icon: const Icon(Icons.sort),
                  initialValue: repo.sortMode,
                  onSelected: (m) => context.read<FolderTreeRepo>().setSortMode(m),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: FolderSortMode.name,
                      child: Text('이름순'),
                    ),
                    PopupMenuItem(
                      value: FolderSortMode.manual,
                      child: Text('사용자순'),
                    ),
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: sel.selectionMode ? '선택 취소' : '멀티 선택',
                      icon:
                      Icon(sel.selectionMode ? Icons.close : Icons.checklist),
                      onPressed: sel.selectionMode ? sel.exit : sel.enter,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 36),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    FilterChip(
                      label: const Text('필터:임계치'),
                      selected: _lowOnly,
                      onSelected: (v) => setState(() => _lowOnly = v),
                      avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                    ),
                    FilterChip(
                      label: Text("즐겨찾기"),
                      selected: _showFavoriteOnly,
                      onSelected: (v) => setState(() => _showFavoriteOnly = v),
                    )

                  ],
                ),
              ),
              const Divider(height: 1),
              // ───────────────────────── Content ─────────────────────────

        Expanded(
         child: FutureBuilder<(List<FolderNode>, List<Item>)>(
           future: _loadData(
                    folderRepo,
                    itemRepo,
                    hasKeyword: hasKeyword,
                    lowOnly: _lowOnly,
                    favOnly: _showFavoriteOnly,
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

                    final (folders, items) = snap.data!;
                    List<Item> currentItems = [];
                    final slivers = <Widget>[];

                    // 루트 & 검색 없음 & (임계치 or 즐겨찾기) ON → 전체 아이템에서 필터 적용
                                        if (depth == 0 && !hasKeyword && (_lowOnly || _showFavoriteOnly)) {
                                          final filtered = _applyFilters(items);
                                          if (filtered.isEmpty) {
                                            return const Center(child: Text('조건에 맞는 아이템이 없습니다.'));
                                          }
                                          currentItems = filtered;
                                          slivers.add(_buildItemSliver(filtered));
                                          slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 80)));
                                        } else if (hasKeyword) {
                                          final filtered = _applyFilters(items);

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
                      slivers.add(const SliverToBoxAdapter(
                          child: SizedBox(height: 80)));
                    } else if (depth == 0) {
                      if (folders.isEmpty) {
                        return const Center(
                            child: Text('하위 폴더가 없습니다.  버튼으로 추가하세요.'));
                      }
                      slivers.add(_buildFolderSliver(folders));
                      slivers.add(const SliverToBoxAdapter(
                          child: SizedBox(height: 80)));
                    } else {
                      final filtered = _applyFilters(items);

                      if (folders.isEmpty && filtered.isEmpty) {
                        return const Center(
                          child:
                          Text('하위 폴더나 아이템이 없습니다.  버튼으로 추가하세요.'),
                        );
                      }

                      if (folders.isNotEmpty) {
                        slivers.add(_buildFolderSliver(folders));
                      }
                      if (filtered.isNotEmpty) {
                        currentItems = filtered;
                        slivers.add(_buildItemSliver(filtered));
                      }
                      slivers.add(const SliverToBoxAdapter(
                          child: SizedBox(height: 80)));
                    }

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

                                final byId = {
                                  for (final it in currentItems) it.id: it
                                };
                                final cart = context.read<CartManager>();

                                for (final id in sel.selected) {
                                  final it = byId[id];
                                  if (it != null) {
                                    cart.addFromItem(it, qty: qty);
                                  }
                                }

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(12),
                                    content: Text(
                                      '장바구니에 ${sel.selected.length}개 담았어요 (×${qty.toStringAsFixed(0)})',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    action: SnackBarAction(
                                      label: '보기',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                              const CartScreen()),
                                        );
                                      },
                                    ),
                                  ),
                                );

                                sel.exit();
                              },
                              onMove: () async {
                                final sel =
                                context.read<ItemSelectionController>();
                                final repo = context.read<FolderTreeRepo>();

                                final dest = await showPathPicker(
                                  context,
                                  childrenProvider:
                                  folderChildrenProvider(repo),
                                  title: '아이템 이동..',
                                  maxDepth: 3,
                                );

                                if (dest == null ||
                                    dest.isEmpty ||
                                    !context.mounted) return;

                                final moved = await repo.moveItemsToPath(
                                  itemIds: sel.selected.toList(),
                                  pathIds: dest,
                                );

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('아이템 $moved개 이동')),
                                );
                                sel.clear();
                              },
                              onSelectAll: () => sel.selectAll(
                                  currentItems.map((e) => e.id)),
                              onClear: sel.exit,
                            ),
                          ),
                        ),
                      ...slivers,
                    ];

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
  ChildrenProvider folderChildrenProvider(FolderTreeRepo repo) {
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
