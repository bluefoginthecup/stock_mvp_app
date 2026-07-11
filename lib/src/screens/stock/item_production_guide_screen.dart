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
  late final Future<_GuideDocument> _documentFuture;
  quill.QuillController? _controller;
  Timer? _saveTimer;
  StreamSubscription<dynamic>? _changesSubscription;
  String? _docBlockId;
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
    final data = await _service.getOrCreateGuide(widget.itemId);
    final blocks = data.blocks;
    final docBlock = _findDocumentBlock(blocks);
    if (docBlock != null) {
      return _GuideDocument(
        blockId: docBlock.id,
        storedText: _QuillTextCodec.normalize(docBlock.text),
      );
    }

    final storedText = _QuillTextCodec.encode(_legacyDocument(blocks));
    final block = blocks
        .where((block) => block.type == ProductionGuideBlockType.step)
        .firstOrNull;
    if (block != null) {
      await _service.updateBlockText(block.id, storedText);
      return _GuideDocument(blockId: block.id, storedText: storedText);
    }

    final created = await _service.addTextBlock(
      itemId: widget.itemId,
      type: ProductionGuideBlockType.step,
      text: storedText,
    );
    return _GuideDocument(blockId: created.id, storedText: storedText);
  }

  ProductionGuideBlock? _findDocumentBlock(List<ProductionGuideBlock> blocks) {
    for (final block in blocks) {
      if (block.type == ProductionGuideBlockType.step &&
          (block.text?.startsWith(_QuillTextCodec.marker) ?? false)) {
        return block;
      }
    }
    return null;
  }

  quill.Document _legacyDocument(List<ProductionGuideBlock> blocks) {
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
      ops.add({'insert': '1. \n'});
    }
    return quill.Document.fromJson(ops);
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
    if (controller == null) return;

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
        destinationDirectory:
            await paths.productionGuideDirectory(widget.itemId),
        maxLongSide: 2400,
        jpgQuality: 85,
      );
      final storedName = p.basename(stored.filePath);
      final relativePath = paths.productionGuideRelativePath(
        widget.itemId,
        storedName,
      );
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
        title: Text('${widget.itemName} 제작 가이드'),
        actions: [
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
                    placeholder: '제육볶음 제작 가이드를 블로그처럼 작성하세요.',
                    expands: true,
                    padding: const EdgeInsets.all(16),
                    embedBuilders: [
                      _GuideImageEmbedBuilder(
                        refresh: _imageRefresh,
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
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text('${widget.itemName} 제작 가이드')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return _buildEditor(context, snapshot.data!);
      },
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

class _GuideImageEmbedBuilder extends quill.EmbedBuilder {
  final int refresh;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onRotate;

  const _GuideImageEmbedBuilder({
    required this.refresh,
    required this.onOpen,
    required this.onRotate,
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
                              IconButton(
                                tooltip: '90도 회전',
                                color: Colors.white,
                                icon: const Icon(Icons.rotate_90_degrees_cw),
                                onPressed: () => onRotate(path),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
