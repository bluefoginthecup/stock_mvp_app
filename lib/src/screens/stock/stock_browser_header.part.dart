// lib/src/screens/stock/stock_browser_header.part.dart
part of 'stock_browser_screen.dart';

///  장바구니 담기 고정 바 시작 ///
const double _kSelectBarHeight = 36.0;

class _SelectBarHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  const _SelectBarHeader({required this.child, this.height = _kSelectBarHeight});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(height: height, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _SelectBarHeader old) =>
      old.child != child || old.height != height;
}

/// 고정바 끝 ///

/// ───────────────────────── AppBar 빌더 ─────────────────────────
PreferredSizeWidget buildAppBar(
    BuildContext context, FolderTreeRepo folderRepo, ItemRepo itemRepo) {
  return AppBar(
    title: const Text('재고 브라우저'),
    actions: [
      IconButton(
        icon: const Icon(Icons.ios_share),
        tooltip: 'JSON 내보내기',
        onPressed: () async {
          final svc = ExportService(itemRepo: itemRepo, folderRepo: folderRepo);
          try {
            await svc.exportEditedJson();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('폴더/아이템 JSON 내보내기 완료')),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('내보내기 실패: $e')),
            );
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.shopping_cart),
        tooltip: '장바구니 보기',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          );
        },
      ),
      Builder(builder: (_) {
        final repo = context.watch<FolderTreeRepo>();
        return PopupMenuButton<FolderSortMode>(
          tooltip: '정렬',
          icon: const Icon(Icons.sort),
          initialValue: repo.sortMode,
          onSelected: (m) => context.read<FolderTreeRepo>().setSortMode(m),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: FolderSortMode.name,
              child: Text('이름순'),
            ),
            PopupMenuItem(
              value: FolderSortMode.manual,
              child: Text('사용자순'),
            ),
          ],
        );
      }),
    ],
  );
}

/// ───────────────────────── Breadcrumb ─────────────────────────
Widget buildBreadcrumb(
    context,_StockBrowserScreenState s, void Function(void Function()) setState) {
  final segs = <Widget>[
    TextButton(
      onPressed: () => setState(() {
        s._l1Id = null;
        s._l2Id = null;
        s._l3Id = null;
      }),
      child: const Text('대분류'),
    ),
  ];

  if (s._l1Id != null) {
    segs.addAll([
      const Text(' > '),
      TextButton(
        onPressed: () => setState(() {
          s._l2Id = null;
          s._l3Id = null;
        }),
        child: folderName(context, s._l1Id!),

      ),
    ]);
  }
  if (s._l2Id != null) {
    segs.addAll([
      const Text(' > '),
      TextButton(
        onPressed: () => setState(() => s._l3Id = null),
        child: folderName(context,s._l2Id!),

      ),
    ]);
  }
  if (s._l3Id != null) {
    segs.addAll([const Text(' > '), folderName(context,s._l3Id!)]);
  }

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: segs),
  );
}
