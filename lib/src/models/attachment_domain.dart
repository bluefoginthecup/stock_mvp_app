enum AttachmentDomain {
  itemImages,
  purchaseReceipts,
  scheduleAttachments,
}

extension AttachmentDomainConfig on AttachmentDomain {
  String get id {
    switch (this) {
      case AttachmentDomain.itemImages:
        return 'item_images';
      case AttachmentDomain.purchaseReceipts:
        return 'purchase_receipts';
      case AttachmentDomain.scheduleAttachments:
        return 'schedule_attachments';
    }
  }

  String get label {
    switch (this) {
      case AttachmentDomain.itemImages:
        return '품목 이미지';
      case AttachmentDomain.purchaseReceipts:
        return '영수증/거래명세서';
      case AttachmentDomain.scheduleAttachments:
        return '일정 첨부 이미지';
    }
  }

  String get ownerLabel {
    switch (this) {
      case AttachmentDomain.itemImages:
        return '품목';
      case AttachmentDomain.purchaseReceipts:
        return '발주';
      case AttachmentDomain.scheduleAttachments:
        return '일정';
    }
  }
}
