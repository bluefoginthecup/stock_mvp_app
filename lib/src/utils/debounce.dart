// lib/src/utils/debounce.dart
import 'dart:async'; // ← Timer

typedef VoidCallback = void Function(); // ← Flutter 미의존으로 사용

class Debouncer {
  Debouncer({this.ms = 250});
  final int ms;
  Timer? _t;

  void run(VoidCallback f) {
    _t?.cancel();
    _t = Timer(Duration(milliseconds: ms), f);
  }

  void dispose() => _t?.cancel();
}
