import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/main_tab_controller.dart';
import 'dashboard_quick_actions.dart';

class DashboardQuickPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const DashboardQuickPanel({
    super.key,
    this.onClose,
  });

  @override
  State<DashboardQuickPanel> createState() => _DashboardQuickPanelState();
}

class _DashboardQuickPanelState extends State<DashboardQuickPanel> {
  static const _favoriteIdsKey = 'dashboardQuickPanelFavoriteMenuIds';

  static const _defaultFavorites = <QuickActionType>[
    QuickActionType.stock,
    QuickActionType.purchases,
    QuickActionType.shortage,
    QuickActionType.suppliers,
    QuickActionType.receipts,
    QuickActionType.settings,
  ];

  List<QuickActionType> _favorites = [..._defaultFavorites];
  bool _allMenuExpanded = false;
  final ScrollController _allMenuScrollController = ScrollController();

  static const _menuGroups = <_QuickPanelMenuGroup>[
    _QuickPanelMenuGroup(
      '주요 업무',
      [
        QuickActionType.stock,
        QuickActionType.txns,
        QuickActionType.works,
        QuickActionType.purchases,
        QuickActionType.orders,
        QuickActionType.quotes,
        QuickActionType.schedules,
      ],
    ),
    _QuickPanelMenuGroup(
      '계산/도구',
      [
        QuickActionType.shortage,
        QuickActionType.fabricCutting,
      ],
    ),
    _QuickPanelMenuGroup(
      '관리',
      [
        QuickActionType.suppliers,
        QuickActionType.shippingDestinations,
        QuickActionType.storageLocations,
        QuickActionType.receipts,
        QuickActionType.memo,
      ],
    ),
    _QuickPanelMenuGroup(
      '시스템',
      [
        QuickActionType.settings,
        QuickActionType.trash,
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
    });
  }

  @override
  void dispose() {
    _allMenuScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.containsKey(_favoriteIdsKey)
          ? prefs.getStringList(_favoriteIdsKey)
          : null;
      if (!mounted) return;

      setState(() {
        _favorites =
            ids == null ? [..._defaultFavorites] : _sanitizeFavoriteIds(ids);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _favorites = [..._defaultFavorites]);
    }
  }

  Future<void> _persistFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _favoriteIdsKey,
        _favorites.map(quickActionIdOf).toList(growable: false),
      );
    } catch (_) {
      // 즐겨찾기 저장 실패가 패널 사용을 막지는 않는다.
    }
  }

  List<QuickActionType> _sanitizeFavoriteIds(List<String> ids) {
    final seen = <QuickActionType>{};
    final result = <QuickActionType>[];
    for (final id in ids) {
      final type = quickActionTypeOfOrNull(id);
      if (type == null || !defaultQuickActionOrder.contains(type)) continue;
      if (seen.add(type)) {
        result.add(type);
      }
    }
    return result;
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _favorites.removeAt(oldIndex);
      _favorites.insert(newIndex, item);
    });

    await _persistFavorites();
  }

  Future<void> _toggleFavorite(
    QuickActionType type, {
    required bool checked,
  }) async {
    setState(() {
      if (checked) {
        if (!_favorites.contains(type)) {
          _favorites.add(type);
        }
      } else {
        _favorites.remove(type);
      }
    });

    await _persistFavorites();
  }

  void _openFullDashboard() {
    final tabs = context.read<MainTabController>();
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
    tabs.openShellRoute(Navigator.defaultRouteName);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Material(
        color: scheme.surface,
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '즐겨찾기 패널',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _buildAllMenu(context),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      children: [
                        Text(
                          '즐겨찾기',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const Spacer(),
                        Text(
                          '${_favorites.length}개',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _favorites.isEmpty
                        ? _buildEmptyFavorites(context)
                        : _buildFavoriteList(context),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: '전체 대시보드로 이동',
              child: InkWell(
                onTap: _openFullDashboard,
                child: Container(
                  width: 44,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.36),
                    border: Border(
                      left: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.primary,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllMenu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final availableGroups = _availableMenuGroups();

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _allMenuExpanded = !_allMenuExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '전체 메뉴',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  _allMenuExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: Scrollbar(
              controller: _allMenuScrollController,
              child: ListView(
                controller: _allMenuScrollController,
                primary: false,
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                children: [
                  _buildAllMenuFavoriteSection(context),
                  if (availableGroups.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Text(
                        '추가 가능한 메뉴',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final group in availableGroups)
                      _buildAvailableGroup(context, group),
                  ],
                ],
              ),
            ),
          ),
          crossFadeState: _allMenuExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }

  List<_QuickPanelMenuGroup> _availableMenuGroups() {
    return _menuGroups
        .map((group) {
          final items = group.items
              .where((type) => !_favorites.contains(type))
              .toList(growable: false);
          return _QuickPanelMenuGroup(group.label, items);
        })
        .where((group) => group.items.isNotEmpty)
        .toList(growable: false);
  }

  Widget _buildAllMenuFavoriteSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Text(
            '즐겨찾기 메뉴',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (_favorites.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
            child: Text(
              '아직 선택한 메뉴가 없습니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          ReorderableListView.builder(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _favorites.length,
            onReorder: _reorder,
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.02).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            itemBuilder: (context, index) {
              final type = _favorites[index];
              final action = buildDashboardQuickAction(context, type);
              return _FavoriteMenuCheckboxTile(
                key: ValueKey('all-menu-favorite-${quickActionIdOf(type)}'),
                action: action,
                checked: true,
                dragHandle: ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.drag_handle, size: 20),
                  ),
                ),
                onChanged: (value) => _toggleFavorite(
                  type,
                  checked: value ?? false,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAvailableGroup(
    BuildContext context,
    _QuickPanelMenuGroup group,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Text(
            group.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        for (final type in group.items)
          CheckboxListTile(
            dense: true,
            value: false,
            controlAffinity: ListTileControlAffinity.leading,
            secondary: Icon(
              buildDashboardQuickAction(context, type).icon,
              size: 20,
            ),
            title: Text(
              buildDashboardQuickAction(context, type).label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: (value) => _toggleFavorite(
              type,
              checked: value ?? false,
            ),
          ),
      ],
    );
  }

  Widget _buildFavoriteList(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: _favorites.length,
      onReorder: _reorder,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.02).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
      itemBuilder: (context, index) {
        final type = _favorites[index];
        final action = buildDashboardQuickAction(
          context,
          type,
          onBeforeNavigate: widget.onClose,
        );

        return Padding(
          key: ValueKey('quick-panel-favorite-${quickActionIdOf(type)}'),
          padding: EdgeInsets.only(
            bottom: index == _favorites.length - 1 ? 0 : 8,
          ),
          child: DashboardQuickActionListTile(
            action: action,
            trailing: ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.drag_handle, size: 20),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyFavorites(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '전체 메뉴에서 자주 쓰는 기능을 체크해보세요.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _QuickPanelMenuGroup {
  final String label;
  final List<QuickActionType> items;

  const _QuickPanelMenuGroup(this.label, this.items);
}

class _FavoriteMenuCheckboxTile extends StatelessWidget {
  final DashboardQuickAction action;
  final bool checked;
  final Widget dragHandle;
  final ValueChanged<bool?> onChanged;

  const _FavoriteMenuCheckboxTile({
    super.key,
    required this.action,
    required this.checked,
    required this.dragHandle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 4,
          end: 8,
          top: 2,
          bottom: 2,
        ),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: onChanged,
              visualDensity: VisualDensity.compact,
            ),
            Icon(action.icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            dragHandle,
          ],
        ),
      ),
    );
  }
}
