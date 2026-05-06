import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_schedule.dart';
import '../../repos/repo_interfaces.dart';

class ScheduleEditScreen extends StatefulWidget {
  final AppSchedule? schedule;
  final ScheduleDraft? draft;

  const ScheduleEditScreen({
    super.key,
    this.schedule,
    this.draft,
  });

  @override
  State<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends State<ScheduleEditScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late AppScheduleStatus _status;
  bool _saving = false;

  bool get _isEdit => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    final draft = widget.draft;

    _titleController.text = schedule?.title ?? draft?.title ?? '';
    _bodyController.text = schedule?.body ?? draft?.body ?? '';
    _date = schedule?.date ?? draft?.date ?? DateTime.now();
    _status = schedule?.status ?? draft?.status ?? AppScheduleStatus.pending;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);
    final repo = context.read<ScheduleRepo>();
    final now = DateTime.now();
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    try {
      final existing = widget.schedule;
      if (existing == null) {
        final schedule = AppSchedule(
          id: const Uuid().v4(),
          title: title,
          body: body,
          date: _date,
          status: _status,
          sourceMemoId: widget.draft?.sourceMemoId,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createSchedule(schedule);
      } else {
        await repo.updateSchedule(
          existing.copyWith(
            title: title,
            body: body,
            date: _date,
            status: _status,
            updatedAt: now,
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정을 저장하지 못했습니다: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final schedule = widget.schedule;
    if (schedule == null) return;
    final repo = context.read<ScheduleRepo>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('이 일정을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await repo.deleteSchedule(schedule.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy-MM-dd').format(_date);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '일정 수정' : '일정 만들기'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const Text('저장중') : const Text('저장'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return '제목을 입력해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '내용',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('날짜'),
              subtitle: Text(dateText),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            const Divider(),
            SegmentedButton<AppScheduleStatus>(
              segments: const [
                ButtonSegment(
                  value: AppScheduleStatus.pending,
                  label: Text('할일'),
                  icon: Icon(Icons.radio_button_unchecked),
                ),
                ButtonSegment(
                  value: AppScheduleStatus.done,
                  label: Text('한일'),
                  icon: Icon(Icons.check_circle_outline),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (values) {
                setState(() => _status = values.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
