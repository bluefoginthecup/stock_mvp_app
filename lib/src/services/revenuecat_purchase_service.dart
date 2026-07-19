import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

class RevenueCatEntitlementSnapshot {
  final bool proActive;
  final bool cloudBackupActive;
  final String? activeProProductId;
  final String? activeCloudBackupProductId;

  const RevenueCatEntitlementSnapshot({
    required this.proActive,
    required this.cloudBackupActive,
    this.activeProProductId,
    this.activeCloudBackupProductId,
  });

  static const empty = RevenueCatEntitlementSnapshot(
    proActive: false,
    cloudBackupActive: false,
  );
}

class RevenueCatPackageOption {
  final String productId;
  final String title;
  final String displayName;
  final String priceString;
  final String? periodLabel;

  const RevenueCatPackageOption({
    required this.productId,
    required this.title,
    required this.displayName,
    required this.priceString,
    this.periodLabel,
  });
}

class RevenueCatPurchaseService {
  static const _verboseLogs =
      bool.fromEnvironment('CHALSTOCK_VERBOSE_REVENUECAT_LOGS');

  static const proEntitlementId = 'pro';
  static const cloudBackupEntitlementId = 'cloud_backup';
  static const _proEntitlementIds = {
    proEntitlementId,
    'chalstock Pro',
  };
  static const _cloudBackupEntitlementIds = {
    cloudBackupEntitlementId,
  };

  static const proProductIds = {
    'chalstock_pro_6m',
    'chalstock_pro_1y',
  };
  static const cloudBackupProductIds = {
    'chalstock_cloud_backup_1y',
    'chalstock_cloud_backup_yearly',
    'chalstock_cloud_yearly',
    'cloud_backup_1y',
    'cloud_backup_yearly',
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

    await rc.Purchases.setLogLevel(
      _verboseLogs ? rc.LogLevel.debug : rc.LogLevel.warn,
    );
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

  Future<RevenueCatEntitlementSnapshot> purchaseProProduct(
    String uid,
    String productId,
  ) {
    return _purchaseProduct(uid, productId, allowedProductIds: proProductIds);
  }

  Future<RevenueCatEntitlementSnapshot> purchaseCloudBackup(String uid) {
    return _purchaseFirstMatchingPackage(uid, cloudBackupProductIds);
  }

  Future<RevenueCatEntitlementSnapshot> purchaseCloudBackupProduct(
    String uid,
    String productId,
  ) {
    return _purchaseProduct(
      uid,
      productId,
      allowedProductIds: cloudBackupProductIds,
    );
  }

  Future<List<RevenueCatPackageOption>> proPackageOptions(String uid) {
    return _packageOptions(uid, proProductIds);
  }

  Future<List<RevenueCatPackageOption>> cloudBackupPackageOptions(String uid) {
    return _packageOptions(uid, cloudBackupProductIds);
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
    final package = await _findFirstMatchingPackage(productIds);

    if (package == null) {
      throw RevenueCatProductNotFoundException(productIds);
    }

    return _purchasePackage(package);
  }

  Future<RevenueCatEntitlementSnapshot> _purchaseProduct(
    String uid,
    String productId, {
    required Set<String> allowedProductIds,
  }) async {
    if (!_matchesProductSet(productId, allowedProductIds)) {
      throw RevenueCatProductNotFoundException({productId});
    }

    await configureForUser(uid);
    final package = await _findPackage(productId);
    if (package == null) {
      throw RevenueCatProductNotFoundException({productId});
    }

    return _purchasePackage(package);
  }

  Future<List<RevenueCatPackageOption>> _packageOptions(
    String uid,
    Set<String> productIds,
  ) async {
    await configureForUser(uid);
    final offerings = await rc.Purchases.getOfferings();
    final packages =
        offerings.current?.availablePackages ?? const <rc.Package>[];
    return packages
        .where((package) => _matchesProductSet(
              package.storeProduct.identifier,
              productIds,
            ))
        .map(_optionFromPackage)
        .toList()
      ..sort(
        (a, b) => _sortOrder(a.productId).compareTo(_sortOrder(b.productId)),
      );
  }

  Future<rc.Package?> _findFirstMatchingPackage(Set<String> productIds) async {
    final offerings = await rc.Purchases.getOfferings();
    final packages =
        offerings.current?.availablePackages ?? const <rc.Package>[];
    return packages.where((candidate) {
      return _matchesProductSet(candidate.storeProduct.identifier, productIds);
    }).firstOrNull;
  }

  Future<rc.Package?> _findPackage(String productId) async {
    final offerings = await rc.Purchases.getOfferings();
    final packages =
        offerings.current?.availablePackages ?? const <rc.Package>[];
    return packages.where((candidate) {
      return candidate.storeProduct.identifier == productId;
    }).firstOrNull;
  }

  Future<RevenueCatEntitlementSnapshot> _purchasePackage(
    rc.Package package,
  ) async {
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

  RevenueCatPackageOption _optionFromPackage(rc.Package package) {
    final product = package.storeProduct;
    return RevenueCatPackageOption(
      productId: product.identifier,
      title: product.title,
      displayName: _displayNameForProduct(product.identifier, product.title),
      priceString: product.priceString,
      periodLabel: _periodLabel(product.subscriptionPeriod),
    );
  }

  RevenueCatEntitlementSnapshot _snapshotFromCustomerInfo(
    rc.CustomerInfo customerInfo,
  ) {
    final entitlements = customerInfo.entitlements.all;
    final activeSubscriptions = customerInfo.activeSubscriptions.toSet();
    final activeProProductId = _firstMatchingProductId(
      activeSubscriptions,
      _isProProductId,
    );
    final activeCloudBackupProductId = _firstMatchingProductId(
      activeSubscriptions,
      _isCloudBackupProductId,
    );
    if (_verboseLogs) {
      debugPrint(
        'RevenueCat activeSubscriptions=$activeSubscriptions '
        'activeEntitlements=${entitlements.entries.where((entry) => entry.value.isActive).map((entry) => entry.key).toList()}',
      );
    }
    final proActive =
        _isAnyEntitlementActive(entitlements, _proEntitlementIds) ||
            activeProProductId != null;
    final cloudBackupActive =
        _isAnyEntitlementActive(entitlements, _cloudBackupEntitlementIds) ||
            activeCloudBackupProductId != null;
    return RevenueCatEntitlementSnapshot(
      proActive: proActive,
      cloudBackupActive: cloudBackupActive,
      activeProProductId: activeProProductId,
      activeCloudBackupProductId: activeCloudBackupProductId,
    );
  }

  String? _firstMatchingProductId(
    Set<String> activeSubscriptions,
    bool Function(String productId) matches,
  ) {
    for (final productId in activeSubscriptions) {
      if (matches(productId)) return productId;
    }
    return null;
  }

  bool _isAnyEntitlementActive(
    Map<String, rc.EntitlementInfo> entitlements,
    Set<String> entitlementIds,
  ) {
    return entitlementIds.any((id) => entitlements[id]?.isActive ?? false);
  }

  bool _matchesProductSet(String productId, Set<String> productIds) {
    if (identical(productIds, proProductIds)) return _isProProductId(productId);
    if (identical(productIds, cloudBackupProductIds)) {
      return _isCloudBackupProductId(productId);
    }
    return productIds.contains(productId);
  }

  bool _isProProductId(String productId) {
    return proProductIds.contains(productId);
  }

  bool _isCloudBackupProductId(String productId) {
    return cloudBackupProductIds.contains(productId);
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

  String _displayNameForProduct(String productId, String fallbackTitle) {
    switch (productId) {
      case 'chalstock_pro_6m':
        return 'Pro 6개월';
      case 'chalstock_pro_1y':
        return 'Pro 12개월';
      case 'chalstock_cloud_backup_1y':
      case 'chalstock_cloud_backup_yearly':
      case 'chalstock_cloud_yearly':
      case 'cloud_backup_1y':
      case 'cloud_backup_yearly':
        return 'Cloud Backup 12개월';
      default:
        return fallbackTitle;
    }
  }

  String? _periodLabel(String? subscriptionPeriod) {
    switch (subscriptionPeriod) {
      case 'P6M':
        return '6개월 자동 갱신';
      case 'P1Y':
        return '12개월 자동 갱신';
      default:
        return null;
    }
  }

  int _sortOrder(String productId) {
    switch (productId) {
      case 'chalstock_pro_6m':
        return 10;
      case 'chalstock_pro_1y':
        return 20;
      case 'chalstock_cloud_backup_1y':
      case 'chalstock_cloud_backup_yearly':
      case 'chalstock_cloud_yearly':
      case 'cloud_backup_1y':
      case 'cloud_backup_yearly':
        return 30;
      default:
        return 100;
    }
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
