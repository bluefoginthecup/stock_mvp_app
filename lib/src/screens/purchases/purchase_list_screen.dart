import 'package:provider/provider.dart';
import '../../repos/repo_interfaces.dart';
import '../../models/purchase_order.dart'; // ✅
import '../../models/purchase_line.dart';
import '../../services/inventory_service.dart';
import '../../ui/common/ui.dart';
import '../purchases/purchase_detail_screen.dart'; // 경로는 프로젝트 구조에 맞게
import '../../ui/common/common_calendar_view.dart';
import '../../utils/calendar_mapper.dart';
import 'widgets/purchase_timeline_preview.dart';

class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  bool isCalendarView = true;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final poRepo = context.read<PurchaseOrderRepo>();
    final inv = context.read<InventoryService>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration(
            hintText: '거래처 / 상품 검색',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _query = '';
                });
              },
            )
                : null,
          ),
          onChanged: (v) {
            setState(() {
              _query = v.trim().toLowerCase();
            });
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              isCalendarView ? Icons.list : Icons.calendar_today,
            ),
            onPressed: () {
              setState(() {
                isCalendarView = !isCalendarView;
              });
            },
          ),
        ],
      ),

      body: FutureBuilder<Map<String, List<PurchaseLine>>>(
        future: poRepo.getLinesMap(), // 🔥 한 번만 가져옴
        builder: (context, linesSnap) {
          if (!linesSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final linesMap = linesSnap.data!;

          return StreamBuilder<List<PurchaseOrder>>(
            stream: poRepo.watchAllPurchaseOrders(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('불러오기 실패: ${snap.error}'));
              }

              final rawList = snap.data ?? const <PurchaseOrder>[];

              // 🔥🔥 검색 필터 핵심
              final list = rawList.where((p) {
                if (_query.isEmpty) return true;

                final supplier =
                (p.supplierName ?? '').toLowerCase();

                final lines = linesMap[p.id] ?? [];

                final hasItem = false;
                // final hasItem = lines.any((l) =>
                //     (l.itemName ?? '')
                //         .toLowerCase()
                //         .contains(_query));
               // return supplier.contains(_query) || hasItem;

                return supplier.contains(_query);

              }).toList();

              if (list.isEmpty) {
                return Center(child: Text('\"$_query\" 검색 결과 없음'));
              }

              /// ============================
              /// 🔵 캘린더 뷰
              /// ============================
              if (isCalendarView) {
                final events = mapPurchaseToEvents(list, linesMap);

                return CommonCalendarView(
                  events: events,
                  onEventTap: (e) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PurchaseDetailScreen(
                          repo: context.read<PurchaseOrderRepo>(),
                          orderId: e.refId,
                        ),
                      ),
                    );
                  },
                  expandedBuilder: (e) {
                    return PurchaseTimelinePreview(
                      purchaseId: e.refId,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PurchaseDetailScreen(
                              repo: context.read<PurchaseOrderRepo>(),
                              orderId: e.refId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              }

              /// ============================
              /// 🟢 리스트 뷰
              /// ============================
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final p = list[i];

                  String fmtDate(DateTime? d) {
                    if (d == null) return '-';
                    final m = d.month.toString().padLeft(2, '0');
                    final day = d.day.toString().padLeft(2, '0');
                    return '${d.year}-$m-$day';
                  }

                  String statusLabel() {
                    switch (p.status.name) {
                      case 'draft':
                        return '임시저장';
                      case 'ordered':
                        return '발주완료';
                      case 'received':
                        return '입고완료';
                      case 'canceled':
                        return '취소';
                      default:
                        return p.status.name;
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text(
                          '발주: ${p.supplierName?.trim().isEmpty == true ? '(미지정)' : p.supplierName}'),
                      subtitle: Text(
                          '상태: ${statusLabel()} • ETA: ${fmtDate(p.eta)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PurchaseDetailScreen(
                              repo: context.read<PurchaseOrderRepo>(),
                              orderId: p.id,
                            ),
                          ),
                        );
                      },
                      contentPadding:
                      const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ).copyWithButtonBar(
                      context, p, poRepo, inv);
                },
              );
            },
          );
        },
      ),
    );
  }
}

extension CardWithButtonBar on Card {
  Widget copyWithButtonBar(
      BuildContext context,
      PurchaseOrder p,
      PurchaseOrderRepo poRepo,
      InventoryService inv,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        this,
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (p.status == PurchaseOrderStatus.draft)
                FilledButton.tonal(
                  onPressed: () async {
                    await inv.orderPurchase(p.id);
                  },
                  child: const Text('발주완료'),
                ),
              if (p.status == PurchaseOrderStatus.ordered)
                FilledButton(
                  onPressed: () async {
                    await inv.receivePurchase(p.id);
                  },
                  child: const Text('입고완료'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}