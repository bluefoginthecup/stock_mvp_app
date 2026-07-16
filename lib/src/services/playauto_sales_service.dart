import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PlayAutoSalesSnapshot {
  final Map<DateTime, PlayAutoSalesDay> days;

  const PlayAutoSalesSnapshot(this.days);

  static const empty = PlayAutoSalesSnapshot({});

  PlayAutoSalesDay? dayOf(DateTime date) {
    return days[DateTime(date.year, date.month, date.day)];
  }

  double monthAmount(DateTime date) {
    final start = DateTime(date.year, date.month);
    final end = DateTime(date.year, date.month + 1);
    return days.values
        .where((day) => !day.date.isBefore(start) && day.date.isBefore(end))
        .fold<double>(0, (sum, day) => sum + day.amount);
  }
}

class PlayAutoSalesDay {
  final DateTime date;
  final double amount;
  final List<PlayAutoSalesOrder> orders;

  const PlayAutoSalesDay({
    required this.date,
    required this.amount,
    required this.orders,
  });

  int get orderCount => orders.length;
}

class PlayAutoSalesOrder {
  final String key;
  final String orderNo;
  final String customer;
  final String shopName;
  final double amount;
  final int quantity;
  final int lineCount;

  const PlayAutoSalesOrder({
    required this.key,
    required this.orderNo,
    required this.customer,
    required this.shopName,
    required this.amount,
    required this.quantity,
    required this.lineCount,
  });
}

class PlayAutoSalesService {
  static const _orderCachePrefix = 'playauto_order_cache_v1';

  const PlayAutoSalesService();

  Future<PlayAutoSalesSnapshot> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final linesByKey = <String, _PlayAutoSalesLine>{};

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_orderCachePrefix)) continue;
      final cachedText = prefs.getString(key);
      if (cachedText == null || cachedText.isEmpty) continue;
      final responseBody = _responseBodyFromCache(cachedText);
      if (responseBody.isEmpty) continue;
      for (final row in _findOrderRows(_tryDecode(responseBody))) {
        final line = _PlayAutoSalesLine.fromJson(row);
        if (line == null) continue;
        linesByKey[line.identityKey] = line;
      }
    }

    final groupsByDayAndOrder = <DateTime, Map<String, _MutableSalesOrder>>{};
    for (final line in linesByKey.values) {
      final day = DateTime(line.date.year, line.date.month, line.date.day);
      final groups = groupsByDayAndOrder.putIfAbsent(day, () => {});
      final group = groups.putIfAbsent(
        line.groupKey,
        () => _MutableSalesOrder(
          key: line.groupKey,
          orderNo: line.orderNo,
          customer: line.customer,
          shopName: line.shopName,
        ),
      );
      group.amount += line.amount;
      group.quantity += line.quantity;
      group.lineCount += 1;
    }

    final days = <DateTime, PlayAutoSalesDay>{};
    for (final entry in groupsByDayAndOrder.entries) {
      final orders = entry.value.values
          .map((order) => PlayAutoSalesOrder(
                key: order.key,
                orderNo: order.orderNo,
                customer: order.customer,
                shopName: order.shopName,
                amount: order.amount,
                quantity: order.quantity,
                lineCount: order.lineCount,
              ))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
      days[entry.key] = PlayAutoSalesDay(
        date: entry.key,
        amount: orders.fold<double>(0, (sum, order) => sum + order.amount),
        orders: orders,
      );
    }

    return PlayAutoSalesSnapshot(days);
  }

  String _responseBodyFromCache(String cachedText) {
    try {
      final decoded = jsonDecode(cachedText);
      if (decoded is Map) {
        return decoded['response_body']?.toString() ?? '';
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, Object?>> _findOrderRows(Object? node) {
    if (node is List) {
      return node.whereType<Map>().map(_stringKeyedMap).toList();
    }
    if (node is! Map) return const [];

    final map = _stringKeyedMap(node);
    for (final key in const [
      'results',
      'result',
      'orders',
      'order_list',
      'list',
      'data',
      'items',
      'rows',
    ]) {
      final value = map[key];
      if (value is List) {
        return value.whereType<Map>().map(_stringKeyedMap).toList();
      }
      if (value is Map) {
        final nestedRows = _findOrderRows(value);
        if (nestedRows.isNotEmpty) return nestedRows;
      }
    }
    return const [];
  }

  Map<String, Object?> _stringKeyedMap(Map<dynamic, dynamic> source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
}

class _PlayAutoSalesLine {
  final String identityKey;
  final String groupKey;
  final String orderNo;
  final String customer;
  final String shopName;
  final String productName;
  final String optionName;
  final DateTime date;
  final int quantity;
  final int amount;

  const _PlayAutoSalesLine({
    required this.identityKey,
    required this.groupKey,
    required this.orderNo,
    required this.customer,
    required this.shopName,
    required this.productName,
    required this.optionName,
    required this.date,
    required this.quantity,
    required this.amount,
  });

  static _PlayAutoSalesLine? fromJson(Map<String, Object?> json) {
    final dateValue = _pickString(json, const [
      'ord_time',
      'pay_time',
      'wdate',
      'mdate',
      'order_date',
    ]);
    final date = _parseDate(dateValue);
    if (date == null) return null;

    final orderNo = _pickString(
        json,
        const [
          'shop_ord_no',
          'shop_order_no',
          'ord_no',
          'order_no',
          'bundle_no',
          'uniq',
        ],
        fallback: '-');
    final uniq = _pickString(json, const ['uniq', 'order_uniq']);
    final bundleNo = _pickString(json, const [
      'bundle_no',
      'pa_bundle_no',
      'package_no',
      'bundle_code',
    ]);
    final shopName = _pickString(
        json,
        const [
          'shop_name',
          'mall_name',
          'shop_cd',
          'shop_id',
        ],
        fallback: '판매처 없음');
    final ordererName = _pickString(json, const [
      'order_name',
      'orderer_name',
      'ord_name',
      'buyer_name',
      'buyer',
      'from_name',
    ]);
    final receiverName = _pickString(
        json,
        const [
          'to_name',
          'receiver_name',
          'recipient_name',
          'customer_name',
          'cust_name',
          'consignee_name',
          'delivery_name',
          'ship_name',
        ],
        fallback: ordererName);
    final customer = receiverName.isNotEmpty
        ? receiverName
        : ordererName.isNotEmpty
            ? ordererName
            : '주문자 없음';
    final productName = _pickString(
        json,
        const [
          'shop_sale_name',
          'prod_name',
          'product_name',
          'sale_name',
          'goods_name',
          'item_name',
        ],
        fallback: '상품명 없음');
    final optionName = _pickString(json, const [
      'shop_opt_name',
      'shop_add_opt_name',
      'opt_name',
      'option_name',
      'attri',
    ]);
    final sku = _pickString(json, const [
      'sku_cd',
      'c_sale_cd',
      'shop_sale_no',
      'shop_prod_no',
      'opt_custom_cd',
    ]);
    final quantity = _pickInt(json, const [
      'qty',
      'cnt',
      'sale_cnt',
      'order_cnt',
      'ord_cnt',
      'ea',
    ]);
    final rawLineAmount = _pickInt(
        json,
        const [
          'sale_price',
          'sales',
          'sale_amt',
          'goods_price',
          'amount',
          'line_amount',
          'line_total',
          'opt_sale_price',
          'shop_opt_price',
          'shop_sale_amt',
        ],
        fallback: 0);
    final rawUnitPrice = _pickInt(
        json,
        const [
          'unit_price',
          'unit_sale_price',
          'price',
          'opt_unit_price',
          'shop_unit_price',
          'shop_sale_price',
          'shop_cost_price',
          'shop_supply_price',
        ],
        fallback: 0);
    final amount = rawLineAmount > 0
        ? rawLineAmount
        : rawUnitPrice > 0
            ? rawUnitPrice * quantity
            : 0;

    final dayText = _shortDate(dateValue);
    final groupId =
        _firstNonEmpty([bundleNo, uniq, if (orderNo != '-') orderNo]);
    final groupKey = groupId.isNotEmpty
        ? 'playauto::group::$groupId'
        : 'playauto::date::$dayText::shop::$shopName::customer::$customer';
    final identityKey = [
      groupKey,
      orderNo,
      uniq,
      bundleNo,
      productName,
      optionName,
      sku,
      quantity,
      amount,
      dayText,
    ].join('::');

    return _PlayAutoSalesLine(
      identityKey: identityKey,
      groupKey: groupKey,
      orderNo: orderNo,
      customer: customer,
      shopName: shopName,
      productName: productName,
      optionName: optionName,
      date: date,
      quantity: quantity,
      amount: amount,
    );
  }

  static String _pickString(
    Map<String, Object?> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  static int _pickInt(
    Map<String, Object?> json,
    List<String> keys, {
    int fallback = 1,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.replaceAll(',', '').trim());
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && trimmed != '-') return trimmed;
    }
    return '';
  }

  static String _shortDate(String value) {
    if (value.length >= 10) return value.substring(0, 10);
    return value;
  }

  static DateTime? _parseDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == '-') return null;
    final isoLike =
        normalized.replaceFirst(' ', 'T').replaceAll(RegExp(r'\.\d+$'), '');
    return DateTime.tryParse(isoLike) ??
        DateTime.tryParse(
          normalized.substring(0, normalized.length.clamp(0, 10)),
        );
  }
}

class _MutableSalesOrder {
  final String key;
  final String orderNo;
  final String customer;
  final String shopName;
  double amount = 0;
  int quantity = 0;
  int lineCount = 0;

  _MutableSalesOrder({
    required this.key,
    required this.orderNo,
    required this.customer,
    required this.shopName,
  });
}
