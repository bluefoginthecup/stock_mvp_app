enum SubscriptionPlan {
  free,
  pro,
  business,
}

extension SubscriptionPlanConfig on SubscriptionPlan {
  String get label {
    switch (this) {
      case SubscriptionPlan.free:
        return '무료 플랜';
      case SubscriptionPlan.pro:
        return 'Pro 플랜';
      case SubscriptionPlan.business:
        return 'Business 플랜';
    }
  }
}
