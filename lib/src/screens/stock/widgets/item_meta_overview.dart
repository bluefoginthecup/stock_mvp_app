import 'package:flutter/material.dart';
import '../../../models/item.dart';

class ItemMetaOverview extends StatelessWidget {
  final Item item;
  const ItemMetaOverview({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // attrs / stockHints 보기 좋게 문자열화
    String _mapToPretty(Map? m) {
      if (m == null || m.isEmpty) return '-';
      final entries = m.entries.map((e) => '• ${e.key}: ${e.value}').join('\n');
      return entries;
    }

    String _stockHintsPretty(StockHints? h) {
      if (h == null) return '-';
      final rows = <String>[];
      if (h.unitIn != null) rows.add('• unit_in: ${h.unitIn}');
      if (h.unitOut != null) rows.add('• unit_out: ${h.unitOut}');
      if (h.conversionRate != null) rows.add('• conversion_rate: ${h.conversionRate}');
      if (h.qty != null) rows.add('• qty: ${h.qty}');
      if (h.usableQtyM != null) rows.add('• usable_qty_m: ${h.usableQtyM}');
      return rows.isEmpty ? '-' : rows.join('\n');
    }

    Widget kv(String k, String v, {bool mono = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(k, style: text.bodyMedium)),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                v.isEmpty ? '-' : v,
                style: mono ? text.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]) : text.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('아이템 메타(모든 필드)', style: text.titleSmall),
            const SizedBox(height: 8),

            // 1) 식별/표시
            kv('id', item.id, mono: true),
            kv('name', item.name),
            kv('displayName', item.displayName ?? '-'),
            kv('sku', item.sku, mono: true),

            const SizedBox(height: 8),
            // 2) 단위/카테고리
            kv('unit', item.unit),
            kv('folder', item.folder),
            kv('subfolder', item.subfolder ?? '-'),
            kv('subsubfolder', item.subsubfolder ?? '-'),

             const SizedBox(height: 8),
             // 2-1) 공급처
             kv('공급처', item.supplierName ?? '-'),


            const SizedBox(height: 8),
            // 3) 재고/임계치
            kv('minQty', item.minQty.toString(), mono: true),
            kv('qty', item.qty.toString(), mono: true),

            const SizedBox(height: 8),
            // 4) 분류/속성
            kv('kind', item.kind ?? '-'),
            kv('attrs', _mapToPretty(item.attrs)),

            const SizedBox(height: 8),
            // 5) 하이브리드 환산
            kv('unit_in', item.unitIn),
            kv('unit_out', item.unitOut),
            kv('conversion_rate', item.conversionRate.toString(), mono: true),
            kv('conversion_mode', item.conversionMode),

            const SizedBox(height: 8),
            // 6) 레거시 폴백 메타
            kv('stockHints', _stockHintsPretty(item.stockHints)),
          ],
        ),
      ),
    );
  }
}
