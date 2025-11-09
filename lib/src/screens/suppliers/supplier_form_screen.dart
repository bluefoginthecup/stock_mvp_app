import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/suppliers.dart';
import '../../repos/repo_interfaces.dart';
import 'package:uuid/uuid.dart';

class SupplierFormScreen extends StatefulWidget {
  final String? supplierId; // null이면 새로 만들기
  const SupplierFormScreen({super.key, this.supplierId});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _contactC = TextEditingController();
  final _phoneC = TextEditingController();
  final _emailC = TextEditingController();
  final _addrC = TextEditingController();
  final _memoC = TextEditingController();
  bool _isActive = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadIfEdit();
  }

  Future<void> _loadIfEdit() async {
    final repo = context.read<SupplierRepo>();
    if (widget.supplierId != null) {
      final s = await repo.get(widget.supplierId!);
      if (s != null) {
        _nameC.text = s.name;
        _contactC.text = s.contactName ?? '';
        _phoneC.text = s.phone ?? '';
        _emailC.text = s.email ?? '';
        _addrC.text = s.addr ?? '';
        _memoC.text = s.memo ?? '';
        _isActive = s.isActive;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _contactC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _addrC.dispose();
    _memoC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.read<SupplierRepo>();
    final now = DateTime.now();

    final existingId = widget.supplierId;
    final supplier = Supplier(
      id: existingId ?? const Uuid().v4(),
      name: _nameC.text.trim(),
      contactName: _contactC.text.trim().isEmpty ? null : _contactC.text.trim(),
      phone: _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim(),
      email: _emailC.text.trim().isEmpty ? null : _emailC.text.trim(),
      addr: _addrC.text.trim().isEmpty ? null : _addrC.text.trim(),
      memo: _memoC.text.trim().isEmpty ? null : _memoC.text.trim(),
      isActive: _isActive,
      createdAt: now,
      updatedAt: now,
    );

    await repo.upsert(supplier);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existingId == null ? '거래처가 등록되었어요' : '거래처가 저장되었어요')),
    );
    Navigator.pop(context, supplier);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplierId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '거래처 수정' : '거래처 등록'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameC,
              decoration: const InputDecoration(labelText: '거래처명 *', hintText: '예) 대원섬유'),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? '거래처명을 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactC,
              decoration: const InputDecoration(labelText: '담당자'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneC,
              decoration: const InputDecoration(labelText: '전화'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailC,
              decoration: const InputDecoration(labelText: '이메일'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addrC,
              decoration: const InputDecoration(labelText: '주소'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _memoC,
              decoration: const InputDecoration(labelText: '메모'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('활성 상태'),
              subtitle: const Text('비활성 시 기본 선택 목록에서 제외'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(isEdit ? '저장' : '등록'),
            ),
          ],
        ),
      ),
    );
  }
}
