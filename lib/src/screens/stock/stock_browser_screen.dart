// Explorer-style Stock browser: L1 (roots) -> L2 -> L3 -> Items
import 'dart:async'; // ← Timer를 쓰려면 꼭 필요!
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/folder_node.dart';
import '../../models/item.dart';
import '../../repos/inmem_repo.dart';
import 'sheet_new_folder.dart';
import 'stock_new_item_sheet.dart';
import '../../ui/common/search_field.dart'; // ← 공용 검색 위젯

class StockBrowserScreen extends StatefulWidget {
  const StockBrowserScreen({super.key});

  @override
  State<StockBrowserScreen> createState() => _StockBrowserScreenState();
}

class _StockBrowserScreenState extends State<StockBrowserScreen> {
  Timer? _debounce;
  String? _l1Id;
  String? _l2Id;
  String? _l3Id; // l3 선택 시 아이템 표시

  final _searchC = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel(); // 추가
    _searchC.dispose();
    super.dispose();
  }
  Future<void> _createFolder() async {
    final repo = context.read<InMemoryRepo>();

    // 1) 선택 폴더 확인
    final parentId = _l3Id ?? _l2Id ?? _l1Id;
    if (parentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 상위 폴더를 선택하세요.')),
      );
      return;
    }

    // 2) L3(소분류)에서는 폴더 생성 불가
    final parent = repo.folderById(parentId);
    if (parent != null && parent.depth >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('소분류 아래에는 폴더를 만들 수 없습니다.')),
      );
      return;
    }

    // 3) 폴더 이름 입력 모달
    final name = await showNewFolderSheet(context);
    if (name == null || name.trim().isEmpty) return;

    // 4) 실제 생성
    await repo.createFolderNode(parentId: parentId, name: name.trim());
    if (!mounted) return;
    setState(() {});
  }


  // ✅ 유연형: 현재 폴더 아래 어디서든 아이템 생성
  Future<void> _createItem() async {
    final repo = context.read<InMemoryRepo>();

    // 현재 선택된 폴더 ID (가장 하위 선택)
    final selectedId = _l3Id ?? _l2Id ?? _l1Id;

    if (selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 폴더를 선택하세요.')),
      );
      return;
    }

    // ✅ 상위 폴더까지 체인 만들기
    final chain = <String>[];
    var cur = repo.folderById(selectedId);
    while (cur != null) {
      chain.insert(0, cur.id); // 앞쪽에 추가해서 [L1, L2, L3] 순서로 만듦
      cur = (cur.parentId != null) ? repo.folderById(cur.parentId!) : null;
    }

    // 예: [완제품ID, 방석커버ID, 루앙그레이ID]
    print('[createItem] path chain = $chain');

    // 아이템 생성창 띄우기
    final created = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StockNewItemSheet(pathIds: chain), // 이건 그대로 넘기기
    );

    if (created != null) {
      await repo.createItemUnderPath(pathIds: chain, item: created); // ✅ 수정된 부분
      if (!mounted) return;
      setState(() {});
    }
  }

  Widget _breadcrumb() {
    final repo = context.read<InMemoryRepo>();
    String nameOf(String? id) {
      if (id == null) return '';
      final n = repo.folderById(id);
      return n?.name ?? '(삭제됨)';
    }

    final segs = <Widget>[];
    segs.add(
      TextButton(
        onPressed: () => setState(() {
          _l1Id = null;
          _l2Id = null;
          _l3Id = null;
        }),
        child: const Text('대분류'),
      ),
    );
    if (_l1Id != null) {
      segs.add(const Text(' > '));
      segs.add(
        TextButton(
          onPressed: () => setState(() {
            _l2Id = null;
            _l3Id = null;
          }),
          child: Text(nameOf(_l1Id)),
        ),
      );
    }
    if (_l2Id != null) {
      segs.add(const Text(' > '));
      segs.add(
        TextButton(
          onPressed: () => setState(() {
            _l3Id = null;
          }),
          child: Text(nameOf(_l2Id)),
        ),
      );
    }
    if (_l3Id != null) {
      segs.add(const Text(' > '));
      segs.add(Text(nameOf(_l3Id)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: segs),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<InMemoryRepo>();
    final repo = context.read<InMemoryRepo>();

    final parent = _l3Id ?? _l2Id ?? _l1Id;
    final depth = _l3Id != null ? 3 : _l2Id != null ? 2 : _l1Id != null ? 1 : 0;
    final hasKeyword = _searchC.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('재고 브라우저')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.all(12), child: _breadcrumb()),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: AppSearchField(
              controller: _searchC,
              hint: '폴더명 / 아이템명 / SKU 검색',
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() {});
                });
              },
            ),
          ),
          const Divider(height: 1),

          // ✅ 검색어가 있을 땐 폴더+아이템 동시 검색
          Expanded(
            child: FutureBuilder<Object?>(
              future: hasKeyword
                  ? repo.searchAll(
                l1: _l1Id, l2: _l2Id, l3: _l3Id,
                keyword: _searchC.text, recursive: true,
              )
                  : (
                  depth == 0
// 루트: 폴더만
                      ? repo.listFolderChildren(null)
// L1/L2/L3: 폴더 + "직속" 아이템
                      : Future.wait([
                    repo.listFolderChildren(_l3Id ?? _l2Id ?? _l1Id),
                    repo.listItemsByFolderPath(
                      l1: _l1Id, l2: _l2Id, l3: _l3Id,
                      keyword: null,
                      recursive: false, // ← 직속만
                    ),
                  ])
              ),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('오류: ${snap.error}'));
                }

                // 🔍 검색 결과 모드
                                if (hasKeyword) {
                                  final tuple = snap.data as (List<FolderNode>, List<Item>);
                                  final folders = tuple.$1;
                                  final items = tuple.$2;

                                  if (folders.isEmpty && items.isEmpty) {
                                    return const Center(child: Text('검색 결과가 없습니다.'));
                                  }

                                  return ListView(
                                    children: [
                                      if (folders.isNotEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('📁 폴더', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      if (folders.isNotEmpty) _buildFolderList(folders),
                                      if (items.isNotEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('📦 아이템', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      if (items.isNotEmpty) _buildItemList(items),
                                    ],
                                  );
                                }

                                // 📁 depth==0 (루트) → 폴더만 표시
                                final depth = _l3Id != null ? 3 : _l2Id != null ? 2 : _l1Id != null ? 1 : 0;
                                if (depth == 0) {
                                  final folders = snap.data as List<FolderNode>;
                                  if (folders.isEmpty) {
                                    return const Center(child: Text('하위 폴더가 없습니다.  버튼으로 추가하세요.'));
                                  }
                                  return _buildFolderList(folders);
                                }

                                // 📦 L1/L2/L3 → 폴더  직속 아이템
                                final result = snap.data as List<Object>;
                                final folders = result[0] as List<FolderNode>;
                                final items = result[1] as List<Item>;

                                if (folders.isEmpty && items.isEmpty) {
                                  return const Center(
                                    child: Text('하위 폴더나 아이템이 없습니다.  버튼으로 추가하세요.'),
                                  );
                                }

                                return ListView(
                                  children: [
                                    if (folders.isNotEmpty) _buildFolderList(folders),
                                    if (items.isNotEmpty) _buildItemList(items),
                                  ],
                                );
              },
            ),
          ),
        ],
      ),

      // ✅ floating button: 현재 폴더에 아이템/폴더 추가
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final act = await showModalBottomSheet<String>(
            context: context,
            builder: (_) => SafeArea(
              child: Wrap(children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('새 아이템'),
                  onTap: () => Navigator.pop(context, 'item'),
                ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder),
                  title: const Text('새 폴더'),
                  onTap: () => Navigator.pop(context, 'folder'),
                ),
              ]),
            ),
          );

          if (act == 'folder') {
            await _createFolder();
            return;
          }
          if (act == 'item') {
            await _createItem();
            return;
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ───────────────────────────────────────── Helper UIs ─────────────────────────────────────────

  Widget _buildFolderList(List<FolderNode> nodes) {
    final repo = context.read<InMemoryRepo>();
    return Column(
      children: nodes.map((n) {
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(n.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            setState(() {
              if (_l1Id == null) {
                _l1Id = n.id;
              } else if (_l2Id == null) {
                _l2Id = n.id;
              } else {
                _l3Id = n.id;
              }
            });
          },
          onLongPress: () async {
            final choice = await showFolderContextMenu(context, n);
            if (choice == FolderMenu.rename) {
              final newName = await showNewFolderSheet(context, initial: n.name);
              if (newName != null && newName.trim().isNotEmpty) {
                await repo.renameFolderNode(id: n.id, newName: newName.trim());
                setState(() {});
              }
            } else if (choice == FolderMenu.delete) {
              try {
                await repo.deleteFolderNode(n.id);
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('삭제 실패: $e')),
                );
              }
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildItemList(List<Item> items) {
    return Column(
      children: items.map((it) {
        final low = it.minQty > 0 && it.qty <= it.minQty;
        return ListTile(
          leading: Icon(low ? Icons.warning_amber_rounded : Icons.inventory_2),
          title: Text(
            it.name,
            style: TextStyle(
              color: low ? Colors.red : null,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text('${it.sku} • ${it.unit}'),
          trailing: Text('${it.qty}'),
          onTap: () {/* TODO: item detail */},
          onLongPress: () {/* TODO: move/edit/delete */},
        );
      }).toList(),
    );
  }
}
