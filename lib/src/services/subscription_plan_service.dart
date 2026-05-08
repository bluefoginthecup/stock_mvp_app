import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_plan.dart';

class SubscriptionPlanService {
  static const _planKey = 'subscription_plan';

  const SubscriptionPlanService();

  // 현재 값은 개발/TestFlight 단계에서 첨부 제한을 빠르게 검증하기 위한
  // 로컬 override이다. 운영 권한의 원천으로 사용하면 안 된다.
  //
  // 실제 구독 기능을 붙일 때는 이 흐름을 다음 구조로 교체한다.
  // 1. Firebase Auth uid 기준으로 서버 entitlement를 조회한다.
  //    예: users/{uid}/entitlements/current
  //    - plan: free | pro | business
  //    - status: active | expired | canceled | trial
  //    - expiresAt, lastVerifiedAt, source(app_store/play_store/admin)
  // 2. Pro/Business 판정은 status == active && expiresAt > now 일 때만 허용한다.
  // 3. App Store/Play 결제 영수증 검증은 클라이언트가 아니라
  //    Cloud Functions/RevenueCat 같은 서버 신뢰 경로에서 처리한다.
  // 4. SharedPreferences는 서버 확인 결과의 짧은 캐시로만 사용한다.
  //    오프라인 유예기간이 필요하면 lastVerifiedAt 기준으로 제한적으로 허용하고,
  //    유예기간이 지나면 free로 fallback한다.
  //
  // 따라서 savePlanForDebug/resetPlanForDebug는 운영 결제 권한 API가 아니라
  // 테스트용 임시 스위치로만 유지한다.
  Future<SubscriptionPlan> loadPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_planKey);
    return SubscriptionPlan.values.firstWhere(
      (plan) => plan.name == value,
      orElse: () => SubscriptionPlan.free,
    );
  }

  Future<void> savePlanForDebug(SubscriptionPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planKey, plan.name);
  }

  Future<void> resetPlanForDebug() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_planKey);
  }
}
