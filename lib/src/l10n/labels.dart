import 'package:flutter/widgets.dart';
import '../l10n/l10n.dart';
import '../models/types.dart';

class Labels {
  static String workStatus(BuildContext c, WorkStatus s) {
    final t = L10n.of(c);
    switch (s) {
    case WorkStatus.planned:    return t.work_status_planned;
    case WorkStatus.inProgress: return t.work_status_in_progress;
    case WorkStatus.done:       return t.work_status_done;
    case WorkStatus.canceled:   return t.work_status_canceled;
    }
  }

  static String purchaseStatus(BuildContext c, PurchaseStatus s) {
    final t = L10n.of(c);
    final n = s.name.toLowerCase();
    if (n == 'planned') return t.purchase_status_planned;
    if (n == 'inprogress' || n == 'in_progress' || n == 'progress') return t.purchase_status_in_progress;
    if (n == 'done' || n == 'completed' || n == 'received') return t.purchase_status_done;
    if (n == 'canceled' || n == 'cancelled') return t.purchase_status_canceled;

    return s.name;
  }

  static String txnType(BuildContext c, TxnType v) => v.name;
}
