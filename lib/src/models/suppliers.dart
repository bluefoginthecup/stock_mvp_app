class Supplier {
  final String id;
  final String name;
  final String? contactName, phone, email, addr, memo;
  final bool isActive;
  final DateTime createdAt, updatedAt;
  const Supplier({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.addr,
    this.memo,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Supplier copyWith({
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? addr,
    String? memo,
    bool? isActive,
    DateTime? updatedAt,
  }) => Supplier(
    id: id,
    name: name ?? this.name,
    contactName: contactName ?? this.contactName,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    addr: addr ?? this.addr,
    memo: memo ?? this.memo,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );
}
