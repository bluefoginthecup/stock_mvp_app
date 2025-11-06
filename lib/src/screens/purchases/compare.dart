// import 'package:flutter/material.dart';
// import 'package:uuid/uuid.dart';
//
// import '../../repos/repo_interfaces.dart';
// import '../../models/purchase_order.dart';
// import '../../models/purchase_line.dart';
// import '../../ui/common/ui.dart';
//
// class PurchaseDetailScreen extends StatefulWidget {
//   final PurchaseOrderRepo repo;
//   final String orderId;
//
//   const PurchaseDetailScreen({
//     super.key,
//     required this.repo,
//     required this.orderId,
//   });
//
//   @override
//   State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
// }
//
// class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
//   PurchaseOrder? _po;
//   List<PurchaseLine> _lines = const [];
//
//   @override
//   void initState() {
//     super.initState();
//     _reload();
//   }
//
//   Future<void> _reload() async {
//     final po = await widget.repo.getPurchaseOrderById(widget.orderId);
//     final lines = await widget.repo.getLines(widget.orderId);
//     if (!mounted) return;
//     setState(() {
//       _po = po;
//       _lines = lines;
//     });
//   }
//
//   PurchaseOrderStatus _next(PurchaseOrderStatus s) {
//     switch (s) {
//       case PurchaseOrderStatus.draft:
//         return PurchaseOrderStatus.ordered;
//       case PurchaseOrderStatus.ordered:
//         return PurchaseOrderStatus.received;
//       case PurchaseOrderStatus.received:
//       case PurchaseOrderStatus.canceled:
//         return s;
//     }
//   }
//
//   String _statusLabel(BuildContext ctx, PurchaseOrderStatus s) {
//     switch (s) {
//       case PurchaseOrderStatus.draft:
//         return '임시';
//       case PurchaseOrderStatus.ordered:
//         return '발주됨';
//       case PurchaseOrderStatus.received:
//         return '입고완료';
//       case PurchaseOrderStatus.canceled:
//         return '취소됨';
//     }
//   }
//
//   Future<void> _editHeader() async {
//     if (_po == null) return;
//     final updated = await showModalBottomSheet<PurchaseOrder>(
//       context: context,
//       isScrollControlled: true,
//       builder: (_) => _EditHeaderSheet(po: _po!),
//     );
//     if (updated != null) {
//       await widget.repo.updatePurchaseOrder(updated);
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('저장되었습니다')),
//       );
//       await _reload();
//     }
//   }
//
//   Future<void> _addLine() async {
//     if (_po == null) return;
//     final created = await showModalBottomSheet<PurchaseLine>(
//       context: context,
//       isScrollControlled: true,
//       builder: (_) => _EditLineSheet(initial: null, orderId: _po!.id),
//     );
//     if (created != null) {
//       final next = [..._lines, created];
//       await widget.repo.upsertLines(_po!.id, next);
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('추가되었습니다')),
//       );
//       await _reload();
//     }
//   }
//
//   Future<void> _editLine(PurchaseLine line) async {
//     final edited = await showModalBottomSheet<PurchaseLine>(
//       context: context,
//       isScrollControlled: true,
//       builder: (_) => _EditLineSheet(initial: line, orderId: line.orderId),
//     );
//     if (edited != null) {
//       final next = _lines.map((e) => e.id == edited.id ? edited : e).toList();
//       await widget.repo.upsertLines(edited.orderId, next);
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('저장되었습니다')),
//       );
//       await _reload();
//     }
//   }
//
//   Future<void> _removeLine(PurchaseLine line) async {
//     final ok = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(context.t.common_delete),
//         content: Text('${line.itemName} 삭제할까요?'),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t.common_cancel)),
//           FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.t.common_delete)),
//         ],
//       ),
//     );
//     if (ok != true) return;
//
//     final next = _lines.where((e) => e.id != line.id).toList();
//     await widget.repo.upsertLines(line.orderId, next);
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('삭제되었습니다')),
//     );
//     await _reload();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final po = _po;
//     final t = context.t;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(t.purchase_detail_title),
//         actions: [
//           IconButton(
//             onPressed: po == null ? null : _editHeader,
//             icon: const Icon(Icons.edit),
//             tooltip: '헤더 편집',
//           ),
//         ],
//       ),
//       floatingActionButton: (po == null)
//           ? null
//           : FloatingActionButton.extended(
//         onPressed: _addLine,
//         icon: const Icon(Icons.add),
//         label: Text(t.btn_add),
//       ),
//       body: po == null
//           ? const Center(child: CircularProgressIndicator())
//           : Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             _HeaderCard(po: po, statusLabel: _statusLabel(context, po.status)),
//             const SizedBox(height: 12),
//             Expanded(
//               child: _lines.isEmpty
//                   ? const Center(child: Text('발주 품목이 없습니다.'))
//                   : ListView.separated(
//                 itemCount: _lines.length,
//                 separatorBuilder: (_, __) => const Divider(height: 0),
//                 itemBuilder: (ctx, i) {
//                   final ln = _lines[i];
//                   return Dismissible(
//                     key: ValueKey(ln.id),
//                     direction: DismissDirection.endToStart,
//                     background: Container(
//                       color: Colors.red,
//                       alignment: Alignment.centerRight,
//                       padding: const EdgeInsets.symmetric(horizontal: 16),
//                       child: const Icon(Icons.delete, color: Colors.white),
//                     ),
//                     confirmDismiss: (_) async => true,
//                     onDismissed: (_) async {
//                       await _removeLine(ln);
//                     },
//                     child: ListTile(
//                       title: Text('${ln.itemName}  × ${ln.qty.toStringAsFixed(2)}'),
//                       subtitle: Text([
//                         if (ln.unitPrice != null) '단가 ${ln.unitPrice!.toStringAsFixed(0)}',
//                         if ((ln.memo ?? '').trim().isNotEmpty) '메모: ${ln.memo}',
//                       ].join(' · ')),
//                       trailing: const Icon(Icons.chevron_right),
//                       onTap: () => _editLine(ln),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 8),
//             _ActionRow(
//               status: po.status,
//               onAdvance: () async {
//                 final next = _next(po.status);
//                 if (next == po.status) return;
//                 await widget.repo.updatePurchaseOrderStatus(po.id, next);
//                 if (!mounted) return;
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('저장되었습니다')),
//                 );
//                 await _reload();
//               },
//               onCancel: po.status == PurchaseOrderStatus.received
//                   ? null
//                   : () async {
//                 await widget.repo.updatePurchaseOrderStatus(po.id, PurchaseOrderStatus.canceled);
//                 if (!mounted) return;
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('저장되었습니다')),
//                 );
//                 await _reload();
//               },
//               labelForAdvance: switch (po.status) {
//                 PurchaseOrderStatus.draft => t.purchase_action_order,
//                 PurchaseOrderStatus.ordered => t.purchase_action_receive,
//                 _ => t.purchase_already_received,
//               },
//               t: t,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _HeaderCard extends StatelessWidget {
//   final PurchaseOrder po;
//   final String statusLabel;
//   const _HeaderCard({required this.po, required this.statusLabel});
//
//   @override
//   Widget build(BuildContext context) {
//     final supplier = po.supplierName.trim().isEmpty ? '(미지정)' : po.supplierName;
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text('공급처: $supplier', style: Theme.of(context).textTheme.titleLarge),
//           const SizedBox(height: 8),
//           Text('ID: ${po.id}'),
//           Text('ETA: ${po.eta.toLocal()}'.split('.').first),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Text(context.t.field_status_label),
//               const SizedBox(width: 6),
//               Chip(label: Text(statusLabel)),
//             ],
//           ),
//           if ((po.memo ?? '').trim().isNotEmpty) ...[
//             const SizedBox(height: 8),
//             Text('적요: ${po.memo}'),
//           ],
//         ]),
//       ),
//     );
//   }
// }
//
// class _ActionRow extends StatelessWidget {
//   final PurchaseOrderStatus status;
//   final VoidCallback? onAdvance;
//   final VoidCallback? onCancel;
//   final String labelForAdvance;
//   final L10n t;
//   const _ActionRow({
//     required this.status,
//     required this.onAdvance,
//     required this.onCancel,
//     required this.labelForAdvance,
//     required this.t,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final canAdvance = status != PurchaseOrderStatus.received &&
//         status != PurchaseOrderStatus.canceled;
//     return Row(
//       children: [
//         Expanded(
//           child: ElevatedButton(
//             onPressed: canAdvance ? onAdvance : null,
//             child: Text(labelForAdvance),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: OutlinedButton(
//             onPressed: onCancel,
//             child: Text(t.common_cancel),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// /// --------------------
// /// 편집 모달들
// /// --------------------
//
// class _EditHeaderSheet extends StatefulWidget {
//   final PurchaseOrder po;
//   const _EditHeaderSheet({required this.po});
//
//   @override
//   State<_EditHeaderSheet> createState() => _EditHeaderSheetState();
// }
//
// class _EditHeaderSheetState extends State<_EditHeaderSheet> {
//   late TextEditingController supplierC;
//   late TextEditingController memoC;
//   late DateTime eta;
//   late PurchaseOrderStatus status;
//
//   @override
//   void initState() {
//     super.initState();
//     supplierC = TextEditingController(text: widget.po.supplierName);
//     memoC = TextEditingController(text: widget.po.memo ?? '');
//     eta = widget.po.eta;
//     status = widget.po.status;
//   }
//
//   @override
//   void dispose() {
//     supplierC.dispose();
//     memoC.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bottom = MediaQuery.of(context).viewInsets.bottom;
//     final t = context.t;
//
//     return Padding(
//       padding: EdgeInsets.only(bottom: bottom),
//       child: DraggableScrollableSheet(
//         expand: false,
//         initialChildSize: 0.75,
//         minChildSize: 0.4,
//         maxChildSize: 0.95,
//         builder: (_, controller) {
//           return Material(
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//             child: ListView(
//               controller: controller,
//               padding: const EdgeInsets.all(16),
//               children: [
//                 Text('헤더 편집', style: Theme.of(context).textTheme.titleLarge),
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: supplierC,
//                   decoration: const InputDecoration(labelText: '공급처(빈문자 허용)'),
//                 ),
//                 const SizedBox(height: 12),
//                 ListTile(
//                   contentPadding: EdgeInsets.zero,
//                   title: const Text('납기일(ETA)'),
//                   subtitle: Text('${eta.toLocal()}'.split('.').first),
//                   trailing: const Icon(Icons.calendar_today),
//                   onTap: () async {
//                     final picked = await showDatePicker(
//                       context: context,
//                       initialDate: eta,
//                       firstDate: DateTime(2020),
//                       lastDate: DateTime(2100),
//                     );
//                     if (picked != null) {
//                       setState(() {
//                         eta = DateTime(picked.year, picked.month, picked.day, eta.hour, eta.minute, eta.second);
//                       });
//                     }
//                   },
//                 ),
//                 const SizedBox(height: 12),
//                 DropdownButtonFormField<PurchaseOrderStatus>(
//                   value: status,
//                   decoration: const InputDecoration(labelText: '상태'),
//                   items: PurchaseOrderStatus.values
//                       .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
//                       .toList(),
//                   onChanged: (s) => setState(() => status = s!),
//                 ),
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: memoC,
//                   minLines: 2,
//                   maxLines: 5,
//                   decoration: const InputDecoration(labelText: '적요(메모)'),
//                 ),
//                 const SizedBox(height: 20),
//                 FilledButton.icon(
//                   icon: const Icon(Icons.save),
//                   label: Text(t.btn_save),
//                   onPressed: () {
//                     final updated = widget.po.copyWith(
//                       supplierName: supplierC.text, // 빈문자 허용
//                       eta: eta,
//                       status: status,
//                       memo: memoC.text.trim().isEmpty ? null : memoC.text.trim(),
//                     );
//                     Navigator.pop(context, updated);
//                   },
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
//
// class _EditLineSheet extends StatefulWidget {
//   final PurchaseLine? initial;
//   final String orderId;
//   const _EditLineSheet({required this.initial, required this.orderId});
//
//   @override
//   State<_EditLineSheet> createState() => _EditLineSheetState();
// }
//
// class _EditLineSheetState extends State<_EditLineSheet> {
//   late final TextEditingController nameC;
//   late final TextEditingController qtyC;
//   late final TextEditingController priceC;
//   late final TextEditingController memoC;
//
//   @override
//   void initState() {
//     super.initState();
//     final i = widget.initial;
//     nameC = TextEditingController(text: i?.itemName ?? '');
//     qtyC = TextEditingController(text: i?.qty.toString() ?? '1');
//     priceC = TextEditingController(text: i?.unitPrice?.toString() ?? '');
//     memoC = TextEditingController(text: i?.memo ?? '');
//   }
//
//   @override
//   void dispose() {
//     nameC.dispose();
//     qtyC.dispose();
//     priceC.dispose();
//     memoC.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bottom = MediaQuery.of(context).viewInsets.bottom;
//     final isEdit = widget.initial != null;
//     final t = context.t;
//
//     return Padding(
//       padding: EdgeInsets.only(bottom: bottom),
//       child: DraggableScrollableSheet(
//         expand: false,
//         initialChildSize: 0.7,
//         minChildSize: 0.4,
//         maxChildSize: 0.95,
//         builder: (_, controller) {
//           return Material(
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//             child: ListView(
//               controller: controller,
//               padding: const EdgeInsets.all(16),
//               children: [
//                 Text(isEdit ? '라인 편집' : '라인 추가',
//                     style: Theme.of(context).textTheme.titleLarge),
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: nameC,
//                   decoration: const InputDecoration(
//                     labelText: '아이템명',
//                     helperText: '아이템 피커 연동 전 임시 입력',
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: qtyC,
//                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                   decoration: const InputDecoration(labelText: '수량'),
//                 ),
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: priceC,
//                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                   decoration: const InputDecoration(labelText: '단가(선택)'),
//                 ),
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: memoC,
//                   minLines: 1,
//                   maxLines: 4,
//                   decoration: const InputDecoration(labelText: '적요(라인 메모)'),
//                 ),
//                 const SizedBox(height: 20),
//                 FilledButton.icon(
//                   icon: Icon(isEdit ? Icons.save : Icons.add),
//                   label: Text(isEdit ? t.btn_save : t.btn_add),
//                   onPressed: () {
//                     final qty = double.tryParse(qtyC.text.trim()) ?? (widget.initial?.qty ?? 1);
//                     final unitPrice = priceC.text.trim().isEmpty
//                         ? null
//                         : double.tryParse(priceC.text.trim());
//                     final line = (widget.initial ??
//                         PurchaseLine(
//                           id: const Uuid().v4(),
//                           orderId: widget.orderId,
//                           itemId: 'manual', // TODO: 아이템 피커 연동 시 실제 ID로 교체
//                           itemName: nameC.text.trim(),
//                           qty: qty,
//                           unitPrice: unitPrice,
//                           memo: memoC.text.trim().isEmpty ? null : memoC.text.trim(),
//                         )).copyWith(
//                       itemName: nameC.text.trim(),
//                       qty: qty,
//                       unitPrice: unitPrice,
//                       memo: memoC.text.trim().isEmpty ? null : memoC.text.trim(),
//                     );
//                     Navigator.pop(context, line);
//                   },
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
