import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/services/auth_service.dart';
import 'src/services/reorder_reminder_service.dart';

/// Desktop entry point.
///
/// `StockApp` opens the database only after the signed-in account has been
/// identified. Opening [AppDatabase] here would bind its singleton to the
/// legacy, non-account-specific database before that happens.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await ReorderReminderService.initialize();

  Provider.debugCheckInvalidValueType = null;

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => const Uuid()),
      ],
      child: const StockApp(),
    ),
  );
}
