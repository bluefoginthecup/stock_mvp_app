import '../models/item.dart';

const registrationAttrCleanupKeys = {
  'temporary',
  'status',
  'source',
  'createdFromPurchaseOrderId',
  'createdAt',
};

bool isNeedsRegistrationItem(Item item) {
  final attrs = item.attrs;
  if (attrs == null || attrs.isEmpty) return false;
  return attrs['temporary'] == true || attrs['status'] == 'needsReview';
}

bool isTemporaryFolderToken(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return true;
  return const {
    'uncategorized',
    'unclassified',
    'temporary',
    'temp',
    '미분류',
    '임시',
  }.contains(normalized);
}

Map<String, dynamic>? cleanupRegistrationAttrs(Map<String, dynamic>? attrs) {
  if (attrs == null || attrs.isEmpty) return attrs;
  final cleaned = Map<String, dynamic>.from(attrs)
    ..removeWhere((key, value) => registrationAttrCleanupKeys.contains(key));
  return cleaned.isEmpty ? null : cleaned;
}
