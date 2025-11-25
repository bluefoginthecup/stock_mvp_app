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
import '../../screens/cart/cart_screen.dart';
import '../../db/app_database.dart';
import '../../screens/trash/trash_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    context.watch<FolderTreeRepo>();
    final folderRepo = context.read<FolderTreeRepo>();
    final itemRepo = context.read<ItemRepo>();

    return ChangeNotifierProvider(
      create: (_) => ItemSelectionController(),
      child: Builder(builder: (context) {
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
                ),  );
      }),
    );
  }

  // ───────────────────────── Browser 본문 (분리된 함수) ─────────────────────────
  Widget buildBrowserContent(BuildContext context, ItemSelectionController sel,
      FolderTreeRepo folderRepo, ItemRepo itemRepo) {
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
                label: const Text("즐겨찾기"),
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
              keyword:
              _searchC.text.trim().isNotEmpty ? _searchC.text : null,
              recursive: _searchC.text.trim().isNotEmpty ||
                  (_selectedDepth == 0 && (_lowOnly || _showFavoriteOnly)),
              lowOnly: _lowOnly,
              favoritesOnly: _showFavoriteOnly,
            ),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !(snap.hasData)) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('오류: ${snap.error}'));
              }

              final items =
              _applyFilters(snap.data ?? const <Item>[],
                  lowOnly: _lowOnly,
                  showFavoriteOnly: _showFavoriteOnly);
              return FutureBuilder<List<FolderNode>>(
                future: folderRepo.listFolderChildren(_selectedId),
                builder: (ctx, folderSnap) {
                  if (folderSnap.connectionState == ConnectionState.waiting &&
                      !(folderSnap.hasData)) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (folderSnap.hasError) {
                    return Center(child: Text('오류: ${folderSnap.error}'));
                  }

                  final folders = folderSnap.data ?? const <FolderNode>[];
                  final hasKeyword = _searchC.text.trim().isNotEmpty;
                  final depth = _selectedDepth;

                  // 단순히 기존 분기 구조 유지
                  final slivers = <Widget>[];
                  if (depth == 0 && !hasKeyword && (_lowOnly || _showFavoriteOnly)) {
                    if (items.isEmpty) {
                      return const Center(child: Text('조건에 맞는 아이템이 없습니다.'));
                    }
                    slivers.add(_buildItemSliver(context, items));
                  } else if (hasKeyword) {
                    if (folders.isNotEmpty) {
                      slivers.add(_sliverHeader('📁 폴더'));
                      slivers.add(_buildFolderSliver(context, folders, setState,
                              (n) => _tryDeleteFolder(context, n, () => setState(() {}))));
                    }
                    if (items.isNotEmpty) {
                      slivers.add(_sliverHeader('📦 아이템'));
                      slivers.add(_buildItemSliver(context, items));
                    }
                  } else if (depth == 0) {
                    slivers.add(_buildFolderSliver(context, folders, setState,
                            (n) => _tryDeleteFolder(context, n, () => setState(() {}))));
                  } else {
                    if (folders.isNotEmpty) {
                      slivers.add(_buildFolderSliver(context, folders, setState,
                              (n) => _tryDeleteFolder(context, n, () => setState(() {}))));
                    }
                    if (items.isNotEmpty) {
                      slivers.add(_buildItemSliver(context, items));
                    }
                  }

                  return CustomScrollView(slivers: slivers);
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
                  title:
                  Text(isLeaf ? '새 폴더 (소분류에서는 불가)' : '새 폴더'),
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
