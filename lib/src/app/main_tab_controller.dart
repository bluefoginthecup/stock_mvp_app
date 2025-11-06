// lib/src/app/main_tab_controller.dart
import 'package:flutter/foundation.dart';

class MainTabController extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void setIndex(int i) {
    if (_index == i) return;
    _index = i;
    notifyListeners();
  }
}
