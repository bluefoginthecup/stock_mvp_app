import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repos/repo_interfaces.dart'; // TrashRepo
import '../../models/trash_entry.dart';
import '../../ui/common/multi_select_bar.dart';
import '../../screens/stock/widgets/item_selection_controller.dart';


class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  String _q = '';

  Future<List<TrashEntry>> _load(BuildContext context) async {
    final trash = context.read<TrashRepo>();
    final all = await trash.listTrash();
    if (_q.isEmpty) return all;

    final q = _q.toLowerCase();
    return all
        .where((e) =>
    e.title.toLowerCase().contains(q) ||
        e.id.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _restore(BuildContext ctx, TrashEntry e) async {
    await ctx.read<TrashRepo>().restore(e.entityType, e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(ctx)
        .showSnackBar(const SnackBar(content: Text('복구되었습니다')));
    setState(() {});
  }

  Future<void> _hardDelete(BuildContext ctx, TrashEntry e) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('완전 삭제'),
        content: const Text('되돌릴 수 없습니다. 계속할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('삭제')),
        ],
      ),
    );

    if (ok != true) return;

    await ctx.read<TrashRepo>().hardDelete(e.entityType, e.id);

    if (!mounted) return;
    ScaffoldMessenger.of(ctx)
        .showSnackBar(const SnackBar(content: Text('완전 삭제되었습니다')));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ItemSelectionController(),
      child: Builder(
        builder: (context) {
          final sel = context.watch<ItemSelectionController>();

          return Scaffold(
            appBar: AppBar(
              title: const Text('통합 휴지통'),

            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      // ✅ 멀티 선택 버튼
                      IconButton(
                        icon: Icon(
                          sel.selectionMode ? Icons.close : Icons.checklist,
                        ),
                        tooltip: sel.selectionMode ? '선택 해제' : '멀티 선택',
                        onPressed: () {
                          if (sel.selectionMode) {
                            sel.exit();
                          } else {
                            sel.enter();
                          }
                        },
                      ),

                      const SizedBox(width: 4),

                      // ✅ 검색창
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: '제목/ID 검색',
                          ),
                          onChanged: (v) => setState(() => _q = v.trim()),
                        ),
                      ),
                    ],
                  ),
                ),

                /// 리스트
                Expanded(
                  child: FutureBuilder<List<TrashEntry>>(
                    future: _load(context),
                    builder: (ctx, snap) {
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final items = snap.data ?? [];

                      if (items.isEmpty) {
                        return const Center(
                            child: Text('삭제된 항목이 없습니다.'));
                      }

                      final keys = items
                          .map((e) => '${e.entityType}_${e.id}')
                          .toList();

                      return Stack(
                        children: [
                          ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final e = items[i];
                              final key =
                                  '${e.entityType}_${e.id}';

                              final deletedAtStr = e.deletedAt
                                  .toIso8601String()
                                  .substring(0, 19)
                                  .replaceFirst('T', ' ');

                              return ListTile(
                                onTap: () {
                                  if (sel.selectionMode) {
                                    sel.toggle(key);
                                    print('현재 선택된 것: ${sel.selected}');
                                  }
                                },

                                leading: sel.selectionMode
                                    ? Checkbox(
                                  value: sel.selected
                                      .contains(key),
                                  onChanged: (_) {
                                    sel.toggle(key);

                                    // 🔥 추가
                                    print('현재 선택된 것: ${sel.selected}');
                                  },
                                )
                                    : Icon(
                                    _iconFor(e.entityType)),
                                title: Text(e.title),
                                subtitle: Text(
                                    '${_labelFor(e.entityType)} • ${e.id} • $deletedAtStr'),
                                trailing:
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'restore')
                                      _restore(context, e);
                                    if (v == 'hard')
                                      _hardDelete(context, e);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'restore',
                                        child: Text('복구')),
                                    PopupMenuItem(
                                        value: 'hard',
                                        child: Text('완전 삭제')),
                                  ],
                                ),
                              );
                            },
                          ),

                          /// 하단 멀티 선택 바
                          if (sel.selectionMode)
                            Align(
                              alignment:
                              Alignment.bottomCenter,
                              child: _buildTrashMultiBar(
                                  context, sel, items),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 아이콘
  IconData _iconFor(String t) {
    switch (t) {
      case 'item':
        return Icons.inventory_2_outlined;
      case 'order':
        return Icons.receipt_long_outlined;
      case 'txn':
        return Icons.swap_vert;
      case 'work':
        return Icons.handyman_outlined;
      case 'po':
        return Icons.assignment_turned_in_outlined;
      default:
        return Icons.delete_outline;
    }
  }

  /// 라벨
  String _labelFor(String t) {
    switch (t) {
      case 'item':
        return '아이템';
      case 'order':
        return '주문';
      case 'txn':
        return '입출고';
      case 'work':
        return '작업';
      case 'po':
        return '발주';
      default:
        return t;
    }
  }

  /// 멀티 선택 바
  Widget _buildTrashMultiBar(
      BuildContext context,
      ItemSelectionController sel,
      List<TrashEntry> items,
      ) {
    final keys = items
        .map((e) => '${e.entityType}_${e.id}')
        .toList();

    final map = {
      for (var e in items)
        '${e.entityType}_${e.id}': e
    };
    return CommonMultiSelectBar(


     selectedCount: sel.selected.length,
     totalCount: keys.length,

      /// ✅ 전체 선택 토글
      onSelectAll: () {
        final isAllSelected =
            sel.selected.length == keys.length && keys.isNotEmpty;

        if (isAllSelected) {
          sel.clear(); // ✅ 선택만 해제 (모드 유지)
        } else {
          sel.selectAll(keys);
        }
      },

      actions: [
        /// 🔄 복구
        MultiSelectAction(
          icon: Icons.restore,
          tooltip: '복구',
          onPressed: () async {
            final repo = context.read<TrashRepo>();

     final futures = sel.selected.map((key) {
       final e = map[key];
       if (e == null) return Future.value();
       return repo.restore(e.entityType, e.id);
     });

            await Future.wait(futures);

            sel.exit();        // 선택모드 종료
            setState(() {});   // 🔥 이거 추가 (핵심)

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('복구 완료')),
            );


          },
        ),

        /// 🗑 완전 삭제
        MultiSelectAction(
          icon: Icons.delete_forever,
          tooltip: '완전 삭제',
          color: Colors.red,
          onPressed: () async {


            final ok = await showDialog<bool>(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                title: const Text('완전 삭제'),
                content: Text('선택한 ${sel.selected.length}개를 삭제합니다.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      child: const Text('삭제')),
                ],
              ),
            );

            if (ok != true) return;

            final repo = context.read<TrashRepo>();

     final futures = sel.selected.map((key) {
       final e = map[key];
       if (e == null) return Future.value();


       print('삭제 시도: ${e.entityType} / ${e.id}');
       return repo.hardDelete(e.entityType, e.id);
     });

            await Future.wait(futures);


            sel.exit();       // 모드 종료
            setState(() {});  // 목록 새로고침

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('완전 삭제 완료')),
            );

          },
        ),
      ],
    );
  }
}