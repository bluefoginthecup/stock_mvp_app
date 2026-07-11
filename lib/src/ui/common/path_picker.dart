import 'package:flutter/material.dart';

/// 트리 노드 최소 인터페이스
class PathNode {
  final String id;
  final String name;
  PathNode(this.id, this.name);
}

/// childrenProvider: parentId(null 허용) -> 그 레벨의 노드들
typedef ChildrenProvider = Future<List<PathNode>> Function(String? parentId);

/// 결과: [L1], [L1,L2], [L1,L2,L3] 등 선택 깊이에 따라 가변
Future<List<String>?> showPathPicker(
  BuildContext context, {
  required ChildrenProvider childrenProvider,
  String title = '이동할 경로 선택',
  String l1Label = '대분류',
  String l2Label = '중분류',
  String l3Label = '소분류',
  int maxDepth = 3,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PathPickerSheet(
      childrenProvider: childrenProvider,
      title: title,
      labels: [l1Label, l2Label, l3Label],
      maxDepth: maxDepth.clamp(1, 3),
    ),
  );
}

class _PathPickerSheet extends StatefulWidget {
  final ChildrenProvider childrenProvider;
  final String title;
  final List<String> labels;
  final int maxDepth;

  const _PathPickerSheet({
    required this.childrenProvider,
    required this.title,
    required this.labels,
    required this.maxDepth,
  });

  @override
  State<_PathPickerSheet> createState() => _PathPickerSheetState();
}

class _PathPickerSheetState extends State<_PathPickerSheet> {
  final _searchC = TextEditingController();
  final _selectedIds = <String>[];
  final _selectedNames = <String>[];
  late Future<List<_PathChoice>> _allPathsFuture;

  @override
  void initState() {
    super.initState();
    _allPathsFuture = _loadAllPaths();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  List<String> get _selectedPath => List.unmodifiable(_selectedIds);

  String get _selectedLabel {
    if (_selectedNames.isEmpty) return '선택된 위치가 없습니다';
    return _selectedNames.join(' > ');
  }

  Future<List<_PathChoice>> _loadAllPaths() async {
    final result = <_PathChoice>[];

    Future<void> walk({
      required String? parentId,
      required int depth,
      required List<String> ids,
      required List<String> names,
    }) async {
      if (depth > widget.maxDepth) return;
      final children = await widget.childrenProvider(parentId);
      for (final child in children) {
        final nextIds = [...ids, child.id];
        final nextNames = [...names, child.name];
        result.add(_PathChoice(
          ids: nextIds,
          names: nextNames,
          depth: depth,
        ));
        await walk(
          parentId: child.id,
          depth: depth + 1,
          ids: nextIds,
          names: nextNames,
        );
      }
    }

    await walk(parentId: null, depth: 1, ids: const [], names: const []);
    return result;
  }

  Future<List<PathNode>> _childrenForDepth(int depth) {
    if (depth == 1) return widget.childrenProvider(null);
    final parentIndex = depth - 2;
    if (_selectedIds.length <= parentIndex) {
      return Future.value(const <PathNode>[]);
    }
    return widget.childrenProvider(_selectedIds[parentIndex]);
  }

  void _pickNode(int depth, PathNode node) {
    setState(() {
      final index = depth - 1;
      if (_selectedIds.length > index) {
        _selectedIds.removeRange(index, _selectedIds.length);
        _selectedNames.removeRange(index, _selectedNames.length);
      }
      _selectedIds.add(node.id);
      _selectedNames.add(node.name);
    });
  }

  void _pickPath(_PathChoice path) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(path.ids);
      _selectedNames
        ..clear()
        ..addAll(path.names);
      _searchC.clear();
    });
  }

  bool _isSelectedAtDepth(int depth, String id) {
    final index = depth - 1;
    return _selectedIds.length > index && _selectedIds[index] == id;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.55,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchC,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '폴더명 검색',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _searchC.text.trim().isEmpty
                      ? _buildDepthPicker(scrollController)
                      : _buildSearchResults(scrollController),
                ),
                _PathConfirmBar(
                  selectedLabel: _selectedLabel,
                  canConfirm: _selectedIds.isNotEmpty,
                  onCancel: () => Navigator.pop(context),
                  onConfirm: () => Navigator.pop(context, _selectedPath),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDepthPicker(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      children: [
        for (var depth = 1; depth <= widget.maxDepth; depth++)
          if (depth == 1 || _selectedIds.length >= depth - 1)
            _buildLevel(depth),
      ],
    );
  }

  Widget _buildLevel(int depth) {
    return FutureBuilder<List<PathNode>>(
      future: _childrenForDepth(depth),
      builder: (context, snapshot) {
        final style = _PathDepthStyle.of(context, depth);
        final label = widget.labels[depth - 1];

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DepthHeader(label: label, style: style),
                const SizedBox(height: 8),
                LinearProgressIndicator(color: style.accent),
              ],
            ),
          );
        }

        final nodes = snapshot.data ?? const <PathNode>[];
        if (nodes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DepthHeader(label: label, style: style),
                const SizedBox(height: 8),
                Text(
                  '$label 폴더가 없습니다',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _DepthHeader(label: label, style: style),
              ),
              const SizedBox(height: 6),
              for (final node in nodes)
                _PathNodeTile(
                  node: node,
                  depth: depth,
                  selected: _isSelectedAtDepth(depth, node.id),
                  style: style,
                  onTap: () => _pickNode(depth, node),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(ScrollController scrollController) {
    final query = _searchC.text.trim().toLowerCase();
    return FutureBuilder<List<_PathChoice>>(
      future: _allPathsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final paths = (snapshot.data ?? const <_PathChoice>[])
            .where((path) => path.searchText.contains(query))
            .toList();

        if (paths.isEmpty) {
          return const Center(child: Text('검색 결과가 없습니다'));
        }

        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          itemCount: paths.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final path = paths[index];
            final style = _PathDepthStyle.of(context, path.depth);
            final selected = _selectedIds.length == path.ids.length &&
                _selectedIds.lastOrNull == path.ids.last;
            return _PathSearchTile(
              path: path,
              style: style,
              selected: selected,
              onTap: () => _pickPath(path),
            );
          },
        );
      },
    );
  }
}

class _PathChoice {
  final List<String> ids;
  final List<String> names;
  final int depth;

  const _PathChoice({
    required this.ids,
    required this.names,
    required this.depth,
  });

  String get label => names.join(' > ');
  String get searchText => label.toLowerCase();
}

class _PathDepthStyle {
  final Color background;
  final Color selectedBackground;
  final Color accent;
  final Color foreground;

  const _PathDepthStyle({
    required this.background,
    required this.selectedBackground,
    required this.accent,
    required this.foreground,
  });

  static _PathDepthStyle of(BuildContext context, int depth) {
    final scheme = Theme.of(context).colorScheme;
    switch (depth) {
      case 1:
        return _PathDepthStyle(
          background: const Color(0xFFEAF6FF),
          selectedBackground: const Color(0xFFD3ECFF),
          accent: const Color(0xFF4BA3E3),
          foreground: scheme.onSurface,
        );
      case 2:
        return _PathDepthStyle(
          background: const Color(0xFFE1F0FF),
          selectedBackground: const Color(0xFFC2E1FF),
          accent: const Color(0xFF1976D2),
          foreground: scheme.onSurface,
        );
      default:
        return _PathDepthStyle(
          background: const Color(0xFFD9E8FF),
          selectedBackground: const Color(0xFFB8D4FF),
          accent: const Color(0xFF0D47A1),
          foreground: scheme.onSurface,
        );
    }
  }
}

class _DepthHeader extends StatelessWidget {
  final String label;
  final _PathDepthStyle style;

  const _DepthHeader({
    required this.label,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: style.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: style.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PathNodeTile extends StatelessWidget {
  final PathNode node;
  final int depth;
  final bool selected;
  final _PathDepthStyle style;
  final VoidCallback onTap;

  const _PathNodeTile({
    required this.node,
    required this.depth,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (depth) {
      1 => '대분류',
      2 => '중분류',
      _ => '소분류',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? style.selectedBackground : style.background,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          minLeadingWidth: 28,
          leading: Icon(
            selected ? Icons.folder_open : Icons.folder_outlined,
            color: style.accent,
          ),
          title: Text(
            node.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: style.foreground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(label),
          trailing: selected ? Icon(Icons.check, color: style.accent) : null,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _PathSearchTile extends StatelessWidget {
  final _PathChoice path;
  final _PathDepthStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _PathSearchTile({
    required this.path,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final depthLabel = switch (path.depth) {
      1 => '대분류',
      2 => '중분류',
      _ => '소분류',
    };

    return Material(
      color: selected ? style.selectedBackground : style.background,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.search, color: style.accent),
        title: Text(
          path.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text(depthLabel),
        trailing: selected ? Icon(Icons.check, color: style.accent) : null,
        onTap: onTap,
      ),
    );
  }
}

class _PathConfirmBar extends StatelessWidget {
  final String selectedLabel;
  final bool canConfirm;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _PathConfirmBar({
    required this.selectedLabel,
    required this.canConfirm,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '선택 위치',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 2),
              Text(
                selectedLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: canConfirm ? onConfirm : null,
                      child: const Text('이 위치로 이동'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
