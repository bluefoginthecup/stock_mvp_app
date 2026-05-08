import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../models/attachment_domain.dart';
import '../../models/app_schedule.dart';
import '../../models/schedule_attachment.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/app_path_service.dart';
import '../../services/attachment_policy_service.dart';

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
  bool _addingAttachment = false;

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

  Future<void> _pickImageAttachment() async {
    final schedule = widget.schedule;
    if (schedule == null || _addingAttachment) return;
    final repo = context.read<ScheduleRepo>();
    final policy =
        await AttachmentPolicyService(context.read<AppDatabase>()).canAttach(
      domain: AttachmentDomain.scheduleAttachments,
      ownerId: schedule.id,
    );
    if (!policy.allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(policy.message ?? '첨부할 수 없습니다.')),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _addingAttachment = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (image == null) return;

      const paths = AppPathService();
      final sourceFile = File(image.path);
      if (!await sourceFile.exists()) {
        throw Exception('선택한 이미지 파일을 찾을 수 없습니다.');
      }

      final dir = await paths.scheduleAttachmentDirectory(schedule.id);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final originalExt = p.extension(image.name).toLowerCase();
      final ext = originalExt.isEmpty ? '.jpg' : originalExt;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}$ext';
      final destination = File(p.join(dir.path, fileName));
      await sourceFile.copy(destination.path);

      final relativePath =
          paths.scheduleAttachmentRelativePath(schedule.id, fileName);
      await repo.addScheduleAttachment(
        ScheduleAttachment(
          id: const Uuid().v4(),
          scheduleId: schedule.id,
          fileName: image.name,
          filePath: relativePath,
          mimeType: image.mimeType ?? 'image/jpeg',
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 첨부에 실패했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _addingAttachment = false);
    }
  }

  Future<void> _openAttachment(ScheduleAttachment attachment) async {
    final file =
        await const AppPathService().resolveAppFile(attachment.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('첨부 이미지를 찾을 수 없습니다.')),
      );
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAttachment(ScheduleAttachment attachment) async {
    final repo = context.read<ScheduleRepo>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('첨부 이미지 삭제'),
        content: Text('${attachment.fileName}을 삭제할까요?'),
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

    await repo.deleteScheduleAttachment(attachment.id);
  }

  Widget _buildAttachmentSection() {
    final schedule = widget.schedule;
    if (schedule == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('이미지 첨부는 일정을 저장한 뒤 사용할 수 있습니다.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '첨부 이미지',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addingAttachment ? null : _pickImageAttachment,
                  icon: _addingAttachment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_addingAttachment ? '첨부중' : '추가'),
                ),
              ],
            ),
            StreamBuilder<List<ScheduleAttachment>>(
              stream: context
                  .read<ScheduleRepo>()
                  .watchScheduleAttachments(schedule.id),
              builder: (context, snapshot) {
                final attachments =
                    snapshot.data ?? const <ScheduleAttachment>[];
                if (attachments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('첨부된 이미지가 없습니다.'),
                  );
                }

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final attachment in attachments)
                      _ScheduleAttachmentTile(
                        attachment: attachment,
                        onOpen: () => _openAttachment(attachment),
                        onDelete: () => _deleteAttachment(attachment),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
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
            const SizedBox(height: 16),
            _buildAttachmentSection(),
          ],
        ),
      ),
    );
  }
}

class _ScheduleAttachmentTile extends StatelessWidget {
  final ScheduleAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ScheduleAttachmentTile({
    required this.attachment,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: const AppPathService().resolveAppFile(attachment.filePath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 96,
                    color: Colors.grey.shade100,
                    child: file == null
                        ? const Center(child: CircularProgressIndicator())
                        : Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('삭제'),
              ),
            ],
          ),
        );
      },
    );
  }
}
