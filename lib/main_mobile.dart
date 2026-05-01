// lib/main_mobile.dart
import 'package:flutter/material.dart';
import 'bootstrap.dart';
import 'platform/mobile/mobile_overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final app = await AppBootstrap.buildApp(
    themeOverride: mobileThemeOverride,
  );
  runApp(app);
}
