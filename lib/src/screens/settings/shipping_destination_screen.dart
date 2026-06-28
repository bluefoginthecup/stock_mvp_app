import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/shipping_destination.dart';
import '../../models/suppliers.dart';
import '../../repos/repo_interfaces.dart';

class ShippingDestinationScreen extends StatefulWidget {
  const ShippingDestinationScreen({super.key});

  @override
  State<ShippingDestinationScreen> createState() =>
      _ShippingDestinationScreenState();
}

class _ShippingDestinationScreenState extends State<ShippingDestinationScreen> {
  bool _loading = true;
  List<ShippingDestination> _destinations = const [];
  Map<String, int> _defaultCounts = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<ShippingDestinationRepo>();
    setState(() => _loading = true);

    final destinations = await repo.listActiveShippingDestinations();
    final counts = <String, int>{};
    for (final destination in destinations) {
      counts[destination.id] =
          (await repo.listDefaultSuppliersForDestination(destination.id))
              .length;
    }

    if (!mounted) return;
    setState(() {
      _destinations = destinations;
      _defaultCounts = counts;
      _loading = false;
    });
  }

  Future<void> _openEditor([ShippingDestination? destination]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShippingDestinationEditorScreen(
          destination: destination,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _delete(ShippingDestination destination) async {
    final repo = context.read<ShippingDestinationRepo>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('배송지 삭제'),
        content: Text(
          '${destination.name} 배송지를 삭제할까요?\n기존 발주서에 저장된 배송지 정보는 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await repo.archiveShippingDestination(destination.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('배송지를 삭제했습니다')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('배송지 관리'),
        centerTitle: true,
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
        label: const Text('배송지'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _destinations.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.local_shipping_outlined, size: 48),
                        SizedBox(height: 12),
                        Center(child: Text('등록된 배송지가 없습니다')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemBuilder: (context, index) {
                        final destination = _destinations[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(destination.name),
                            subtitle: Text([
                              if (destination.address.trim().isNotEmpty)
                                destination.address.trim(),
                              if ((destination.phone ?? '').trim().isNotEmpty)
                                destination.phone!.trim(),
                              '기본 거래처 ${_defaultCounts[destination.id] ?? 0}개',
                            ].join(' · ')),
                            onTap: () => _openEditor(destination),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _delete(destination);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('삭제'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: _destinations.length,
                    ),
            ),
    );
  }
}

class ShippingDestinationEditorScreen extends StatefulWidget {
  final ShippingDestination? destination;

  const ShippingDestinationEditorScreen({
    super.key,
    this.destination,
  });

  @override
  State<ShippingDestinationEditorScreen> createState() =>
      _ShippingDestinationEditorScreenState();
}

class _ShippingDestinationEditorScreenState
    extends State<ShippingDestinationEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _addressC = TextEditingController();
  final _contactC = TextEditingController();
  final _phoneC = TextEditingController();
  final _memoC = TextEditingController();
  final _searchC = TextEditingController();
  final _uuid = const Uuid();

  late final String _destinationId;
  bool _loading = true;
  bool _saving = false;
  List<Supplier> _suppliers = const [];
  Set<String> _selectedSupplierIds = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    final destination = widget.destination;
    _destinationId = destination?.id ?? _uuid.v4();
    if (destination != null) {
      _nameC.text = destination.name;
      _addressC.text = destination.address;
      _contactC.text = destination.contactName ?? '';
      _phoneC.text = destination.phone ?? '';
      _memoC.text = destination.memo ?? '';
    }
    _searchC.addListener(() {
      setState(() => _query = _searchC.text.trim());
    });
    _load();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _addressC.dispose();
    _contactC.dispose();
    _phoneC.dispose();
    _memoC.dispose();
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final supplierRepo = context.read<SupplierRepo>();
    final destinationRepo = context.read<ShippingDestinationRepo>();

    final suppliers = await supplierRepo.list(onlyActive: true);
    final selected = widget.destination == null
        ? <Supplier>[]
        : await destinationRepo
            .listDefaultSuppliersForDestination(widget.destination!.id);

    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _selectedSupplierIds = selected.map((supplier) => supplier.id).toSet();
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    final repo = context.read<ShippingDestinationRepo>();
    final now = DateTime.now();
    final existing = widget.destination;
    final destination = ShippingDestination(
      id: _destinationId,
      name: _nameC.text.trim(),
      address: _addressC.text.trim(),
      contactName: _nullIfBlank(_contactC.text),
      phone: _nullIfBlank(_phoneC.text),
      memo: _nullIfBlank(_memoC.text),
      mapImagePath: existing?.mapImagePath,
      isArchived: false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() => _saving = true);
    try {
      if (existing == null) {
        await repo.createShippingDestination(destination);
      } else {
        await repo.updateShippingDestination(destination);
      }
      await repo.setDefaultDestinationForSuppliers(
        destinationId: destination.id,
        supplierIds: _selectedSupplierIds,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('배송지를 저장하지 못했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<Supplier> get _filteredSuppliers {
    if (_query.isEmpty) return _suppliers;
    final lower = _query.toLowerCase();
    return _suppliers.where((supplier) {
      return supplier.name.toLowerCase().contains(lower) ||
          (supplier.contactName ?? '').toLowerCase().contains(lower) ||
          (supplier.phone ?? '').toLowerCase().contains(lower);
    }).toList();
  }

  void _toggleSupplier(String supplierId, bool selected) {
    setState(() {
      if (selected) {
        _selectedSupplierIds.add(supplierId);
      } else {
        _selectedSupplierIds.remove(supplierId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.destination != null;
    final filteredSuppliers = _filteredSuppliers;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '배송지 수정' : '배송지 등록'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '저장',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  Text(
                    '배송지 기본 정보',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameC,
                    decoration: const InputDecoration(labelText: '배송지명 *'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? '배송지명을 입력하세요'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressC,
                    decoration: const InputDecoration(labelText: '주소'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactC,
                    decoration: const InputDecoration(labelText: '담당자'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneC,
                    decoration: const InputDecoration(labelText: '연락처'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _memoC,
                    decoration: const InputDecoration(labelText: '메모'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '이 배송지를 기본으로 사용하는 거래처',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text('${_selectedSupplierIds.length}개 선택'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchC,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '거래처 검색',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedSupplierIds.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final supplier in _suppliers.where(
                          (supplier) =>
                              _selectedSupplierIds.contains(supplier.id),
                        ))
                          InputChip(
                            label: Text(supplier.name),
                            onDeleted: () =>
                                _toggleSupplier(supplier.id, false),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  if (filteredSuppliers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('표시할 거래처가 없습니다'),
                    )
                  else
                    ...filteredSuppliers.map((supplier) {
                      final selected =
                          _selectedSupplierIds.contains(supplier.id);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        title: Text(supplier.name),
                        subtitle: Text([
                          if ((supplier.contactName ?? '').trim().isNotEmpty)
                            '담당 ${supplier.contactName!.trim()}',
                          if ((supplier.phone ?? '').trim().isNotEmpty)
                            supplier.phone!.trim(),
                        ].join(' · ')),
                        onChanged: (value) =>
                            _toggleSupplier(supplier.id, value == true),
                      );
                    }),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? '저장 중...' : '저장'),
                  ),
                ],
              ),
            ),
    );
  }
}
