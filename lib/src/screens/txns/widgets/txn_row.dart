import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/txn.dart';
import '../../../models/types.dart';
import '../../../ui/ui_utils.dart';
import '../../../repos/repo_interfaces.dart';
import '../../../ui/common/qty_badge.dart';
import '../../../utils/item_presentation.dart'; // ItemLabel
import '../../../ui/common/delete_more_menu.dart';

// ────────────────────────────────────────────────────────────
// 로깅 유틸
// ────────────────────────────────────────────────────────────
void _d(String msg) {
  if (kDebugMode) debugPrint('[TxnRow] $msg');
}

// Provider 안전 읽기 (provider 버전 이슈로 maybeOf 사용 불가 → try/catch)
T? _tryRead<T>(BuildContext ctx) {
  try {
    final v = Provider.of<T>(ctx, listen: false);
    _d('Provider<$T> OK');
    return v;
  } catch (e) {
    _d('Provider<$T> MISSING: $e');
    return null;
  }
}

/// 입·출고 기록 한 줄 표시
class TxnRow extends StatelessWidget {
  final Txn t;
  final Widget? trailing;
  const TxnRow({super.key, required this.t, this.trailing});

  Future<(String, String?)> _loadNames(BuildContext ctx) async {
    _d('----- _loadNames start: itemId=${t.itemId}, refType=${t.refType}, refId=${t.refId}, ts=${t.ts}');
    final itemRepo  = _tryRead<ItemRepo>(ctx);
    final orderRepo = _tryRead<OrderRepo>(ctx);

    String itemName = '';
    String? customer;

    try {
      if (itemRepo != null) {
        _d('itemRepo.nameOf(${t.itemId})...');
        final n = await itemRepo.nameOf(t.itemId);
        final nt = n?.trim();
        if (nt != null && nt.isNotEmpty) {
          itemName = nt;
          _d('item name resolved="$itemName"');
        } else {
          _d('item name empty');
        }
      } else {
        _d('itemRepo is null → skip nameOf()');
      }
    } catch (e, st) {
      _d('EX in itemRepo.nameOf: $e\n$st');
    }

    try {
      if (t.refType == RefType.order && t.refId != null && orderRepo != null) {
        _d('orderRepo.customerNameOf(${t.refId})...');
        final r  = await orderRepo.customerNameOf(t.refId);
        final rt = r?.trim();
        if (rt != null && rt.isNotEmpty) {
          customer = rt;
          _d('customer resolved="$customer"');
        } else {
          _d('customer empty');
        }
      } else {
        _d('skip customer lookup (refType=${t.refType}, refId=${t.refId}, orderRepo? ${orderRepo != null})');
      }
    } catch (e, st) {
      _d('EX in orderRepo.customerNameOf: $e\n$st');
    }

    if (itemName.isEmpty) {
      itemName = '아이템 ${shortId(t.itemId)}';
      _d('fallback itemName="$itemName"');
    }

    _d('----- _loadNames done');
    return (itemName, customer);
  }

  void _goItemDetail(BuildContext context) {
    _d('tap -> item detail: ${t.itemId}');
    Navigator.of(context, rootNavigator: true).pushNamed(
           '/items/detail',
           arguments: t.itemId,
         );
  }

  void _goPurchaseDetail(BuildContext context, String poId) {
    _d('tap -> purchase detail: $poId');
      debugPrint('[TxnRow] Navigating to /purchases/detail with orderId=$poId');
    Navigator.of(context, rootNavigator: true).pushNamed(
      '/purchases/detail',
      arguments: poId,
    );
  }

  @override
  Widget build(BuildContext context) {
    _d('build: txnId=${shortId(t.id)}, type=${t.type}, isPlanned=${t.isPlanned}');
    final isInbound = t.type == TxnType.in_;

    Widget reasonBadge = badge(t.refType.name, Colors.blueGrey);
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
        if (snap.connectionState == ConnectionState.waiting) {
          // 진행 로그
          _d('FutureBuilder waiting...');
          return const ListTile(
            dense: true,
            title: Text('로딩 중...'),
          );
        }

        if (snap.hasError) {
          _d('FutureBuilder ERROR: ${snap.error}\n${snap.stackTrace}');
          // 에러도 화면에 살짝 보여줌(임시)
          return ListTile(
            dense: true,
            leading: const Icon(Icons.error, color: Colors.red),
            title: const Text('행 렌더링 실패'),
            subtitle: Text('${snap.error}'),
          );
        }

        final itemName = snap.data?.$1 ?? '아이템 ${shortId(t.itemId)}';
        final customer = snap.data?.$2;

        return ListTile(
          leading: leadIcon,
          title: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                QtyBadge(qty: t.qty.abs(), direction: t.type, status: t.status),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _goItemDetail(context),
                    child: ItemLabel(itemId: t.itemId, full: true),
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
                  if (t.refType == RefType.purchase && t.refId != null)
                    InkWell(
                      onTap: () => _goPurchaseDetail(context, t.refId!),
                      child: Text(
                        '발주번호 ${shortId(t.refId)}',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          color: Colors.blue,
                        ),
                      ),
                    )
                  else if (t.refType == RefType.order && t.refId != null)
                    Text('주문번호 ${shortId(t.refId)}')
                  else if (t.refType == RefType.work && t.refId != null)
                      Text('작업번호 ${shortId(t.refId)}'),
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
