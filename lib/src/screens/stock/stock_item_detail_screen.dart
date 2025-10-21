// lib/src/screens/stock/stock_item_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/ui.dart';
import '../../utils/item_presentation.dart'; // ItemLabel
import '../bom/finished_bom_edit_screen.dart';
import '../bom/semi_bom_edit_screen.dart';

class StockItemDetailScreen extends StatefulWidget {
  final String itemId;
  const StockItemDetailScreen({super.key, required this.itemId});

  @override
  State<StockItemDetailScreen> createState() => _StockItemDetailScreenState();
}

class _StockItemDetailScreenState extends State<StockItemDetailScreen> {
  Item? _item;
  String? _name; // 사람 읽는 이름 (repo.nameOf)
  bool? _isFinished; // finished/semi 추정

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final itemRepo = context.read<ItemRepo>();
    final item = await itemRepo.getItem(widget.itemId);
    final name = await itemRepo.nameOf(widget.itemId);

    bool? finishedGuess;
    // 레거시 폴더 체계로 finished/semi 추정 (없으면 null)
    if (item != null) {
      final segs = <String>[
        item.folder,
        if (item.subfolder != null) item.subfolder!,
        if (item.subsubfolder != null) item.subsubfolder!,
      ].map((e) => e.toLowerCase());
      final joined = segs.join('/');
      if (joined.contains('finished') || joined.contains('완제품')) finishedGuess = true;
      else if (joined.contains('semi') || joined.contains('반제품') || joined.contains('세미')) finishedGuess = false;
    }

    if (!mounted) return;
    setState(() {
      _item = item;
      _name = name ?? item?.name ?? widget.itemId;
      _isFinished = finishedGuess; // null이면 두 버튼 다 보여줌
    });
  }

  Future<void> _showRecentTxns() async {
    // 간이: TxnRepo.listTxns() → itemId로 필터 → 하단 모달에 표시
    try {
      final txnRepo = context.read<TxnRepo>();
      final List<dynamic> all = await txnRepo.listTxns(); // 타입을 dynamic으로 받아서 안전하게 접근
      final filtered = all.where((t) {
        try { return t.itemId == widget.itemId; } catch (_) { return false; }
      }).toList();

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
            itemBuilder: (_, i) {
              final t = filtered[i];
              // 안전 접근 (필드 이름 프로젝트별로 다를 수 있어 최소 표시 보장)
              String line1;
              try {
                final qty = t.qty as int?;
                final refType = t.refType?.toString();
                final refId = t.refId?.toString();
                line1 = '±${qty ?? 0} • ${refType ?? '-'} • ${refId ?? ''}'.trim();
              } catch (_) {
                line1 = t.toString();
              }
              String line2;
              try {
                // 흔히 쓰는 타임스탬프 후보들
                final ts = (t.createdAt ?? t.ts ?? t.time) as DateTime?;
                line2 = ts != null ? ts.toIso8601String() : '';
              } catch (_) {
                line2 = '';
              }
              return ListTile(
                leading: const Icon(Icons.swap_vert),
                title: Text(line1),
                subtitle: line2.isEmpty ? null : Text(line2),
              );
            },
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

  @override
  Widget build(BuildContext context) {
    final item = _item;

    return Scaffold(
      appBar: AppBar(title: Text(context.t.stock_item_detail_title)),
      body: item == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
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
                    style: Theme.of(context).textTheme.titleMedium,
                    separator: ' / ',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 재고 수량 / 단위
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.numbers, size: 16),
                  label: Text('${context.t.common_stock}: ${item.qty}'),
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: const Icon(Icons.straighten, size: 16),
                  label: Text('${context.t.item_unit}: ${item.unit}'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 최근 입출고 내역 버튼
            FilledButton.tonalIcon(
              onPressed: _showRecentTxns,
              icon: const Icon(Icons.history),
              label: Text(context.t.txn_recent_button), // 예: "최근 입출고 내역"
            ),

            const SizedBox(height: 24),
            Text(context.t.bom_edit_section_title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            if (_isFinished == true) ...[
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FinishedBomEditScreen(finishedItemId: widget.itemId),
                    ),
                  );
                },
                icon: const Icon(Icons.account_tree),
                label: Text(context.t.bom_edit_finished),
              ),
            ] else if (_isFinished == false) ...[
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SemiBomEditScreen(semiItemId: widget.itemId),
                    ),
                  );
                },
                icon: const Icon(Icons.account_tree_outlined),
                label: Text(context.t.bom_edit_semi),
              ),
            ] else ...[
              // 구분 불가 → 둘 다 제공
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FinishedBomEditScreen(finishedItemId: widget.itemId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.account_tree),
                    label: Text(context.t.bom_edit_finished),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SemiBomEditScreen(semiItemId: widget.itemId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.account_tree_outlined),
                    label: Text(context.t.bom_edit_semi),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.t.bom_edit_unknown_type_hint, // 예: '유형을 확정할 수 없어 두 버튼을 모두 표시합니다.'
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
