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
import '../../services/entitlement_service.dart';
import 'schedule_edit_screen.dart';

class ScheduleDetailScreen extends StatefulWidget {
  final AppSchedule schedule;

  const ScheduleDetailScreen({
    super.key,
    required this.schedule,
  });

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  late AppSchedule _schedule;
  bool _addingAttachment = false;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
  }

  Future<void> _reload() async {
    final latest =
        await context.read<ScheduleRepo>().getScheduleById(_schedule.id);
    if (!mounted || latest == null) return;
    setState(() => _schedule = latest);
  }

  Future<void> _openEditor() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleEditScreen(schedule: _schedule),
      ),
    );
    if (changed == true) {
      await _reload();
    }
  }

  Future<void> _togglePinned() async {
    final next = _schedule.copyWith(
      isPinned: !_schedule.isPinned,
      updatedAt: DateTime.now(),
    );
    await context.read<ScheduleRepo>().updateSchedule(next);
    if (!mounted) return;
    setState(() => _schedule = next);
  }

  Future<void> _toggleStatus() async {
    final nextStatus = _schedule.status == AppScheduleStatus.pending
        ? AppScheduleStatus.done
        : AppScheduleStatus.pending;
    final next = _schedule.copyWith(
      status: nextStatus,
      updatedAt: DateTime.now(),
    );
    await context.read<ScheduleRepo>().updateSchedule(next);
    if (!mounted) return;
    setState(() => _schedule = next);
  }

  Future<void> _delete() async {
    final repo = context.read<ScheduleRepo>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('이 일정을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await repo.deleteSchedule(_schedule.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _pickImageAttachment() async {
    if (_addingAttachment) return;
    final repo = context.read<ScheduleRepo>();
    final policy = await AttachmentPolicyService(
      context.read<AppDatabase>(),
      entitlementService: context.read<EntitlementService>(),
    ).canAttach(
      domain: AttachmentDomain.scheduleAttachments,
      ownerId: _schedule.id,
    );
    if (!policy.allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(policy.message ?? '첨부할 수 없습니다.')),
      );
      return;
    }

    if (!mounted) return;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMobile)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('사진 촬영'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(isMobile ? '갤러리 선택' : '이미지 선택'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
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

      final dir = await paths.scheduleAttachmentDirectory(_schedule.id);
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
          paths.scheduleAttachmentRelativePath(_schedule.id, fileName);
      await repo.addScheduleAttachment(
        ScheduleAttachment(
          id: const Uuid().v4(),
          scheduleId: _schedule.id,
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
      builder: (dialogContext) => Dialog(
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
                  onPressed: () => Navigator.pop(dialogContext),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('첨부 이미지 삭제'),
        content: Text('${attachment.fileName}을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await repo.deleteScheduleAttachment(attachment.id);
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy-MM-dd').format(_schedule.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 상세'),
        actions: [
          IconButton(
            tooltip: _schedule.status == AppScheduleStatus.pending
                ? '한일로 변경'
                : '할일로 변경',
            icon: Icon(
              _schedule.status == AppScheduleStatus.pending
                  ? Icons.task_alt_rounded
                  : Icons.radio_button_unchecked,
            ),
            onPressed: _toggleStatus,
          ),
          IconButton(
            tooltip: _schedule.isPinned ? '고정 해제' : '고정',
            icon: Icon(
              _schedule.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            onPressed: _togglePinned,
          ),
          IconButton(
            tooltip: '수정',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEditor,
          ),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _schedule.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (_schedule.isPinned)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 4),
                  child: Icon(Icons.push_pin, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(label: Text(_schedule.statusLabel)),
              Chip(label: Text(dateText)),
              for (final tag in _schedule.tags) Chip(label: Text('#$tag')),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _toggleStatus,
            icon: Icon(
              _schedule.status == AppScheduleStatus.pending
                  ? Icons.task_alt_rounded
                  : Icons.radio_button_unchecked,
            ),
            label: Text(
              _schedule.status == AppScheduleStatus.pending
                  ? '한일로 변경'
                  : '할일로 변경',
            ),
          ),
          if (_schedule.body.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              _schedule.body,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 20),
          _ScheduleAttachmentSection(
            scheduleId: _schedule.id,
            adding: _addingAttachment,
            onAdd: _pickImageAttachment,
            onOpen: _openAttachment,
            onDelete: _deleteAttachment,
          ),
        ],
      ),
    );
  }
}

class _ScheduleAttachmentSection extends StatelessWidget {
  final String scheduleId;
  final bool adding;
  final VoidCallback onAdd;
  final ValueChanged<ScheduleAttachment> onOpen;
  final ValueChanged<ScheduleAttachment> onDelete;

  const _ScheduleAttachmentSection({
    required this.scheduleId,
    required this.adding,
    required this.onAdd,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                  onPressed: adding ? null : onAdd,
                  icon: adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(adding ? '첨부중' : '추가'),
                ),
              ],
            ),
            StreamBuilder<List<ScheduleAttachment>>(
              stream: context
                  .read<ScheduleRepo>()
                  .watchScheduleAttachments(scheduleId),
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
                        onOpen: () => onOpen(attachment),
                        onDelete: () => onDelete(attachment),
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
