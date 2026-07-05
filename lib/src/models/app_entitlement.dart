import 'subscription_plan.dart';

class AppEntitlement {
  final SubscriptionPlan plan;
  final bool isAppTrialActive;
  final bool isCloudTrialActive;
  final bool hasCloudBackup;
  final String? activeProProductId;
  final String? activeCloudBackupProductId;
  final DateTime? appTrialEndsAt;
  final DateTime? cloudTrialEndsAt;

  const AppEntitlement({
    required this.plan,
    required this.isAppTrialActive,
    required this.isCloudTrialActive,
    required this.hasCloudBackup,
    this.activeProProductId,
    this.activeCloudBackupProductId,
    this.appTrialEndsAt,
    this.cloudTrialEndsAt,
  });

  static const signedOut = AppEntitlement(
    plan: SubscriptionPlan.free,
    isAppTrialActive: false,
    isCloudTrialActive: false,
    hasCloudBackup: false,
  );

  bool get isPaidPlan =>
      plan == SubscriptionPlan.pro || plan == SubscriptionPlan.business;

  bool get canUseProFeatures => isAppTrialActive || isPaidPlan;

  bool get canEditData => canUseProFeatures;

  bool get canCreateCloudBackup =>
      isCloudTrialActive || (isPaidPlan && hasCloudBackup);

  bool get canRestoreCloudBackup => true;

  String get planLabel {
    final productLabel = _proProductLabel(activeProProductId);
    if (productLabel != null) return productLabel;
    if (isPaidPlan) return plan.label;
    if (isAppTrialActive) return 'Trial';
    return plan.label;
  }

  String get cloudBackupLabel {
    if (hasCloudBackup && isPaidPlan) {
      return _cloudBackupProductLabel(activeCloudBackupProductId) ?? '사용 중';
    }
    if (isCloudTrialActive) return 'Cloud Trial';
    return '사용 안 함';
  }

  String? _proProductLabel(String? productId) {
    switch (productId) {
      case 'chalstock_pro_6m':
        return 'Pro 6개월';
      case 'chalstock_pro_1y':
        return 'Pro 12개월';
      default:
        return null;
    }
  }

  String? _cloudBackupProductLabel(String? productId) {
    switch (productId) {
      case 'chalstock_cloud_backup_1y':
      case 'chalstock_cloud_backup_yearly':
      case 'chalstock_cloud_yearly':
      case 'cloud_backup_1y':
      case 'cloud_backup_yearly':
        return 'Cloud Backup 12개월';
      default:
        return null;
    }
  }
}
