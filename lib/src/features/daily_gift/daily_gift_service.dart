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
  final String userComment;
  final bool hasGift;
  final DateTime unlockedAt;
  final DateTime sourceDate;

  const DailyGift({
    required this.id,
    required this.title,
    required this.description,
    this.userComment = '',
    required this.hasGift,
    required this.unlockedAt,
    required this.sourceDate,
  });

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'userComment': userComment,
      'hasGift': hasGift,
      'unlockedAt': unlockedAt.toIso8601String(),
      'sourceDate': _dateKey(sourceDate),
    };
  }

  static DailyGift fromJson(Map<String, Object?> json) {
    return DailyGift(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '찰떡이의 일기',
      description: json['description']?.toString() ?? '',
      userComment: json['userComment']?.toString() ?? '',
      hasGift: json['hasGift'] == true,
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
  static const _lastEntryDateKey = 'dailyGift.lastGiftDate.v1';
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
        '찰떡이의 일기가 도착했어요',
        '오늘 작업실에서 있었던 일을 보관함에 남겨둘게요.',
        tz.TZDateTime.from(next, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_gifts',
            '찰떡이의 일기',
            channelDescription: '정한 시간에 찰떡이의 작업실 일기 알림',
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
    if (prefs.getString(_lastEntryDateKey) == todayKey) return null;

    final existing = await loadGifts(grantIfDue: false);
    final spec = _giftCatalog[existing.length % _giftCatalog.length];
    final gift = DailyGift(
      id: '$todayKey-${spec.title}',
      title: spec.title,
      description: spec.description,
      hasGift: spec.hasGift,
      unlockedAt: current,
      sourceDate: DateTime(current.year, current.month, current.day),
    );
    final next = [gift, ...existing];
    await prefs.setString(
      _giftsKey,
      jsonEncode(next.map((gift) => gift.toJson()).toList()),
    );
    await prefs.setString(_lastEntryDateKey, todayKey);
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
      hasGift: spec.hasGift,
      unlockedAt: now,
      sourceDate: DateTime(now.year, now.month, now.day),
    );
    await prefs.setString(
      _giftsKey,
      jsonEncode([gift, ...existing].map((gift) => gift.toJson()).toList()),
    );
    return gift;
  }

  Future<void> saveUserComment(String giftId, String comment) async {
    final prefs = await SharedPreferences.getInstance();
    final gifts = await loadGifts(grantIfDue: false);
    final normalized = comment.trim();
    final next = gifts.map((gift) {
      if (gift.id != giftId) return gift;
      return DailyGift(
        id: gift.id,
        title: gift.title,
        description: gift.description,
        userComment: normalized,
        hasGift: gift.hasGift,
        unlockedAt: gift.unlockedAt,
        sourceDate: gift.sourceDate,
      );
    }).toList();
    await prefs.setString(
      _giftsKey,
      jsonEncode(next.map((gift) => gift.toJson()).toList()),
    );
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
  final bool hasGift;

  const _GiftSpec(
    this.title,
    this.description, {
    this.hasGift = false,
  });
}

const _giftCatalog = [
  _GiftSpec(
    '찰떡이의 작은 화분 배달',
    '찰떡이가 창고 한 바퀴를 돌더니 작은 화분을 물고 왔어요.\n\n'
        '옆집 꽃집의 미미가 “선반 위 빈자리에 딱 맞을 것”이라며 보냈대요. '
        '오늘 일기 맨 아래에는 삐뚤빼뚤하게 이렇게 적혀 있습니다.\n\n'
        '“화분은 움직이지 않아서 좋다. 그래도 내가 지켜봐야 한다.”',
    hasGift: true,
  ),
  _GiftSpec(
    '상자를 지키는 날',
    '찰떡이가 테이프가 잔뜩 붙은 상자를 질질 끌고 왔어요.\n\n'
        '상자 위에는 배달부 도담이가 남긴 “중요할지도 모름” 메모가 붙어 있습니다. '
        '열어보려 하자 찰떡이가 앞발로 살짝 막았어요.\n\n'
        '오늘 일기는 짧습니다. “상자는 아직 준비가 안 됐다. 나도 안 됐다.”',
    hasGift: true,
  ),
  _GiftSpec(
    '도장 연습',
    '찰떡이가 도장을 물고 와서 장부 옆에 내려놓았어요.\n\n'
        '문구점 사장님 토리가 “확인한 일에는 찍는 맛이 있어야 한다”고 했다나요. '
        '찰떡이는 빈 종이에 먼저 한 번 찍어보고는 아무 일도 없었다는 얼굴입니다.\n\n'
        '일기에는 “도장은 소리가 좋다. 종이는 놀라지 않았다.”라고 쓰여 있어요.',
    hasGift: true,
  ),
  _GiftSpec(
    '달력이 조금 삐뚤어진 날',
    '찰떡이와 이웃 고양이 나리가 달력을 들고 들어왔어요.\n\n'
        '둘이서 벽에 붙이다가 조금 삐뚤어졌지만, 오늘 날짜에는 동그라미가 제대로 그려졌습니다. '
        '찰떡이는 그 정도면 완벽하다고 믿는 눈치예요.\n\n'
        '나리는 “내일은 더 반듯하게 붙이자”고 했고, 찰떡이는 못 들은 척했습니다.',
  ),
  _GiftSpec(
    '유리병 검사',
    '찰떡이가 투명한 유리병 하나를 조심조심 굴려왔어요.\n\n'
        '골목 잡화점의 모리가 “작은 성실함을 담아두기 좋다”고 했대요. '
        '병은 비어 보이지만, 찰떡이는 벌써 꽤 찼다고 우기는 중입니다.\n\n'
        '일기 마지막 줄에는 “안 보이는 것도 들어갈 수 있다”라고 적혀 있어요.',
    hasGift: true,
  ),
  _GiftSpec(
    '라벨 스티커 소동',
    '찰떡이가 라벨 스티커 묶음을 물고 와 책상 위에 와르르 쏟았어요.\n\n'
        '분명 정리하라고 가져온 것 같은데, 몇 장은 찰떡이 발바닥에 붙어 있습니다. '
        '이웃 창고지기 루루가 웃으면서 여분을 더 두고 갔어요.\n\n'
        '찰떡이는 자기 발에 붙은 라벨을 한참 들여다보다가 “나도 분류됨”이라고 썼습니다.',
    hasGift: true,
  ),
  _GiftSpec(
    '장부 첫 장',
    '찰떡이가 낑낑거리며 장부 한 권을 밀고 왔어요.\n\n'
        '회계사무소의 은우가 “기록은 반듯할수록 나중에 편하다”고 보냈다네요. '
        '찰떡이는 첫 장에 발자국을 남길 뻔했지만, 가까스로 참았습니다.\n\n'
        '대신 일기장에는 아주 작은 발자국이 하나 남았습니다.',
    hasGift: true,
  ),
  _GiftSpec(
    '머그컵을 들고 온 이유',
    '찰떡이가 머그컵을 조심히 물고 오다가 문 앞에서 잠깐 멈췄어요.\n\n'
        '카페 사장 하루가 작업실에 두라고 챙겨준 컵이래요. '
        '찰떡이는 자기가 배달한 것 중 가장 깨지기 쉬운 물건이었다며 매우 진지한 표정입니다.\n\n'
        '일기에는 “깨지는 건 천천히 가져와야 한다”라고 적혀 있어요.',
    hasGift: true,
  ),
  _GiftSpec(
    '나리의 창가 관찰',
    '이웃 고양이 나리가 창가에 앉아 작업실을 한참 바라봤어요.\n\n'
        '찰떡이는 나리가 아무것도 안 한다고 생각했지만, 나리는 먼지가 쌓인 선반을 세 군데나 찾아냈습니다. '
        '오늘 일기에는 “가만히 있는 것도 일일 수 있다”라고 쓰여 있어요.',
  ),
  _GiftSpec(
    '루루가 남긴 쪽지',
    '이웃 창고지기 루루가 지나가며 작은 쪽지를 남겼어요.\n\n'
        '“급한 것과 중요한 것은 자주 헷갈린다. 찰떡이는 둘 다 물어온다.” '
        '찰떡이는 쪽지를 읽는 척하다가 종이 모서리만 아주 조금 접어두었습니다.',
  ),
  _GiftSpec(
    '도담이의 잘못 온 배달',
    '배달부 도담이가 옆 가게 물건을 잘못 들고 왔어요.\n\n'
        '찰떡이는 그걸 바로 알아차린 것처럼 고개를 끄덕였지만, 사실 상자 냄새가 달랐던 것 같습니다. '
        '오늘 일기 제목은 “냄새도 검수다”예요.',
  ),
  _GiftSpec(
    '미미의 물 주는 법',
    '꽃집의 미미가 화분에 물 주는 법을 알려주고 갔어요.\n\n'
        '찰떡이는 아주 진지하게 들었지만, 마지막에는 물뿌리개를 자기 밥그릇 옆에 놓았습니다. '
        '일기에는 “물은 위치가 중요하다”라고 적혀 있어요.',
  ),
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
