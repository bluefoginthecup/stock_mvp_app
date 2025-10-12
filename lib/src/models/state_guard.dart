import '../models/types.dart';

bool canTransitionWork(WorkStatus from, WorkStatus to) {
  switch (from) {
    case WorkStatus.planned:
      return to == WorkStatus.inProgress || to == WorkStatus.canceled;
    case WorkStatus.inProgress:
      return to == WorkStatus.done || to == WorkStatus.canceled;
    case WorkStatus.done:
    case WorkStatus.canceled:
      return false;
  }
}

bool canTransitionPurchase(PurchaseStatus from, PurchaseStatus to) {
  switch (from) {
    case PurchaseStatus.planned:
      return to == PurchaseStatus.ordered || to == PurchaseStatus.canceled;
    case PurchaseStatus.ordered:
      return to == PurchaseStatus.received || to == PurchaseStatus.canceled;
    case PurchaseStatus.received:
    case PurchaseStatus.canceled:
      return false;
  }
}
