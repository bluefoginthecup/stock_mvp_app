// lib/src/app/main_tab_controller.dart
import 'package:flutter/foundation.dart';

class MainTabController extends ChangeNotifier {
  static const dashboardTabId = 'dashboard';
  static const _legacyTabIds = [
    dashboardTabId,
    'orders',
    'stock',
    'txns',
    'works',
    'purchases',
  ];

  String _tabId = dashboardTabId;
  String get tabId => _tabId;

  int get index {
    final legacyIndex = _legacyTabIds.indexOf(_tabId);
    return legacyIndex < 0 ? 0 : legacyIndex;
  }

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
    if (i < 0 || i >= _legacyTabIds.length) {
      setTabId(dashboardTabId);
      return;
    }
    setTabId(_legacyTabIds[i]);
  }

  void setTabId(String id) {
    if (_tabId == id) return;
    _tabId = id;
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
