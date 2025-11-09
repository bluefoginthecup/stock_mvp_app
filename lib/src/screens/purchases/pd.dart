// // lib/src/screens/purchases/purchase_detail_screen.dart
// import 'package:uuid/uuid.dart';
//
// import '../../repos/repo_interfaces.dart';
// import '../../models/purchase_order.dart';
// import '../../models/purchase_line.dart';
// import '../../ui/common/ui.dart';
// import 'widgets/purchase_print_action.dart';
// import 'package:provider/provider.dart';     // ⬅️ context.read 확장자
// import '../../repos/inmem_repo.dart';         // ⬅️ InMemoryRepo 타입
// import '../../services/inventory_service.dart';
//
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
//       case PurchaseOrderStatus.draft:    return '임시저장';
//       case PurchaseOrderStatus.ordered:  return '발주완료';
//       case PurchaseOrderStatus.received: return '입고완료';
//       case PurchaseOrderStatus.canceled: return '발주취소';
//     }
//   }
//
//   Future<void> _editHeader() async {
//     if (_po == null) return;
//     if (_po == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('발주서를 불러오는 중입니다')),
//       );
//       return;
//     }
//     final updated = await showModalBottomSheet<PurchaseOrder>(
//       context: context,
//       isScrollControlled: true,
//       builder: (_) => _EditHeaderSheet(po: _po!),
//     );
//     if (updated != null) {
//       await widget.repo.updatePurchaseOrder(updated);
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다')));
//       await _reload();
//     }
//   }
//
//   Future<void> _addLine() async {
//     if (_po == null) return;
//     // 추가
//     final created = await showModalBottomSheet<PurchaseLine>(
//       context: context,
//       isScrollControlled: true,
//       builder: (_) => _EditLineSheet(initial: null, orderId: widget.orderId),
//     );
//     if (created != null) {
//       final next = [..._lines, created];
//       await widget.repo.upsertLines(widget.orderId, next);
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('추가되었습니다')));
//       await _reload();
//     }
//   }
//
//   Future<void> _editLine(PurchaseLine line) async {
//     // 편집
//     final edited = await showModalBottomSheet<PurchaseLine>(
//       context: context,
//       isScrollControlled: true,
//       builder: (_) => _EditLineSheet(initial: line, orderId: widget.orderId),
//     );
//     if (edited != null) {
//       final next = _lines.map((e) => e.id == edited.id ? edited : e).toList();
//       await widget.repo.upsertLines(widget.orderId, next);
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다')));
//       await _reload();
//     }
//   }
//
//   Future<void> _removeLine(PurchaseLine line) async {
//     final ok = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(context.t.common_delete),
//         content: Text('${line.name} 삭제할까요?'),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t.common_cancel)),
//           FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.t.common_delete)),
//         ],
//       ),
//     );
//     if (ok != true) return;
//
//     final next = _lines.where((e) => e.id != line.id).toList();
//     await widget.repo.upsertLines(widget.orderId, next);
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제되었습니다')));
//     await _reload();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final po = _po;
//     final t = context.t;
//     final itemRepo = context.read<InMemoryRepo>(); // ⬅️ 추가
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(t.purchase_detail_title),
//         actions: [
//           IconButton(
//             onPressed: _editHeader,
//             icon: const Icon(Icons.edit),
//             tooltip: '헤더 편집',
//           ),
//           PurchasePrintAction(poId: widget.orderId), // ✅ PDF 보기
//         ],
//       ),
//       floatingActionButton: FloatingActionButton.extended(
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
//                     onDismissed: (_) async => _removeLine(ln),
//                     child: ListTile(
//                       title: Text(// 있으면 name, 없으면 itemRepo로 보강
//                         (ln.name.trim().isNotEmpty)
//                             ? '${ln.name} × ${ln.qty} ${ln.unit}'
//                             : '${(itemRepo.getItemById(ln.itemId)?.displayName ?? ln.itemId)} × ${ln.qty} ${ln.unit}',
//                       ),
//                       // unitPrice/메모 필드 미사용(모델에 없음)
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
//                 if (po.status == PurchaseOrderStatus.draft && next == PurchaseOrderStatus.ordered) {
//                   await context.read<InventoryService>().orderPurchase(po.id);
//                   if (!mounted) return;
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('발주완료: 예정 입고 기록 생성됨')),
//                   );
//                   await _reload();
//                 } else if (po.status == PurchaseOrderStatus.ordered && next == PurchaseOrderStatus.received) {
//                   await context.read<InventoryService>().receivePurchase(po.id);
//                   if (!mounted) return;
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('입고 완료: 입출고기록 생성 및 재고 반영됨')),
//                   );
//                   await _reload();
//                 }
//               },
//               onCancel: po.status == PurchaseOrderStatus.received
//                   ? null
//                   : () async {
//                 // ✅ 예정입고 롤백 + 상태전환을 서비스에서 일괄 처리
//                 await context.read<InventoryService>().cancelPurchase(po.id);
//                 if (!mounted) return;
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('발주 취소: 예정 입고 기록이 정리되었습니다')),
//                 );
//                 await _reload();
//               },
//               labelForAdvance: switch (po.status) {
//                 PurchaseOrderStatus.draft   => t.purchase_action_order,
//                 PurchaseOrderStatus.ordered => t.purchase_action_receive,
//                 _                           => t.purchase_already_received,
//               },
//               cancelLabel: t.common_cancel,
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
//           Text('발주ID: ${po.id}'),
//           Text('입고예정일: ${po.eta.toLocal()}'.split('.').first),
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
//   final String cancelLabel;
//   const _ActionRow({
//     required this.status,
//     required this.onAdvance,
//     required this.onCancel,
//     required this.labelForAdvance,
//     required this.cancelLabel,
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
//             child: Text(cancelLabel),
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
//                       supplierName: supplierC.text,
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
//   late final TextEditingController itemIdC; // ✅ 추가
//   late final TextEditingController nameC;
//   late final TextEditingController unitC;
//   late final TextEditingController qtyC;
//   final TextEditingController colorNoC = TextEditingController();
//
//
//   @override
//   void initState() {
//     super.initState();
//     final i = widget.initial;
//     itemIdC = TextEditingController(text: i?.itemId ?? '');   // ✅ 추가
//     nameC   = TextEditingController(text: i?.name ?? '');
//     unitC   = TextEditingController(text: i?.unit ?? 'EA');
//     qtyC    = TextEditingController(text: i?.qty.toString() ?? '1');
//     colorNoC.text = i?.colorNo ?? '';
//
//   }
//
//   @override
//   void dispose() {
//     itemIdC.dispose(); // ✅ 추가
//     nameC.dispose();
//     unitC.dispose();
//     qtyC.dispose();
//     colorNoC.dispose(); // ✅ 추가
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
//
//                 // ✅ itemId 입력
//                 TextField(
//                   controller: itemIdC,
//                   decoration: const InputDecoration(
//                     labelText: '아이템 ID(itemId)',
//                     helperText: '예: it_rouen_gray_cc_50',
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//
//                 TextField(
//                   controller: nameC,
//                   decoration: const InputDecoration(
//                     labelText: '아이템명(name)',
//                     helperText: '아이템 피커 연동 전 임시 입력',
//                   ),
//                 ),
//
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: colorNoC,
//                   decoration: const InputDecoration(
//                     labelText: '색상번호(colorNo)',
//                     helperText: '예: 01, 2, 014N 등',
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: unitC,
//                   decoration: const InputDecoration(labelText: '단위(unit, 예: EA/M/ROLL)'),
//                 ),
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: qtyC,
//                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                   decoration: const InputDecoration(labelText: '수량(qty)'),
//                 ),
//                 const SizedBox(height: 20),
//                 FilledButton.icon(
//                   icon: Icon(isEdit ? Icons.save : Icons.add),
//                   label: Text(isEdit ? t.btn_save : t.btn_add),
//                   onPressed: () {
//                     final qty = double.tryParse(qtyC.text.trim()) ?? (widget.initial?.qty ?? 1);
//
//                     // ✅ itemId 필수 포함해서 생성
//                     final line = PurchaseLine(
//                       id: widget.initial?.id ?? const Uuid().v4(),
//                       orderId: widget.orderId,
//                       itemId: itemIdC.text.trim(),   // ✅ 추가
//                       name: nameC.text.trim(),
//                       unit: unitC.text.trim(),
//                       qty: qty,
//                       colorNo: colorNoC.text.trim(),
//
//                     );
//
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
//
//
