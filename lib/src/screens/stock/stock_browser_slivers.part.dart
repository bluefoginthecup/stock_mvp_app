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
  final sel = context.watch<ItemSelectionController>();
  final picked = sel.selectedFolders.contains(n.id);

  return ListTile(
    dense: true, // ← 아이템 타일과 통일
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),

    leading: sel.selectionMode
        ? Checkbox(value: picked, onChanged: (_) => sel.toggleFolder(n.id))
        : const Icon(
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

    trailing: sel.selectionMode
        ? null
        : const Icon(
            Icons.chevron_right,
            size: 18, // ← 컴팩트 UI에 맞게 축소
            color: Colors.black45,
          ),

    onTap: () async {
      if (sel.selectionMode) {
        sel.toggleFolder(n.id);
        return;
      }
      if (onTapFolder != null) {
        await onTapFolder(n);
      } else {
        setState(() {
          final s =
              context.findAncestorStateOfType<_StockBrowserScreenState>()!;
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
      if (sel.selectionMode) {
        sel.toggleFolder(n.id);
        return;
      }

      final action = await showEntityActionsSheet(
        context,
        moveLabel: '폴더 이동',
      );
      if (action == null) return;
      if (!context.mounted) return;

      final repo = context.read<FolderTreeRepo>();
      switch (action) {
        case EntityAction.rename:
          final newName = await showNewFolderSheet(context, initial: n.name);
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
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('이동 실패: $e')),
              );
            }
          }
          break;

        case EntityAction.delete:
          final ok = await showDeleteConfirm(
            context,
            message: '"${n.name}" 폴더를 휴지통으로 보낼까요?',
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

        case EntityAction.cloneConfiguration:
          final service = context.read<FolderService>();
          final sampleSkus = await service.sampleSkusInFolder(n.id);
          if (!context.mounted) return;

          final options = await _showFolderConfigurationCloneDialog(
            context,
            sourceName: n.name,
            sampleSkus: sampleSkus,
          );
          if (options == null) return;
          if (!context.mounted) return;

          try {
            final result = await service.cloneFolderConfiguration(
              sourceFolderId: n.id,
              options: options,
            );

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '"${result.newFolderName}" 구성 ${result.itemCount}개를 만들었습니다.',
                ),
              ),
            );
            setState(() {});
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('구성복제 실패: $e')),
            );
          }
          break;
      }
    },
  );
}

Future<FolderCloneOptions?> _showFolderConfigurationCloneDialog(
  BuildContext context, {
  required String sourceName,
  required List<String> sampleSkus,
}) {
  return showDialog<FolderCloneOptions>(
    context: context,
    builder: (_) => _FolderConfigurationCloneDialog(
      sourceName: sourceName,
      sampleSkus: sampleSkus,
    ),
  );
}

class _FolderConfigurationCloneDialog extends StatefulWidget {
  final String sourceName;
  final List<String> sampleSkus;

  const _FolderConfigurationCloneDialog({
    required this.sourceName,
    required this.sampleSkus,
  });

  @override
  State<_FolderConfigurationCloneDialog> createState() =>
      _FolderConfigurationCloneDialogState();
}

class _FolderConfigurationCloneDialogState
    extends State<_FolderConfigurationCloneDialog> {
  late final TextEditingController replaceFromController;
  final replaceToController = TextEditingController();
  final skuReplaceFromController = TextEditingController();
  final skuReplaceToController = TextEditingController();
  bool resetQty = true;
  bool replaceSku = true;
  bool copyBom = true;

  @override
  void initState() {
    super.initState();
    replaceFromController = TextEditingController(text: widget.sourceName);
  }

  @override
  void dispose() {
    replaceFromController.dispose();
    replaceToController.dispose();
    skuReplaceFromController.dispose();
    skuReplaceToController.dispose();
    super.dispose();
  }

  void submit() {
    final replaceFrom = replaceFromController.text.trim();
    final replaceTo = replaceToController.text.trim();
    if (replaceFrom.isEmpty || replaceTo.isEmpty) return;
    Navigator.pop(
      context,
      FolderCloneOptions(
        replaceFrom: replaceFrom,
        replaceTo: replaceTo,
        skuReplaceFrom: skuReplaceFromController.text.trim(),
        skuReplaceTo: skuReplaceToController.text.trim(),
        resetQty: resetQty,
        replaceSku: replaceSku,
        copyBom: copyBom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('구성복제'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: replaceFromController,
              decoration: const InputDecoration(
                labelText: '바꿀 이름',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replaceToController,
              decoration: const InputDecoration(
                labelText: '새 이름',
                hintText: '예: 플로라 핑크',
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 16),
            if (widget.sampleSkus.isNotEmpty) ...[
              _ExistingSkuPreview(skus: widget.sampleSkus),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: skuReplaceFromController,
              decoration: const InputDecoration(
                labelText: 'SKU에서 바꿀 부분',
                hintText: '예: dotori_white',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: skuReplaceToController,
              decoration: const InputDecoration(
                labelText: 'SKU 새 문자열',
                hintText: '예: flora_pink',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: resetQty,
              title: const Text('현재고 0으로 시작'),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() => resetQty = value ?? true);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: replaceSku,
              title: const Text('SKU 치환 적용'),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() => replaceSku = value ?? true);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: copyBom,
              title: const Text('BOM/소요자재 구성 복사'),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() => copyBom = value ?? true);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: submit,
          child: const Text('복제하기'),
        ),
      ],
    );
  }
}

class _ExistingSkuPreview extends StatelessWidget {
  final List<String> skus;

  const _ExistingSkuPreview({required this.skus});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '기존 SKU',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          SelectableText(
            skus.join('\n'),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

SliverList _buildItemSliver(
  BuildContext context,
  List<Item> items, {
  Map<String, ItemLocationSummary> locationSummaries = const {},
  VoidCallback? onLocationChanged,
}) {
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
              onLocationChanged?.call();
            }
          },
          onLongPress: () async {
            // 롱프레스 → 수량 조정(기존 로직 유지)
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
          locationSummary: locationSummaries[it.id],
          onTapLocation: locationSummaries[it.id]?.primaryLocation == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StorageLocationDetailScreen(
                        locationId:
                            locationSummaries[it.id]!.primaryLocation!.id,
                      ),
                    ),
                  );
                },
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
