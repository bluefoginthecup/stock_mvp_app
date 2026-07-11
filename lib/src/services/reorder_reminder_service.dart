import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/item.dart';
import '../utils/reorder_schedule_utils.dart';

class ReorderReminderService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _unavailable = false;

  static Future<void> initialize() async {
    if (_initialized || _unavailable || kIsWeb) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      windows: WindowsInitializationSettings(
        appName: 'ChalStock',
        appUserModelId: 'Bluefog.ChalStock.StockApp',
        guid: '9cf3e4e5-6d0f-4c6d-a5f5-4c3ed2a65b9b',
      ),
    );
    try {
      await _notifications.initialize(settings);
      _initialized = true;
    } on MissingPluginException catch (e) {
      _unavailable = true;
      debugPrint('ReorderReminder unavailable until full rebuild: $e');
    } catch (e, st) {
      debugPrint('ReorderReminder initialize failed: $e');
      debugPrint('$st');
    }
  }

  static Future<void> rescheduleForItem(Item item) async {
    await initialize();
    if (!_initialized) return;
    await cancelForItem(item.id);

    final nextReorderDate = ReorderScheduleUtils.effectiveNextReorderDate(item);
    if (!item.reorderReminderEnabled || nextReorderDate == null) {
      return;
    }

    final reminderDate = ReorderScheduleUtils.reminderDate(
      nextReorderDate: nextReorderDate,
      daysBefore: item.reorderReminderDaysBefore,
    );
    if (reminderDate == null) return;

    final now = DateTime.now();
    final scheduled = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9,
    );
    if (!scheduled.isAfter(now)) return;

    try {
      await _requestPermissionsIfNeeded();
    } catch (e) {
      debugPrint('ReorderReminder permission request failed: $e');
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reorder_reminders',
        '발주 알림',
        channelDescription: '정기 발주 예정일 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );

    final title = item.displayName?.trim().isNotEmpty == true
        ? item.displayName!.trim()
        : item.name;
    try {
      await _notifications.zonedSchedule(
        _notificationIdForItem(item.id),
        '발주 예정',
        '$title 발주 시점이 다가왔어요.',
        tz.TZDateTime.from(scheduled, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.id,
      );
    } catch (e, st) {
      debugPrint('ReorderReminder schedule failed: $e');
      debugPrint('$st');
    }
  }

  static Future<void> cancelForItem(String itemId) async {
    if (!_initialized && kIsWeb) return;
    await initialize();
    if (!_initialized) return;
    try {
      await _notifications.cancel(_notificationIdForItem(itemId));
    } catch (e) {
      debugPrint('ReorderReminder cancel failed: $e');
    }
  }

  static Future<void> _requestPermissionsIfNeeded() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _notifications
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static int _notificationIdForItem(String itemId) {
    var hash = 0x811c9dc5;
    for (final unit in itemId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 100000 + (hash % 1900000000);
  }
}
