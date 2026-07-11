import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

String _normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[\s\-\(\)\.]'), '').trim();
}

class PlayAutoOrderImportScreen extends StatefulWidget {
  const PlayAutoOrderImportScreen({super.key});

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

  Future<void> _fetchRecentOrders() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('API Key를 입력해주세요.');
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
      final tokenResult = await _ensureTokenForOrderFetch(apiKey);
      if (tokenResult.response != null) return tokenResult.response!;
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
                onPressed: _loading ? null : _fetchRecentOrders,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('최근 주문 조회'),
              ),
              OutlinedButton.icon(
                onPressed: _orders.isEmpty ? null : _openOrderPreview,
                icon: const Icon(Icons.view_agenda_outlined),
                label: Text('주문 보기 ${_orders.length}건'),
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
  });

  final List<_PlayAutoOrderPreview> orders;

  @override
  State<_PlayAutoOrderPreviewScreen> createState() =>
      _PlayAutoOrderPreviewScreenState();
}

class _PlayAutoOrderPreviewScreenState
    extends State<_PlayAutoOrderPreviewScreen> {
  final _searchController = TextEditingController();
  var _query = '';
  String? _selectedShopName;

  @override
  void dispose() {
    _searchController.dispose();
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
      appBar: AppBar(title: Text('플토 주문 ${filteredOrders.length}건')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlayAutoSummaryBand(
                    orderCount: filteredOrders.length,
                    totalQty: totalQty,
                  ),
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
    return widget.orders.where((order) {
      final shopMatches =
          _selectedShopName == null || order.shopName == _selectedShopName;
      if (!shopMatches) return false;
      if (normalizedQuery.isEmpty) return true;
      return order.searchText.contains(normalizedQuery);
    }).toList();
  }

  List<String> get _shopNames {
    final names = widget.orders
        .map((order) => order.shopName.trim())
        .where((name) => name.isNotEmpty && name != '판매처 없음')
        .toSet()
        .toList();
    names.sort();
    return names;
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
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, size: 18, color: scheme.primary),
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
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: '운송장 복사',
            onPressed: () => _copyInvoice(context),
            icon: const Icon(Icons.copy_outlined),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => _openTracking(context),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('배송조회'),
          ),
        ],
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
