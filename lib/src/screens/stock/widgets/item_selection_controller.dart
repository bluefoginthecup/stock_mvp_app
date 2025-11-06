import 'package:flutter/foundation.dart';

class ItemSelectionController extends ChangeNotifier {
  bool selectionMode = false;
  final Set<String> selected = <String>{};

  void enter([String? firstId]) {
    if (!selectionMode) { selectionMode = true; selected.clear(); }
    if (firstId != null) { selected.add(firstId); }
    notifyListeners();
  }

  void exit() {
    selectionMode = false; selected.clear(); notifyListeners();
  }

  void toggle(String id) {
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) { selected..clear()..addAll(ids); notifyListeners(); }
  void clear() { selected.clear(); notifyListeners(); }
}
