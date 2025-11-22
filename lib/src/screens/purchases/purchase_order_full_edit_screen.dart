import 'package:flutter/material.dart';

import '../../models/purchase_order.dart';
import '../../repos/repo_interfaces.dart';
import '../../ui/common/ui.dart';

class PurchaseOrderFullEditScreen extends StatefulWidget {
  final PurchaseOrderRepo repo;
  final String orderId;

  const PurchaseOrderFullEditScreen({
    super.key,
    required this.repo,
    required this.orderId,
  });

  @override
  State<PurchaseOrderFullEditScreen> createState() => _PurchaseOrderFullEditScreenState();
}

class _PurchaseOrderFullEditScreenState extends State<PurchaseOrderFullEditScreen> {
  final _formKey = GlobalKey<FormState>();

  PurchaseOrder? _po;

  late final TextEditingController supplierC;
  late final TextEditingController memoC;
  late DateTime eta;
  late PurchaseOrderStatus status;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    supplierC = TextEditingController();
    memoC = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final po = await widget.repo.getPurchaseOrderById(widget.orderId);
        if (!mounted) return;
        // ✅ null 가드: 발주서가 없으면 알림 후 화면 닫기
        if (po == null) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('발주서를 찾을 수 없습니다')),
          );
          if (mounted) Navigator.pop(context, false);
          return;
        }
        // ✅ 안전하게 접근
        setState(() {
          _po = po;
          supplierC.text = po.supplierName;
          memoC.text = po.memo ?? '';
          eta = po.eta;
          status = po.status;
          _loading = false;
        });
  }

  @override
  void dispose() {
    supplierC.dispose();
    memoC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: eta,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        eta = DateTime(picked.year, picked.month, picked.day, eta.hour, eta.minute, eta.second);
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final base = _po!;
    final updated = base.copyWith(
      supplierName: supplierC.text.trim(),
      eta: eta,
      status: status,
      memo: memoC.text.trim().isEmpty ? null : memoC.text.trim(),
    );
    await widget.repo.updatePurchaseOrder(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('헤더 저장 완료')));
    Navigator.pop(context, true);
  }

  InputDecoration _dec(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('발주서 헤더 편집'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save, tooltip: '저장'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('공급/납기/상태', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: supplierC,
                decoration: _dec('공급처'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('입고예정일(ETA)'),
                subtitle: Text('${eta.toLocal()}'.split('.').first),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PurchaseOrderStatus>(
                value: status,
                decoration: _dec('상태'),
                items: PurchaseOrderStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (s) => setState(() => status = s ?? status),
              ),

              const SizedBox(height: 16),
              Text('메모', style: text.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: memoC,
                maxLines: 4,
                decoration: _dec('적요/메모'),
              ),

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('저장'),
              ),

              const SizedBox(height: 16),
              Text('발주ID: ${_po!.id}', style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
