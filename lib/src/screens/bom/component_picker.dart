// lib/src/screens/bom/component_picker.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../models/bom.dart';
import '../../repos/repo_interfaces.dart';
import '../../utils/item_presentation.dart'; // ItemLabel

/// BOM 구성품 선택 다이얼로그.
/// 선택 시 itemId(String)를 pop으로 반환한다.
class ComponentPicker extends StatefulWidget {
  /// 이 피커가 호출된 BOM의 루트 (finished에서 호출되면 semi/raw/sub만 허용)
  final BomRoot root;
  final String initialQuery;

  const ComponentPicker({
    super.key,
    required this.root,
    this.initialQuery = '',
  });

  @override
  State<ComponentPicker> createState() => _ComponentPickerState();
}

class _ComponentPickerState extends State<ComponentPicker> {
  final _searchC = TextEditingController();
  bool _loading = true;
  bool _searching = false;

  /// 'ALL' | 'SemiFinished' | 'Raw' | 'Sub'
  String _activeL1 = 'ALL';

  List<Item> _items = const [];
  List<Item> _results = const [];

  @override
  void initState() {
    super.initState();
    _searchC.text = widget.initialQuery;
    _activeL1 = _defaultL1For(widget.root);
    _loadInitial();
  }

  String _defaultL1For(BomRoot root) {
    switch (root) {
      case BomRoot.finished:
        return 'ALL'; // 세 가지 모두
      case BomRoot.semi:
        return 'Raw'; // 기본 Raw에서 시작(원하는 경우 탭으로 전환)
      case BomRoot.raw:
      case BomRoot.sub:
        return 'ALL';
    }
  }

  List<String> _allowedL1(BomRoot root) {
    switch (root) {
      case BomRoot.finished:
        return const ['SemiFinished', 'Raw', 'Sub'];
      case BomRoot.semi:
        return const ['Raw', 'Sub'];
      case BomRoot.raw:
      case BomRoot.sub:
        return const <String>[];
    }
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    final repo = context.read<ItemRepo>();

    // 허용 루트들에서 모두 모아서 병합
    final allowed = _allowedL1(widget.root);
    final List<Item> acc = [];
    for (final l1 in allowed) {
      final ids = await repo.pathIdsByNames(l1Name: l1, createIfMissing: true);
      final items = await repo.listItemsByFolderPath(
        l1: ids[0], // l1 folderId
        recursive: true,
      );
      acc.addAll(items);
    }
    // 중복 제거
    final map = {for (final it in acc) it.id: it};
    _items = map.values.toList();

    _applyFilters();
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilters() {
    final q = _searchC.text.trim().toLowerCase();
    final active = _activeL1;

    Iterable<Item> list = _items;

    // L1 칩 필터 (ALL이면 생략) — _items 자체가 이미 허용 L1로 제한된 상태라 noop
    if (active != 'ALL') {
      list = list.where((_) => true);
    }

    // 키워드(이름/sku) 필터
    if (q.isNotEmpty) {
      list = list.where((it) {
        final name = (it.name ?? '').toLowerCase();
        final sku = (it.sku ?? '').toLowerCase();
        return name.contains(q) || sku.contains(q);
      });
    }

    _results = list.toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
  }

  Future<void> _onSearchChanged() async {
    setState(() => _searching = true);
    _applyFilters();
    setState(() => _searching = false);
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowedL1(widget.root);

    return AlertDialog(
      title: const Text('구성품 선택'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 L1 필터 칩 (허용되는 루트만 표시)
            if (allowed.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('전체'),
                    selected: _activeL1 == 'ALL',
                    onSelected: (_) => setState(() {
                      _activeL1 = 'ALL';
                      _applyFilters();
                    }),
                  ),
                  for (final l1 in allowed)
                    ChoiceChip(
                      label: Text(l1),
                      selected: _activeL1 == l1,
                      onSelected: (_) => setState(() {
                        _activeL1 = l1;
                        _applyFilters();
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 12),

            // 검색창
            TextField(
              controller: _searchC,
              decoration: const InputDecoration(
                hintText: '이름 또는 SKU로 검색',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => _onSearchChanged(),
            ),
            const SizedBox(height: 8),

            if (_loading) const LinearProgressIndicator(),
            if (!_loading && _searching) const LinearProgressIndicator(),
            const SizedBox(height: 8),

            // 결과 리스트
            Flexible(
              child: _results.isEmpty
                  ? const Center(child: Text('선택 가능한 항목이 없습니다.'))
                  : ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final it = _results[i];
                  return ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: ItemLabel(itemId: it.id, full: true),
                    subtitle: Text('SKU: ${it.sku ?? '-'}'),
                    trailing: FilledButton(
                      onPressed: () => Navigator.pop(context, it.id),
                      child: const Text('선택'),
                    ),
                    onTap: () => Navigator.pop(context, it.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }
}
