import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/roll_cut_item.dart';
import '../models/roll_fabric_optimization_result.dart';
import '../models/roll_fabric_plan.dart';
import '../services/roll_fabric_optimizer.dart';
import '../services/roll_optimizer_storage_service.dart';
import 'roll_optimizer_plan_list_screen.dart';

class RollFabricOptimizerScreen extends StatefulWidget {
  const RollFabricOptimizerScreen({super.key});

  @override
  State<RollFabricOptimizerScreen> createState() =>
      _RollFabricOptimizerScreenState();
}

class _RollFabricOptimizerScreenState extends State<RollFabricOptimizerScreen> {
  final _optimizer = const RollFabricOptimizer();
  final _storage = const RollOptimizerStorageService();
  final _nameC = TextEditingController();

  late RollOptimizerPlanSet _planSet;

  @override
  void initState() {
    super.initState();
    _planSet = _newPlanSet();
    _nameC.text = _planSet.name;
  }

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  RollOptimizerPlanSet _newPlanSet() {
    final now = DateTime.now();
    return RollOptimizerPlanSet(
      id: now.microsecondsSinceEpoch.toString(),
      name: '',
      rolls: [
        RollFabricPlan(
          id: '${now.microsecondsSinceEpoch}_roll',
          name: '1번 원단',
          colorName: '네이비',
          colorValue: const Color(0xFF1F3F73).toARGB32(),
          widthCm: 140,
          totalLength: 10,
          unit: RollLengthUnit.yard,
          cuts: [
            RollCutItem(
              id: '${now.microsecondsSinceEpoch}_cut_1',
              label: '13×90',
              widthCm: 13,
              lengthCm: 90,
              quantity: 24,
            ),
            RollCutItem(
              id: '${now.microsecondsSinceEpoch}_cut_2',
              label: '13×55',
              widthCm: 13,
              lengthCm: 55,
              quantity: 24,
            ),
          ],
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }

  void _syncName() {
    _planSet = _planSet.copyWith(name: _nameC.text);
  }

  void _updateRoll(int index, RollFabricPlan roll) {
    final rolls = [..._planSet.rolls];
    rolls[index] = roll;
    setState(() => _planSet = _planSet.copyWith(rolls: rolls));
  }

  void _addRoll() {
    final now = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _planSet = _planSet.copyWith(
        rolls: [
          ..._planSet.rolls,
          RollFabricPlan(
            id: '${now}_roll',
            name: '${_planSet.rolls.length + 1}번 원단',
            colorName: '색상',
            colorValue: const Color(0xFFDDDDDD).toARGB32(),
            widthCm: 140,
            totalLength: 10,
            unit: RollLengthUnit.yard,
            cuts: [
              RollCutItem(
                id: '${now}_cut',
                label: '재단항목',
                widthCm: 10,
                lengthCm: 10,
                quantity: 1,
              ),
            ],
          ),
        ],
      );
    });
  }

  void _removeRoll(int index) {
    if (_planSet.rolls.length <= 1) return;
    final rolls = [..._planSet.rolls]..removeAt(index);
    setState(() => _planSet = _planSet.copyWith(rolls: rolls));
  }

  Future<void> _save() async {
    _syncName();
    await _storage.savePlan(_planSet);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_planSet.displayName} 저장 완료')),
    );
  }

  Future<void> _load() async {
    final selected = await Navigator.of(context).push<RollOptimizerPlanSet>(
      MaterialPageRoute(builder: (_) => const RollOptimizerPlanListScreen()),
    );
    if (selected == null) return;
    setState(() {
      _planSet = selected;
      _nameC.text = selected.name;
    });
  }

  void _reset() {
    setState(() {
      _planSet = _newPlanSet();
      _nameC.text = _planSet.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncName();
    final results = _optimizer.optimizeAll(_planSet.rolls);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            _HeaderCard(
              nameC: _nameC,
              onChanged: () => setState(_syncName),
              onNew: _reset,
              onLoad: _load,
              onSave: _save,
            ),
            const SizedBox(height: 12),
            Text('보유 롤 원단', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < _planSet.rolls.length; i++)
              _RollEditorCard(
                key: ValueKey(_planSet.rolls[i].id),
                index: i,
                roll: _planSet.rolls[i],
                canDelete: _planSet.rolls.length > 1,
                onChanged: (roll) => _updateRoll(i, roll),
                onDelete: () => _removeRoll(i),
              ),
            FilledButton.icon(
              onPressed: _addRoll,
              icon: const Icon(Icons.add),
              label: const Text('보유 롤 원단 추가'),
            ),
            const SizedBox(height: 14),
            Text('재단 결과', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < results.length; i++)
              _RollResultCard(index: i, result: results[i]),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final TextEditingController nameC;
  final VoidCallback onChanged;
  final VoidCallback onNew;
  final VoidCallback onLoad;
  final VoidCallback onSave;

  const _HeaderCard({
    required this.nameC,
    required this.onChanged,
    required this.onNew,
    required this.onLoad,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(
                labelText: '최적화 이름',
                hintText: '예: 네이비 방석 커버 원단 최적화',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNew,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('새로'),
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
          ],
        ),
      ),
    );
  }
}

class _RollEditorCard extends StatelessWidget {
  final int index;
  final RollFabricPlan roll;
  final bool canDelete;
  final ValueChanged<RollFabricPlan> onChanged;
  final VoidCallback onDelete;

  const _RollEditorCard({
    super.key,
    required this.index,
    required this.roll,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 15, child: Text('${index + 1}')),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${index + 1}번 보유 롤',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: '롤 원단 삭제',
                  onPressed: canDelete ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: roll.name,
              decoration: const InputDecoration(
                labelText: '원단명',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onChanged(roll.copyWith(name: value)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: roll.colorName,
                    decoration: const InputDecoration(
                      labelText: '색상명',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        onChanged(roll.copyWith(colorName: value)),
                  ),
                ),
                const SizedBox(width: 10),
                _ColorButton(
                  color: roll.color,
                  onTap: () => _showColorSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DoubleField(
                    label: '원단폭',
                    suffix: 'cm',
                    value: roll.widthCm,
                    onChanged: (value) =>
                        onChanged(roll.copyWith(widthCm: value)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DoubleField(
                    label: '보유 길이',
                    suffix: roll.unit.label,
                    value: roll.totalLength,
                    onChanged: (value) =>
                        onChanged(roll.copyWith(totalLength: value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<RollLengthUnit>(
              value: roll.unit,
              decoration: const InputDecoration(
                labelText: '보유 길이 단위',
                border: OutlineInputBorder(),
              ),
              items: RollLengthUnit.values
                  .map(
                    (unit) => DropdownMenuItem(
                      value: unit,
                      child: Text(unit.label),
                    ),
                  )
                  .toList(),
              onChanged: (unit) {
                if (unit != null) onChanged(roll.copyWith(unit: unit));
              },
            ),
            const Divider(height: 28),
            Text('재단 항목', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < roll.cuts.length; i++)
              _CutItemEditor(
                key: ValueKey(roll.cuts[i].id),
                index: i,
                cut: roll.cuts[i],
                canDelete: roll.cuts.length > 1,
                onChanged: (cut) => _updateCut(i, cut),
                onDelete: () => _removeCut(i),
              ),
            OutlinedButton.icon(
              onPressed: _addCut,
              icon: const Icon(Icons.add),
              label: const Text('재단 항목 추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _addCut() {
    final now = DateTime.now().microsecondsSinceEpoch;
    onChanged(
      roll.copyWith(
        cuts: [
          ...roll.cuts,
          RollCutItem(
            id: '${now}_cut',
            label: '재단항목',
            widthCm: 10,
            lengthCm: 10,
            quantity: 1,
          ),
        ],
      ),
    );
  }

  void _updateCut(int index, RollCutItem cut) {
    final cuts = [...roll.cuts];
    cuts[index] = cut;
    onChanged(roll.copyWith(cuts: cuts));
  }

  void _removeCut(int index) {
    if (roll.cuts.length <= 1) return;
    final cuts = [...roll.cuts]..removeAt(index);
    onChanged(roll.copyWith(cuts: cuts));
  }

  void _showColorSheet(BuildContext context) {
    const colors = [
      Color(0xFF1F3F73),
      Color(0xFFF7F4EA),
      Color(0xFF2E7D32),
      Color(0xFFC62828),
      Color(0xFF6A4C93),
      Color(0xFFE6A23C),
      Color(0xFF222222),
      Color(0xFFDDDDDD),
      Color(0xFF7FB3D5),
      Color(0xFFF4A6A6),
      Color(0xFF8D6E63),
      Color(0xFF26A69A),
    ];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in colors)
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.pop(context);
                      onChanged(roll.copyWith(colorValue: color.toARGB32()));
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.toARGB32() == roll.colorValue
                              ? Theme.of(context).colorScheme.primary
                              : Colors.black26,
                          width: color.toARGB32() == roll.colorValue ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CutItemEditor extends StatelessWidget {
  final int index;
  final RollCutItem cut;
  final bool canDelete;
  final ValueChanged<RollCutItem> onChanged;
  final VoidCallback onDelete;

  const _CutItemEditor({
    super.key,
    required this.index,
    required this.cut,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: cut.label,
                  decoration: InputDecoration(
                    labelText: '${index + 1}번 재단명',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => onChanged(cut.copyWith(label: value)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '재단 항목 삭제',
                onPressed: canDelete ? onDelete : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DoubleField(
                  label: '폭',
                  suffix: 'cm',
                  value: cut.widthCm,
                  onChanged: (value) => onChanged(cut.copyWith(widthCm: value)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DoubleField(
                  label: '길이',
                  suffix: 'cm',
                  value: cut.lengthCm,
                  onChanged: (value) =>
                      onChanged(cut.copyWith(lengthCm: value)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IntField(
                  label: '수량',
                  value: cut.quantity,
                  onChanged: (value) =>
                      onChanged(cut.copyWith(quantity: value)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RollResultCard extends StatelessWidget {
  final int index;
  final RollFabricOptimizationResult result;

  const _RollResultCard({
    required this.index,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remainText = result.remainLengthCm >= 0 ? '남음' : '부족';
    final note = switch (result.mode) {
      RollOptimizationMode.sameWidthLane =>
        '같은 폭 ${_fmt(result.laneWidthCm)}cm 재단물을 ${result.laneCount}개 레인에 섞어 최소 길이로 배치했습니다.',
      RollOptimizationMode.mixedWidthHeuristic =>
        '폭이 다른 재단물을 같은 길이 구간 안에 혼합 배치했습니다. 각 구간은 원단폭 이하로 조합하고 남는 폭이 적은 위치를 우선 사용합니다.',
      RollOptimizationMode.grouped => '혼합 배치가 단순 묶음보다 이득이 없어 항목별 묶음 배치를 표시합니다.',
      RollOptimizationMode.empty => '재단 항목을 추가하면 결과가 표시됩니다.',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${index + 1}번 ${result.roll.name} / ${result.roll.colorName}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                _StatusPill(possible: result.possible),
              ],
            ),
            const SizedBox(height: 8),
            Text(note, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniStat(
                    label: '보유', value: '${_fmt(result.totalLengthCm)}cm'),
                _MiniStat(
                  label: result.optimized ? '최적 필요' : '필요',
                  value: '${_fmt(result.usedLengthCm)}cm',
                ),
                if (result.groupedLengthCm > result.usedLengthCm + 0.0001)
                  _MiniStat(
                    label: '기존 묶음',
                    value: '${_fmt(result.groupedLengthCm)}cm',
                  ),
                _MiniStat(
                  label: remainText,
                  value: '${_fmt(result.remainLengthCm.abs())}cm',
                  danger: !result.possible,
                ),
                if (result.savedLengthCm > 0.0001)
                  _MiniStat(
                    label: '절약',
                    value: '${_fmt(result.savedLengthCm)}cm',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Legend(result: result),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showFullscreenLayout(context),
                icon: const Icon(Icons.open_in_full, size: 18),
                label: const Text('전체화면 보기'),
              ),
            ),
            const SizedBox(height: 6),
            _RollPreview(
              result: result,
              onOpen: () => _showFullscreenLayout(context),
            ),
            const SizedBox(height: 12),
            _ResultTable(result: result),
          ],
        ),
      ),
    );
  }

  void _showFullscreenLayout(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: const Color(0xFF111111),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _RollFullscreenViewer(result: result),
                ),
                Positioned(
                  top: 8,
                  left: 16,
                  right: 64,
                  child: Text(
                    '${result.roll.name} 배치도',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
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
}

class _RollPreview extends StatelessWidget {
  final RollFabricOptimizationResult result;
  final VoidCallback onOpen;

  const _RollPreview({
    required this.result,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final drawLength = math.max(result.totalLengthCm, result.usedLengthCm);
        final scaleX =
            constraints.maxWidth / drawLength.clamp(1, double.infinity);
        final scaleY = 230 / result.roll.widthCm.clamp(1, double.infinity);
        final scale = math.min(scaleX, scaleY).clamp(0.15, 12.0);
        final width = drawLength * scale;
        final height = result.roll.widthCm * scale;

        return Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onOpen,
            child: SizedBox(
              width: width,
              height: height + 24,
              child: CustomPaint(
                painter: _RollPreviewPainter(result: result, scale: scale),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RollFullscreenViewer extends StatelessWidget {
  final RollFabricOptimizationResult result;

  const _RollFullscreenViewer({required this.result});

  @override
  Widget build(BuildContext context) {
    const detailScale = 4.0;
    final drawLength = math.max(result.totalLengthCm, result.usedLengthCm);
    final width = drawLength * detailScale;
    final height = result.roll.widthCm * detailScale + 24;

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(900),
      minScale: 0.15,
      maxScale: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _RollPreviewPainter(result: result, scale: detailScale),
            ),
          ),
        ),
      ),
    );
  }
}

class _RollPreviewPainter extends CustomPainter {
  final RollFabricOptimizationResult result;
  final double scale;

  const _RollPreviewPainter({
    required this.result,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final roll = result.roll;
    final drawLength = math.max(result.totalLengthCm, result.usedLengthCm);
    final rollWidth = drawLength * scale;
    final rollHeight = roll.widthCm * scale;
    const topOffset = 18.0;
    final border = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final base = Paint()..color = Colors.white;
    final remainPaint = Paint()
      ..color = roll.color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    final outer = Rect.fromLTWH(0, topOffset, rollWidth, rollHeight);
    canvas.drawRect(outer, base);
    canvas.drawRect(outer, border);

    if (result.remainLengthCm > 0.01) {
      final remainRect = Rect.fromLTWH(
        result.usedLengthCm * scale,
        topOffset,
        result.remainLengthCm * scale,
        rollHeight,
      );
      canvas.drawRect(remainRect, remainPaint);
      canvas.drawRect(remainRect, border);
      _drawCenteredText(canvas, remainRect,
          '남은 원단\n${_fmt(result.remainLengthCm)}cm', Colors.black54,
          fontSize: scale >= 3 ? 15 : 11);
    }

    for (final lane in result.lanes) {
      for (final item in lane.items) {
        final color = _shadeColor(roll.color, item.cutIndex * 20);
        final rect = Rect.fromLTWH(
          item.xCm * scale,
          topOffset + item.yCm * scale,
          item.lengthCm * scale,
          item.widthCm * scale,
        );
        canvas.drawRect(rect, Paint()..color = color);
        canvas.drawRect(rect, border);
        if (rect.width > 30 && rect.height > 17) {
          _drawCenteredText(
            canvas,
            rect,
            '${item.cut.label}\n${_fmt(item.lengthCm)}×${_fmt(item.widthCm)}',
            _readableTextColor(color),
            fontSize: scale >= 3 ? 15 : 11,
          );
        }
      }
    }

    if (result.widthRemainCm > 0.01 && result.optimizedByLane) {
      final remainWidthRect = Rect.fromLTWH(
        0,
        topOffset + (result.laneCount * result.laneWidthCm * scale),
        drawLength * scale,
        result.widthRemainCm * scale,
      );
      canvas.drawRect(remainWidthRect, remainPaint);
      canvas.drawRect(remainWidthRect, border);
    }

    _drawAxisText(canvas, Offset.zero, '길이 ${_fmt(drawLength)}cm');
    _drawAxisText(canvas, Offset(math.max(0, rollWidth - 76), rollHeight + 20),
        '폭 ${_fmt(roll.widthCm)}cm');
  }

  void _drawCenteredText(
    Canvas canvas,
    Rect rect,
    String text,
    Color color, {
    required double fontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, height: 1.12),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: rect.width - 4);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  void _drawAxisText(Canvas canvas, Offset offset, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black87,
          fontSize: scale >= 3 ? 18 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RollPreviewPainter oldDelegate) {
    return oldDelegate.result != result || oldDelegate.scale != scale;
  }
}

class _ResultTable extends StatelessWidget {
  final RollFabricOptimizationResult result;

  const _ResultTable({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: result.cutSummaries.map((summary) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  summary.cut.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                result.optimized
                    ? '${summary.placedQuantity}/${summary.cut.quantity}장'
                    : '${summary.piecesPerColumn}장 × ${summary.columnsNeeded}줄',
              ),
              const SizedBox(width: 10),
              Text('${_fmt(summary.requiredLengthCm)}cm'),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Legend extends StatelessWidget {
  final RollFabricOptimizationResult result;

  const _Legend({required this.result});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < result.roll.cuts.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 10,
                  color: _shadeColor(result.roll.color, i * 20),
                ),
                const SizedBox(width: 5),
                Text(
                  '${result.roll.cuts[i].label} ${result.roll.cuts[i].quantity}장',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;

  const _MiniStat({
    required this.label,
    required this.value,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: danger ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool possible;

  const _StatusPill({required this.possible});

  @override
  Widget build(BuildContext context) {
    final color =
        possible ? Colors.green.shade700 : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        possible ? '가능' : '부족',
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DoubleField extends StatelessWidget {
  final String label;
  final String suffix;
  final double value;
  final ValueChanged<double> onChanged;

  const _DoubleField({
    required this.label,
    required this.suffix,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: _fmt(value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (raw) {
        final parsed = double.tryParse(raw.replaceAll(',', '.'));
        if (parsed != null) onChanged(parsed <= 0 ? 0.1 : parsed);
      },
    );
  }
}

class _IntField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _IntField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (raw) {
        final parsed = int.tryParse(raw);
        if (parsed != null) onChanged(parsed < 1 ? 1 : parsed);
      },
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 84,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.palette_outlined, size: 20),
          ],
        ),
      ),
    );
  }
}

Color _shadeColor(Color color, int amount) {
  int shift(int channel) => (channel + amount).clamp(0, 255).toInt();
  return Color.fromARGB(
    color.alpha,
    shift(color.red),
    shift(color.green),
    shift(color.blue),
  );
}

Color _readableTextColor(Color color) {
  final brightness = ThemeData.estimateBrightnessForColor(color);
  return brightness == Brightness.dark ? Colors.white : Colors.black87;
}

String _fmt(double n) => n.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
