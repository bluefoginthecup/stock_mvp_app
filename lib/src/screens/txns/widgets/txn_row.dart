import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/txn.dart';
import '../../../models/types.dart';
import '../../../ui/ui_utils.dart';
import '../../../repos/repo_interfaces.dart';
import '../../../ui/common/qty_badge.dart';

// ✅ 브레드크럼 라벨 재사용
import '../../../utils/item_presentation.dart'; // ItemLabel, ItemPresentationService

import '../../../ui/common/delete_more_menu.dart'; // ▼ 더보기 메뉴 임포트 (경로 맞춰주세요)



/// 입·출고 기록 한 줄 표시
/// - 아이템명 (없으면 itemId tail)
/// - 주문자명 (order인 경우)
/// - 뱃지: 작업입고/주문출고
/// - UUID는 …abcd 4글자만
class TxnRow extends StatelessWidget {
    final Txn t;
    /// 선택: 외부에서 trailing 커스터마이즈 가능
    final Widget? trailing;
    const TxnRow({super.key, required this.t, this.trailing});


  Future<(String, String?)> _loadNames(BuildContext ctx) async {
    // ItemRepo / OrderRepo가 주입되어 있지 않아도 안전하게 동작하도록 설계
    final itemRepo = ctx.read<ItemRepo?>();
    final orderRepo = ctx.read<OrderRepo?>();

    String itemName = '';
    String? customer;

    try {
      if (itemRepo != null) {
        final n = await itemRepo.nameOf(t.itemId);
        final nt = n?.trim();
        if (nt != null && nt.isNotEmpty) itemName = nt;
      }
    } catch (_) {}

    if (t.refType == RefType.order && t.refId != null && orderRepo != null) {
      try {
        final r  = await orderRepo.customerNameOf(t.refId!);
        final rt = r?.trim();
        if (rt != null && rt.isNotEmpty) customer = rt;
      } catch (_) {}
    }

    if (itemName.isEmpty) {
      itemName = '아이템 ${shortId(t.itemId)}';
    }
    return (itemName, customer);
  }

  @override
  Widget build(BuildContext context) {
    final isInbound = t.type == TxnType.in_;

    // 뱃지
    Widget reasonBadge = badge(t.refType.name, Colors.blueGrey); // ← 기본값

    if (t.refType == RefType.work) {
      reasonBadge = t.isPlanned
          ? badge('작업등록', Colors.blueGrey)
          : badge('작업물 입고', Colors.green, icon: Icons.factory);
    } else if (t.refType == RefType.purchase) {
      reasonBadge = t.isPlanned ? badge('발주등록', Colors.blueGrey)
          : badge('발주품 입고', Colors.green);
    } else if (t.refType == RefType.order) {
      reasonBadge = t.isIn ? badge('주문입고', Colors.blueGrey)
          : badge('주문출고', Colors.red, icon: Icons.shopping_cart);
    }


    final leadIcon = Icon(
      isInbound ? Icons.south_west : Icons.north_east,
      color: isInbound ? Colors.green : Colors.red,
    );

    return FutureBuilder<(String, String?)>(
      future: _loadNames(context),
      builder: (context, snap) {
        final itemName = snap.data?.$1 ?? '아이템 ${shortId(t.itemId)}';
        final customer = snap.data?.$2;

        return ListTile(
                      leading: leadIcon,
                      // ✅ 타이틀: [수량 배지]  [풀 경로 브레드크럼]
                      title: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        // 수량 배지
                        QtyBadge(qty:t.qty.abs(), direction: t.type, status: t.status),
                        const SizedBox(width: 8),
                        // 브레드크럼 (한 줄 말줄임)
                        Expanded(
                          child: ItemLabel(
                            itemId: t.itemId,
                            full: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(fmtYmdHm(t.ts)),
                          reasonBadge,
                          if (customer != null) Text('주문자 $customer'),
                          if (t.refType == RefType.order && t.refId != null)
                            Text('주문번호 ${shortId(t.refId!)}')
                          else if (t.refType == RefType.work && t.refId != null)
                            Text('작업번호 ${shortId(t.refId!)}')
                          else if (t.refType == RefType.purchase && t.refId != null)
                            Text('발주번호 ${shortId(t.refId!)}'),
                        ],
                      ),
                      if (t.memo != null && t.memo!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '메모: ${t.memo!}',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
          trailing: trailing ?? DeleteMoreMenu<Txn>(entity: t),
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        );
      },
    );
  }
}
