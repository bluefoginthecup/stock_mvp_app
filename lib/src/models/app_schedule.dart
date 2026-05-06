enum AppScheduleStatus { pending, done }

class ScheduleDraft {
  final String title;
  final String body;
  final DateTime date;
  final AppScheduleStatus status;
  final int? sourceMemoId;

  const ScheduleDraft({
    required this.title,
    required this.body,
    required this.date,
    this.status = AppScheduleStatus.pending,
    this.sourceMemoId,
  });

  factory ScheduleDraft.fromSelectedText(
    String text, {
    int? sourceMemoId,
    DateTime? date,
  }) {
    final trimmed = text.trim();
    final title =
        trimmed.length <= 30 ? trimmed : '${trimmed.substring(0, 30)}...';

    return ScheduleDraft(
      title: title,
      body: trimmed,
      date: date ?? DateTime.now(),
      sourceMemoId: sourceMemoId,
    );
  }
}

class AppSchedule {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final AppScheduleStatus status;
  final int? sourceMemoId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppSchedule({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.status = AppScheduleStatus.pending,
    this.sourceMemoId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDone => status == AppScheduleStatus.done;
  String get statusLabel => isDone ? '한일' : '할일';

  AppSchedule copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? date,
    AppScheduleStatus? status,
    int? sourceMemoId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSchedule(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      date: date ?? this.date,
      status: status ?? this.status,
      sourceMemoId: sourceMemoId ?? this.sourceMemoId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AppSchedule.fromJson(Map<String, dynamic> json) {
    return AppSchedule(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      status: AppScheduleStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending'),
        orElse: () => AppScheduleStatus.pending,
      ),
      sourceMemoId: (json['sourceMemoId'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'date': date.toIso8601String(),
        'status': status.name,
        'sourceMemoId': sourceMemoId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
