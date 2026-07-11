import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _gsi = GoogleSignIn();

  Stream<User?> get userStream => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  String? get uid => currentUser?.uid;

  /// 기존 로그인 유지 or 조용한 로그인 (앱 시작 시 자동 시도)
  Future<bool> trySilentSignIn() async {
    if (_auth.currentUser != null) return true;
    if (!_supportsGoogleSignIn) return false;
    final googleUser = await _gsi.signInSilently();
    if (googleUser == null) return false;

    final gAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    await _auth.signInWithCredential(cred);
    return true;
  }

  /// 명시적 구글 로그인 (버튼 누를 때)
  Future<void> signInWithGoogle() async {
    if (!_supportsGoogleSignIn) {
      throw const GoogleSignInUnsupportedException();
    }
    final googleUser = await _gsi.signIn();
    if (googleUser == null) return; // 취소

    final gAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    await _auth.signInWithCredential(cred);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> createUserWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    if (_supportsGoogleSignIn) {
      await _gsi.signOut();
    }
    await _auth.signOut();
  }

  bool get _supportsGoogleSignIn {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }
}

class GoogleSignInUnsupportedException implements Exception {
  const GoogleSignInUnsupportedException();

  @override
  String toString() => 'Windows 데스크탑에서는 이메일 로그인을 사용해 주세요.';
}
