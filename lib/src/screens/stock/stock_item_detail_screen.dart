// lib/src/screens/stock/stock_item_detail_screen.dart
// ignore_for_file: unused_element

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart' hide TxnRow;
import '../../models/attachment_domain.dart';
import '../../models/item_image.dart';
import '../../models/item.dart';
import '../../models/storage_location.dart';
import '../../repos/repo_interfaces.dart';

import '../../ui/common/ui.dart';
import '../../utils/item_presentation.dart'; // ItemLabel

import '../bom/finished_bom_edit_screen.dart';
import '../bom/semi_bom_edit_screen.dart';

import '../txns/adjust_form.dart';
import '../../models/txn.dart' show Txn;
import '../txns/widgets/txn_row.dart';
import 'stock_item_full_edit_screen.dart';
import 'widgets/item_meta_overview.dart';
import 'widgets/reorder_badge.dart';
import '../../ui/common/qty_set_sheet.dart';
import '../../ui/common/inout_flow.dart';
import '../../ui/common/path_picker.dart';

import '../../dev/bom_debug.dart'; // 콘솔 덤프 유틸
import '../../providers/cart_manager.dart';
import '../../ui/common/cart_add.dart';
import '../../services/stock_service.dart';
import '../../services/app_path_service.dart';
import '../../services/attachment_file_service.dart';
import '../../services/attachment_policy_service.dart';
import '../../utils/item_registration.dart';
import '../../utils/reorder_schedule_utils.dart';
import '../../app/main_tab_controller.dart';

class StockItemDetailScreen extends StatefulWidget {
  final String itemId;
  const StockItemDetailScreen({super.key, required this.itemId});

  @override
  State<StockItemDetailScreen> createState() => _StockItemDetailScreenState();
}

class _ItemLocationViewData {
  final List<StorageLocation> locations;
  final List<ItemLocation> links;
  final List<StorageLocation> allLocations;

  const _ItemLocationViewData({
    required this.locations,
    required this.links,
    required this.allLocations,
  });
}

class _StockItemDetailScreenState extends State<StockItemDetailScreen> {
  Item? _item; // 사람 읽는 이름 (repo.nameOf)
  bool? _isFinished; // finished/semi 추정
  List<String> _registrationMissing = const [];
  int _locationMovementRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _buildRegistrationNotice(List<String> missing) {
    final items = missing.isEmpty ? const ['필수값 확인 필요'] : missing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_late_outlined,
                  size: 18, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '정식등록 필요 아이템입니다. 필수값을 입력해주세요.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (text) => Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text('- $text'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final itemRepo = context.read<ItemRepo>();
    final item = await itemRepo.getItem(widget.itemId);
    final missing = item == null
        ? const <String>[]
        : await itemRepo.registrationMissingFields(widget.itemId);

    bool? finishedGuess;
    if (item != null) {
      // 레거시 폴더 체계로 finished/semi 추정 (없으면 null)
      final segs = <String>[
        item.folder,
        if (item.subfolder != null) item.subfolder!,
        if (item.subsubfolder != null) item.subsubfolder!,
      ].map((e) => e.toLowerCase());
      final joined = segs.join('/');
      if (joined.contains('finished') || joined.contains('완제품')) {
        finishedGuess = true;
      } else if (joined.contains('semi') ||
          joined.contains('반제품') ||
          joined.contains('세미')) {
        finishedGuess = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _item = item;
      _isFinished = finishedGuess;
      _registrationMissing = missing;
    });
  }

  Future<void> _showRecentTxns() async {
    try {
      final txnRepo = context.read<TxnRepo>();
      final all = await txnRepo.listTxns();
      final List<Txn> filtered =
          all.cast<Txn>().where((t) => t.itemId == widget.itemId).toList();
      DateTime _ts(Txn x) => x.ts;
      filtered.sort((a, b) => _ts(b).compareTo(_ts(a)));

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) {
          if (filtered.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.t.txn_list_empty_hint),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => TxnRow(t: filtered[i]),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최근 입출고 내역을 불러올 수 없습니다: $e')),
      );
    }
  }

  Future<_ItemLocationViewData> _loadItemLocationViewData(String itemId) async {
    final repo = context.read<StorageLocationRepo>();
    final results = await Future.wait([
      repo.listLocationsForItem(itemId),
      repo.listItemLocationLinks(itemId),
      repo.searchLocations(''),
    ]);
    return _ItemLocationViewData(
      locations: results[0] as List<StorageLocation>,
      links: results[1] as List<ItemLocation>,
      allLocations: results[2] as List<StorageLocation>,
    );
  }

  String _locationPathLabel(
    StorageLocation location,
    List<StorageLocation> allLocations,
  ) {
    final byId = {for (final loc in allLocations) loc.id: loc};
    final names = <String>[location.name];
    var cursor = location.parentId == null ? null : byId[location.parentId];
    while (cursor != null) {
      names.insert(0, cursor.name);
      cursor = cursor.parentId == null ? null : byId[cursor.parentId];
    }
    return names.join(' > ');
  }

  Future<void> _openStorageLocationPicker(Item item) async {
    final repo = context.read<StorageLocationRepo>();
    final allLocations = await repo.searchLocations('');
    final links = await repo.listItemLocationLinks(item.id);

    if (!mounted) return;
    if (allLocations.isEmpty) {
      final goSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('보관 위치가 없습니다'),
          content: const Text('설정에서 작업실, 창고, 선반 같은 보관 위치를 먼저 추가할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('위치 관리로 이동'),
            ),
          ],
        ),
      );
      if (goSettings == true && mounted) {
        await context
            .read<MainTabController>()
            .openShellRoute('/settings/storage-locations', tabIndex: 0);
      }
      return;
    }

    final originalSelectedIds = links.map((link) => link.locationId).toSet();
    final selectedIds = {...originalSelectedIds};
    String? primaryId = links
        .where((link) => link.isPrimary)
        .map((link) => link.locationId)
        .cast<String?>()
        .firstWhere((id) => id != null, orElse: () => null);
    primaryId ??= selectedIds.isEmpty ? null : selectedIds.first;

    final searchC = TextEditingController();
    var query = '';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final q = query.toLowerCase();
            final filtered = q.isEmpty
                ? allLocations
                : allLocations.where((location) {
                    final path = _locationPathLabel(location, allLocations);
                    return path.toLowerCase().contains(q) ||
                        StorageLocationType.label(location.type)
                            .toLowerCase()
                            .contains(q) ||
                        (location.memo ?? '').toLowerCase().contains(q);
                  }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.78,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '보관 위치 선택',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            child: const Text('취소'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            child: const Text('저장'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: searchC,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: '위치 검색',
                        ),
                        onChanged: (value) {
                          setSheetState(() => query = value.trim());
                        },
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final location = filtered[index];
                            final selected = selectedIds.contains(location.id);
                            final isPrimary = primaryId == location.id;
                            return CheckboxListTile(
                              value: selected,
                              secondary: Radio<String>(
                                value: location.id,
                                groupValue: primaryId,
                                onChanged: selected
                                    ? (value) {
                                        setSheetState(() => primaryId = value);
                                      }
                                    : null,
                              ),
                              title: Text(
                                _locationPathLabel(location, allLocations),
                              ),
                              subtitle: Text(isPrimary
                                  ? '기본 위치'
                                  : StorageLocationType.label(location.type)),
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selectedIds.add(location.id);
                                    primaryId ??= location.id;
                                  } else {
                                    selectedIds.remove(location.id);
                                    if (primaryId == location.id) {
                                      primaryId = selectedIds.isEmpty
                                          ? null
                                          : selectedIds.first;
                                    }
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    searchC.dispose();

    if (saved != true) return;
    await _saveItemLocationsWithMovementHistory(
      repo: repo,
      itemId: item.id,
      beforeLocationIds: originalSelectedIds,
      afterLocationIds: selectedIds,
      primaryLocationId: primaryId,
    );
    if (!mounted) return;
    setState(() => _locationMovementRevision++);
  }

  Future<void> _saveItemLocationsWithMovementHistory({
    required StorageLocationRepo repo,
    required String itemId,
    required Set<String> beforeLocationIds,
    required Set<String> afterLocationIds,
    required String? primaryLocationId,
  }) async {
    final removed = beforeLocationIds.difference(afterLocationIds).toList();
    final added = afterLocationIds.difference(beforeLocationIds).toList();
    final moveCount =
        removed.length < added.length ? removed.length : added.length;

    for (var i = 0; i < moveCount; i++) {
      await repo.moveItemLocation(
        itemId: itemId,
        fromLocationId: removed[i],
        toLocationId: added[i],
        memo: '아이템 상세에서 위치 변경',
      );
    }

    await repo.setLocationsForItem(
      itemId: itemId,
      locationIds: afterLocationIds.toList(),
      primaryLocationId: primaryLocationId,
    );
  }

  Future<void> _removeStorageLocation({
    required String itemId,
    required String locationId,
  }) async {
    final repo = context.read<StorageLocationRepo>();
    final links = await repo.listItemLocationLinks(itemId);
    final remaining = links
        .where((link) => link.locationId != locationId)
        .map((link) => link.locationId)
        .toList();
    final currentPrimary = links
        .where((link) => link.isPrimary && link.locationId != locationId)
        .map((link) => link.locationId)
        .cast<String?>()
        .firstWhere((id) => id != null, orElse: () => null);

    await repo.setLocationsForItem(
      itemId: itemId,
      locationIds: remaining,
      primaryLocationId:
          currentPrimary ?? (remaining.isEmpty ? null : remaining.first),
    );
    if (!mounted) return;
    setState(() => _locationMovementRevision++);
  }

  Future<void> _setPrimaryStorageLocation({
    required String itemId,
    required String locationId,
  }) async {
    await context.read<StorageLocationRepo>().setPrimaryLocationForItem(
          itemId: itemId,
          locationId: locationId,
        );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _editStorageLocationQty({
    required Item item,
    required StorageLocation location,
    required int currentQty,
  }) async {
    final controller = TextEditingController(text: currentQty.toString());
    final nextQty = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('위치 수량 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '${_locationPathLabel(location, const [])} 수량',
            suffixText: item.unit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(parsed == null ? null : parsed);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nextQty == null) return;
    await context.read<StorageLocationRepo>().setItemLocationQty(
          itemId: item.id,
          locationId: location.id,
          qty: nextQty,
        );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickItemImage(Item item, {ItemImage? replacing}) async {
    if (replacing == null) {
      final policy =
          await AttachmentPolicyService(context.read<AppDatabase>()).canAttach(
        domain: AttachmentDomain.itemImages,
        ownerId: item.id,
      );
      if (!policy.allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(policy.message ?? '이미지를 첨부할 수 없습니다.')),
        );
        return;
      }
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (image == null) return;

      const paths = AppPathService();
      final stored = await const AttachmentFileService().copyOptimizedImage(
        sourcePath: image.path,
        originalFileName: image.name,
        destinationDirectory: await paths.itemImageDirectory(item.id),
      );
      final storedName = p.basename(stored.filePath);
      final relativePath = paths.itemImageRelativePath(item.id, storedName);
      final repo = context.read<ItemRepo>();
      await repo.addItemImage(
        ItemImage(
          id: const Uuid().v4(),
          itemId: item.id,
          fileName: stored.fileName,
          filePath: relativePath,
          mimeType: stored.mimeType,
          createdAt: DateTime.now(),
          isPrimary: true,
        ),
      );
      if (replacing != null) {
        await repo.deleteItemImage(replacing.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 저장에 실패했습니다: $e')),
      );
    }
  }

  Future<void> _openItemImage(ItemImage image) async {
    final file = await const AppPathService().resolveAppFile(image.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 파일을 찾을 수 없습니다.')),
      );
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                image.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItemImage(ItemImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('품목 이미지 삭제'),
        content: Text('${image.fileName}을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await context.read<ItemRepo>().deleteItemImage(image.id);
  }

  Widget _buildItemImageSection(Item item) {
    return StreamBuilder<List<ItemImage>>(
      stream: context.read<ItemRepo>().watchItemImages(item.id),
      builder: (context, snapshot) {
        final images = snapshot.data ?? const <ItemImage>[];
        final primaryImage = images.isEmpty ? null : images.first;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.image_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '품목 이미지',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _pickItemImage(
                        item,
                        replacing: primaryImage,
                      ),
                      icon: Icon(primaryImage == null
                          ? Icons.add_photo_alternate_outlined
                          : Icons.swap_horiz),
                      label: Text(primaryImage == null ? '추가' : '교체'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (primaryImage == null)
                  const Text('아직 등록된 이미지가 없습니다.')
                else
                  _ItemImagePreview(
                    image: primaryImage,
                    onOpen: () => _openItemImage(primaryImage),
                    onDelete: () => _deleteItemImage(primaryImage),
                  ),
                const SizedBox(height: 8),
                Text(
                  '무료 플랜: 이미지가 있는 품목 최대 10개, 품목당 1장',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorageLocationSection(Item item) {
    return FutureBuilder<_ItemLocationViewData>(
      future: _loadItemLocationViewData(item.id),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final locations = data?.locations ?? const <StorageLocation>[];
        final links = data?.links ?? const <ItemLocation>[];
        final allLocations = data?.allLocations ?? const <StorageLocation>[];
        final primaryIds = links
            .where((link) => link.isPrimary)
            .map((link) => link.locationId)
            .toSet();
        final linkByLocationId = {
          for (final link in links) link.locationId: link,
        };
        final assignedQty = links.fold<int>(0, (sum, link) => sum + link.qty);
        final unassignedQty = item.qty - assignedQty;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '보관 위치',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openStorageLocationPicker(item),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('위치 추가'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  unassignedQty >= 0
                      ? '위치 배정 $assignedQty${item.unit} / 총 ${item.qty}${item.unit} · 미배정 $unassignedQty${item.unit}'
                      : '위치 배정 $assignedQty${item.unit} / 총 ${item.qty}${item.unit} · 초과 ${-unassignedQty}${item.unit}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: unassignedQty < 0
                            ? Theme.of(context).colorScheme.error
                            : Colors.grey.shade700,
                      ),
                ),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (locations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('아직 연결된 보관 위치가 없습니다'),
                  )
                else
                  ...locations.map((location) {
                    final isPrimary = primaryIds.contains(location.id);
                    final link = linkByLocationId[location.id];
                    final locationQty = link?.qty ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isPrimary ? Icons.star : Icons.place_outlined,
                        color: isPrimary
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(_locationPathLabel(location, allLocations)),
                      subtitle: Text(
                        [
                          if (isPrimary) '기본 위치',
                          StorageLocationType.label(location.type),
                          '수량 $locationQty${item.unit}',
                        ].join(' · '),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'qty') {
                            _editStorageLocationQty(
                              item: item,
                              location: location,
                              currentQty: locationQty,
                            );
                          } else if (value == 'primary') {
                            _setPrimaryStorageLocation(
                              itemId: item.id,
                              locationId: location.id,
                            );
                          } else if (value == 'remove') {
                            _removeStorageLocation(
                              itemId: item.id,
                              locationId: location.id,
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'qty',
                            child: ListTile(
                              leading: Icon(Icons.numbers_outlined),
                              title: Text('위치 수량 수정'),
                            ),
                          ),
                          if (!isPrimary)
                            const PopupMenuItem(
                              value: 'primary',
                              child: ListTile(
                                leading: Icon(Icons.star_outline),
                                title: Text('기본 위치로 지정'),
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: ListTile(
                              leading: Icon(Icons.remove_circle_outline),
                              title: Text('위치 제거'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ 입출고 폼 열기(일반 모드)
  void _openAdjust() {
    if (_item == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(context.t.stock_item_detail_title), // "아이템상세" 유지
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: AdjustForm(item: _item!),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ 표준: ItemRepo.adjustQty(itemId, delta, refType?, refId?, note?)
  Future<void> _applyQtyChange(
      {required int delta, required int newQty}) async {
    final itemRepo = context.read<ItemRepo>();
    await itemRepo.adjustQty(
      itemId: _item!.id,
      delta: delta,
      refType: 'MANUAL',
      note: 'Detail:setQty ${_item!.qty} → $newQty',
    );
  }

  Future<bool> _confirm(BuildContext context, String message) async {
    return (await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('확인'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false), // ✅ 변경
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true), // ✅ 변경
                child: const Text('확인'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _toggleFavorite() async {
    final it = _item;
    if (it == null) return;
    final repo = context.read<ItemRepo>();
    final next = !(it.isFavorite == true);
    await repo.setFavorite(itemId: it.id, value: next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next ? '즐겨찾기에 추가했습니다.' : '즐겨찾기 해제했습니다.')),
    );
    await _load();
  }

  Future<void> _moveThisItem() async {
    final it = _item;
    if (it == null) return;
    final folderRepo = context.read<FolderTreeRepo>();
    final dest = await showPathPicker(
      context,
      // ✅ 상세화면에서는 인라인으로 FolderNode → PathNode 매핑
      childrenProvider: (String? parentId) async {
        final folders = await folderRepo.listFolderChildren(parentId);
        return folders.map((f) => PathNode(f.id, f.name)).toList();
      },
      title: '아이템 이동..',
      maxDepth: 3,
    );
    if (dest == null || dest.isEmpty) return;
    try {
      final moved =
          await folderRepo.moveItemsToPath(itemIds: [it.id], pathIds: dest);
      final finalized =
          await context.read<ItemRepo>().tryFinalizeRegistration(it.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(finalized ? '정식등록 완료' : '아이템 $moved개 이동')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('이동 실패: $e')));
    }
  }

  Future<void> _trashThisItem() async {
    final it = _item;
    if (it == null) return;
    final ok =
        await _confirm(context, '"${it.displayName ?? it.name}"을 휴지통으로 보낼까요?');
    if (!ok) return;
    try {
      await context.read<ItemRepo>().moveItemToTrash(it.id);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('휴지통 이동됨'),
          action: SnackBarAction(
            label: '열기',
            onPressed: () =>
                context.read<MainTabController>().openShellRoute('/trash'),
          ),
        ),
      );

// 👉 그 다음 pop
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('이동 실패: $e')));
    }
  }

  void _addThisToCart() {
    final it = _item;
    if (it == null) return;

    final cart = context.read<CartManager>();
    addItemsToCart(cart, [it]);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('1개를 장바구니에 담았습니다.'),
        action: SnackBarAction(
          label: '보기',
          onPressed: () {
            context.read<MainTabController>().openShellRoute('/cart');
          },
        ),
      ),
    );
  }

  // ✅ 재고 롱프레스 : 공용 플로우로 연결 (Browser와 동일)
  Future<void> _openQtyChangeSheet() async {
    final it = _item;
    if (it == null) return;
    await runQtySetFlow(
      context,
      currentQty: it.qty,
      minQtyHint: it.minQty,
      apply: (finalDelta) =>
          StockService.applyItemQtyChange(context, it, finalDelta),
      onSuccess: () async {
        await _load(); // 상세 화면 값 리프레시
      },
      successMessage: context.t.btn_save,
      errorPrefix: context.t.common_error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.stock_item_detail_title), // "아이템상세" 유지
        actions: [
          IconButton(
            tooltip: '모든 필드 편집',
            icon: const Icon(Icons.tune),
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => StockItemFullEditScreen(itemId: _item!.id),
                ),
              );
              if (changed == true) await _load();
            },
          ),
          if (_item != null)
            IconButton(
              tooltip: (_item!.isFavorite == true) ? '즐겨찾기 해제' : '즐겨찾기',
              icon: Icon(
                  (_item!.isFavorite == true) ? Icons.star : Icons.star_border),
              onPressed: _toggleFavorite,
            ),
          if (_item != null)
            IconButton(
              tooltip: '이동',
              icon: const Icon(Icons.drive_file_move),
              onPressed: _moveThisItem,
            ),
          if (_item != null)
            IconButton(
              tooltip: '휴지통으로',
              icon: const Icon(Icons.delete_outline),
              onPressed: _trashThisItem,
            ),
        ],
      ),
      body: item == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNeedsRegistrationItem(item)) ...[
                      _buildRegistrationNotice(_registrationMissing),
                      const SizedBox(height: 12),
                    ],
                    // 아이템 라벨 (경로/이름 표시)
                    Row(
                      children: [
                        const Icon(Icons.inventory_2),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ItemLabel(
                            itemId: widget.itemId,
                            full: true,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                            separator: ' / ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildItemImageSection(item),
                    const SizedBox(height: 12),
                    if (ReorderScheduleUtils.statusFor(item).shouldShow) ...[
                      ReorderBadge(item: item),
                      const SizedBox(height: 12),
                    ],

                    // 재고 수량 / 단위
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Tooltip(
                          message: context.t.hint_longpress_to_edit_qty,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onLongPress: _openQtyChangeSheet,
                            child: Chip(
                              avatar: const Icon(Icons.numbers, size: 16),
                              label: Text(
                                  '${context.t.common_stock}: ${item.qty}'),
                            ),
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.straighten, size: 16),
                          label: Text('${context.t.item_unit}: ${item.unit}'),
                        ),
                        IconButton(
                          tooltip: '장바구니 담기',
                          icon: const Icon(Icons.add_shopping_cart),
                          onPressed: _addThisToCart,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    ItemMetaOverview(item: item),
                    const SizedBox(height: 12),
                    _buildStorageLocationSection(item),
                    const SizedBox(height: 12),
                    _ItemLocationMovementSection(
                      key: ValueKey(
                        '${item.id}-location-moves-$_locationMovementRevision',
                      ),
                      itemId: item.id,
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.download, size: 16),
                          label: Text('입고가: ${item.defaultPurchasePrice ?? 0}'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.upload, size: 16),
                          label: Text('출고가: ${item.defaultSalePrice ?? 0}'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('입출고 기록'),
                      onPressed: _showRecentTxns,
                    ),

                    // ✅ BOM 편집 버튼 (완제품/반제품)
                    if (_isFinished == true) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('BOM 편집 (완제품)'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FinishedBomEditScreen(
                                finishedItemId: widget.itemId),
                          ),
                        ),
                      ),
                    ] else if (_isFinished == false) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('BOM 편집 (반제품)'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SemiBomEditScreen(semiItemId: widget.itemId),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => BomDebug.dumpItemBomsToConsole(
                          context, widget.itemId),
                      icon: const Icon(Icons.terminal),
                      label: const Text('BOM 콘솔 출력'),
                    ),
                  ],
                ),
              ),
            ),

      // 🔧 항상 하단 바 표시(롤 모드 제거)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.remove),
                  label: const Text('출고'),
                  onPressed: (_item == null)
                      ? null
                      : () async {
                          final it = _item!;
                          final itemRepo = context.read<ItemRepo>();
                          final changed = await runStockInOutFlow(
                            context,
                            isIn: false,
                            item: it,
                            updateProfile: (
                                {required String itemId,
                                String? unitIn,
                                String? unitOut,
                                double? conversionRate}) {
                              // ← 실제 연결
                              return itemRepo.updateUnits(
                                itemId: itemId,
                                unitIn: unitIn,
                                unitOut: unitOut,
                                conversionRate: conversionRate,
                              );
                            },
                          );
                          if (changed) await _load();
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('입고'),
                  onPressed: (_item == null)
                      ? null
                      : () async {
                          final it = _item!;
                          final itemRepo = context.read<ItemRepo>(); // 반드시 꺼내기
                          final changed = await runStockInOutFlow(
                            context,
                            isIn: true,
                            item: it,
                            updateProfile: (
                                {required String itemId,
                                String? unitIn,
                                String? unitOut,
                                double? conversionRate}) {
                              return itemRepo.updateUnits(
                                itemId: itemId,
                                unitIn: unitIn,
                                unitOut: unitOut,
                                conversionRate: conversionRate,
                              );
                            },
                          );
                          if (changed) await _load();
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemLocationMovementSection extends StatefulWidget {
  final String itemId;

  const _ItemLocationMovementSection({
    super.key,
    required this.itemId,
  });

  @override
  State<_ItemLocationMovementSection> createState() =>
      _ItemLocationMovementSectionState();
}

class _ItemLocationMovementSectionState
    extends State<_ItemLocationMovementSection> {
  bool _expanded = false;
  Future<List<StorageLocationMovement>>? _future;

  void _onExpansionChanged(bool expanded) {
    setState(() {
      _expanded = expanded;
      if (expanded) {
        _future ??= context.read<StorageLocationRepo>().listLocationMovements(
              itemId: widget.itemId,
              limit: 10,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        maintainState: true,
        leading: const Icon(Icons.swap_horiz_outlined),
        title: const Text('최근 위치 이동 기록- 최대 10개'),
        onExpansionChanged: _onExpansionChanged,
        children: [
          if (!_expanded)
            const SizedBox.shrink()
          else
            FutureBuilder<List<StorageLocationMovement>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: LinearProgressIndicator(),
                  );
                }

                final movements =
                    snapshot.data ?? const <StorageLocationMovement>[];
                if (movements.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('아직 위치 이동 기록이 없습니다'),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final movement in movements)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.drive_file_move_outlined),
                        title: Text(
                          '${movement.fromLocationPath ?? '위치 미지정'} → ${movement.toLocationPath}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_dateTimeLabel(movement.movedAt)),
                      ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String _dateTimeLabel(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _ItemImagePreview extends StatelessWidget {
  final ItemImage image;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ItemImagePreview({
    required this.image,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: const AppPathService().resolveAppFile(image.filePath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  color: Colors.grey.shade100,
                  child: file == null
                      ? const SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Image.file(
                          file,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            height: 160,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    image.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('삭제'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
