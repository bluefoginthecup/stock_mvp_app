import 'package:flutter/material.dart';

/// 최대 행 수까지만 보이고, 그 이상은 스크롤로 보여주는 재사용 리스트
class ScrollCappedList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final double rowHeight; // 한 행의 대략적 높이
  final int maxRows;      // 최대 표시 행 수
  final EdgeInsetsGeometry? padding;
  final bool separated;
  final Widget? separator; // separated=true일 때 각 행 사이에 들어갈 위젯(예: Divider)
  final ScrollPhysics physics;

  const ScrollCappedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.rowHeight = 56,
    this.maxRows = 5,
    this.padding,
    this.separated = true,
    this.separator = const Divider(height: 1),
    this.physics = const ClampingScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final maxHeight = rowHeight * maxRows;

    final listView = separated
        ? ListView.separated(
      itemCount: items.length,
      shrinkWrap: true,
      padding: padding,
      physics: physics,
      separatorBuilder: (_, __) => separator ?? const SizedBox.shrink(),
      itemBuilder: (ctx, i) => itemBuilder(ctx, items[i]),
    )
        : ListView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      padding: padding,
      physics: physics,
      itemBuilder: (ctx, i) => itemBuilder(ctx, items[i]),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: listView,
    );
  }
}
