import '../models/attachment_domain.dart';
import '../models/subscription_plan.dart';

class AttachmentLimit {
  final int? maxOwnersWithAttachments;
  final int? maxFilesPerOwner;

  const AttachmentLimit({
    this.maxOwnersWithAttachments,
    this.maxFilesPerOwner,
  });

  bool get hasOwnerLimit => maxOwnersWithAttachments != null;

  bool get hasFileLimit => maxFilesPerOwner != null;

  String summaryFor(AttachmentDomain domain) {
    final ownerLabel = domain.ownerLabel;
    final ownerLimit = maxOwnersWithAttachments;
    final fileLimit = maxFilesPerOwner;

    if (ownerLimit == null && fileLimit == null) {
      return '제한 없음';
    }
    if (ownerLimit != null && fileLimit != null) {
      return '$ownerLabel $ownerLimit개 / $ownerLabel당 $fileLimit개';
    }
    if (ownerLimit != null) {
      return '$ownerLabel $ownerLimit개';
    }
    return '$ownerLabel당 $fileLimit개';
  }
}

class AttachmentLimitConfig {
  final Map<SubscriptionPlan, Map<AttachmentDomain, AttachmentLimit>> limits;

  const AttachmentLimitConfig(this.limits);

  // 첨부 제한 기본값.
  //
  // maxOwnersWithAttachments:
  // - 첨부파일을 1개 이상 가진 대상(owner)의 최대 개수.
  // - 품목 이미지에서는 "이미지가 있는 품목 수",
  //   영수증/거래명세서에서는 "첨부가 있는 발주 수",
  //   일정 첨부에서는 "첨부가 있는 일정 수"를 의미한다.
  // - null이면 대상 개수 제한이 없다.
  //
  // maxFilesPerOwner:
  // - 대상 1개에 붙일 수 있는 첨부파일 최대 개수.
  // - 품목 이미지에서는 "품목당 이미지 수",
  //   영수증/거래명세서에서는 "발주당 파일 수",
  //   일정 첨부에서는 "일정당 이미지 수"를 의미한다.
  // - null이면 대상당 파일 개수 제한이 없다.
  //
  // 현재 값은 앱 코드에 있는 로컬 기본값이다. 나중에 구독/관리자 설정을
  // 붙이면 이 값을 fallback으로 두고, Firestore/Remote Config/서버
  // entitlement에서 내려온 값으로 덮어쓰는 구조로 확장한다.
  static const defaults = AttachmentLimitConfig({
    SubscriptionPlan.free: {
      AttachmentDomain.itemImages: AttachmentLimit(
        maxOwnersWithAttachments: 10,
        maxFilesPerOwner: 1,
      ),
      AttachmentDomain.purchaseReceipts: AttachmentLimit(
        maxOwnersWithAttachments: 100,
        maxFilesPerOwner: 3,
      ),
      AttachmentDomain.scheduleAttachments: AttachmentLimit(
        maxOwnersWithAttachments: 100,
        maxFilesPerOwner: 3,
      ),
    },
    SubscriptionPlan.pro: {
      AttachmentDomain.itemImages: AttachmentLimit(
        maxOwnersWithAttachments: 10000,
        maxFilesPerOwner: 5,
      ),
      AttachmentDomain.purchaseReceipts: AttachmentLimit(maxFilesPerOwner: 20),
      AttachmentDomain.scheduleAttachments:
          AttachmentLimit(maxFilesPerOwner: 10),
    },
    SubscriptionPlan.business: {
      AttachmentDomain.itemImages: AttachmentLimit(),
      AttachmentDomain.purchaseReceipts: AttachmentLimit(),
      AttachmentDomain.scheduleAttachments: AttachmentLimit(),
    },
  });

  AttachmentLimit limitFor({
    required SubscriptionPlan plan,
    required AttachmentDomain domain,
  }) {
    return limits[plan]?[domain] ??
        limits[SubscriptionPlan.free]?[domain] ??
        const AttachmentLimit(maxFilesPerOwner: 1);
  }
}
