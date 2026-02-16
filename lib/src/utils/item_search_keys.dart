import '../models/item.dart';
import 'korean_search.dart';

({String baseName, String nameNorm, String initials, String fullNorm})
buildItemSearchKeys(Item item) {
  final baseName =
  (item.displayName?.trim().isNotEmpty == true)
      ? item.displayName!.trim()
      : item.name;

  return (
  baseName: baseName,
  nameNorm: normalizeForSearch(baseName),
  initials: toChosungString(baseName),
  fullNorm: _buildFullNormalized(
    name: baseName,
    sku: item.sku,
    folder: item.folder,
    subfolder: item.subfolder,
    subsubfolder: item.subsubfolder,
  ),
  );
}

String _buildFullNormalized({
  required String name,
  required String sku,
  String? folder,
  String? subfolder,
  String? subsubfolder,
}) {
  final src = [
    name,
    sku,
    if (folder != null) folder,
    if (subfolder != null) subfolder,
    if (subsubfolder != null) subsubfolder,
  ].join(' ');
  return normalizeForSearch(src);
}
 ({String baseName, String nameNorm, String initials, String fullNorm})
 buildItemSearchKeysRaw({
   required String name,
   required String sku,
   String? folder,
   String? subfolder,
   String? subsubfolder,
 }) {
   return (
     baseName: name,
     nameNorm: normalizeForSearch(name),
     initials: toChosungString(name),
     fullNorm: normalizeForSearch(
       [
         name,
         sku,
         if (folder != null) folder,
         if (subfolder != null) subfolder,
         if (subsubfolder != null) subsubfolder,
       ].join(' '),
     ),
   );
 }
