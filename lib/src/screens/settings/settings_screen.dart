import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stockapp_mvp/src/services/seed_importer.dart'; // ⬅️ 이미 있다면 이걸, 없다면 아래 2) 코드 추가


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')), // TODO: i18n 키 있으면 교체
      body: ListView(
        children: [
          const _SectionHeader('일반'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('언어 설정'), // TODO: i18n 키 있으면 교체
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/settings/language'),
          ),
        const _SectionHeader('데이터'),
                  ListTile(
                        leading: const Icon(Icons.download_for_offline),
                    title: const Text('시드 임포트'),
                subtitle: const Text('assets/seeds/2025-10-26의 JSON을 불러옵니다'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('시드 임포트'),
                      content: const Text('현재 DB에 시드 데이터를 가져올까요? 기존 데이터와 병합/덮어쓰기 로직은 SeedImporter에 따릅니다.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('가져오기')),
                      ],
                    ),
                  );
                  if (ok != true) return;

                  // 진행중 다이얼로그
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );
                  String msg = '시드 임포트 완료';
                  try {
                    // 👉 실제 임포트 실행
                    await UnifiedSeedImporter.run(context);
                  } catch (e) {
                    msg = '임포트 실패: $e';
                  } finally {
                    Navigator.of(context, rootNavigator: true).pop(); // progress 닫기
                  }
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                },
              ),
          // ─────────────────────────────────────────────────────────
          // 향후 확장 예시
          // ListTile(
          //   leading: const Icon(Icons.notifications),
          //   title: const Text('알림 설정'),
          //   trailing: const Icon(Icons.chevron_right),
          //   onTap: () => Navigator.pushNamed(context, '/settings/notifications'),
          // ),
          // ListTile(
          //   leading: const Icon(Icons.palette_outlined),
          //   title: const Text('테마 / 디자인'),
          //   trailing: const Icon(Icons.chevron_right),
          //   onTap: () {},
          // ),
          // ListTile(
          //   leading: const Icon(Icons.cloud_sync_outlined),
          //   title: const Text('데이터 / 백업'),
          //   trailing: const Icon(Icons.chevron_right),
          //   onTap: () {},
          // ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text, style: style?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
