// // metrics/stock_metrics.dart
// import '../repos/views.dart';
// import '../models/txn.dart';
// import '../models/work.dart';
// import '../models/purchase.dart';
// import '../models/types.dart';
//
// class StockMetrics {
//   final TxnRepoView txnView;
//   final WorkRepoView workView;
//   final PurchaseRepoView purchaseView;
//
//   StockMetrics(this.txnView, this.workView, this.purchaseView);
//
//   int get recentInActual => txnView.all.where((t)=>t.type==TxnType.in_ && t.status==TxnStatus.actual).fold(0,(a,b)=>a+b.qty);
//   int get recentOutActual => txnView.all.where((t)=>t.type==TxnType.out_ && t.status==TxnStatus.actual).fold(0,(a,b)=>a+b.qty);
//
//   int get plannedInbound   => txnView.all.where((t)=>t.type==TxnType.in_ && t.status==TxnStatus.planned).fold(0,(a,b)=>a+b.qty);
//
//   int get worksPlanned     => workView.all.where((w)=>w.status==WorkStatus.planned || w.status==WorkStatus.inProgress).length;
//   int get worksDoneToday(DateTime day){
//     final s = DateTime(day.year,day.month,day.day);
//     final e = s.add(const Duration(days:1));
//     return workView.all.where((w)=>w.status==WorkStatus.done && w.completedAt!=null && w.completedAt!.isAfter(s)&&w.completedAt!.isBefore(e)).length;
//   }
//
//   int get purchasesPlanned => purchaseView.all.where((p)=>p.status==PurchaseStatus.planned || p.status==PurchaseStatus.ordered).length;
//   int get purchasesReceivedToday(DateTime day){
//     final s = DateTime(day.year,day.month,day.day);
//     final e = s.add(const Duration(days:1));
//     return purchaseView.all.where((p)=>p.status==PurchaseStatus.received && p.receivedAt!=null && p.receivedAt!.isAfter(s)&&p.receivedAt!.isBefore(e)).length;
//   }
// }
