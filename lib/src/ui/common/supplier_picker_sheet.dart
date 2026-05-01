import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/suppliers.dart';
import '../../repos/repo_interfaces.dart';
import '../../screens/suppliers/supplier_form_screen.dart';

Future<Supplier?> showSupplierPickerSheet(
  BuildContext context, {
  String? initialQuery,
  String title = '거래처 선택',
}) {
  return showModalBottomSheet<Supplier>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SupplierPickerSheet(
      initialQuery: initialQuery,
      title: title,
    ),
  );
}

class _SupplierPickerSheet extends StatefulWidget {
  final String? initialQuery;
  final String title;

  const _SupplierPickerSheet({
    required this.initialQuery,
    required this.title,
  });

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  late final TextEditingController _searchC;
  bool _loading = true;
  List<Supplier> _results = const [];

  @override
  void initState() {
    super.initState();
    _searchC = TextEditingController(text: widget.initialQuery ?? '');
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<SupplierRepo>();
    final q = _searchC.text.trim();
    final results = await repo.list(q: q.isEmpty ? null : q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _createSupplier() async {
    final supplier = await Navigator.of(context).push<Supplier>(
      MaterialPageRoute(
        builder: (_) => SupplierFormScreen(
          initialName: _searchC.text.trim(),
        ),
      ),
    );

    if (!mounted || supplier == null) return;
    Navigator.pop(context, supplier);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchC,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '거래처명/담당자/전화 검색',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _load(),
            ),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Flexible(
              child: SizedBox(
                height: 320,
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _loading ? '불러오는 중...' : '검색 결과가 없습니다',
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _results[i];
                          final subtitle = [
                            if ((s.contactName ?? '').isNotEmpty)
                              '담당: ${s.contactName}',
                            if ((s.phone ?? '').isNotEmpty) '전화: ${s.phone}',
                          ].join(' · ');

                          return ListTile(
                            leading: const Icon(Icons.business),
                            title: Text(s.name),
                            subtitle:
                                subtitle.isEmpty ? null : Text(subtitle),
                            onTap: () => Navigator.pop(context, s),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('신규 거래처 등록'),
                onPressed: _createSupplier,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
