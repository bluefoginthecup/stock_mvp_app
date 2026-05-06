class ShippingDestination {
  final String id;
  final String name;
  final String address;
  final String? contactName;
  final String? phone;
  final String? memo;
  final String? mapImagePath;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShippingDestination({
    required this.id,
    required this.name,
    required this.address,
    this.contactName,
    this.phone,
    this.memo,
    this.mapImagePath,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  ShippingDestination copyWith({
    String? name,
    String? address,
    String? contactName,
    String? phone,
    String? memo,
    String? mapImagePath,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return ShippingDestination(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      memo: memo ?? this.memo,
      mapImagePath: mapImagePath ?? this.mapImagePath,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SupplierShippingDestinationLink {
  final String supplierId;
  final String shippingDestinationId;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplierShippingDestinationLink({
    required this.supplierId,
    required this.shippingDestinationId,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });
}
