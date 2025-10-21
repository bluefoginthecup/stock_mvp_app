import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/bom.dart';
import '../../services/bom_service.dart';
import '../../services/shortage_service.dart';

class ShortageTestScreen extends StatefulWidget {
  const ShortageTestScreen({super.key});

  @override
  State<ShortageTestScreen> createState() => _ShortageTestScreenState();
}

class _ShortageTestScreenState extends State<ShortageTestScreen> {
  final _finishedIdC = TextEditingController(text: 'it-finished-001');
  final _qtyC = TextEditingController(text: '10');
  String _log = '';
  Map<String, double> _semi = {};
  Map<String, double> _raw = {};
  Map<String, double> _sub = {};

  Future<void> _runTest() async {
    final repo = context.read<ItemRepo>();
    final bom = BomService(repo);
    final shortage = ShortageService(repo: repo, bom: bom);

    final finishedId = _finishedIdC.text.trim();
    final qty = int.tryParse(_qtyC.text) ?? 1;
    final result = await shortage.compute(finishedId: finishedId, orderQty: qty);

    setState(() {
      _semi = result.semiShortage;
      _raw = result.rawShortage;
      _sub = result.subShortage;
      _log = '''
==== shortage result ====
semi: $_semi
raw : $_raw
sub : $_sub
=========================
''';
    });

    // 콘솔 로그도 같이 출력
    // ignore: avoid_print
    print(_log);
  }

  Widget _buildMapView(String title, Map<String, double> map) {
    if (map.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final e in map.entries)
              Text('${e.key}  →  부족 ${e.value.toStringAsFixed(1)}개'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('부족 계산 테스트')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _finishedIdC,
              decoration: const InputDecoration(labelText: '완제품 ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qtyC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '주문 수량'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _runTest,
              icon: const Icon(Icons.calculate),
              label: const Text('부족 계산 실행'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMapView('세미완제품 부족', _semi),
                    _buildMapView('원자재 부족', _raw),
                    _buildMapView('부자재 부족', _sub),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
