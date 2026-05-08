import '../models/item.dart';

class ReorderScheduleStatus {
  final bool shouldShow;
  final String label;
  final bool overdue;

  const ReorderScheduleStatus({
    required this.shouldShow,
    required this.label,
    required this.overdue,
  });
}

class ReorderScheduleUtils {
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime? calculateNextReorderDate({
    required DateTime? lastOrderedAt,
    required int? intervalDays,
    DateTime? now,
  }) {
    if (intervalDays == null || intervalDays <= 0) return null;
    final base = dateOnly(lastOrderedAt ?? now ?? DateTime.now());
    return base.add(Duration(days: intervalDays));
  }

  static DateTime? reminderDate({
    required DateTime? nextReorderDate,
    required int daysBefore,
  }) {
    if (nextReorderDate == null) return null;
    final safeDays = daysBefore < 0 ? 0 : daysBefore;
    return dateOnly(nextReorderDate).subtract(Duration(days: safeDays));
  }

  static bool isReminderDue(Item item, {DateTime? now}) {
    if (item.reorderIntervalDays == null || item.nextReorderDate == null) {
      return false;
    }
    final today = dateOnly(now ?? DateTime.now());
    final reminder = reminderDate(
      nextReorderDate: item.nextReorderDate,
      daysBefore: item.reorderReminderDaysBefore,
    );
    return reminder != null && !today.isBefore(reminder);
  }

  static ReorderScheduleStatus statusFor(Item item, {DateTime? now}) {
    if (!isReminderDue(item, now: now) || item.nextReorderDate == null) {
      return const ReorderScheduleStatus(
        shouldShow: false,
        label: '',
        overdue: false,
      );
    }

    final today = dateOnly(now ?? DateTime.now());
    final next = dateOnly(item.nextReorderDate!);
    final diff = next.difference(today).inDays;
    if (diff < 0) {
      return const ReorderScheduleStatus(
        shouldShow: true,
        label: '발주 예정일 지남',
        overdue: true,
      );
    }
    if (diff == 0) {
      return const ReorderScheduleStatus(
        shouldShow: true,
        label: '오늘 발주 예정',
        overdue: false,
      );
    }
    return ReorderScheduleStatus(
      shouldShow: true,
      label: '$diff일 후 발주 예정',
      overdue: false,
    );
  }
}
