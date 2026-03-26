
import '../types.dart';
import '../../ui/common/ui.dart';

extension PaymentStatusX on PaymentStatus {
  String get value => name;

  static PaymentStatus from(String? s) {
    return PaymentStatus.values.firstWhere(
          (e) => e.name == s,
      orElse: () => PaymentStatus.unpaid,
    );
  }

  String label(BuildContext context) {
    final t = context.t;

    switch (this) {
      case PaymentStatus.unpaid:
        return t.payment_unpaid;
      case PaymentStatus.paid:
        return t.payment_paid;
      case PaymentStatus.partial:
        return t.payment_partial;
    }
  }
}