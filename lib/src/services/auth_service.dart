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
    final googleUser = await _gsi.signIn();
    if (googleUser == null) return; // 취소

    final gAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    await _auth.signInWithCredential(cred);
  }

  Future<void> signOut() async {
    await _gsi.signOut();
    await _auth.signOut();
  }
}
