import 'dart:math';
import 'package:flutter/material.dart';
import '../../../repos/timeline_repo.dart';

class OrderTimeline extends StatefulWidget {
    final TimelineData data;
    const OrderTimeline({super.key, required this.data});

    @override
    State<OrderTimeline> createState() => _OrderTimelineState();
  }

class _OrderTimelineState extends State<OrderTimeline> {
    final ScrollController _hCtrl = ScrollController(); // ✅ 가로 스크롤 전용
    static const lanes = ['ORDER', 'PROCUREMENT', 'PRODUCTION'];

    @override
    void dispose() {
      _hCtrl.dispose();
      super.dispose();
    }


  @override
  Widget build(BuildContext context) {
    // 세로 구성: 레인 헤더 + 레인 바들
    final laneToBars = {
      for (final lane in _OrderTimelineState.lanes)
        lane: widget.data.bars.where((b) => b.lane == lane).toList()
    };
    // 가로 스크롤: 1px=1day
    final totalDays = widget.data.rangeEnd.difference(widget.data.rangeStart).inDays + 1;

  final contentWidth = max(300.0, totalDays.toDouble()); // 최소 너비

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text(
  '${_fmtDate(widget.data.rangeStart)} ~ ${_fmtDate(widget.data.rangeEnd)}',

  style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text('1일=1px', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const Divider(height: 1),
        // 바디
        Expanded(
          child: Scrollbar(
            controller: _hCtrl,          // ✅ Scrollbar와
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _hCtrl,        // ✅ SingleChildScrollView에 동일 컨트롤러

              child: SizedBox(
                width: contentWidth,
              child: ListView.builder(
                      shrinkWrap: true,                              // ✅ 자체 높이만 사용
                      physics: const NeverScrollableScrollPhysics(), // ✅ 세로 스크롤 비활성화(Primary 불참여)
                      itemCount: _OrderTimelineState.lanes.length,
                      itemBuilder: (context, i) {

                    final lane = _OrderTimelineState.lanes[i];

                    final bars = laneToBars[lane]!;
                    return _LaneRow(
                      lane: lane,
                      bars: bars,
                      rangeStart: widget.data.rangeStart,
                      rangeEnd: widget.data.rangeEnd,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}

class _LaneRow extends StatelessWidget {
  final String lane;
  final List<TimelineBar> bars;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  const _LaneRow({
    required this.lane,
    required this.bars,
    required this.rangeStart,
    required this.rangeEnd,
  });

  Color get laneColor => lane == 'ORDER'
      ? const Color(0xFF5A5A5A)
      : lane == 'PROCUREMENT'
      ? const Color(0xFF7A4FFF)
      : const Color(0xFF25A55F);

  @override
  Widget build(BuildContext context) {
    // 세로 한 줄 영역
    const rowHeight = 32.0;
    const gap = 8.0;
    final height = max(rowHeight, bars.length * (rowHeight + gap) + 28);

    return SizedBox(
      height: height + 12,
      child: Stack(
        children: [
          // 레인 타이틀
          Positioned(
            left: 8,
            top: 6,
            child: Text(lane, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
          // 그리기 캔버스
          Positioned.fill(
            left: 0,
            top: 20,
            child: CustomPaint(
              painter: _TimelinePainter(
                lane: lane,
                bars: bars,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                laneColor: laneColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final String lane;
  final List<TimelineBar> bars;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final Color laneColor;

  _TimelinePainter({
    required this.lane,
    required this.bars,
    required this.rangeStart,
    required this.rangeEnd,
    required this.laneColor,
  });

  double _x(DateTime day) => day.difference(rangeStart).inDays.toDouble(); // 1px=1day

  @override
  void paint(Canvas canvas, Size size) {
    final paintBar = Paint()..color = laneColor.withOpacity(0.85);
    final paintToday = Paint()..color = Colors.grey.withOpacity(0.6)..strokeWidth = 1;

    final today = DateTime.now();
    final todayLocal = DateTime(today.year, today.month, today.day);
    final todayX = _x(todayLocal);

    // 오늘 세로선
    if (todayX >= 0 && todayX <= size.width) {
      canvas.drawLine(Offset(todayX, 0), Offset(todayX, size.height), paintToday);
    }

    // 바들 (세로로 여러 줄)
    const rowH = 24.0;
    const vGap = 8.0;
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final startX = max(0.0, _x(b.start));
      final endDate = b.end ?? todayLocal;
      final endX = _x(endDate);
      final width = max(1.0, endX - startX + 1); // 폐구간: 최소 1px

      final top = i * (rowH + vGap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(startX, top, width, rowH),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paintBar);

      // 라벨 (폭이 좁으면 생략될 수 있음)
      final tp = TextPainter(
        text: TextSpan(text: b.label, style: const TextStyle(fontSize: 11, color: Colors.white)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: max(0, width - 6));
      tp.paint(canvas, Offset(startX + 3, top + (rowH - tp.height) / 2));

      // 마커들
      for (final m in b.markers) {
        final mx = _x(m.date);
        final markerPaint = Paint()..color = Colors.black.withOpacity(0.9);
        // 간단 원 마커
        canvas.drawCircle(Offset(mx, top + rowH / 2), 3.0, markerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) {
    return old.bars != bars || old.rangeStart != rangeStart || old.rangeEnd != rangeEnd;
  }
}
