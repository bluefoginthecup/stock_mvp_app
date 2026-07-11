// lib/src/screens/stock/stock_browser_screen.dart
library stock_browser;

import 'dart:async';
import 'package:provider/provider.dart';
import '../../repos/drift_unified_repo.dart';
import '../../ui/common/ui.dart';
import '../../models/folder_node.dart';
import '../../models/item.dart';
import '../../models/storage_location.dart';
import 'sheet_new_folder.dart';
import 'stock_new_item_sheet.dart';
import '../../ui/common/search_field.dart';
import '../../ui/common/path_picker.dart';
import '../../ui/common/entity_actions.dart';
import 'stock_item_detail_screen.dart';
import '../../services/export_service.dart';
import '../../ui/common/qty_set_sheet.dart';
import '../../ui/common/supplier_picker_sheet.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/selection/item_selection_controller.dart';
import 'widgets/stock_item_select_tile.dart';
import '../../providers/cart_manager.dart';
import '../../ui/common/cart_add.dart';
import '../../ui/common/selection/multi_select_bar.dart';
import '../../app/main_tab_controller.dart';
import '../settings/storage_location_screen.dart';
import '../settings/widgets/storage_location_picker_sheet.dart';

import 'widgets/new_item_result.dart';
import 'package:stockapp_mvp/src/ui/common/draggable_fab.dart';
import '../../services/stock_service.dart';
import '../../services/folder_service.dart';
import '../../utils/item_registration.dart';
import 'bulk_item_info_edit_sheet.dart';

part 'stock_browser_header.part.dart';
part 'stock_browser_actions.part.dart';
part 'stock_browser_slivers.part.dart';
part 'stock_browser_helpers.part.dart';

// ============================================================================
//  Explorer-style Stock browser: L1 (roots) -> L2 -> L3 -> Items
// ============================================================================

class StockBrowserScreen extends StatefulWidget {
  final bool showLowStockOnly;
  final List<String>? initialPath;
  final bool autofocusSearch;

  const StockBrowserScreen({
    super.key,
    this.showLowStockOnly = false,
    this.initialPath,
    this.autofocusSearch = false,
  });

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
  bool _needsReviewOnly = false;
  List<String> _locationSummaryItemIds = const [];
  Future<Map<String, ItemLocationSummary>>? _locationSummaryFuture;
  List<String> _visibleSelectionItemIds = const [];
  List<String> _visibleSelectionFolderIds = const [];

  String? get _selectedId => _l3Id ?? _l2Id ?? _l1Id;
  int get _selectedDepth => _l3Id != null
      ? 3
      : _l2Id != null
          ? 2
          : _l1Id != null
              ? 1
              : 0;

  @override
  void initState() {
    super.initState();

    _lowOnly = widget.showLowStockOnly;

    // 🔥 추가
    if (widget.initialPath != null) {
      final path = widget.initialPath!;

      _l1Id = path.isNotEmpty ? path[0] : null;
      _l2Id = path.length > 1 ? path[1] : null;
      _l3Id = path.length > 2 ? path[2] : null;
    }
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

  Future<Map<String, ItemLocationSummary>> _locationSummariesForItems(
    List<Item> items,
  ) {
    final ids = items.map((item) => item.id).toList();
    if (_locationSummaryFuture == null ||
        !_sameStringList(_locationSummaryItemIds, ids)) {
      _locationSummaryItemIds = ids;
      _locationSummaryFuture =
          context.read<StorageLocationRepo>().getLocationSummariesForItems(ids);
    }
    return _locationSummaryFuture!;
  }

  void _invalidateLocationSummaries() {
    _locationSummaryItemIds = const [];
    _locationSummaryFuture = null;
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int get _visibleSelectionTotal =>
      _visibleSelectionItemIds.length + _visibleSelectionFolderIds.length;

  bool _isVisibleSelectionAllSelected(ItemSelectionController sel) {
    return _visibleSelectionTotal > 0 &&
        _visibleSelectionItemIds.every(sel.selectedItems.contains) &&
        _visibleSelectionFolderIds.every(sel.selectedFolders.contains);
  }

  void _toggleVisibleSelection(ItemSelectionController sel) {
    if (_isVisibleSelectionAllSelected(sel)) {
      sel.clear();
    } else {
      sel.selectAllEntities(
        itemIds: _visibleSelectionItemIds,
        folderIds: _visibleSelectionFolderIds,
      );
    }
  }

  void _rememberVisibleSelectionScope(
    List<FolderNode> folders,
    List<Item> items,
  ) {
    final itemIds = items.map((e) => e.id).toList();
    final folderIds = folders.map((e) => e.id).toList();
    if (_sameStringList(_visibleSelectionItemIds, itemIds) &&
        _sameStringList(_visibleSelectionFolderIds, folderIds)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _visibleSelectionItemIds = itemIds;
        _visibleSelectionFolderIds = folderIds;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final folderRepo = context.read<FolderTreeRepo>();
    final itemRepo = context.read<ItemRepo>();

    // ✅ 화면 전반 간격 압축 테마
    final base = Theme.of(context);
    final compact = base.copyWith(
      visualDensity: VisualDensity.compact, // 대부분 위젯 간격 ↓
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // 탭 타겟 축소
      appBarTheme: base.appBarTheme.copyWith(
        toolbarHeight: 44, // AppBar 높이 ↓ (필요 시 조절)
        titleSpacing: 8,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
      chipTheme: base.chipTheme.copyWith(
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        selectedLabelStyle: const TextStyle(fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(32, 32), // 기본 48→32
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );

    return ChangeNotifierProvider(
      create: (_) => ItemSelectionController(),
      child: Builder(
        builder: (context) {
          final sel = context.watch<ItemSelectionController>();
          return Theme(
            // ✅ 여기서 감싼다
            data: compact,
            child: Scaffold(
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
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: AppSearchField(
            controller: _searchC,
            hint: '폴더명 / 아이템명 / SKU / 거래처 검색',
            autofocus: widget.autofocusSearch,
            onChanged: (_) => _debouncedRebuild(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 2,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (sel.selectionMode) ...[
                  IconButton(
                    tooltip: '선택 모드 종료',
                    icon: const Icon(Icons.close),
                    onPressed: sel.exit,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 36),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  IconButton(
                    tooltip: _isVisibleSelectionAllSelected(sel)
                        ? '현재 목록 전체 해제'
                        : '현재 목록 전체 선택',
                    icon: Icon(
                      _isVisibleSelectionAllSelected(sel)
                          ? Icons.deselect
                          : Icons.select_all,
                    ),
                    onPressed: _visibleSelectionTotal == 0
                        ? null
                        : () => _toggleVisibleSelection(sel),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 36),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ] else
                  IconButton(
                    tooltip: '멀티 선택',
                    icon: const Icon(Icons.checklist),
                    onPressed: sel.enter,
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
                FilterChip(
                  label: const Text('정식등록 필요'),
                  selected: _needsReviewOnly,
                  onSelected: (v) => setState(() => _needsReviewOnly = v),
                  avatar: const Icon(Icons.assignment_late_outlined, size: 18),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<Item>>(
            stream: itemRepo.watchItems(
              l1: _searchC.text.trim().isNotEmpty
                  ? null
                  : (_selectedDepth == 0 ? null : _l1Id),
              l2: _searchC.text.trim().isNotEmpty
                  ? null
                  : (_selectedDepth <= 1 ? null : _l2Id),
              l3: _searchC.text.trim().isNotEmpty
                  ? null
                  : (_selectedDepth <= 2 ? null : _l3Id),
              keyword:
                  _searchC.text.trim().isNotEmpty ? _searchC.text.trim() : null,
              recursive: _searchC.text.trim().isNotEmpty
                  ? true
                  : (_selectedDepth == 0 &&
                      (_lowOnly || _showFavoriteOnly || _needsReviewOnly)),
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
                needsReviewOnly: _needsReviewOnly,
              );
              final hasKeyword = _searchC.text.trim().isNotEmpty;
              final keyword = _searchC.text.trim();

              if (hasKeyword) {
                return StreamBuilder<List<FolderNode>>(
                  stream: folderRepo.watchFolderSearch(keyword), // ✅ 1)에서 만든 것
                  builder: (ctx, folderSnap) {
                    if (folderSnap.connectionState == ConnectionState.waiting &&
                        !folderSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (folderSnap.hasError) {
                      return Center(child: Text('오류: ${folderSnap.error}'));
                    }

                    final folders = folderSnap.data ?? const <FolderNode>[];
                    _rememberVisibleSelectionScope(folders, items);

                    final slivers = <Widget>[];
                    slivers.add(_sliverBreadcrumb(context, setState));

                    if (folders.isNotEmpty) {
                      slivers.add(_sliverHeader('📁 폴더'));
                      slivers.add(
                        _buildFolderSliver(
                          context,
                          folders,
                          setState,
                          (n) => _tryDeleteFolder(
                              context, n, () => setState(() {})),
                          (n) => _jumpToFolderFromSearch(
                              folderRepo: folderRepo, target: n, sel: sel),
                        ),
                      );
                    }

                    if (items.isNotEmpty) {
                      slivers.add(_sliverHeader('📦 아이템'));
                      slivers.add(_buildItemSliverWithLocationSummaries(
                          context, items));
                    }

                    if (folders.isEmpty && items.isEmpty) {
                      return const Center(child: Text('검색 결과가 없습니다.'));
                    }

                    return _buildStackWithList(
                      sel,
                      folders,
                      items,
                      slivers,
                    );
                  },
                );
              }

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
                  _rememberVisibleSelectionScope(folders, items);
                  final hasKeyword = _searchC.text.trim().isNotEmpty;
                  final depth = _selectedDepth;

                  final slivers = <Widget>[];
                  slivers.add(_sliverBreadcrumb(context, setState));
                  if (depth == 0 &&
                      !hasKeyword &&
                      (_lowOnly || _showFavoriteOnly || _needsReviewOnly)) {
                    if (items.isEmpty) {
                      return const Center(child: Text('조건에 맞는 아이템이 없습니다.'));
                    }
                    slivers.add(
                        _buildItemSliverWithLocationSummaries(context, items));
                  } else if (hasKeyword) {
                    if (folders.isNotEmpty) {
                      slivers.add(_sliverHeader('📁 폴더'));
                      slivers.add(
                        _buildFolderSliver(
                          context,
                          folders,
                          setState,
                          (n) => _tryDeleteFolder(
                              context, n, () => setState(() {})),
                          null,
                        ),
                      );
                    }
                    if (items.isNotEmpty) {
                      slivers.add(_buildItemSliverWithLocationSummaries(
                          context, items));
                    }
                  } else if (depth == 0) {
                    slivers.add(
                      _buildFolderSliver(
                        context,
                        folders,
                        setState,
                        (n) =>
                            _tryDeleteFolder(context, n, () => setState(() {})),
                        null,
                      ),
                    );
                  } else {
                    if (folders.isNotEmpty) {
                      slivers.add(
                        _buildFolderSliver(
                          context,
                          folders,
                          setState,
                          (n) => _tryDeleteFolder(
                              context, n, () => setState(() {})),
                          null,
                        ),
                      );
                    }
                    if (items.isNotEmpty) {
                      slivers.add(_buildItemSliverWithLocationSummaries(
                          context, items));
                    }
                  }

                  // 리스트 + 멀티선택바
                  return _buildStackWithList(
                    sel,
                    folders,
                    items,
                    slivers,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemSliverWithLocationSummaries(
    BuildContext context,
    List<Item> items,
  ) {
    return FutureBuilder<Map<String, ItemLocationSummary>>(
      future: _locationSummariesForItems(items),
      builder: (context, snapshot) {
        return _buildItemSliver(
          context,
          items,
          locationSummaries:
              snapshot.data ?? const <String, ItemLocationSummary>{},
          onLocationChanged: () {
            _invalidateLocationSummaries();
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  // ───────────────────────── FloatingActionButton 빌더 ─────────────────────────
  Widget buildFloatingButton(BuildContext context, int depth) {
    final folderRepo = context.read<FolderTreeRepo>();
    final itemRepo = context.read<ItemRepo>();
    final selectedId = context
        .findAncestorStateOfType<_StockBrowserScreenState>()
        ?._selectedId;
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
                  onTap: isLeaf ? null : () => Navigator.pop(context, 'folder'),
                ),
              ],
            ),
          ),
        );

        if (act == 'folder') {
          await _createFolder(context, folderRepo, selectedId);
          if (!mounted) return;
          setState(() {}); // ✅ 생성 직후 목록 갱신 트리거
        }
        if (act == 'item') {
          await _createItem(context, selectedId, folderRepo, itemRepo);
          if (!mounted) return;
          setState(() {}); // ✅ 생성 직후 목록 갱신 트리거
        }
      },
      child: const Icon(Icons.add),
    );
  }

  //---------멅티셀렉 함수 --------//
  Widget _buildMultiSelectBar({
    required BuildContext context,
    required ItemSelectionController sel,
    required List<FolderNode> folders,
    required List<Item> items,
  }) {
    final totalCount = folders.length + items.length;
    final secondaryActions = <MultiSelectAction>[
      MultiSelectAction(
        icon: Icons.edit_note,
        tooltip: '정보 일괄 수정',
        onPressed: () async {
          final itemIds = sel.selectedItems.toList();
          if (itemIds.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('정보 수정은 아이템을 선택해야 사용할 수 있어요.')),
            );
            return;
          }

          final changed = await showBulkItemInfoEditSheet(
            context,
            itemIds: itemIds,
          );
          if (changed != true) return;
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('선택한 ${itemIds.length}개 아이템 정보를 수정했어요.')),
          );
          sel.exit();
          setState(() {});
        },
      ),
      MultiSelectAction(
        icon: Icons.location_on_outlined,
        tooltip: '보관 위치 지정',
        onPressed: () async {
          final itemIds = sel.selectedItems.toList();
          if (itemIds.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('아이템을 선택해야 위치를 지정할 수 있어요.')),
            );
            return;
          }

          final location = await showStorageLocationPickerSheet(context);
          if (location == null) return;

          await context.read<StorageLocationRepo>().setPrimaryLocationForItems(
                itemIds: itemIds,
                locationId: location.id,
              );

          if (!context.mounted) return;
          _invalidateLocationSummaries();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '선택한 ${itemIds.length}개 아이템의 기본 위치를 지정했어요.',
              ),
            ),
          );

          sel.exit();
          setState(() {});
        },
      ),
      MultiSelectAction(
        icon: Icons.storefront_outlined,
        tooltip: '거래처 지정',
        onPressed: () async {
          final itemIds = sel.selectedItems.toList();
          if (itemIds.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('아이템을 선택해야 거래처를 지정할 수 있어요.')),
            );
            return;
          }

          final supplier = await showSupplierPickerSheet(
            context,
            title: '선택 아이템 거래처 지정',
          );
          if (supplier == null) return;

          await context.read<ItemRepo>().setDefaultSupplierBulk(
                ids: itemIds,
                supplier: supplier,
              );

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '선택한 ${itemIds.length}개 아이템의 거래처를 ${supplier.name}(으)로 지정했어요.',
              ),
            ),
          );

          sel.exit();
          setState(() {});
        },
      ),
      MultiSelectAction(
        icon: Icons.drive_file_move,
        tooltip: '이동',
        onPressed: () async {
          if (sel.selectedCount == 0) return;

          final repo = context.read<FolderTreeRepo>();
          final itemRepo = context.read<ItemRepo>();
          final selectedItemIds = sel.selectedItems.toList(growable: false);
          final dest = await showPathPicker(
            context,
            childrenProvider: pathChildrenFromFolderRepo(repo),
            title: sel.selectedFolders.isEmpty ? '아이템 이동..' : '선택 항목 이동..',
            maxDepth: sel.selectedFolders.isEmpty ? 3 : 2,
          );
          if (dest == null || dest.isEmpty) return;

          var movedItems = 0;
          var movedFolders = 0;
          var finalizedItems = 0;

          try {
            if (selectedItemIds.isNotEmpty) {
              movedItems = await repo.moveItemsToPath(
                itemIds: selectedItemIds,
                pathIds: dest,
              );
              for (final itemId in selectedItemIds) {
                if (await itemRepo.tryFinalizeRegistration(itemId)) {
                  finalizedItems++;
                }
              }
            }

            final foldersToMove = await _topLevelSelectedFolders(repo, sel);
            for (final folderId in foldersToMove) {
              await repo.moveEntityToPath(
                MoveRequest(
                  kind: EntityKind.folder,
                  id: folderId,
                  pathIds: dest,
                ),
              );
              movedFolders++;
            }
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('이동 실패: $e')),
            );
            return;
          }

          if (!context.mounted) return;
          final registrationSuffix =
              finalizedItems > 0 ? ' · 정식등록 $finalizedItems개 완료' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '아이템 $movedItems개, 폴더 $movedFolders개 이동$registrationSuffix',
              ),
            ),
          );

          sel.exit();
        },
      ),
      MultiSelectAction(
        icon: Icons.copy,
        tooltip: '복사',
        onPressed: () async {
          if (sel.selectedCount == 0) return;

          final folderService = context.read<FolderService>();
          final folderRepo = context.read<FolderTreeRepo>();
          final itemRepo = context.read<ItemRepo>();
          final foldersToCopy = await _topLevelSelectedFolders(
            folderRepo,
            sel,
          );

          if (sel.selectedItems.isNotEmpty && foldersToCopy.isEmpty) {
            final sourceItems = <Item>[];
            for (final id in sel.selectedItems) {
              final item = await itemRepo.getItem(id);
              if (item != null) sourceItems.add(item);
            }
            if (sourceItems.isEmpty) return;
            if (!context.mounted) return;
            final options = await _showItemCopyDialog(
              context,
              items: sourceItems,
            );
            if (options == null) return;
            await folderService.copyItemsWithOptions(
              sourceItems.map((item) => item.id).toList(),
              options,
            );
          } else {
            for (final id in sel.selectedItems) {
              await folderService.copySingleItem(id);
            }
          }
          for (final id in foldersToCopy) {
            await folderService.copyFolderTree(id);
          }

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${sel.selectedCount}개 복사됨')),
          );

          sel.exit();
        },
      ),
      MultiSelectAction(
        icon: Icons.delete_outline,
        tooltip: '휴지통',
        color: Colors.redAccent,
        onPressed: () async {
          if (sel.selectedCount == 0) return;

          final ok = await showDeleteConfirm(
            context,
            message: '선택한 ${sel.selectedCount}개를 휴지통으로 보낼까요?',
          );
          if (ok != true) return;

          final itemRepo = context.read<ItemRepo>();
          final folderRepo = context.read<FolderTreeRepo>();

          try {
            if (sel.selectedItems.isNotEmpty) {
              await itemRepo.moveItemsToTrash(sel.selectedItems.toList());
            }
            final foldersToDelete = await _topLevelSelectedFolders(
              folderRepo,
              sel,
            );
            for (final folderId in foldersToDelete) {
              await folderRepo.deleteFolderNode(folderId, force: true);
            }
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_friendlyDeleteError(e))),
            );
            return;
          }

          if (!context.mounted) return;
          showGoSnack(
            context,
            message: '${sel.selectedCount}개 이동 완료',
            actionText: '휴지통 열기',
            onAction: (_) =>
                context.read<MainTabController>().openShellRoute('/trash'),
          );

          sel.exit();
        },
      ),
    ];

    return CommonMultiSelectBar(
      selectedCount: sel.selectedCount,
      totalCount: totalCount,
      actions: [
        // ⭐ 즐겨찾기
        MultiSelectAction(
          icon: Icons.star,
          tooltip: '즐겨찾기',
          onPressed: () async {
            final picked =
                items.where((it) => sel.selectedItems.contains(it.id)).toList();
            if (picked.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('아이템을 선택해야 즐겨찾기를 바꿀 수 있어요.')),
              );
              return;
            }

            final repo = context.read<ItemRepo>();
            final ids = picked.map((e) => e.id).toList();
            final allFav = picked.every((it) => it.isFavorite == true);
            final next = !allFav;

            final dyn = repo as dynamic;
            if (dyn.setFavoritesBulk is Function) {
              await dyn.setFavoritesBulk(ids: ids, value: next);
            } else {
              for (final id in ids) {
                await repo.setFavorite(itemId: id, value: next);
              }
            }

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(next
                      ? '선택한 ${ids.length}개 즐겨찾기 추가'
                      : '선택한 ${ids.length}개 즐겨찾기 해제')),
            );
          },
        ),
        // 장바구니
        MultiSelectAction(
          icon: Icons.add_shopping_cart,
          tooltip: '담기',
          onPressed: () {
            final picked =
                items.where((it) => sel.selectedItems.contains(it.id)).toList();
            if (picked.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('장바구니에는 아이템만 담을 수 있어요.')),
              );
              return;
            }

            final cart = context.read<CartManager>();
            addItemsToCart(cart, picked);

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${picked.length}개 담기 완료')),
            );
          },
        ),
        MultiSelectAction(
          icon: Icons.more_horiz,
          tooltip: '더보기',
          onPressed: () async {
            final picked = await showModalBottomSheet<MultiSelectAction>(
              context: context,
              showDragHandle: true,
              builder: (sheetContext) => SafeArea(
                child: Wrap(
                  children: [
                    for (final action in secondaryActions)
                      ListTile(
                        leading: Icon(action.icon, color: action.color),
                        title: Text(
                          action.tooltip,
                          style: TextStyle(color: action.color),
                        ),
                        onTap: () => Navigator.pop(sheetContext, action),
                      ),
                  ],
                ),
              ),
            );
            picked?.onPressed();
          },
        ),
      ],
    );
  }

  //------빌드 스택 위드 리스트 ------//

  Widget _buildStackWithList(
    ItemSelectionController sel,
    List<FolderNode> folders,
    List<Item> items,
    List<Widget> slivers,
  ) {
    return Stack(
      children: [
        CustomScrollView(slivers: slivers),
        if (sel.selectionMode)
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildMultiSelectBar(
              context: context,
              sel: sel,
              folders: folders,
              items: items,
            ),
          ),
      ],
    );
  }

  Future<List<String>> _topLevelSelectedFolders(
    FolderTreeRepo repo,
    ItemSelectionController sel,
  ) async {
    final selected = sel.selectedFolders;
    final result = <String>[];

    for (final folderId in selected) {
      var hasSelectedAncestor = false;
      var current = await repo.folderById(folderId);

      while (current?.parentId != null) {
        final parentId = current!.parentId!;
        if (selected.contains(parentId)) {
          hasSelectedAncestor = true;
          break;
        }
        current = await repo.folderById(parentId);
      }

      if (!hasSelectedAncestor) result.add(folderId);
    }

    return result;
  }

  //----검색결과 나온 폴더로 이동 ----//
//----검색결과 나온 폴더로 이동 ----//
  Future<void> _jumpToFolderFromSearch({
    required FolderTreeRepo folderRepo,
    required FolderNode target,
    required ItemSelectionController sel,
  }) async {
    // 키보드 닫기
    FocusScope.of(context).unfocus();

    // target -> parent -> ... -> root 로 쌓기
    final chain = <FolderNode>[target];
    var cur = target;

    while (cur.parentId != null) {
      final parent = await folderRepo.folderById(cur.parentId!);
      if (parent == null) break;
      chain.add(parent);
      cur = parent;
    }

    // root -> ... -> target
    final path = chain.reversed.toList();

    setState(() {
      // ✅ 여기서 chain이 아니라 path를 써야 "탭한 폴더(target)"가 최종 목적지가 됨
      _l1Id = path.isNotEmpty ? path[0].id : null;
      _l2Id = path.length >= 2 ? path[1].id : null;
      _l3Id = path.length >= 3 ? path[2].id : null;

      // 검색 종료 (탐색 모드로 전환)
      _searchC.clear();

      // 멀티선택 해제(선택 상태로 점프하면 UX 혼동 생김)
      sel.exit();
    });
  }
}
