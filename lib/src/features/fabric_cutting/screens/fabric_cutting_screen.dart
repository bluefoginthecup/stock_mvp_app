import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/fabric_cutting_project.dart';
import '../models/fabric_piece.dart';
import '../services/fabric_cutting_calculator.dart';
import '../services/fabric_cutting_storage_service.dart';
import '../services/fabric_image_service.dart';
import '../widgets/fabric_cutting_table.dart';
import '../widgets/fabric_layout_preview.dart';
import '../widgets/fabric_piece_editor.dart';
import '../widgets/fabric_result_summary.dart';
import 'fabric_cutting_project_list_screen.dart';

class FabricCuttingScreen extends StatefulWidget {
  final bool showAppBar;

  const FabricCuttingScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<FabricCuttingScreen> createState() => _FabricCuttingScreenState();
}

class _FabricCuttingScreenState extends State<FabricCuttingScreen> {
  final _calculator = const FabricCuttingCalculator();
  final _storage = const FabricCuttingStorageService();
  final _imageService = FabricImageService();
  final _productNameC = TextEditingController();
  final _memoC = TextEditingController();
  final _quantityC = TextEditingController(text: '20');
  final _fabricWidthC = TextEditingController(text: '140');

  late FabricCuttingProject _project;

  @override
  void initState() {
    super.initState();
    _project = _newProject();
    _syncControllersFromProject();
  }

  @override
  void dispose() {
    _productNameC.dispose();
    _memoC.dispose();
    _quantityC.dispose();
    _fabricWidthC.dispose();
    super.dispose();
  }

  FabricCuttingProject _newProject() {
    final now = DateTime.now();
    return FabricCuttingProject(
      id: now.microsecondsSinceEpoch.toString(),
      productName: '',
      imagePath: null,
      memo: '',
      quantity: 20,
      fabricWidthCm: 140,
      pieces: [
        FabricPiece(
          id: '${now.microsecondsSinceEpoch}_1',
          name: '네이비',
          widthCm: 13,
          lengthCm: 55,
          seamAllowanceCm: 1.5,
          colorValue: const Color(0xFF1F3F73).value,
        ),
        FabricPiece(
          id: '${now.microsecondsSinceEpoch}_2',
          name: '화이트',
          widthCm: 35,
          lengthCm: 55,
          seamAllowanceCm: 3,
          colorValue: const Color(0xFFF7F4EA).value,
        ),
        FabricPiece(
          id: '${now.microsecondsSinceEpoch}_3',
          name: '네이비',
          widthCm: 13,
          lengthCm: 55,
          seamAllowanceCm: 1.5,
          colorValue: const Color(0xFF1F3F73).value,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }

  void _syncControllersFromProject() {
    _productNameC.text = _project.productName;
    _memoC.text = _project.memo;
    _quantityC.text = _project.quantity.toString();
    _fabricWidthC.text = _fmt(_project.fabricWidthCm);
  }

  void _syncProjectFromInputs() {
    final quantity = int.tryParse(_quantityC.text) ?? _project.quantity;
    final fabricWidth =
        double.tryParse(_fabricWidthC.text.replaceAll(',', '.')) ??
            _project.fabricWidthCm;
    _project = _project.copyWith(
      productName: _productNameC.text,
      memo: _memoC.text,
      quantity: quantity < 1 ? 1 : quantity,
      fabricWidthCm: fabricWidth < 1 ? 1 : fabricWidth,
    );
  }

  void _onInputChanged() {
    setState(_syncProjectFromInputs);
  }

  Future<void> _pickImage(ImageSource source) async {
    final path = await _imageService.pickAndCopyImage(
      source: source,
      projectId: _project.id,
    );
    if (path == null) return;
    setState(() {
      _project = _project.copyWith(imagePath: path);
    });
  }

  void _showImageSheet() {
    final imagePath = _project.imagePath;
    final hasImage = imagePath != null && File(imagePath).existsSync();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (hasImage)
                ListTile(
                  leading: const Icon(Icons.zoom_out_map),
                  title: const Text('원본 이미지 보기'),
                  onTap: () {
                    Navigator.pop(context);
                    _showOriginalImage(imagePath);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('사진 보관함에서 선택'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('카메라로 촬영'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('이미지 제거'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() =>
                        _project = _project.copyWith(clearImagePath: true));
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showOriginalImage(String imagePath) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 5,
                    child: Image(
                      image: FileImage(File(imagePath)),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    tooltip: '닫기',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addPiece() {
    final now = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _project = _project.copyWith(
        pieces: [
          ..._project.pieces,
          FabricPiece(
            id: now.toString(),
            name: '${_project.pieces.length + 1}번 원단',
            widthCm: 10,
            lengthCm: 55,
            seamAllowanceCm: 1.5,
            colorValue: const Color(0xFFDDDDDD).value,
          ),
        ],
      );
    });
  }

  void _updatePiece(int index, FabricPiece piece) {
    final pieces = [..._project.pieces];
    pieces[index] = piece;
    setState(() => _project = _project.copyWith(pieces: pieces));
  }

  void _removePiece(int index) {
    if (_project.pieces.length <= 1) return;
    final pieces = [..._project.pieces]..removeAt(index);
    setState(() => _project = _project.copyWith(pieces: pieces));
  }

  Future<void> _save() async {
    _syncProjectFromInputs();
    await _storage.saveProject(_project);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_project.displayName} 저장 완료')),
    );
  }

  Future<void> _load() async {
    final selected = await Navigator.of(context).push<FabricCuttingProject>(
      MaterialPageRoute(builder: (_) => const FabricCuttingProjectListScreen()),
    );
    if (selected == null) return;
    setState(() {
      _project = selected;
      _syncControllersFromProject();
    });
  }

  void _reset() {
    setState(() {
      _project = _newProject();
      _syncControllersFromProject();
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncProjectFromInputs();
    final result = _calculator.calculate(_project);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('배색 원단 재단 계산기'),
              actions: [
                IconButton(
                  tooltip: '새 계산',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _reset,
                ),
                IconButton(
                  tooltip: '불러오기',
                  icon: const Icon(Icons.folder_open_outlined),
                  onPressed: _load,
                ),
                IconButton(
                  tooltip: '저장',
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _save,
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            if (!widget.showAppBar) ...[
              _ProjectActions(
                onNew: _reset,
                onLoad: _load,
                onSave: _save,
              ),
              const SizedBox(height: 12),
            ],
            _ProductCard(
              productNameC: _productNameC,
              memoC: _memoC,
              imagePath: _project.imagePath,
              onChanged: _onInputChanged,
              onPickImage: _showImageSheet,
            ),
            const SizedBox(height: 12),
            _BasicInputs(
              quantityC: _quantityC,
              fabricWidthC: _fabricWidthC,
              onChanged: _onInputChanged,
            ),
            const SizedBox(height: 12),
            FabricResultSummary(result: result),
            const SizedBox(height: 12),
            Text('원단', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < _project.pieces.length; i++)
              FabricPieceEditor(
                key: ValueKey(_project.pieces[i].id),
                index: i,
                piece: _project.pieces[i],
                onChanged: (piece) => _updatePiece(i, piece),
                onDelete:
                    _project.pieces.length <= 1 ? null : () => _removePiece(i),
              ),
            FilledButton.icon(
              onPressed: _addPiece,
              icon: const Icon(Icons.add),
              label: const Text('원단 추가'),
            ),
            const SizedBox(height: 12),
            FabricLayoutPreview(result: result),
            const SizedBox(height: 12),
            FabricCuttingTable(result: result),
          ],
        ),
      ),
    );
  }
}

class _ProjectActions extends StatelessWidget {
  final VoidCallback onNew;
  final VoidCallback onLoad;
  final VoidCallback onSave;

  const _ProjectActions({
    required this.onNew,
    required this.onLoad,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('새 계산'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('불러오기'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final TextEditingController productNameC;
  final TextEditingController memoC;
  final String? imagePath;
  final VoidCallback onChanged;
  final VoidCallback onPickImage;

  const _ProductCard({
    required this.productNameC,
    required this.memoC,
    required this.imagePath,
    required this.onChanged,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && File(imagePath!).existsSync();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: productNameC,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '제품명',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onPickImage,
              child: Container(
                height: 164,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.file(
                          File(imagePath!),
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 36),
                          SizedBox(height: 8),
                          Text('제품 이미지 첨부'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: memoC,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '메모',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BasicInputs extends StatelessWidget {
  final TextEditingController quantityC;
  final TextEditingController fabricWidthC;
  final VoidCallback onChanged;

  const _BasicInputs({
    required this.quantityC,
    required this.fabricWidthC,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: quantityC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '제작 개수',
                  suffixText: '개',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: fabricWidthC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '원단폭',
                  suffixText: 'cm',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(double n) => n.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
