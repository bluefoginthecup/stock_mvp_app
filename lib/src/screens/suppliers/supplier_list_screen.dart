import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/suppliers.dart';
import '../../repos/repo_interfaces.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _searchC = TextEditingController();
  Timer? _debounce;
  bool _showInactive = false;
  bool _loading = true;
  List<Supplier> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchC.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _load);
  }

  Future<void> _load() async {
    final repo = context.read<SupplierRepo>();
    setState(() => _loading = true);
    final list = await repo.list(
      q: _searchC.text.trim().isEmpty ? null : _searchC.text.trim(),
      onlyActive: !_showInactive,
    );
    if (!mounted) return;
    setState(() {
      _suppliers = list;
      _loading = false;
    });
  }

  Future<void> _toggleActive(Supplier s) async {
    final repo = context.read<SupplierRepo>();
    await repo.toggleActive(s.id, !s.isActive);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${s.name} ${s.isActive ? "비활성화" : "활성화"}됨')),
    );
  }

  Future<void> _softDelete(Supplier s) async {
    final repo = context.read<SupplierRepo>();
    await repo.softDelete(s.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${s.name} 비활성 처리됨')),
    );
  }

  Future<void> _openNew() async {
    await Navigator.of(context, rootNavigator: true).pushNamed('/suppliers/new');
    if (!mounted) return;
    _load();
  }

  Future<void> _openEdit(String id) async {
    await Navigator.of(context, rootNavigator: true)
        .pushNamed('/suppliers/edit', arguments: id);
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래처 목록'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('신규'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchC,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '거래처명/담당자/전화 검색',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('비활성 포함해서 보기'),
            value: _showInactive,
            onChanged: (v) {
              setState(() => _showInactive = v);
              _load();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 88, top: 8),
                itemCount: _suppliers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = _suppliers[i];
                  return ListTile(
                    leading: Icon(
                      s.isActive ? Icons.business : Icons.business,

                    ),
                    title: Text(s.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: s.isActive ? null : Colors.grey,
                        )),
                    subtitle: _buildSubtitle(s),
                    onTap: () => _openEdit(s.id),
                    trailing: PopupMenuButton<String>(
                      onSelected: (key) {
                        switch (key) {
                          case 'edit':
                            _openEdit(s.id);
                            break;
                          case 'toggle':
                            _toggleActive(s);
                            break;
                          case 'delete':
                            _softDelete(s);
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('수정'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: ListTile(
                            leading: Icon(
                                s.isActive ? Icons.visibility_off : Icons.visibility),
                            title: Text(s.isActive ? '비활성화' : '활성화'),
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('비활성 처리'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(Supplier s) {
    final parts = <String>[];
    if ((s.contactName ?? '').isNotEmpty) parts.add('담당: ${s.contactName}');
    if ((s.phone ?? '').isNotEmpty) parts.add('전화: ${s.phone}');
    if ((s.email ?? '').isNotEmpty) parts.add('메일: ${s.email}');
    return parts.isEmpty ? const SizedBox.shrink() : Text(parts.join(' · '));
  }
}
