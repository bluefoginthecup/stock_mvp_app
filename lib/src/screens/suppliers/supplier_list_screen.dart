import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/suppliers.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/supplier_picker_sheet.dart';

enum _SupplierRoleTab { purchase, customer, unclassified }

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _searchController = TextEditingController();
  final _selectedIds = <String>{};
  Timer? _debounce;
  bool _showInactive = false;
  bool _loading = true;
  bool _selectionMode = false;
  int? _selectionAnchorIndex;
  double? _dragStartY;
  int? _dragStartIndex;
  int? _dragLastIndex;
  bool _dragSelectValue = true;
  _SupplierRoleTab _tab = _SupplierRoleTab.purchase;
  List<Supplier> _allSuppliers = const [];

  List<Supplier> get _visibleSuppliers => _allSuppliers.where((supplier) {
        return switch (_tab) {
          _SupplierRoleTab.purchase => supplier.isPurchaseSupplier,
          _SupplierRoleTab.customer => supplier.isCustomer,
          _SupplierRoleTab.unclassified =>
            !supplier.isPurchaseSupplier && !supplier.isCustomer,
        };
      }).toList();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final suppliers = await context.read<SupplierRepo>().list(
          q: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          onlyActive: !_showInactive,
        );
    if (!mounted) return;
    setState(() {
      _allSuppliers = suppliers;
      _selectedIds.removeWhere(
        (id) => !suppliers.any((supplier) => supplier.id == id),
      );
      _loading = false;
    });
  }

  void _setTab(_SupplierRoleTab tab) {
    setState(() {
      _tab = tab;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.contains(id)
          ? _selectedIds.remove(id)
          : _selectedIds.add(id);
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _handleSupplierTap(List<Supplier> visible, int index) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final shift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    final additive = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
    if (shift && _selectionAnchorIndex != null) {
      final start =
          _selectionAnchorIndex! < index ? _selectionAnchorIndex! : index;
      final end =
          _selectionAnchorIndex! > index ? _selectionAnchorIndex! : index;
      setState(() {
        _selectionMode = true;
        if (!additive) _selectedIds.clear();
        _selectedIds.addAll(
          visible.sublist(start, end + 1).map((supplier) => supplier.id),
        );
      });
      return;
    }
    if (_selectionMode || additive) {
      _toggleSelection(visible[index].id);
      _selectionAnchorIndex = index;
      return;
    }
    _openEdit(visible[index].id);
  }

  void _toggleAllVisible(List<Supplier> visible) {
    final ids = visible.map((supplier) => supplier.id).toSet();
    final allSelected = ids.isNotEmpty && ids.every(_selectedIds.contains);
    setState(() {
      _selectionMode = !allSelected;
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _startDragSelection(
    List<Supplier> visible,
    int index,
    DragStartDetails details,
  ) {
    _dragStartY = details.localPosition.dy;
    _dragStartIndex = index;
    _dragLastIndex = null;
    _dragSelectValue = !_selectedIds.contains(visible[index].id);
    _applyDragSelection(visible, index);
  }

  void _updateDragSelection(
    List<Supplier> visible,
    DragUpdateDetails details,
  ) {
    final start = _dragStartIndex;
    final startY = _dragStartY;
    if (start == null || startY == null) return;
    final offset = ((details.localPosition.dy - startY) / 56).truncate();
    final index = (start + offset).clamp(0, visible.length - 1);
    _applyDragSelection(visible, index);
  }

  void _applyDragSelection(List<Supplier> visible, int index) {
    if (_dragLastIndex == index) return;
    setState(() {
      _selectionMode = true;
      final id = visible[index].id;
      _dragSelectValue ? _selectedIds.add(id) : _selectedIds.remove(id);
    });
    _dragLastIndex = index;
  }

  void _endSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
      _selectionAnchorIndex = null;
    });
  }

  Future<void> _setSelectedRoles({bool? purchase, bool? customer}) async {
    await context.read<SupplierRepo>().setRoles(
          _selectedIds,
          isPurchaseSupplier: purchase,
          isCustomer: customer,
        );
    _endSelection();
    await _load();
  }

  Future<void> _mergeSelected() async {
    final selectedIds = {..._selectedIds};
    if (selectedIds.isEmpty) return;

    final target = await showSupplierPickerSheet(
      context,
      title: '대표 거래처 선택',
    );
    if (!mounted || target == null) return;

    final sourceIds = selectedIds.where((id) => id != target.id).toSet();
    if (sourceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대표 거래처와 병합할 거래처를 따로 선택해주세요.')),
      );
      return;
    }

    final repo = context.read<SupplierRepo>();
    final preview = await repo.previewMerge(
      targetId: target.id,
      sourceIds: sourceIds,
    );
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _SupplierMergeConfirmDialog(preview: preview),
    );
    if (confirmed != true || !mounted) return;

    await repo.mergeInto(targetId: target.id, sourceIds: sourceIds);
    if (!mounted) return;
    _endSelection();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${preview.sources.length}개 거래처를 병합했습니다.')),
    );
  }

  Future<void> _openNew() async {
    await Navigator.of(context).pushNamed('/suppliers/new');
    if (mounted) await _load();
  }

  Future<void> _openEdit(String id) async {
    await Navigator.of(context).pushNamed('/suppliers/edit', arguments: id);
    if (mounted) await _load();
  }

  Future<void> _toggleActive(Supplier supplier) async {
    await context
        .read<SupplierRepo>()
        .toggleActive(supplier.id, !supplier.isActive);
    await _load();
  }

  Future<void> _softDelete(Supplier supplier) async {
    await context.read<SupplierRepo>().softDelete(supplier.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleSuppliers;
    final selectedVisibleCount =
        visible.where((supplier) => _selectedIds.contains(supplier.id)).length;
    final allVisibleSelected =
        visible.isNotEmpty && selectedVisibleCount == visible.length;
    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                onPressed: _endSelection, icon: const Icon(Icons.close))
            : null,
        title: Text(_selectionMode ? '${_selectedIds.length}개 선택' : '거래처'),
        actions: [
          if (_selectionMode)
            TextButton(
              onPressed: () => setState(() {
                _selectedIds
                  ..clear()
                  ..addAll(visible.map((supplier) => supplier.id));
              }),
              child: const Text('전체 선택'),
            )
          else ...[
            TextButton(
              onPressed: () => setState(() => _selectionMode = true),
              child: const Text('선택'),
            ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _openNew,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('신규'),
            ),
      bottomNavigationBar: _selectionMode && _selectedIds.isNotEmpty
          ? _buildSelectionBar()
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<_SupplierRoleTab>(
              segments: const [
                ButtonSegment(
                  value: _SupplierRoleTab.purchase,
                  label: Text('발주처'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: _SupplierRoleTab.customer,
                  label: Text('고객'),
                  icon: Icon(Icons.people_outline),
                ),
                ButtonSegment(
                  value: _SupplierRoleTab.unclassified,
                  label: Text('미분류'),
                  icon: Icon(Icons.help_outline),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (values) => _setTab(values.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '거래처명·담당자·전화 검색',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('비활성 거래처 포함'),
            value: _showInactive,
            onChanged: (value) {
              setState(() => _showInactive = value);
              _load();
            },
          ),
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('전체 선택'),
            subtitle: Text('${visible.length}개'),
            value: selectedVisibleCount > 0 && !allVisibleSelected
                ? null
                : allVisibleSelected,
            tristate: true,
            onChanged:
                visible.isEmpty ? null : (_) => _toggleAllVisible(visible),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? Center(child: Text('${_tabLabel(_tab)} 거래처가 없습니다.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 88, top: 8),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) =>
                              _buildSupplierTile(visible, index),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierTile(List<Supplier> visible, int index) {
    final supplier = visible[index];
    final selected = _selectedIds.contains(supplier.id);
    return ListTile(
      leading: _selectionMode
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleSelection(supplier.id),
              onVerticalDragStart: (details) =>
                  _startDragSelection(visible, index, details),
              onVerticalDragUpdate: (details) =>
                  _updateDragSelection(visible, details),
              child: SizedBox(
                width: 48,
                height: 48,
                child: IgnorePointer(
                  child: Checkbox(value: selected, onChanged: (_) {}),
                ),
              ),
            )
          : const Icon(Icons.business),
      selected: selected,
      title: Text(
        supplier.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: supplier.isActive ? null : Colors.grey,
        ),
      ),
      subtitle: _buildSubtitle(supplier),
      onLongPress: () => _toggleSelection(supplier.id),
      onTap: () => _handleSupplierTap(visible, index),
      trailing: _selectionMode
          ? null
          : PopupMenuButton<String>(
              onSelected: (key) {
                if (key == 'edit') _openEdit(supplier.id);
                if (key == 'toggle') _toggleActive(supplier);
                if (key == 'delete') _softDelete(supplier);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(supplier.isActive ? '비활성화' : '활성화'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('비활성 처리')),
              ],
            ),
    );
  }

  Widget _buildSubtitle(Supplier supplier) {
    final details = <String>[];
    if ((supplier.contactName ?? '').isNotEmpty) {
      details.add('담당: ${supplier.contactName}');
    }
    if ((supplier.phone ?? '').isNotEmpty) details.add('전화: ${supplier.phone}');
    final roles = <String>[
      if (supplier.isPurchaseSupplier) '발주처',
      if (supplier.isCustomer) '고객',
    ];
    if (roles.isNotEmpty) details.add(roles.join('·'));
    return details.isEmpty
        ? const SizedBox.shrink()
        : Text(details.join(' · '));
  }

  Widget _buildSelectionBar() {
    return SafeArea(
      child: Material(
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _setSelectedRoles(purchase: true),
                child: const Text('발주처 지정'),
              ),
              FilledButton.tonal(
                onPressed: () => _setSelectedRoles(customer: true),
                child: const Text('고객 지정'),
              ),
              FilledButton.tonal(
                onPressed: () => _setSelectedRoles(
                  purchase: true,
                  customer: true,
                ),
                child: const Text('둘 다 지정'),
              ),
              OutlinedButton(
                onPressed: _tab == _SupplierRoleTab.purchase
                    ? () => _setSelectedRoles(purchase: false)
                    : _tab == _SupplierRoleTab.customer
                        ? () => _setSelectedRoles(customer: false)
                        : null,
                child: const Text('현재 탭에서 제외'),
              ),
              FilledButton.icon(
                onPressed: _mergeSelected,
                icon: const Icon(Icons.call_merge),
                label: const Text('대표에 병합'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _tabLabel(_SupplierRoleTab tab) => switch (tab) {
        _SupplierRoleTab.purchase => '발주처',
        _SupplierRoleTab.customer => '고객',
        _SupplierRoleTab.unclassified => '미분류',
      };
}

class _SupplierMergeConfirmDialog extends StatelessWidget {
  const _SupplierMergeConfirmDialog({required this.preview});

  final SupplierMergePreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('거래처 병합'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('대표 거래처', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              _SupplierMergeNameRow(preview.target),
              const SizedBox(height: 16),
              Text('병합될 거래처', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              ...preview.sources.map(_SupplierMergeNameRow.new),
              const SizedBox(height: 16),
              Text('변경될 데이터', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _MergeCountRow(label: '발주서', count: preview.purchaseOrders),
              _MergeCountRow(label: '견적서', count: preview.quotes),
              _MergeCountRow(label: '아이템 기본 거래처', count: preview.items),
              _MergeCountRow(label: '연락처', count: preview.contacts),
              _MergeCountRow(label: '계좌', count: preview.accounts),
              _MergeCountRow(
                label: '배송지 연결',
                count: preview.shippingDestinations,
              ),
              const SizedBox(height: 12),
              Text(
                '대표 거래처 정보는 유지하고, 비어 있는 항목만 병합될 거래처 값으로 보충합니다. '
                '병합된 거래처는 비활성 처리됩니다.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('병합 실행'),
        ),
      ],
    );
  }
}

class _SupplierMergeNameRow extends StatelessWidget {
  const _SupplierMergeNameRow(this.supplier);

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if ((supplier.phone ?? '').isNotEmpty) supplier.phone,
      if ((supplier.addr ?? '').isNotEmpty) supplier.addr,
    ].join(' · ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.business),
      title: Text(supplier.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
    );
  }
}

class _MergeCountRow extends StatelessWidget {
  const _MergeCountRow({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$count건'),
        ],
      ),
    );
  }
}
