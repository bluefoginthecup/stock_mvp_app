import 'package:flutter/foundation.dart';

class ItemSelectionController extends ChangeNotifier {
  bool selectionMode = false;
  final Set<String> selectedItems = <String>{};
  final Set<String> selectedFolders = <String>{};

  Set<String> get selected => selectedItems;
  int get selectedCount => selectedItems.length + selectedFolders.length;

  void enter([String? firstId]) {
    if (!selectionMode) {
      selectionMode = true;
      clear(notify: false);
    }
    if (firstId != null) {
      selectedItems.add(firstId);
    }
    notifyListeners();
  }

  void enterFolder(String folderId) {
    if (!selectionMode) {
      selectionMode = true;
      clear(notify: false);
    }
    selectedFolders.add(folderId);
    notifyListeners();
  }

  void exit() {
    selectionMode = false;
    clear(notify: false);
    notifyListeners();
  }

  void toggle(String id) {
    selectedItems.contains(id)
        ? selectedItems.remove(id)
        : selectedItems.add(id);
    notifyListeners();
  }

  void toggleFolder(String id) {
    selectedFolders.contains(id)
        ? selectedFolders.remove(id)
        : selectedFolders.add(id);
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    selectedItems
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void selectAllEntities({
    required Iterable<String> itemIds,
    required Iterable<String> folderIds,
  }) {
    selectedItems
      ..clear()
      ..addAll(itemIds);
    selectedFolders
      ..clear()
      ..addAll(folderIds);
    notifyListeners();
  }

  void clear({bool notify = true}) {
    selectedItems.clear();
    selectedFolders.clear();
    if (notify) notifyListeners();
  }
}
