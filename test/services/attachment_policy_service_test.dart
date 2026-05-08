import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stockapp_mvp/src/db/app_database.dart';
import 'package:stockapp_mvp/src/models/attachment_domain.dart';
import 'package:stockapp_mvp/src/models/subscription_plan.dart';
import 'package:stockapp_mvp/src/services/app_path_service.dart';
import 'package:stockapp_mvp/src/services/attachment_policy_service.dart';
import 'package:stockapp_mvp/src/services/subscription_plan_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  final String root;

  _FakePathProviderPlatform(this.root);

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => p.join(root, 'tmp');
}

class _FakePlanService extends SubscriptionPlanService {
  final SubscriptionPlan plan;

  const _FakePlanService(this.plan);

  @override
  Future<SubscriptionPlan> loadPlan() async => plan;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late AppDatabase db;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('attachment_policy_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(root.path);
    AppPathService.setActiveUserId(null);
    await AppDatabase.closeInstance();
    db = AppDatabase();
  });

  tearDown(() async {
    await AppDatabase.closeInstance();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Future<void> addItemImage({
    required String id,
    required String itemId,
  }) async {
    await db.customStatement('''
      INSERT INTO items (id, name, sku, unit, folder, min_qty, qty)
      VALUES (?, ?, ?, 'EA', '', 0, 0)
    ''', [itemId, itemId, itemId]);
    await db.customStatement('''
      INSERT INTO item_images
        (id, item_id, file_name, file_path, mime_type, created_at, sort_order, is_primary)
      VALUES (?, ?, ?, ?, 'image/jpeg', '2026-05-08T00:00:00.000', 0, 1)
    ''', [id, itemId, '$id.jpg', 'item_images/$itemId/$id.jpg']);
  }

  test('free blocks a second item image for the same item', () async {
    await addItemImage(id: 'img-1', itemId: 'item-1');

    final service = AttachmentPolicyService(
      db,
      planService: const _FakePlanService(SubscriptionPlan.free),
    );
    final result = await service.canAttach(
      domain: AttachmentDomain.itemImages,
      ownerId: 'item-1',
    );

    expect(result.allowed, isFalse);
    expect(result.message, contains('품목당 1개'));
  });

  test('pro allows up to five item images for the same item', () async {
    await addItemImage(id: 'img-1', itemId: 'item-1');

    final service = AttachmentPolicyService(
      db,
      planService: const _FakePlanService(SubscriptionPlan.pro),
    );
    final result = await service.canAttach(
      domain: AttachmentDomain.itemImages,
      ownerId: 'item-1',
    );

    expect(result.allowed, isTrue);
  });
}
