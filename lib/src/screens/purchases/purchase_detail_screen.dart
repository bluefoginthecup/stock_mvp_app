import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repos/repo_interfaces.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_line.dart';
import '../../ui/common/ui.dart';
import 'widgets/purchase_print_action.dart';
import '../../services/inventory_service.dart';
import 'purchase_order_full_edit_screen.dart';
import 'purchase_line_full_edit_screen.dart';

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
  Map<String, String> _itemNameById = const {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final po = await widget.repo.getPurchaseOrderById(widget.orderId);
    final lines = await widget.repo.getLines(widget.orderId);

    final itemRepo = context.read<ItemRepo>();
    final nameMap = <String, String>{};

    await Future.wait(lines.map((ln) async {
      final it = await itemRepo.getItem(ln.itemId);
      if (it != null) {
        nameMap[ln.itemId] = (it.displayName ?? it.name);
      }
    }));

    if (!mounted) return;
    setState(() {
      _po = po;
      _lines = lines;
      _itemNameById = nameMap;
    });
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

  PurchaseOrderStatus _next(PurchaseOrderStatus s) {
    switch (s) {
      case PurchaseOrderStatus.draft:
        return PurchaseOrderStatus.ordered;
      case PurchaseOrderStatus.ordered:
        return PurchaseOrderStatus.received;
      case PurchaseOrderStatus.received:
      case PurchaseOrderStatus.canceled:
        return s;
    }
  }

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

  Future<String?> _selectOption({
    required String title,
    required List<String> options,
    required String current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16)),
            const Divider(),

            ...options.map((e) {
              return ListTile(
                title: Text(e),
                trailing: e == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, e),
              );
            }),
          ],
        );
      },
    );
  }
  Future<double?> _editNumber({
    required String title,
    required double initial,
  }) {
    final controller = TextEditingController(
      text: initial.toStringAsFixed(0),
    );

    return showModalBottomSheet<double>(
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

                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text) ?? 0;
                    Navigator.pop(context, value);
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

  Future<void> _openHeaderFullEdit() async {
    if (_po == null) return;

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseOrderFullEditScreen(
          repo: widget.repo,
          orderId: widget.orderId,
        ),
      ),
    );

    if (changed == true) await _reload();
  }

  Future<void> _addLineFull() async {
    if (_po == null) return;

    final saved = await Navigator.push<PurchaseLine?>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseLineFullEditScreen(
          repo: widget.repo,
          orderId: widget.orderId,
          initial: null,
        ),
      ),
    );

    if (saved != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추가되었습니다')),
      );
      await _reload();
    }
  }

  Future<void> _openLineFull(PurchaseLine line) async {
    final saved = await Navigator.push<PurchaseLine?>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseLineFullEditScreen(
          repo: widget.repo,
          orderId: widget.orderId,
          initial: line,
        ),
      ),
    );

    if (saved != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장되었습니다')),
      );
      await _reload();
    }
  }

  String _titleForLine(PurchaseLine ln) {
    final baseName = (ln.name.trim().isNotEmpty)
        ? ln.name
        : (_itemNameById[ln.itemId] ?? ln.itemId);
    return '$baseName × ${ln.qty} ${ln.unit}';
  }
  String _fmt(num v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final po = _po;
    final t = context.t;

    if (po == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final itemsTotal = _lines.fold(
      0.0,
          (sum, l) => sum + (l.qty * l.unitPrice),
    );
    double calcVat(double itemsTotal, bool vatIncluded) {
      if (vatIncluded) {
        return itemsTotal / 11;
      } else {
        return itemsTotal * 0.1;
      }
    }
    final vat = calcVat(itemsTotal, po.vatIncluded);

    final shipping = po.shippingCost ?? 0;
    final extra = po.extraCost ?? 0;

    final total = po.vatIncluded
        ? itemsTotal + shipping + extra
        : itemsTotal + vat + shipping + extra;



    return Scaffold(
      appBar: AppBar(
        title: Text(t.purchase_detail_title),
        actions: [
          IconButton(
            onPressed: _openHeaderFullEdit,
            icon: const Icon(Icons.edit_note),
          ),
          PurchasePrintAction(poId: widget.orderId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLineFull,
        icon: const Icon(Icons.add),
        label: Text(t.btn_add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
          children: [
            /// 헤더
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('헤더',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(width: 8),
                        Chip(label: Text(_statusLabel(po.status))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('발주 상태'),
                      subtitle: Text(po.status.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await showModalBottomSheet<PurchaseOrderStatus>(
                          context: context,
                          builder: (_) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: PurchaseOrderStatus.values.map((s) {
                                return ListTile(
                                  title: Text(s.name),
                                  trailing: s == po.status ? const Icon(Icons.check) : null,
                                  onTap: () => Navigator.pop(context, s),
                                );
                              }).toList(),
                            );
                          },
                        );

                        if (result != null) {
                          await widget.repo.updatePurchaseOrder(
                            po.copyWith(status: result),
                          );
                          await _reload();
                        }
                      },
                    ),

                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('공급처'),
                      subtitle: Text(
                        po.supplierName.isEmpty ? '(미지정)' : po.supplierName,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await _editText(
                          title: '공급처',
                          initial: po.supplierName,
                        );

                        if (result != null) {
                          await widget.repo.updatePurchaseOrder(
                            po.copyWith(supplierName: result),
                          );
                          await _reload();
                        }
                      },
                    ),

                    ListTile(
                      title: const Text('입고예정일'),
                      subtitle: Text(
                        po.eta.toLocal().toString().split('.').first,
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: po.eta,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          await widget.repo.updatePurchaseOrder(
                            po.copyWith(eta: picked),
                          );
                          await _reload();
                        }
                      },
                    ),
                      ListTile(
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

                          if (result != null) {
                            await widget.repo.updatePurchaseOrder(
                              po.copyWith(
                                memo: result.isEmpty ? null : result,
                              ),
                            );
                            await _reload();
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            /// 상품 리스트
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
                            final name = (ln.name.trim().isNotEmpty)
                                ? ln.name
                                : (_itemNameById[ln.itemId] ?? ln.itemId);

                            final total = ln.qty * ln.unitPrice;

                            return ListTile(
                              title: Text('$name × ${ln.qty}'),
                              subtitle: Text(
                                '단가 ${ln.unitPrice} / 합계 ${_fmt(total)}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openLineFull(ln),
                            );
                          }).toList(),
                        ),
                      ),


            const SizedBox(height: 8),

            /// 금액
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('상품금액', itemsTotal),
                    SwitchListTile(
                      title: const Text('부가세 포함'),
                      value: po.vatIncluded,
                      onChanged: (v) async {
                        await widget.repo.updatePurchaseOrder(
                          po.copyWith(vatIncluded: v),
                        );
                        await _reload();
                      },
                    ),

                    ListTile(
                      title: const Text('부가세'),
                      subtitle: Text(_fmt(po.vat ?? 0)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await _editNumber(
                          title: '부가세',
                          initial: po.vat ?? 0,
                        );

                        if (result != null) {
                          await widget.repo.updatePurchaseOrder(
                            po.copyWith(vat: result),
                          );
                          await _reload();
                        }
                      },
                    ),

                    ListTile(
                      title: const Text('배송비'),
                      subtitle: Text(_fmt(po.shippingCost ?? 0)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await _editNumber(
                          title: '배송비',
                          initial: po.shippingCost ?? 0,
                        );

                        if (result != null) {
                          await widget.repo.updatePurchaseOrder(
                            po.copyWith(shippingCost: result),
                          );
                          await _reload();
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('기타비용'),
                      subtitle: Text(_fmt(po.extraCost ?? 0)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await _editNumber(
                          title: '기타비용',
                          initial: po.extraCost ?? 0,
                        );

                        if (result != null) {
                          await widget.repo.updatePurchaseOrder(
                            po.copyWith(extraCost: result),
                          );
                          await _reload();
                        }
                      },
                    ),
                    const Divider(),
                    _row('총 지급금액', total, bold: true),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            /// 결제
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('결제 상태'),
                      subtitle: Text(po.paymentStatus ?? 'unpaid'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await _selectOption(
                          title: '결제 상태',
                          options: ['unpaid', 'paid', 'partial'],
                          current: po.paymentStatus ?? 'unpaid',
                        );

                        if (result != null) {
                          await widget.repo.updatePurchaseOrder(
                            po.copyWith(paymentStatus: result),
                          );
                          await _reload();
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('입금일'),
                      subtitle: Text(
                        po.paidAt == null
                            ? '(미입력)'
                            : po.paidAt!.toLocal().toString().split('.').first,
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: po.paidAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          await widget.repo.updatePurchaseOrder(
                            po.copyWith(paidAt: picked),
                          );
                          await _reload();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            /// 세금계산서
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('세금계산서'),
                      subtitle: Text(po.vatInvoiceStatus ?? 'pending'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await _selectOption(
                          title: '세금계산서 상태',
                          options: ['pending', 'issued'],
                          current: po.vatInvoiceStatus ?? 'pending',
                        );

                        if (result != null) {
                          await widget.repo.updatePurchaseOrder(
                            po.copyWith(vatInvoiceStatus: result),
                          );
                          await _reload();
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('발행일'),
                      subtitle: Text(
                        po.vatInvoiceIssuedAt == null
                            ? '(미입력)'
                            : po.vatInvoiceIssuedAt!.toLocal().toString().split('.').first,
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      enabled: po.vatInvoiceStatus == 'issued',
                        onTap: po.vatInvoiceStatus == 'issued'
                        ? () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: po.vatInvoiceIssuedAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          await widget.repo.updatePurchaseOrder(
                            po.copyWith(
                              vatInvoiceIssuedAt: picked,
                              vatInvoiceStatus: 'issued', // 🔥 같이 변경
                            ),
                          );
                          await _reload();
                        }
                      }
                            : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),


            /// 🔥 FAB 공간 확보
            const SizedBox(height: 80),

            _ActionRow(
              status: po.status,
              onAdvance: () async {
                final next = _next(po.status);
                if (next == po.status) return;

                if (po.status == PurchaseOrderStatus.draft &&
                    next == PurchaseOrderStatus.ordered) {
                  await context.read<InventoryService>().orderPurchase(po.id);
                  await _reload();
                } else if (po.status == PurchaseOrderStatus.ordered &&
                    next == PurchaseOrderStatus.received) {
                  await context.read<InventoryService>().receivePurchase(po.id);
                  await _reload();
                }
              },
              onCancel: po.status == PurchaseOrderStatus.received
                  ? null
                  : () async {
                await context.read<InventoryService>().cancelPurchase(po.id);
                await _reload();
              },
              labelForAdvance: switch (po.status) {
                PurchaseOrderStatus.draft => t.purchase_action_order,
                PurchaseOrderStatus.ordered => t.purchase_action_receive,
                _ => t.purchase_already_received,
              },
              cancelLabel: t.common_cancel,
            ),
          ],
        ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            _fmt(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final PurchaseOrderStatus status;
  final VoidCallback? onAdvance;
  final VoidCallback? onCancel;
  final String labelForAdvance;
  final String cancelLabel;

  const _ActionRow({
    required this.status,
    required this.onAdvance,
    required this.onCancel,
    required this.labelForAdvance,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final canAdvance = status != PurchaseOrderStatus.received &&
        status != PurchaseOrderStatus.canceled;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: canAdvance ? onAdvance : null,
            child: Text(labelForAdvance),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: Text(cancelLabel),
          ),
        ),
      ],
    );
  }
}