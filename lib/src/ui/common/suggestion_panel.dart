import 'package:flutter/material.dart';
import 'scroll_capped_list.dart';

/// 검색 제안/빠른결과 패널을 바로 만들 수 있는 래퍼
class SuggestionPanel<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final double rowHeight;
  final int maxRows;
  final EdgeInsetsGeometry? padding;
  final bool separated;
  final Widget? separator;
  final double elevation;
  final BorderRadiusGeometry borderRadius;
  final Clip clipBehavior;

  const SuggestionPanel({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.rowHeight = 56,
    this.maxRows = 5,
    this.padding,
    this.separated = true,
    this.separator = const Divider(height: 1),
    this.elevation = 8,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Material(
      elevation: elevation,
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: ScrollCappedList<T>(
        items: items,
        itemBuilder: itemBuilder,
        rowHeight: rowHeight,
        maxRows: maxRows,
        padding: padding,
        separated: separated,
        separator: separator,
      ),
    );
  }
}
