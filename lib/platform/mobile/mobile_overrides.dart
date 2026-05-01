// lib/platform/mobile/mobile_overrides.dart
import 'package:flutter/material.dart';

ThemeData mobileThemeOverride(ThemeData base) {
  return base.copyWith(
    visualDensity: VisualDensity.standard,
  );
}
