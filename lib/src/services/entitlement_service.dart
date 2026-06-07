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
    final appTrialEndsAt = _dateValue(data['manualAppTrialEndsAt']);
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

  Future<AppEntitlement> startAppTrial() async {
    final uid = authService.uid;
    if (uid == null) return AppEntitlement.signedOut;

    final data = await _ensureEntitlementDoc(uid);
    if (_dateValue(data['manualAppTrialStartedAt']) == null) {
      final now = DateTime.now();
      await _doc(uid).set(
        {
          'manualAppTrialStartedAt': Timestamp.fromDate(now),
          'manualAppTrialEndsAt': Timestamp.fromDate(
            now.add(appTrialDuration),
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    return loadEntitlement();
  }

  Future<AppEntitlement> startCloudTrial() async {
    final uid = authService.uid;
    if (uid == null) return AppEntitlement.signedOut;

    final entitlement = await loadEntitlement();
    if (!entitlement.canUseProFeatures) {
      throw const CloudTrialRequiresProOrTrialException();
    }

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

  Future<AppEntitlement> purchaseProProduct(String productId) async {
    final uid = authService.uid;
    if (uid == null) return AppEntitlement.signedOut;
    await _purchaseService.purchaseProProduct(uid, productId);
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

  Future<AppEntitlement> purchaseCloudBackupProduct(String productId) async {
    final uid = authService.uid;
    if (uid == null) return AppEntitlement.signedOut;
    final entitlement = await loadEntitlement();
    if (!entitlement.isPaidPlan) {
      throw const CloudBackupRequiresProException();
    }
    await _purchaseService.purchaseCloudBackupProduct(uid, productId);
    return loadEntitlement();
  }

  Future<List<RevenueCatPackageOption>> proPackageOptions() async {
    final uid = authService.uid;
    if (uid == null) return const [];
    return _purchaseService.proPackageOptions(uid);
  }

  Future<List<RevenueCatPackageOption>> cloudBackupPackageOptions() async {
    final uid = authService.uid;
    if (uid == null) return const [];
    return _purchaseService.cloudBackupPackageOptions(uid);
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

    final data = <String, Object?>{
      'plan': SubscriptionPlan.free.name,
      'manualAppTrialStartedAt': null,
      'manualAppTrialEndsAt': null,
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

class CloudTrialRequiresProOrTrialException implements Exception {
  const CloudTrialRequiresProOrTrialException();

  @override
  String toString() => 'Cloud Backup 체험은 App Trial 또는 Pro 상태에서 시작할 수 있습니다.';
}

class CloudBackupRequiresProException implements Exception {
  const CloudBackupRequiresProException();

  @override
  String toString() => 'Cloud Backup은 Pro 사용자만 구독할 수 있습니다.';
}
