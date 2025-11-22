import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthService>();
    try {
      // 기존 로그인 세션이 있거나, 조용한 로그인 시도
      await auth.trySilentSignIn();
    } catch (e) {
      // 실패해도 로그인 화면으로 진행
      debugPrint('[LaunchGate] silent sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _booting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder(
      stream: context.read<AuthService>().userStream,
      builder: (context, snapshot) {
        final user = context.read<AuthService>().currentUser;

        // 로그인된 상태라면 메인으로 진입
        if (user != null) {
          return widget.signedInBuilder(context);
        }

        // 로그인 필요 화면
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FlutterLogo(size: 64),
                      const SizedBox(height: 16),
                      Text(
                        '로그인이 필요합니다',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Google 계정으로 로그인하고 동기화를 시작하세요.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Google로 로그인'),
                          onPressed: () async {
                            final auth = context.read<AuthService>();
                            try {
                              await auth.signInWithGoogle();
                              if (!mounted) return;
                              final uid = auth.uid;
                              if (uid != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('로그인 완료: $uid')),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                  Text('로그인 실패: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
