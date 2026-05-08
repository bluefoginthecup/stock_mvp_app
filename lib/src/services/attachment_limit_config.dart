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
}

class AttachmentLimitConfig {
  final Map<SubscriptionPlan, Map<AttachmentDomain, AttachmentLimit>> limits;

  const AttachmentLimitConfig(this.limits);

  static const defaults = AttachmentLimitConfig({
    SubscriptionPlan.free: {
      AttachmentDomain.itemImages: AttachmentLimit(
        maxOwnersWithAttachments: 10,
        maxFilesPerOwner: 1,
      ),
      AttachmentDomain.purchaseReceipts: AttachmentLimit(maxFilesPerOwner: 10),
      AttachmentDomain.scheduleAttachments:
          AttachmentLimit(maxFilesPerOwner: 3),
    },
    SubscriptionPlan.pro: {
      AttachmentDomain.itemImages: AttachmentLimit(
        maxOwnersWithAttachments: 100,
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
