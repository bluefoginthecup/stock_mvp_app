// lib/src/widgets/qty_control.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QtyControl extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;
  final int step;
  final double fieldWidth;
  final bool dense;
  final bool allowLongPressRepeat;

  const QtyControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.step = 1,
    this.fieldWidth = 56,
    this.dense = true,
    this.allowLongPressRepeat = true,
  });

  @override
  State<QtyControl> createState() => _QtyControlState();
}

class _QtyControlState extends State<QtyControl> {
  late TextEditingController _c;
  Timer? _repeatTimer;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant QtyControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부에서 value가 바뀌면 필드 동기화
    if (oldWidget.value != widget.value && _c.text != widget.value.toString()) {
      _c.text = widget.value.toString();
      _c.selection = TextSelection.fromPosition(
        TextPosition(offset: _c.text.length),
      );
    }
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  int _clamp(int v) {
    final min = widget.min;
    final max = widget.max;
    if (v < min) return min;
    if (max != null && v > max) return max;
    return v;
  }

  void _apply(int v) {
    final nv = _clamp(v);
    if (nv.toString() != _c.text) {
      _c.text = nv.toString();
      _c.selection = TextSelection.fromPosition(
        TextPosition(offset: _c.text.length),
      );
    }
    if (nv != widget.value) widget.onChanged(nv);
  }

  void _stepBy(int delta) {
    final current = int.tryParse(_c.text) ?? widget.value;
    _apply(current + delta);
  }

  // 길게 누르면 반복
  void _startRepeat(int delta) {
    if (!widget.allowLongPressRepeat) return;
    _repeatTimer?.cancel();
    // 시작 지연 후 빠르게 반복
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _stepBy(delta);
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final btnPadding = widget.dense ? EdgeInsets.zero : const EdgeInsets.all(8);

    final minusBtn = GestureDetector(
      onTap: () => _stepBy(-widget.step),
      onLongPressStart: (_) => _startRepeat(-widget.step),
      onLongPressEnd: (_) => _stopRepeat(),
      child: IconButton(
        padding: btnPadding,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.remove),
        onPressed: () => _stepBy(-widget.step),
        tooltip: 'context.t.qty_decrease',
      ),
    );

    final plusBtn = GestureDetector(
      onTap: () => _stepBy(widget.step),
      onLongPressStart: (_) => _startRepeat(widget.step),
      onLongPressEnd: (_) => _stopRepeat(),
      child: IconButton(
        padding: btnPadding,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.add),
        onPressed: () => _stepBy(widget.step),
        tooltip: 'context.t.qty_increase',
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        minusBtn,
        SizedBox(
          width: widget.fieldWidth,
          child: TextField(
            controller: _c,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              isDense: widget.dense,
              contentPadding: widget.dense
                  ? const EdgeInsets.symmetric(vertical: 6)
                  : const EdgeInsets.symmetric(vertical: 10),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) => _apply(int.tryParse(v) ?? widget.value),
            onTapOutside: (_) => _apply(int.tryParse(_c.text) ?? widget.value),
          ),
        ),
        plusBtn,
      ],
    );
  }
}
