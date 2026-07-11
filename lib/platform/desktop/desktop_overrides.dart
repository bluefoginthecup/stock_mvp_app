// lib/platform/desktop/desktop_overrides.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

ThemeData desktopThemeOverride(ThemeData base) {
  return base.copyWith(
    visualDensity: VisualDensity.comfortable, // 마우스/대화면에 맞춤
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.macOS: _NoTransitionsBuilder(),
        TargetPlatform.windows: _NoTransitionsBuilder(),
        TargetPlatform.linux: _NoTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// 데스크톱은 페이지 트랜지션 덜 요란하게
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route, BuildContext context, Animation<double> anim,
    Animation<double> secAnim, Widget child,
  ) => child;
}
