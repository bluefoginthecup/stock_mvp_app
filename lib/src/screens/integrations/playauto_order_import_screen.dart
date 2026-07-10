import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PlayAutoOrderImportScreen extends StatefulWidget {
  const PlayAutoOrderImportScreen({super.key});

  @override
  State<PlayAutoOrderImportScreen> createState() =>
      _PlayAutoOrderImportScreenState();
}

class _PlayAutoOrderImportScreenState extends State<PlayAutoOrderImportScreen> {
  final _baseUrlController = TextEditingController(
    text: 'https://openapi.playauto.io/api',
  );
  final _apiKeyController = TextEditingController();
  final _authenticationKeyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();
  final _sdateController = TextEditingController();
  final _edateController = TextEditingController();
  final _lengthController = TextEditingController(text: '100');

  var _loading = false;
  List<_PlayAutoOrderPreview> _orders = const [];
  String? _result;
  int? _statusCode;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    _sdateController.text = _formatDate(weekAgo);
    _edateController.text = _formatDate(now);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _authenticationKeyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    _sdateController.dispose();
    _edateController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  Future<void> _issueToken() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('API Key를 입력해주세요.');
      return;
    }

    final authenticationKey = _authenticationKeyController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (authenticationKey.isEmpty && (email.isEmpty || password.isEmpty)) {
      _showSnack('솔루션 인증키 또는 이메일/비밀번호를 입력해주세요.');
      return;
    }

    await _runRequest(() async {
      final body = authenticationKey.isNotEmpty
          ? <String, Object?>{'authentication_key': authenticationKey}
          : <String, Object?>{'email': email, 'password': password};

      final response = await http.post(
        _endpoint('/auth'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode(body),
      );

      final prettyBody = _prettyBody(response.body);
      final token = _readToken(response.body);
      if (token != null) {
        _tokenController.text = token;
      }

      return _PlayAutoResponse(
        statusCode: response.statusCode,
        body: token == null
            ? prettyBody
            : '토큰 발급 성공\n\nAuthorization: Token $token\n\n$prettyBody',
      );
    });
  }

  Future<void> _fetchRecentOrders() async {
    final apiKey = _apiKeyController.text.trim();
    final token = _tokenController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('API Key를 입력해주세요.');
      return;
    }
    if (token.isEmpty) {
      _showSnack('먼저 토큰을 발급하거나 입력해주세요.');
      return;
    }

    final length = int.tryParse(_lengthController.text.trim());
    if (length == null || length <= 0 || length > 3000) {
      _showSnack('조회 개수는 1~3000 사이로 입력해주세요.');
      return;
    }

    final sdate = _sdateController.text.trim();
    final edate = _edateController.text.trim();
    if (sdate.isEmpty || edate.isEmpty) {
      _showSnack('조회 시작일과 종료일을 입력해주세요.');
      return;
    }

    await _runRequest(() async {
      final requestBody = <String, Object?>{
        'start': 0,
        'length': length,
        'date_type': 'wdate',
        'sdate': sdate,
        'edate': edate,
        'status': ['ALL'],
        'bundle_yn': false,
      };

      final response = await http.post(
        _endpoint('/orders'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'Authorization': 'Token $token',
        },
        body: jsonEncode(requestBody),
      );
      final orders = _readOrders(response.body);
      if (mounted) {
        setState(() => _orders = orders);
      }

      return _PlayAutoResponse(
        statusCode: response.statusCode,
        body: [
          '요청 바디',
          const JsonEncoder.withIndent('  ').convert(requestBody),
          '',
          '응답',
          _prettyBody(response.body),
        ].join('\n'),
      );
    });
  }

  void _openOrderPreview() {
    if (_orders.isEmpty) {
      _showSnack('먼저 최근 주문을 조회해주세요.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlayAutoOrderPreviewScreen(orders: _orders),
      ),
    );
  }

  Future<void> _runRequest(
    Future<_PlayAutoResponse> Function() request,
  ) async {
    setState(() {
      _loading = true;
      _statusCode = null;
      _result = null;
      _orders = const [];
    });

    try {
      final response = await request();
      if (!mounted) return;
      setState(() {
        _statusCode = response.statusCode;
        _result = response.body;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = '요청 실패\n\n$e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Uri _endpoint(String path) {
    final base =
        _baseUrlController.text.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  String? _readToken(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final token = decoded['token'];
        if (token is String && token.isNotEmpty) return token;

        final data = decoded['data'];
        if (data is Map<String, Object?>) {
          final nestedToken = data['token'];
          if (nestedToken is String && nestedToken.isNotEmpty) {
            return nestedToken;
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  List<_PlayAutoOrderPreview> _readOrders(String body) {
    try {
      final decoded = jsonDecode(body);
      final rows = _findOrderRows(decoded);
      return rows.map(_PlayAutoOrderPreview.fromJson).toList();
    } catch (_) {
      return const [];
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

  String _prettyBody(String body) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonDecode(body));
    } catch (_) {
      return body;
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('플토 테스트')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'PlayAuto 토큰 발급과 최근 주문 조회 응답 확인용 화면입니다. 아직 주문 저장은 하지 않습니다.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'OpenAPI Base URL',
              helperText: '문서와 계정 설정에 따라 /api 포함 여부가 다를 수 있어 수정 가능하게 둡니다.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _authenticationKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '솔루션 인증키',
              helperText: '이 값을 입력하면 이메일/비밀번호 없이 토큰 발급을 시도합니다.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '발급 토큰',
              helperText: '토큰 발급 성공 시 자동으로 채워집니다. 유효시간은 24시간입니다.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : _issueToken,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.vpn_key_outlined),
                label: const Text('토큰 발급 테스트'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _fetchRecentOrders,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('최근 주문 조회'),
              ),
              OutlinedButton.icon(
                onPressed: _orders.isEmpty ? null : _openOrderPreview,
                icon: const Icon(Icons.view_agenda_outlined),
                label: Text('주문 보기 ${_orders.length}건'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '주문 조회 조건',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sdateController,
                  decoration: const InputDecoration(
                    labelText: '시작일',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _edateController,
                  decoration: const InputDecoration(
                    labelText: '종료일',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _lengthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '개수',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_statusCode != null)
            Text(
              'HTTP $_statusCode',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          if (_result != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              ),
              child: SelectableText(
                _result!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayAutoOrderPreviewScreen extends StatelessWidget {
  const _PlayAutoOrderPreviewScreen({
    required this.orders,
  });

  final List<_PlayAutoOrderPreview> orders;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalQty = orders.fold<int>(0, (sum, order) => sum + order.quantity);

    return Scaffold(
      appBar: AppBar(title: Text('플토 주문 ${orders.length}건')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _PlayAutoSummaryBand(
                orderCount: orders.length,
                totalQty: totalQty,
              ),
            ),
          ),
          SliverList.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = orders[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  index == 0 ? 4 : 0,
                  16,
                  index == orders.length - 1 ? 20 : 0,
                ),
                child: _PlayAutoOrderCard(
                  order: order,
                  statusColor: _statusColor(scheme, order.status),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _statusColor(ColorScheme scheme, String status) {
    if (status.contains('취소') || status.contains('반품')) {
      return scheme.error;
    }
    if (status.contains('완료') || status.contains('결정')) {
      return Colors.green.shade700;
    }
    if (status.contains('배송') || status.contains('출고')) {
      return Colors.blue.shade700;
    }
    return scheme.primary;
  }
}

class _PlayAutoSummaryBand extends StatelessWidget {
  const _PlayAutoSummaryBand({
    required this.orderCount,
    required this.totalQty,
  });

  final int orderCount;
  final int totalQty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(child: _SummaryValue(label: '주문', value: '$orderCount건')),
          Container(width: 1, height: 36, color: scheme.outlineVariant),
          Expanded(child: _SummaryValue(label: '수량', value: '$totalQty개')),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _PlayAutoOrderCard extends StatelessWidget {
  const _PlayAutoOrderCard({
    required this.order,
    required this.statusColor,
  });

  final _PlayAutoOrderPreview order;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (order.optionName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          order.optionName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(label: order.status, color: statusColor),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.storefront_outlined,
                  text: order.shopName,
                ),
                _InfoChip(icon: Icons.person_outline, text: order.customerName),
                _InfoChip(
                  icon: Icons.inventory_2_outlined,
                  text: '${order.quantity}개',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MutedLine(label: '주문번호', value: order.orderNo),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MutedLine(
                    label: '주문일',
                    value: order.orderDate,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            if (order.sku.isNotEmpty) ...[
              const SizedBox(height: 6),
              _MutedLine(label: 'SKU', value: order.sku),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedLine extends StatelessWidget {
  const _MutedLine({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PlayAutoOrderPreview {
  const _PlayAutoOrderPreview({
    required this.orderNo,
    required this.status,
    required this.shopName,
    required this.customerName,
    required this.productName,
    required this.optionName,
    required this.sku,
    required this.quantity,
    required this.orderDate,
  });

  final String orderNo;
  final String status;
  final String shopName;
  final String customerName;
  final String productName;
  final String optionName;
  final String sku;
  final int quantity;
  final String orderDate;

  factory _PlayAutoOrderPreview.fromJson(Map<String, Object?> json) {
    final productName = _pickString(json, const [
      'shop_sale_name',
      'prod_name',
      'product_name',
      'sale_name',
      'goods_name',
      'item_name',
    ]);
    final optionName = _pickString(json, const [
      'shop_opt_name',
      'shop_add_opt_name',
      'opt_name',
      'option_name',
      'attri',
    ]);

    return _PlayAutoOrderPreview(
      orderNo: _pickString(
          json,
          const [
            'shop_ord_no',
            'shop_order_no',
            'ord_no',
            'order_no',
            'bundle_no',
            'uniq',
          ],
          fallback: '-'),
      status: _pickString(
          json,
          const [
            'ord_status',
            'status',
            'order_status',
          ],
          fallback: '상태없음'),
      shopName: _pickString(
          json,
          const [
            'shop_name',
            'mall_name',
            'shop_cd',
            'shop_id',
          ],
          fallback: '판매처 없음'),
      customerName: _pickString(
          json,
          const [
            'order_name',
            'to_name',
            'receiver_name',
            'buyer_name',
            'order_id',
          ],
          fallback: '주문자 없음'),
      productName: productName.isEmpty ? '상품명 없음' : productName,
      optionName: optionName,
      sku: _pickString(json, const [
        'sku_cd',
        'c_sale_cd',
        'shop_sale_no',
        'shop_prod_no',
        'opt_custom_cd',
      ]),
      quantity: _pickInt(json, const [
        'qty',
        'cnt',
        'sale_cnt',
        'order_cnt',
        'ord_cnt',
        'ea',
      ]),
      orderDate: _shortDate(
        _pickString(
            json,
            const [
              'ord_time',
              'pay_time',
              'wdate',
              'mdate',
              'order_date',
            ],
            fallback: '-'),
      ),
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

  static int _pickInt(Map<String, Object?> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.replaceAll(',', '').trim());
        if (parsed != null) return parsed;
      }
    }
    return 1;
  }

  static String _shortDate(String value) {
    if (value.length >= 10) return value.substring(0, 10);
    return value;
  }
}

class _PlayAutoResponse {
  const _PlayAutoResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}
