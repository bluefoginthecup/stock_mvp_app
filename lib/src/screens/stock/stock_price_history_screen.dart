import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../db/app_database.dart';

class StockPriceHistoryScreen extends StatefulWidget {
  final String itemId;
  final String itemName;

  const StockPriceHistoryScreen({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<StockPriceHistoryScreen> createState() =>
      _StockPriceHistoryScreenState();
}

class _StockPriceHistoryScreenState extends State<StockPriceHistoryScreen> {
  String _kind = 'purchase';
  bool _showChart = true;

  Stream<List<_PriceHistoryEntry>> _watchRows(AppDatabase db) {
    final q = db.select(db.itemPriceHistories)
      ..where((t) => t.itemId.equals(widget.itemId))
      ..where((t) => t.kind.equals(_kind))
      ..orderBy([(t) => OrderingTerm.asc(t.changedAt)]);
    return q.watch().map(
          (rows) => rows
              .map(
                (row) => _PriceHistoryEntry(
                  changedAt: row.changedAt,
                  oldPrice: row.oldPrice,
                  newPrice: row.newPrice,
                  source: row.source,
                ),
              )
              .toList(),
        );
  }

  String get _kindLabel => _kind == 'purchase' ? '입고가' : '출고가';

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.itemName} 가격 추이'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'purchase',
                      label: Text('입고가'),
                      icon: Icon(Icons.download),
                    ),
                    ButtonSegment(
                      value: 'sale',
                      label: Text('출고가'),
                      icon: Icon(Icons.upload),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (values) {
                    setState(() => _kind = values.first);
                  },
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.show_chart),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.table_rows),
                    ),
                  ],
                  selected: {_showChart},
                  onSelectionChanged: (values) {
                    setState(() => _showChart = values.first);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<_PriceHistoryEntry>>(
              stream: _watchRows(db),
              builder: (context, snap) {
                final rows = snap.data ?? const <_PriceHistoryEntry>[];
                if (snap.connectionState == ConnectionState.waiting &&
                    rows.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (rows.isEmpty) {
                  return Center(
                    child: Text('아직 $_kindLabel 변경 이력이 없습니다.'),
                  );
                }
                return _showChart
                    ? _PriceChartView(rows: rows, kindLabel: _kindLabel)
                    : _PriceTableView(rows: rows);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceHistoryEntry {
  final String changedAt;
  final double? oldPrice;
  final double? newPrice;
  final String source;

  const _PriceHistoryEntry({
    required this.changedAt,
    required this.oldPrice,
    required this.newPrice,
    required this.source,
  });
}

class _PriceChartView extends StatelessWidget {
  final List<_PriceHistoryEntry> rows;
  final String kindLabel;

  const _PriceChartView({
    required this.rows,
    required this.kindLabel,
  });

  @override
  Widget build(BuildContext context) {
    final points = rows.where((row) => row.newPrice != null).toList();
    if (points.isEmpty) {
      return Center(child: Text('$kindLabel 가격 삭제 이력만 있습니다.'));
    }
    final latest = points.last;
    final firstPrice = points.first.newPrice ?? 0;
    final latestPrice = latest.newPrice ?? 0;
    final delta = latestPrice - firstPrice;
    final up = delta >= 0;
    final color = up ? Colors.green : Colors.red;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          _formatMoney(latestPrice),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${up ? '+' : ''}${_formatMoney(delta)} · ${_formatDate(latest.changedAt)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 260,
          child: CustomPaint(
            painter: _PriceLineChartPainter(
              rows: points,
              color: color,
              textStyle: Theme.of(context).textTheme.bodySmall ??
                  const TextStyle(fontSize: 12),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '총 ${rows.length}건의 변경 이력',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PriceLineChartPainter extends CustomPainter {
  final List<_PriceHistoryEntry> rows;
  final Color color;
  final TextStyle textStyle;

  _PriceLineChartPainter({
    required this.rows,
    required this.color,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 58.0;
    const top = 16.0;
    const right = 16.0;
    const bottom = 36.0;
    final chart =
        Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    if (chart.width <= 0 || chart.height <= 0) return;

    final prices = rows.map((row) => row.newPrice ?? 0).toList();
    var minPrice = prices.reduce(math.min);
    var maxPrice = prices.reduce(math.max);
    if ((maxPrice - minPrice).abs() < 0.0001) {
      maxPrice += 1;
      minPrice = math.max(0, minPrice - 1);
    }
    final pad = (maxPrice - minPrice) * 0.12;
    minPrice = math.max(0, minPrice - pad);
    maxPrice += pad;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.20),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(chart);
    final dotPaint = Paint()..color = color;

    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      axisPaint,
    );

    Offset pointAt(int index) {
      final x = rows.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (rows.length - 1);
      final price = rows[index].newPrice ?? 0;
      final normalized = (price - minPrice) / (maxPrice - minPrice);
      final y = chart.bottom - chart.height * normalized;
      return Offset(x, y);
    }

    final path = Path();
    final area = Path();
    for (var i = 0; i < rows.length; i++) {
      final p = pointAt(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        area.moveTo(p.dx, chart.bottom);
        area.lineTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
        area.lineTo(p.dx, p.dy);
      }
    }
    area.lineTo(pointAt(rows.length - 1).dx, chart.bottom);
    area.close();
    canvas.drawPath(area, fillPaint);
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < rows.length; i++) {
      canvas.drawCircle(pointAt(i), 4, dotPaint);
    }

    _drawText(canvas, _formatMoney(maxPrice), Offset(0, chart.top - 6));
    _drawText(canvas, _formatMoney(minPrice), Offset(0, chart.bottom - 14));
    final labelIndexes = rows.length <= 6
        ? List<int>.generate(rows.length, (index) => index)
        : <int>[0, rows.length ~/ 2, rows.length - 1];
    for (final index in labelIndexes) {
      final point = pointAt(index);
      final label = _formatDate(rows[index].changedAt);
      final painter = _textPainter(label)..layout();
      final x = (point.dx - painter.width / 2)
          .clamp(chart.left, chart.right - painter.width);
      painter.paint(canvas, Offset(x, chart.bottom + 8));
    }
  }

  TextPainter _textPainter(String text) {
    return TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final painter = _textPainter(text)..layout(maxWidth: 54);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PriceLineChartPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.color != color ||
        oldDelegate.textStyle != textStyle;
  }
}

class _PriceTableView extends StatelessWidget {
  final List<_PriceHistoryEntry> rows;

  const _PriceTableView({required this.rows});

  @override
  Widget build(BuildContext context) {
    final descending = rows.reversed.toList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: descending.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = descending[index];
        final oldPrice = row.oldPrice;
        final newPrice = row.newPrice;
        final delta =
            oldPrice == null || newPrice == null ? null : newPrice - oldPrice;
        final color = delta == null
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : delta >= 0
                ? Colors.green
                : Colors.red;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_formatDateTime(row.changedAt)),
          subtitle: Text(_sourceLabel(row.source)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                newPrice == null ? '삭제' : _formatMoney(newPrice),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (delta != null)
                Text(
                  '${delta >= 0 ? '+' : ''}${_formatMoney(delta)}',
                  style: TextStyle(color: color),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _formatDate(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  return DateFormat('MM/dd').format(parsed);
}

String _formatDateTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  return DateFormat('yyyy-MM-dd HH:mm').format(parsed);
}

String _formatMoney(num value) {
  final formatted = NumberFormat('#,##0').format(value.round());
  return '$formatted원';
}

String _sourceLabel(String source) {
  switch (source) {
    case 'initial':
      return '최초 등록';
    case 'manual':
      return '수동 수정';
    case 'purchase':
      return '발주 입고가 반영';
    default:
      return source;
  }
}
