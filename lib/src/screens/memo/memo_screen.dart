import 'dart:async';
import 'package:flutter/material.dart';
import '../../repos/modules/memo_repo.dart';
import '../../models/app_schedule.dart';
import '../schedules/schedule_edit_screen.dart';
import '../schedules/schedule_list_screen.dart';

class MemoScreen extends StatefulWidget {
  const MemoScreen({super.key});

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  final _controller = TextEditingController();
  final _repo = MemoRepo();
  UndoHistoryController _undoController = UndoHistoryController();
  Timer? _debounce;
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    _load();
    // 🔥 추가 (붙여넣기 대응)
    _controller.addListener(() {
      _onChanged(_controller.text);
    });
  }

  Future<void> _load() async {
    final text = await _repo.load();
    if (!mounted) return;
    _hydrating = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _hydrating = false;
    _resetUndoHistory();
  }

  void _onChanged(String text) {
    if (_hydrating) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _repo.save(text);
    });
  }

  void _resetUndoHistory() {
    final old = _undoController;
    setState(() {
      _undoController = UndoHistoryController();
    });
    old.dispose();
  }

  Future<void> _createScheduleFromSelection(String selectedText) async {
    final text = selectedText.trim();
    if (text.isEmpty) return;

    final memoId = await _repo.saveAndReturnId(_controller.text);
    if (!mounted) return;

    final draft = ScheduleDraft.fromSelectedText(
      text,
      sourceMemoId: memoId,
    );
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleEditScreen(draft: draft),
      ),
    );

    if (!mounted || saved != true) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScheduleListScreen()),
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final value = editableTextState.textEditingValue;
    final selection = value.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final buttonItems = <ContextMenuButtonItem>[
      ...editableTextState.contextMenuButtonItems,
      if (hasSelection)
        ContextMenuButtonItem(
          label: '일정 만들기',
          onPressed: () {
            final selectedText = selection.textInside(value.text);
            ContextMenuController.removeAny();
            _createScheduleFromSelection(selectedText);
          },
        ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();

    // 🔥 마지막 저장
    _repo.save(_controller.text);

    _undoController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메모'),
        actions: [
          IconButton(
            tooltip: '일정/할일',
            icon: const Icon(Icons.event_note),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduleListScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          undoController: _undoController,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            hintText: '자유롭게 메모하세요...',
            border: InputBorder.none,
          ),
          contextMenuBuilder: _buildContextMenu,
          onChanged: _onChanged,
        ),
      ),
    );
  }
}
