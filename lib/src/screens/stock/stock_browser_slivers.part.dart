// lib/src/screens/stock/stock_browser_slivers.part.dart
part of 'stock_browser_screen.dart';



// ───────────────────────── Sliver builders ─────────────────────────
SliverList _buildFolderSliver(
    BuildContext context,
    List<FolderNode> nodes,
    void Function(void Function()) setState,
    Future<void> Function(FolderNode n) onDelete,
    Future<void> Function(FolderNode n)? onTapFolder, // ✅ 추가
    ) {
  return SliverList(
    delegate: SliverChildBuilderDelegate(
          (context, i) => _buildFolderTile(
            context,
            nodes[i],
            setState,
            onDelete,
            onTapFolder,
          ),
      childCount: nodes.length,
    ),
  );
}

Widget _buildFolderTile(
    BuildContext context,
    FolderNode n,
    void Function(void Function()) setState,
    Future<void> Function(FolderNode n) onDelete,
    Future<void> Function(FolderNode n)? onTapFolder,
    ) {
  return ListTile(
    dense: true,   // ← 아이템 타일과 통일
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),

    leading: const Icon(
      Icons.folder,
      size: 22, // ← 아이템 아이콘(Inventory)와 비슷하게 줄이기
    ),

    // 🔥 폴더 글자 크게 + 아이템과 통일
    title: Text(
      n.name,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),

    trailing: const Icon(
      Icons.chevron_right,
      size: 18, // ← 컴팩트 UI에 맞게 축소
      color: Colors.black45,
    ),


  onTap: () async {
  if (onTapFolder != null) {
  await onTapFolder(n);
  } else {
      setState(() {
        final s = context.findAncestorStateOfType<_StockBrowserScreenState>()!;
        if (s._l1Id == null) {
          s._l1Id = n.id;
        } else if (s._l2Id == null) {
          s._l2Id = n.id;
        } else {
          s._l3Id = n.id;
        }
      });
    }
  },
    onLongPress: () async {
      final action = await showEntityActionsSheet(
        context,
        moveLabel: '폴더 이동',
      );
      if (action == null) return;

      final repo = context.read<FolderTreeRepo>();
      switch (action) {
        case EntityAction.rename:
          final newName =
          await showNewFolderSheet(context, initial: n.name);
          if (newName != null && newName.trim().isNotEmpty) {
            await repo.renameFolderNode(id: n.id, newName: newName.trim());
            if (!context.mounted) return;
            setState(() {});
          }
          break;

        case EntityAction.move:
          final dest = await showPathPicker(
            context,
            childrenProvider: folderChildrenProvider(repo),
            title: '폴더 이동..',
            maxDepth: 2,
          );
          if (dest != null && dest.isNotEmpty) {
            try {
              await repo.moveEntityToPath(
                MoveRequest(kind: EntityKind.folder, id: n.id, pathIds: dest),
              );
              if (!context.mounted) return;
              setState(() {});
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('이동 실패: $e')),
              );
            }
          }
          break;

        case EntityAction.delete:
          final ok = await showDeleteConfirm(
            context,
            message: '"${n.name}" 폴더를 삭제하시겠어요?',
          );
          if (ok == true) await onDelete(n);
          break;

        case EntityAction.copy:
          final service = FolderService(context.read<DriftUnifiedRepo>());

          await service.copyFolderTree(n.id);

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${n.name}" 복사 완료')),
          );

          setState(() {});
          break;
      }
    },
  );
}
SliverList _buildItemSliver(BuildContext context, List<Item> items) {
  return SliverList(
    delegate: SliverChildBuilderDelegate(
          (context, i) {
        final sel = context.watch<ItemSelectionController>();
        final it = items[i];
        final picked = sel.selected.contains(it.id);

        return StockItemSelectTile(
          item: it,
          selectionMode: sel.selectionMode,
          selected: picked,
          onTap: () async {
            if (sel.selectionMode) {
              sel.toggle(it.id);
            } else {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StockItemDetailScreen(itemId: it.id),
                ),
              );
            }
          },
          onLongPress: () async {
            // 롱프레스 → 수량 조정(기존 로직 유지)
            final itemRepo = context.read<ItemRepo>();
            await runQtySetFlow(
              context,
              currentQty: it.qty,
              minQtyHint: it.minQty,
              apply: (finalDelta) =>
                  StockService.applyItemQtyChange(context, it, finalDelta),
              onSuccess: () async {},
              successMessage: context.t.btn_save,
              errorPrefix: context.t.common_error,
            );
          },
          onTogglePick: () => sel.toggle(it.id),
        );
      },
      childCount: items.length,
    ),
  );
}
// ───────────────────────── Compact Section Header (재추가) ─────────────────────────
SliverToBoxAdapter _sliverHeader(String text) {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  );
}

// ───────────────────────── Breadcrumb (로컬 구현) ─────────────────────────
Widget _breadcrumbRow(
    BuildContext context,
    _StockBrowserScreenState s,
    void Function(void Function()) setState,
    ) {
  final segs = <Widget>[
    TextButton(
      onPressed: () => setState(() {
        s._l1Id = null;
        s._l2Id = null;
        s._l3Id = null;
      }),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('대분류', style: TextStyle(fontSize: 13)),
    ),
  ];

  if (s._l1Id != null) {
    segs.addAll([
      const Text(' > ', style: TextStyle(fontSize: 13)),
      TextButton(
        onPressed: () => setState(() {
          s._l2Id = null;
          s._l3Id = null;
        }),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: folderName(context, s._l1Id!),
      ),
    ]);
  }
  if (s._l2Id != null) {
    segs.addAll([
      const Text(' > ', style: TextStyle(fontSize: 13)),
      TextButton(
        onPressed: () => setState(() => s._l3Id = null),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: folderName(context, s._l2Id!),
      ),
    ]);
  }
  if (s._l3Id != null) {
    segs.addAll([
      const Text(' > ', style: TextStyle(fontSize: 13)),
      folderName(context, s._l3Id!),
    ]);
  }

  return Row(children: segs);
}

SliverToBoxAdapter _sliverBreadcrumb(
    BuildContext context,
    void Function(void Function()) setState,
    ) {
  final s = context.findAncestorStateOfType<_StockBrowserScreenState>()!;
  return SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _breadcrumbRow(context, s, setState), // 로컬 함수 사용
          ),
        ),
        const Divider(height: 1),
      ],
    ),
  );
}


