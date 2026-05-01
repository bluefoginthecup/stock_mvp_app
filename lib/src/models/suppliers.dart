class Supplier {
  final String id;
  final String name;
  final String? contactName, phone, email, addr, memo;
  final String? fax;
  final String? businessNumber;
  final String? representative;
  final String? businessType;
  final String? businessItem;
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
    this.fax,
    this.businessNumber,
    this.representative,
    this.businessType,
    this.businessItem,
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
    String? fax,
    String? businessNumber,
    String? representative,
    String? businessType,
    String? businessItem,
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
    fax: fax ?? this.fax,
    businessNumber: businessNumber ?? this.businessNumber,
    representative: representative ?? this.representative,
    businessType: businessType ?? this.businessType,
    businessItem: businessItem ?? this.businessItem,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

class SupplierContact {
  final String id;
  final String supplierId;
  final String name;
  final String? roleOrMemo;
  final String? phone;
  final String? fax;
  final String? email;
  final String? address;
  final bool isPrimary;
  final int sortOrder;

  const SupplierContact({
    required this.id,
    required this.supplierId,
    required this.name,
    this.roleOrMemo,
    this.phone,
    this.fax,
    this.email,
    this.address,
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  SupplierContact copyWith({
    String? id,
    String? supplierId,
    String? name,
    String? roleOrMemo,
    String? phone,
    String? fax,
    String? email,
    String? address,
    bool? isPrimary,
    int? sortOrder,
  }) =>
      SupplierContact(
        id: id ?? this.id,
        supplierId: supplierId ?? this.supplierId,
        name: name ?? this.name,
        roleOrMemo: roleOrMemo ?? this.roleOrMemo,
        phone: phone ?? this.phone,
        fax: fax ?? this.fax,
        email: email ?? this.email,
        address: address ?? this.address,
        isPrimary: isPrimary ?? this.isPrimary,
        sortOrder: sortOrder ?? this.sortOrder,
  );
}

class SupplierAccount {
  final String id;
  final String supplierId;
  final String bankName;
  final String accountNumber;
  final String? accountHolder;
  final String? memo;
  final bool isPrimary;
  final int sortOrder;

  const SupplierAccount({
    required this.id,
    required this.supplierId,
    required this.bankName,
    required this.accountNumber,
    this.accountHolder,
    this.memo,
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  SupplierAccount copyWith({
    String? id,
    String? supplierId,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? memo,
    bool? isPrimary,
    int? sortOrder,
  }) =>
      SupplierAccount(
        id: id ?? this.id,
        supplierId: supplierId ?? this.supplierId,
        bankName: bankName ?? this.bankName,
        accountNumber: accountNumber ?? this.accountNumber,
        accountHolder: accountHolder ?? this.accountHolder,
        memo: memo ?? this.memo,
        isPrimary: isPrimary ?? this.isPrimary,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
