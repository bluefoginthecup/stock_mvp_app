import 'types.dart';
import 'buyer_profile.dart';
import 'extensions/payment_status_ext.dart';
import 'extensions/vat_invoice_status_ext.dart';

enum PurchaseOrderStatus { draft, ordered, received, canceled }

enum VatType {
  exclusive, // 부가세 별도
  inclusive, // 부가세 포함
  exempt, // 면세
}

class PurchaseOrder {
  final String id;
  final String supplierName;
  final String? supplierId;
  final DateTime eta; // 예상 입고(2단계 점선에 사용)
  final PurchaseOrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String? memo;
  final String? deliveryName;
  final String? deliveryAddress;
  final String? deliveryPhone;
  final String? deliveryMemo;
  final bool showDeliveryOnPrint;
  final int? buyerProfileId;
  final String? buyerProfileName;
  final String? buyerBusinessNumber;
  final String? buyerCompanyName;
  final String? buyerRepresentative;
  final String? buyerAddress;
  final String? buyerBusinessType;
  final String? buyerBusinessItem;
  final String? buyerPhoneFax;

  // ✅ 추가
  final String? orderId; // 주문 연동 발주만 주문 상세 타임라인에 표시
  final DateTime? receivedAt; // 실제 입고 완료일(막대 종료)
  final double shippingCost;
  final double extraCost;
  final VatType vatType;

  final String paymentStatus;
  final DateTime? paidAt;
  final DateTime? paymentDueAt;

  final String vatInvoiceStatus;
  final DateTime? vatInvoiceIssuedAt;
  final DateTime? vatInvoiceDueAt;

  PaymentStatus get paymentStatusEnum => PaymentStatusX.from(paymentStatus);

  VatInvoiceStatus get vatInvoiceStatusEnum =>
      VatInvoiceStatusX.from(vatInvoiceStatus);

  BuyerProfile get buyerSnapshotProfile {
    final profile = BuyerProfile(
      id: buyerProfileId ?? 1,
      profileName: buyerProfileName ?? '',
      businessNumber: buyerBusinessNumber ?? '',
      companyName: buyerCompanyName ?? '',
      representative: buyerRepresentative ?? '',
      address: buyerAddress ?? '',
      businessType: buyerBusinessType ?? '',
      businessItem: buyerBusinessItem ?? '',
      phoneFax: buyerPhoneFax ?? '',
      isDefault: false,
      updatedAt: updatedAt,
    );
    return profile.isConfigured ? profile : BuyerProfile.fallback();
  }

  PurchaseOrder copyWithBuyerProfile(BuyerProfile profile) => copyWith(
        buyerProfileId: profile.id,
        buyerProfileName: profile.profileName,
        buyerBusinessNumber: profile.businessNumber,
        buyerCompanyName: profile.companyName,
        buyerRepresentative: profile.representative,
        buyerAddress: profile.address,
        buyerBusinessType: profile.businessType,
        buyerBusinessItem: profile.businessItem,
        buyerPhoneFax: profile.phoneFax,
        updatedAt: DateTime.now(),
      );

  PurchaseOrder({
    required this.id,
    required this.supplierName,
    required this.eta,
    this.status = PurchaseOrderStatus.draft,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.memo,
    this.deliveryName,
    this.deliveryAddress,
    this.deliveryPhone,
    this.deliveryMemo,
    this.showDeliveryOnPrint = false,
    this.buyerProfileId,
    this.buyerProfileName,
    this.buyerBusinessNumber,
    this.buyerCompanyName,
    this.buyerRepresentative,
    this.buyerAddress,
    this.buyerBusinessType,
    this.buyerBusinessItem,
    this.buyerPhoneFax,
    this.orderId,
    this.receivedAt,
    this.supplierId,
    this.shippingCost = 0,
    this.extraCost = 0,
    this.vatType = VatType.exclusive,
    this.paymentStatus = 'unpaid',
    this.paidAt,
    this.paymentDueAt,
    this.vatInvoiceStatus = 'pending',
    this.vatInvoiceIssuedAt,
    this.vatInvoiceDueAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PurchaseOrder copyWith({
    String? supplierName,
    DateTime? eta,
    PurchaseOrderStatus? status,
    bool? isDeleted,
    DateTime? updatedAt,
    String? memo,
    String? deliveryName,
    String? deliveryAddress,
    String? deliveryPhone,
    String? deliveryMemo,
    bool? showDeliveryOnPrint,
    int? buyerProfileId,
    String? buyerProfileName,
    String? buyerBusinessNumber,
    String? buyerCompanyName,
    String? buyerRepresentative,
    String? buyerAddress,
    String? buyerBusinessType,
    String? buyerBusinessItem,
    String? buyerPhoneFax,
    String? orderId,
    DateTime? receivedAt,
    String? supplierId,
    double? shippingCost,
    double? extraCost,
    VatType? vatType,
    String? paymentStatus,
    DateTime? paidAt,
    DateTime? paymentDueAt,
    String? vatInvoiceStatus,
    DateTime? vatInvoiceIssuedAt,
    DateTime? vatInvoiceDueAt,
    DateTime? createdAt,
  }) =>
      PurchaseOrder(
        id: id,
        supplierName: supplierName ?? this.supplierName,
        eta: eta ?? this.eta,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        isDeleted: isDeleted ?? this.isDeleted,
        memo: memo ?? this.memo,
        deliveryName: deliveryName ?? this.deliveryName,
        deliveryAddress: deliveryAddress ?? this.deliveryAddress,
        deliveryPhone: deliveryPhone ?? this.deliveryPhone,
        deliveryMemo: deliveryMemo ?? this.deliveryMemo,
        showDeliveryOnPrint: showDeliveryOnPrint ?? this.showDeliveryOnPrint,
        buyerProfileId: buyerProfileId ?? this.buyerProfileId,
        buyerProfileName: buyerProfileName ?? this.buyerProfileName,
        buyerBusinessNumber: buyerBusinessNumber ?? this.buyerBusinessNumber,
        buyerCompanyName: buyerCompanyName ?? this.buyerCompanyName,
        buyerRepresentative: buyerRepresentative ?? this.buyerRepresentative,
        buyerAddress: buyerAddress ?? this.buyerAddress,
        buyerBusinessType: buyerBusinessType ?? this.buyerBusinessType,
        buyerBusinessItem: buyerBusinessItem ?? this.buyerBusinessItem,
        buyerPhoneFax: buyerPhoneFax ?? this.buyerPhoneFax,
        orderId: orderId ?? this.orderId,
        receivedAt: receivedAt ?? this.receivedAt,
        supplierId: supplierId ?? this.supplierId,
        shippingCost: shippingCost ?? this.shippingCost,
        extraCost: extraCost ?? this.extraCost,
        vatType: vatType ?? this.vatType,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        paidAt: paidAt ?? this.paidAt,
        paymentDueAt: paymentDueAt ?? this.paymentDueAt,
        vatInvoiceStatus: vatInvoiceStatus ?? this.vatInvoiceStatus,
        vatInvoiceIssuedAt: vatInvoiceIssuedAt ?? this.vatInvoiceIssuedAt,
        vatInvoiceDueAt: vatInvoiceDueAt ?? this.vatInvoiceDueAt,
      );

  factory PurchaseOrder.fromJson(Map<String, dynamic> j) => PurchaseOrder(
        id: j['id'] as String,
        supplierName: j['supplierName'] as String? ?? '',
        eta: DateTime.parse(j['eta'] as String),
        status:
            PurchaseOrderStatus.values.firstWhere((e) => e.name == j['status']),
        createdAt: DateTime.parse(j['createdAt']),
        updatedAt: DateTime.parse(j['updatedAt']),
        isDeleted: j['isDeleted'] == true,
        memo: j['memo'] as String?,
        deliveryName: j['deliveryName'] as String?,
        deliveryAddress: j['deliveryAddress'] as String?,
        deliveryPhone: j['deliveryPhone'] as String?,
        deliveryMemo: j['deliveryMemo'] as String?,
        showDeliveryOnPrint: j['showDeliveryOnPrint'] == true,
        buyerProfileId: (j['buyerProfileId'] as num?)?.toInt(),
        buyerProfileName: j['buyerProfileName'] as String?,
        buyerBusinessNumber: j['buyerBusinessNumber'] as String?,
        buyerCompanyName: j['buyerCompanyName'] as String?,
        buyerRepresentative: j['buyerRepresentative'] as String?,
        buyerAddress: j['buyerAddress'] as String?,
        buyerBusinessType: j['buyerBusinessType'] as String?,
        buyerBusinessItem: j['buyerBusinessItem'] as String?,
        buyerPhoneFax: j['buyerPhoneFax'] as String?,
        orderId: j['orderId'] as String?, // ✅
        receivedAt: (j['receivedAt'] as String?) != null // ✅
            ? DateTime.parse(j['receivedAt'])
            : null,
        supplierId: j['supplierId']?.toString(),
        shippingCost: (j['shippingCost'] as num?)?.toDouble() ?? 0,
        extraCost: (j['extraCost'] as num?)?.toDouble() ?? 0,
        vatType: VatType.values[j['vatType'] ?? 0],
        paymentStatus: j['paymentStatus'] as String? ?? 'pending',
        paidAt: (j['paidAt'] as String?) != null
            ? DateTime.parse(j['paidAt'])
            : null,
        vatInvoiceStatus: j['vatInvoiceStatus'] as String? ?? 'pending',
        vatInvoiceIssuedAt: (j['vatInvoiceIssuedAt'] as String?) != null
            ? DateTime.parse(j['vatInvoiceIssuedAt'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplierName': supplierName,
        'eta': eta.toIso8601String(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDeleted': isDeleted,
        'memo': memo,
        'deliveryName': deliveryName,
        'deliveryAddress': deliveryAddress,
        'deliveryPhone': deliveryPhone,
        'deliveryMemo': deliveryMemo,
        'showDeliveryOnPrint': showDeliveryOnPrint,
        'buyerProfileId': buyerProfileId,
        'buyerProfileName': buyerProfileName,
        'buyerBusinessNumber': buyerBusinessNumber,
        'buyerCompanyName': buyerCompanyName,
        'buyerRepresentative': buyerRepresentative,
        'buyerAddress': buyerAddress,
        'buyerBusinessType': buyerBusinessType,
        'buyerBusinessItem': buyerBusinessItem,
        'buyerPhoneFax': buyerPhoneFax,
        'orderId': orderId, // ✅
        'receivedAt': receivedAt?.toIso8601String(), // ✅
        'supplierId': supplierId,
        'shippingCost': shippingCost,
        'extraCost': extraCost,
        'vatType': vatType.index,
        'paymentStatus': paymentStatus,
        'paidAt': paidAt?.toIso8601String(),
        'vatInvoiceStatus': vatInvoiceStatus,
        'vatInvoiceIssuedAt': vatInvoiceIssuedAt?.toIso8601String(),
      };
}
