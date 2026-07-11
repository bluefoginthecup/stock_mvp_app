import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../db/app_database.dart';
import '../../models/production_guide.dart';
import '../../services/app_path_service.dart';
import '../../services/attachment_file_service.dart';
import '../../services/production_guide_service.dart';

class ItemProductionGuideScreen extends StatefulWidget {
  final String itemId;
  final String itemName;

  const ItemProductionGuideScreen({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<ItemProductionGuideScreen> createState() =>
      _ItemProductionGuideScreenState();
}

class _ItemProductionGuideScreenState extends State<ItemProductionGuideScreen> {
  late final ProductionGuideService _service;
  final Map<String, Timer> _saveTimers = {};
  final Map<String, String> _drafts = {};

  @override
  void initState() {
    super.initState();
    _service = ProductionGuideService(context.read<AppDatabase>());
  }

  @override
  void dispose() {
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _addStep() async {
    await _service.addTextBlock(
      itemId: widget.itemId,
      type: ProductionGuideBlockType.step,
      text: '',
    );
  }

  Future<void> _addNote(_GuideStep step) async {
    await _service.addTextBlock(
      itemId: widget.itemId,
      type: ProductionGuideBlockType.note,
      text: '',
      afterBlockId: step.lastBlockId,
    );
  }

  Future<void> _addImage(_GuideStep step) async {
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

    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (image == null) return;

      const paths = AppPathService();
      final stored = await const AttachmentFileService().copyOptimizedImage(
        sourcePath: image.path,
        originalFileName: image.name,
        destinationDirectory:
            await paths.productionGuideDirectory(widget.itemId),
      );
      final storedName = p.basename(stored.filePath);
      final relativePath = paths.productionGuideRelativePath(
        widget.itemId,
        storedName,
      );
      await _service.addImageBlock(
        itemId: widget.itemId,
        fileName: stored.fileName,
        filePath: relativePath,
        mimeType: stored.mimeType,
        afterBlockId: step.lastBlockId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 저장에 실패했습니다: $e')),
      );
    }
  }

  Future<void> _deleteBlock(ProductionGuideBlock block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('삭제'),
        content: Text(
          block.type == ProductionGuideBlockType.step
              ? '이 단계와 연결된 항목을 삭제할까요?'
              : '이 항목을 삭제할까요?',
        ),
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
    if (confirmed == true) {
      await _service.deleteBlock(block.id);
      _drafts.remove(block.id);
    }
  }

  Future<void> _deleteStep(_GuideStep step) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('단계 삭제'),
        content: const Text('이 단계와 연결된 사진/메모를 함께 삭제할까요?'),
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

    for (final block in step.blocks.reversed) {
      await _service.deleteBlock(block.id);
      _drafts.remove(block.id);
    }
  }

  Future<void> _openImage(ProductionGuideBlock block) async {
    final path = block.filePath;
    if (path == null || path.isEmpty) return;
    final file = await const AppPathService().resolveAppFile(path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 파일을 찾을 수 없습니다.')),
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
                block.fileName ?? '사진',
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
                minScale: 0.5,
                maxScale: 5,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rotateImage(ProductionGuideBlock block) async {
    final path = block.filePath;
    if (path == null || path.isEmpty) return;
    try {
      final file = await const AppPathService().resolveAppFile(path);
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) {
        throw const FormatException('Unsupported image format');
      }
      final rotated = img.copyRotate(decoded, angle: 90);
      await file.writeAsBytes(img.encodeJpg(rotated, quality: 85), flush: true);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 회전에 실패했습니다: $e')),
      );
    }
  }

  void _updateDraft(
    ProductionGuideBlock block,
    String value, {
    bool immediate = false,
  }) {
    _drafts[block.id] = value;
    _saveTimers[block.id]?.cancel();
    if (immediate) {
      _saveBlock(block.id, value);
      return;
    }
    _saveTimers[block.id] = Timer(const Duration(milliseconds: 650), () {
      _saveBlock(block.id, value);
    });
  }

  Future<void> _saveBlock(String blockId, String value) async {
    _saveTimers.remove(blockId)?.cancel();
    await _service.updateBlockText(blockId, value);
  }

  String _valueFor(ProductionGuideBlock block) {
    return _drafts[block.id] ?? _QuillTextCodec.normalize(block.text);
  }

  List<_GuideStep> _groupSteps(List<ProductionGuideBlock> blocks) {
    final steps = <_GuideStep>[];
    ProductionGuideBlock? currentStep;
    var children = <ProductionGuideBlock>[];
    var stepNumber = 0;

    void flush() {
      if (currentStep == null && children.isEmpty) return;
      final step = currentStep;
      steps.add(_GuideStep(
        stepBlock: step,
        blocks: [if (step != null) step, ...children],
        stepNumber: step == null ? 0 : stepNumber,
      ));
      children = [];
    }

    for (final block in blocks) {
      if (block.type == ProductionGuideBlockType.step) {
        flush();
        stepNumber += 1;
        currentStep = block;
      } else {
        children.add(block);
      }
    }
    flush();
    return steps;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.format_list_numbered, size: 48),
            const SizedBox(height: 12),
            Text(
              '첫 제작 단계를 추가해 보세요.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('단계 추가'),
              onPressed: _addStep,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(
    ProductionGuideData data,
    _GuideStep step,
    int index,
    int stepCount,
  ) {
    final theme = Theme.of(context);
    final stepBlock = step.stepBlock;
    final media = step.mediaBlocks;
    final notes = step.noteBlocks;
    final canMoveUp = index > 0 && stepBlock != null;
    final canMoveDown = index < stepCount - 1 && stepBlock != null;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  child:
                      Text(step.stepNumber == 0 ? '-' : '${step.stepNumber}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.stepNumber == 0 ? '미분류 항목' : '${step.stepNumber}단계',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: '위로',
                  onPressed: canMoveUp
                      ? () => _service.moveStep(
                            guideId: data.guide.id,
                            stepBlockId: stepBlock.id,
                            delta: -1,
                          )
                      : null,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: '아래로',
                  onPressed: canMoveDown
                      ? () => _service.moveStep(
                            guideId: data.guide.id,
                            stepBlockId: stepBlock.id,
                            delta: 1,
                          )
                      : null,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                if (stepBlock != null)
                  IconButton(
                    tooltip: '단계 삭제',
                    onPressed: () => _deleteStep(step),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (stepBlock != null) ...[
              const SizedBox(height: 8),
              _QuillStepEditor(
                key: ValueKey(stepBlock.id),
                value: _valueFor(stepBlock),
                hintText: '예: 고기를 손질한다',
                onChanged: (value) => _updateDraft(stepBlock, value),
              ),
            ],
            if (media.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 152,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: media.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, mediaIndex) => _GuideImageTile(
                    block: media[mediaIndex],
                    onTap: () => _openImage(media[mediaIndex]),
                    onRotate: () => _rotateImage(media[mediaIndex]),
                    onDelete: () => _deleteBlock(media[mediaIndex]),
                  ),
                ),
              ),
            ],
            for (final note in notes) ...[
              const SizedBox(height: 10),
              _NoteEditor(
                key: ValueKey(note.id),
                initialText: note.text ?? '',
                onChanged: (text) => _updateDraft(
                  note,
                  text,
                ),
                onDelete: () => _deleteBlock(note),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('사진'),
                  onPressed: () => _addImage(step),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.notes_outlined),
                  label: const Text('메모'),
                  onPressed: () => _addNote(step),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProductionGuideData?>(
      stream: _service.watchGuideData(widget.itemId),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final blocks = data?.blocks ?? const <ProductionGuideBlock>[];
        final steps = _groupSteps(blocks);
        final editableSteps =
            steps.where((step) => step.stepBlock != null).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.itemName} 제작 가이드'),
            actions: [
              IconButton(
                tooltip: '단계 추가',
                icon: const Icon(Icons.add),
                onPressed: _addStep,
              ),
            ],
          ),
          body: blocks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: steps.length,
                  itemBuilder: (context, index) => _buildStepCard(
                    data!,
                    steps[index],
                    editableSteps.indexWhere(
                      (step) =>
                          step.stepBlock?.id == steps[index].stepBlock?.id,
                    ),
                    editableSteps.length,
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('단계 추가'),
            onPressed: _addStep,
          ),
        );
      },
    );
  }
}

class _GuideStep {
  final ProductionGuideBlock? stepBlock;
  final List<ProductionGuideBlock> blocks;
  final int stepNumber;

  const _GuideStep({
    required this.stepBlock,
    required this.blocks,
    required this.stepNumber,
  });

  String? get lastBlockId => blocks.isEmpty ? stepBlock?.id : blocks.last.id;

  List<ProductionGuideBlock> get mediaBlocks => blocks
      .where((block) => block.type == ProductionGuideBlockType.image)
      .toList();

  List<ProductionGuideBlock> get noteBlocks => blocks
      .where((block) => block.type == ProductionGuideBlockType.note)
      .toList();
}

class _QuillStepEditor extends StatefulWidget {
  final String value;
  final String hintText;
  final ValueChanged<String> onChanged;

  const _QuillStepEditor({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<_QuillStepEditor> createState() => _QuillStepEditorState();
}

class _QuillStepEditorState extends State<_QuillStepEditor> {
  late final quill.QuillController _controller;
  StreamSubscription<dynamic>? _changesSubscription;

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController(
      document: _QuillTextCodec.documentFromStored(widget.value),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _changesSubscription = _controller.document.changes.listen((_) {
      widget.onChanged(_QuillTextCodec.encode(_controller.document));
    });
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _QuillStepEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _QuillTextCodec.encode(_controller.document) != widget.value) {
      _controller.document = _QuillTextCodec.documentFromStored(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: quill.QuillSimpleToolbar(
            controller: _controller,
            config: const quill.QuillSimpleToolbarConfig(
              showAlignmentButtons: true,
              showBackgroundColorButton: true,
              showColorButton: true,
              showFontFamily: true,
              showFontSize: true,
              showHeaderStyle: false,
              showInlineCode: false,
              showCodeBlock: false,
              showQuote: false,
              showSearchButton: false,
              multiRowsDisplay: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: quill.QuillEditor.basic(
                controller: _controller,
                config: quill.QuillEditorConfig(
                  placeholder: widget.hintText,
                  expands: false,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuillTextCodec {
  static const marker = '__guide_quill_delta_v1__';
  static const legacyMarker = '__guide_rich_text_v1__';

  static String normalize(String? raw) {
    if (raw == null || raw.isEmpty) {
      return encode(_plainDocument(''));
    }
    if (raw.startsWith(marker)) return raw;
    return encode(documentFromStored(raw));
  }

  static quill.Document documentFromStored(String? raw) {
    if (raw == null || raw.isEmpty) return _plainDocument('');
    if (raw.startsWith(marker)) {
      try {
        final decoded = jsonDecode(raw.substring(marker.length));
        if (decoded is List) {
          return quill.Document.fromJson(decoded.cast<Map<String, dynamic>>());
        }
      } catch (_) {}
    }
    if (raw.startsWith(legacyMarker)) {
      try {
        final decoded = jsonDecode(raw.substring(legacyMarker.length));
        if (decoded is Map<String, dynamic>) {
          return _plainDocument(decoded['text'] as String? ?? '');
        }
      } catch (_) {}
    }
    return _plainDocument(raw);
  }

  static String encode(quill.Document document) {
    return '$marker${jsonEncode(document.toDelta().toJson())}';
  }

  static quill.Document _plainDocument(String text) {
    final normalized = text.endsWith('\n') ? text : '$text\n';
    return quill.Document.fromJson([
      {'insert': normalized},
    ]);
  }
}

class _NoteEditor extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;

  const _NoteEditor({
    super.key,
    required this.initialText,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.notes_outlined),
              hintText: '주의사항이나 메모',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.onChanged,
          ),
        ),
        IconButton(
          tooltip: '메모 삭제',
          onPressed: widget.onDelete,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _GuideImageTile extends StatelessWidget {
  final ProductionGuideBlock block;
  final VoidCallback onTap;
  final VoidCallback onRotate;
  final VoidCallback onDelete;

  const _GuideImageTile({
    required this.block,
    required this.onTap,
    required this.onRotate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final path = block.filePath;
    if (path == null || path.isEmpty) {
      return const SizedBox(
        width: 144,
        child: Center(child: Text('사진 경로 없음')),
      );
    }
    return FutureBuilder<File>(
      future: const AppPathService().resolveAppFile(path),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return SizedBox(
          width: 164,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: file == null
                            ? const Center(child: CircularProgressIndicator())
                            : Image.file(
                                file,
                                fit: BoxFit.contain,
                                gaplessPlayback: false,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('사진 오류'),
                                ),
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: PopupMenuButton<String>(
                      tooltip: '사진 메뉴',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'open') onTap();
                        if (value == 'rotate') onRotate();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'open', child: Text('확대')),
                        PopupMenuItem(value: 'rotate', child: Text('90도 회전')),
                        PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
