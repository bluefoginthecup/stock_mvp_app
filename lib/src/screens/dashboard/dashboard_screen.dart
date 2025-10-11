// // screens/dashboard/dashboard_screen.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../repos/views.dart';
// import '../../metrics/stock_metrics.dart';
//
// class DashboardScreen extends StatelessWidget {
//   const DashboardScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Consumer3<TxnRepoView, WorkRepoView, PurchaseRepoView>(
//       builder: (_, txns, works, purchases, __) {
//         final m = StockMetrics(txns, works, purchases);
//         final today = DateTime.now();
//
//         return Scaffold(
//           appBar: AppBar(title: const Text('대시보드')),
//           body: ListView(
//             padding: const EdgeInsets.all(12),
//             children: [
//               _StatCard(title: '실제 입고 합계(최근 전체)', value: m.recentInActual.toString()),
//               _StatCard(title: '실제 출고 합계(최근 전체)', value: m.recentOutActual.toString()),
//               _StatCard(title: '예정 입고(Planned)', value: m.plannedInbound.toString()),
//               const SizedBox(height: 8),
//               _SectionTitle('작업/발주 진행 현황'),
//               _Row2(
//                 left:  _StatCard(title: '작업 예정/진행', value: m.worksPlanned.toString()),
//                 right: _StatCard(title: '오늘 완료된 작업', value: m.worksDoneToday(today).toString()),
//               ),
//               _Row2(
//                 left:  _StatCard(title: '발주 예정/주문', value: m.purchasesPlanned.toString()),
//                 right: _StatCard(title: '오늘 입고 완료', value: m.purchasesReceivedToday(today).toString()),
//               ),
//               const SizedBox(height: 12),
//               FilledButton(
//                 onPressed: (){
//                   // TODO: Txn/Work/Purchase 상세 리스트로 네비게이션
//                 },
//                 child: const Text('상세 보기 / 필터로 이동'),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
//
// class _StatCard extends StatelessWidget {
//   final String title;
//   final String value;
//   const _StatCard({required this.title, required this.value});
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(14.0),
//         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text(title, style: Theme.of(context).textTheme.labelLarge),
//           const SizedBox(height: 8),
//           Text(value, style: Theme.of(context).textTheme.headlineMedium),
//         ]),
//       ),
//     );
//   }
// }
//
// class _SectionTitle extends StatelessWidget {
//   final String text;
//   const _SectionTitle(this.text);
//   @override
//   Widget build(BuildContext context) => Padding(
//     padding: const EdgeInsets.symmetric(vertical: 6),
//     child: Text(text, style: Theme.of(context).textTheme.titleLarge),
//   );
// }
//
// class _Row2 extends StatelessWidget {
//   final Widget left, right;
//   const _Row2({required this.left, required this.right});
//   @override
//   Widget build(BuildContext context) => Row(
//     children: [
//       Expanded(child: left),
//       Expanded(child: right),
//     ],
//   );
// }
