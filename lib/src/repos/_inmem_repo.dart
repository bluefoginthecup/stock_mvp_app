// // inmem_repo.dart
// Future<List<Item>> listItemsByFolderPath({
//   String? l1,
//   String? l2,
//   String? l3,
//   String? keyword,
//   bool recursive = false, // ← 추가: 기본 비재귀(직속만)
// }) async {
//   Iterable<MapEntry<String, Item>> it = _items.entries;
//
//   final wantedDepth = (l1 == null) ? 0 : (l2 == null) ? 1 : (l3 == null) ? 2 : 3;
//
//   bool _pathMatches(String itemId) {
//     final path = _itemPaths[itemId];
//     if (path == null) return false;
//
//     // prefix 매칭
//     if (l1 != null && (path.isEmpty || path[0] != l1)) return false;
//     if (l2 != null && (path.length < 2 || path[1] != l2)) return false;
//     if (l3 != null && (path.length < 3 || path[2] != l3)) return false;
//
//     // 🔑 비재귀면 "직속"만 (경로 길이 정확히 일치)
//     if (!recursive) return path.length == wantedDepth;
//
//     return true;
//   }
//
//   it = it.where((e) => _pathMatches(e.key));
//
//   if (keyword != null && keyword.trim().isNotEmpty) {
//     final k = keyword.trim().toLowerCase();
//     it = it.where((e) {
//       final v = e.value;
//       return v.name.toLowerCase().contains(k) || v.sku.toLowerCase().contains(k);
//     });
//   }
//   return it.map((e) => e.value).toList(growable: false);
// }
