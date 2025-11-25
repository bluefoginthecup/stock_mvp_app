import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraggableFab extends StatefulWidget {
  final Widget child;
  final String storageKey;
  final EdgeInsets margin;

  const DraggableFab({
    super.key,
    required this.child,
    required this.storageKey,
    this.margin = const EdgeInsets.all(16),
  });

  @override
  State<DraggableFab> createState() => _DraggableFabState();
}

class _DraggableFabState extends State<DraggableFab> {
  Offset? _offset;
  Size? _childSize;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final dx = p.getDouble('${widget.storageKey}_dx');
    final dy = p.getDouble('${widget.storageKey}_dy');
    if (dx != null && dy != null) setState(() => _offset = Offset(dx, dy));
  }

  Future<void> _save(Offset o) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('${widget.storageKey}_dx', o.dx);
    await p.setDouble('${widget.storageKey}_dy', o.dy);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final padding = media.padding;

    return LayoutBuilder(builder: (ctx, c) {
      final maxW = c.maxWidth, maxH = c.maxHeight;

      final defaultOffset = _offset ??
          Offset(
            maxW - (72 + widget.margin.right),
            maxH - (72 + widget.margin.bottom + padding.bottom),
          );

      Offset clamp(Offset raw) {
        final cw = _childSize?.width ?? 56;
        final ch = _childSize?.height ?? 56;
        final minX = widget.margin.left + padding.left;
        final minY = widget.margin.top + padding.top;
        final maxX = maxW - cw - widget.margin.right - padding.right;
        final maxY = maxH - ch - widget.margin.bottom - padding.bottom;
        return Offset(
          raw.dx.clamp(minX, math.max(minX, maxX)),
          raw.dy.clamp(minY, math.max(minY, maxY)),
        );
      }

      final pos = clamp(defaultOffset);

      return Stack(children: [
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() => _offset = clamp(pos + d.delta)),
            onPanEnd: (_) {
              if (_offset != null) _save(_offset!);
            },
            child: _SizeWatcher(
              onSize: (s) => _childSize = s,
              child: widget.child,
            ),
          ),
        ),
      ]);
    });
  }
}

class _SizeWatcher extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onSize;
  const _SizeWatcher({required this.child, required this.onSize});

  @override
  State<_SizeWatcher> createState() => _SizeWatcherState();
}

class _SizeWatcherState extends State<_SizeWatcher> {
  final key = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) widget.onSize(box.size);
  }

  @override
  Widget build(BuildContext context) {
    return Container(key: key, child: widget.child);
  }
}
