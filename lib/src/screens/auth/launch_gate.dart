import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_auto_backup_service.dart';
import '../../services/entitlement_service.dart';
import '../../ui/intro_loading_screen.dart';
import '../../ui/intro_timing.dart';
import 'start_screen.dart';

/// 앱 시작 시 로그인 상태를 점검하고,
/// - 로그인 되어 있으면 child로 진입
/// - 아니면 구글 로그인 화면을 보여주는 게이트 위젯
class LaunchGate extends StatefulWidget {
  final WidgetBuilder signedInBuilder; // 로그인 후 보여줄 화면

  const LaunchGate({super.key, required this.signedInBuilder});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  bool _booting = true;
  bool _showAuthForm = false;
  bool _emailModeIsSignUp = false;
  bool _authWorking = false;
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final startedAt = DateTime.now();
    final auth = context.read<AuthService>();
    try {
      // 기존 로그인 세션이 있거나, 조용한 로그인 시도
      await auth.trySilentSignIn();
    } catch (e) {
      // 실패해도 로그인 화면으로 진행
      debugPrint('[LaunchGate] silent sign-in failed: $e');
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < introMinimumDuration) {
        await Future<void>.delayed(introMinimumDuration - elapsed);
      }
      if (mounted) setState(() => _booting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const IntroLoadingScreen();
    }

    return StreamBuilder(
      stream: context.read<AuthService>().userStream,
      initialData: context.read<AuthService>().currentUser,
      builder: (context, snapshot) {
        // On Windows, older FlutterFire builds can occasionally deliver the
        // auth-state event on the wrong platform thread. FirebaseAuth has
        // already updated currentUser at this point, so prefer that value when
        // rebuilding after a completed sign-in.
        final user = context.read<AuthService>().currentUser ?? snapshot.data;

        // 로그인된 상태라면 메인으로 진입
        if (user != null) {
          return _CloudAutoBackupRunner(
            child: widget.signedInBuilder(context),
          );
        }

        if (!_showAuthForm) {
          return StartScreen(
            onStart: () => setState(() => _showAuthForm = true),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: _LoginPanel(
                          emailFormKey: _emailFormKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          isSignUp: _emailModeIsSignUp,
                          working: _authWorking,
                          onToggleMode: () {
                            setState(
                              () => _emailModeIsSignUp = !_emailModeIsSignUp,
                            );
                          },
                          onEmailSubmit: _submitEmailAuth,
                          onGoogleSignIn: _signInWithGoogle,
                          onPasswordReset: _sendPasswordReset,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitEmailAuth() async {
    if (_authWorking) return;
    final form = _emailFormKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _authWorking = true);
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_emailModeIsSignUp) {
        await auth.createUserWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await auth.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_emailModeIsSignUp ? '회원가입 완료' : '로그인 완료')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_emailModeIsSignUp ? '회원가입 실패: $e' : '로그인 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _authWorking = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_authWorking) return;
    setState(() => _authWorking = true);
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.signInWithGoogle();
      if (!mounted) return;
      if (auth.uid != null) {
        // Force the gate to re-read FirebaseAuth.currentUser instead of
        // waiting only for the Windows auth-state platform-channel event.
        setState(() {});
        messenger.showSnackBar(
          const SnackBar(content: Text('Google 로그인 완료')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Google 로그인 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _authWorking = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_authWorking) return;
    final email = _emailController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (email.isEmpty || !email.contains('@')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('비밀번호 재설정 이메일을 입력해 주세요.')),
      );
      return;
    }

    setState(() => _authWorking = true);
    try {
      await context.read<AuthService>().sendPasswordResetEmail(email);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('비밀번호 재설정 이메일을 보냈습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('비밀번호 재설정 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _authWorking = false);
    }
  }
}

class _LoginPanel extends StatelessWidget {
  final GlobalKey<FormState> emailFormKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isSignUp;
  final bool working;
  final VoidCallback onToggleMode;
  final VoidCallback onEmailSubmit;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onPasswordReset;

  const _LoginPanel({
    required this.emailFormKey,
    required this.emailController,
    required this.passwordController,
    required this.isSignUp,
    required this.working,
    required this.onToggleMode,
    required this.onEmailSubmit,
    required this.onGoogleSignIn,
    required this.onPasswordReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              IntroLoadingScreen.puppyAsset,
              width: 132,
              height: 132,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isSignUp ? '찰스톡 시작하기' : '찰스톡 로그인',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '이메일 또는 Google 계정으로 로그인하고 백업과 동기화를 사용할 수 있습니다.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Form(
          key: emailFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: emailController,
                enabled: !working,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return '이메일을 입력해 주세요.';
                  if (!email.contains('@')) return '올바른 이메일을 입력해 주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                enabled: !working,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => onEmailSubmit(),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) return '비밀번호를 입력해 주세요.';
                  if (password.length < 6) {
                    return '비밀번호는 6자 이상이어야 합니다.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            icon: working
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mail_outline),
            label: Text(isSignUp ? '이메일로 회원가입' : '이메일로 로그인'),
            onPressed: working ? null : onEmailSubmit,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: working ? null : onToggleMode,
          child: Text(isSignUp ? '이미 계정이 있나요? 로그인' : '계정이 없나요? 회원가입'),
        ),
        if (!isSignUp)
          TextButton(
            onPressed: working ? null : onPasswordReset,
            child: const Text('비밀번호 재설정'),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('또는', style: theme.textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Google로 로그인'),
            onPressed: working ? null : onGoogleSignIn,
          ),
        ),
      ],
    );
  }
}

class _CloudAutoBackupRunner extends StatefulWidget {
  final Widget child;

  const _CloudAutoBackupRunner({required this.child});

  @override
  State<_CloudAutoBackupRunner> createState() => _CloudAutoBackupRunnerState();
}

class _CloudAutoBackupRunnerState extends State<_CloudAutoBackupRunner>
    with WidgetsBindingObserver {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeRun();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRun();
    }
  }

  Future<void> _maybeRun() async {
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null || _running) return;

    _running = true;
    try {
      final service = CloudAutoBackupService(
        authService: auth,
        entitlementService: context.read<EntitlementService>(),
      );
      final result = await service.runIfDue();
      const verboseCloudBackupLogs =
          bool.fromEnvironment('CHALSTOCK_VERBOSE_CLOUD_BACKUP_LOGS');
      if (verboseCloudBackupLogs) {
        debugPrint('CloudAutoBackup startup: ${result.message}');
      }
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
