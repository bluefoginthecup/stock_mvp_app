import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../app/main_tab_controller.dart';
import '../../models/item.dart';
import '../../models/order.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/playauto_item_mapping_service.dart';
import '../../services/playauto_order_link_service.dart';
import '../../ui/common/item_picker_sheet.dart';
import '../stock/stock_new_item_sheet.dart';
import '../stock/widgets/new_item_result.dart';

String _normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[\s\-\(\)\.]'), '').trim();
}

String _playAutoMappingKey(_PlayAutoOrderPreview order) {
  final sku = order.sku.trim();
  final shop = _normalizeSearchText(order.shopName);
  final product = _normalizeSearchText(order.productName);
  final option = _normalizeSearchText(order.optionName);
  final skuPart = sku.isEmpty ? 'nosku' : 'sku::${_normalizeSearchText(sku)}';
  return 'playauto::$shop::$skuPart::product::$product::option::$option';
}

String _playAutoOrderGroupKey(_PlayAutoOrderPreview order) {
  final date = order.orderDate.trim().isEmpty ? '-' : order.orderDate.trim();
  final customer = _normalizeSearchText(order.customerName);
  return 'playauto::date::$date::customer::$customer';
}

class PlayAutoOrderImportScreen extends StatefulWidget {
  const PlayAutoOrderImportScreen({super.key}) : orderViewOnly = false;

  const PlayAutoOrderImportScreen.orderView({super.key}) : orderViewOnly = true;

  final bool orderViewOnly;

  @override
  State<PlayAutoOrderImportScreen> createState() =>
      _PlayAutoOrderImportScreenState();
}

class _PlayAutoOrderImportScreenState extends State<PlayAutoOrderImportScreen> {
  static const _storage = FlutterSecureStorage();
  static const _baseUrlKey = 'playauto_openapi_base_url_v1';
  static const _apiKeyKey = 'playauto_api_key_v1';
  static const _authenticationKeyKey = 'playauto_authentication_key_v1';
  static const _tokenKey = 'playauto_token_v1';
  static const _tokenIssuedAtKey = 'playauto_token_issued_at_v1';
  static const _orderCachePrefix = 'playauto_order_cache_v1';
  static const _tokenLifetime = Duration(hours: 24);

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
  final _workShopCodeController = TextEditingController();
  final _workShopIdsController = TextEditingController();

  var _loading = false;
  var _credentialsLoaded = false;
  var _workAction = 'ScrapOrder';
  List<_PlayAutoOrderPreview> _orders = const [];
  List<_PlayAutoShopAccount> _shopAccounts = const [];
  Set<String> _selectedShopAccountKeys = const {};
  List<String> _lastWorkNos = const [];
  String? _result;
  int? _statusCode;
  DateTime? _tokenIssuedAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    _sdateController.text = _formatDate(weekAgo);
    _edateController.text = _formatDate(now);
    _loadSavedCredentials();
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
    _workShopCodeController.dispose();
    _workShopIdsController.dispose();
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
      final result = await _requestToken(
        apiKey: apiKey,
        authenticationKey: authenticationKey,
        email: email,
        password: password,
      );
      final token = result.token;
      if (token != null) {
        await _storeIssuedToken(token, showMessage: true);
      }

      return _PlayAutoResponse(
        statusCode: result.statusCode,
        body: token == null
            ? result.body
            : '토큰 발급 성공\n\nAuthorization: Token $token\n\n${result.body}',
      );
    }, clearOrders: false);
  }

  Future<_TokenIssueResult> _requestToken({
    required String apiKey,
    required String authenticationKey,
    String email = '',
    String password = '',
  }) async {
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

    return _TokenIssueResult(
      statusCode: response.statusCode,
      body: _prettyBody(response.body),
      token: _readToken(response.body),
    );
  }

  Future<void> _storeIssuedToken(
    String token, {
    bool showMessage = false,
  }) async {
    _tokenController.text = token;
    _tokenController.selection = TextSelection.collapsed(
      offset: _tokenController.text.length,
    );
    _tokenIssuedAt = DateTime.now();
    await _saveCredentials(showMessage: false);
    if (!mounted) return;
    setState(() {});
    if (showMessage) {
      _showSnack('토큰을 자동으로 입력하고 저장했습니다.');
    }
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final baseUrl = await _storage.read(key: _baseUrlKey);
      final apiKey = await _storage.read(key: _apiKeyKey);
      final authenticationKey = await _storage.read(
        key: _authenticationKeyKey,
      );
      final token = await _storage.read(key: _tokenKey);
      final tokenIssuedAtText = await _storage.read(key: _tokenIssuedAtKey);
      final tokenIssuedAt = tokenIssuedAtText == null
          ? null
          : DateTime.tryParse(tokenIssuedAtText);
      final tokenStillValid = tokenIssuedAt != null &&
          DateTime.now().difference(tokenIssuedAt) < _tokenLifetime;

      if (!mounted) return;
      setState(() {
        if (baseUrl != null && baseUrl.isNotEmpty) {
          _baseUrlController.text = baseUrl;
        }
        if (apiKey != null) _apiKeyController.text = apiKey;
        if (authenticationKey != null) {
          _authenticationKeyController.text = authenticationKey;
        }
        if (tokenStillValid && token != null) {
          _tokenController.text = token;
          _tokenIssuedAt = tokenIssuedAt;
        }
        _credentialsLoaded = true;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _credentialsLoaded = true);
      _showSnack('보안 저장소가 아직 준비되지 않았습니다. 앱을 다시 실행해주세요.');
    }
  }

  Future<void> _saveCredentials({bool showMessage = true}) async {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final authenticationKey = _authenticationKeyController.text.trim();
    final token = _tokenController.text.trim();

    if (apiKey.isEmpty && authenticationKey.isEmpty && token.isEmpty) {
      _showSnack('저장할 API Key, 인증키, 토큰이 없습니다.');
      return;
    }

    try {
      if (baseUrl.isNotEmpty) {
        await _storage.write(key: _baseUrlKey, value: baseUrl);
      }
      if (apiKey.isNotEmpty) {
        await _storage.write(key: _apiKeyKey, value: apiKey);
      }
      if (authenticationKey.isNotEmpty) {
        await _storage.write(
          key: _authenticationKeyKey,
          value: authenticationKey,
        );
      }
      if (token.isNotEmpty) {
        final issuedAt = _tokenIssuedAt ?? DateTime.now();
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(
          key: _tokenIssuedAtKey,
          value: issuedAt.toIso8601String(),
        );
        _tokenIssuedAt = issuedAt;
      }
      if (showMessage) _showSnack('플토 인증 정보를 저장했습니다.');
      if (mounted) setState(() {});
    } on MissingPluginException {
      _showSnack('보안 저장소가 아직 준비되지 않았습니다. 앱을 다시 실행해주세요.');
    }
  }

  Future<void> _clearSavedCredentials() async {
    try {
      await _storage.delete(key: _baseUrlKey);
      await _storage.delete(key: _apiKeyKey);
      await _storage.delete(key: _authenticationKeyKey);
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _tokenIssuedAtKey);
      if (!mounted) return;
      setState(() {
        _apiKeyController.clear();
        _authenticationKeyController.clear();
        _tokenController.clear();
        _tokenIssuedAt = null;
      });
      _showSnack('저장된 플토 인증 정보를 삭제했습니다.');
    } on MissingPluginException {
      _showSnack('보안 저장소가 아직 준비되지 않았습니다. 앱을 다시 실행해주세요.');
    }
  }

  Future<_PlayAutoOrderFetchResult> _fetchOrdersFromPlayAuto({
    required String sdate,
    required String edate,
    required int length,
    bool forceRefresh = false,
  }) async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      throw const _PlayAutoUserMessage('API Key를 입력해주세요.');
    }

    if (!forceRefresh) {
      final cached = await _readCachedOrderFetch(
        sdate: sdate,
        edate: edate,
        length: length,
      );
      if (cached != null) return cached;
    }

    final tokenResult = await _ensureTokenForOrderFetch(apiKey);
    if (tokenResult.response != null) {
      return _PlayAutoOrderFetchResult(
        orders: const [],
        statusCode: tokenResult.response!.statusCode,
        body: tokenResult.response!.body,
        fromCache: false,
        fetchedAt: DateTime.now(),
      );
    }
    final token = tokenResult.token!;

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
      headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
      body: jsonEncode(requestBody),
    );
    final orders = _readOrders(response.body);
    await _writeCachedOrderFetch(
      sdate: sdate,
      edate: edate,
      length: length,
      statusCode: response.statusCode,
      responseBody: response.body,
    );

    return _PlayAutoOrderFetchResult(
      orders: orders,
      statusCode: response.statusCode,
      body: [
        '요청 바디',
        const JsonEncoder.withIndent('  ').convert(requestBody),
        '',
        '응답',
        _prettyBody(response.body),
      ].join('\n'),
      fromCache: false,
      fetchedAt: DateTime.now(),
    );
  }

  Future<_PlayAutoOrderFetchResult?> _readCachedOrderFetch({
    required String sdate,
    required String edate,
    required int length,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedText = prefs.getString(
      _orderCacheKey(sdate: sdate, edate: edate, length: length),
    );
    if (cachedText == null || cachedText.isEmpty) return null;

    try {
      final cached = jsonDecode(cachedText) as Map<String, Object?>;
      final responseBody = cached['response_body']?.toString() ?? '';
      final fetchedAt = DateTime.tryParse(
        cached['fetched_at']?.toString() ?? '',
      );
      final statusCode = int.tryParse(cached['status_code']?.toString() ?? '');
      final orders = _readOrders(responseBody);
      return _PlayAutoOrderFetchResult(
        orders: orders,
        statusCode: statusCode,
        body: [
          '캐시 사용',
          if (fetchedAt != null) '저장 시각: ${_formatDateTime(fetchedAt)}',
          '',
          '응답',
          _prettyBody(responseBody),
        ].join('\n'),
        fromCache: true,
        fetchedAt: fetchedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedOrderFetch({
    required String sdate,
    required String edate,
    required int length,
    required int statusCode,
    required String responseBody,
  }) async {
    if (statusCode < 200 || statusCode >= 300) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _orderCacheKey(sdate: sdate, edate: edate, length: length),
      jsonEncode({
        'fetched_at': DateTime.now().toIso8601String(),
        'status_code': statusCode,
        'response_body': responseBody,
      }),
    );
  }

  String _orderCacheKey({
    required String sdate,
    required String edate,
    required int length,
  }) {
    final baseUrl =
        _baseUrlController.text.trim().replaceFirst(RegExp(r'/+$'), '');
    return '$_orderCachePrefix::$baseUrl::wdate::$sdate::$edate::$length';
  }

  Future<void> _fetchShopAccounts() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('API Key를 입력해주세요.');
      return;
    }

    await _runRequest(() async {
      final tokenResult = await _ensureTokenForOrderFetch(apiKey);
      if (tokenResult.response != null) return tokenResult.response!;
      final token = tokenResult.token!;

      final response = await http.get(
        _endpoint('/shops').replace(queryParameters: {'used': 'true'}),
        headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
      );
      final shops = _readShopAccounts(response.body);
      if (mounted) {
        setState(() {
          _shopAccounts = shops;
          _selectedShopAccountKeys = {
            for (final key in _selectedShopAccountKeys)
              if (shops.any((shop) => shop.key == key)) key,
          };
          if (shops.length == 1) _toggleShopAccount(shops.first, true);
        });
      }

      return _PlayAutoResponse(
        statusCode: response.statusCode,
        body: [
          '불러온 쇼핑몰 ${shops.length}건',
          if (shops.isEmpty) '응답 구조에서 쇼핑몰 코드를 찾지 못했습니다.',
          '',
          '요청',
          'GET /shops?used=true',
          '',
          '응답',
          _prettyBody(response.body),
        ].join('\n'),
      );
    }, clearOrders: false);
  }

  Future<void> _registerOrderCollectionWork() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('API Key를 입력해주세요.');
      return;
    }

    final workTargets = _selectedWorkTargets;
    if (workTargets.isEmpty) {
      _showSnack('쇼핑몰 코드와 아이디를 입력하거나 쇼핑몰을 선택해주세요.');
      return;
    }
    final missingIds =
        workTargets.where((target) => target.id.trim().isEmpty).toList();
    if (missingIds.isNotEmpty) {
      _showSnack('선택한 쇼핑몰 중 아이디가 없는 항목이 있습니다. 쇼핑몰 아이디를 입력해주세요.');
      return;
    }

    await _runRequest(() async {
      final tokenResult = await _ensureTokenForOrderFetch(apiKey);
      if (tokenResult.response != null) return tokenResult.response!;
      final token = tokenResult.token!;

      final groupedTargets = _groupWorkTargetsByCode(workTargets);
      final responses = <String>[];
      final workNos = <String>{};
      int? statusCode;

      for (var index = 0; index < groupedTargets.length; index += 1) {
        final entry = groupedTargets.entries.elementAt(index);
        final requestBody = <String, Object?>{
          'act': _workAction,
          'params': {
            'site_code': entry.key,
            'site_id': entry.value.toList(),
          },
        };

        final response = await http.post(
          _endpoint('/work/addWork/v1.2'),
          headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
          body: jsonEncode(requestBody),
        );
        statusCode ??= response.statusCode;
        workNos.addAll(_readWorkNos(response.body));
        responses.add(
          [
            '쇼핑몰 코드 ${entry.key}',
            'HTTP ${response.statusCode}',
            '요청 바디',
            const JsonEncoder.withIndent('  ').convert(requestBody),
            '',
            '응답',
            _prettyBody(response.body),
          ].join('\n'),
        );

        if (index < groupedTargets.length - 1) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }

      if (mounted) {
        setState(() => _lastWorkNos = workNos.toList());
      }

      return _PlayAutoResponse(
        statusCode: statusCode,
        body: [
          if (workNos.isNotEmpty) ...[
            '등록된 작업번호',
            workNos.join(', '),
            '',
          ],
          '등록 요청 ${groupedTargets.length}건',
          '',
          responses.join('\n\n'),
        ].join('\n'),
      );
    }, clearOrders: false);
  }

  Future<void> _fetchLastWorkResult() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('API Key를 입력해주세요.');
      return;
    }
    if (_lastWorkNos.isEmpty) {
      _showSnack('먼저 주문 수집 작업을 실행해주세요.');
      return;
    }

    await _runRequest(() async {
      final tokenResult = await _ensureTokenForOrderFetch(apiKey);
      if (tokenResult.response != null) return tokenResult.response!;
      final token = tokenResult.token!;

      final responses = <String>[];
      int? statusCode;
      for (final workNo in _lastWorkNos) {
        final response = await http.get(
          _endpoint('/work/$workNo'),
          headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
        );
        statusCode ??= response.statusCode;
        responses.add(
          [
            '작업번호 $workNo',
            'HTTP ${response.statusCode}',
            _prettyBody(response.body),
          ].join('\n'),
        );
      }

      return _PlayAutoResponse(
        statusCode: statusCode,
        body: responses.join('\n\n'),
      );
    }, clearOrders: false);
  }

  Future<_TokenReadyResult> _ensureTokenForOrderFetch(String apiKey) async {
    final currentToken = _tokenController.text.trim();
    if (currentToken.isNotEmpty && !_isSavedTokenExpired) {
      return _TokenReadyResult(token: currentToken);
    }

    final authenticationKey = _authenticationKeyController.text.trim();
    if (authenticationKey.isEmpty) {
      return const _TokenReadyResult(
        response: _PlayAutoResponse(
          statusCode: null,
          body: '토큰 자동 발급 불가\n\n솔루션 인증키를 저장하거나 입력해주세요.',
        ),
      );
    }

    final result = await _requestToken(
      apiKey: apiKey,
      authenticationKey: authenticationKey,
    );
    final token = result.token;
    if (token == null) {
      return _TokenReadyResult(
        response: _PlayAutoResponse(
          statusCode: result.statusCode,
          body: '토큰 자동 발급 실패\n\n${result.body}',
        ),
      );
    }

    await _storeIssuedToken(token);
    return _TokenReadyResult(token: token);
  }

  Map<String, String> _authorizedJsonHeaders({
    required String apiKey,
    required String token,
  }) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'Authorization': 'Token $token',
    };
  }

  void _openOrderPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlayAutoOrderPreviewScreen(
          orders: _orders,
          startDate: _sdateController.text.trim(),
          endDate: _edateController.text.trim(),
          length: int.tryParse(_lengthController.text.trim()) ?? 100,
          onFetchOrders: _fetchOrdersForPreview,
        ),
      ),
    );
  }

  Future<_PlayAutoOrderFetchResult> _fetchOrdersForPreview({
    required String sdate,
    required String edate,
    required int length,
    bool forceRefresh = false,
  }) async {
    final result = await _fetchOrdersFromPlayAuto(
      sdate: sdate,
      edate: edate,
      length: length,
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _orders = result.orders;
        _sdateController.text = sdate;
        _edateController.text = edate;
        _lengthController.text = length.toString();
        _statusCode = result.statusCode;
        _result = result.body;
      });
    }
    return result;
  }

  void _toggleShopAccount(_PlayAutoShopAccount shop, bool selected) {
    final keys = {..._selectedShopAccountKeys};
    if (selected) {
      keys.add(shop.key);
    } else {
      keys.remove(shop.key);
    }
    _selectedShopAccountKeys = keys;
    _syncManualTargetFields();
  }

  void _selectAllShopAccounts(bool selected) {
    _selectedShopAccountKeys =
        selected ? _shopAccounts.map((shop) => shop.key).toSet() : const {};
    _syncManualTargetFields();
  }

  void _syncManualTargetFields() {
    final selected = _selectedShopAccounts;
    if (selected.isEmpty) return;
    final firstCode = selected.first.code;
    _workShopCodeController.text = firstCode;
    _workShopIdsController.text = selected
        .where((shop) => shop.code == firstCode && shop.id.isNotEmpty)
        .map((shop) => shop.id)
        .join(', ');
  }

  List<_PlayAutoShopAccount> get _selectedShopAccounts {
    return _shopAccounts
        .where((shop) => _selectedShopAccountKeys.contains(shop.key))
        .toList();
  }

  List<_PlayAutoWorkTarget> get _selectedWorkTargets {
    final selectedTargets = _selectedShopAccounts
        .map((shop) => _PlayAutoWorkTarget(code: shop.code, id: shop.id))
        .toList();
    if (selectedTargets.isNotEmpty) return selectedTargets;

    final manualCode = _workShopCodeController.text.trim();
    if (manualCode.isEmpty) return const [];
    return _readDelimitedValues(_workShopIdsController.text)
        .map((id) => _PlayAutoWorkTarget(code: manualCode, id: id))
        .toList();
  }

  Map<String, Set<String>> _groupWorkTargetsByCode(
    List<_PlayAutoWorkTarget> targets,
  ) {
    final grouped = <String, Set<String>>{};
    for (final target in targets) {
      final code = target.code.trim();
      final id = target.id.trim();
      if (code.isEmpty || id.isEmpty) continue;
      grouped.putIfAbsent(code, () => <String>{}).add(id);
    }
    return grouped;
  }

  Future<void> _runRequest(
    Future<_PlayAutoResponse> Function() request, {
    bool clearOrders = true,
  }) async {
    setState(() {
      _loading = true;
      _statusCode = null;
      _result = null;
      if (clearOrders) _orders = const [];
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

  bool get _isSavedTokenExpired {
    final issuedAt = _tokenIssuedAt;
    if (issuedAt == null || _tokenController.text.trim().isEmpty) return false;
    return DateTime.now().difference(issuedAt) >= _tokenLifetime;
  }

  String get _tokenHelperText {
    final issuedAt = _tokenIssuedAt;
    if (issuedAt == null) {
      return '토큰은 24시간 유효하며, 주문 조회 시 필요하면 자동으로 다시 발급됩니다.';
    }
    final expiresAt = issuedAt.add(_tokenLifetime);
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return '저장된 토큰이 만료됐습니다. 다음 주문 조회 때 자동으로 다시 발급됩니다.';
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return '저장된 토큰 사용 중 · 약 $hours시간 $minutes분 남음';
  }

  String? _readToken(String body) {
    try {
      final decoded = jsonDecode(body);
      return _findTokenValue(decoded);
    } catch (_) {
      return null;
    }
  }

  String? _findTokenValue(Object? node) {
    if (node is Map) {
      for (final key in const ['token', 'access_token', 'auth_token']) {
        final value = node[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      for (final value in node.values) {
        final token = _findTokenValue(value);
        if (token != null) return token;
      }
    }
    if (node is List) {
      for (final value in node) {
        final token = _findTokenValue(value);
        if (token != null) return token;
      }
    }
    return null;
  }

  List<String> _readWorkNos(String body) {
    try {
      final decoded = jsonDecode(body);
      final workNos = <String>{};
      _collectWorkNos(decoded, workNos);
      return workNos.toList();
    } catch (_) {
      return const [];
    }
  }

  List<_PlayAutoShopAccount> _readShopAccounts(String body) {
    try {
      final decoded = jsonDecode(body);
      final accounts = <String, _PlayAutoShopAccount>{};
      _collectShopAccounts(decoded, accounts);
      final list = accounts.values.toList();
      list.sort((a, b) => a.label.compareTo(b.label));
      return list;
    } catch (_) {
      return const [];
    }
  }

  void _collectShopAccounts(
    Object? node,
    Map<String, _PlayAutoShopAccount> accounts, {
    String inheritedCode = '',
    String inheritedName = '',
  }) {
    if (node is List) {
      for (final child in node) {
        _collectShopAccounts(
          child,
          accounts,
          inheritedCode: inheritedCode,
          inheritedName: inheritedName,
        );
      }
      return;
    }
    if (node is! Map) return;

    final map = _stringKeyedMap(node);
    final code = _pickStringFromMap(
        map,
        const [
          'site_code',
          'shop_cd',
          'shop_code',
          'shopCode',
          'mall_code',
          'mall_cd',
          'code',
        ],
        fallback: inheritedCode);
    final name = _pickStringFromMap(
        map,
        const [
          'site_name',
          'shop_name',
          'shopName',
          'mall_name',
          'mallName',
          'name',
          'seller_nick',
          'sellerNick',
          'nickname',
          'nick_name',
          'custom_shop_name',
          'customShopName',
        ],
        fallback: inheritedName);
    final id = _pickStringFromMap(map, const [
      'site_id',
      'shop_id',
      'shopId',
      'id',
      'custom_shop_id',
      'customShopId',
      'mall_id',
      'mallId',
      'account_id',
      'accountId',
      'seller_id',
      'sellerId',
      'login_id',
      'loginId',
    ]);
    if (code.isNotEmpty) {
      final account = _PlayAutoShopAccount(
        code: code,
        id: id,
        name: name,
      );
      accounts[account.key] = account;
    }

    for (final entry in map.entries) {
      final childInheritedCode =
          _looksLikeShopCode(entry.key) ? entry.key : code;
      if (_looksLikeShopCode(entry.key) && entry.value is String) {
        final account = _PlayAutoShopAccount(
          code: entry.key,
          id: '',
          name: entry.value.toString().trim(),
        );
        accounts[account.key] = account;
      }
      _collectShopAccounts(
        entry.value,
        accounts,
        inheritedCode: childInheritedCode,
        inheritedName: name,
      );
    }
  }

  String _pickStringFromMap(
    Map<String, Object?> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  bool _looksLikeShopCode(String value) {
    return RegExp(r'^[A-Z]\d{3}$').hasMatch(value.trim());
  }

  void _collectWorkNos(Object? node, Set<String> workNos) {
    if (node is Map) {
      final value = node['work_no'];
      if (value != null && value.toString().trim().isNotEmpty) {
        workNos.add(value.toString().trim());
      }
      for (final child in node.values) {
        _collectWorkNos(child, workNos);
      }
    }
    if (node is List) {
      for (final child in node) {
        _collectWorkNos(child, workNos);
      }
    }
  }

  List<String> _readDelimitedValues(String value) {
    return value
        .split(RegExp(r'[,\n\r]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<_PlayAutoOrderPreview> _readOrders(String body) {
    try {
      final decoded = jsonDecode(body);
      final rows = _findOrderRows(decoded);
      final orders = rows.map(_PlayAutoOrderPreview.fromJson).toList();
      orders.sort(_compareOrdersNewestFirst);
      return orders;
    } catch (_) {
      return const [];
    }
  }

  int _compareOrdersNewestFirst(
    _PlayAutoOrderPreview a,
    _PlayAutoOrderPreview b,
  ) {
    final aDate = a.sortDate;
    final bDate = b.sortDate;
    if (aDate != null && bDate != null) return bDate.compareTo(aDate);
    if (aDate != null) return -1;
    if (bDate != null) return 1;
    return b.orderNo.compareTo(a.orderNo);
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

  String _formatDateTime(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.orderViewOnly) {
      if (!_credentialsLoaded) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return _PlayAutoOrderPreviewScreen(
        orders: _orders,
        startDate: _sdateController.text.trim(),
        endDate: _edateController.text.trim(),
        length: int.tryParse(_lengthController.text.trim()) ?? 100,
        onFetchOrders: _fetchOrdersForPreview,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('플토 테스트')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_credentialsLoaded) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
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
            decoration: InputDecoration(
              labelText: '발급 토큰',
              helperText: _tokenHelperText,
              border: const OutlineInputBorder(),
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
                onPressed: _loading ? null : _openOrderPreview,
                icon: const Icon(Icons.view_agenda_outlined),
                label: Text(
                  _orders.isEmpty ? '주문 보기' : '주문 보기 ${_orders.length}건',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _saveCredentials(),
                icon: const Icon(Icons.save_outlined),
                label: const Text('인증 정보 저장'),
              ),
              TextButton.icon(
                onPressed: _loading ? null : _clearSavedCredentials,
                icon: const Icon(Icons.delete_outline),
                label: const Text('저장 정보 삭제'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '주문 수집 작업',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '쇼핑몰에서 PlayAuto로 주문 수집을 실행합니다. 등록 후 작업이 완료되면 최근 주문 조회로 새 주문을 확인하세요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _workAction,
            decoration: const InputDecoration(
              labelText: '수집 작업',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'ScrapOrder',
                child: Text('발주확인된 주문 수집'),
              ),
              DropdownMenuItem(
                value: 'ScrapOrderConfirmList',
                child: Text('결제완료 주문 수집'),
              ),
              DropdownMenuItem(
                value: 'ScrapOrderAndConfirmDoit',
                child: Text('발주확인 후 주문 수집'),
              ),
              DropdownMenuItem(
                value: 'SyncOrderState',
                child: Text('주문동기화'),
              ),
            ],
            onChanged: _loading
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _workAction = value);
                  },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _fetchShopAccounts,
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('쇼핑몰 목록 불러오기'),
              ),
              if (_shopAccounts.isNotEmpty)
                Text(
                  '${_shopAccounts.length}개 쇼핑몰 불러옴',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
          if (_shopAccounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '선택 ${_selectedShopAccountKeys.length}개',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _selectAllShopAccounts(
                              _selectedShopAccountKeys.length !=
                                  _shopAccounts.length,
                            );
                          });
                        },
                  icon: Icon(
                    _selectedShopAccountKeys.length == _shopAccounts.length
                        ? Icons.check_box_outlined
                        : Icons.select_all_outlined,
                  ),
                  label: Text(
                    _selectedShopAccountKeys.length == _shopAccounts.length
                        ? '전체 해제'
                        : '전체 선택',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _shopAccounts.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: scheme.outlineVariant),
                itemBuilder: (context, index) {
                  final shop = _shopAccounts[index];
                  final selected = _selectedShopAccountKeys.contains(shop.key);
                  return CheckboxListTile(
                    value: selected,
                    enabled: !_loading,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      shop.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      shop.id.isEmpty
                          ? '${shop.code} · 쇼핑몰 아이디 필요'
                          : '${shop.code} · ${shop.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: (value) {
                      setState(() => _toggleShopAccount(shop, value ?? false));
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _workShopCodeController,
                  decoration: const InputDecoration(
                    labelText: '쇼핑몰 코드',
                    hintText: '예: A001',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _workShopIdsController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '쇼핑몰 아이디',
                    hintText: '여러 개면 쉼표 또는 줄바꿈',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : _registerOrderCollectionWork,
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('주문 수집 실행'),
              ),
              OutlinedButton.icon(
                onPressed: _loading || _lastWorkNos.isEmpty
                    ? null
                    : _fetchLastWorkResult,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  _lastWorkNos.isEmpty
                      ? '작업 결과 확인'
                      : '작업 결과 확인 ${_lastWorkNos.length}건',
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

class _PlayAutoOrderPreviewScreen extends StatefulWidget {
  const _PlayAutoOrderPreviewScreen({
    required this.orders,
    required this.startDate,
    required this.endDate,
    required this.length,
    required this.onFetchOrders,
  });

  final List<_PlayAutoOrderPreview> orders;
  final String startDate;
  final String endDate;
  final int length;
  final Future<_PlayAutoOrderFetchResult> Function({
    required String sdate,
    required String edate,
    required int length,
    bool forceRefresh,
  }) onFetchOrders;

  @override
  State<_PlayAutoOrderPreviewScreen> createState() =>
      _PlayAutoOrderPreviewScreenState();
}

class _PlayAutoOrderPreviewScreenState
    extends State<_PlayAutoOrderPreviewScreen> {
  static const _uuid = Uuid();
  final _searchController = TextEditingController();
  final _mappingService = PlayAutoItemMappingService();
  final _orderLinkService = PlayAutoOrderLinkService();
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _lengthController;
  late List<_PlayAutoOrderPreview> _orders;
  Map<String, PlayAutoItemMapping> _mappings = const {};
  Map<String, Item> _mappedItems = const {};
  Map<String, PlayAutoOrderLink> _orderLinks = const {};
  var _query = '';
  var _loadingOrders = false;
  var _loadingMappings = false;
  var _cacheNotice = '조회 버튼을 누르면 저장된 주문을 먼저 확인합니다.';
  String? _selectedShopName;

  @override
  void initState() {
    super.initState();
    _orders = widget.orders;
    _startDateController = TextEditingController(text: widget.startDate);
    _endDateController = TextEditingController(text: widget.endDate);
    _lengthController = TextEditingController(text: widget.length.toString());
    _loadMappings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filteredOrders = _filteredOrders;
    final totalQty =
        filteredOrders.fold<int>(0, (sum, order) => sum + order.quantity);
    final shopNames = _shopNames;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('플토 주문 ${filteredOrders.length}건'),
            Text(
              '${_startDateController.text} ~ ${_endDateController.text}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OrderQueryPanel(
                    startDateController: _startDateController,
                    endDateController: _endDateController,
                    lengthController: _lengthController,
                    loading: _loadingOrders,
                    onPickStartDate: () => _pickDate(_startDateController),
                    onPickEndDate: () => _pickDate(_endDateController),
                    onFetch: () => _fetchOrders(forceRefresh: false),
                    onRefresh: () => _fetchOrders(forceRefresh: true),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cacheNotice,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _PlayAutoSummaryBand(
                    orderCount: filteredOrders.length,
                    totalQty: totalQty,
                    matchedCount: _matchedCount(filteredOrders),
                    needsMappingCount: _needsMappingCount(filteredOrders),
                    availableCount: _availableCount(filteredOrders),
                    shortageCount: _shortageCount(filteredOrders),
                  ),
                  if (_loadingMappings) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '검색 지우기',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      labelText: '주문자, 주소, 연락처 검색',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  if (shopNames.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('전체'),
                              selected: _selectedShopName == null,
                              onSelected: (_) {
                                setState(() => _selectedShopName = null);
                              },
                            ),
                          ),
                          for (final shopName in shopNames)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(shopName),
                                selected: _selectedShopName == shopName,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedShopName =
                                        _selectedShopName == shopName
                                            ? null
                                            : shopName;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (filteredOrders.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('조건에 맞는 주문이 없습니다.')),
            )
          else
            SliverList.separated(
              itemCount: filteredOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    index == 0 ? 4 : 0,
                    16,
                    index == filteredOrders.length - 1 ? 20 : 0,
                  ),
                  child: _PlayAutoOrderCard(
                    order: order,
                    statusColor: _statusColor(scheme, order.status),
                    mapping: _mappings[_playAutoMappingKey(order)],
                    matchedItem: _matchedItemFor(order),
                    stockStatus: _stockStatusFor(order),
                    orderLink: _orderLinks[_playAutoOrderGroupKey(order)],
                    onTapProduct: () => _openMappingSheet(order),
                    onClearMapping: () => _clearMapping(order),
                    onOpenOrCreateOrder: () =>
                        _openOrCreateChalstockOrder(order),
                    onOpenMatchedItem: () {
                      final itemId =
                          _mappings[_playAutoMappingKey(order)]?.itemId;
                      if (itemId != null) _openMatchedItem(itemId);
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<_PlayAutoOrderPreview> get _filteredOrders {
    final normalizedQuery = _normalizeSearchText(_query);
    return _orders.where((order) {
      final shopMatches =
          _selectedShopName == null || order.shopName == _selectedShopName;
      if (!shopMatches) return false;
      if (normalizedQuery.isEmpty) return true;
      return order.searchText.contains(normalizedQuery);
    }).toList();
  }

  List<String> get _shopNames {
    final names = _orders
        .map((order) => order.shopName.trim())
        .where((name) => name.isNotEmpty && name != '판매처 없음')
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  int _matchedCount(List<_PlayAutoOrderPreview> orders) {
    return orders
        .where((order) =>
            _mappings[_playAutoMappingKey(order)]?.isConfirmed == true)
        .length;
  }

  int _needsMappingCount(List<_PlayAutoOrderPreview> orders) {
    return orders
        .where((order) =>
            _mappings[_playAutoMappingKey(order)]?.isConfirmed != true)
        .length;
  }

  int _availableCount(List<_PlayAutoOrderPreview> orders) {
    return orders
        .where((order) => _stockStatusFor(order)?.isAvailable == true)
        .length;
  }

  int _shortageCount(List<_PlayAutoOrderPreview> orders) {
    return orders
        .where((order) => _stockStatusFor(order)?.hasShortage == true)
        .length;
  }

  Item? _matchedItemFor(_PlayAutoOrderPreview order) {
    final mapping = _mappings[_playAutoMappingKey(order)];
    final itemId = mapping?.itemId;
    if (itemId == null) return null;
    return _mappedItems[itemId];
  }

  _PlayAutoStockStatus? _stockStatusFor(_PlayAutoOrderPreview order) {
    final mapping = _mappings[_playAutoMappingKey(order)];
    if (mapping?.isConfirmed != true) return null;
    final item = _matchedItemFor(order);
    if (item == null) return null;
    final shortage =
        (order.quantity - item.qty).clamp(0, order.quantity).toInt();
    return _PlayAutoStockStatus(
      item: item,
      orderQty: order.quantity,
      stockQty: item.qty,
      shortageQty: shortage,
    );
  }

  Future<void> _loadMappings() async {
    if (_orders.isEmpty) {
      setState(() {
        _mappings = const {};
        _mappedItems = const {};
        _orderLinks = const {};
      });
      return;
    }
    setState(() => _loadingMappings = true);
    try {
      final itemRepo = context.read<ItemRepo>();
      final mappings = await _mappingService.listByKeys(
        _orders.map(_playAutoMappingKey),
      );
      final orderLinks = await _orderLinkService.listByOrderNos(
        _orders.map(_playAutoOrderGroupKey),
      );
      final itemIds = mappings.values
          .where((mapping) => mapping.isConfirmed)
          .map((mapping) => mapping.itemId)
          .whereType<String>()
          .toSet();
      final itemEntries = await Future.wait(
        itemIds.map((itemId) async {
          final item = await itemRepo.getItemById(itemId);
          return MapEntry(itemId, item);
        }),
      );
      final itemsById = <String, Item>{
        for (final entry in itemEntries)
          if (entry.value != null) entry.key: entry.value!,
      };
      if (!mounted) return;
      setState(() {
        _mappings = mappings;
        _mappedItems = itemsById;
        _orderLinks = orderLinks;
      });
    } finally {
      if (mounted) setState(() => _loadingMappings = false);
    }
  }

  Future<void> _openMappingSheet(_PlayAutoOrderPreview order) async {
    final itemRepo = context.read<ItemRepo>();
    final mappingKey = _playAutoMappingKey(order);
    final current = _mappings[mappingKey];
    final items = await itemRepo.listItems();
    if (!mounted) return;
    final selected = await showModalBottomSheet<_PlayAutoMappingSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlayAutoItemMappingSheet(
        order: order,
        currentMapping: current,
        candidates: _rankCandidates(order, items),
      ),
    );
    if (selected == null || !mounted) return;

    var itemId = selected.itemId;
    if (selected.createNew) {
      final item = await _openNewItemSheetForMapping();
      if (item == null || !mounted) return;
      itemId = item.id;
    }
    if (selected.openPicker) {
      itemId = await showItemPickerSheet(
        context,
        initialItemId: current?.itemId,
        title: '매칭할 찰스톡 아이템 검색',
      );
      if (itemId == null || !mounted) return;
    }
    if (itemId == null) return;

    await _mappingService.saveConfirmed(
      externalKey: mappingKey,
      productName: order.productName,
      optionName: order.optionName,
      sku: order.sku,
      shopName: order.shopName,
      itemId: itemId,
    );
    await _loadMappings();
    _showSnack('플토 상품 매칭을 저장했습니다.');
  }

  Future<Item?> _openNewItemSheetForMapping() async {
    final itemRepo = context.read<ItemRepo>();
    final rootId = await _findUncategorizedRootId();
    final initialPathIds = [
      if (rootId != null) rootId,
    ];
    if (!mounted) return null;

    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StockNewItemSheet(pathIds: initialPathIds),
    );
    if (result == null) return null;

    final resolved = switch (result) {
      NewItemResult() => result,
      Item() => NewItemResult(result, initialPathIds),
      _ => null,
    };
    if (resolved == null) {
      _showSnack('아이템 생성 결과를 확인할 수 없습니다.');
      return null;
    }

    final l1 = resolved.pathIds.isNotEmpty ? resolved.pathIds[0] : null;
    final l2 = resolved.pathIds.length > 1 ? resolved.pathIds[1] : null;
    final l3 = resolved.pathIds.length > 2 ? resolved.pathIds[2] : null;
    final dyn = itemRepo as dynamic;
    if (l1 != null && dyn.upsertItemWithPath is Function) {
      await dyn.upsertItemWithPath(resolved.item, l1, l2, l3);
    } else {
      await itemRepo.upsertItem(resolved.item);
    }
    _showSnack('새 아이템으로 추가하고 매칭했습니다.');
    return resolved.item;
  }

  Future<String?> _findUncategorizedRootId() async {
    final folderRepo = context.read<FolderTreeRepo>();
    final roots = await folderRepo.listFolderChildren(null);
    for (final root in roots) {
      final id = root.id.trim().toLowerCase();
      final name = root.name.trim().toLowerCase();
      if (id == 'uncategorized' || name == 'uncategorized') {
        return root.id;
      }
    }
    return null;
  }

  Future<void> _clearMapping(_PlayAutoOrderPreview order) async {
    await _mappingService.delete(_playAutoMappingKey(order));
    await _loadMappings();
    _showSnack('매칭을 해제했습니다.');
  }

  Future<void> _openOrCreateChalstockOrder(
    _PlayAutoOrderPreview order,
  ) async {
    final groupKey = _playAutoOrderGroupKey(order);
    final existing = _orderLinks[groupKey];
    if (existing != null) {
      _openChalstockOrder(existing.orderId);
      return;
    }

    final grouped = _orders
        .where((candidate) => _playAutoOrderGroupKey(candidate) == groupKey)
        .toList();
    if (grouped.isEmpty) return;

    final missing = grouped.where((line) {
      final mapping = _mappings[_playAutoMappingKey(line)];
      return mapping?.isConfirmed != true || mapping?.itemId == null;
    }).toList();
    if (missing.isNotEmpty) {
      _showSnack('같은 플토 주문번호 안에 매칭 안 된 상품이 있습니다.');
      return;
    }

    final orderId = 'ord_${_uuid.v4()}';
    final lines = grouped.map((line) {
      final mapping = _mappings[_playAutoMappingKey(line)]!;
      return OrderLine(
        id: _uuid.v4(),
        itemId: mapping.itemId!,
        qty: line.quantity,
      );
    }).toList();
    final first = grouped.first;
    final orderNos = grouped
        .map((line) => line.orderNo.trim())
        .where((orderNo) => orderNo.isNotEmpty && orderNo != '-')
        .toSet()
        .toList();
    final memo = [
      '플토 주문묶음: ${first.orderDate} / ${first.customerName}',
      if (orderNos.isNotEmpty) '플토 주문번호: ${orderNos.join(', ')}',
      '판매처: ${first.shopName}',
      if (first.phone.isNotEmpty) '연락처: ${first.phone}',
      if (first.address.isNotEmpty) '주소: ${first.address}',
      '',
      '플토 주문상품',
      for (final line in grouped)
        '- ${line.productName}'
            '${line.optionName.isEmpty ? '' : ' / ${line.optionName}'}'
            ' x ${line.quantity}',
    ].join('\n');
    final chalstockOrder = Order(
      id: orderId,
      date: first.sortDate ?? DateTime.now(),
      customer: first.customerName,
      memo: memo,
      status: OrderStatus.planned,
      lines: lines,
    );

    await context.read<OrderRepo>().upsertOrder(chalstockOrder);
    await _orderLinkService.save(
      externalOrderNo: groupKey,
      orderId: orderId,
      shopName: first.shopName,
    );
    await _loadMappings();
    _openChalstockOrder(orderId);
  }

  void _openChalstockOrder(String orderId) {
    context.read<MainTabController>().openShellRoute(
          '/orders/detail',
          arguments: orderId,
          tabIndex: 1,
        );
  }

  void _openMatchedItem(String itemId) {
    context.read<MainTabController>().openShellRoute(
          '/items/detail',
          arguments: itemId,
          tabIndex: 2,
        );
  }

  List<_PlayAutoItemCandidate> _rankCandidates(
    _PlayAutoOrderPreview order,
    List<Item> items,
  ) {
    final orderText = _normalizeSearchText(
      '${order.productName} ${order.optionName} ${order.sku}',
    );
    final productOnly = _normalizeSearchText(order.productName);
    final optionOnly = _normalizeSearchText(order.optionName);
    final scored = <_PlayAutoItemCandidate>[];

    for (final item in items) {
      final itemText = _normalizeSearchText(
        '${item.name} ${item.displayName ?? ''} ${item.sku} '
        '${item.folder} ${item.subfolder ?? ''} ${item.subsubfolder ?? ''}',
      );
      var score = 0;
      if (order.sku.isNotEmpty &&
          _normalizeSearchText(item.sku) == _normalizeSearchText(order.sku)) {
        score += 120;
      }
      if (orderText.isNotEmpty && itemText.contains(orderText)) score += 90;
      if (productOnly.isNotEmpty && itemText.contains(productOnly)) score += 50;
      if (optionOnly.isNotEmpty && itemText.contains(optionOnly)) score += 25;
      for (final token in _candidateTokens(order)) {
        if (itemText.contains(token)) score += token.length >= 3 ? 12 : 6;
      }
      if (item.kind == 'Finished') score += 5;
      if (score > 0) {
        scored.add(_PlayAutoItemCandidate(item: item, score: score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.item.name.compareTo(b.item.name);
    });
    return scored.take(5).toList();
  }

  List<String> _candidateTokens(_PlayAutoOrderPreview order) {
    final raw = '${order.productName} ${order.optionName}'
        .replaceAll(RegExp(r'[\[\]\(\),/|]+'), ' ');
    return raw
        .split(RegExp(r'\s+'))
        .map(_normalizeSearchText)
        .where((token) => token.length >= 2)
        .toSet()
        .toList();
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

  Future<void> _pickDate(TextEditingController controller) async {
    final initialDate = DateTime.tryParse(controller.text.trim()) ??
        DateTime.tryParse(_endDateController.text.trim()) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: '주문 조회 날짜 선택',
    );
    if (picked == null) return;
    setState(() => controller.text = _formatDate(picked));
  }

  Future<void> _fetchOrders({required bool forceRefresh}) async {
    final sdate = _startDateController.text.trim();
    final edate = _endDateController.text.trim();
    final length = int.tryParse(_lengthController.text.trim());
    if (length == null || length <= 0 || length > 3000) {
      _showSnack('조회 개수는 1~3000 사이로 입력해주세요.');
      return;
    }
    final startDate = DateTime.tryParse(sdate);
    final endDate = DateTime.tryParse(edate);
    if (startDate == null || endDate == null) {
      _showSnack('조회 날짜는 YYYY-MM-DD 형식으로 선택해주세요.');
      return;
    }
    if (startDate.isAfter(endDate)) {
      _showSnack('시작일은 종료일보다 늦을 수 없습니다.');
      return;
    }

    setState(() => _loadingOrders = true);
    try {
      final result = await widget.onFetchOrders(
        sdate: sdate,
        edate: edate,
        length: length,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _orders = result.orders;
        _selectedShopName = null;
        _cacheNotice = result.notice;
      });
      await _loadMappings();
    } on _PlayAutoUserMessage catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack('주문 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
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
}

class _PlayAutoSummaryBand extends StatelessWidget {
  const _PlayAutoSummaryBand({
    required this.orderCount,
    required this.totalQty,
    required this.matchedCount,
    required this.needsMappingCount,
    required this.availableCount,
    required this.shortageCount,
  });

  final int orderCount;
  final int totalQty;
  final int matchedCount;
  final int needsMappingCount;
  final int availableCount;
  final int shortageCount;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = constraints.maxWidth < 420
              ? (constraints.maxWidth - 10) / 2
              : (constraints.maxWidth - 20) / 3;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryValue(
                label: '주문',
                value: '$orderCount건',
                width: tileWidth,
              ),
              _SummaryValue(
                label: '수량',
                value: '$totalQty개',
                width: tileWidth,
              ),
              _SummaryValue(
                label: '매칭 완료',
                value: '$matchedCount건',
                width: tileWidth,
              ),
              _SummaryValue(
                label: '매칭 필요',
                value: '$needsMappingCount건',
                width: tileWidth,
              ),
              _SummaryValue(
                label: '출고 가능',
                value: '$availableCount건',
                width: tileWidth,
              ),
              _SummaryValue(
                label: '재고 부족',
                value: '$shortageCount건',
                width: tileWidth,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    this.width,
  });

  final String label;
  final String value;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _OrderQueryPanel extends StatelessWidget {
  const _OrderQueryPanel({
    required this.startDateController,
    required this.endDateController,
    required this.lengthController,
    required this.loading,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onFetch,
    required this.onRefresh,
  });

  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final TextEditingController lengthController;
  final bool loading;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onFetch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: TextField(
              controller: startDateController,
              readOnly: true,
              onTap: onPickStartDate,
              decoration: InputDecoration(
                labelText: '시작일',
                suffixIcon: IconButton(
                  tooltip: '시작일 선택',
                  onPressed: onPickStartDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              controller: endDateController,
              readOnly: true,
              onTap: onPickEndDate,
              decoration: InputDecoration(
                labelText: '종료일',
                suffixIcon: IconButton(
                  tooltip: '종료일 선택',
                  onPressed: onPickEndDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 98,
            child: TextField(
              controller: lengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '개수',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: loading ? null : onFetch,
            icon: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open_outlined),
            label: const Text('조회'),
          ),
          OutlinedButton.icon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.sync_outlined),
            label: const Text('새로고침'),
          ),
          const Chip(
            avatar: Icon(Icons.event_available_outlined, size: 18),
            label: Text('수집일 기준'),
          ),
        ],
      ),
    );
  }
}

class _PlayAutoOrderCard extends StatelessWidget {
  const _PlayAutoOrderCard({
    required this.order,
    required this.statusColor,
    required this.mapping,
    required this.matchedItem,
    required this.stockStatus,
    required this.orderLink,
    required this.onTapProduct,
    required this.onClearMapping,
    required this.onOpenOrCreateOrder,
    required this.onOpenMatchedItem,
  });

  final _PlayAutoOrderPreview order;
  final Color statusColor;
  final PlayAutoItemMapping? mapping;
  final Item? matchedItem;
  final _PlayAutoStockStatus? stockStatus;
  final PlayAutoOrderLink? orderLink;
  final VoidCallback onTapProduct;
  final VoidCallback onClearMapping;
  final VoidCallback onOpenOrCreateOrder;
  final VoidCallback onOpenMatchedItem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final linked = mapping?.isConfirmed == true;

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
                  child: InkWell(
                    onTap: onTapProduct,
                    onLongPress: linked ? onClearMapping : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (order.optionName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              order.optionName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusPill(label: order.status, color: statusColor),
                    if (mapping?.isConfirmed == true) ...[
                      const SizedBox(height: 6),
                      _StockStatusPill(status: stockStatus),
                      const SizedBox(height: 6),
                      ActionChip(
                        label: const Text('찰스톡 주문'),
                        onPressed: onOpenOrCreateOrder,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        side: BorderSide(
                          color: scheme.primary.withValues(alpha: 0.35),
                        ),
                        backgroundColor:
                            scheme.primaryContainer.withValues(alpha: 0.18),
                        labelStyle:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (mapping?.isConfirmed == true) ...[
              const SizedBox(height: 10),
              _MatchedItemRow(
                itemId: mapping!.itemId!,
                item: matchedItem,
                stockStatus: stockStatus,
                onTap: onOpenMatchedItem,
              ),
            ],
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
            if (order.invoiceNo.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DeliveryTrackingRow(order: order),
            ],
            if (order.phone.isNotEmpty) ...[
              const SizedBox(height: 6),
              _MutedLine(label: '연락처', value: order.phone),
            ],
            if (order.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              _MutedLine(label: '주소', value: order.address),
            ],
          ],
        ),
      ),
    );
  }
}

class _StockStatusPill extends StatelessWidget {
  const _StockStatusPill({required this.status});

  final _PlayAutoStockStatus? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (status == null) {
      return _StatusPill(label: '재고 확인중', color: scheme.outline);
    }
    if (status!.isAvailable) {
      return _StatusPill(label: '출고 가능', color: Colors.blue.shade700);
    }
    return _StatusPill(label: '재고 부족', color: scheme.error);
  }
}

class _MatchedItemRow extends StatelessWidget {
  const _MatchedItemRow({
    required this.itemId,
    required this.item,
    required this.stockStatus,
    required this.onTap,
  });

  final String itemId;
  final Item? item;
  final _PlayAutoStockStatus? stockStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedItem = stockStatus?.item ?? item;
    final title = resolvedItem == null
        ? '찰스톡 아이템 불러오는 중'
        : resolvedItem.displayName ?? resolvedItem.name;
    final subtitle = resolvedItem == null
        ? itemId
        : [
            if (resolvedItem.sku.isNotEmpty) resolvedItem.sku,
            if (stockStatus == null)
              '재고 ${resolvedItem.qty}${resolvedItem.unit}'
            else
              '주문 ${stockStatus!.orderQty}개',
            if (stockStatus != null)
              '현재고 ${stockStatus!.stockQty}${resolvedItem.unit}',
            if (stockStatus != null)
              '부족 ${stockStatus!.shortageQty}${resolvedItem.unit}',
          ].join(' · ');
    final hasShortage = stockStatus?.hasShortage == true;
    final accent = hasShortage ? scheme.error : Colors.green.shade700;

    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                hasShortage
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
                color: accent,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryTrackingRow extends StatelessWidget {
  const _DeliveryTrackingRow({
    required this.order,
  });

  final _PlayAutoOrderPreview order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final carrier = order.carrierName.isEmpty ? '택배사 없음' : order.carrierName;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 330;
          return Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      carrier,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      order.invoiceNo,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox.square(
                dimension: 38,
                child: IconButton.filledTonal(
                  tooltip: '운송장 복사',
                  onPressed: () => _copyInvoice(context),
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              if (compact)
                SizedBox.square(
                  dimension: 38,
                  child: IconButton.filled(
                    tooltip: '배송조회',
                    onPressed: () => _openTracking(context),
                    icon: const Icon(Icons.open_in_new, size: 19),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: () => _openTracking(context),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('배송조회'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(104, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: Theme.of(context).textTheme.labelMedium,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _copyInvoice(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: order.invoiceNo));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('운송장 번호를 복사했습니다.')),
    );
  }

  Future<void> _openTracking(BuildContext context) async {
    final uri = _trackingUri(order.carrierName, order.invoiceNo);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('배송조회 페이지를 열 수 없습니다.')),
    );
  }

  Uri _trackingUri(String carrierName, String invoiceNo) {
    final trackerCarrierId = _trackerDeliveryCarrierId(carrierName);
    if (trackerCarrierId == null) {
      return Uri.https('tracker.delivery', '/');
    }
    return Uri(
      scheme: 'https',
      host: 'tracker.delivery',
      fragment: '/$trackerCarrierId/$invoiceNo',
    );
  }

  String? _trackerDeliveryCarrierId(String carrierName) {
    final normalized =
        carrierName.toLowerCase().replaceAll(RegExp(r'[\s\-\_\(\)\[\]\.]'), '');

    if (normalized.contains('cj') ||
        normalized.contains('대한통운') ||
        normalized.contains('씨제이')) {
      return 'kr.cjlogistics';
    }
    if (normalized.contains('우체국') ||
        normalized.contains('epost') ||
        normalized.contains('postoffice')) {
      return 'kr.epost';
    }
    if (normalized.contains('한진') || normalized.contains('hanjin')) {
      return 'kr.hanjin';
    }
    if (normalized.contains('롯데') ||
        normalized.contains('lotte') ||
        normalized.contains('현대택배')) {
      return 'kr.lotte';
    }
    if (normalized.contains('로젠') || normalized.contains('logen')) {
      return 'kr.logen';
    }
    if (normalized.contains('편의점') ||
        normalized.contains('cvsnet') ||
        normalized.contains('gs25') ||
        normalized.contains('gs네트웍스')) {
      return 'kr.cvsnet';
    }
    if (normalized.contains('cupost') ||
        normalized.contains('cu택배') ||
        normalized.contains('cu편의점')) {
      return 'kr.cupost';
    }
    if (normalized.contains('경동') || normalized.contains('kdexp')) {
      return 'kr.kdexp';
    }
    if (normalized.contains('대신') || normalized.contains('daesin')) {
      return 'kr.daesin';
    }
    if (normalized.contains('일양') || normalized.contains('ilyang')) {
      return 'kr.ilyanglogis';
    }
    if (normalized.contains('건영') || normalized.contains('kunyoung')) {
      return 'kr.kunyoung';
    }
    if (normalized.contains('천일') || normalized.contains('chunil')) {
      return 'kr.chunilps';
    }
    return null;
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

class _PlayAutoItemMappingSheet extends StatelessWidget {
  const _PlayAutoItemMappingSheet({
    required this.order,
    required this.currentMapping,
    required this.candidates,
  });

  final _PlayAutoOrderPreview order;
  final PlayAutoItemMapping? currentMapping;
  final List<_PlayAutoItemCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 4,
          bottom: 16 + viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '찰스톡 아이템 매칭',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (order.optionName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        order.optionName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: Icons.inventory_2_outlined,
                          text: '${order.quantity}개',
                        ),
                        if (order.sku.isNotEmpty)
                          _InfoChip(icon: Icons.qr_code_2, text: order.sku),
                        _InfoChip(
                          icon: Icons.storefront_outlined,
                          text: order.shopName,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '추천 후보',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (candidates.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    '추천 후보가 없습니다. 직접 검색으로 연결해주세요.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      final item = candidate.item;
                      final selected = currentMapping?.itemId == item.id;
                      return _PlayAutoCandidateTile(
                        candidate: candidate,
                        selected: selected,
                        onMatch: () => Navigator.pop(
                          context,
                          _PlayAutoMappingSheetResult.item(item.id),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const _PlayAutoMappingSheetResult.openPicker(),
                      ),
                      icon: const Icon(Icons.search),
                      label: const Text('직접 검색'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.pop(
                        context,
                        const _PlayAutoMappingSheetResult.createNew(),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('새 아이템'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayAutoCandidateTile extends StatelessWidget {
  const _PlayAutoCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onMatch,
  });

  final _PlayAutoItemCandidate candidate;
  final bool selected;
  final VoidCallback onMatch;

  @override
  Widget build(BuildContext context) {
    final item = candidate.item;
    final scheme = Theme.of(context).colorScheme;
    final title = item.displayName ?? item.name;
    final path = [
      item.folder,
      if ((item.subfolder ?? '').isNotEmpty) item.subfolder!,
      if ((item.subsubfolder ?? '').isNotEmpty) item.subsubfolder!,
    ].where((part) => part.trim().isNotEmpty).join(' / ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.inventory_2_outlined,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (item.sku.isNotEmpty) item.sku,
                    if (path.isNotEmpty) path,
                    '재고 ${item.qty}${item.unit}',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onMatch,
            child: Text(selected ? '선택됨' : '매칭'),
          ),
        ],
      ),
    );
  }
}

class _PlayAutoMappingSheetResult {
  const _PlayAutoMappingSheetResult.item(this.itemId)
      : openPicker = false,
        createNew = false;

  const _PlayAutoMappingSheetResult.openPicker()
      : itemId = null,
        openPicker = true,
        createNew = false;

  const _PlayAutoMappingSheetResult.createNew()
      : itemId = null,
        openPicker = false,
        createNew = true;

  final String? itemId;
  final bool openPicker;
  final bool createNew;
}

class _PlayAutoItemCandidate {
  const _PlayAutoItemCandidate({
    required this.item,
    required this.score,
  });

  final Item item;
  final int score;
}

class _PlayAutoStockStatus {
  const _PlayAutoStockStatus({
    required this.item,
    required this.orderQty,
    required this.stockQty,
    required this.shortageQty,
  });

  final Item item;
  final int orderQty;
  final int stockQty;
  final int shortageQty;

  bool get isAvailable => shortageQty == 0;
  bool get hasShortage => shortageQty > 0;
}

class _PlayAutoShopAccount {
  const _PlayAutoShopAccount({
    required this.code,
    required this.id,
    required this.name,
  });

  final String code;
  final String id;
  final String name;

  String get key => '$code::$id';

  String get title => name.isEmpty ? '쇼핑몰명 없음' : name;

  String get label {
    if (id.isEmpty) return '$title · $code';
    return '$title · $code · $id';
  }
}

class _PlayAutoWorkTarget {
  const _PlayAutoWorkTarget({
    required this.code,
    required this.id,
  });

  final String code;
  final String id;
}

class _PlayAutoOrderPreview {
  const _PlayAutoOrderPreview({
    required this.orderNo,
    required this.status,
    required this.shopName,
    required this.customerName,
    required this.address,
    required this.phone,
    required this.productName,
    required this.optionName,
    required this.sku,
    required this.carrierName,
    required this.invoiceNo,
    required this.quantity,
    required this.orderDate,
    required this.sortDate,
  });

  final String orderNo;
  final String status;
  final String shopName;
  final String customerName;
  final String address;
  final String phone;
  final String productName;
  final String optionName;
  final String sku;
  final String carrierName;
  final String invoiceNo;
  final int quantity;
  final String orderDate;
  final DateTime? sortDate;

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

    final dateValue = _pickString(
      json,
      const [
        'ord_time',
        'pay_time',
        'wdate',
        'mdate',
        'order_date',
      ],
      fallback: '-',
    );

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
      address: _joinNonEmpty([
        _pickString(json, const [
          'addr',
          'address',
          'to_addr',
          'receiver_addr',
          'recipient_addr',
          'delivery_addr',
          'ship_addr',
        ]),
        _pickString(json, const [
          'addr_detail',
          'address_detail',
          'to_addr_detail',
          'receiver_addr_detail',
          'delivery_addr_detail',
          'ship_addr_detail',
        ]),
      ]),
      phone: _joinNonEmpty([
        _pickString(json, const [
          'tel',
          'phone',
          'mobile',
          'hp',
          'cellphone',
          'to_tel',
          'to_mobile',
          'receiver_tel',
          'receiver_mobile',
          'buyer_tel',
          'order_tel',
        ]),
        _pickString(json, const [
          'tel2',
          'phone2',
          'to_tel2',
          'receiver_tel2',
        ]),
      ]),
      productName: productName.isEmpty ? '상품명 없음' : productName,
      optionName: optionName,
      sku: _pickString(json, const [
        'sku_cd',
        'c_sale_cd',
        'shop_sale_no',
        'shop_prod_no',
        'opt_custom_cd',
      ]),
      carrierName: _pickString(json, const [
        'carr_name',
        'carrier_name',
        'delivery_company',
        'delivery_company_name',
        'shipping_company',
        'ship_company',
        'courier',
        'courier_name',
      ]),
      invoiceNo: _pickString(json, const [
        'invoice_no',
        'invoiceNo',
        'tracking_no',
        'trackingNo',
        'waybill_no',
        'waybillNo',
        'delivery_no',
        'deliveryNo',
        'ship_no',
        'shipNo',
      ]),
      quantity: _pickInt(json, const [
        'qty',
        'cnt',
        'sale_cnt',
        'order_cnt',
        'ord_cnt',
        'ea',
      ]),
      orderDate: _shortDate(dateValue),
      sortDate: _parseDate(dateValue),
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

  String get searchText => _normalizeSearchText(
        [
          customerName,
          address,
          phone,
          shopName,
          orderNo,
          productName,
          optionName,
          sku,
          carrierName,
          invoiceNo,
        ].join(' '),
      );

  static String _joinNonEmpty(List<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
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

  static DateTime? _parseDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == '-') return null;
    final isoLike =
        normalized.replaceFirst(' ', 'T').replaceAll(RegExp(r'\.\d+$'), '');
    return DateTime.tryParse(isoLike) ??
        DateTime.tryParse(
            normalized.substring(0, normalized.length.clamp(0, 10)));
  }
}

class _PlayAutoResponse {
  const _PlayAutoResponse({
    required this.statusCode,
    required this.body,
  });

  final int? statusCode;
  final String body;
}

class _PlayAutoOrderFetchResult {
  const _PlayAutoOrderFetchResult({
    required this.orders,
    required this.statusCode,
    required this.body,
    required this.fromCache,
    this.fetchedAt,
  });

  final List<_PlayAutoOrderPreview> orders;
  final int? statusCode;
  final String body;
  final bool fromCache;
  final DateTime? fetchedAt;

  String get notice {
    final time = fetchedAt == null ? '' : ' · ${_formatNoticeTime(fetchedAt!)}';
    return fromCache ? '캐시 사용$time' : 'PlayAuto API 호출$time';
  }

  static String _formatNoticeTime(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}

class _PlayAutoUserMessage implements Exception {
  const _PlayAutoUserMessage(this.message);

  final String message;

  @override
  String toString() => message;
}

class _TokenIssueResult {
  const _TokenIssueResult({
    required this.statusCode,
    required this.body,
    required this.token,
  });

  final int statusCode;
  final String body;
  final String? token;
}

class _TokenReadyResult {
  const _TokenReadyResult({
    this.token,
    this.response,
  });

  final String? token;
  final _PlayAutoResponse? response;
}
