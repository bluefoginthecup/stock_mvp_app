import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart'; // ✅ 추가
import 'firebase_options.dart'; // ✅ 플랫폼별 FirebaseOptions
import 'package:firebase_auth/firebase_auth.dart';

import 'src/app.dart';

// ✅ 추가: Auth & Gate
import 'src/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // ✅ macOS 포함 모든 플랫폼에서 필수
  );

  // Provider 경고 끄기 (필요 시)
  Provider.debugCheckInvalidValueType = null;

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => const Uuid()),
      ],
      // ⛳️ 여기 **무조건** StockApp (MaterialApp 포함)
      child: const StockApp(),
    ),
  );

  // ✅ 로그인 세션 디버깅용
  FirebaseAuth.instance.authStateChanges().listen((user) {
    debugPrint('🔥 FirebaseAuth user: ${user?.uid}');
  });
}
