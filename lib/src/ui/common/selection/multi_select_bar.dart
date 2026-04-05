import 'package:flutter/material.dart';

class MultiSelectAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const MultiSelectAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });
}

class CommonMultiSelectBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;

  final VoidCallback? onSelectAll;
  final VoidCallback? onClear;

  final List<MultiSelectAction> actions;

  const CommonMultiSelectBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    this.onSelectAll,
    this.onClear,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE6E0F8),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text('선택됨 $selectedCount / $totalCount'),
              ),

              ///전체선택

              if (onSelectAll != null)
                IconButton(
                  icon: Icon(
                    selectedCount == totalCount
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: selectedCount == totalCount
                      ? '전체 해제'
                      : '전체 선택',
                  onPressed: onSelectAll,
                ),
              // 나머지 액션
              ...actions.map(
                    (a) => Tooltip(
                  message: a.tooltip,
                  child: IconButton(
                    onPressed: selectedCount == 0 ? null : a.onPressed,
                    icon: Icon(a.icon),
                    color: a.color,
                    iconSize: 20,
                    padding: const EdgeInsets.all(6),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}