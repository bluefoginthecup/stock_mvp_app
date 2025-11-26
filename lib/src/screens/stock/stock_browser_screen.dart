// lib/src/screens/stock/stock_browser_screen.dart
library stock_browser;

import 'dart:async';
import 'package:provider/provider.dart';
import '../../ui/common/ui.dart';
import '../../models/folder_node.dart';
import '../../models/item.dart';
import 'sheet_new_folder.dart';
import 'stock_new_item_sheet.dart';
import '../../ui/common/search_field.dart';
import '../../ui/common/path_picker.dart';
import '../../ui/common/entity_actions.dart';
import 'stock_item_detail_screen.dart';
import '../../services/export_service.dart';
import '../../ui/common/qty_set_sheet.dart';
import '../../repos/repo_interfaces.dart';
import 'widgets/item_selection_controller.dart';
import 'widgets/stock_item_select_tile.dart';
import 'widgets/stock_multi_select_bar.dart';
import '../../providers/cart_manager.dart';
import '../../db/app_database.dart';
import 'widgets/new_item_result.dart';
import 'package:stockapp_mvp/src/ui/common/draggable_fab.dart';

part 'stock_browser_header.part.dart';
part 'stock_browser_actions.part.dart';
part 'stock_browser_slivers.part.dart';
part 'stock_browser_helpers.part.dart';

// ============================================================================
//  Explorer-style Stock browser: L1 (roots) -> L2 -> L3 -> Items
// ============================================================================

class StockBrowserScreen extends StatefulWidget {
  final bool showLowStockOnly;
  const StockBrowserScreen({super.key, this.showLowStockOnly = false});

  @override
  State<StockBrowserScreen> createState() => _StockBrowserScreenState();
}

class _StockBrowserScreenState extends State<StockBrowserScreen> {
  Timer? _debounce;
  String? _l1Id;
  String? _l2Id;
  String? _l3Id;
  final _searchC = TextEditingController();
  bool _lowOnly = false;
  bool _showFavoriteOnly = false;

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

  // 🛒 CartManager 헬퍼
  void _addItemsToCart(dynamic cart, List<Item> items) {
    for (final it in items) {
      if (cart.addItemFromItem is Function) {
        cart.addItemFromItem(it);
      } else if (cart.addItem is Function) {
        cart.addItem(it.id, 1);
      } else if (cart.addLine is Function) {
        cart.addLine({
          'itemId': it.id,
          'name': it.displayName ?? it.name,
          'qty': 1,
          'unit': it.unit,
        });
      } else {
        debugPrint('[CartManager] No known add method.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FolderTreeRepo>();
    final folderRepo = context.read<FolderTreeRepo>();
    final itemRepo = context.read<ItemRepo>();

    return ChangeNotifierProvider(
      create: (_) => ItemSelectionController(),
      child: Builder(
        builder: (context) {
          final sel = context.watch<ItemSelectionController>();
          return Scaffold(
            appBar: buildAppBar(context, folderRepo, itemRepo),
            body: Stack(
              children: [
                buildBrowserContent(context, sel, folderRepo, itemRepo),
                DraggableFab(
                  storageKey: 'fab_offset_stock',
                  child: buildFloatingButton(context, _selectedDepth),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────── Browser 본문 ─────────────────────────
  Widget buildBrowserContent(
      BuildContext context,
      ItemSelectionController sel,
      FolderTreeRepo folderRepo,
      ItemRepo itemRepo,
      ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: buildBreadcrumb(context, this, setState),
        ),
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
                icon: Icon(sel.selectionMode ? Icons.close : Icons.checklist),
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
                label: const Text('즐겨찾기'),
                selected: _showFavoriteOnly,
                onSelected: (v) => setState(() => _showFavoriteOnly = v),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<Item>>(
            stream: itemRepo.watchItems(
              l1: _selectedDepth == 0 ? null : _l1Id,
              l2: _selectedDepth <= 1 ? null : _l2Id,
              l3: _selectedDepth <= 2 ? null : _l3Id,
              keyword: _searchC.text.trim().isNotEmpty ? _searchC.text : null,
              recursive: _searchC.text.trim().isNotEmpty ||
                  (_selectedDepth == 0 && (_lowOnly || _showFavoriteOnly)),
              lowOnly: _lowOnly,
              favoritesOnly: _showFavoriteOnly,
            ),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('오류: ${snap.error}'));
              }

              final items = _applyFilters(
                snap.data ?? const <Item>[],
                lowOnly: _lowOnly,
                showFavoriteOnly: _showFavoriteOnly,
              );

              return FutureBuilder<List<FolderNode>>(
                future: folderRepo.listFolderChildren(_selectedId),
                builder: (ctx, folderSnap) {
                  if (folderSnap.connectionState == ConnectionState.waiting &&
                      !folderSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (folderSnap.hasError) {
                    return Center(child: Text('오류: ${folderSnap.error}'));
                  }

                  final folders = folderSnap.data ?? const <FolderNode>[];
                  final hasKeyword = _searchC.text.trim().isNotEmpty;
                  final depth = _selectedDepth;

                  final slivers = <Widget>[];
                  if (depth == 0 && !hasKeyword && (_lowOnly || _showFavoriteOnly)) {
                    if (items.isEmpty) {
                      return const Center(child: Text('조건에 맞는 아이템이 없습니다.'));
                    }
                    slivers.add(_buildItemSliver(context, items));
                  } else if (hasKeyword) {
                    if (folders.isNotEmpty) {
                      slivers.add(_sliverHeader('📁 폴더'));
                      slivers.add(
                        _buildFolderSliver(
                          context,
                          folders,
                          setState,
                              (n) => _tryDeleteFolder(context, n, () => setState(() {})),
                        ),
                      );
                    }
                    if (items.isNotEmpty) {
                      slivers.add(_sliverHeader('📦 아이템'));
                      slivers.add(_buildItemSliver(context, items));
                    }
                  } else if (depth == 0) {
                    slivers.add(
                      _buildFolderSliver(
                        context,
                        folders,
                        setState,
                            (n) => _tryDeleteFolder(context, n, () => setState(() {})),
                      ),
                    );
                  } else {
                    if (folders.isNotEmpty) {
                      slivers.add(
                        _buildFolderSliver(
                          context,
                          folders,
                          setState,
                              (n) => _tryDeleteFolder(context, n, () => setState(() {})),
                        ),
                      );
                    }
                    if (items.isNotEmpty) {
                      slivers.add(_buildItemSliver(context, items));
                    }
                  }

                  // 리스트 + 멀티선택바
                  return Stack(
                    children: [
                      CustomScrollView(slivers: slivers),
                      if (sel.selectionMode)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: StockMultiSelectBar(
                            selectedCount: sel.selected.length,
                            totalCount: items.length,
                            onSelectAll: () =>
                                sel.selectAll(items.map((e) => e.id).toList()),
                            onClear: sel.exit,
                            onMove: sel.selected.isEmpty
                                ? () {}
                                : () async {
                              final dest = await showPathPicker(
                                context,
                                childrenProvider: pathChildrenFromFolderRepo(
                                    context.read<FolderTreeRepo>()),
                                title: '아이템 이동..',
                                maxDepth: 3,
                              );
                              if (dest == null || dest.isEmpty) return;
                              final moved = await context
                                  .read<FolderTreeRepo>()
                                  .moveItemsToPath(
                                itemIds: sel.selected.toList(),
                                pathIds: dest,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('아이템 $moved개 이동')),
                              );
                              sel.exit();
                            },
                            onAddToCart: () async {
                              if (sel.selected.isEmpty) return;
                              final picked = items
                                  .where((it) => sel.selected.contains(it.id))
                                  .toList();
                              final cart = context.read<CartManager>();
                              _addItemsToCart(cart, picked);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                  Text('${picked.length}개를 장바구니에 담았습니다.'),
                                  action: SnackBarAction(
                                    label: '보기',
                                    onPressed: () =>
                                        Navigator.of(context, rootNavigator: true).pushNamed('/cart'),
                                  ),
                                ),
                              );
                            },
                            onTrash: () async {
                              if (sel.selected.isEmpty) return;
                              final ok = await showDeleteConfirm(
                                context,
                                message:
                                '선택한 ${sel.selected.length}개를 휴지통으로 보낼까요?',
                              );
                              if (ok != true) return;
                              try {
                                final repo = context.read<ItemRepo>();
                                await repo.moveItemsToTrash(sel.selected.toList());
                                if (!context.mounted) return;
                                showGoSnack(
                                  context,
                                  message: '${sel.selected.length}개를 휴지통으로 이동했습니다.',
                                  actionText: '휴지통 열기',
                                  onAction: (_) =>
                                      Navigator.of(context).pushNamed('/trash'),
                                );
                                sel.exit();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('이동 실패: $e')),
                                );
                              }
                            },
                            allSelectedAreFavorite: (() {
                              final picked = items
                                  .where((it) => sel.selected.contains(it.id))
                                  .toList();
                              return picked.isNotEmpty &&
                                  picked.every((it) => it.isFavorite == true);
                            })(),
                            onToggleFavoriteAll: () async {
                              final picked = items
                                  .where((it) => sel.selected.contains(it.id))
                                  .toList();
                              if (picked.isEmpty) return;
                              final repo = context.read<ItemRepo>();
                              final ids = picked.map((e) => e.id).toList();
                              final allFav =
                              picked.every((it) => it.isFavorite == true);
                              final next = !allFav;
                              try {
                                final dyn = repo as dynamic;
                                if (dyn.setFavoritesBulk is Function) {
                                  await dyn.setFavoritesBulk(
                                      ids: ids, value: next);
                                } else {
                                  for (final id in ids) {
                                    await repo.setFavorite(
                                        itemId: id, value: next);
                                  }
                                }
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      next
                                          ? '선택한 ${ids.length}개 즐겨찾기 추가'
                                          : '선택한 ${ids.length}개 즐겨찾기 해제',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('처리 실패: $e')),
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ───────────────────────── FloatingActionButton 빌더 ─────────────────────────
  Widget buildFloatingButton(BuildContext context, int depth) {
    final folderRepo = context.read<FolderTreeRepo>();
    final itemRepo = context.read<ItemRepo>();
    final selectedId =
        context.findAncestorStateOfType<_StockBrowserScreenState>()?._selectedId;
    final isLeaf = depth >= 3;

    return FloatingActionButton(
      heroTag: 'fab-stock',
      onPressed: () async {
        final act = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('새 아이템'),
                  onTap: () => Navigator.pop(context, 'item'),
                ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder),
                  title: Text(isLeaf ? '새 폴더 (소분류에서는 불가)' : '새 폴더'),
                  enabled: !isLeaf,
                  onTap: isLeaf
                      ? null
                      : () => Navigator.pop(context, 'folder'),
                ),
              ],
            ),
          ),
        );

        if (act == 'folder') {
          await _createFolder(context, folderRepo, selectedId);
        }
        if (act == 'item') {
          await _createItem(context, selectedId, folderRepo, itemRepo);
        }
      },
      child: const Icon(Icons.add),
    );
  }
}
