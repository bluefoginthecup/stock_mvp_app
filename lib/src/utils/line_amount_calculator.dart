import '../models/purchase_order.dart';

class LineAmountBreakdown {
  final double supplyAmount;
  final double vatAmount;
  final double totalAmount;

  const LineAmountBreakdown({
    required this.supplyAmount,
    required this.vatAmount,
    required this.totalAmount,
  });
}

class LineAmountCalculator {
  const LineAmountCalculator._();

  static LineAmountBreakdown calculate({
    required double unitPrice,
    required double qty,
    required VatType vatType,
  }) {
    final base = (unitPrice * qty).roundToDouble();
    if (base <= 0) {
      return const LineAmountBreakdown(
        supplyAmount: 0,
        vatAmount: 0,
        totalAmount: 0,
      );
    }

    switch (vatType) {
      case VatType.exclusive:
        final vat = (base * 0.1).roundToDouble();
        return LineAmountBreakdown(
          supplyAmount: base,
          vatAmount: vat,
          totalAmount: base + vat,
        );
      case VatType.inclusive:
        final vat = (base / 11).roundToDouble();
        return LineAmountBreakdown(
          supplyAmount: base - vat,
          vatAmount: vat,
          totalAmount: base,
        );
      case VatType.exempt:
        return LineAmountBreakdown(
          supplyAmount: base,
          vatAmount: 0,
          totalAmount: base,
        );
    }
  }
}
