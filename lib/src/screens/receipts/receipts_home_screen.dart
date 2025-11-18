import 'package:flutter/material.dart';

class ReceiptsHomeScreen extends StatelessWidget {
  const ReceiptsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('영수증 관리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.post_add),
            title: const Text('거래명세서 등록'),
            subtitle: const Text('사진/카메라로 업로드해서 아이템 자동 추출'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/receipts/new'),
          ),
          const Divider(),
          // TODO: 등록된 영수증 리스트(필요 시)
        ],
      ),
    );
  }
}
