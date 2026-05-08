import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_schedule.dart';
import '../../repos/repo_interfaces.dart';
import '../../utils/tag_utils.dart';

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
  final _titleFocusNode = FocusNode();
  final _bodyFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late AppScheduleStatus _status;
  bool _saving = false;
  List<String> _knownTags = const [];

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
    _titleController.addListener(_refreshTagSuggestions);
    _bodyController.addListener(_refreshTagSuggestions);
    _titleFocusNode.addListener(_refreshTagSuggestions);
    _bodyFocusNode.addListener(_refreshTagSuggestions);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadKnownTags();
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_refreshTagSuggestions);
    _bodyController.removeListener(_refreshTagSuggestions);
    _titleFocusNode.removeListener(_refreshTagSuggestions);
    _bodyFocusNode.removeListener(_refreshTagSuggestions);
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadKnownTags() async {
    final schedules = await context.read<ScheduleRepo>().watchSchedules().first;
    if (!mounted) return;
    setState(() => _knownTags = collectTagsFromSchedules(schedules));
  }

  void _refreshTagSuggestions() {
    if (!mounted) return;
    setState(() {});
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
    final tags = extractHashTagsFromSchedule(title: title, body: body);

    try {
      final existing = widget.schedule;
      if (existing == null) {
        final schedule = AppSchedule(
          id: const Uuid().v4(),
          title: title,
          body: body,
          tags: tags,
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
            tags: tags,
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

  _ActiveTagInput? _activeTagInput() {
    if (_titleFocusNode.hasFocus) {
      return _activeTagInputFor(_titleController);
    }
    if (_bodyFocusNode.hasFocus) {
      return _activeTagInputFor(_bodyController);
    }
    return null;
  }

  _ActiveTagInput? _activeTagInputFor(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final fragment = findActiveHashTagFragment(
      text: controller.text,
      cursorOffset: selection.baseOffset,
    );
    if (fragment == null) return null;
    return _ActiveTagInput(controller: controller, fragment: fragment);
  }

  void _applyTagSuggestion(_ActiveTagInput input, String tag) {
    final text = input.controller.text;
    final replaced = replaceHashTagFragment(
      text: text,
      fragment: input.fragment,
      tag: tag,
    );
    final offset = input.fragment.start + normalizeTag(tag).length + 1;
    input.controller.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  void _insertKnownTag(String tag) {
    final controller =
        _titleFocusNode.hasFocus ? _titleController : _bodyController;
    if (!_titleFocusNode.hasFocus && !_bodyFocusNode.hasFocus) {
      _bodyFocusNode.requestFocus();
    }

    final selection = controller.selection;
    final offset =
        selection.isValid ? selection.baseOffset : controller.text.length;
    final safeOffset = offset.clamp(0, controller.text.length);
    final prefix =
        safeOffset == 0 || controller.text[safeOffset - 1].trim().isEmpty
            ? ''
            : ' ';
    final insertText = '$prefix#${normalizeTag(tag)} ';
    final nextText =
        controller.text.replaceRange(safeOffset, safeOffset, insertText);
    controller.value = TextEditingValue(
      text: nextText,
      selection:
          TextSelection.collapsed(offset: safeOffset + insertText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy-MM-dd').format(_date);
    final activeTagInput = _activeTagInput();
    final suggestions = activeTagInput == null
        ? const <String>[]
        : suggestHashTags(
            query: activeTagInput.fragment.query,
            candidates: _knownTags,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '일정 수정' : '일정 만들기'),
        actions: [
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
              focusNode: _titleFocusNode,
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
              focusNode: _bodyFocusNode,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '내용',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (activeTagInput != null && suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _TagSuggestionChips(
                suggestions: suggestions,
                onSelected: (tag) => _applyTagSuggestion(activeTagInput, tag),
              ),
            ],
            if (_knownTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              _KnownTagChips(
                tags: _knownTags.take(12).toList(growable: false),
                onSelected: _insertKnownTag,
              ),
            ],
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

class _ActiveTagInput {
  final TextEditingController controller;
  final ActiveHashTagFragment fragment;

  const _ActiveTagInput({
    required this.controller,
    required this.fragment,
  });
}

class _TagSuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  const _TagSuggestionChips({
    required this.suggestions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tag in suggestions)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                label: Text('#$tag'),
                visualDensity: VisualDensity.compact,
                onPressed: () => onSelected(tag),
              ),
            ),
        ],
      ),
    );
  }
}

class _KnownTagChips extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<String> onSelected;

  const _KnownTagChips({
    required this.tags,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 태그',
          style: textTheme.labelMedium?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tag in tags)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text('#$tag'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onSelected(tag),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
