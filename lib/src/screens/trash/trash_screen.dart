import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repos/repo_interfaces.dart'; // TrashRepo, TrashEntry
import '../../models/trash_entry.dart';

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
    return all.where((e) => e.title.toLowerCase().contains(q) || e.id.toLowerCase().contains(q)).toList();
  }

  Future<void> _restore(BuildContext ctx, TrashEntry e) async {
    await ctx.read<TrashRepo>().restore(e.entityType, e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('복구되었습니다')));
    setState(() {}); // 목록 새로고침
  }

  Future<void> _hardDelete(BuildContext ctx, TrashEntry e) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('완전 삭제'),
        content: const Text('되돌릴 수 없습니다. 계속할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    await ctx.read<TrashRepo>().hardDelete(e.entityType, e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('완전 삭제되었습니다')));
    setState(() {}); // 목록 새로고침
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('통합 휴지통')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '제목/ID 검색',
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<TrashEntry>>(
              future: _load(context),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? const <TrashEntry>[];
                if (items.isEmpty) {
                  return const Center(child: Text('삭제된 항목이 없습니다.'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    final deletedAtStr = e.deletedAt.toIso8601String().substring(0, 19).replaceFirst('T', ' ');
                    return ListTile(
                      leading: Icon(_iconFor(e.entityType)),
                      title: Text(e.title),
                      subtitle: Text('${_labelFor(e.entityType)} • ${e.id} • $deletedAtStr'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'restore') _restore(context, e);
                          if (v == 'hard') _hardDelete(context, e);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'restore', child: Text('복구')),
                          PopupMenuItem(value: 'hard', child: Text('완전 삭제')),
                        ],
                        icon: const Icon(Icons.more_vert),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'item': return Icons.inventory_2_outlined;
      case 'order': return Icons.receipt_long_outlined;
      case 'txn': return Icons.swap_vert;
      case 'work': return Icons.handyman_outlined;
      case 'po': return Icons.assignment_turned_in_outlined;
      default: return Icons.delete_outline;
    }
  }

  String _labelFor(String t) {
    switch (t) {
      case 'item': return '아이템';
      case 'order': return '주문';
      case 'txn': return '입출고';
      case 'work': return '작업';
      case 'po': return '발주';
      default: return t;
    }
  }
}
