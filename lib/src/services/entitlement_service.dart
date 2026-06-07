import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_entitlement.dart';
import '../models/subscription_plan.dart';
import 'auth_service.dart';
import 'revenuecat_purchase_service.dart';

class EntitlementService {
  static const appTrialDuration = Duration(days: 7);
  static const cloudTrialDuration = Duration(days: 7);

  EntitlementService({
    required this.authService,
    FirebaseFirestore? firestore,
    RevenueCatPurchaseService? purchaseService,
  })  : _firestore = firestore,
        _purchaseService = purchaseService ?? RevenueCatPurchaseService();

  final AuthService authService;
  final FirebaseFirestore? _firestore;
  final RevenueCatPurchaseService _purchaseService;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  bool get purchaseConfigured => _purchaseService.hasApiKey;

  Future<AppEntitlement> loadEntitlement() async {
    final uid = authService.uid;
    if (uid == null) return AppEntitlement.signedOut;

    final data = await _ensureEntitlementDoc(uid);
    final now = DateTime.now();
    final appTrialEndsAt = _dateValue(data['appTrialEndsAt']);
    final cloudTrialEndsAt = _dateValue(data['cloudTrialEndsAt']);

    RevenueCatEntitlementSnapshot purchaseSnapshot =
        RevenueCatEntitlementSnapshot.empty;
    if (_purchaseService.hasApiKey) {
      purchaseSnapshot = await _purchaseService.customerInfo(uid);
      await _doc(uid).set(
        {
          'revenueCatUserId': uid,
          'revenueCatProActive': purchaseSnapshot.proActive,
          'revenueCatCloudBackupActive': purchaseSnapshot.cloudBackupActive,
          'lastSyncedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final plan = purchaseSnapshot.proActive
        ? SubscriptionPlan.pro
        : SubscriptionPlan.free;
    final isPaidPlan =
        plan == SubscriptionPlan.pro || plan == SubscriptionPlan.business;
    final hasCloudBackup = isPaidPlan && purchaseSnapshot.cloudBackupActive;

    return AppEntitlement(
      plan: plan,
      isAppTrialActive: appTrialEndsAt != null && now.isBefore(appTrialEndsAt),
      isCloudTrialActive:
          cloudTrialEndsAt != null && now.isBefore(cloudTrialEndsAt),
      hasCloudBackup: hasCloudBackup,
      appTrialEndsAt: appTrialEndsAt,
      cloudTrialEndsAt: cloudTrialEndsAt,
    );
  }

  Future<AppEntitlement> startCloudTrial() async {
    final uid = authService.uid;
    if (uid == null) return AppEntitlement.signedOut;

    final data = await _ensureEntitlementDoc(uid);
    if (_dateValue(data['cloudTrialStartedAt']) == null) {
      final now = DateTime.now();
      await _doc(uid).set(
        {
          'cloudTrialStartedAt': Timestamp.fromDate(now),
          'cloudTrialEndsAt': Timestamp.fromDate(now.add(cloudTrialDuration)),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    return loadEntitlement();
  }

  Future<AppEntitlement> purchasePro() async {
    final uid = authService.uid;
    if (uid == null) return AppEntitlement.signedOut;
    await _purchaseService.purchasePro(uid);
    return loadEntitlement();
  }

  Future<AppEntitlement> purchaseCloudBackup() async {
    final uid = authService.uid;
    if (uid == null) return AppEntitlement.signedOut;
    final entitlement = await loadEntitlement();
    if (!entitlement.isPaidPlan) {
      throw const CloudBackupRequiresProException();
    }
    await _purchaseService.purchaseCloudBackup(uid);
    return loadEntitlement();
  }

  Future<AppEntitlement> restorePurchases() async {
    final uid = authService.uid;
    if (uid == null) return AppEntitlement.signedOut;
    await _purchaseService.restorePurchases(uid);
    return loadEntitlement();
  }

  Future<Map<String, Object?>> _ensureEntitlementDoc(String uid) async {
    final ref = _doc(uid);
    final snapshot = await ref.get();
    if (snapshot.exists) {
      return snapshot.data() ?? const <String, Object?>{};
    }

    final now = DateTime.now();
    final data = <String, Object?>{
      'plan': SubscriptionPlan.free.name,
      'appTrialStartedAt': Timestamp.fromDate(now),
      'appTrialEndsAt': Timestamp.fromDate(now.add(appTrialDuration)),
      'cloudTrialStartedAt': null,
      'cloudTrialEndsAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await ref.set(data, SetOptions(merge: true));
    return data;
  }

  DocumentReference<Map<String, Object?>> _doc(String uid) {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('entitlements')
        .doc('current');
  }

  DateTime? _dateValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class CloudBackupRequiresProException implements Exception {
  const CloudBackupRequiresProException();

  @override
  String toString() => 'Cloud Backup은 Pro 사용자만 구독할 수 있습니다.';
}
