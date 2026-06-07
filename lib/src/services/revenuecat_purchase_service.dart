import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

class RevenueCatEntitlementSnapshot {
  final bool proActive;
  final bool cloudBackupActive;

  const RevenueCatEntitlementSnapshot({
    required this.proActive,
    required this.cloudBackupActive,
  });

  static const empty = RevenueCatEntitlementSnapshot(
    proActive: false,
    cloudBackupActive: false,
  );
}

class RevenueCatPurchaseService {
  static const proEntitlementId = 'pro';
  static const cloudBackupEntitlementId = 'cloud_backup';

  static const proProductIds = {
    'chalstock_pro_6m',
    'chalstock_pro_1y',
  };
  static const cloudBackupProductIds = {
    'chalstock_cloud_backup_1y',
  };

  static const _iosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  static const _androidApiKey =
      String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');
  static const _testApiKey = String.fromEnvironment('REVENUECAT_TEST_API_KEY');

  static String? _configuredUserId;

  bool get hasApiKey => _apiKeyForCurrentPlatform() != null;

  Future<void> configureForUser(String uid) async {
    if (_configuredUserId == uid) return;
    final apiKey = _apiKeyForCurrentPlatform();
    if (apiKey == null) {
      throw const RevenueCatNotConfiguredException();
    }

    await rc.Purchases.setLogLevel(rc.LogLevel.debug);
    if (await rc.Purchases.isConfigured) {
      final currentUserId = await rc.Purchases.appUserID;
      if (currentUserId != uid) {
        await rc.Purchases.logIn(uid);
      }
    } else {
      final configuration = rc.PurchasesConfiguration(apiKey)..appUserID = uid;
      await rc.Purchases.configure(configuration);
    }
    _configuredUserId = uid;
  }

  Future<RevenueCatEntitlementSnapshot> customerInfo(String uid) async {
    await configureForUser(uid);
    final customerInfo = await rc.Purchases.getCustomerInfo();
    return _snapshotFromCustomerInfo(customerInfo);
  }

  Future<RevenueCatEntitlementSnapshot> purchasePro(String uid) {
    return _purchaseFirstMatchingPackage(uid, proProductIds);
  }

  Future<RevenueCatEntitlementSnapshot> purchaseCloudBackup(String uid) {
    return _purchaseFirstMatchingPackage(uid, cloudBackupProductIds);
  }

  Future<RevenueCatEntitlementSnapshot> restorePurchases(String uid) async {
    await configureForUser(uid);
    final customerInfo = await rc.Purchases.restorePurchases();
    return _snapshotFromCustomerInfo(customerInfo);
  }

  Future<RevenueCatEntitlementSnapshot> _purchaseFirstMatchingPackage(
    String uid,
    Set<String> productIds,
  ) async {
    await configureForUser(uid);
    final offerings = await rc.Purchases.getOfferings();
    final packages =
        offerings.current?.availablePackages ?? const <rc.Package>[];
    final package = packages.where((candidate) {
      return productIds.contains(candidate.storeProduct.identifier);
    }).firstOrNull;

    if (package == null) {
      throw RevenueCatProductNotFoundException(productIds);
    }

    try {
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.package(package),
      );
      return _snapshotFromCustomerInfo(result.customerInfo);
    } on PlatformException catch (e) {
      final code = rc.PurchasesErrorHelper.getErrorCode(e);
      if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
        throw const RevenueCatPurchaseCancelledException();
      }
      rethrow;
    }
  }

  RevenueCatEntitlementSnapshot _snapshotFromCustomerInfo(
    rc.CustomerInfo customerInfo,
  ) {
    final entitlements = customerInfo.entitlements.all;
    final proActive = entitlements[proEntitlementId]?.isActive ?? false;
    final cloudBackupActive =
        entitlements[cloudBackupEntitlementId]?.isActive ?? false;
    return RevenueCatEntitlementSnapshot(
      proActive: proActive,
      cloudBackupActive: cloudBackupActive,
    );
  }

  String? _apiKeyForCurrentPlatform() {
    if (_testApiKey.isNotEmpty) return _testApiKey;
    if (kIsWeb) return null;
    if (Platform.isIOS || Platform.isMacOS) {
      return _iosApiKey.isEmpty ? null : _iosApiKey;
    }
    if (Platform.isAndroid) {
      return _androidApiKey.isEmpty ? null : _androidApiKey;
    }
    return null;
  }
}

class RevenueCatNotConfiguredException implements Exception {
  const RevenueCatNotConfiguredException();

  @override
  String toString() {
    return 'RevenueCat API key가 설정되지 않았습니다. '
        '--dart-define=REVENUECAT_IOS_API_KEY=... 또는 '
        '--dart-define=REVENUECAT_ANDROID_API_KEY=... 값을 넣어주세요.';
  }
}

class RevenueCatProductNotFoundException implements Exception {
  final Set<String> productIds;

  const RevenueCatProductNotFoundException(this.productIds);

  @override
  String toString() {
    return 'RevenueCat Offering에서 상품을 찾지 못했습니다: '
        '${productIds.join(', ')}';
  }
}

class RevenueCatPurchaseCancelledException implements Exception {
  const RevenueCatPurchaseCancelledException();

  @override
  String toString() => '구매가 취소되었습니다.';
}
