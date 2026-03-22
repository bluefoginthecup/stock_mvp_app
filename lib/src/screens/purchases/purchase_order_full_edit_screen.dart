import 'package:flutter/material.dart';

import '../../models/purchase_order.dart';
import '../../repos/repo_interfaces.dart';

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

  /// 🔥 추가
  late final TextEditingController vatC;
  late final TextEditingController shippingC;
  late final TextEditingController extraC;

  late DateTime eta;
  late PurchaseOrderStatus status;

  /// 🔥 추가
  bool vatIncluded = false;

  String paymentStatus = 'unpaid';
  DateTime? paidAt;

  String vatInvoiceStatus = 'pending';
  DateTime? vatInvoiceIssuedAt;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    supplierC = TextEditingController();
    memoC = TextEditingController();
    vatC = TextEditingController();
    shippingC = TextEditingController();
    extraC = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final po = await widget.repo.getPurchaseOrderById(widget.orderId);

    if (!mounted) return;

    if (po == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('발주서를 찾을 수 없습니다')),
      );
      Navigator.pop(context, false);
      return;
    }

    setState(() {
      _po = po;
      supplierC.text = po.supplierName;
      memoC.text = po.memo ?? '';

      vatC.text = (po.vat ?? 0).toString();
      shippingC.text = (po.shippingCost ?? 0).toString();
      extraC.text = (po.extraCost ?? 0).toString();

      eta = po.eta;
      status = po.status;

      vatIncluded = po.vatIncluded;

      paymentStatus = po.paymentStatus ?? 'unpaid';
      paidAt = po.paidAt;

      vatInvoiceStatus = po.vatInvoiceStatus ?? 'pending';
      vatInvoiceIssuedAt = po.vatInvoiceIssuedAt;

      _loading = false;
    });
  }

  @override
  void dispose() {
    supplierC.dispose();
    memoC.dispose();
    vatC.dispose();
    shippingC.dispose();
    extraC.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime initial,
    required Function(DateTime) onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onPicked(picked);
      setState(() {});
    }
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text) ?? 0;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final base = _po!;

    final updated = base.copyWith(
      supplierName: supplierC.text.trim(),
      eta: eta,
      status: status,
      memo: memoC.text.trim().isEmpty ? null : memoC.text.trim(),

      /// 🔥 금액
      vat: _parse(vatC),
      shippingCost: _parse(shippingC),
      extraCost: _parse(extraC),
      vatIncluded: vatIncluded,

      /// 🔥 결제
      paymentStatus: paymentStatus,
      paidAt: paidAt,

      /// 🔥 세금계산서
      vatInvoiceStatus: vatInvoiceStatus,
      vatInvoiceIssuedAt: vatInvoiceIssuedAt,
    );

    await widget.repo.updatePurchaseOrder(updated);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장 완료')),
    );

    Navigator.pop(context, true);
  }

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('발주서 전체 편집'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            /// 기본
            Text('기본정보', style: text.titleSmall),
            TextFormField(controller: supplierC, decoration: _dec('공급처')),

            ListTile(
              title: const Text('입고예정일'),
              subtitle: Text('${eta.toLocal()}'.split('.').first),
              onTap: () => _pickDate(
                initial: eta,
                onPicked: (d) => eta = d,
              ),
            ),

            DropdownButtonFormField(
              value: status,
              items: PurchaseOrderStatus.values
                  .map((s) => DropdownMenuItem(
                value: s,
                child: Text(s.name),
              ))
                  .toList(),
              onChanged: (v) => setState(() => status = v!),
            ),

            const SizedBox(height: 16),

            /// 금액
            Text('금액', style: text.titleSmall),

            TextFormField(
              controller: vatC,
              keyboardType: TextInputType.number,
              decoration: _dec('부가세'),
            ),

            TextFormField(
              controller: shippingC,
              keyboardType: TextInputType.number,
              decoration: _dec('배송비'),
            ),

            TextFormField(
              controller: extraC,
              keyboardType: TextInputType.number,
              decoration: _dec('기타비용'),
            ),

            SwitchListTile(
              title: const Text('부가세 포함'),
              value: vatIncluded,
              onChanged: (v) => setState(() => vatIncluded = v),
            ),

            const SizedBox(height: 16),

            /// 결제
            Text('결제', style: text.titleSmall),

            DropdownButtonFormField(
                 value: ['unpaid', 'paid', 'partial'].contains(paymentStatus)
                 ? paymentStatus
                 : 'unpaid',
              items: ['unpaid', 'paid', 'partial']
                  .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e),
              ))
                  .toList(),
              onChanged: (v) => setState(() => paymentStatus = v!),
            ),

            ListTile(
              title: const Text('입금일'),
              subtitle: Text(
                paidAt == null
                    ? '-'
                    : '${paidAt!.toLocal()}'.split('.').first,
              ),
              onTap: () => _pickDate(
                initial: paidAt ?? DateTime.now(),
                onPicked: (d) => paidAt = d,
              ),
            ),

            const SizedBox(height: 16),

            /// 세금계산서
            Text('세금계산서', style: text.titleSmall),

            DropdownButtonFormField(
                value: ['pending', 'issued'].contains(vatInvoiceStatus)
                 ? vatInvoiceStatus
                 : 'pending',
              items: ['pending', 'issued']
                  .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e),
              ))
                  .toList(),
              onChanged: (v) => setState(() => vatInvoiceStatus = v!),
            ),

            ListTile(
              title: const Text('발행일'),
              subtitle: Text(
                vatInvoiceIssuedAt == null
                    ? '-'
                    : '${vatInvoiceIssuedAt!.toLocal()}'
                    .split('.')
                    .first,
              ),
              onTap: () => _pickDate(
                initial: vatInvoiceIssuedAt ?? DateTime.now(),
                onPicked: (d) => vatInvoiceIssuedAt = d,
              ),
            ),

            const SizedBox(height: 16),

            /// 메모
            TextFormField(
              controller: memoC,
              maxLines: 4,
              decoration: _dec('메모'),
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _save,
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}