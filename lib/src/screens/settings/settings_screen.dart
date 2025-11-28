import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stockapp_mvp/src/services/seed_importer.dart';
// ⬆️ 여기에는 enum SeedPart와 UnifiedSeedImporter가 이미 포함되어 있어야 합니다.

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 공통 실행 함수: 진행중 스피너 + 에러/성공 스낵바
    Future<void> runWithSpinner(
        Future<void> Function() job, {
          String okMsg = '완료했습니다.',
        }) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      String msg = okMsg;
      try {
        await job();
      } catch (e) {
        msg = '실패: $e';
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // progress 닫기
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    }

    // 개별 파트 임포트 실행기
    Future<void> runPart(SeedPart part, String okMsg) async {
      await runWithSpinner(
            () => UnifiedSeedImporter.runPart(
          context,
          part: part,
          // 필요 시 에셋 경로 커스터마이즈 가능:
          // itemsAssetPath: 'assets/seeds/2025-10-26/items.json',
          // foldersAssetPath: 'assets/seeds/2025-10-26/folders.json',
          // bomAssetPath: 'assets/seeds/2025-10-26/bom.json',
          // lotsAssetPath: 'assets/seeds/2025-10-26/lots.json',
          clearBefore: false,
          verbose: true,
        ),
        okMsg: okMsg,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('설정')), // TODO: i18n 키가 있으면 교체
      body: ListView(
        children: [
          const _SectionHeader('일반'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('언어 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/settings/language'),
          ),

          const _SectionHeader('데이터'),

          // ───────────────── 전체 임포트 (기존)
          ListTile(
            leading: const Icon(Icons.download_for_offline),
            title: const Text('시드 임포트 (전체)'),
            subtitle: const Text('assets/seeds/2025-10-26의 JSON을 한 번에 불러옵니다'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('시드 임포트(전체)'),
                  content: const Text('현재 DB에 전체 시드 데이터를 가져올까요?\n기존 데이터와 병합/덮어쓰기는 SeedImporter 로직을 따릅니다.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('가져오기')),
                  ],
                ),
              );
              if (ok != true) return;

              await runWithSpinner(
                    () => UnifiedSeedImporter.run(context, clearBefore: false, verbose: true),
                okMsg: '전체 임포트 완료',
              );
            },
          ),

          // ───────────────── 개별 임포트 (신규)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('개별 임포트', style: TextStyle(fontWeight: FontWeight.w600)),
          ),

          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('폴더만 임포트'),
            subtitle: const Text('folders.json만 반영 (트리 리빌드 포함)'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('폴더만 임포트'),
                  content: const Text('folders.json만 임포트합니다. 계속할까요?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('가져오기')),
                  ],
                ),
              );
              if (ok != true) return;
              await runPart(SeedPart.folders, '폴더 임포트 완료');
            },
          ),

          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('아이템만 임포트'),
            subtitle: const Text('items.json만 반영 (폴더 경로 자동 매칭 시도)'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('아이템만 임포트'),
                  content: const Text('items.json만 임포트합니다. 계속할까요?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('가져오기')),
                  ],
                ),
              );
              if (ok != true) return;
              await runPart(SeedPart.items, '아이템 임포트 완료');
            },
          ),

          ListTile(
            leading: const Icon(Icons.account_tree),
            title: const Text('BOM만 임포트'),
            subtitle: const Text('bom.json만 반영 (BOM 스냅샷/인덱스 리프레시)'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('BOM만 임포트'),
                  content: const Text('bom.json만 임포트합니다. 계속할까요?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('가져오기')),
                  ],
                ),
              );
              if (ok != true) return;
              await runPart(SeedPart.bom, 'BOM 임포트 완료');
            },
          ),

          ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: const Text('로트만 임포트'),
            subtitle: const Text('lots.json만 반영 (트랜잭션/스냅샷 갱신)'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('로트만 임포트'),
                  content: const Text('lots.json만 임포트합니다. 계속할까요?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('가져오기')),
                  ],
                ),
              );
              if (ok != true) return;
              await runPart(SeedPart.lots, '로트 임포트 완료');
            },
          ),
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
