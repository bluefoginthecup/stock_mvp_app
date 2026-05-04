import 'buyer_profile.dart';

enum QuoteStatus { draft, sent, accepted, canceled }

enum QuoteVatType { exclusive, inclusive, exempt }

class Quote {
  final String id;
  final String customerName;
  final String? customerId;
  final DateTime quoteDate;
  final DateTime? validUntil;
  final QuoteStatus status;
  final String? memo;
  final double discountAmount;
  final double shippingCost;
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
    this.validUntil,
    this.status = QuoteStatus.draft,
    this.memo,
    this.discountAmount = 0,
    this.shippingCost = 0,
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
    DateTime? validUntil,
    QuoteStatus? status,
    String? memo,
    double? discountAmount,
    double? shippingCost,
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
        validUntil: validUntil ?? this.validUntil,
        status: status ?? this.status,
        memo: memo ?? this.memo,
        discountAmount: discountAmount ?? this.discountAmount,
        shippingCost: shippingCost ?? this.shippingCost,
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
}
