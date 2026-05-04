class BuyerProfile {
  final int id;
  final String profileName;
  final String businessNumber;
  final String companyName;
  final String representative;
  final String address;
  final String businessType;
  final String businessItem;
  final String phoneFax;
  final bool isDefault;
  final DateTime updatedAt;

  const BuyerProfile({
    required this.id,
    required this.profileName,
    required this.businessNumber,
    required this.companyName,
    required this.representative,
    required this.address,
    required this.businessType,
    required this.businessItem,
    required this.phoneFax,
    required this.isDefault,
    required this.updatedAt,
  });

  bool get isConfigured =>
      businessNumber.trim().isNotEmpty ||
      companyName.trim().isNotEmpty ||
      representative.trim().isNotEmpty ||
      address.trim().isNotEmpty ||
      businessType.trim().isNotEmpty ||
      businessItem.trim().isNotEmpty ||
      phoneFax.trim().isNotEmpty;

  String get displayName {
    final name = profileName.trim();
    if (name.isNotEmpty) return name;
    final company = companyName.trim();
    return company.isEmpty ? '공급받는자 $id' : company;
  }

  BuyerProfile copyWith({
    int? id,
    String? profileName,
    String? businessNumber,
    String? companyName,
    String? representative,
    String? address,
    String? businessType,
    String? businessItem,
    String? phoneFax,
    bool? isDefault,
    DateTime? updatedAt,
  }) {
    return BuyerProfile(
      id: id ?? this.id,
      profileName: profileName ?? this.profileName,
      businessNumber: businessNumber ?? this.businessNumber,
      companyName: companyName ?? this.companyName,
      representative: representative ?? this.representative,
      address: address ?? this.address,
      businessType: businessType ?? this.businessType,
      businessItem: businessItem ?? this.businessItem,
      phoneFax: phoneFax ?? this.phoneFax,
      isDefault: isDefault ?? this.isDefault,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BuyerProfile.fallback() {
    return BuyerProfile(
      id: 1,
      profileName: '예시',
      businessNumber: '000-00-00000',
      companyName: '홍길동 상사',
      representative: '홍길동',
      address: '서울특별시 중구 세종대로 000',
      businessType: '도소매업',
      businessItem: '예시 품목',
      phoneFax: '010-0000-0000',
      isDefault: true,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
