import 'purchase_order.dart';
import '../utils/line_amount_calculator.dart';

class QuoteLine {
  final String id;
  final String quoteId;
  final String itemId;
  final String name;
  final String unit;
  final double qty;
  final double unitPrice;
  final VatType vatType;
  final double supplyAmount;
  final double vatAmount;
  final double totalAmount;
  final bool amountEdited;
  final String? memo;

  QuoteLine({
    required this.id,
    required this.quoteId,
    required this.itemId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    this.vatType = VatType.exclusive,
    double? supplyAmount,
    double? vatAmount,
    double? totalAmount,
    this.amountEdited = false,
    this.memo,
  })  : supplyAmount = supplyAmount ??
            LineAmountCalculator.calculate(
              unitPrice: unitPrice,
              qty: qty,
              vatType: vatType,
            ).supplyAmount,
        vatAmount = vatAmount ??
            LineAmountCalculator.calculate(
              unitPrice: unitPrice,
              qty: qty,
              vatType: vatType,
            ).vatAmount,
        totalAmount = totalAmount ??
            LineAmountCalculator.calculate(
              unitPrice: unitPrice,
              qty: qty,
              vatType: vatType,
            ).totalAmount;

  double get amount => totalAmount;

  QuoteLine copyWith({
    String? itemId,
    String? name,
    String? unit,
    double? qty,
    double? unitPrice,
    VatType? vatType,
    double? supplyAmount,
    double? vatAmount,
    double? totalAmount,
    bool? amountEdited,
    String? memo,
  }) {
    final nextQty = qty ?? this.qty;
    final nextUnitPrice = unitPrice ?? this.unitPrice;
    final nextVatType = vatType ?? this.vatType;
    final nextAmountEdited = amountEdited ?? this.amountEdited;
    final autoAmount = nextAmountEdited
        ? null
        : LineAmountCalculator.calculate(
            unitPrice: nextUnitPrice,
            qty: nextQty,
            vatType: nextVatType,
          );
    return QuoteLine(
      id: id,
      quoteId: quoteId,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      qty: nextQty,
      unitPrice: nextUnitPrice,
      vatType: nextVatType,
      supplyAmount:
          supplyAmount ?? autoAmount?.supplyAmount ?? this.supplyAmount,
      vatAmount: vatAmount ?? autoAmount?.vatAmount ?? this.vatAmount,
      totalAmount: totalAmount ?? autoAmount?.totalAmount ?? this.totalAmount,
      amountEdited: nextAmountEdited,
      memo: memo ?? this.memo,
    );
  }
}
