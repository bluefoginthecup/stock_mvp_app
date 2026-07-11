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

  @override
  void initState() {
    super.initState();
    _service = ProductionGuideService(context.read<AppDatabase>());
  }

  Future<void> _createGuide() async {
    final title = await _showTitleDialog(
      context: context,
      title: '새 제작 가이드',
      initial: '${widget.itemName} 제작 가이드',
    );
    if (title == null) return;
    final data = await _service.createGuide(
      itemId: widget.itemId,
      title: title,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductionGuideEditorScreen(
          itemName: widget.itemName,
          guideId: data.guide.id,
        ),
      ),
    );
  }

  Future<void> _renameGuide(ProductionGuide guide) async {
    final title = await _showTitleDialog(
      context: context,
      title: '이름 변경',
      initial: guide.title,
    );
    if (title == null) return;
    await _service.updateGuideTitle(guide.id, title);
  }

  Future<void> _deleteGuide(ProductionGuide guide) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('제작 가이드 삭제'),
        content: Text('"${guide.title}" 가이드를 삭제할까요?'),
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
      await _service.deleteGuide(guide.id);
    }
  }

  void _openGuide(ProductionGuide guide) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductionGuideViewScreen(
          itemName: widget.itemName,
          guideId: guide.id,
        ),
      ),
    );
  }

  Widget _buildGuideTile(ProductionGuideData data) {
    final guide = data.guide;
    final plainText = _GuideDocumentCodec.plainTextFromData(data);
    final summary = plainText.trim().isEmpty
        ? '아직 작성된 내용이 없습니다'
        : plainText.trim().replaceAll(RegExp(r'\s+'), ' ');

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            guide.isPrimary ? Icons.star_outline : Icons.article_outlined,
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(guide.title)),
            if (guide.isPrimary)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text('대표'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        subtitle: Text(
          summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'primary') {
              _service.setPrimaryGuide(
                  itemId: widget.itemId, guideId: guide.id);
            } else if (value == 'rename') {
              _renameGuide(guide);
            } else if (value == 'delete') {
              _deleteGuide(guide);
            }
          },
          itemBuilder: (_) => [
            if (!guide.isPrimary)
              const PopupMenuItem(value: 'primary', child: Text('대표로 지정')),
            const PopupMenuItem(value: 'rename', child: Text('이름 변경')),
            const PopupMenuItem(value: 'delete', child: Text('삭제')),
          ],
        ),
        onTap: () => _openGuide(guide),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProductionGuideData>>(
      stream: _service.watchGuideList(widget.itemId),
      builder: (context, snapshot) {
        final guides = snapshot.data ?? const <ProductionGuideData>[];
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.itemName} 제작 가이드'),
            actions: [
              IconButton(
                tooltip: '새 가이드',
                icon: const Icon(Icons.add),
                onPressed: _createGuide,
              ),
            ],
          ),
          body: guides.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.article_outlined, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          '아직 제작 가이드가 없습니다.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('새 가이드'),
                          onPressed: _createGuide,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: guides.length,
                  itemBuilder: (context, index) =>
                      _buildGuideTile(guides[index]),
                ),
          floatingActionButton: guides.isEmpty
              ? null
              : FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('새 가이드'),
                  onPressed: _createGuide,
                ),
        );
      },
    );
  }
}

class ProductionGuideViewScreen extends StatelessWidget {
  final String itemName;
  final String guideId;

  const ProductionGuideViewScreen({
    super.key,
    required this.itemName,
    required this.guideId,
  });

  @override
  Widget build(BuildContext context) {
    final service = ProductionGuideService(context.read<AppDatabase>());
    return StreamBuilder<ProductionGuideData?>(
      stream: service.watchGuideDataById(guideId),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final title = data?.guide.title ?? '제작 가이드';
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (data != null)
                IconButton(
                  tooltip: '수정',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductionGuideEditorScreen(
                          itemName: itemName,
                          guideId: guideId,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: data == null
              ? const Center(child: Text('제작 가이드를 찾을 수 없습니다.'))
              : _GuideDocumentViewer(data: data),
        );
      },
    );
  }
}

class ProductionGuideEditorScreen extends StatefulWidget {
  final String itemName;
  final String guideId;

  const ProductionGuideEditorScreen({
    super.key,
    required this.itemName,
    required this.guideId,
  });

  @override
  State<ProductionGuideEditorScreen> createState() =>
      _ProductionGuideEditorScreenState();
}

class _ProductionGuideEditorScreenState
    extends State<ProductionGuideEditorScreen> {
  late final ProductionGuideService _service;
  late final Future<_GuideDocument> _documentFuture;
  quill.QuillController? _controller;
  Timer? _saveTimer;
  StreamSubscription<dynamic>? _changesSubscription;
  String? _docBlockId;
  String? _itemId;
  String? _guideTitle;
  int _imageRefresh = 0;

  @override
  void initState() {
    super.initState();
    _service = ProductionGuideService(context.read<AppDatabase>());
    _documentFuture = _loadDocument();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _changesSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<_GuideDocument> _loadDocument() async {
    final data = await _service.getGuideDataById(widget.guideId);
    if (data == null) {
      throw StateError('Guide not found');
    }
    _itemId = data.guide.itemId;
    _guideTitle = data.guide.title;

    final docBlock = _GuideDocumentCodec.findDocumentBlock(data.blocks);
    if (docBlock != null) {
      return _GuideDocument(
        blockId: docBlock.id,
        storedText: _QuillTextCodec.normalize(docBlock.text),
      );
    }

    final storedText = _QuillTextCodec.encode(
      _GuideDocumentCodec.legacyDocument(data.blocks),
    );
    final block = data.blocks
        .where((block) => block.type == ProductionGuideBlockType.step)
        .firstOrNull;
    if (block != null) {
      await _service.updateBlockText(block.id, storedText);
      return _GuideDocument(blockId: block.id, storedText: storedText);
    }

    final created = await _service.addTextBlock(
      itemId: data.guide.itemId,
      guideId: data.guide.id,
      type: ProductionGuideBlockType.step,
      text: storedText,
    );
    return _GuideDocument(blockId: created.id, storedText: storedText);
  }

  void _initController(_GuideDocument guideDocument) {
    if (_controller != null) return;
    _docBlockId = guideDocument.blockId;
    _controller = quill.QuillController(
      document: _QuillTextCodec.documentFromStored(guideDocument.storedText),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _changesSubscription = _controller!.document.changes.listen(
      (_) => _scheduleSave(),
    );
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _saveNow);
  }

  Future<void> _saveNow() async {
    final controller = _controller;
    final blockId = _docBlockId;
    if (controller == null || blockId == null) return;
    _saveTimer?.cancel();
    await _service.updateBlockText(
      blockId,
      _QuillTextCodec.encode(controller.document),
    );
  }

  Future<void> _renameGuide() async {
    final current = _guideTitle ?? '제작 가이드';
    final title = await _showTitleDialog(
      context: context,
      title: '가이드 이름',
      initial: current,
    );
    if (title == null) return;
    await _service.updateGuideTitle(widget.guideId, title);
    if (!mounted) return;
    setState(() => _guideTitle = title.trim().isEmpty ? current : title.trim());
  }

  void _insertStep() {
    final controller = _controller;
    if (controller == null) return;
    final stepNumber = _nextStepNumber(controller.document.toPlainText());
    _insertText('\n$stepNumber. ');
  }

  int _nextStepNumber(String text) {
    final matches = RegExp(r'^\s*(\d+)\.\s+', multiLine: true).allMatches(text);
    var max = 0;
    for (final match in matches) {
      final value = int.tryParse(match.group(1) ?? '') ?? 0;
      if (value > max) max = value;
    }
    return max + 1;
  }

  void _insertText(String text) {
    final controller = _controller;
    if (controller == null) return;
    final selection = controller.selection;
    final index = selection.baseOffset < 0
        ? controller.document.length - 1
        : selection.baseOffset;
    final length = selection.isCollapsed ? 0 : selection.end - selection.start;
    controller.replaceText(
      index,
      length,
      text,
      TextSelection.collapsed(offset: index + text.length),
    );
  }

  Future<void> _addImage() async {
    final controller = _controller;
    final itemId = _itemId;
    if (controller == null || itemId == null) return;

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
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
      );
      if (image == null) return;

      const paths = AppPathService();
      final stored = await const AttachmentFileService().copyOptimizedImage(
        sourcePath: image.path,
        originalFileName: image.name,
        destinationDirectory: await paths.productionGuideDirectory(itemId),
        maxLongSide: 2400,
        jpgQuality: 85,
      );
      final storedName = p.basename(stored.filePath);
      final relativePath =
          paths.productionGuideRelativePath(itemId, storedName);
      _insertImage(relativePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 저장에 실패했습니다: $e')),
      );
    }
  }

  void _insertImage(String relativePath) {
    final controller = _controller;
    if (controller == null) return;
    final selection = controller.selection;
    final index = selection.baseOffset < 0
        ? controller.document.length - 1
        : selection.baseOffset;
    final length = selection.isCollapsed ? 0 : selection.end - selection.start;
    controller.replaceText(
      index,
      length,
      quill.BlockEmbed.image(relativePath),
      TextSelection.collapsed(offset: index + 1),
    );
    controller.replaceText(
      index + 1,
      0,
      '\n',
      TextSelection.collapsed(offset: index + 2),
    );
  }

  Future<void> _openImage(String path) async {
    await _showImageDialog(context: context, path: path);
  }

  Future<void> _rotateImage(String path) async {
    try {
      final file = await const AppPathService().resolveAppFile(path);
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) {
        throw const FormatException('Unsupported image format');
      }
      final rotated = img.copyRotate(decoded, angle: 90);
      await file.writeAsBytes(img.encodeJpg(rotated, quality: 88), flush: true);
      if (!mounted) return;
      setState(() => _imageRefresh += 1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 회전에 실패했습니다: $e')),
      );
    }
  }

  Widget _buildEditor(BuildContext context, _GuideDocument guideDocument) {
    _initController(guideDocument);
    final controller = _controller!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_guideTitle ?? '제작 가이드'),
        actions: [
          IconButton(
            tooltip: '이름 변경',
            icon: const Icon(Icons.drive_file_rename_outline),
            onPressed: _renameGuide,
          ),
          IconButton(
            tooltip: '저장',
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveNow,
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: colorScheme.surface,
            elevation: 1,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.format_list_numbered),
                        label: const Text('단계'),
                        onPressed: _insertStep,
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('사진'),
                        onPressed: _addImage,
                      ),
                    ],
                  ),
                ),
                quill.QuillSimpleToolbar(
                  controller: controller,
                  config: const quill.QuillSimpleToolbarConfig(
                    showAlignmentButtons: true,
                    showBackgroundColorButton: true,
                    showColorButton: true,
                    showFontFamily: true,
                    showFontSize: true,
                    showHeaderStyle: true,
                    showInlineCode: false,
                    showCodeBlock: false,
                    showQuote: false,
                    showSearchButton: false,
                    multiRowsDisplay: false,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: quill.QuillEditor.basic(
                  controller: controller,
                  config: quill.QuillEditorConfig(
                    placeholder: '제작 가이드를 블로그처럼 작성하세요.',
                    expands: true,
                    padding: const EdgeInsets.all(16),
                    embedBuilders: [
                      _GuideImageEmbedBuilder(
                        refresh: _imageRefresh,
                        editable: true,
                        onOpen: _openImage,
                        onRotate: _rotateImage,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GuideDocument>(
      future: _documentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('제작 가이드')),
            body: Center(child: Text('제작 가이드를 불러오지 못했습니다: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('제작 가이드')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return _buildEditor(context, snapshot.data!);
      },
    );
  }
}

class _GuideDocumentViewer extends StatefulWidget {
  final ProductionGuideData data;

  const _GuideDocumentViewer({required this.data});

  @override
  State<_GuideDocumentViewer> createState() => _GuideDocumentViewerState();
}

class _GuideDocumentViewerState extends State<_GuideDocumentViewer> {
  late quill.QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
  }

  @override
  void didUpdateWidget(covariant _GuideDocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.guide.updatedAt != widget.data.guide.updatedAt ||
        oldWidget.data.blocks.length != widget.data.blocks.length) {
      _controller.dispose();
      _controller = _buildController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  quill.QuillController _buildController() {
    final document = _GuideDocumentCodec.documentFromData(widget.data);
    return quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plainText = _controller.document.toPlainText().trim();
    if (plainText.isEmpty) {
      return const Center(child: Text('아직 작성된 내용이 없습니다.'));
    }
    return quill.QuillEditor.basic(
      controller: _controller,
      config: quill.QuillEditorConfig(
        padding: const EdgeInsets.all(18),
        embedBuilders: [
          _GuideImageEmbedBuilder(
            refresh: 0,
            editable: false,
            onOpen: (path) => _showImageDialog(context: context, path: path),
          ),
        ],
      ),
    );
  }
}

class _GuideDocument {
  final String blockId;
  final String storedText;

  const _GuideDocument({
    required this.blockId,
    required this.storedText,
  });
}

class _GuideDocumentCodec {
  static ProductionGuideBlock? findDocumentBlock(
    List<ProductionGuideBlock> blocks,
  ) {
    for (final block in blocks) {
      if (block.type == ProductionGuideBlockType.step &&
          (block.text?.startsWith(_QuillTextCodec.marker) ?? false)) {
        return block;
      }
    }
    return null;
  }

  static quill.Document documentFromData(ProductionGuideData data) {
    final docBlock = findDocumentBlock(data.blocks);
    if (docBlock != null) {
      return _QuillTextCodec.documentFromStored(docBlock.text);
    }
    return legacyDocument(data.blocks);
  }

  static String plainTextFromData(ProductionGuideData data) {
    return documentFromData(data).toPlainText();
  }

  static quill.Document legacyDocument(List<ProductionGuideBlock> blocks) {
    final ops = <Map<String, dynamic>>[];
    var stepNumber = 0;
    var hasContent = false;

    for (final block in blocks) {
      switch (block.type) {
        case ProductionGuideBlockType.step:
          stepNumber += 1;
          final text = _QuillTextCodec.plainTextFromStored(block.text).trim();
          ops.add({
            'insert': '$stepNumber. ${text.isEmpty ? '새 단계' : text}\n',
            'attributes': {'bold': true, 'size': 'large'},
          });
          hasContent = true;
        case ProductionGuideBlockType.note:
          final text = (block.text ?? '').trim();
          if (text.isNotEmpty) {
            ops.add({'insert': '$text\n'});
            hasContent = true;
          }
        case ProductionGuideBlockType.image:
          final path = block.filePath;
          if (path != null && path.trim().isNotEmpty) {
            ops.add({
              'insert': {'image': path},
            });
            ops.add({'insert': '\n'});
            final caption = (block.text ?? '').trim();
            if (caption.isNotEmpty) ops.add({'insert': '$caption\n'});
            hasContent = true;
          }
      }
      ops.add({'insert': '\n'});
    }

    if (!hasContent) {
      ops.add({'insert': '\n'});
    }
    return quill.Document.fromJson(ops);
  }
}

class _GuideImageEmbedBuilder extends quill.EmbedBuilder {
  final int refresh;
  final bool editable;
  final ValueChanged<String> onOpen;
  final ValueChanged<String>? onRotate;

  const _GuideImageEmbedBuilder({
    required this.refresh,
    required this.editable,
    required this.onOpen,
    this.onRotate,
  });

  @override
  String get key => quill.BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final path = embedContext.node.value.data as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: FutureBuilder<File>(
        future: const AppPathService().resolveAppFile(path),
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) {
            return const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Stack(
                    children: [
                      InkWell(
                        onTap: () => onOpen(path),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 260,
                            maxHeight: 560,
                          ),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: Image.file(
                              file,
                              key: ValueKey('$path-$refresh'),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                height: 260,
                                child: Center(child: Text('사진을 불러오지 못했습니다.')),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.46),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '확대',
                                color: Colors.white,
                                icon: const Icon(Icons.open_in_full),
                                onPressed: () => onOpen(path),
                              ),
                              if (editable && onRotate != null)
                                IconButton(
                                  tooltip: '90도 회전',
                                  color: Colors.white,
                                  icon: const Icon(Icons.rotate_90_degrees_cw),
                                  onPressed: () => onRotate!(path),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
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

  static String plainTextFromStored(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith(marker) || raw.startsWith(legacyMarker)) {
      return documentFromStored(raw).toPlainText();
    }
    return raw;
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

Future<String?> _showTitleDialog({
  required BuildContext context,
  required String title,
  required String initial,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '가이드 이름'),
        onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<void> _showImageDialog({
  required BuildContext context,
  required String path,
}) async {
  final file = await const AppPathService().resolveAppFile(path);
  if (!await file.exists()) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('사진 파일을 찾을 수 없습니다.')),
    );
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Text(p.basename(path)),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
