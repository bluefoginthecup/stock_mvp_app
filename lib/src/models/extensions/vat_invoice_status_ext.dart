import '../types.dart';
import '../../ui/common/ui.dart';

extension VatInvoiceStatusX on VatInvoiceStatus {
  String get value => name;

  static VatInvoiceStatus from(String? s) {
    return VatInvoiceStatus.values.firstWhere(
          (e) => e.name == s,
      orElse: () => VatInvoiceStatus.pending,
    );
  }

  String label(BuildContext context) {
    final t = context.t;

    switch (this) {
      case VatInvoiceStatus.pending:
        return t.vat_pending;
      case VatInvoiceStatus.issued:
        return t.vat_issued;
    }
  }
}