import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class DailyGift {
  final String id;
  final String title;
  final String description;
  final DateTime unlockedAt;
  final DateTime sourceDate;

  const DailyGift({
    required this.id,
    required this.title,
    required this.description,
    required this.unlockedAt,
    required this.sourceDate,
  });

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'unlockedAt': unlockedAt.toIso8601String(),
      'sourceDate': _dateKey(sourceDate),
    };
  }

  static DailyGift fromJson(Map<String, Object?> json) {
    return DailyGift(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '작업실 선물',
      description: json['description']?.toString() ?? '',
      unlockedAt: DateTime.tryParse(json['unlockedAt']?.toString() ?? '') ??
          DateTime.now(),
      sourceDate:
          _parseDateKey(json['sourceDate']?.toString()) ?? DateTime.now(),
    );
  }
}

class DailyGiftSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const DailyGiftSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  static const defaults = DailyGiftSettings(
    enabled: false,
    hour: 18,
    minute: 30,
  );

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  DailyGiftSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
  }) {
    return DailyGiftSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

class DailyGiftService {
  static const _enabledKey = 'dailyGift.enabled.v1';
  static const _hourKey = 'dailyGift.hour.v1';
  static const _minuteKey = 'dailyGift.minute.v1';
  static const _lastGiftDateKey = 'dailyGift.lastGiftDate.v1';
  static const _giftsKey = 'dailyGift.gifts.v1';
  static const _notificationId = 240716;

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
      debugPrint('DailyGift notifications unavailable until full rebuild: $e');
    } catch (e, st) {
      debugPrint('DailyGift notifications initialize failed: $e');
      debugPrint('$st');
    }
  }

  Future<DailyGiftSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return DailyGiftSettings(
      enabled: prefs.getBool(_enabledKey) ?? DailyGiftSettings.defaults.enabled,
      hour: prefs.getInt(_hourKey) ?? DailyGiftSettings.defaults.hour,
      minute: prefs.getInt(_minuteKey) ?? DailyGiftSettings.defaults.minute,
    );
  }

  Future<void> saveSettings(DailyGiftSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setInt(_hourKey, settings.hour);
    await prefs.setInt(_minuteKey, settings.minute);
    await scheduleReminder(settings);
  }

  Future<void> scheduleReminder(DailyGiftSettings settings) async {
    if (kIsWeb) return;
    await initialize();
    if (!_initialized) return;

    try {
      await _notifications.cancel(_notificationId);
      if (!settings.enabled) return;
      await _requestPermissionsIfNeeded();

      final next = _nextScheduleTime(settings);
      await _notifications.zonedSchedule(
        _notificationId,
        '작업실 선물이 도착했어요',
        '오늘의 작은 선물을 보관함에서 확인해보세요.',
        tz.TZDateTime.from(next, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_gifts',
            '작업실 선물',
            channelDescription: '매일 정한 시간에 작업실 선물 도착 알림',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_gift',
      );
    } catch (e, st) {
      debugPrint('DailyGift schedule failed: $e');
      debugPrint('$st');
    }
  }

  Future<List<DailyGift>> loadGifts({bool grantIfDue = true}) async {
    if (grantIfDue) await grantTodayIfDue();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_giftsKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final gifts = decoded
          .whereType<Map>()
          .map((item) => DailyGift.fromJson(item.cast<String, Object?>()))
          .toList();
      gifts.sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
      return gifts;
    } catch (_) {
      return const [];
    }
  }

  Future<DailyGift?> grantTodayIfDue({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final settings = await loadSettings();
    if (!settings.enabled) return null;
    if (!_isGiftTimeReached(current, settings)) return null;

    final todayKey = _dateKey(current);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastGiftDateKey) == todayKey) return null;

    final existing = await loadGifts(grantIfDue: false);
    final spec = _giftCatalog[existing.length % _giftCatalog.length];
    final gift = DailyGift(
      id: '$todayKey-${spec.title}',
      title: spec.title,
      description: spec.description,
      unlockedAt: current,
      sourceDate: DateTime(current.year, current.month, current.day),
    );
    final next = [gift, ...existing];
    await prefs.setString(
      _giftsKey,
      jsonEncode(next.map((gift) => gift.toJson()).toList()),
    );
    await prefs.setString(_lastGiftDateKey, todayKey);
    return gift;
  }

  Future<DailyGift> grantTestGift() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadGifts(grantIfDue: false);
    final now = DateTime.now();
    final spec = _giftCatalog[existing.length % _giftCatalog.length];
    final gift = DailyGift(
      id: '${now.toIso8601String()}-${spec.title}',
      title: spec.title,
      description: spec.description,
      unlockedAt: now,
      sourceDate: DateTime(now.year, now.month, now.day),
    );
    await prefs.setString(
      _giftsKey,
      jsonEncode([gift, ...existing].map((gift) => gift.toJson()).toList()),
    );
    return gift;
  }

  DateTime _nextScheduleTime(DailyGiftSettings settings) {
    final now = DateTime.now();
    var next =
        DateTime(now.year, now.month, now.day, settings.hour, settings.minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  bool _isGiftTimeReached(DateTime now, DailyGiftSettings settings) {
    final giftTime = DateTime(
      now.year,
      now.month,
      now.day,
      settings.hour,
      settings.minute,
    );
    return !now.isBefore(giftTime);
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
}

class _GiftSpec {
  final String title;
  final String description;

  const _GiftSpec(this.title, this.description);
}

const _giftCatalog = [
  _GiftSpec('작은 화분', '오늘 작업실에 조용한 초록이 하나 놓였어요.'),
  _GiftSpec('포장된 선물 상자', '아직 열지 않은 마음처럼, 내일의 일이 반듯하게 기다리고 있어요.'),
  _GiftSpec('책상 위 작은 도장', '하나씩 확인하고 지나온 일의 흔적이에요.'),
  _GiftSpec('벽에 붙은 달력', '오늘을 넘긴 표시가 작업실 벽에 하나 더 생겼어요.'),
  _GiftSpec('선반 위 유리병', '작은 성실함을 모아두기 좋은 투명한 병이에요.'),
  _GiftSpec('새 라벨 스티커', '정리된 것들은 이름을 얻고 조금 더 찾기 쉬워져요.'),
  _GiftSpec('반듯한 장부', '오늘의 기록이 조용히 한 줄 더 늘었어요.'),
  _GiftSpec('따뜻한 머그컵', '잠깐 쉬어가도 괜찮다는 표시예요.'),
];

String _dateKey(DateTime value) {
  final d = DateTime(value.year, value.month, value.day);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

DateTime? _parseDateKey(String? value) {
  if (value == null) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}
