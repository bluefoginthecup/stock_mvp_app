// lib/main_web.dart
import 'package:flutter/material.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await AppBootstrap.buildApp(
    themeOverride: (base) => base,
  );
  runApp(app);
}
