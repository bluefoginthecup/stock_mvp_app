// lib/src/screens/shortage/shortage_calc_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:provider/provider.dart';

import '../../repos/repo_interfaces.dart';
import '../../services/shortage_service.dart';

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


class DemandRow {
  final String itemId;
  final int qty;
  DemandRow(this.itemId, this.qty);
}

class FinishedResult {
  final DemandRow demand;
  final Shortage2L res;
  FinishedResult({required this.demand, required this.res});
}

class ShortageCalcScreen extends StatefulWidget {
  const ShortageCalcScreen({super.key});

  @override
  State<ShortageCalcScreen> createState() => _ShortageCalcScreenState();
}

class _ShortageCalcScreenState extends State<ShortageCalcScreen> {
  bool _loading = false;
  String? _error;

  String? _fileName;
  List<DemandRow> _rows = [];

  // 결과(품목별)
  List<FinishedResult> finishedResults = [];


    // itemId -> name 캐시 (한 번에 로드해서 UI에서 즉시 lookup)
    Map<String, String> itemNameCache = {};


  // 전체 합산(요약용)
  Map<String, double> semiShortTotal = {};
  Map<String, double> rawShortTotal = {};
  Map<String, double> subShortTotal = {};
  double finishedShortTotal = 0;

  // CSV에 들어왔지만 DB에 없는 item_id들(검증용)
  List<String> unknownItemIds = [];

  // ---------------- Helpers ----------------

  List<DemandRow> _aggregateByItemId(List<DemandRow> input) {
    final m = <String, int>{};
    for (final r in input) {
      final id = r.itemId.trim();
      if (id.isEmpty) continue;
      if (r.qty <= 0) continue;
      m.update(id, (x) => x + r.qty, ifAbsent: () => r.qty);
    }
    final out = m.entries.map((e) => DemandRow(e.key, e.value)).toList()
      ..sort((a, b) => a.itemId.compareTo(b.itemId));
    return out;
  }

  Map<String, double> _mergeMap(Map<String, double> a, Map<String, double> b) {
    final r = <String, double>{}..addAll(a);
    b.forEach((k, v) => r.update(k, (x) => x + v, ifAbsent: () => v));
    return r;
  }

  int _findHeaderIndex(List<dynamic> headerRow, List<String> candidates) {
    final h = headerRow.map((e) => e.toString().trim().toLowerCase()).toList();
    for (final c in candidates) {
      final idx = h.indexOf(c.toLowerCase());
      if (idx >= 0) return idx;
    }
    return -1;
  }

  String _fmt(double v) => (v % 1 == 0) ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

    String _nameOf(String id) => itemNameCache[id] ?? id;

    Future<void> _loadItemNames(Set<String> ids) async {
        final repo = context.read<ItemRepo>();
        final m = <String, String>{};

        for (final id in ids) {
          try {
            final name = await repo.nameOf(id); // Future<String?>
            if (name != null && name.trim().isNotEmpty) {
              m[id] = name;
            }
          } catch (_) {
            // 실패해도 id로 fallback
          }
        }

        if (!mounted) return;
        setState(() => itemNameCache.addAll(m));
      }


  Widget _shortageLines(Map<String, double> m, {int limit = 50}) {
    if (m.isEmpty) return const Text('부족 없음');

    final entries = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.take(limit).map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text('${_nameOf(e.key)}  부족 ${_fmt(e.value)}'),
        );
      }).toList(),
    );
  }

  // ---------------- Actions ----------------

  Future<void> _pickAndParseCsv() async {
    setState(() {
      _loading = true;
      _error = null;
      _fileName = null;
      _rows = [];

      itemNameCache = {};
      finishedResults = [];
      semiShortTotal = {};
      rawShortTotal = {};
      subShortTotal = {};
      finishedShortTotal = 0;

      unknownItemIds = [];
    });

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );

      if (res == null) {
        setState(() => _loading = false);
        return;
      }

      final f = res.files.single;
      _fileName = f.name;

      final bytes = f.bytes;
      if (bytes == null) {
        throw StateError('파일 바이트를 읽을 수 없습니다. (withData: true 확인)');
      }

      // UTF-8 디코딩 (BOM 제거)
      var text = utf8.decode(bytes);
      if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
        text = text.substring(1);
      }

      // csv 파싱
      final table = const CsvToListConverter(eol: '\n').convert(text);
      if (table.isEmpty) throw StateError('CSV가 비어있습니다.');

      final header = table.first;
      final itemIdIdx = _findHeaderIndex(header, const ['item_id', 'itemid', 'id']);
      final qtyIdx = _findHeaderIndex(header, const ['qty', 'quantity']);

      if (itemIdIdx < 0 || qtyIdx < 0) {
        throw StateError('헤더에 item_id, qty 컬럼이 필요합니다. 예: item_id,qty');
      }

      final parsed = <DemandRow>[];
      for (int i = 1; i < table.length; i++) {
        final row = table[i];
        if (row.length <= itemIdIdx || row.length <= qtyIdx) continue;

        final itemId = row[itemIdIdx].toString().trim();
        final qtyRaw = row[qtyIdx];

        final qty = (qtyRaw is num)
            ? qtyRaw.toInt()
            : int.tryParse(qtyRaw.toString().trim()) ?? 0;

        if (itemId.isEmpty || qty <= 0) continue;
        parsed.add(DemandRow(itemId, qty));
      }

      setState(() {
        _rows = _aggregateByItemId(parsed);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _computeShortage() async {
    if (_rows.isEmpty) {
      setState(() => _error = '먼저 item_id,qty CSV를 업로드하세요.');
      return;
    }

    final itemRepo = context.read<ItemRepo>();
    final shortage = context.read<ShortageService>();

    setState(() {
      _loading = true;
      _error = null;

      itemNameCache = {};

      finishedResults = [];
      semiShortTotal = {};
      rawShortTotal = {};
      subShortTotal = {};
      finishedShortTotal = 0;

      unknownItemIds = [];
    });

    try {
      final perItem = <FinishedResult>[];
      Map<String, double> semiT = {};
      Map<String, double> rawT = {};
      Map<String, double> subT = {};
      double finT = 0;
      final unknown = <String>[];

      // item 존재 검증(가능하면)
      Future<bool> exists(String id) async {
        final dyn = itemRepo as dynamic;
        try {
          if (dyn.getItem is Function) {
            final v = dyn.getItem(id);
            if (v is Future) {
              final it = await v;
              return it != null;
            } else {
              return v != null;
            }
          }
        } catch (_) {}
        // getItem이 없거나 실패하면 "존재한다고 가정"
        return true;
      }

      for (final r in _rows) {
        final ok = await exists(r.itemId);
        if (!ok) {
          unknown.add(r.itemId);
          continue;
        }

        final res = shortage.compute(finishedId: r.itemId, orderQty: r.qty);

        perItem.add(FinishedResult(demand: r, res: res));

        // ✅ 요약 합산
        finT += res.finishedShortage;
        semiT = _mergeMap(semiT, res.semiShortage);
        rawT = _mergeMap(rawT, res.rawShortage);
        subT = _mergeMap(subT, res.subShortage);
      }

      // 보기 좋게: 완제품 부족 큰 순 → 주문량 큰 순
      perItem.sort((a, b) {
        final c1 = b.res.finishedShortage.compareTo(a.res.finishedShortage);
        if (c1 != 0) return c1;
        return b.demand.qty.compareTo(a.demand.qty);
      });

    // ✅ 화면에 표시할 모든 itemId 모아서 이름 캐싱
          final ids = <String>{};
          for (final fr in perItem) {
            ids.add(fr.demand.itemId); // 완제품
            fr.res.semiShortage.keys.forEach(ids.add);
            fr.res.rawShortage.keys.forEach(ids.add);
            fr.res.subShortage.keys.forEach(ids.add);
          }
           //(원하면 need까지도 이름 표시하게 포함 가능)
           for (final fr in perItem) {
            fr.res.semiNeed.keys.forEach(ids.add);
             fr.res.rawNeed.keys.forEach(ids.add);
            fr.res.subNeed.keys.forEach(ids.add);
           }

          await _loadItemNames(ids);

      setState(() {
        finishedResults = perItem;
        semiShortTotal = semiT;
        rawShortTotal = rawT;
        subShortTotal = subT;
        finishedShortTotal = finT;
        unknownItemIds = unknown;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ---------------- UI ----------------

  Widget _summaryCard() {
    if (_loading) return const SizedBox.shrink();
    if (finishedResults.isEmpty && unknownItemIds.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('요약', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('완제품 부족 합계: ${_fmt(finishedShortTotal)}'),
            const SizedBox(height: 8),
            Text('반제품 부족 종류: ${semiShortTotal.length}'),
            Text('원자재 부족 종류: ${rawShortTotal.length}'),
            Text('부자재 부족 종류: ${subShortTotal.length}'),
          ],
        ),
      ),
    );
  }

  Widget _finishedCard(FinishedResult fr) {
    final r = fr.res;
    final d = fr.demand;

    final bomEmpty = r.semiNeed.isEmpty && r.rawNeed.isEmpty && r.subNeed.isEmpty;

    final hasAnyShort =
        r.finishedShortage > 0 ||
            r.semiShortage.isNotEmpty ||
            r.rawShortage.isNotEmpty ||
            r.subShortage.isNotEmpty;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        title: Text(
                    _nameOf(d.itemId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
        subtitle: Text('주문 ${d.qty} · 현재고 ${_fmt(r.finishedStock)} · 부족 ${_fmt(r.finishedShortage)}'),

        trailing: hasAnyShort
            ? const Icon(Icons.warning_amber_rounded)
            : const Icon(Icons.check_circle_outline),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Shortage2L에 finishedStock을 추가한 경우 아래를 해제해서 사용
                Text('완제품 현재고: ${_fmt(r.finishedStock)}'),
                Text('완제품 부족: ${_fmt(r.finishedShortage)}'),

                if (bomEmpty && r.finishedShortage > 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '⚠️ BOM 미등록(자재 계산 불가)',
                    style: TextStyle(color: Colors.red),
                  ),
                ],

                const SizedBox(height: 10),
                const Text('반제품 부족', style: TextStyle(fontWeight: FontWeight.bold)),
                _shortageLines(r.semiShortage),

                const SizedBox(height: 10),
                const Text('원자재 부족', style: TextStyle(fontWeight: FontWeight.bold)),
                _shortageLines(r.rawShortage),

                const SizedBox(height: 10),
                const Text('부자재 부족', style: TextStyle(fontWeight: FontWeight.bold)),
                _shortageLines(r.subShortage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCompute = !_loading && _rows.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('부족분 계산')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_fileName != null) Text('파일: $_fileName'),
            Text('업로드 라인(합산 후): ${_rows.length}'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _pickAndParseCsv,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('CSV 업로드'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canCompute ? _computeShortage : null,
                    icon: const Icon(Icons.calculate),
                    label: const Text('부족분 계산'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportDb,
                    icon: const Icon(Icons.calculate),
                    label: const Text('db추출'),
                  ),
                ),

              ],
            ),

            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _summaryCard(),

                  if (unknownItemIds.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '미등록 item_id (계산 제외)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...unknownItemIds.map((s) => Text(s)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  ...finishedResults.map(_finishedCard),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _exportDb() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final dbFile = File(p.join(dir.path, 'stockapp.db'));

      if (!await dbFile.exists()) {
        debugPrint('DB 파일이 존재하지 않음: ${dbFile.path}');
        // 디렉토리 내용도 찍어보기
        for (final f in dir.listSync()) {
          debugPrint(' - ${f.path}');
        }
        return;
      }

      debugPrint('DB PATH: ${dbFile.path}');

      // WAL 모드면 -wal / -shm도 같이 내보내는 게 안전함
      final wal = File('${dbFile.path}-wal');
      final shm = File('${dbFile.path}-shm');

      final files = <XFile>[XFile(dbFile.path)];
      if (await wal.exists()) files.add(XFile(wal.path));
      if (await shm.exists()) files.add(XFile(shm.path));

      await Share.shareXFiles(files, text: 'stockapp drift db');
    } catch (e) {
      debugPrint('DB export error: $e');
    }
  }


}
