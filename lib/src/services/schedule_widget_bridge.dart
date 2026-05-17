import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_schedule.dart';
import '../repos/repo_interfaces.dart';
import '../screens/memo/memo_screen.dart';
import '../screens/schedules/schedule_edit_screen.dart';
import '../screens/schedules/schedule_detail_screen.dart';
import '../screens/schedules/schedule_list_screen.dart';
import '../screens/stock/stock_browser_screen.dart';

class ScheduleWidgetBridge {
  static const MethodChannel _channel = MethodChannel('chalstock/widget');
  static bool _initialized = false;
  static bool _syncInFlight = false;
  static bool _syncAgain = false;
  static final ValueNotifier<String> lastSyncStatus =
      ValueNotifier<String>('위젯 동기화 전');

  static Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (!Platform.isIOS) return;
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'widgetAction') {
        await _handleAction(navigatorKey, call.arguments?.toString());
      }
    });

    try {
      final action = await _channel.invokeMethod<String>('getInitialAction');
      await _handleAction(navigatorKey, action);
    } catch (e) {
      debugPrint('[ScheduleWidgetBridge] initial action failed: $e');
    }
  }

  static Future<void> syncTodaySchedules(ScheduleRepo repo) async {
    if (!Platform.isIOS) return;
    if (_syncInFlight) {
      _syncAgain = true;
      return;
    }

    _syncInFlight = true;
    try {
      final schedules = await repo.listSchedulesByDate(DateTime.now());
      final payload = _buildPayload(schedules);
      await _channel.invokeMethod<void>(
        'saveTodaySchedulesJson',
        jsonEncode(payload),
      );
      lastSyncStatus.value =
          '성공 ${DateFormat('HH:mm:ss').format(DateTime.now())} / 오늘 ${schedules.length}개';
    } catch (e) {
      lastSyncStatus.value = '실패: $e';
      debugPrint('[ScheduleWidgetBridge] sync failed: $e');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        final schedules = await repo.listSchedulesByDate(DateTime.now());
        final payload = _buildPayload(schedules);
        await _channel.invokeMethod<void>(
          'saveTodaySchedulesJson',
          jsonEncode(payload),
        );
        lastSyncStatus.value =
            '재시도 성공 ${DateFormat('HH:mm:ss').format(DateTime.now())} / 오늘 ${schedules.length}개';
      } catch (retryError) {
        lastSyncStatus.value = '재시도 실패: $retryError';
        debugPrint('[ScheduleWidgetBridge] sync retry failed: $retryError');
      }
    } finally {
      _syncInFlight = false;
      if (_syncAgain) {
        _syncAgain = false;
        unawaited(syncTodaySchedules(repo));
      }
    }
  }

  static Map<String, Object?> _buildPayload(List<AppSchedule> schedules) {
    final today = DateTime.now();
    final sorted = [...schedules]..sort((a, b) {
        final pinned = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
        if (pinned != 0) return pinned;
        final status = a.status.index.compareTo(b.status.index);
        if (status != 0) return status;
        return a.date.compareTo(b.date);
      });

    return {
      'dateLabel': DateFormat('M월 d일 EEEE', 'ko_KR').format(today),
      'updatedAtLabel': DateFormat('HH:mm').format(DateTime.now()),
      'pendingCount':
          schedules.where((s) => s.status == AppScheduleStatus.pending).length,
      'doneCount':
          schedules.where((s) => s.status == AppScheduleStatus.done).length,
      'schedules': sorted.take(10).map(_scheduleToJson).toList(growable: false),
    };
  }

  static Map<String, Object?> _scheduleToJson(AppSchedule schedule) {
    final body = schedule.body.trim();
    return {
      'id': schedule.id,
      'title': schedule.title,
      'body': body,
      'status': schedule.status.name,
      'isPinned': schedule.isPinned,
    };
  }

  static Future<void> _handleAction(
    GlobalKey<NavigatorState> navigatorKey,
    String? action,
  ) async {
    if (action == null || action.isEmpty) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (action) {
      case 'home':
        navigator.popUntil((route) => route.isFirst);
        break;
      case 'newSchedule':
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => const ScheduleEditScreen(),
            settings: const RouteSettings(name: '/schedules/new'),
          ),
        );
        break;
      case 'todaySchedules':
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => const ScheduleListScreen(),
            settings: const RouteSettings(name: '/schedules'),
          ),
        );
        break;
      case 'stock':
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => const StockBrowserScreen(autofocusSearch: true),
            settings: const RouteSettings(name: '/stock'),
          ),
        );
        break;
      case 'memo':
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => const MemoScreen(focusAtEnd: true),
            settings: const RouteSettings(name: '/memo'),
          ),
        );
        break;
      default:
        if (action.startsWith('schedule:')) {
          final id = action.substring('schedule:'.length);
          final repo = navigator.context.read<ScheduleRepo>();
          final schedule = await repo.getScheduleById(id);
          if (schedule == null) return;
          navigator.push(
            MaterialPageRoute(
              builder: (_) => const ScheduleListScreen(),
              settings: const RouteSettings(name: '/schedules'),
            ),
          );
          await Future<void>.delayed(Duration.zero);
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => ScheduleDetailScreen(schedule: schedule),
              settings: RouteSettings(
                name: '/schedules/detail',
                arguments: id,
              ),
            ),
          );
        }
    }
  }
}

class ScheduleWidgetSync extends StatefulWidget {
  final ScheduleRepo repo;
  final Widget child;

  const ScheduleWidgetSync({
    super.key,
    required this.repo,
    required this.child,
  });

  @override
  State<ScheduleWidgetSync> createState() => _ScheduleWidgetSyncState();
}

class _ScheduleWidgetSyncState extends State<ScheduleWidgetSync> {
  StreamSubscription<List<AppSchedule>>? _subscription;
  Timer? _debounce;
  late AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant ScheduleWidgetSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repo != widget.repo) {
      _subscription?.cancel();
      _debounce?.cancel();
      _lifecycleListener.dispose();
      _start();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounce?.cancel();
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _start() {
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(ScheduleWidgetBridge.syncTodaySchedules(
        widget.repo,
      )),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ScheduleWidgetBridge.syncTodaySchedules(widget.repo));
    });
    _subscription = widget.repo.watchSchedules().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        unawaited(ScheduleWidgetBridge.syncTodaySchedules(widget.repo));
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
