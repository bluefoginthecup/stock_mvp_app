// lib/src/app/main_tab_controller.dart
import 'package:flutter/foundation.dart';

class MainTabController extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  get jumpTo => null;

  Future<Object?> Function(
    String routeName, {
    Object? arguments,
    int tabIndex,
  })? _shellRouteOpener;

  void attachShellRouteOpener(
    Future<Object?> Function(
      String routeName, {
      Object? arguments,
      int tabIndex,
    }) opener,
  ) {
    _shellRouteOpener = opener;
  }

  void detachShellRouteOpener(
    Future<Object?> Function(
      String routeName, {
      Object? arguments,
      int tabIndex,
    }) opener,
  ) {
    if (_shellRouteOpener == opener) {
      _shellRouteOpener = null;
    }
  }

  void setIndex(int i) {
    if (_index == i) return;
    _index = i;
    notifyListeners();
  }

  Future<T?> openShellRoute<T>(
    String routeName, {
    Object? arguments,
    int tabIndex = 0,
  }) async {
    setIndex(tabIndex);
    final result = await _shellRouteOpener?.call(
      routeName,
      arguments: arguments,
      tabIndex: tabIndex,
    );
    return result as T?;
  }
}
