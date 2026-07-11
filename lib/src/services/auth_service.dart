import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'windows_google_oauth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _gsi = GoogleSignIn();
  final _windowsGoogleOAuth = WindowsGoogleOAuth();
  final _userController = StreamController<User?>.broadcast();
  late final StreamSubscription<User?> _nativeAuthSubscription;
  User? _currentUser;

  AuthService() {
    _currentUser = _auth.currentUser;
    _nativeAuthSubscription = _auth.authStateChanges().listen(_publishUser);
  }

  Stream<User?> get userStream => _userController.stream;
  User? get currentUser => _currentUser ?? _auth.currentUser;
  String? get uid => currentUser?.uid;

  void _publishUser(User? user) {
    _currentUser = user;
    if (!_userController.isClosed) _userController.add(user);
  }

  /// 기존 로그인 유지 or 조용한 로그인 (앱 시작 시 자동 시도)
  Future<bool> trySilentSignIn() async {
    if (_auth.currentUser != null) return true;
    if (!_supportsNativeGoogleSignIn) return false;
    final googleUser = await _gsi.signInSilently();
    if (googleUser == null) return false;

    final gAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    final signedIn = await _auth.signInWithCredential(cred);
    _publishUser(signedIn.user);
    return true;
  }

  /// 명시적 구글 로그인 (버튼 누를 때)
  Future<void> signInWithGoogle() async {
    if (Platform.isWindows) {
      final result = await _windowsGoogleOAuth.signIn();
      final credential = GoogleAuthProvider.credential(
        accessToken: result.accessToken,
        idToken: result.idToken,
      );
      final signedIn = await _auth.signInWithCredential(credential);
      _publishUser(signedIn.user);
      return;
    }
    if (!_supportsNativeGoogleSignIn) {
      throw const GoogleSignInUnsupportedException();
    }
    final googleUser = await _gsi.signIn();
    if (googleUser == null) return; // 취소

    final gAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    final signedIn = await _auth.signInWithCredential(cred);
    _publishUser(signedIn.user);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final signedIn = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _publishUser(signedIn.user);
  }

  Future<void> createUserWithEmail({
    required String email,
    required String password,
  }) async {
    final signedIn = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _publishUser(signedIn.user);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    if (_supportsNativeGoogleSignIn) {
      await _gsi.signOut();
    }
    await _auth.signOut();
    _publishUser(null);
  }

  Future<void> dispose() async {
    await _nativeAuthSubscription.cancel();
    await _userController.close();
  }

  bool get _supportsNativeGoogleSignIn {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }
}

class GoogleSignInUnsupportedException implements Exception {
  const GoogleSignInUnsupportedException();

  @override
  String toString() => 'Windows 데스크탑에서는 이메일 로그인을 사용해 주세요.';
}
