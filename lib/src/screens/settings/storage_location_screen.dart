import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/item.dart';
import '../../models/storage_location.dart';
import '../../repos/repo_interfaces.dart';
import '../stock/stock_item_detail_screen.dart';
import 'widgets/storage_location_picker_sheet.dart';

class StorageLocationScreen extends StatefulWidget {
  const StorageLocationScreen({super.key});

  @override
  State<StorageLocationScreen> createState() => _StorageLocationScreenState();
}

class _StorageLocationScreenState extends State<StorageLocationScreen> {
  final _searchC = TextEditingController();
  bool _loading = true;
  String _query = '';
  List<StorageLocation> _roots = const [];
  List<StorageLocation> _allLocations = const [];
  Map<String, int> _childCounts = const {};
  Map<String, int> _itemCounts = const {};

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() {
      setState(() => _query = _searchC.text.trim());
    });
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<StorageLocationRepo>();
    setState(() => _loading = true);
    final roots = await repo.listRootLocations();
    final all = await repo.searchLocations('');
    final childCounts = <String, int>{};
    final itemCounts = <String, int>{};
    for (final location in all) {
      childCounts[location.id] = await repo.countChildLocations(location.id);
      itemCounts[location.id] = await repo.countItemsForLocationTree(
        location.id,
      );
    }
    if (!mounted) return;
    setState(() {
      _roots = roots;
      _allLocations = all;
      _childCounts = childCounts;
      _itemCounts = itemCounts;
      _loading = false;
    });
  }

  Future<void> _openEditor({
    StorageLocation? location,
    StorageLocation? parent,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StorageLocationEditorScreen(
          location: location,
          parent: parent,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _archive(StorageLocation location) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('보관 위치 보관'),
        content: Text('${location.name} 위치를 보관할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('보관'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await context.read<StorageLocationRepo>().archiveLocation(location.id);
    await _load();
  }

  Future<void> _openDetail(StorageLocation location) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StorageLocationDetailScreen(locationId: location.id),
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  String _pathLabel(StorageLocation location) {
    final byId = {for (final loc in _allLocations) loc.id: loc};
    final names = <String>[location.name];
    var cursor = location.parentId == null ? null : byId[location.parentId];
    while (cursor != null) {
      names.insert(0, cursor.name);
      cursor = cursor.parentId == null ? null : byId[cursor.parentId];
    }
    return names.join(' > ');
  }

  List<StorageLocation> get _filtered {
    if (_query.isEmpty) return const [];
    final q = _query.toLowerCase();
    return _allLocations.where((location) {
      return _pathLabel(location).toLowerCase().contains(q) ||
          StorageLocationType.label(location.type).contains(_query) ||
          (location.memo ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('보관 위치 관리'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: '위치'),
              Tab(text: '아이템 찾기'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '새로고침',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('위치'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildLocationTab(),
                  const _ItemLocationSearchTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildLocationTab() {
    final searching = _query.isNotEmpty;
    final filtered = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          TextField(
            controller: _searchC,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: '위치 검색',
              hintText: '작업실, 선반, 박스 이름으로 찾기',
            ),
          ),
          const SizedBox(height: 12),
          if (searching)
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: Text('검색된 위치가 없습니다')),
              )
            else
              ...filtered.map(
                (location) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(_pathLabel(location)),
                    subtitle: Text(_countSubtitle(location)),
                    onTap: () => _openDetail(location),
                  ),
                ),
              )
          else if (_roots.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Icon(Icons.location_on_outlined, size: 48),
                  SizedBox(height: 12),
                  Text('등록된 보관 위치가 없습니다'),
                ],
              ),
            )
          else
            ..._roots.map(
              (location) => _StorageLocationNodeTile(
                key: ValueKey(location.id),
                location: location,
                depth: 0,
                childCounts: _childCounts,
                itemCounts: _itemCounts,
                onOpen: _openDetail,
                onAddChild: (parent) => _openEditor(parent: parent),
                onEdit: (target) => _openEditor(location: target),
                onArchive: _archive,
              ),
            ),
        ],
      ),
    );
  }

  String _countSubtitle(StorageLocation location) {
    final typeLabel = StorageLocationType.label(location.type);
    final childCount = _childCounts[location.id] ?? 0;
    final itemCount = _itemCounts[location.id] ?? 0;
    return '$typeLabel · 하위 위치 $childCount개 · 아이템 $itemCount개';
  }
}

class _StorageLocationNodeTile extends StatefulWidget {
  final StorageLocation location;
  final int depth;
  final Map<String, int> childCounts;
  final Map<String, int> itemCounts;
  final ValueChanged<StorageLocation> onOpen;
  final ValueChanged<StorageLocation> onAddChild;
  final ValueChanged<StorageLocation> onEdit;
  final ValueChanged<StorageLocation> onArchive;

  const _StorageLocationNodeTile({
    super.key,
    required this.location,
    required this.depth,
    required this.childCounts,
    required this.itemCounts,
    required this.onOpen,
    required this.onAddChild,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  State<_StorageLocationNodeTile> createState() =>
      _StorageLocationNodeTileState();
}

class _StorageLocationNodeTileState extends State<_StorageLocationNodeTile> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<StorageLocationRepo>();
    final left = 12.0 + (widget.depth * 18.0);
    final childCount = widget.childCounts[widget.location.id] ?? 0;
    final hasChildren = childCount > 0;

    return Padding(
      padding: EdgeInsets.only(left: left, bottom: 8),
      child: Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(_iconForType(widget.location.type)),
              title: Text(widget.location.name),
              subtitle: Text(_countSubtitle(widget.location)),
              onTap: () => widget.onOpen(widget.location),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasChildren)
                    IconButton(
                      tooltip: _expanded ? '하위 위치 접기' : '하위 위치 펼치기',
                      onPressed: _toggleExpanded,
                      icon: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'child') widget.onAddChild(widget.location);
                      if (value == 'edit') widget.onEdit(widget.location);
                      if (value == 'archive') widget.onArchive(widget.location);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'child',
                        child: ListTile(
                          leading: Icon(Icons.subdirectory_arrow_right),
                          title: Text('하위 위치 추가'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('수정'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: ListTile(
                          leading: Icon(Icons.archive_outlined),
                          title: Text('보관'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_expanded)
              FutureBuilder<List<StorageLocation>>(
                future: repo.listChildLocations(widget.location.id),
                builder: (context, snapshot) {
                  final children = snapshot.data ?? const <StorageLocation>[];
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (children.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: children
                        .map(
                          (child) => _StorageLocationNodeTile(
                            key: ValueKey(child.id),
                            location: child,
                            depth: widget.depth + 1,
                            childCounts: widget.childCounts,
                            itemCounts: widget.itemCounts,
                            onOpen: widget.onOpen,
                            onAddChild: widget.onAddChild,
                            onEdit: widget.onEdit,
                            onArchive: widget.onArchive,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _countSubtitle(StorageLocation location) {
    final typeLabel = StorageLocationType.label(location.type);
    final childCount = widget.childCounts[location.id] ?? 0;
    final itemCount = widget.itemCounts[location.id] ?? 0;
    return '$typeLabel · 하위 위치 $childCount개 · 아이템 $itemCount개';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case StorageLocationType.room:
        return Icons.meeting_room_outlined;
      case StorageLocationType.warehouse:
        return Icons.warehouse_outlined;
      case StorageLocationType.store:
        return Icons.storefront_outlined;
      case StorageLocationType.shelf:
        return Icons.shelves;
      case StorageLocationType.rack:
        return Icons.view_module_outlined;
      case StorageLocationType.box:
        return Icons.inventory_2_outlined;
      case StorageLocationType.drawer:
        return Icons.inbox_outlined;
      case StorageLocationType.section:
        return Icons.grid_view_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}

class _ItemLocationSearchTab extends StatefulWidget {
  const _ItemLocationSearchTab();

  @override
  State<_ItemLocationSearchTab> createState() => _ItemLocationSearchTabState();
}

class _ItemLocationSearchTabState extends State<_ItemLocationSearchTab> {
  final _searchC = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() {
      setState(() => _query = _searchC.text.trim());
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _openItem(String itemId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockItemDetailScreen(itemId: itemId),
      ),
    );
  }

  void _openLocation(StorageLocation location) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StorageLocationDetailScreen(locationId: location.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<StorageLocationRepo>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        TextField(
          controller: _searchC,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: '아이템 위치 검색',
            hintText: '아이템명, SKU, 별칭, 초성으로 찾기',
          ),
        ),
        const SizedBox(height: 12),
        if (_query.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Column(
              children: [
                Icon(Icons.manage_search, size: 48),
                SizedBox(height: 12),
                Text('찾고 싶은 아이템을 검색하면 보관 위치가 같이 보여요'),
              ],
            ),
          )
        else
          FutureBuilder<List<ItemWithLocations>>(
            future: repo.searchItemsWithLocations(_query),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: LinearProgressIndicator(),
                );
              }
              final results = snapshot.data ?? const <ItemWithLocations>[];
              if (results.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: Text('검색된 아이템이 없습니다')),
                );
              }

              return Column(
                children: [
                  for (final result in results) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(
                          result.item.displayName?.trim().isNotEmpty == true
                              ? result.item.displayName!
                              : result.item.name,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'SKU ${result.item.sku} · 재고 ${result.item.qty}'),
                            const SizedBox(height: 4),
                            if (result.primaryLocation == null)
                              const Text('기본 위치 없음')
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ActionChip(
                                    avatar: const Icon(Icons.star, size: 16),
                                    label: Text(
                                      result.primaryLocationPath ??
                                          result.primaryLocation!.name,
                                    ),
                                    onPressed: () =>
                                        _openLocation(result.primaryLocation!),
                                  ),
                                  if (result.otherLocationCount > 0)
                                    Chip(
                                      label: Text(
                                          '기타 위치 ${result.otherLocationCount}곳'),
                                    ),
                                ],
                              ),
                          ],
                        ),
                        onTap: () => _openItem(result.item.id),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class StorageLocationDetailScreen extends StatefulWidget {
  final String locationId;

  const StorageLocationDetailScreen({
    super.key,
    required this.locationId,
  });

  @override
  State<StorageLocationDetailScreen> createState() =>
      _StorageLocationDetailScreenState();
}

class _StorageLocationDetailScreenState
    extends State<StorageLocationDetailScreen> {
  Future<_StorageLocationDetailData> _load() async {
    final repo = context.read<StorageLocationRepo>();
    final results = await Future.wait([
      repo.getLocation(widget.locationId),
      repo.buildLocationBreadcrumb(widget.locationId),
      repo.listChildLocations(widget.locationId),
      repo.listItemsForLocation(widget.locationId),
      repo.listItemLocationsForLocation(widget.locationId),
      repo.listDescendantLocations(widget.locationId),
      repo.listItemEntriesForLocationTree(widget.locationId),
    ]);

    return _StorageLocationDetailData(
      location: results[0] as StorageLocation?,
      breadcrumb: results[1] as List<StorageLocation>,
      children: results[2] as List<StorageLocation>,
      items: results[3] as List<Item>,
      links: results[4] as List<ItemLocation>,
      descendants: results[5] as List<StorageLocation>,
      treeItemEntries: results[6] as List<LocationItemEntry>,
    );
  }

  Future<void> _openEditor(StorageLocation location) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StorageLocationEditorScreen(location: location),
      ),
    );
    if (changed == true && mounted) {
      setState(() {});
    }
  }

  void _openItem(String itemId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockItemDetailScreen(itemId: itemId),
      ),
    );
  }

  void _openChild(StorageLocation location) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StorageLocationDetailScreen(locationId: location.id),
      ),
    );
  }

  Future<void> _moveItemFromLocation({
    required Item item,
    required String fromLocationId,
  }) async {
    final toLocation = await showStorageLocationPickerSheet(context);
    if (!mounted || toLocation == null) return;
    if (toLocation.id == fromLocationId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 같은 위치에 있어요.')),
      );
      return;
    }

    await context.read<StorageLocationRepo>().moveItemLocation(
          itemId: item.id,
          fromLocationId: fromLocationId,
          toLocationId: toLocation.id,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_itemLabel(item)} 위치를 이동했어요.')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StorageLocationDetailData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final location = data?.location;

        return Scaffold(
          appBar: AppBar(
            title: Text(location?.name ?? '위치 상세'),
            centerTitle: true,
            actions: [
              if (location != null)
                IconButton(
                  tooltip: '수정',
                  onPressed: () => _openEditor(location),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: snapshot.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : location == null
                  ? const Center(child: Text('위치를 찾을 수 없습니다'))
                  : _buildBody(context, data!),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, _StorageLocationDetailData data) {
    final breadcrumb =
        data.breadcrumb.map((location) => location.name).join(' > ');
    final primaryItemIds = data.links
        .where((link) => link.isPrimary)
        .map((link) => link.itemId)
        .toSet();
    final directLinksByItemId = {
      for (final link in data.links) link.itemId: link,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  breadcrumb,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.category_outlined, size: 16),
                      label:
                          Text(StorageLocationType.label(data.location!.type)),
                    ),
                    Chip(
                      avatar:
                          const Icon(Icons.subdirectory_arrow_right, size: 16),
                      label: Text('하위 위치 ${data.descendants.length}개'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: Text('직접 아이템 ${data.items.length}개'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.account_tree_outlined, size: 16),
                      label: Text('하위 포함 ${data.treeItemEntries.length}개'),
                    ),
                  ],
                ),
                if ((data.location!.memo ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(data.location!.memo!.trim()),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('하위 위치', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (data.children.isEmpty)
          const Card(
            child: ListTile(title: Text('하위 위치가 없습니다')),
          )
        else
          ...data.children.map(
            (child) => Card(
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(child.name),
                subtitle: Text(StorageLocationType.label(child.type)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openChild(child),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          data.descendants.isEmpty ? '이 위치의 아이템' : '하위 위치 포함 아이템',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (data.treeItemEntries.isEmpty)
          const Card(
            child: ListTile(title: Text('이 위치와 하위 위치에 연결된 아이템이 없습니다')),
          )
        else
          ...data.treeItemEntries.map(
            (entry) {
              final item = entry.item;
              return Card(
                child: ListTile(
                  leading: Icon(
                    entry.isPrimary ? Icons.star : Icons.inventory_2_outlined,
                  ),
                  title: Text(item.displayName?.trim().isNotEmpty == true
                      ? item.displayName!
                      : item.name),
                  subtitle: Text(
                    'SKU ${item.sku} · 총재고 ${item.qty}${item.unit} · '
                    '위치수량 ${entry.qty}${item.unit} · ${entry.locationPath}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _ItemLocationActions(
                    isPrimary: entry.isPrimary,
                    onMove: () => _moveItemFromLocation(
                      item: item,
                      fromLocationId: entry.location.id,
                    ),
                  ),
                  onTap: () => _openItem(item.id),
                ),
              );
            },
          ),
        if (data.descendants.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('이 위치에 직접 연결된 아이템',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (data.items.isEmpty)
            const Card(
              child: ListTile(title: Text('직접 연결된 아이템은 없습니다')),
            )
          else
            ...data.items.map(
              (item) {
                final isPrimary = primaryItemIds.contains(item.id);
                final link = directLinksByItemId[item.id];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      isPrimary ? Icons.star : Icons.inventory_2_outlined,
                    ),
                    title: Text(item.displayName?.trim().isNotEmpty == true
                        ? item.displayName!
                        : item.name),
                    subtitle: Text(
                      'SKU ${item.sku} · 총재고 ${item.qty}${item.unit} · '
                      '위치수량 ${link?.qty ?? 0}${item.unit}',
                    ),
                    trailing: _ItemLocationActions(
                      isPrimary: isPrimary,
                      onMove: () => _moveItemFromLocation(
                        item: item,
                        fromLocationId: data.location!.id,
                      ),
                    ),
                    onTap: () => _openItem(item.id),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  String _itemLabel(Item item) {
    return item.displayName?.trim().isNotEmpty == true
        ? item.displayName!.trim()
        : item.name;
  }
}

class _StorageLocationDetailData {
  final StorageLocation? location;
  final List<StorageLocation> breadcrumb;
  final List<StorageLocation> children;
  final List<Item> items;
  final List<ItemLocation> links;
  final List<StorageLocation> descendants;
  final List<LocationItemEntry> treeItemEntries;

  const _StorageLocationDetailData({
    required this.location,
    required this.breadcrumb,
    required this.children,
    required this.items,
    required this.links,
    required this.descendants,
    required this.treeItemEntries,
  });
}

class _ItemLocationActions extends StatelessWidget {
  final bool isPrimary;
  final VoidCallback onMove;

  const _ItemLocationActions({
    required this.isPrimary,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPrimary) const Chip(label: Text('기본')),
        IconButton(
          tooltip: '위치 이동',
          onPressed: onMove,
          icon: const Icon(Icons.drive_file_move_outlined),
        ),
      ],
    );
  }
}

class StorageLocationEditorScreen extends StatefulWidget {
  final StorageLocation? location;
  final StorageLocation? parent;

  const StorageLocationEditorScreen({
    super.key,
    this.location,
    this.parent,
  });

  @override
  State<StorageLocationEditorScreen> createState() =>
      _StorageLocationEditorScreenState();
}

class _StorageLocationEditorScreenState
    extends State<StorageLocationEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _memoC = TextEditingController();
  final _uuid = const Uuid();
  late final String _locationId;
  late String _type;

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    _locationId = location?.id ?? _uuid.v4();
    _nameC.text = location?.name ?? '';
    _memoC.text = location?.memo ?? '';
    _type = location?.type ?? StorageLocationType.room;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _memoC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = context.read<StorageLocationRepo>();
    final now = DateTime.now();
    final existing = widget.location;
    final location = StorageLocation(
      id: _locationId,
      name: _nameC.text.trim(),
      parentId: existing?.parentId ?? widget.parent?.id,
      type: _type,
      memo: _nullIfBlank(_memoC.text),
      sortOrder: existing?.sortOrder ?? 0,
      isArchived: false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (existing == null) {
      await repo.createLocation(location);
    } else {
      await repo.updateLocation(location);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.location != null;
    final parentName = widget.location == null ? widget.parent?.name : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '보관 위치 수정' : '보관 위치 추가'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '저장',
            onPressed: _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            if (parentName != null) ...[
              InputDecorator(
                decoration: const InputDecoration(labelText: '상위 위치'),
                child: Text(parentName),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nameC,
              decoration: const InputDecoration(labelText: '위치명 *'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '위치명을 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: '위치 유형'),
              items: StorageLocationType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(StorageLocationType.label(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _memoC,
              decoration: const InputDecoration(labelText: '메모'),
              minLines: 1,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
