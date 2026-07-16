import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_schedule.dart';
import '../models/types.dart';
import '../models/work.dart';
import '../repos/repo_interfaces.dart';
import '../screens/memo/memo_screen.dart';
import '../screens/schedules/schedule_edit_screen.dart';
import '../screens/schedules/schedule_detail_screen.dart';
import '../screens/schedules/schedule_list_screen.dart';
import '../screens/stock/stock_browser_screen.dart';
import '../screens/works/work_detail_screen.dart';
import '../screens/works/work_list_screen.dart';

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

  static Future<void> syncTodaySchedules(
    ScheduleRepo repo, {
    WorkRepo? workRepo,
    ItemRepo? itemRepo,
  }) async {
    if (!Platform.isIOS) return;
    if (_syncInFlight) {
      _syncAgain = true;
      return;
    }

    _syncInFlight = true;
    try {
      final schedules = await repo.listSchedulesByDate(DateTime.now());
      final works = await _loadWorks(workRepo);
      final payload = await _buildPayload(
        schedules,
        works: works,
        itemRepo: itemRepo,
      );
      await _channel.invokeMethod<void>(
        'saveTodaySchedulesJson',
        jsonEncode(payload),
      );
      lastSyncStatus.value =
          '성공 ${DateFormat('HH:mm:ss').format(DateTime.now())} / 오늘 ${schedules.length}개 · 작업 ${works.length}개';
    } catch (e) {
      lastSyncStatus.value = '실패: $e';
      debugPrint('[ScheduleWidgetBridge] sync failed: $e');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        final schedules = await repo.listSchedulesByDate(DateTime.now());
        final works = await _loadWorks(workRepo);
        final payload = await _buildPayload(
          schedules,
          works: works,
          itemRepo: itemRepo,
        );
        await _channel.invokeMethod<void>(
          'saveTodaySchedulesJson',
          jsonEncode(payload),
        );
        lastSyncStatus.value =
            '재시도 성공 ${DateFormat('HH:mm:ss').format(DateTime.now())} / 오늘 ${schedules.length}개 · 작업 ${works.length}개';
      } catch (retryError) {
        lastSyncStatus.value = '재시도 실패: $retryError';
        debugPrint('[ScheduleWidgetBridge] sync retry failed: $retryError');
      }
    } finally {
      _syncInFlight = false;
      if (_syncAgain) {
        _syncAgain = false;
        unawaited(syncTodaySchedules(
          repo,
          workRepo: workRepo,
          itemRepo: itemRepo,
        ));
      }
    }
  }

  static Future<List<Work>> _loadWorks(WorkRepo? workRepo) async {
    if (workRepo == null) return const <Work>[];
    try {
      return await workRepo.watchAllWorks().first;
    } catch (e) {
      debugPrint('[ScheduleWidgetBridge] work load failed: $e');
      return const <Work>[];
    }
  }

  static Future<Map<String, Object?>> _buildPayload(
    List<AppSchedule> schedules, {
    required List<Work> works,
    ItemRepo? itemRepo,
  }) async {
    final today = DateTime.now();
    final sorted = [...schedules]..sort((a, b) {
        final pinned = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
        if (pinned != 0) return pinned;
        final status = a.status.index.compareTo(b.status.index);
        if (status != 0) return status;
        return a.date.compareTo(b.date);
      });
    final activeWorks = works
        .where((w) =>
            w.status == WorkStatus.planned || w.status == WorkStatus.inProgress)
        .toList(growable: false);
    final activeTodayWorks =
        activeWorks.where((w) => _isWorkActiveToday(w, today)).toList();
    final doneTodayWorks = works
        .where((w) => w.status == WorkStatus.done && _isWorkDoneToday(w, today))
        .toList(growable: false);
    final sortedWorks = works
        .where((w) =>
            (w.status == WorkStatus.planned ||
                w.status == WorkStatus.inProgress) &&
            _isWorkActiveToday(w, today))
        .toList()
      ..sort((a, b) {
        final status =
            _workSortRank(a.status).compareTo(_workSortRank(b.status));
        if (status != 0) return status;
        return b.createdAt.compareTo(a.createdAt);
      });
    final visibleWorks = sortedWorks.take(6).toList(growable: false);
    final workItems = <Map<String, Object?>>[];
    for (final work in visibleWorks) {
      workItems.add(await _workToJson(work, itemRepo));
    }

    return {
      'dateLabel': DateFormat('M월 d일 EEEE', 'ko_KR').format(today),
      'updatedAtLabel': DateFormat('HH:mm').format(DateTime.now()),
      'pendingCount':
          schedules.where((s) => s.status == AppScheduleStatus.pending).length,
      'doneCount':
          schedules.where((s) => s.status == AppScheduleStatus.done).length,
      'schedules': sorted.take(10).map(_scheduleToJson).toList(growable: false),
      'workPendingCount': activeTodayWorks.length,
      'workDoneCount': doneTodayWorks.length,
      'works': workItems,
    };
  }

  static bool _isWorkActiveToday(Work work, DateTime today) {
    return _isSameDay(work.startedAt, today) ||
        _isSameDay(work.updatedAt, today) ||
        _isSameDay(work.createdAt, today);
  }

  static bool _isWorkDoneToday(Work work, DateTime today) {
    return _isSameDay(work.finishedAt, today) ||
        _isSameDay(work.updatedAt, today) ||
        _isSameDay(work.createdAt, today);
  }

  static bool _isSameDay(DateTime? value, DateTime day) {
    if (value == null) return false;
    return value.year == day.year &&
        value.month == day.month &&
        value.day == day.day;
  }

  static int _workSortRank(WorkStatus status) {
    switch (status) {
      case WorkStatus.inProgress:
        return 0;
      case WorkStatus.planned:
        return 1;
      case WorkStatus.done:
        return 2;
      case WorkStatus.canceled:
        return 3;
    }
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

  static Future<Map<String, Object?>> _workToJson(
    Work work,
    ItemRepo? itemRepo,
  ) async {
    var title = '';
    if (itemRepo != null) {
      try {
        title = (await itemRepo.nameOf(work.itemId))?.trim() ?? '';
      } catch (_) {}
    }
    if (title.isEmpty) {
      final shortId = work.id.length <= 8 ? work.id : work.id.substring(0, 8);
      title = '작업 $shortId';
    }
    return {
      'id': work.id,
      'title': title,
      'status': work.status.name,
      'qty': work.qty,
      'doneQty': work.doneQty,
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
      case 'works':
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => const WorkListScreen(),
            settings: const RouteSettings(name: '/works'),
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
        } else if (action.startsWith('work:')) {
          final id = action.substring('work:'.length);
          final repo = navigator.context.read<WorkRepo>();
          final work = await repo.getWorkById(id);
          if (work == null) return;
          navigator.push(
            MaterialPageRoute(
              builder: (_) => const WorkListScreen(),
              settings: const RouteSettings(name: '/works'),
            ),
          );
          await Future<void>.delayed(Duration.zero);
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => WorkDetailScreen(work: work),
              settings: RouteSettings(
                name: '/works/detail',
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
  final WorkRepo? workRepo;
  final ItemRepo? itemRepo;
  final Widget child;

  const ScheduleWidgetSync({
    super.key,
    required this.repo,
    this.workRepo,
    this.itemRepo,
    required this.child,
  });

  @override
  State<ScheduleWidgetSync> createState() => _ScheduleWidgetSyncState();
}

class _ScheduleWidgetSyncState extends State<ScheduleWidgetSync> {
  StreamSubscription<List<AppSchedule>>? _subscription;
  StreamSubscription<List<Work>>? _workSubscription;
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
      _workSubscription?.cancel();
      _debounce?.cancel();
      _lifecycleListener.dispose();
      _start();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _workSubscription?.cancel();
    _debounce?.cancel();
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _start() {
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(ScheduleWidgetBridge.syncTodaySchedules(
        widget.repo,
        workRepo: widget.workRepo,
        itemRepo: widget.itemRepo,
      )),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ScheduleWidgetBridge.syncTodaySchedules(
        widget.repo,
        workRepo: widget.workRepo,
        itemRepo: widget.itemRepo,
      ));
    });
    _subscription = widget.repo.watchSchedules().listen((_) {
      _queueSync();
    });
    _workSubscription = widget.workRepo?.watchAllWorks().listen((_) {
      _queueSync();
    });
  }

  void _queueSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(ScheduleWidgetBridge.syncTodaySchedules(
        widget.repo,
        workRepo: widget.workRepo,
        itemRepo: widget.itemRepo,
      ));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
