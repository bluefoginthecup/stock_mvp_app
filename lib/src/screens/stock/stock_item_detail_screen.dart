// lib/src/screens/stock/stock_item_detail_screen.dart
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';

import '../../ui/common/ui.dart';
import '../../utils/item_presentation.dart';   // ItemLabel

import '../bom/finished_bom_edit_screen.dart';
import '../bom/semi_bom_edit_screen.dart';

import '../txns/adjust_form.dart';
import '../../models/txn.dart' show Txn;
import '../txns/widgets/txn_row.dart';
import 'stock_item_edit_sheet.dart';
import 'stock_item_full_edit_screen.dart';
import 'widgets/item_meta_overview.dart';
import '../../ui/common/qty_set_sheet.dart';
import '../../utils/unit_converter.dart';
import '../../ui/common/inout_flow.dart';
import '../../ui/common/path_picker.dart';

import '../../dev/bom_debug.dart';             // 콘솔 덤프 유틸
import '../../providers/cart_manager.dart';
import '../../ui/common/cart_add.dart';
import '../../services/stock_service.dart';


class StockItemDetailScreen extends StatefulWidget {
  final String itemId;
  const StockItemDetailScreen({super.key, required this.itemId});

  @override
  State<StockItemDetailScreen> createState() => _StockItemDetailScreenState();
}

class _StockItemDetailScreenState extends State<StockItemDetailScreen> {
  Item? _item; // 사람 읽는 이름 (repo.nameOf)
  bool? _isFinished; // finished/semi 추정

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final itemRepo = context.read<ItemRepo>();
    final item = await itemRepo.getItem(widget.itemId);

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
      } else if (joined.contains('semi') || joined.contains('반제품') ||
          joined.contains('세미')) {
        finishedGuess = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _item = item;
      _isFinished = finishedGuess;
    });
  }

  Future<void> _showRecentTxns() async {
    try {
      final txnRepo = context.read<TxnRepo>();
      final all = await txnRepo.listTxns();
      final List<Txn> filtered = all
          .cast<Txn>()
          .where((t) => t.itemId == widget.itemId)
          .toList();
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

  // ✅ 입출고 폼 열기(일반 모드)
  void _openAdjust() {
    if (_item == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            Scaffold(
              appBar: AppBar(
                title: Text(context.t.stock_item_detail_title), // "아이템상세" 유지
              ),
              body: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery
                        .of(context)
                        .viewInsets
                        .bottom,
                    left: 16, right: 16, top: 16,
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
      builder: (_) =>
          AlertDialog(
            title: const Text('확인'),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소')),
              FilledButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('확인')),
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
        final moved = await folderRepo.moveItemsToPath(
            itemIds: [it.id], pathIds: dest);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('아이템 $moved개 이동')),
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이동 실패: $e')));
      }
    }

    Future<void> _trashThisItem() async {
      final it = _item;
      if (it == null) return;
      final ok = await _confirm(
          context, '"${it.displayName ?? it.name}"을 휴지통으로 보낼까요?');
      if (!ok) return;
      try {
        await context.read<ItemRepo>().moveItemToTrash(it.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${it.displayName ?? it.name}"을 휴지통으로 이동했습니다.'),
            action: SnackBarAction(
              label: '휴지통 열기',
              onPressed: () => Navigator.of(context).pushNamed('/trash'),
            ),
          ),
        );
        Navigator.of(context).pop(); // 상세 닫기
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이동 실패: $e')));
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
            Navigator.of(context, rootNavigator: true).pushNamed('/cart');
          },
        ),
      ),
    );
  }


  // ✅ 재고 롱프레스 : 공용 플로우로 연결 (Browser와 동일)
    Future<void> _openQtyChangeSheet() async {
      final it = _item;
      if (it == null) return;
      final itemRepo = context.read<ItemRepo>();
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
            if (_item != null)
              IconButton(
                tooltip: '간단 편집',
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final changed = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => StockItemEditSheet(itemId: _item!.id),
                  );
                  if (changed == true) {
                    await _load(); // 저장 성공 시에만 리프레시
                  }
                },
              ),
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
                icon: Icon((_item!.isFavorite == true) ? Icons.star : Icons
                    .star_border),
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
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleMedium,
                        separator: ' / ',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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
                          label: Text('${context.t.common_stock}: ${item.qty}'),
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
                    onPressed: () =>
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                FinishedBomEditScreen(
                                    finishedItemId: widget.itemId),
                          ),
                        ),
                  ),
                ] else
                  if (_isFinished == false) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('BOM 편집 (반제품)'),
                      onPressed: () =>
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SemiBomEditScreen(semiItemId: widget.itemId),
                            ),
                          ),
                    ),
                  ],

                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      BomDebug.dumpItemBomsToConsole(context, widget.itemId),
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
                            {required String itemId, String? unitIn, String? unitOut, double? conversionRate}) {
                          // ← 실제 연결
                          return itemRepo.updateUnits(itemId: itemId,
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
                            {required String itemId, String? unitIn, String? unitOut, double? conversionRate}) {
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