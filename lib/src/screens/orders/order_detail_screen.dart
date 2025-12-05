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

import '../../repos/timeline_repo.dart';
import 'widgets/order_timeline.dart';

import '../../models/work.dart';
import '../../models/types.dart';
import '../works/work_detail_screen.dart';
import '../works/widgets/work_row.dart';
import '../../services/inventory_service.dart';



class OrderDetailScreen extends StatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;
  TimelineData? _timeline;
  bool _tlLoading = false;
  bool _busy = false; // 주문 완료 처리 중 여부

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _reload(); // 진입 시 최신화(옵션)
    _loadTimeline(); // 👈 타임라인 로드
  }

  Future<void> _reload() async {
    final orderRepo = context.read<OrderRepo>();
    // 프로젝트에서 sync면 await 제거
    final latest = await orderRepo.getOrder(_order.id);
    if (!mounted) return;
    if (latest == null) return;
    setState(() => _order = latest);
    // 주문 편집 후에도 타임라인 갱신
    await _loadTimeline();
  }

  Future<void> _loadTimeline() async {
        setState(() => _tlLoading = true);
        try {
          final tlRepo = context.read<TimelineRepo>();
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
          debugPrint('[TL][ERROR] $e');
        }
      }

  Future<void> _goEdit() async {
    final editedId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderFormScreen(orderId: _order.id),
      ),
    );
    // 편집 화면에서 저장 시 pop(context, orderId)로 반환한다고 가정
    if (editedId != null && editedId.isNotEmpty) {
      await _reload();
    }
  }

  Future<void> _markAsDone() async {
        if (_busy) return;

        // 미리 캡처 (dialog 안팎 context 혼용 방지)
        final repo = context.read<OrderRepo>();
        final messenger = ScaffoldMessenger.of(context);

        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('완료'),
            content: const Text('이 주문을 완료 처리할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('완료'),
              ),
            ],
          ),
        );
        if (!mounted || ok != true) return;

        setState(() => _busy = true);
        try {
          await repo.updateOrderStatus(_order.id, OrderStatus.done);
          if (!mounted) return;

          // 로컬 상태도 즉시 갱신 (리스트로 돌아가면 바로 반영됨)
          setState(() => _order = _order.copyWith(status: OrderStatus.done));
          messenger.showSnackBar(const SnackBar(content: Text('주문을 완료로 변경했어요.')));

          // 원하면 상세 유지 대신 아래 주석을 사용해 리스트로 돌아가기
          // Navigator.pop(context, 'done');
        } catch (e) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text('완료 처리에 실패했습니다: $e')));
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      }

  @override
  Widget build(BuildContext context) {
    final hasLines = _order.lines.isNotEmpty;
    final isDone = _order.status == OrderStatus.done; // ✅ 한곳에서 판단

    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 상세'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: '편집', onPressed: _goEdit),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: hasLines ? _buildOrderWithLines(context) : _buildOrderEmpty(context),
      ),
        bottomNavigationBar: (isDone)
                ? null
            : SafeArea(
                top: false,
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: _busy ? const Text('처리중...') : const Text('완료'),
                      onPressed: _busy ? null : _markAsDone,
                    ),
                  ),
                ),
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

    // 👇 타임라인 박스 (리스트 위로)
            Container(
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _tlLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_timeline == null
                      ? const Center(child: Text('타임라인을 불러오지 못했어요.'))
                      : OrderTimeline(data: _timeline!)),
            ),
            const SizedBox(height: 16),

    // ✅ 비스크롤 리스트 (바깥 SingleChildScrollView가 스크롤 담당)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _order.lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final line = _order.lines[index];
                return _buildLineCard(context, line.itemId, line.qty);
              },
            ),

        const SizedBox(height: 16),
        // 전체 품목에 대해 한 번에 계산
        ElevatedButton.icon(
          icon: const Icon(Icons.assessment),
          label: const Text('전체 품목 부족분 계산'),
          onPressed: () async{
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderShortageResultScreen(order: _order),
              ),
            );
    // 부족분 계산/생성 이후 타임라인 갱신
                await _loadTimeline();
          },
        ),
        const SizedBox(height: 8),
        Text(
          '각 품목 카드를 눌러 개별 부족분을 보거나, 전체 버튼으로 한 번에 계산할 수 있어요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
            const SizedBox(height: 120),
            const Center(child: Text('(주문 라인이 없습니다)')),
          ],
        );
  }

  /// 개별 라인 카드
  Widget _buildLineCard(BuildContext context, String itemId, int qty) {
    final workRepo = context.read<WorkRepo>();
    final inv = context.read<InventoryService>();

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
                    full: false,                  // 전체 경로까지 표시 (원하면 false)
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
                                        // ✅ ShortageResultScreen.show가 Future<String?> 반환하도록 바뀌어야 함
                                        final workId = await ShortageResultScreen.show(
                                          context,
                                          orderId: _order.id,        // 👈 추가
                                          finishedItemId: itemId,
                                          orderQty: qty,
                                        );
                                        if (!mounted) return;
                                        if (workId != null && workId.isNotEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('작업이 생성되었습니다.')),
                                          );
                                          await _reload();        // 주문/상태 갱신
                                          await _loadTimeline();  // 타임라인 갱신
                                          // (선택) 관련 작업 섹션을 쓰면: await _reloadWorks();
                                        }
                                      },
                ),
              ],
            ),

    const SizedBox(height: 8),

              // 🔹 관련 작업 리스트 (이 주문  이 아이템)
              StreamBuilder<List<Work>>(
                stream: workRepo.watchWorksByOrderAndItem(_order.id, itemId),
                builder: (context, snap) {
                  final list = snap.data ?? const [];
                  if (list.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('관련 작업', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      ListView.separated(
                        itemCount: list.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final w = list[i];
                          return WorkRow(
                            w: w,
                            onStart: (w.status == WorkStatus.planned)
                                ? () => inv.startWork(w.id)
                                : null,
                            onDone: (w.status == WorkStatus.inProgress)
                                ? () => inv.completeWork(w.id)
                                : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorkDetailScreen(work: w),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
