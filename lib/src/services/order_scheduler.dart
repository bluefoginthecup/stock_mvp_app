// // services/order_scheduler.dart
// import 'dart:async';
// import '../services/order_planning_service.dart';
//
// class OrderScheduler {
//   final OrderPlanningService svc;
//   Timer? _timer;
//   final Duration interval;
//   OrderScheduler(this.svc, {this.interval = const Duration(minutes: 15)});
//
//   void start(){
//     _timer?.cancel();
//     _timer = Timer.periodic(interval, (_) async {
//       await svc.autoCompleteIfConditionsMet(); // 조건 기반 완료 처리(예: 모든 하위 완료, ETA 경과 등)
//     });
//   }
//   void stop(){ _timer?.cancel(); }
// }
