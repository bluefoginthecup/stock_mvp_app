import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../models/attachment_domain.dart';
import '../models/subscription_plan.dart';
import 'attachment_limit_config.dart';
import 'entitlement_service.dart';
import 'subscription_plan_service.dart';

class AttachmentPolicyResult {
  final bool allowed;
  final String? message;

  const AttachmentPolicyResult.allowed()
      : allowed = true,
        message = null;

  const AttachmentPolicyResult.denied(this.message) : allowed = false;
}

class AttachmentPolicyService {
  const AttachmentPolicyService(
    this.db, {
    this.entitlementService,
    this.planService = const SubscriptionPlanService(),
    this.limitConfig = AttachmentLimitConfig.defaults,
  });

  final AppDatabase db;
  final EntitlementService? entitlementService;
  final SubscriptionPlanService planService;
  final AttachmentLimitConfig limitConfig;

  // 모든 첨부 도메인은 이 서비스만 통해 플랜 제한을 확인해야 한다.
  // 나중에 SubscriptionPlanService가 서버 entitlement 기반으로 바뀌면
  // 품목/발주/일정 첨부 기능은 별도 수정 없이 같은 권한 판단을 따른다.
  Future<AttachmentLimit> policyFor(AttachmentDomain domain) async {
    final plan = await _effectivePlan();
    return limitConfig.limitFor(plan: plan, domain: domain);
  }

  Future<AttachmentPolicyResult> canAttach({
    required AttachmentDomain domain,
    required String ownerId,
  }) async {
    final plan = await _effectivePlan();
    final policy = limitConfig.limitFor(plan: plan, domain: domain);
    final filesForOwner = await _countFilesForOwner(domain, ownerId);
    final maxFilesPerOwner = policy.maxFilesPerOwner;
    if (maxFilesPerOwner != null && filesForOwner >= maxFilesPerOwner) {
      return AttachmentPolicyResult.denied(
        '${plan.label}에서는 ${domain.label}을(를) ${domain.ownerLabel}당 '
        '$maxFilesPerOwner개까지 첨부할 수 있습니다.',
      );
    }

    final ownerLimit = policy.maxOwnersWithAttachments;
    if (ownerLimit != null && filesForOwner == 0) {
      final ownersWithAttachments = await _countOwnersWithAttachments(domain);
      if (ownersWithAttachments >= ownerLimit) {
        return AttachmentPolicyResult.denied(
          '${plan.label}에서는 ${domain.label}이(가) 있는 ${domain.ownerLabel}을(를) '
          '$ownerLimit개까지 사용할 수 있습니다. 기존 이미지를 삭제하거나 '
          '상위 플랜에서 더 많이 사용할 수 있습니다.',
        );
      }
    }

    return const AttachmentPolicyResult.allowed();
  }

  Future<SubscriptionPlan> _effectivePlan() async {
    final entitlementService = this.entitlementService;
    if (entitlementService != null) {
      final entitlement = await entitlementService.loadEntitlement();
      return entitlement.canUseProFeatures
          ? SubscriptionPlan.pro
          : SubscriptionPlan.free;
    }
    return planService.loadPlan();
  }

  Future<int> _countFilesForOwner(
    AttachmentDomain domain,
    String ownerId,
  ) async {
    final spec = _tableSpec(domain);
    final rows = await db.customSelect(
      'SELECT COUNT(*) AS count FROM ${spec.table} WHERE ${spec.ownerColumn} = ?',
      variables: [Variable.withString(ownerId)],
    ).get();
    return (rows.first.data['count'] as int?) ?? 0;
  }

  Future<int> _countOwnersWithAttachments(AttachmentDomain domain) async {
    final spec = _tableSpec(domain);
    final rows = await db
        .customSelect(
          'SELECT COUNT(DISTINCT ${spec.ownerColumn}) AS count FROM ${spec.table}',
        )
        .get();
    return (rows.first.data['count'] as int?) ?? 0;
  }

  _AttachmentTableSpec _tableSpec(AttachmentDomain domain) {
    switch (domain) {
      case AttachmentDomain.itemImages:
        return const _AttachmentTableSpec('item_images', 'item_id');
      case AttachmentDomain.purchaseReceipts:
        return const _AttachmentTableSpec(
          'purchase_receipts',
          'purchase_order_id',
        );
      case AttachmentDomain.scheduleAttachments:
        return const _AttachmentTableSpec(
          'schedule_attachments',
          'schedule_id',
        );
    }
  }
}

class _AttachmentTableSpec {
  final String table;
  final String ownerColumn;

  const _AttachmentTableSpec(this.table, this.ownerColumn);
}
