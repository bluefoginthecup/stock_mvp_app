// lib/src/screens/bom/component_picker.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../models/bom.dart';
import '../../repos/inmem_repo.dart';        // ✅ InMemoryRepo 직접 사용
import '../../utils/item_presentation.dart'; // ItemLabel

/// BOM 구성품 선택 다이얼로그.
/// 선택 시 itemId(String)를 pop으로 반환한다.
class ComponentPicker extends StatefulWidget {
  final BomRoot root;         // finished OR semi
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
        return 'Raw'; // 기본 Raw에서 시작
    }
  }

  List<String> _allowedL1(BomRoot root) {
    switch (root) {
      case BomRoot.finished:
        return const ['SemiFinished', 'Raw', 'Sub'];
      case BomRoot.semi:
        return const ['Raw', 'Sub'];
    }
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);

    // ✅ InMemoryRepo 직접 사용 (listItemsByFolderPath, pathIdsByNames 활용)
    final repo = context.read<InMemoryRepo>();
    final allowed = _allowedL1(widget.root);

    final List<Item> acc = [];
    for (final l1Name in allowed) {
      // 이름 -> id들
      final ids = await repo.pathIdsByNames(
        l1Name: l1Name,
        createIfMissing: true, // 존재 안 하면 만들어줌 (시드 환경에서도 안전)
      );
      // L1 전체 재귀 조회
      final items = await repo.listItemsByFolderPath(
        l1: ids[0],
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

    // 활성 L1 필터 (ALL이면 패스)
    if (active != 'ALL') {
      // 간단하게 이름 문자열 포함으로 1차 필터 (repo 저장 방식에 따라 향후 보강 가능)
      list = list.where((it) {
        // ItemLabel은 id만 필요하지만, 여기선 속성으로 걸러야 하므로
        // 이름/sku 문자열로 대충 1차 필터
        final name = (it.name ?? '');
        return name.contains(active); // 예: "Raw", "Sub" 등이 이름경로에 포함되도록 시드 구성 권장
      });
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
            if (allowed.isNotEmpty)
              Wrap(
                spacing: 8, runSpacing: 8,
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

            Flexible(
              child: _results.isEmpty
                  ? const Center(child: Text('선택 가능한 항목이 없습니다.'))
                  : ListView.separated(
                shrinkWrap: true,
    itemCount: _results.length,
    separatorBuilder: (_, __) => const Divider(height: 1),
    itemBuilder: (context, i) {
    final it = _results[i];
    return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    children: [
    const Icon(Icons.inventory_2, size: 20),
    const SizedBox(width: 8),
    Expanded(child: ItemLabel(itemId: it.id, full: false)),
    ],
    ),
    const SizedBox(height: 4),
    Text('SKU: ${it.sku ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
    const SizedBox(height: 6),
    Align(
    alignment: Alignment.centerRight,
    child: FilledButton(
    onPressed: () => Navigator.pop(context, it.id),
    child: const Text('선택'),
    ),
    ),
    ],
    ),
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
