import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/extensions/payment_status_ext.dart';
import '../../models/extensions/vat_invoice_status_ext.dart';
import '../../models/purchase_line.dart';
import '../../models/purchase_order.dart';
import '../../models/types.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/inventory_service.dart';
import '../../ui/common/ui.dart';
import 'purchase_line_full_edit_screen.dart';
import 'widgets/purchase_print_action.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final PurchaseOrderRepo repo;
  final String orderId;

  const PurchaseDetailScreen({
    super.key,
    required this.repo,
    required this.orderId,
  });

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  PurchaseOrder? _po;
  List<PurchaseLine> _lines = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
    });

    try {
      final po = await widget.repo.getPurchaseOrderById(widget.orderId);
      final lines = await widget.repo.getLines(widget.orderId);

      if (!mounted) return;

      setState(() {
        _po = po;
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  String _statusLabel(PurchaseOrderStatus s) {
    switch (s) {
      case PurchaseOrderStatus.draft:
        return '임시저장';
      case PurchaseOrderStatus.ordered:
        return '발주완료';
      case PurchaseOrderStatus.received:
        return '입고완료';
      case PurchaseOrderStatus.canceled:
        return '발주취소';
    }
  }

  String _fmt(num v) => v.toStringAsFixed(0);

  Future<String?> _editText({
    required String title,
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                TextField(controller: controller),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, controller.text.trim());
                  },
                  child: const Text('저장'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDateTap(int index) async {
    final po = _po;
    if (po == null) return;

    DateTime initialDate;
    switch (index) {
      case 0:
        initialDate = po.createdAt;
        break;
      case 1:
        initialDate = po.receivedAt ?? po.eta ?? DateTime.now();
        break;
      case 2:
        initialDate = po.paidAt ?? po.paymentDueAt ?? DateTime.now();
        break;
      case 3:
        initialDate = po.vatInvoiceIssuedAt ?? po.vatInvoiceDueAt ?? DateTime.now();
        break;
      default:
        initialDate = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    PurchaseOrder updated;
    switch (index) {
      case 0:
        updated = po.copyWith(
          createdAt: picked,
          updatedAt: DateTime.now(),
        );
        break;
      case 1:
        if (po.status == PurchaseOrderStatus.received) {
          // 입고완료 상태 → receivedAt
          updated = po.copyWith(
            receivedAt: picked,
            updatedAt: DateTime.now(),
          );
        } else {
          // 입고예정 상태 → eta
          updated = po.copyWith(
            eta: picked,
            updatedAt: DateTime.now(),
          );
        }
        break;
      case 2:
        if (po.paymentStatusEnum == PaymentStatus.paid) {
          updated = po.copyWith(
            paidAt: picked,
            updatedAt: DateTime.now(),
          );
        } else {
          updated = po.copyWith(
            paymentDueAt: picked,
            updatedAt: DateTime.now(),
          );
        }
        break;
      case 3:
        if (po.vatInvoiceStatusEnum == VatInvoiceStatus.issued) {
          updated = po.copyWith(
            vatInvoiceIssuedAt: picked,
            updatedAt: DateTime.now(),
          );
        } else {
          updated = po.copyWith(
            vatInvoiceDueAt: picked,
            updatedAt: DateTime.now(),
          );
        }
        break;
      default:
        return;
    }

    await widget.repo.updatePurchaseOrder(updated);
    await _reload();
  }

  Future<void> _addLineFull() async {
    final po = _po;
    if (po == null) return;

    final saved = await Navigator.push<PurchaseLine?>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseLineFullEditScreen(
          repo: widget.repo,
          orderId: po.id,
          initial: null,
        ),
      ),
    );

    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추가되었습니다')),
      );
      await _reload();
    }
  }

  Future<void> _openLineFull(PurchaseLine line) async {
    final po = _po;
    if (po == null) return;

    final saved = await Navigator.push<PurchaseLine?>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseLineFullEditScreen(
          repo: widget.repo,
          orderId: po.id,
          initial: line,
        ),
      ),
    );

    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장되었습니다')),
      );
      await _reload();
    }
  }

  Future<void> _handleTimelineTap(int index) async {
    final po = _po;
    if (po == null) return;

    switch (index) {
      case 0:
        final result = await showModalBottomSheet<PurchaseOrderStatus>(
          context: context,
          builder: (_) {
            final options = PurchaseOrderStatus.values
                .where((s) => s != PurchaseOrderStatus.received)
                .toList();

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((s) {
                  return ListTile(
                    title: Text(_statusLabel(s)),
                    trailing: s == po.status ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, s),
                  );
                }).toList(),
              ),
            );
          },
        );

        if (result == null) return;

        await widget.repo.updatePurchaseOrder(
          po.copyWith(
            status: result,
            updatedAt: DateTime.now(),
          ),
        );
        await _reload();
        break;

      case 1:
        final result = await showModalBottomSheet<bool>(
          context: context,
          builder: (_) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('입고완료'),
                    onTap: () => Navigator.pop(context, true),
                  ),
                  ListTile(
                    title: const Text('입고예정'),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            );
          },
        );

        if (result == null) return;

        if (result == false) {
          final picked = await showDatePicker(
            context: context,
            initialDate: po.eta ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );

          if (picked == null) return;

          await context.read<InventoryService>().rollbackReceivePurchase(
            po.id,
            eta: picked,
          );
          await _reload();
          return;
        }

        final receivedDate = await showDatePicker(
          context: context,
          initialDate: po.receivedAt ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (receivedDate == null) return;

        await context.read<InventoryService>().receivePurchase(po.id);

        final newPo = await widget.repo.getPurchaseOrderById(po.id);
        if (newPo != null) {
          await widget.repo.updatePurchaseOrder(
            newPo.copyWith(
              receivedAt: receivedDate,
              updatedAt: DateTime.now(),
            ),
          );
        }

        await _reload();
        break;

      case 2:
        if (po.status != PurchaseOrderStatus.received) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('입고완료 후 결제 처리할 수 있습니다.')),
          );
          return;
        }

        final result = await showModalBottomSheet<bool>(
          context: context,
          builder: (_) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('결제완료'),
                    onTap: () => Navigator.pop(context, true),
                  ),
                  ListTile(
                    title: const Text('결제예정'),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            );
          },
        );

        if (result == null) return;

        if (result == false) {
          final picked = await showDatePicker(
            context: context,
            initialDate: po.paymentDueAt ?? _endOfMonth(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );

          if (picked == null) return;

          await widget.repo.updatePurchaseOrder(
            po.copyWith(
              paymentStatus: PaymentStatus.unpaid.value,
              paidAt: null,
              paymentDueAt: picked,
              updatedAt: DateTime.now(),
            ),
          );
          await _reload();
          return;
        }

        final paidDate = await showDatePicker(
          context: context,
          initialDate: po.paidAt ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (paidDate == null) return;

        await widget.repo.updatePurchaseOrder(
          po.copyWith(
            paymentStatus: PaymentStatus.paid.value,
            paidAt: paidDate,
            updatedAt: DateTime.now(),
          ),
        );
        await _reload();
        break;

      case 3:
        final result = await showModalBottomSheet<bool>(
          context: context,
          builder: (_) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('세금계산서 발행완료'),
                    onTap: () => Navigator.pop(context, true),
                  ),
                  ListTile(
                    title: const Text('세금계산서 발행예정'),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            );
          },
        );

        if (result == null) return;

        if (result == false) {
          final picked = await showDatePicker(
            context: context,
            initialDate: po.vatInvoiceDueAt ?? _endOfMonth(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );

          if (picked == null) return;

          await widget.repo.updatePurchaseOrder(
            po.copyWith(
              vatInvoiceStatus: VatInvoiceStatus.pending.value,
              vatInvoiceIssuedAt: null,
              vatInvoiceDueAt: picked,
              updatedAt: DateTime.now(),
            ),
          );
          await _reload();
          return;
        }

        final issuedDate = await showDatePicker(
          context: context,
          initialDate: po.vatInvoiceIssuedAt ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (issuedDate == null) return;

        await widget.repo.updatePurchaseOrder(
          po.copyWith(
            vatInvoiceStatus: VatInvoiceStatus.issued.value,
            vatInvoiceIssuedAt: issuedDate,
            updatedAt: DateTime.now(),
          ),
        );
        await _reload();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final po = _po;
    if (po == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('발주상세')),
        body: const Center(
          child: Text('발주 정보를 불러오지 못했습니다.'),
        ),
      );
    }

    final itemsTotal = _lines.fold<double>(
      0,
          (sum, l) => sum + (l.qty * l.unitPrice),
    );

    final vat = switch (po.vatType) {
      VatType.exempt => 0.0,
      VatType.inclusive => itemsTotal / 11,
      VatType.exclusive => itemsTotal * 0.1,
    };

    final shipping = po.shippingCost ?? 0.0;
    final extra = po.extraCost ?? 0.0;

    final total = po.vatType == VatType.inclusive
        ? itemsTotal + shipping + extra
        : itemsTotal + vat + shipping + extra;

    return Scaffold(
      appBar: AppBar(
        title: Text('발주상세'),
        actions: [
          PurchasePrintAction(poId: widget.orderId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLineFull,
        icon: const Icon(Icons.add),
        label: Text('추가'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            po.supplierName.isEmpty ? '(거래처 미지정)' : po.supplierName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(_statusLabel(po.status)),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PurchaseTimeline(
                      po: po,
                      onStepTap: _handleTimelineTap,
                      onDateTap: _handleDateTap,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('메모'),
                      subtitle: Text(
                        (po.memo ?? '').isEmpty ? '(없음)' : po.memo!,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await _editText(
                          title: '메모',
                          initial: po.memo ?? '',
                        );

                        if (result == null) return;

                        await widget.repo.updatePurchaseOrder(
                          po.copyWith(
                            memo: result.isEmpty ? null : result,
                            updatedAt: DateTime.now(),
                          ),
                        );
                        await _reload();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _lines.isEmpty
                ? const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('발주 품목이 없습니다.'),
              ),
            )
                : Card(
              child: Column(
                children: _lines.map((ln) {
                  final lineTotal = ln.qty * ln.unitPrice;
                  final name = ln.name.trim().isEmpty ? ln.itemId : ln.name;

                  return ListTile(
                    title: Text('$name × ${ln.qty}'),
                    subtitle: Text(
                      '단가 ${_fmt(ln.unitPrice)} / 합계 ${_fmt(lineTotal)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openLineFull(ln),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₩ ${_fmt(total)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _calcItem('상품', itemsTotal),
                        _calcItem('세금', vat),
                        _calcItem('기타', shipping + extra),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class PurchaseTimeline extends StatelessWidget {
  final PurchaseOrder po;
  final void Function(int index) onStepTap;
  final void Function(int index)? onDateTap;

  const PurchaseTimeline({
    super.key,
    required this.po,
    required this.onStepTap,
    this.onDateTap,
  });

  bool get isOrdered =>
      po.status == PurchaseOrderStatus.ordered ||
          po.status == PurchaseOrderStatus.received;

  bool get isReceived => po.status == PurchaseOrderStatus.received;

  bool get isPaid => po.paymentStatusEnum == PaymentStatus.paid;

  bool get isVatIssued => po.vatInvoiceStatusEnum == VatInvoiceStatus.issued;

  Widget _segmentBox({required bool active}) {
    return Expanded(
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: active ? Colors.green : Colors.grey.shade300,
          border: Border.all(
            color: Colors.grey.shade400,
            width: 1,
          ),
        ),
      ),
    );
  }

  String _orderLabel() {
    switch (po.status) {
      case PurchaseOrderStatus.draft:
        return '임시저장';
      case PurchaseOrderStatus.ordered:
      case PurchaseOrderStatus.received:
        return '발주완료';
      case PurchaseOrderStatus.canceled:
        return '발주취소';
    }
  }

  String _receiveLabel() => isReceived ? '입고완료' : '입고예정';

  String _paymentLabel() => isPaid ? '결제완료' : '결제예정';

  String _vatLabel() => isVatIssued ? '세금계산서 발행완료' : '세금계산서 발행예정';

  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step(_orderLabel(), isOrdered, po.createdAt),
      _Step(
        _receiveLabel(),
        isReceived,
        isReceived ? po.receivedAt : po.eta,
      ),
      _Step(
        _paymentLabel(),
        isPaid,
        isPaid ? po.paidAt : po.paymentDueAt,
      ),
      _Step(
        _vatLabel(),
        isVatIssued,
        isVatIssued ? po.vatInvoiceIssuedAt : po.vatInvoiceDueAt,
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 20,
          child: Row(
            children: [
              _segmentBox(active: isOrdered),
              _segmentBox(active: isOrdered && isReceived),
              _segmentBox(active: isOrdered && isReceived && isPaid),
              _segmentBox(
                active: isOrdered && isReceived && isPaid && isVatIssued,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: steps.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;

            return Expanded(
              child: GestureDetector(
                onTap: () => onStepTap(i),
                child: Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: s.done ? Colors.green : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Row(
          children: steps.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;

            return Expanded(
              child: GestureDetector(
                onTap: onDateTap == null ? null : () => onDateTap!(i),
                child: Center(
                  child: Text(
                    s.date != null ? '${s.date!.month}/${s.date!.day}' : '',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Step {
  final String label;
  final bool done;
  final DateTime? date;

  _Step(this.label, this.done, this.date);
}

Widget _calcItem(String label, double value) {
  return Column(
    children: [
      Text(value.toStringAsFixed(0)),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    ],
  );
}

DateTime _endOfMonth([DateTime? base]) {
  final now = base ?? DateTime.now();
  return DateTime(now.year, now.month + 1, 0);
}