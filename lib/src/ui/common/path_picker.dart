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
      int maxDepth = 3, // 필요하면 더 깊게도 확장 가능
    }) {
  String? l1;
  String? l2;
  String? l3;

  List<String> buildPath() {
    final p = <String>[];
    if (l1 != null) p.add(l1!);
    if (l2 != null) p.add(l2!);
    if (l3 != null) p.add(l3!);
    return p;
  }

  Widget level(String label, String? currentId, Future<List<PathNode>> future, void Function(String) onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        FutureBuilder<List<PathNode>>(
          future: future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              );
            }
            final list = snap.data ?? [];
            return Column(
              children: list.map((n) {
                final selected = n.id == currentId;
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(n.name),
                  trailing: selected ? const Icon(Icons.check) : null,
                  onTap: () => onPick(n.id),
                );
              }).toList(),
            );
          },
        ),
        const Divider(height: 1),
      ],
    );
  }

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        bool canConfirm() => l1 != null;

        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            builder: (ctx, scroll) {
              return SingleChildScrollView(
                controller: scroll,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    level(l1Label, l1, childrenProvider(null), (id) {
                      l1 = id; l2 = null; l3 = null; setSheetState(() {});
                    }),
                    if (maxDepth >= 2 && l1 != null)
                      level(l2Label, l2, childrenProvider(l1), (id) {
                        l2 = id; l3 = null; setSheetState(() {});
                      }),
                    if (maxDepth >= 3 && l2 != null)
                      level(l3Label, l3, childrenProvider(l2), (id) {
                        l3 = id; setSheetState(() {});
                      }),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('취소'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: canConfirm() ? () => Navigator.pop(context, buildPath()) : null,
                              child: const Text('확인'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
