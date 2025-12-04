// lib/src/screens/orders/order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import 'order_form_screen.dart';
import '../../utils/item_presentation.dart';

// ⛳ 개별 품목 부족분 모달 (정적 show 사용)
import '../bom/shortage_result_screen.dart';
// ⛳ 전체 주문 품목 부족분 결과 화면
import '../bom/order_shortage_result_screen.dart';

// ✅ 타임라인 레포/위젯 (신규 추가)
import '../../repos/timeline_repo.dart';
import 'widgets/order_timeline.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;

  // ✅ 타임라인 상태
  TimelineData? _timeline;
  bool _tlLoading = true;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _reload();       // 주문 본문 최신화
    _loadTimeline(); // 타임라인 로드
  }

  Future<void> _reload() async {
    final orderRepo = context.read<OrderRepo>();
    final latest = await orderRepo.getOrder(_order.id);
    if (!mounted || latest == null) return;
    setState(() => _order = latest);
  }

  // ✅ 타임라인 로딩
  Future<void> _loadTimeline() async {
    setState(() => _tlLoading = true);
    try {
      final tlRepo = context.read<TimelineRepo>(); // Provider로 주입되어 있어야 함
      final data = await tlRepo.fetchOrderTimeline(_order.id);
      if (!mounted) return;
      setState(() {
        _timeline = data;
        _tlLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _timeline = null;
        _tlLoading = false;
      });
      // 필요하면 스낵바 등으로 노출
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('타임라인 로드 실패: $e')));
    }
  }

  Future<void> _goEdit() async {
    final editedId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderFormScreen(orderId: _order.id),
      ),
    );
    // 편집 후 돌아오면 본문/타임라인 다시 로드
    if (editedId != null && editedId.isNotEmpty) {
      await _reload();
      await _loadTimeline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLines = _order.lines.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '편집',
            onPressed: _goEdit,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: hasLines ? _buildOrderWithLines(context) : _buildOrderEmpty(context),
      ),
    );
  }

  /// 라인이 있는 경우 UI
  Widget _buildOrderWithLines(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 주문 메타
        Text('고객명: ${_order.customer}'),
        Text('주문일: ${_order.date.toIso8601String().split("T").first}'),
        Text('상태: ${_order.status.name}'),
        const SizedBox(height: 12),

        // ✅ 모든 주문 라인 표시
        Expanded(
          child: ListView(
            children: [
              // 라인 리스트
              ...List.generate(_order.lines.length, (index) {
                final line = _order.lines[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: index == _order.lines.length - 1 ? 12 : 12),
                  child: _buildLineCard(context, line.itemId, line.qty),
                );
              }),

              const SizedBox(height: 16),

              // 전체 품목 부족분 계산 버튼
              ElevatedButton.icon(
                icon: const Icon(Icons.assessment),
                label: const Text('전체 품목 부족분 계산'),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderShortageResultScreen(order: _order),
                    ),
                  );
                  // 계산/생성 후 타임라인 갱신 필요 시
                  await _reload();
                  await _loadTimeline();
                },
              ),
              const SizedBox(height: 8),
              Text(
                '각 품목 카드를 눌러 개별 부족분을 보거나, 전체 버튼으로 한 번에 계산할 수 있어요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ✅ 타임라인 섹션
              Row(
                children: [
                  Text('타임라인', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    tooltip: '새로고침',
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadTimeline,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 280, // 초기 높이
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildTimelineBody(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 라인이 없는 경우 UI
  Widget _buildOrderEmpty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('고객명: ${_order.customer}'),
        Text('주문일: ${_order.date.toIso8601String().split("T").first}'),
        Text('상태: ${_order.status.name}'),
        const SizedBox(height: 12),
        const Expanded(
          child: Center(child: Text('(주문 라인이 없습니다)')),
        ),
      ],
    );
  }

  /// 타임라인 섹션 본문
  Widget _buildTimelineBody() {
    if (_tlLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_timeline == null) {
      return Center(
        child: Text(
          '타임라인 데이터를 불러오지 못했어요.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return OrderTimeline(data: _timeline!);
  }

  /// 개별 라인 카드
  Widget _buildLineCard(BuildContext context, String itemId, int qty) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목영역
            Row(
              children: [
                Expanded(
                  child: ItemLabel(
                    itemId: itemId,
                    full: false,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                    autoNavigate: true,
                  ),
                ),
                Text(
                  '수량 $qty',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.blueGrey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 액션
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calculate),
                  label: const Text('이 품목 부족분'),
                  onPressed: () async {
                    await ShortageResultScreen.show(
                      context,
                      finishedItemId: itemId,
                      orderQty: qty,
                    );
                    // 부족분 계산 후 작업/발주 생성했다면 타임라인 갱신
                    await _reload();
                    await _loadTimeline();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
