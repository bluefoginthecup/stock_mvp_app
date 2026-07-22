import 'buyer_profile.dart';
import 'quote_line.dart';

enum QuoteStatus { draft, sent, accepted, canceled }

enum QuoteVatType { exclusive, inclusive, exempt }

class Quote {
  final String id;
  final String customerName;
  final String? customerId;
  final DateTime quoteDate;
  final DateTime? deliveryDate;
  final DateTime? validUntil;
  final QuoteStatus status;
  final String? memo;
  final double discountAmount;
  final double shippingCost;
  final String? deliveryName;
  final String? deliveryPhone;
  final String? deliveryZip;
  final String? deliveryAddress1;
  final String? deliveryAddress2;
  final String? deliveryMemo;
  final QuoteVatType vatType;
  final int? supplierProfileId;
  final String? supplierProfileName;
  final String? supplierBusinessNumber;
  final String? supplierCompanyName;
  final String? supplierRepresentative;
  final String? supplierAddress;
  final String? supplierBusinessType;
  final String? supplierBusinessItem;
  final String? supplierPhoneFax;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Quote({
    required this.id,
    required this.customerName,
    this.customerId,
    required this.quoteDate,
    this.deliveryDate,
    this.validUntil,
    this.status = QuoteStatus.draft,
    this.memo,
    this.discountAmount = 0,
    this.shippingCost = 0,
    this.deliveryName,
    this.deliveryPhone,
    this.deliveryZip,
    this.deliveryAddress1,
    this.deliveryAddress2,
    this.deliveryMemo,
    this.vatType = QuoteVatType.exclusive,
    this.supplierProfileId,
    this.supplierProfileName,
    this.supplierBusinessNumber,
    this.supplierCompanyName,
    this.supplierRepresentative,
    this.supplierAddress,
    this.supplierBusinessType,
    this.supplierBusinessItem,
    this.supplierPhoneFax,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  BuyerProfile get supplierSnapshotProfile {
    final profile = BuyerProfile(
      id: supplierProfileId ?? 1,
      profileName: supplierProfileName ?? '',
      businessNumber: supplierBusinessNumber ?? '',
      companyName: supplierCompanyName ?? '',
      representative: supplierRepresentative ?? '',
      address: supplierAddress ?? '',
      businessType: supplierBusinessType ?? '',
      businessItem: supplierBusinessItem ?? '',
      phoneFax: supplierPhoneFax ?? '',
      isDefault: false,
      updatedAt: updatedAt,
    );
    return profile.isConfigured ? profile : BuyerProfile.fallback();
  }

  Quote copyWithSupplierProfile(BuyerProfile profile) => copyWith(
        supplierProfileId: profile.id,
        supplierProfileName: profile.profileName,
        supplierBusinessNumber: profile.businessNumber,
        supplierCompanyName: profile.companyName,
        supplierRepresentative: profile.representative,
        supplierAddress: profile.address,
        supplierBusinessType: profile.businessType,
        supplierBusinessItem: profile.businessItem,
        supplierPhoneFax: profile.phoneFax,
        updatedAt: DateTime.now(),
      );

  Quote copyWith({
    String? customerName,
    String? customerId,
    DateTime? quoteDate,
    DateTime? deliveryDate,
    DateTime? validUntil,
    QuoteStatus? status,
    String? memo,
    double? discountAmount,
    double? shippingCost,
    String? deliveryName,
    String? deliveryPhone,
    String? deliveryZip,
    String? deliveryAddress1,
    String? deliveryAddress2,
    String? deliveryMemo,
    QuoteVatType? vatType,
    int? supplierProfileId,
    String? supplierProfileName,
    String? supplierBusinessNumber,
    String? supplierCompanyName,
    String? supplierRepresentative,
    String? supplierAddress,
    String? supplierBusinessType,
    String? supplierBusinessItem,
    String? supplierPhoneFax,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      Quote(
        id: id,
        customerName: customerName ?? this.customerName,
        customerId: customerId ?? this.customerId,
        quoteDate: quoteDate ?? this.quoteDate,
        deliveryDate: deliveryDate ?? this.deliveryDate,
        validUntil: validUntil ?? this.validUntil,
        status: status ?? this.status,
        memo: memo ?? this.memo,
        discountAmount: discountAmount ?? this.discountAmount,
        shippingCost: shippingCost ?? this.shippingCost,
        deliveryName: deliveryName ?? this.deliveryName,
        deliveryPhone: deliveryPhone ?? this.deliveryPhone,
        deliveryZip: deliveryZip ?? this.deliveryZip,
        deliveryAddress1: deliveryAddress1 ?? this.deliveryAddress1,
        deliveryAddress2: deliveryAddress2 ?? this.deliveryAddress2,
        deliveryMemo: deliveryMemo ?? this.deliveryMemo,
        vatType: vatType ?? this.vatType,
        supplierProfileId: supplierProfileId ?? this.supplierProfileId,
        supplierProfileName: supplierProfileName ?? this.supplierProfileName,
        supplierBusinessNumber:
            supplierBusinessNumber ?? this.supplierBusinessNumber,
        supplierCompanyName: supplierCompanyName ?? this.supplierCompanyName,
        supplierRepresentative:
            supplierRepresentative ?? this.supplierRepresentative,
        supplierAddress: supplierAddress ?? this.supplierAddress,
        supplierBusinessType: supplierBusinessType ?? this.supplierBusinessType,
        supplierBusinessItem: supplierBusinessItem ?? this.supplierBusinessItem,
        supplierPhoneFax: supplierPhoneFax ?? this.supplierPhoneFax,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        isDeleted: isDeleted ?? this.isDeleted,
      );
}

class QuoteTotals {
  final double subtotal;
  final double discount;
  final double shipping;
  final double vat;
  final double total;

  const QuoteTotals({
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.vat,
    required this.total,
  });

  factory QuoteTotals.from({
    required Quote quote,
    required double linesSubtotal,
  }) {
    final discount = quote.discountAmount < 0 ? 0.0 : quote.discountAmount;
    final shipping = quote.shippingCost < 0 ? 0.0 : quote.shippingCost;
    final taxableBase =
        (linesSubtotal - discount + shipping).clamp(0.0, double.infinity);
    final vat =
        quote.vatType == QuoteVatType.exclusive ? taxableBase * 0.1 : 0.0;
    return QuoteTotals(
      subtotal: linesSubtotal,
      discount: discount,
      shipping: shipping,
      vat: vat,
      total: taxableBase + vat,
    );
  }

  factory QuoteTotals.fromLines({
    required Quote quote,
    required List<QuoteLine> lines,
  }) {
    final discount = quote.discountAmount < 0 ? 0.0 : quote.discountAmount;
    final shipping = quote.shippingCost < 0 ? 0.0 : quote.shippingCost;
    final subtotal = lines.fold<double>(
      0,
      (sum, line) => sum + line.supplyAmount,
    );
    final vat = lines.fold<double>(0, (sum, line) => sum + line.vatAmount);
    final lineTotal =
        lines.fold<double>(0, (sum, line) => sum + line.totalAmount);
    return QuoteTotals(
      subtotal: subtotal,
      discount: discount,
      shipping: shipping,
      vat: vat,
      total: (lineTotal - discount + shipping).clamp(0.0, double.infinity),
    );
  }
}
