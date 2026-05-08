import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../models/attachment_domain.dart';

class AttachmentPolicy {
  final int? freeMaxOwnersWithAttachments;
  final int freeMaxFilesPerOwner;

  const AttachmentPolicy({
    this.freeMaxOwnersWithAttachments,
    required this.freeMaxFilesPerOwner,
  });
}

class AttachmentPolicyResult {
  final bool allowed;
  final String? message;

  const AttachmentPolicyResult.allowed()
      : allowed = true,
        message = null;

  const AttachmentPolicyResult.denied(this.message) : allowed = false;
}

class AttachmentPolicyService {
  const AttachmentPolicyService(this.db);

  final AppDatabase db;

  AttachmentPolicy policyFor(AttachmentDomain domain) {
    switch (domain) {
      case AttachmentDomain.itemImages:
        return const AttachmentPolicy(
          freeMaxOwnersWithAttachments: 10,
          freeMaxFilesPerOwner: 1,
        );
      case AttachmentDomain.purchaseReceipts:
        return const AttachmentPolicy(freeMaxFilesPerOwner: 10);
      case AttachmentDomain.scheduleAttachments:
        return const AttachmentPolicy(freeMaxFilesPerOwner: 3);
    }
  }

  Future<AttachmentPolicyResult> canAttach({
    required AttachmentDomain domain,
    required String ownerId,
  }) async {
    final policy = policyFor(domain);
    final filesForOwner = await _countFilesForOwner(domain, ownerId);
    if (filesForOwner >= policy.freeMaxFilesPerOwner) {
      return AttachmentPolicyResult.denied(
        '무료 플랜에서는 ${domain.label}을(를) 항목당 '
        '${policy.freeMaxFilesPerOwner}개까지 첨부할 수 있습니다.',
      );
    }

    final ownerLimit = policy.freeMaxOwnersWithAttachments;
    if (ownerLimit != null && filesForOwner == 0) {
      final ownersWithAttachments = await _countOwnersWithAttachments(domain);
      if (ownersWithAttachments >= ownerLimit) {
        return AttachmentPolicyResult.denied(
          '무료 플랜에서는 ${domain.label}이(가) 있는 품목을 '
          '$ownerLimit개까지 사용할 수 있습니다. 기존 이미지를 삭제하거나 '
          'Pro에서 더 많이 사용할 수 있습니다.',
        );
      }
    }

    return const AttachmentPolicyResult.allowed();
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
