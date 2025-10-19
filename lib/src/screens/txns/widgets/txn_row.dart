import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/txn.dart';
import '../../../models/types.dart';
import '../../../ui/ui_utils.dart';
import '../../../repos/repo_interfaces.dart';

// ✅ 브레드크럼 라벨 재사용
import '../../../utils/item_presentation.dart'; // ItemLabel, ItemPresentationService


/// 입·출고 기록 한 줄 표시
/// - 아이템명 (없으면 itemId tail)
/// - 주문자명 (order인 경우)
/// - 뱃지: 작업입고/주문출고
/// - UUID는 …abcd 4글자만
class TxnRow extends StatelessWidget {
  final Txn t;
  const TxnRow({super.key, required this.t});

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
    final qtyStr = (isInbound ? '+' : '-') + t.qty.toString();

    // 뱃지
    Widget reasonBadge;
    if (t.refType == RefType.work) {
      reasonBadge = badge('작업입고', Colors.green, icon: Icons.factory);
    } else if (t.refType == RefType.order) {
      reasonBadge = isInbound
          ? badge('주문입고?', Colors.blueGrey)
          : badge('주문출고', Colors.red, icon: Icons.shopping_cart);
    } else {
      reasonBadge = badge(t.refType.name, Colors.blueGrey);
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
                  // ✅ 상단 타이틀을 "풀 경로 브레드크럼"으로 교체
                  title: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: ItemLabel(
                      itemId: t.itemId,
                      full: true,          // 전체 경로: 예) 완제품 › 사계절용 › 에리카 화이트 › 50기본형 방석커버
                      // compact / separator / maxLines 등이 있다면 여기서 옵션으로 조정 가능
                    ),
                  ),
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(fmtYmdHm(t.ts)),
              reasonBadge,
              if (customer != null) Text('주문자 $customer'),
              if (t.refType == RefType.order)
                Text('주문번호 ${shortId(t.refId)}')
              else if (t.refType == RefType.work)
                Text('작업번호 ${shortId(t.refId)}')
              else if (t.refType == RefType.purchase)
                  Text('발주번호 ${shortId(t.refId)}')

            ],
          ),
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        );
      },
    );
  }
}
