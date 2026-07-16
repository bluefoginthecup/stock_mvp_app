import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/main_tab_controller.dart';
import '../../models/calendar_event.dart';
import '../../models/item.dart';
import '../../models/order.dart';
import '../../models/quote.dart';
import '../../models/quote_line.dart';
import '../../models/suppliers.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/order_planning_service.dart';
import '../../services/playauto_item_mapping_service.dart';
import '../../services/playauto_order_link_service.dart';
import '../../ui/common/common_calendar_view.dart';
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

String _playAutoOrderIdentityKey(_PlayAutoOrderPreview order) {
  final primary = [
    order.bundleNo,
    order.uniq,
    order.orderNo,
  ].map((value) => value.trim()).firstWhere(
        (value) => value.isNotEmpty && value != '-',
        orElse: () => '',
      );
  if (primary.isNotEmpty) return _normalizeSearchText(primary);
  return _normalizeSearchText([
    order.orderDate,
    order.shopName,
    order.customerName,
    order.productName,
    order.optionName,
  ].join('::'));
}

bool _samePlayAutoOrder(
  _PlayAutoOrderPreview left,
  _PlayAutoOrderPreview right,
) {
  final leftKeys = {
    left.bundleNo.trim(),
    left.uniq.trim(),
    left.orderNo.trim(),
  }.where((value) => value.isNotEmpty && value != '-').toSet();
  final rightKeys = {
    right.bundleNo.trim(),
    right.uniq.trim(),
    right.orderNo.trim(),
  };
  if (rightKeys.any(leftKeys.contains)) return true;
  return _playAutoOrderIdentityKey(left) == _playAutoOrderIdentityKey(right);
}

_PlayAutoOrderPreview? _findMatchingOrderPreview(
  _PlayAutoOrderPreview original,
  List<_PlayAutoOrderPreview> orders,
) {
  for (final order in orders) {
    if (_samePlayAutoOrder(order, original)) return order;
  }
  return null;
}

bool _isPlayAutoFreshOrderStatus(String status) {
  return status.contains('신규') || status.contains('결제완료');
}

class PlayAutoOrderImportScreen extends StatefulWidget {
  const PlayAutoOrderImportScreen({super.key})
      : orderViewOnly = false,
        fulfillmentMode = false;

  const PlayAutoOrderImportScreen.orderView({super.key})
      : orderViewOnly = true,
        fulfillmentMode = true;

  const PlayAutoOrderImportScreen.fulfillment({super.key})
      : orderViewOnly = true,
        fulfillmentMode = true;

  final bool orderViewOnly;
  final bool fulfillmentMode;

  @override
  State<PlayAutoOrderImportScreen> createState() =>
      _PlayAutoOrderImportScreenState();
}

class _PlayAutoOrderImportScreenState extends State<PlayAutoOrderImportScreen>
    with WidgetsBindingObserver {
  static const _storage = FlutterSecureStorage();
  static const _baseUrlKey = 'playauto_openapi_base_url_v1';
  static const _apiKeyKey = 'playauto_api_key_v1';
  static const _authenticationKeyKey = 'playauto_authentication_key_v1';
  static const _tokenKey = 'playauto_token_v1';
  static const _tokenIssuedAtKey = 'playauto_token_issued_at_v1';
  static const _orderCachePrefix = 'playauto_order_cache_v1';
  static const _quoteOrderAddLogKey = 'playauto_quote_order_add_logs_v1';
  static const _autoSyncEnabledKey = 'playauto_auto_sync_enabled_v1';
  static const _autoSyncIntervalMinutesKey =
      'playauto_auto_sync_interval_minutes_v1';
  static const _autoSyncLastRunKey = 'playauto_auto_sync_last_run_v1';
  static const _knownOrderKeysKey = 'playauto_known_order_keys_v1';
  static const _defaultOrderCollectionAction = 'ScrapOrderAndConfirmDoit';
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
  String? _loadingMessage;
  var _credentialsLoaded = false;
  var _autoFetchedOrderView = false;
  var _workAction = _defaultOrderCollectionAction;
  List<_PlayAutoOrderPreview> _orders = const [];
  List<_PlayAutoShopAccount> _shopAccounts = const [];
  List<_PlayAutoQuoteOrderAddLog> _quoteOrderAddLogs = const [];
  Set<String> _selectedShopAccountKeys = const {};
  List<String> _lastWorkNos = const [];
  String? _result;
  int? _statusCode;
  DateTime? _tokenIssuedAt;
  Timer? _autoSyncTimer;
  var _autoSyncEnabled = false;
  var _autoSyncIntervalMinutes = 60;
  var _autoSyncRunning = false;
  DateTime? _lastAutoSyncAt;
  String? _lastAutoSyncError;
  int _newOrderBadgeCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    _sdateController.text = _formatDate(weekAgo);
    _edateController.text = _formatDate(now);
    _loadAutoSyncSettings();
    _loadSavedCredentials();
    _loadQuoteOrderAddLogs();
    _initializePlayAutoNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runDueAutoSync();
    }
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

    await _runRequest(
      () async {
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
      },
      clearOrders: false,
      loadingMessage: 'PlayAuto 토큰을 발급하고 있습니다.',
    );
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
      _scheduleOrderViewAutoFetch();
      _runDueAutoSync();
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _credentialsLoaded = true);
      _scheduleOrderViewAutoFetch();
      _runDueAutoSync();
      _showSnack('보안 저장소가 아직 준비되지 않았습니다. 앱을 다시 실행해주세요.');
    }
  }

  Future<void> _initializePlayAutoNotifications() async {
    await _PlayAutoOrderNotificationService.initialize();
  }

  Future<void> _loadAutoSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoSyncEnabledKey) ?? false;
    final interval = prefs.getInt(_autoSyncIntervalMinutesKey) ?? 60;
    final lastRunText = prefs.getString(_autoSyncLastRunKey);
    final lastRun = lastRunText == null ? null : DateTime.tryParse(lastRunText);
    if (!mounted) return;
    setState(() {
      _autoSyncEnabled = enabled;
      _autoSyncIntervalMinutes = _normalizeAutoSyncInterval(interval);
      _lastAutoSyncAt = lastRun;
    });
    _restartAutoSyncTimer();
  }

  Future<void> _saveAutoSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncEnabledKey, _autoSyncEnabled);
    await prefs.setInt(
      _autoSyncIntervalMinutesKey,
      _autoSyncIntervalMinutes,
    );
  }

  int _normalizeAutoSyncInterval(int value) {
    const allowed = [30, 60, 120, 360];
    return allowed.contains(value) ? value : 60;
  }

  Future<void> _setAutoSyncEnabled(bool enabled) async {
    setState(() {
      _autoSyncEnabled = enabled;
      _lastAutoSyncError = null;
    });
    await _saveAutoSyncSettings();
    _restartAutoSyncTimer();
    if (enabled) {
      await _seedKnownOrderKeysIfNeeded();
      await _runDueAutoSync(force: true);
    } else {
      await _PlayAutoOrderNotificationService.showBadgeOnly(0);
      if (mounted) setState(() => _newOrderBadgeCount = 0);
    }
  }

  Future<void> _setAutoSyncInterval(int minutes) async {
    setState(() {
      _autoSyncIntervalMinutes = _normalizeAutoSyncInterval(minutes);
      _lastAutoSyncError = null;
    });
    await _saveAutoSyncSettings();
    _restartAutoSyncTimer();
  }

  void _restartAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    if (!_autoSyncEnabled) return;
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: _autoSyncIntervalMinutes),
      (_) => _runDueAutoSync(force: true),
    );
  }

  Future<void> _runDueAutoSync({bool force = false}) async {
    if (!_autoSyncEnabled || _autoSyncRunning) return;
    if (_apiKeyController.text.trim().isEmpty) return;
    if (!mounted) return;
    final last = _lastAutoSyncAt;
    final due = last == null ||
        DateTime.now().difference(last) >=
            Duration(minutes: _autoSyncIntervalMinutes);
    if (!force && !due) return;

    setState(() {
      _autoSyncRunning = true;
      _lastAutoSyncError = null;
    });
    try {
      final sdate = _sdateController.text.trim();
      final edate = _edateController.text.trim();
      final length = int.tryParse(_lengthController.text.trim()) ?? 100;
      final collection = await _runDefaultOrderCollectionBeforeFetch();
      final result = await _fetchOrdersFromPlayAuto(
        sdate: sdate,
        edate: edate,
        length: length,
        forceRefresh: true,
      );
      final newOrders = await _detectNewAutoSyncedOrders(result.orders);
      final freshCount = _freshOrderCount(result.orders);
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_autoSyncLastRunKey, now.toIso8601String());
      await _storeKnownOrderKeys(result.orders);
      if (!mounted) return;
      setState(() {
        _orders = result.orders;
        _statusCode = result.statusCode;
        _result = [
          if (collection != null) collection.body,
          if (collection != null) '',
          result.body,
        ].join('\n');
        _lastAutoSyncAt = now;
        _newOrderBadgeCount = freshCount;
      });
      if (newOrders.isNotEmpty) {
        await _PlayAutoOrderNotificationService.showNewOrders(
          count: newOrders.length,
          badgeCount: newOrders.length,
          sampleTitle: newOrders.first.productName,
        );
      } else {
        await _PlayAutoOrderNotificationService.showBadgeOnly(0);
      }
    } on _PlayAutoUserMessage catch (e) {
      if (!mounted) return;
      setState(() => _lastAutoSyncError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastAutoSyncError = '$e');
    } finally {
      if (mounted) setState(() => _autoSyncRunning = false);
    }
  }

  Future<_PlayAutoCollectionRunResult?>
      _runDefaultOrderCollectionBeforeFetch() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) return null;

    final tokenResult = await _ensureTokenForOrderFetch(apiKey);
    if (tokenResult.response != null) {
      throw _PlayAutoUserMessage(tokenResult.response!.body);
    }
    final token = tokenResult.token!;

    var shops = _shopAccounts;
    if (shops.isEmpty) {
      shops = await _fetchShopAccountsInternal(apiKey: apiKey, token: token);
      if (mounted) {
        setState(() {
          _shopAccounts = shops;
          _selectedShopAccountKeys = {
            for (final shop in shops)
              if (shop.id.trim().isNotEmpty) shop.key,
          };
          _syncManualTargetFields();
        });
      }
    }

    final targets = shops
        .where((shop) => shop.id.trim().isNotEmpty)
        .map((shop) => _PlayAutoWorkTarget(code: shop.code, id: shop.id))
        .toList();
    if (targets.isEmpty) {
      throw const _PlayAutoUserMessage(
        '자동 동기화할 쇼핑몰 아이디를 찾지 못했습니다. 쇼핑몰 목록을 확인해주세요.',
      );
    }

    final registered = await _registerOrderCollectionWorkInternal(
      apiKey: apiKey,
      token: token,
      targets: targets,
      action: _defaultOrderCollectionAction,
    );
    if (mounted) {
      setState(() => _lastWorkNos = registered.workNos);
    }

    _PlayAutoResponse? workResult;
    if (registered.workNos.isNotEmpty) {
      await Future<void>.delayed(const Duration(seconds: 2));
      workResult = await _fetchWorkResultsInternal(
        apiKey: apiKey,
        token: token,
        workNos: registered.workNos,
      );
    }

    return _PlayAutoCollectionRunResult(
      statusCode: workResult?.statusCode ?? registered.response.statusCode,
      body: [
        '자동 동기화 주문 수집',
        '작업: 발주확인 후 주문 수집',
        '대상 쇼핑몰 ${targets.length}개',
        if (registered.workNos.isNotEmpty)
          '작업번호 ${registered.workNos.join(', ')}',
        '',
        registered.response.body,
        if (workResult != null) ...[
          '',
          '작업 결과',
          workResult.body,
        ],
      ].join('\n'),
    );
  }

  Future<void> _seedKnownOrderKeysIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_knownOrderKeysKey) ?? const [];
    if (existing.isNotEmpty || _orders.isEmpty) return;
    await _storeKnownOrderKeys(_orders);
  }

  Future<List<_PlayAutoOrderPreview>> _detectNewAutoSyncedOrders(
    List<_PlayAutoOrderPreview> orders,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final knownKeys = (prefs.getStringList(_knownOrderKeysKey) ?? const [])
        .where((key) => key.isNotEmpty)
        .toSet();
    if (knownKeys.isEmpty) return const [];
    return orders
        .where((order) =>
            _isPlayAutoFreshOrderStatus(order.status) &&
            !knownKeys.contains(_playAutoOrderIdentityKey(order)))
        .toList();
  }

  Future<void> _storeKnownOrderKeys(List<_PlayAutoOrderPreview> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = orders
        .map(_playAutoOrderIdentityKey)
        .where((key) {
          return key.isNotEmpty;
        })
        .toSet()
        .toList();
    await prefs.setStringList(_knownOrderKeysKey, keys);
  }

  int _freshOrderCount(List<_PlayAutoOrderPreview> orders) {
    return orders
        .where((order) => _isPlayAutoFreshOrderStatus(order.status))
        .length;
  }

  void _scheduleOrderViewAutoFetch() {
    if (_autoFetchedOrderView) return;
    if (_apiKeyController.text.trim().isEmpty) return;
    _autoFetchedOrderView = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _orders.isNotEmpty) return;
      try {
        await _fetchOrdersForPreview(
          sdate: _sdateController.text.trim(),
          edate: _edateController.text.trim(),
          length: int.tryParse(_lengthController.text.trim()) ?? 100,
          forceRefresh: false,
        );
      } catch (_) {
        // 최초 진입 자동조회 실패는 주문 탭에서 수동 조회로 다시 시도할 수 있다.
      }
    });
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
      _runDueAutoSync();
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

  Future<void> _loadQuoteOrderAddLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_quoteOrderAddLogKey);
    if (text == null || text.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return;
      final logs = decoded
          .whereType<Map>()
          .map((row) => _PlayAutoQuoteOrderAddLog.fromJson(
                row.map((key, value) => MapEntry(key.toString(), value)),
              ))
          .toList();
      if (!mounted) return;
      setState(() => _quoteOrderAddLogs = logs);
    } catch (_) {
      // 저장된 로그가 깨진 경우 화면 표시만 건너뛴다.
    }
  }

  Future<void> _clearQuoteOrderAddLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_quoteOrderAddLogKey);
    if (!mounted) return;
    setState(() => _quoteOrderAddLogs = const []);
    _showSnack('플토 주문 전송 로그를 지웠습니다.');
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
      return const _PlayAutoOrderFetchResult(
        orders: [],
        statusCode: null,
        body: '저장된 캐시가 없습니다. PlayAuto API를 호출하려면 동기화를 눌러주세요.',
        fromCache: true,
        noticeOverride: '캐시 없음 · API 호출 안 함',
      );
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

    await _runRequest(
      () async {
        final tokenResult = await _ensureTokenForOrderFetch(apiKey);
        if (tokenResult.response != null) return tokenResult.response!;
        final token = tokenResult.token!;

        final rawResponse = await http.get(
          _endpoint('/shops').replace(queryParameters: {'used': 'true'}),
          headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
        );
        final shops = _readShopAccounts(rawResponse.body);
        if (mounted) {
          setState(() {
            _shopAccounts = shops;
            final selected = {
              for (final key in _selectedShopAccountKeys)
                if (shops.any((shop) => shop.key == key)) key,
            };
            _selectedShopAccountKeys = selected.isEmpty
                ? {
                    for (final shop in shops)
                      if (shop.id.trim().isNotEmpty) shop.key,
                  }
                : selected;
            _syncManualTargetFields();
          });
        }

        return _PlayAutoResponse(
          statusCode: rawResponse.statusCode,
          body: [
            '불러온 쇼핑몰 ${shops.length}건',
            if (shops.isEmpty) '응답 구조에서 쇼핑몰 코드를 찾지 못했습니다.',
            '',
            '요청',
            'GET /shops?used=true',
            '',
            '응답',
            _prettyBody(rawResponse.body),
          ].join('\n'),
        );
      },
      clearOrders: false,
      loadingMessage: 'PlayAuto 쇼핑몰 목록을 불러오고 있습니다.',
    );
  }

  Future<List<_PlayAutoShopAccount>> _fetchShopAccountsInternal({
    required String apiKey,
    required String token,
  }) async {
    final response = await http.get(
      _endpoint('/shops').replace(queryParameters: {'used': 'true'}),
      headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
    );
    return _readShopAccounts(response.body);
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

    await _runRequest(
      () async {
        final tokenResult = await _ensureTokenForOrderFetch(apiKey);
        if (tokenResult.response != null) return tokenResult.response!;
        final token = tokenResult.token!;

        final result = await _registerOrderCollectionWorkInternal(
          apiKey: apiKey,
          token: token,
          targets: workTargets,
          action: _workAction,
        );

        if (mounted) {
          setState(() => _lastWorkNos = result.workNos);
        }

        return result.response;
      },
      clearOrders: false,
      loadingMessage: 'PlayAuto에 주문 수집 작업을 등록하고 있습니다.',
    );
  }

  Future<_PlayAutoWorkRegistrationResult> _registerOrderCollectionWorkInternal({
    required String apiKey,
    required String token,
    required List<_PlayAutoWorkTarget> targets,
    required String action,
  }) async {
    final groupedTargets = _groupWorkTargetsByCode(targets);
    final responses = <String>[];
    final workNos = <String>{};
    int? statusCode;

    for (var index = 0; index < groupedTargets.length; index += 1) {
      final entry = groupedTargets.entries.elementAt(index);
      final requestBody = <String, Object?>{
        'act': action,
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

    final response = _PlayAutoResponse(
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
    return _PlayAutoWorkRegistrationResult(
      response: response,
      workNos: workNos.toList(),
    );
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

    await _runRequest(
      () async {
        final tokenResult = await _ensureTokenForOrderFetch(apiKey);
        if (tokenResult.response != null) return tokenResult.response!;
        final token = tokenResult.token!;

        return _fetchWorkResultsInternal(
          apiKey: apiKey,
          token: token,
          workNos: _lastWorkNos,
        );
      },
      clearOrders: false,
      loadingMessage: 'PlayAuto 주문 수집 결과를 확인하고 있습니다.',
    );
    if (mounted) {
      await _refreshOrdersAfterCollection();
    }
  }

  Future<void> _refreshOrdersAfterCollection() async {
    final sdate = _sdateController.text.trim();
    final edate = _edateController.text.trim();
    final length = int.tryParse(_lengthController.text.trim()) ?? 100;
    if (sdate.isEmpty || edate.isEmpty || length <= 0) return;

    setState(() => _loading = true);
    try {
      final previousResult = _result;
      final result = await _fetchOrdersFromPlayAuto(
        sdate: sdate,
        edate: edate,
        length: length,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _orders = result.orders;
        _statusCode = result.statusCode;
        _result = [
          if (previousResult != null && previousResult.isNotEmpty)
            previousResult,
          if (previousResult != null && previousResult.isNotEmpty) '',
          '주문 동기화',
          '반영된 주문 ${result.orders.length}건',
          '',
          result.body,
        ].join('\n');
      });
      _showSnack('플토 주문 ${result.orders.length}건을 새로 반영했습니다.');
    } on _PlayAutoUserMessage catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack('주문 동기화 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_PlayAutoResponse> _fetchWorkResultsInternal({
    required String apiKey,
    required String token,
    required List<String> workNos,
  }) async {
    final responses = <String>[];
    int? statusCode;
    for (final workNo in workNos) {
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
          onFetchOrderDetail: _fetchOrderDetailFromPlayAuto,
          fulfillmentMode: widget.fulfillmentMode,
          onInstruction: _requestShipmentInstruction,
          onSetInvoice: _requestSetInvoice,
          onCompleteInvoice: _requestCompleteInvoice,
          onSendInvoice: _requestSendInvoice,
        ),
      ),
    );
  }

  Future<_PlayAutoResponse> _requestShipmentInstruction(
    _PlayAutoOrderPreview order,
  ) async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      throw const _PlayAutoUserMessage('API Key를 입력해주세요.');
    }
    final bundleNo = order.playAutoBundleNo;
    if (bundleNo.isEmpty) {
      throw const _PlayAutoUserMessage('출고지시할 묶음번호를 찾지 못했습니다.');
    }

    final tokenResult = await _ensureTokenForOrderFetch(apiKey);
    if (tokenResult.response != null) return tokenResult.response!;
    final token = tokenResult.token!;
    final requestBody = <String, Object?>{
      'bundle_codes': [bundleNo],
      'auto_bundle': true,
    };
    final response = await http.put(
      _endpoint('/order/instruction'),
      headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
      body: jsonEncode(requestBody),
    );
    return _PlayAutoResponse(
      statusCode: response.statusCode,
      body: [
        '출고지시',
        '묶음번호 $bundleNo',
        '',
        '요청 바디',
        const JsonEncoder.withIndent('  ').convert(requestBody),
        '',
        '응답',
        _prettyBody(response.body),
      ].join('\n'),
    );
  }

  Future<_PlayAutoOrderPreview?> _fetchOrderDetailFromPlayAuto(
    _PlayAutoOrderPreview order,
  ) async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      throw const _PlayAutoUserMessage('API Key를 입력해주세요.');
    }
    final uniq = order.uniq.trim();
    if (uniq.isEmpty) return null;

    final tokenResult = await _ensureTokenForOrderFetch(apiKey);
    if (tokenResult.response != null) {
      throw _PlayAutoUserMessage(tokenResult.response!.body);
    }
    final token = tokenResult.token!;
    final response = await http.get(
      _endpoint('/order/$uniq'),
      headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _PlayAutoUserMessage(
        '주문 상세 조회 실패: HTTP ${response.statusCode}',
      );
    }
    final orders = _readOrders(response.body);
    return _findMatchingOrderPreview(order, orders);
  }

  Future<_PlayAutoResponse> _requestSetInvoice(
    _PlayAutoOrderPreview order,
    String carrierCode,
    String invoiceNo,
  ) async {
    return _requestSetInvoiceInternal(
      order: order,
      carrierCode: carrierCode,
      invoiceNo: invoiceNo,
      changeComplete: false,
      label: '송장번호 입력',
    );
  }

  Future<_PlayAutoResponse> _requestSetInvoiceInternal({
    required _PlayAutoOrderPreview order,
    required String carrierCode,
    required String invoiceNo,
    required bool changeComplete,
    required String label,
  }) async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      throw const _PlayAutoUserMessage('API Key를 입력해주세요.');
    }
    final bundleNo = order.playAutoBundleNo;
    if (bundleNo.isEmpty) {
      throw const _PlayAutoUserMessage('송장번호를 입력할 묶음번호를 찾지 못했습니다.');
    }
    if (carrierCode.trim().isEmpty || invoiceNo.trim().isEmpty) {
      throw const _PlayAutoUserMessage('택배사 코드와 송장번호를 입력해주세요.');
    }

    final tokenResult = await _ensureTokenForOrderFetch(apiKey);
    if (tokenResult.response != null) return tokenResult.response!;
    final token = tokenResult.token!;
    final requestBody = <String, Object?>{
      'orders': [
        {
          'bundle_no': bundleNo,
          'carr_no': carrierCode.trim(),
          'invoice_no': invoiceNo.trim(),
        }
      ],
      'overwrite': true,
      'change_complete': changeComplete,
    };
    final response = await http.put(
      _endpoint('/order/setInvoice'),
      headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
      body: jsonEncode(requestBody),
    );
    return _PlayAutoResponse(
      statusCode: response.statusCode,
      body: [
        label,
        '묶음번호 $bundleNo',
        '상태변경 ${changeComplete ? '출고완료' : '운송장출력'}',
        '',
        '요청 바디',
        const JsonEncoder.withIndent('  ').convert(requestBody),
        '',
        '응답',
        _prettyBody(response.body),
      ].join('\n'),
    );
  }

  Future<_PlayAutoResponse> _requestCompleteInvoice(
    _PlayAutoOrderPreview order,
  ) async {
    final carrierCode = order.carrierCode.trim();
    final invoiceNo = order.invoiceNo.trim();
    if (carrierCode.isEmpty || invoiceNo.isEmpty) {
      throw const _PlayAutoUserMessage(
          '출고완료 처리할 송장정보가 없습니다. 먼저 동기화하거나 송장번호를 입력해주세요.');
    }
    return _requestSetInvoiceInternal(
      order: order,
      carrierCode: carrierCode,
      invoiceNo: invoiceNo,
      changeComplete: true,
      label: '출고완료 처리',
    );
  }

  Future<_PlayAutoResponse> _requestSendInvoice(
    _PlayAutoOrderPreview order,
  ) async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      throw const _PlayAutoUserMessage('API Key를 입력해주세요.');
    }
    final targets = order.playAutoSendInvoiceTargets;
    if (targets.isEmpty) {
      throw const _PlayAutoUserMessage('송장전송할 주문/묶음번호를 찾지 못했습니다.');
    }

    final tokenResult = await _ensureTokenForOrderFetch(apiKey);
    if (tokenResult.response != null) return tokenResult.response!;
    final token = tokenResult.token!;
    final attempts = <String>[];
    int? lastStatusCode;
    for (final targetNo in targets) {
      final requestBody = <String, Object?>{
        'work_type': 'SEND_INVOICE',
        'list': [targetNo],
      };
      final response = await http.post(
        _endpoint('/work/addWorkSelect/v1.1'),
        headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
        body: jsonEncode(requestBody),
      );
      lastStatusCode = response.statusCode;
      final prettyResponse = _prettyBody(response.body);
      final businessError = _playAutoBodyHasError(response.body);
      final workNos = _readWorkNos(response.body);
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          !businessError;
      debugPrint(
        [
          '[PlayAuto SEND_INVOICE]',
          ok ? 'success' : 'business_error',
          'http=${response.statusCode}',
          'target=$targetNo',
          if (workNos.isNotEmpty) 'work_no=${workNos.join(',')}',
          'response=${_compactLogText(prettyResponse)}',
        ].join(' '),
      );
      attempts.add([
        '대상 $targetNo',
        if (workNos.isNotEmpty) '작업번호 ${workNos.join(', ')}',
        '',
        '요청 바디',
        const JsonEncoder.withIndent('  ').convert(requestBody),
        '',
        '응답',
        prettyResponse,
      ].join('\n'));
      if (ok) {
        return _PlayAutoResponse(
          statusCode: response.statusCode,
          body: [
            '송장전송 작업 등록',
            '성공 대상 $targetNo',
            '',
            attempts.join('\n\n--- 재시도 ---\n\n'),
          ].join('\n'),
        );
      }
    }
    return _PlayAutoResponse(
      statusCode: lastStatusCode,
      body: [
        '송장전송 작업 등록 실패',
        '시도 대상 ${targets.join(', ')}',
        '',
        attempts.join('\n\n--- 재시도 ---\n\n'),
      ].join('\n'),
    );
  }

  bool _playAutoBodyHasError(String body) {
    try {
      final decoded = jsonDecode(body);
      return _jsonContainsError(decoded);
    } catch (_) {
      final lower = body.toLowerCase();
      return lower.contains('"error"') || lower.contains('error_code');
    }
  }

  bool _jsonContainsError(Object? node) {
    if (node is Map) {
      if (node.containsKey('error') || node.containsKey('error_code')) {
        return true;
      }
      final status = node['status']?.toString().trim();
      if (status == '실패' || status?.toLowerCase() == 'failed') return true;
      for (final value in node.values) {
        if (_jsonContainsError(value)) return true;
      }
    }
    if (node is List) {
      for (final value in node) {
        if (_jsonContainsError(value)) return true;
      }
    }
    return false;
  }

  String _compactLogText(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 220) return compact;
    return '${compact.substring(0, 220)}...';
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
        _newOrderBadgeCount = _freshOrderCount(result.orders);
      });
    }
    if (result.orders.isNotEmpty) {
      await _storeKnownOrderKeys(result.orders);
      await _PlayAutoOrderNotificationService.showBadgeOnly(0);
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
    String loadingMessage = 'PlayAuto 요청을 처리하고 있습니다.',
  }) async {
    setState(() {
      _loading = true;
      _loadingMessage = loadingMessage;
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
        setState(() {
          _loading = false;
          _loadingMessage = null;
        });
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
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '0') {
        workNos.add(text);
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

  String _lastAutoSyncText() {
    final last = _lastAutoSyncAt;
    if (last == null) return '없음';
    return DateFormat('MM-dd HH:mm').format(last);
  }

  String _nextAutoSyncText() {
    final last = _lastAutoSyncAt;
    if (last == null) return '대기 중';
    final next = last.add(Duration(minutes: _autoSyncIntervalMinutes));
    if (next.isBefore(DateTime.now())) return '곧 실행';
    return DateFormat('MM-dd HH:mm').format(next);
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
        onFetchOrderDetail: _fetchOrderDetailFromPlayAuto,
        fulfillmentMode: widget.fulfillmentMode,
        onInstruction: _requestShipmentInstruction,
        onSetInvoice: _requestSetInvoice,
        onCompleteInvoice: _requestCompleteInvoice,
        onSendInvoice: _requestSendInvoice,
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 52,
          titleSpacing: 12,
          title: Row(
            children: [
              const Text('플토'),
              const SizedBox(width: 14),
              Expanded(
                child: TabBar(
                  onTap: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  dividerHeight: 0,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  tabs: const [
                    Tab(height: 38, text: '달력'),
                    Tab(height: 38, text: '주문'),
                    Tab(height: 38, text: '계정'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: TabBarView(
            children: [
              _PlayAutoOrderCalendarScreen(
                orders: _orders,
                embedded: true,
              ),
              if (!_credentialsLoaded)
                const Center(child: CircularProgressIndicator())
              else
                _PlayAutoOrderPreviewScreen(
                  orders: _orders,
                  startDate: _sdateController.text.trim(),
                  endDate: _edateController.text.trim(),
                  length: int.tryParse(_lengthController.text.trim()) ?? 100,
                  onFetchOrders: _fetchOrdersForPreview,
                  onFetchOrderDetail: _fetchOrderDetailFromPlayAuto,
                  fulfillmentMode: true,
                  embedded: true,
                  onInstruction: _requestShipmentInstruction,
                  onSetInvoice: _requestSetInvoice,
                  onCompleteInvoice: _requestCompleteInvoice,
                  onSendInvoice: _requestSendInvoice,
                ),
              ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_credentialsLoaded) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'PlayAuto 토큰 발급, 주문 수집, 견적 주문 전송 로그를 확인합니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    _PlayAutoLoadingBanner(
                      message: _loadingMessage ?? 'PlayAuto 요청을 처리하고 있습니다.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _baseUrlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'OpenAPI Base URL',
                      helperText:
                          '문서와 계정 설정에 따라 /api 포함 여부가 다를 수 있어 수정 가능하게 둡니다.',
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
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('자동 동기화'),
                            subtitle: Text(
                              '앱이 켜져 있을 때 PlayAuto 주문을 주기적으로 확인합니다.',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            value: _autoSyncEnabled,
                            onChanged:
                                _credentialsLoaded ? _setAutoSyncEnabled : null,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _autoSyncIntervalMinutes,
                            decoration: const InputDecoration(
                              labelText: '동기화 간격',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30분마다'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('1시간마다'),
                              ),
                              DropdownMenuItem(
                                value: 120,
                                child: Text('2시간마다'),
                              ),
                              DropdownMenuItem(
                                value: 360,
                                child: Text('6시간마다'),
                              ),
                            ],
                            onChanged: _autoSyncEnabled
                                ? (value) {
                                    if (value != null) {
                                      _setAutoSyncInterval(value);
                                    }
                                  }
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              _AutoSyncStatusChip(
                                icon: Icons.notifications_active_outlined,
                                label: '신규 $_newOrderBadgeCount',
                              ),
                              _AutoSyncStatusChip(
                                icon: Icons.history_outlined,
                                label: '마지막 ${_lastAutoSyncText()}',
                              ),
                              if (_autoSyncEnabled)
                                _AutoSyncStatusChip(
                                  icon: Icons.schedule_outlined,
                                  label: '다음 ${_nextAutoSyncText()}',
                                ),
                              if (_autoSyncRunning)
                                const _AutoSyncStatusChip(
                                  icon: Icons.sync_outlined,
                                  label: '동기화 중',
                                ),
                            ],
                          ),
                          if (_lastAutoSyncError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '최근 자동 동기화 실패: $_lastAutoSyncError',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.error),
                            ),
                          ],
                        ],
                      ),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.vpn_key_outlined),
                        label: const Text('토큰 발급 테스트'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _openOrderPreview,
                        icon: const Icon(Icons.view_agenda_outlined),
                        label: Text(
                          _orders.isEmpty
                              ? '주문 보기'
                              : '주문 보기 ${_orders.length}건',
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
                  if (_quoteOrderAddLogs.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '최근 견적 주문 전송',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _clearQuoteOrderAddLogs,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('지우기'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            for (final log in _quoteOrderAddLogs.take(5))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  log.success
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  color:
                                      log.success ? Colors.green : Colors.red,
                                ),
                                title: Text(
                                  log.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  [
                                    _formatDateTime(log.sentAt),
                                    if (log.statusCode != null)
                                      'HTTP ${log.statusCode}',
                                    log.message,
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    '주문 수집 작업',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '쇼핑몰에서 PlayAuto로 주문 수집 또는 상태 동기화를 실행합니다. 수집 후 다음 주문 조회는 PlayAuto에서 새로 받아 캐시에 반영합니다.',
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
                            _selectedShopAccountKeys.length ==
                                    _shopAccounts.length
                                ? Icons.check_box_outlined
                                : Icons.select_all_outlined,
                          ),
                          label: Text(
                            _selectedShopAccountKeys.length ==
                                    _shopAccounts.length
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
                          final selected =
                              _selectedShopAccountKeys.contains(shop.key);
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
                              setState(() =>
                                  _toggleShopAccount(shop, value ?? false));
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
                        onPressed:
                            _loading ? null : _registerOrderCollectionWork,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_outlined),
                        label: const Text('쇼핑몰 주문 수집'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading || _lastWorkNos.isEmpty
                            ? null
                            : _fetchLastWorkResult,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.fact_check_outlined),
                        label: Text(
                          _lastWorkNos.isEmpty
                              ? '결과 확인'
                              : '결과 확인 ${_lastWorkNos.length}건',
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
                    _PlayAutoResultBox(text: _result!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayAutoResultBox extends StatefulWidget {
  const _PlayAutoResultBox({required this.text});

  final String text;

  @override
  State<_PlayAutoResultBox> createState() => _PlayAutoResultBoxState();
}

class _PlayAutoResultBoxState extends State<_PlayAutoResultBox> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalController,
          primary: false,
          padding: const EdgeInsets.all(12),
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontalController,
              primary: false,
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                widget.text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoSyncStatusChip extends StatelessWidget {
  const _AutoSyncStatusChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _PlayAutoLoadingBanner extends StatelessWidget {
  const _PlayAutoLoadingBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayAutoOrderNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _badgeChannel = MethodChannel(
    'chalstock/app_badge',
  );
  static var _initialized = false;
  static var _unavailable = false;

  static Future<void> initialize() async {
    if (_initialized || _unavailable) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      windows: WindowsInitializationSettings(
        appName: 'ChalStock',
        appUserModelId: 'Bluefog.ChalStock.StockApp',
        guid: '9cf3e4e5-6d0f-4c6d-a5f5-4c3ed2a65b9b',
      ),
    );
    try {
      await _notifications.initialize(settings);
      _initialized = true;
    } on MissingPluginException catch (e) {
      _unavailable = true;
      debugPrint('PlayAuto notifications unavailable until full rebuild: $e');
    } catch (e, st) {
      debugPrint('PlayAuto notifications initialize failed: $e');
      debugPrint('$st');
    }
  }

  static Future<void> showNewOrders({
    required int count,
    required int badgeCount,
    required String sampleTitle,
  }) async {
    await initialize();
    if (!_initialized) return;
    await _requestPermissionsIfNeeded();
    final title = '신규 주문 $count건';
    final body = count == 1
        ? sampleTitle
        : '$sampleTitle 외 ${count - 1}건의 새 주문이 들어왔습니다.';
    await _notifications.show(
      220715,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'playauto_new_orders',
          '플토 신규 주문',
          channelDescription: 'PlayAuto 신규 주문 자동 동기화 알림',
          importance: Importance.high,
          priority: Priority.high,
          number: badgeCount,
        ),
        iOS: DarwinNotificationDetails(badgeNumber: badgeCount),
        macOS: DarwinNotificationDetails(badgeNumber: badgeCount),
        windows: const WindowsNotificationDetails(),
      ),
      payload: 'playauto_orders',
    );
    await _setNativeBadgeCount(badgeCount);
  }

  static Future<void> showBadgeOnly(int badgeCount) async {
    await initialize();
    if (!_initialized) return;
    if (!Platform.isIOS && !Platform.isMacOS) return;
    await _requestPermissionsIfNeeded();
    final normalizedBadgeCount = math.max(0, badgeCount);
    await _setNativeBadgeCount(normalizedBadgeCount);
    await _notifications.show(
      220716,
      null,
      null,
      NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
          badgeNumber: normalizedBadgeCount,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
          badgeNumber: normalizedBadgeCount,
        ),
      ),
    );
    if (normalizedBadgeCount == 0) {
      await _notifications.cancel(220716);
    }
  }

  static Future<void> _setNativeBadgeCount(int badgeCount) async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    try {
      await _badgeChannel.invokeMethod<void>(
        'setBadgeCount',
        {'count': math.max(0, badgeCount)},
      );
    } on MissingPluginException {
      // Older installed builds will pick this up after a full rebuild.
    } catch (e) {
      debugPrint('PlayAuto app badge update failed: $e');
    }
  }

  static Future<void> _requestPermissionsIfNeeded() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _notifications
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }
}

class _PlayAutoOrderPreviewScreen extends StatefulWidget {
  const _PlayAutoOrderPreviewScreen({
    required this.orders,
    required this.startDate,
    required this.endDate,
    required this.length,
    required this.onFetchOrders,
    required this.onFetchOrderDetail,
    required this.fulfillmentMode,
    this.embedded = false,
    required this.onInstruction,
    required this.onSetInvoice,
    required this.onCompleteInvoice,
    required this.onSendInvoice,
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
  final Future<_PlayAutoOrderPreview?> Function(_PlayAutoOrderPreview order)
      onFetchOrderDetail;
  final bool fulfillmentMode;
  final bool embedded;
  final Future<_PlayAutoResponse> Function(_PlayAutoOrderPreview order)
      onInstruction;
  final Future<_PlayAutoResponse> Function(
    _PlayAutoOrderPreview order,
    String carrierCode,
    String invoiceNo,
  ) onSetInvoice;
  final Future<_PlayAutoResponse> Function(_PlayAutoOrderPreview order)
      onCompleteInvoice;
  final Future<_PlayAutoResponse> Function(_PlayAutoOrderPreview order)
      onSendInvoice;

  @override
  State<_PlayAutoOrderPreviewScreen> createState() =>
      _PlayAutoOrderPreviewScreenState();
}

class _PlayAutoOrderCalendarScreen extends StatelessWidget {
  const _PlayAutoOrderCalendarScreen({
    required this.orders,
    this.embedded = false,
  });

  final List<_PlayAutoOrderPreview> orders;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final events = _calendarEvents;
    final focusedDay = _focusedDay(events);
    final body = events.isEmpty
        ? const Center(child: Text('날짜가 있는 주문이 없습니다.'))
        : CommonCalendarView(
            events: events,
            focusedDay: focusedDay,
            expandedBuilder: (event) {
              final index = int.tryParse(event.refId);
              if (index == null || index < 0 || index >= orders.length) {
                return const SizedBox.shrink();
              }
              return _PlayAutoCalendarOrderTile(order: orders[index]);
            },
          );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('플토 주문 달력'),
      ),
      body: body,
    );
  }

  List<CalendarEvent> get _calendarEvents {
    final events = <CalendarEvent>[];
    for (var i = 0; i < orders.length; i += 1) {
      final order = orders[i];
      final date = order.sortDate;
      if (date == null) continue;
      events.add(
        CalendarEvent(
          date: date,
          type: CalendarEventType.playAutoOrder,
          title: order.customerName,
          subtitle: [
            order.shopName,
            order.productName,
            '${order.quantity}개',
            if (order.status.isNotEmpty) order.status,
          ].where((value) => value.trim().isNotEmpty).join(' · '),
          refId: '$i',
          searchText: order.searchText,
          colorValue: _playAutoCalendarStatusColor(order.status).toARGB32(),
        ),
      );
    }
    return events;
  }

  DateTime? _focusedDay(List<CalendarEvent> events) {
    if (events.isEmpty) return null;
    final sorted = [...events]..sort((a, b) => b.date.compareTo(a.date));
    return sorted.first.date;
  }
}

class _PlayAutoCalendarOrderTile extends StatelessWidget {
  const _PlayAutoCalendarOrderTile({required this.order});

  final _PlayAutoOrderPreview order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _playAutoCalendarStatusColor(order.status);
    final amountText = order.amount > 0
        ? '${NumberFormat('#,##0').format(order.amount)} 원'
        : '-';

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withValues(alpha: 0.38)),
      ),
      color: statusColor.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (order.optionName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                order.optionName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                    icon: Icons.storefront_outlined, text: order.shopName),
                _InfoChip(icon: Icons.person_outline, text: order.customerName),
                _InfoChip(icon: Icons.local_offer_outlined, text: order.status),
                _InfoChip(
                  icon: Icons.inventory_2_outlined,
                  text: '${order.quantity}개',
                ),
                _InfoChip(icon: Icons.payments_outlined, text: amountText),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _playAutoCalendarStatusColor(String status) {
  if (status.contains('신규')) return Colors.pink.shade400;
  if (status.contains('배송완료') || status.contains('구매결정')) {
    return Colors.grey.shade600;
  }
  if (status.contains('배송중')) return Colors.blue.shade600;
  return const Color(0xFFE0B72F);
}

class _PlayAutoAddressEntry {
  final String title;
  final String address;
  final String source;
  final String? contactName;
  final String? phone;

  const _PlayAutoAddressEntry({
    required this.title,
    required this.address,
    required this.source,
    this.contactName,
    this.phone,
  });

  String get searchableText {
    return [
      title,
      address,
      source,
      contactName,
      phone,
    ].whereType<String>().join(' ').toLowerCase();
  }
}

class PlayAutoDeliveryAddressEntry {
  final String title;
  final String address;
  final String source;
  final String? contactName;
  final String? phone;

  const PlayAutoDeliveryAddressEntry({
    required this.title,
    required this.address,
    required this.source,
    this.contactName,
    this.phone,
  });

  _PlayAutoAddressEntry get _internal => _PlayAutoAddressEntry(
        title: title,
        address: address,
        source: source,
        contactName: contactName,
        phone: phone,
      );

  static PlayAutoDeliveryAddressEntry _fromInternal(
    _PlayAutoAddressEntry entry,
  ) =>
      PlayAutoDeliveryAddressEntry(
        title: entry.title,
        address: entry.address,
        source: entry.source,
        contactName: entry.contactName,
        phone: entry.phone,
      );
}

Future<PlayAutoDeliveryAddressEntry?> showPlayAutoAddressBookSheet(
  BuildContext context, {
  required List<PlayAutoDeliveryAddressEntry> entries,
  required String initialQuery,
}) async {
  final selected = await showModalBottomSheet<_PlayAutoAddressEntry>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PlayAutoAddressBookSheet(
      entries: entries.map((entry) => entry._internal).toList(),
      initialQuery: initialQuery,
    ),
  );
  if (selected == null) return null;
  return PlayAutoDeliveryAddressEntry._fromInternal(selected);
}

class _PlayAutoAddressBookSheet extends StatefulWidget {
  final List<_PlayAutoAddressEntry> entries;
  final String initialQuery;

  const _PlayAutoAddressBookSheet({
    required this.entries,
    required this.initialQuery,
  });

  @override
  State<_PlayAutoAddressBookSheet> createState() =>
      _PlayAutoAddressBookSheetState();
}

class _PlayAutoAddressBookSheetState extends State<_PlayAutoAddressBookSheet> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery.trim());
    _queryController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<_PlayAutoAddressEntry> get _filteredEntries {
    final query = _queryController.text.trim().toLowerCase();
    final entries = widget.entries
        .where((entry) => entry.address.trim().isNotEmpty)
        .toList();
    if (query.isEmpty) return entries;
    return entries
        .where((entry) => entry.searchableText.contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '주소록에서 불러오기',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _queryController,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _queryController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '검색어 지우기',
                            onPressed: _queryController.clear,
                            icon: const Icon(Icons.clear),
                          ),
                    hintText: '고객명, 거래처명, 주소, 연락처 검색',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                        children: const [
                          Icon(Icons.manage_search, size: 42),
                          SizedBox(height: 12),
                          Center(child: Text('불러올 주소가 없습니다')),
                        ],
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final subtitle = [
                            entry.address.trim(),
                            if ((entry.contactName ?? '').trim().isNotEmpty)
                              entry.contactName!.trim(),
                            if ((entry.phone ?? '').trim().isNotEmpty)
                              entry.phone!.trim(),
                          ].join(' · ');

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.place_outlined),
                            title: Text(entry.title),
                            subtitle: Text(subtitle),
                            trailing: Text(entry.source),
                            onTap: () => Navigator.of(context).pop(entry),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DaumPostcodeResult {
  final String zonecode;
  final String roadAddress;
  final String jibunAddress;
  final String buildingName;

  const _DaumPostcodeResult({
    required this.zonecode,
    required this.roadAddress,
    required this.jibunAddress,
    required this.buildingName,
  });

  factory _DaumPostcodeResult.fromJson(Map<String, Object?> json) {
    return _DaumPostcodeResult(
      zonecode: json['zonecode']?.toString() ?? '',
      roadAddress: json['roadAddress']?.toString() ?? '',
      jibunAddress: json['jibunAddress']?.toString() ?? '',
      buildingName: json['buildingName']?.toString() ?? '',
    );
  }

  String get address {
    if (roadAddress.trim().isNotEmpty) return roadAddress.trim();
    return jibunAddress.trim();
  }
}

class PlayAutoPostcodeResult {
  final String zonecode;
  final String address;

  const PlayAutoPostcodeResult({
    required this.zonecode,
    required this.address,
  });
}

Future<PlayAutoPostcodeResult?> showPlayAutoPostcodeSearchSheet(
  BuildContext context,
) async {
  final selected = await showModalBottomSheet<_DaumPostcodeResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DaumPostcodeSheet(),
  );
  if (selected == null) return null;
  return PlayAutoPostcodeResult(
    zonecode: selected.zonecode,
    address: selected.address,
  );
}

class _DaumPostcodeSheet extends StatefulWidget {
  const _DaumPostcodeSheet();

  @override
  State<_DaumPostcodeSheet> createState() => _DaumPostcodeSheetState();
}

class _DaumPostcodeSheetState extends State<_DaumPostcodeSheet> {
  late final WebViewController _controller;
  var _loading = true;
  var _completed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('[DaumPostcode] init');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            debugPrint('[DaumPostcode] page finished');
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            debugPrint('[DaumPostcode] navigation ${request.url}');
            final uri = Uri.tryParse(request.url);
            if (uri?.host == 'postcode.chalstock.local' &&
                uri?.path == '/complete') {
              _handlePostcodePayload(uri);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'DaumPostcode',
        onMessageReceived: (message) {
          debugPrint(
            '[DaumPostcode] js channel ${_compactLogText(message.message)}',
          );
          if (message.message.startsWith('log:')) return;
          _completePostcode(message.message);
        },
      );
    _loadPostcodeHtml();
  }

  Future<void> _loadPostcodeHtml() async {
    try {
      debugPrint('[DaumPostcode] load html');
      await _controller.loadHtmlString(
        _daumPostcodeHtml,
        baseUrl: 'https://postcode.chalstock.local/search.html',
      );
      debugPrint('[DaumPostcode] load html requested');
    } catch (e) {
      debugPrint('[DaumPostcode] load html failed $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '주소 검색 화면을 열 수 없습니다. 앱을 완전히 종료한 뒤 다시 실행해주세요.';
      });
    }
  }

  void _handlePostcodePayload(Uri? uri) {
    final payload = uri?.queryParameters['payload'];
    debugPrint(
      '[DaumPostcode] url payload ${payload == null ? 'null' : _compactLogText(payload)}',
    );
    if (payload == null || payload.isEmpty) return;
    _completePostcode(payload);
  }

  void _completePostcode(String payload) {
    if (_completed) {
      debugPrint('[DaumPostcode] complete ignored after pop');
      return;
    }
    try {
      debugPrint('[DaumPostcode] complete ${_compactLogText(payload)}');
      if (mounted) {
        setState(() => _errorMessage = null);
      }
      final decoded = jsonDecode(payload);
      if (decoded is! Map || !mounted) return;
      debugPrint('[DaumPostcode] pop result $decoded');
      _completed = true;
      Navigator.of(context).pop(
        _DaumPostcodeResult.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    } catch (_) {
      debugPrint('[DaumPostcode] complete parse failed');
      if (!mounted) return;
      setState(() => _errorMessage = '선택한 주소를 읽지 못했습니다. 다시 선택해주세요.');
    }
  }

  String _compactLogText(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 220) return compact;
    return '${compact.substring(0, 220)}...';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '주소 검색',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _errorMessage == null
                    ? Stack(
                        children: [
                          WebViewWidget(controller: _controller),
                          if (_loading)
                            const Center(child: CircularProgressIndicator()),
                        ],
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _daumPostcodeHtml = '''
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <style>
    html, body {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
      overflow: hidden;
      background: #fff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    .postcode-help {
      height: 42px;
      display: flex;
      align-items: center;
      padding: 0 14px;
      box-sizing: border-box;
      border-bottom: 1px solid #e5e7eb;
      background: #f8fafc;
      color: #334155;
      font-size: 13px;
      font-weight: 600;
    }
    #postcode {
      width: 100%;
      height: calc(100% - 42px);
    }
  </style>
</head>
<body>
  <div class="postcode-help">검색 결과의 주소 행을 클릭하면 자동 입력됩니다.</div>
  <div id="postcode"></div>
  <script src="https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
  <script>
    function log(message) {
      try { console.log('[DaumPostcodeHTML] ' + message); } catch (e) {}
      try {
        if (window.DaumPostcode && window.DaumPostcode.postMessage) {
          window.DaumPostcode.postMessage('log:' + message);
        }
      } catch (e) {}
    }

    function sendResult(data) {
      log('sendResult called');
      var payload = JSON.stringify({
        zonecode: data.zonecode || '',
        roadAddress: data.roadAddress || '',
        jibunAddress: data.jibunAddress || '',
        buildingName: data.buildingName || ''
      });

      try {
        if (window.DaumPostcode && window.DaumPostcode.postMessage) {
          log('posting payload to channel');
          window.DaumPostcode.postMessage(payload);
          return;
        }
      } catch (e) {
        log('channel post failed; using fallback url');
      }

      setTimeout(function() {
        log('navigating fallback url');
        window.location.href = 'https://postcode.chalstock.local/complete?payload=' + encodeURIComponent(payload);
      }, 0);
    }

    function openPostcode() {
      log('openPostcode called');
      new daum.Postcode({
        width: '100%',
        height: '100%',
        autoClose: false,
        oncomplete: function(data) {
          log('oncomplete called');
          sendResult(data);
        }
      }).embed(document.getElementById('postcode'));
    }

    if (window.daum && window.daum.Postcode) {
      log('daum.Postcode ready');
      openPostcode();
    } else {
      log('waiting window.onload');
      window.onload = function() {
        log('window.onload');
        openPostcode();
      };
    }
  </script>
</body>
</html>
''';

class PlayAutoQuoteOrderAddScreen extends StatefulWidget {
  const PlayAutoQuoteOrderAddScreen({
    super.key,
    required this.quote,
    required this.lines,
    this.autoSubmit = false,
  });

  final Quote quote;
  final List<QuoteLine> lines;
  final bool autoSubmit;

  @override
  State<PlayAutoQuoteOrderAddScreen> createState() =>
      _PlayAutoQuoteOrderAddScreenState();
}

class _PlayAutoQuoteOrderAddScreenState
    extends State<PlayAutoQuoteOrderAddScreen> {
  static const _storage = FlutterSecureStorage();
  static const _baseUrlKey = _PlayAutoOrderImportScreenState._baseUrlKey;
  static const _apiKeyKey = _PlayAutoOrderImportScreenState._apiKeyKey;
  static const _authenticationKeyKey =
      _PlayAutoOrderImportScreenState._authenticationKeyKey;
  static const _tokenKey = _PlayAutoOrderImportScreenState._tokenKey;
  static const _tokenIssuedAtKey =
      _PlayAutoOrderImportScreenState._tokenIssuedAtKey;
  static const _quoteOrderAddLogKey =
      _PlayAutoOrderImportScreenState._quoteOrderAddLogKey;
  static const _quoteOrderAddDraftKey = 'playauto_quote_order_add_draft';
  static const _tokenLifetime = _PlayAutoOrderImportScreenState._tokenLifetime;

  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController(
    text: 'https://openapi.playauto.io/api',
  );
  final _apiKeyController = TextEditingController();
  final _authenticationKeyController = TextEditingController();
  final _tokenController = TextEditingController();
  final _customShopCodeController = TextEditingController();
  final _customShopIdController = TextEditingController();
  final _orderNameController = TextEditingController();
  final _orderPhoneController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _zipController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _shipMessageController = TextEditingController();
  final _shippingCostController = TextEditingController(text: '0');
  final _shopOrderNoController = TextEditingController(text: '__AUTO__');
  final _shopSaleNameController = TextEditingController();

  DateTime? _tokenIssuedAt;
  var _loading = false;
  var _loadingShops = false;
  String? _result;
  String? _lastCreatedOrderNoText;
  DateTime? _lastCreatedAt;
  List<_PlayAutoShopAccount> _shops = const [];
  _PlayAutoShopAccount? _selectedShop;
  Map<String, String> _lineSkus = const {};
  List<_PlayAutoAddressEntry> _addressEntries = const [];
  Timer? _draftSaveTimer;
  var _draftReady = false;
  var _autoSubmitStarted = false;

  @override
  void initState() {
    super.initState();
    final customerName = widget.quote.customerName.trim();
    final firstLineName =
        widget.lines.isEmpty ? '찰스톡 견적 주문' : widget.lines.first.name;
    _orderNameController.text = customerName;
    _receiverNameController.text = customerName;
    _shopSaleNameController.text = widget.lines.length <= 1
        ? firstLineName
        : '$firstLineName 외 ${widget.lines.length - 1}건';
    _shippingCostController.text =
        widget.quote.shippingCost.clamp(0, double.infinity).toStringAsFixed(0);
    _receiverNameController.text =
        (widget.quote.deliveryName ?? '').trim().isNotEmpty
            ? widget.quote.deliveryName!.trim()
            : customerName;
    _receiverPhoneController.text = widget.quote.deliveryPhone ?? '';
    if (_orderPhoneController.text.trim().isEmpty &&
        (widget.quote.deliveryPhone ?? '').trim().isNotEmpty) {
      _orderPhoneController.text = widget.quote.deliveryPhone!.trim();
    }
    _zipController.text = widget.quote.deliveryZip ?? '';
    _address1Controller.text = widget.quote.deliveryAddress1 ?? '';
    _address2Controller.text = widget.quote.deliveryAddress2 ?? '';
    _shipMessageController.text = widget.quote.deliveryMemo ?? '';
    for (final controller in _draftControllers) {
      controller.addListener(_scheduleSaveDraft);
    }
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadSavedCredentials();
    await _loadLineSkus();
    await _loadAddressEntries();
    await _loadQuoteCustomerDefaults();
    await _loadSavedDraft();
    if (widget.autoSubmit && mounted && !_autoSubmitStarted) {
      _autoSubmitStarted = true;
      await _submit();
    }
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    if (_draftReady) {
      unawaited(_saveDraft());
    }
    for (final controller in _draftControllers) {
      controller.removeListener(_scheduleSaveDraft);
    }
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _authenticationKeyController.dispose();
    _tokenController.dispose();
    _customShopCodeController.dispose();
    _customShopIdController.dispose();
    _orderNameController.dispose();
    _orderPhoneController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _zipController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _shipMessageController.dispose();
    _shippingCostController.dispose();
    _shopOrderNoController.dispose();
    _shopSaleNameController.dispose();
    super.dispose();
  }

  List<TextEditingController> get _draftControllers => [
        _customShopCodeController,
        _customShopIdController,
        _orderNameController,
        _orderPhoneController,
        _receiverNameController,
        _receiverPhoneController,
        _zipController,
        _address1Controller,
        _address2Controller,
        _shipMessageController,
        _shippingCostController,
        _shopOrderNoController,
        _shopSaleNameController,
      ];

  String get _draftStorageKey => '$_quoteOrderAddDraftKey:${widget.quote.id}';

  void _scheduleSaveDraft() {
    if (!_draftReady) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_saveDraft());
    });
  }

  Future<void> _loadSavedDraft() async {
    try {
      final text = await _storage.read(key: _draftStorageKey);
      if (text == null || text.trim().isEmpty) {
        _draftReady = true;
        return;
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map || !mounted) {
        _draftReady = true;
        return;
      }
      setState(() {
        _customShopCodeController.text =
            (decoded['customShopCode'] ?? '').toString();
        _customShopIdController.text =
            (decoded['customShopId'] ?? '').toString();
        _orderNameController.text = (decoded['orderName'] ?? '').toString();
        _orderPhoneController.text = (decoded['orderPhone'] ?? '').toString();
        if (_receiverNameController.text.trim().isEmpty) {
          _receiverNameController.text =
              (decoded['receiverName'] ?? '').toString();
        }
        if (_receiverPhoneController.text.trim().isEmpty) {
          _receiverPhoneController.text =
              (decoded['receiverPhone'] ?? '').toString();
        }
        if (_zipController.text.trim().isEmpty) {
          _zipController.text = (decoded['zip'] ?? '').toString();
        }
        if (_address1Controller.text.trim().isEmpty) {
          _address1Controller.text = (decoded['address1'] ?? '').toString();
        }
        if (_address2Controller.text.trim().isEmpty) {
          _address2Controller.text = (decoded['address2'] ?? '').toString();
        }
        if (_shipMessageController.text.trim().isEmpty) {
          _shipMessageController.text =
              (decoded['shipMessage'] ?? '').toString();
        }
        _shippingCostController.text =
            (decoded['shippingCost'] ?? '').toString();
        _shopOrderNoController.text = (decoded['shopOrderNo'] ?? '').toString();
        _shopSaleNameController.text =
            (decoded['shopSaleName'] ?? '').toString();
      });
    } catch (e) {
      debugPrint('[PlayAuto /order/add] draft load failed: $e');
    } finally {
      _draftReady = true;
    }
  }

  Future<void> _saveDraft() async {
    try {
      await _storage.write(
        key: _draftStorageKey,
        value: jsonEncode({
          'customShopCode': _customShopCodeController.text,
          'customShopId': _customShopIdController.text,
          'orderName': _orderNameController.text,
          'orderPhone': _orderPhoneController.text,
          'receiverName': _receiverNameController.text,
          'receiverPhone': _receiverPhoneController.text,
          'zip': _zipController.text,
          'address1': _address1Controller.text,
          'address2': _address2Controller.text,
          'shipMessage': _shipMessageController.text,
          'shippingCost': _shippingCostController.text,
          'shopOrderNo': _shopOrderNoController.text,
          'shopSaleName': _shopSaleNameController.text,
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );
    } on MissingPluginException {
      // 보안 저장소가 준비되지 않은 개발 빌드에서는 조용히 건너뛴다.
    } catch (e) {
      debugPrint('[PlayAuto /order/add] draft save failed: $e');
    }
  }

  Future<void> _saveQuoteDeliveryFromForm() async {
    try {
      await context.read<QuoteRepo>().updateQuote(
            widget.quote.copyWith(
              deliveryName: _receiverNameController.text.trim(),
              deliveryPhone: _receiverPhoneController.text.trim(),
              deliveryZip: _zipController.text.trim(),
              deliveryAddress1: _address1Controller.text.trim(),
              deliveryAddress2: _address2Controller.text.trim(),
              deliveryMemo: _shipMessageController.text.trim(),
            ),
          );
    } catch (e) {
      debugPrint('[PlayAuto /order/add] quote delivery save failed: $e');
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
      });
    } on MissingPluginException {
      if (!mounted) return;
      _showSnack('보안 저장소가 아직 준비되지 않았습니다. 앱을 다시 실행해주세요.');
    }
  }

  Future<void> _loadAddressEntries() async {
    try {
      final repo = context.read<SupplierRepo>();
      final suppliers = await repo.list(onlyActive: true);
      final entries = <_PlayAutoAddressEntry>[];
      final quoteCustomerId = widget.quote.customerId;
      final quoteCustomerName = widget.quote.customerName.trim();

      for (final supplier in suppliers) {
        final supplierAddress = (supplier.addr ?? '').trim();
        if (supplierAddress.isNotEmpty) {
          entries.add(
            _PlayAutoAddressEntry(
              title: supplier.name,
              address: supplierAddress,
              source: supplier.isCustomer ? '고객' : '거래처',
              contactName: supplier.contactName,
              phone: supplier.phone,
            ),
          );
        }

        final contacts = await repo.listContacts(supplier.id);
        for (final contact in contacts) {
          final contactAddress = (contact.address ?? '').trim();
          if (contactAddress.isEmpty) continue;
          entries.add(
            _PlayAutoAddressEntry(
              title: '${supplier.name} · ${contact.name}',
              address: contactAddress,
              source: contact.isPrimary ? '주 담당자' : '담당자',
              contactName: contact.name,
              phone: contact.phone,
            ),
          );
        }
      }

      entries.sort((a, b) {
        final aScore =
            _addressEntryScore(a, quoteCustomerId, quoteCustomerName);
        final bScore =
            _addressEntryScore(b, quoteCustomerId, quoteCustomerName);
        if (aScore != bScore) return bScore.compareTo(aScore);
        return a.title.compareTo(b.title);
      });

      if (!mounted) return;
      setState(() => _addressEntries = entries);
    } catch (_) {
      if (!mounted) return;
      setState(() => _addressEntries = const []);
    }
  }

  Future<void> _loadQuoteCustomerDefaults() async {
    try {
      final repo = context.read<SupplierRepo>();
      final supplier = await _findQuoteCustomer(repo);
      if (supplier == null || !mounted) return;

      final contacts = await repo.listContacts(supplier.id);
      final primaryContact = contacts.where((contact) => contact.isPrimary);
      final fallbackContact = primaryContact.isNotEmpty
          ? primaryContact.first
          : (contacts.isNotEmpty ? contacts.first : null);
      final phone = (supplier.phone ?? '').trim().isNotEmpty
          ? supplier.phone!.trim()
          : (fallbackContact?.phone ?? '').trim();
      if (phone.isEmpty || !mounted) return;

      setState(() {
        if (_orderPhoneController.text.trim().isEmpty) {
          _orderPhoneController.text = phone;
        }
        if (_receiverPhoneController.text.trim().isEmpty) {
          _receiverPhoneController.text = phone;
        }
      });
    } catch (_) {
      // 연락처 자동 채움 실패는 사용자가 직접 입력할 수 있으므로 조용히 넘어간다.
    }
  }

  Future<Supplier?> _findQuoteCustomer(SupplierRepo repo) async {
    final customerId = widget.quote.customerId?.trim();
    if (customerId != null && customerId.isNotEmpty) {
      final supplier = await repo.get(customerId);
      if (supplier != null) return supplier;
    }

    final customerName = widget.quote.customerName.trim();
    if (customerName.isEmpty) return null;
    final candidates = await repo.list(q: customerName, onlyActive: true);
    if (candidates.isEmpty) return null;

    final exactMatches = candidates
        .where((supplier) => supplier.name.trim() == customerName)
        .toList();
    if (exactMatches.isEmpty) return candidates.first;
    exactMatches.sort((a, b) {
      if (a.isCustomer != b.isCustomer) return a.isCustomer ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return exactMatches.first;
  }

  int _addressEntryScore(
    _PlayAutoAddressEntry entry,
    String? customerId,
    String customerName,
  ) {
    final text = entry.searchableText;
    var score = 0;
    if (customerId != null &&
        customerId.isNotEmpty &&
        text.contains(customerId)) {
      score += 4;
    }
    if (customerName.isNotEmpty && text.contains(customerName.toLowerCase())) {
      score += 3;
    }
    if (entry.source == '고객') score += 2;
    if (entry.source == '주 담당자') score += 1;
    return score;
  }

  Future<void> _openAddressBook() async {
    final initialQuery = _address1Controller.text.trim().isNotEmpty
        ? _address1Controller.text.trim()
        : widget.quote.customerName;
    final selected = await showModalBottomSheet<_PlayAutoAddressEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlayAutoAddressBookSheet(
        entries: _addressEntries,
        initialQuery: initialQuery,
      ),
    );
    if (selected == null) return;
    _applyAddressEntry(selected);
  }

  Future<void> _openDaumPostcodeSearch() async {
    if (!_supportsEmbeddedDaumPostcode) {
      _showSnack('이 환경에서는 주소 검색창을 열 수 없습니다. 고객/거래처 배송지 불러오기 또는 직접 입력을 사용해주세요.');
      return;
    }
    debugPrint('[PlayAutoQuoteOrderAdd] open shipping address search');
    final selected = await showModalBottomSheet<_DaumPostcodeResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DaumPostcodeSheet(),
    );
    if (selected == null) return;

    setState(() {
      if (_receiverPhoneController.text.trim().isEmpty) {
        _receiverPhoneController.text = _orderPhoneController.text.trim();
      }
      _zipController.text = selected.zonecode;
      _address1Controller.text = selected.address;
      _address2Controller.clear();
    });
    debugPrint(
      '[PlayAutoQuoteOrderAdd] applied shipping address '
      'zip=${selected.zonecode} address=${selected.address}',
    );
    _showSnack('수령자 배송지 주소를 입력했습니다. 상세주소를 확인해주세요.');
  }

  bool get _supportsEmbeddedDaumPostcode {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  void _applyAddressEntry(_PlayAutoAddressEntry entry) {
    setState(() {
      _orderNameController.text = entry.title.split(' · ').first;
      _receiverNameController.text = (entry.contactName ?? '').trim().isNotEmpty
          ? entry.contactName!.trim()
          : entry.title.split(' · ').first;
      final phone = (entry.phone ?? '').trim();
      if (phone.isNotEmpty) {
        _orderPhoneController.text = phone;
        _receiverPhoneController.text = phone;
      }
      _address1Controller.text = entry.address.trim();
    });
  }

  Future<void> _loadLineSkus() async {
    final repo = context.read<ItemRepo>();
    final skus = <String, String>{};
    for (final line in widget.lines) {
      final itemId = line.itemId.trim();
      if (itemId.isEmpty) continue;
      final item = await repo.getItem(itemId);
      final sku = item?.sku.trim() ?? '';
      if (sku.isNotEmpty) skus[line.id] = sku;
    }
    if (!mounted) return;
    setState(() => _lineSkus = skus);
  }

  Future<void> _fetchShops() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('API Key를 입력해주세요.');
      return;
    }
    setState(() {
      _loadingShops = true;
      _result = null;
    });
    try {
      final token = await _ensureToken(apiKey);
      final response = await http.get(
        _endpoint('/shops').replace(queryParameters: {'used': 'true'}),
        headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
      );
      final shops = _readShopAccounts(response.body);
      if (!mounted) return;
      setState(() {
        _shops = shops;
        if (_selectedShop != null &&
            !shops.any((shop) => shop.key == _selectedShop!.key)) {
          _selectedShop = null;
        }
        _result = [
          '쇼핑몰 계정 ${shops.length}건',
          if (shops.isEmpty) '직접입력 쇼핑몰 계정을 찾지 못하면 코드와 아이디를 직접 입력해주세요.',
        ].join('\n');
      });
    } on _PlayAutoUserMessage catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack('쇼핑몰 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingShops = false);
    }
  }

  Future<void> _submit() async {
    if (widget.lines.isEmpty) {
      _showSnack('플토 주문으로 보낼 견적 품목이 없습니다.');
      if (widget.autoSubmit && mounted) {
        Navigator.of(context).pop('플토 주문으로 보낼 견적 품목이 없습니다.');
      }
      return;
    }
    if (!widget.autoSubmit && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('API Key를 입력해주세요.');
      if (widget.autoSubmit && mounted) {
        Navigator.of(context).pop('API Key를 입력해주세요.');
      }
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      if (widget.autoSubmit) {
        await _ensureAutoSubmitShopAccount(apiKey);
        final validationMessage = _autoSubmitValidationMessage();
        if (validationMessage != null) {
          _showSnack(validationMessage);
          if (mounted) Navigator.of(context).pop(validationMessage);
          return;
        }
      }
      await _saveDraft();
      await _saveQuoteDeliveryFromForm();
      final token = await _ensureToken(apiKey);
      final requestBody = _buildRequestBody();
      _debugPrintPlayAutoOrderAddRequest(requestBody);
      final response = await http.post(
        _endpoint('/order/add'),
        headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
        body: jsonEncode(requestBody),
      );
      final responseText = _prettyBody(response.body);
      final success = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          !_playAutoBodyHasError(response.body);
      final createdOrderNoText = success
          ? _readCreatedOrderNumberText(response.body)
          : _lastCreatedOrderNoText;
      final createdAt = success ? DateTime.now() : _lastCreatedAt;
      final createdOrderDetails = success
          ? await _debugFetchCreatedPlayAutoOrders(
              apiKey: apiKey,
              token: token,
              responseBody: response.body,
            )
          : null;
      final log = _PlayAutoQuoteOrderAddLog(
        sentAt: DateTime.now(),
        quoteId: widget.quote.id,
        title: _shopSaleNameController.text.trim(),
        statusCode: response.statusCode,
        success: success,
        message: _shortResponseMessage(responseText),
      );
      debugPrint(
        [
          '[PlayAuto /order/add]',
          success ? 'success' : 'business_error',
          'quote=${widget.quote.id}',
          'http=${response.statusCode}',
          'title=${log.title}',
          'response=${log.message}',
        ].join(' '),
      );
      await _saveQuoteOrderAddLog(log);
      if (!mounted) return;
      final resultMessage = _playAutoOrderAddResultMessage(
        success: success,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      setState(() {
        _lastCreatedOrderNoText = createdOrderNoText;
        _lastCreatedAt = createdAt;
        _result = success
            ? [
                resultMessage,
                if (createdOrderNoText?.isNotEmpty == true)
                  '주문번호 $createdOrderNoText',
                if (createdOrderDetails != null) createdOrderDetails,
              ].join('\n')
            : resultMessage;
      });
      _showSnack(resultMessage);
      if (widget.autoSubmit && mounted) {
        Navigator.of(context).pop(resultMessage);
      }
    } on _PlayAutoUserMessage catch (e) {
      if (!mounted) return;
      debugPrint(
          '[PlayAuto /order/add] user-message quote=${widget.quote.id} $e');
      _showSnack(e.message);
      if (widget.autoSubmit && mounted) Navigator.of(context).pop(e.message);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[PlayAuto /order/add] exception quote=${widget.quote.id} $e');
      await _saveQuoteOrderAddLog(
        _PlayAutoQuoteOrderAddLog(
          sentAt: DateTime.now(),
          quoteId: widget.quote.id,
          title: _shopSaleNameController.text.trim(),
          statusCode: null,
          success: false,
          message: e.toString(),
        ),
      );
      _showSnack('플토 주문 등록 실패: $e');
      if (widget.autoSubmit && mounted) {
        Navigator.of(context).pop('플토 주문 등록 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _autoSubmitValidationMessage() {
    final missing = <String>[
      if (_apiKeyController.text.trim().isEmpty) 'API Key',
      if (_customShopCodeController.text.trim().isEmpty) 'shop_cd',
      if (_customShopIdController.text.trim().isEmpty) 'shop_id',
      if (_shopOrderNoController.text.trim().isEmpty) '플토 주문번호',
      if (_shopSaleNameController.text.trim().isEmpty) '주문상품명',
      if (_orderNameController.text.trim().isEmpty) '주문자명',
      if (_orderPhoneController.text.trim().isEmpty) '주문자 연락처',
      if (_receiverNameController.text.trim().isEmpty) '수령자명',
      if (_receiverPhoneController.text.trim().isEmpty) '수령자 연락처',
      if (_zipController.text.trim().isEmpty) '우편번호',
      if (_address1Controller.text.trim().isEmpty) '주소',
      if (_shippingCostController.text.trim().isEmpty) '배송비',
    ];
    if (missing.isEmpty) return null;
    return '플토 주문 전송에 필요한 값이 없습니다: ${missing.join(', ')}';
  }

  Future<void> _ensureAutoSubmitShopAccount(String apiKey) async {
    if (_customShopCodeController.text.trim().isNotEmpty &&
        _customShopIdController.text.trim().isNotEmpty) {
      return;
    }

    final token = await _ensureToken(apiKey);
    final response = await http.get(
      _endpoint('/shops').replace(queryParameters: {'used': 'true'}),
      headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
    );
    final shops = _readShopAccounts(response.body);
    final usableShops = shops.where((shop) => shop.id.trim().isNotEmpty);
    final shop = usableShops.isEmpty ? null : usableShops.first;
    if (shop == null) {
      throw const _PlayAutoUserMessage(
        '플토 주문 전송 실패: 사용 가능한 쇼핑몰 계정을 찾지 못했습니다.',
      );
    }

    if (!mounted) return;
    setState(() {
      _shops = shops;
      _selectedShop = shop;
      _customShopCodeController.text = shop.code;
      _customShopIdController.text = shop.id;
    });
  }

  void _debugPrintPlayAutoOrderAddRequest(Map<String, Object?> requestBody) {
    debugPrint('[PlayAuto /order/add] request amount summary');
    for (final line in widget.lines) {
      final qty = _linePlayAutoSaleCount(line);
      final lineAmount = _linePlayAutoLineAmount(line);
      debugPrint(
        '[PlayAuto /order/add] line '
        'name=${line.name} sale_price(lineAmount)=$lineAmount '
        'sale_cnt=$qty quoteTotal=${line.totalAmount.round()}',
      );
    }
    final opts = requestBody['opts'];
    final goodsTotal = widget.lines.fold<int>(
      0,
      (sum, line) => sum + _linePlayAutoLineAmount(line),
    );
    debugPrint(
      '[PlayAuto /order/add] pay_amt=${requestBody['pay_amt']} '
      'ship_cost=${requestBody['ship_cost']} goods_total=$goodsTotal',
    );
    debugPrint('[PlayAuto /order/add] opts=${jsonEncode(opts)}');
    _debugPrintLong(
      '[PlayAuto /order/add] request body ',
      const JsonEncoder.withIndent('  ').convert(requestBody),
    );
  }

  void _debugPrintLong(String prefix, String text) {
    const chunkSize = 900;
    if (text.length <= chunkSize) {
      debugPrint('$prefix$text');
      return;
    }
    for (var start = 0; start < text.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, text.length);
      debugPrint('$prefix${text.substring(start, end)}');
    }
  }

  Future<String?> _debugFetchCreatedPlayAutoOrders({
    required String apiKey,
    required String token,
    required String responseBody,
  }) async {
    final uniqs = _readCreatedOrderUniqs(responseBody);
    if (uniqs.isEmpty) {
      debugPrint('[PlayAuto /order/add] no uniq found for detail lookup');
      return null;
    }

    final details = <String>[];
    for (final uniq in uniqs.take(5)) {
      try {
        final response = await http.get(
          _endpoint('/order/$uniq'),
          headers: _authorizedJsonHeaders(apiKey: apiKey, token: token),
        );
        final pretty = _prettyBody(response.body);
        final summary = _playAutoOrderDetailSummary(response.body);
        debugPrint(
          '[PlayAuto /order/$uniq] http=${response.statusCode} $summary',
        );
        _debugPrintLong('[PlayAuto /order/$uniq] body ', pretty);
        details.add(
          [
            '주문 $uniq',
            'HTTP ${response.statusCode}',
            if (summary.isNotEmpty) summary,
            pretty,
          ].join('\n'),
        );
      } catch (e) {
        debugPrint('[PlayAuto /order/$uniq] detail lookup failed $e');
        details.add('주문 $uniq\n상세 조회 실패: $e');
      }
    }
    return details.join('\n\n');
  }

  List<String> _readCreatedOrderUniqs(String body) {
    try {
      final uniqs = <String>{};
      void visit(Object? node) {
        if (node is List) {
          for (final value in node) {
            visit(value);
          }
          return;
        }
        if (node is! Map) return;
        final map = node.map((key, value) => MapEntry(key.toString(), value));
        final uniq = map['uniq']?.toString().trim();
        if (uniq != null && uniq.isNotEmpty && uniq != 'null') {
          uniqs.add(uniq);
        }
        for (final value in map.values) {
          visit(value);
        }
      }

      visit(jsonDecode(body));
      return uniqs.toList();
    } catch (_) {
      return const [];
    }
  }

  String _playAutoOrderDetailSummary(String body) {
    try {
      final summaries = <String>[];
      void visit(Object? node) {
        if (node is List) {
          for (final value in node) {
            visit(value);
          }
          return;
        }
        if (node is! Map) return;
        final map = node.map((key, value) => MapEntry(key.toString(), value));
        final interesting = <String>[];
        for (final key in const [
          'uniq',
          'shop_sale_name',
          'shop_opt_name',
          'sale_cnt',
          'opt_sale_cnt',
          'sale_price',
          'sales',
          'pay_amt',
          'shop_cost_price',
          'shop_supply_price',
          'delivery_msg',
          'delivery_message',
          'delivery_memo',
          'delivery_request',
          'delivery_request_msg',
          'ship_msg',
          'ship_message',
          'ship_memo',
          'shipping_message',
          'shipping_memo',
          'shipping_request',
          'order_memo',
          'order_msg',
          'to_memo',
          'receiver_memo',
          'delivery_remark',
          'etc_msg',
          'etc_message',
          'etc_memo',
          'extra_msg',
          'extra_message',
          'extra_memo',
          'admin_msg',
          'admin_memo',
          'manager_msg',
          'manager_memo',
          'cs_memo',
          'mall_memo',
          'seller_memo',
          'private_memo',
        ]) {
          if (map.containsKey(key)) interesting.add('$key=${map[key]}');
        }
        if (interesting.length >= 2) summaries.add(interesting.join(' '));
        for (final value in map.values) {
          visit(value);
        }
      }

      visit(jsonDecode(body));
      return summaries.take(8).join(' | ');
    } catch (_) {
      return '';
    }
  }

  String? _readCreatedOrderNumberText(String body) {
    final uniqs = _readCreatedOrderUniqs(body);
    if (uniqs.isEmpty) return null;
    return '${_formatOrderNoDate(DateTime.now())} 외 ${uniqs.length}건';
  }

  Future<void> _saveQuoteOrderAddLog(_PlayAutoQuoteOrderAddLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final existingText = prefs.getString(_quoteOrderAddLogKey);
    final logs = <_PlayAutoQuoteOrderAddLog>[log];
    if (existingText != null && existingText.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(existingText);
        if (decoded is List) {
          logs.addAll(
            decoded.whereType<Map>().map(
                  (row) => _PlayAutoQuoteOrderAddLog.fromJson(
                    row.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                ),
          );
        }
      } catch (_) {
        // 깨진 기존 로그는 새 로그로 대체한다.
      }
    }
    await prefs.setString(
      _quoteOrderAddLogKey,
      jsonEncode(logs.take(20).map((entry) => entry.toJson()).toList()),
    );
  }

  String _shortResponseMessage(String responseText) {
    final flattened = responseText
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'"token"\s*:\s*"[^"]+"'), '"token":"***"')
        .trim();
    if (flattened.length <= 180) return flattened;
    return '${flattened.substring(0, 180)}...';
  }

  String _playAutoOrderAddResultMessage({
    required bool success,
    required int statusCode,
    required String responseBody,
  }) {
    final reason = _playAutoOrderAddShortReason(responseBody);
    if (success) {
      if (reason.isEmpty || reason == '성공') return '플토 주문 등록 완료';
      return '플토 주문 등록 완료: $reason';
    }
    final fallback = 'HTTP $statusCode';
    return '플토 주문 등록 실패: ${reason.isEmpty ? fallback : reason}';
  }

  String _playAutoOrderAddShortReason(String body) {
    final decoded = _tryDecodePlayAutoJson(body);
    final fromJson = _findPlayAutoReason(decoded);
    if (fromJson.isNotEmpty) return fromJson;

    for (final key in const [
      'results',
      'result',
      'message',
      'msg',
      'error',
      'error_message',
      'reason',
    ]) {
      final match = RegExp(
        '"$key"\\s*:\\s*"([^"]+)"',
        caseSensitive: false,
      ).firstMatch(body);
      if (match != null) return _shortenPlayAutoReason(match.group(1) ?? '');
    }

    if (body.contains('성공')) return '성공';
    if (body.contains('실패')) return _shortenPlayAutoReason(body);
    return '';
  }

  Object? _tryDecodePlayAutoJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      final start = body.indexOf('{');
      final end = body.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      try {
        return jsonDecode(body.substring(start, end + 1));
      } catch (_) {
        return null;
      }
    }
  }

  String _findPlayAutoReason(Object? node) {
    if (node is Map) {
      for (final key in const [
        'error_message',
        'error_msg',
        'message',
        'msg',
        'reason',
        'result',
        'results',
        'error',
      ]) {
        final value = node[key];
        if (value is String && value.trim().isNotEmpty) {
          return _shortenPlayAutoReason(value);
        }
      }
      for (final value in node.values) {
        final found = _findPlayAutoReason(value);
        if (found.isNotEmpty) return found;
      }
    }
    if (node is List) {
      for (final value in node) {
        final found = _findPlayAutoReason(value);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  String _shortenPlayAutoReason(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 80) return compact;
    return '${compact.substring(0, 80)}...';
  }

  bool _playAutoBodyHasError(String body) {
    try {
      return _jsonContainsError(jsonDecode(body));
    } catch (_) {
      final lower = body.toLowerCase();
      return lower.contains('"error"') ||
          lower.contains('error_code') ||
          body.contains('"status": "실패"') ||
          body.contains('"status":"실패"');
    }
  }

  bool _jsonContainsError(Object? node) {
    if (node is Map) {
      if (node.containsKey('error') || node.containsKey('error_code')) {
        return true;
      }
      final status = node['status']?.toString().trim();
      if (status == '실패' || status?.toLowerCase() == 'failed') return true;
      for (final value in node.values) {
        if (_jsonContainsError(value)) return true;
      }
    }
    if (node is List) {
      for (final value in node) {
        if (_jsonContainsError(value)) return true;
      }
    }
    return false;
  }

  Map<String, Object?> _buildRequestBody() {
    final nowText = _formatDateTime(DateTime.now());
    final shopCode = _customShopCodeController.text.trim();
    final shopId = _customShopIdController.text.trim();
    final shipCost =
        double.tryParse(_shippingCostController.text.replaceAll(',', '')) ?? 0;
    final totals = QuoteTotals.fromLines(
      quote: widget.quote,
      lines: widget.lines,
    );
    return {
      'ord_time': nowText,
      'pay_time': nowText,
      if (shopCode.isNotEmpty) 'custom_shop_cd': shopCode,
      if (shopId.isNotEmpty) 'custom_shop_id': shopId,
      'order_name': _orderNameController.text.trim(),
      'order_htel': _orderPhoneController.text.trim(),
      'to_name': _receiverNameController.text.trim(),
      'to_htel': _receiverPhoneController.text.trim(),
      'to_zipcd': _zipController.text.trim(),
      'to_addr1': _address1Controller.text.trim(),
      'to_addr2': _address2Controller.text.trim(),
      'shop_ord_no': _shopOrderNoController.text.trim().isEmpty
          ? '__AUTO__'
          : _shopOrderNoController.text.trim(),
      'shop_sale_name': _shopSaleNameController.text.trim(),
      'ship_method': '선결제',
      'ship_cost': shipCost.round(),
      'pay_amt': totals.total.round(),
      'ship_msg': _shipMessageController.text.trim(),
      'c_sale_cd': widget.quote.id,
      'opts': [
        for (final line in widget.lines)
          {
            'opt_name': _lineOptionName(line),
            'sale_price': _linePlayAutoLineAmount(line),
            'shop_cost_price': 0,
            'shop_supply_price': 0,
            'sale_cnt': _linePlayAutoSaleCount(line),
            'pack_unit': 1,
          },
      ],
    };
  }

  int _linePlayAutoSaleCount(QuoteLine line) {
    return line.qty.round().clamp(1, 999999);
  }

  int _linePlayAutoLineAmount(QuoteLine line) {
    final lineTotal = line.totalAmount.round();
    if (lineTotal > 0) return lineTotal;
    return (line.unitPrice * _linePlayAutoSaleCount(line)).round();
  }

  String _lineOptionName(QuoteLine line) {
    final memo = line.memo?.trim() ?? '';
    if (memo.isEmpty) return line.name.trim();
    return '${line.name.trim()} / $memo';
  }

  Future<String> _ensureToken(String apiKey) async {
    final currentToken = _tokenController.text.trim();
    if (currentToken.isNotEmpty && !_isSavedTokenExpired) return currentToken;
    final authenticationKey = _authenticationKeyController.text.trim();
    if (authenticationKey.isEmpty) {
      throw const _PlayAutoUserMessage('솔루션 인증키를 저장하거나 입력해주세요.');
    }
    final response = await http.post(
      _endpoint('/auth'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      },
      body: jsonEncode({'authentication_key': authenticationKey}),
    );
    final token = _readToken(response.body);
    if (token == null) {
      throw _PlayAutoUserMessage('토큰 자동 발급 실패\n${_prettyBody(response.body)}');
    }
    _tokenController.text = token;
    _tokenIssuedAt = DateTime.now();
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
      key: _tokenIssuedAtKey,
      value: _tokenIssuedAt!.toIso8601String(),
    );
    return token;
  }

  bool get _isSavedTokenExpired {
    final issuedAt = _tokenIssuedAt;
    if (issuedAt == null || _tokenController.text.trim().isEmpty) return false;
    return DateTime.now().difference(issuedAt) >= _tokenLifetime;
  }

  Uri _endpoint(String path) {
    final base =
        _baseUrlController.text.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
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
    final map = node.map((key, value) => MapEntry(key.toString(), value));
    final code = _pickStringFromMap(
      map,
      const ['site_code', 'shop_cd', 'shop_code', 'mall_code', 'code'],
      fallback: inheritedCode,
    );
    final name = _pickStringFromMap(
      map,
      const [
        'site_name',
        'shop_name',
        'mall_name',
        'name',
        'seller_nick',
        'custom_shop_name',
      ],
      fallback: inheritedName,
    );
    final id = _pickStringFromMap(map, const [
      'site_id',
      'shop_id',
      'id',
      'custom_shop_id',
      'mall_id',
      'account_id',
      'seller_id',
      'login_id',
    ]);
    if (code.isNotEmpty) {
      final account = _PlayAutoShopAccount(code: code, id: id, name: name);
      accounts[account.key] = account;
    }
    for (final entry in map.entries) {
      _collectShopAccounts(
        entry.value,
        accounts,
        inheritedCode: _looksLikeShopCode(entry.key) ? entry.key : code,
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

  String? _readToken(String body) {
    try {
      return _findTokenValue(jsonDecode(body));
    } catch (_) {
      return null;
    }
  }

  String? _findTokenValue(Object? node) {
    if (node is Map) {
      for (final key in const ['token', 'access_token', 'auth_token']) {
        final value = node[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
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

  String _prettyBody(String body) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
    } catch (_) {
      return body;
    }
  }

  String _formatDateTime(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  String _formatOrderNoDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$year$month$day$hour$minute$second';
  }

  String? _requiredText(String? value) {
    if ((value ?? '').trim().isEmpty) return '필수 입력';
    return null;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _openChalstockOrderPrint() {
    final document = _buildChalstockOrderPrintDocument();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChalstockOrderPrintView(document: document),
      ),
    );
  }

  _ChalstockOrderPrintDocument _buildChalstockOrderPrintDocument() {
    final createdAt = _lastCreatedAt ?? DateTime.now();
    final totals = QuoteTotals.fromLines(
      quote: widget.quote,
      lines: widget.lines,
    );
    final orderNo = (_lastCreatedOrderNoText ?? '').trim().isNotEmpty
        ? _lastCreatedOrderNoText!.trim()
        : '${_formatOrderNoDate(createdAt)} 외 ${widget.lines.length}건';
    final address = [
      if (_zipController.text.trim().isNotEmpty)
        '(${_zipController.text.trim()})',
      _address1Controller.text.trim(),
      _address2Controller.text.trim(),
    ].where((value) => value.isNotEmpty).join(' ');
    return _ChalstockOrderPrintDocument(
      orderDate: _formatDateTime(createdAt),
      orderNo: orderNo,
      shopName: _selectedShop?.name.trim().isNotEmpty == true
          ? _selectedShop!.name.trim()
          : '직접입력',
      orderName: _orderNameController.text.trim(),
      orderPhone: _orderPhoneController.text.trim(),
      orderTel: '',
      orderMobile: _orderPhoneController.text.trim(),
      receiverName: _receiverNameController.text.trim(),
      receiverPhone: _receiverPhoneController.text.trim(),
      receiverTel: '',
      receiverMobile: _receiverPhoneController.text.trim(),
      address: address,
      shippingMethod: '선결제',
      shippingMessage: _shipMessageController.text.trim(),
      totalQuantity: widget.lines.fold<int>(
        0,
        (sum, line) => sum + _linePlayAutoSaleCount(line),
      ),
      totalAmount: totals.total.round(),
      lines: [
        for (final line in widget.lines)
          _ChalstockOrderPrintLine(
            productName: line.name,
            optionName: line.memo?.trim().isNotEmpty == true
                ? line.memo!.trim()
                : line.name,
            quantity: _linePlayAutoSaleCount(line),
            amount: line.totalAmount.round(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.autoSubmit) {
      return Scaffold(
        appBar: AppBar(title: const Text('플토 주문 전송')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('플토 주문을 전송하고 있습니다'),
            ],
          ),
        ),
      );
    }
    final totals = QuoteTotals.fromLines(
      quote: widget.quote,
      lines: widget.lines,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('플토 주문')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '견적 ${widget.lines.length}개 품목 · 합계 ${NumberFormat('#,##0').format(totals.total)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _sectionTitle('플토 계정'),
            TextFormField(
              controller: _baseUrlController,
              decoration: const InputDecoration(labelText: 'API 주소'),
              validator: _requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(labelText: 'API Key'),
              validator: _requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _authenticationKeyController,
              decoration: const InputDecoration(labelText: '솔루션 인증키'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<_PlayAutoShopAccount>(
                    value: _selectedShop,
                    decoration: const InputDecoration(labelText: '직접입력 쇼핑몰'),
                    items: [
                      for (final shop in _shops)
                        DropdownMenuItem(value: shop, child: Text(shop.label)),
                    ],
                    onChanged: (shop) {
                      setState(() {
                        _selectedShop = shop;
                        if (shop != null) {
                          _customShopCodeController.text = shop.code;
                          _customShopIdController.text = shop.id;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: '쇼핑몰 불러오기',
                  onPressed: _loadingShops ? null : _fetchShops,
                  icon: _loadingShops
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customShopCodeController,
                    decoration: const InputDecoration(labelText: 'shop_cd'),
                    validator: _requiredText,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _customShopIdController,
                    decoration: const InputDecoration(labelText: 'shop_id'),
                    validator: _requiredText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('주문 정보'),
            TextFormField(
              controller: _shopOrderNoController,
              decoration: const InputDecoration(labelText: '플토 주문번호'),
              validator: _requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _shopSaleNameController,
              decoration: const InputDecoration(labelText: '주문상품명'),
              validator: _requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _orderNameController,
              decoration: const InputDecoration(labelText: '주문자명'),
              validator: _requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _orderPhoneController,
              decoration: const InputDecoration(labelText: '주문자 연락처'),
              keyboardType: TextInputType.phone,
              validator: _requiredText,
            ),
            const SizedBox(height: 20),
            _sectionTitle('배송 정보'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _addressEntries.isEmpty ? null : _openAddressBook,
                  icon: const Icon(Icons.manage_search_outlined),
                  label: Text(
                    _addressEntries.isEmpty
                        ? '불러올 고객/거래처 주소 없음'
                        : '고객/거래처 배송지 불러오기',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openDaumPostcodeSearch,
                  icon: const Icon(Icons.travel_explore_outlined),
                  label: const Text('수령자 주소 검색'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _receiverNameController,
              decoration: const InputDecoration(labelText: '수령자명'),
              validator: _requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _receiverPhoneController,
              decoration: const InputDecoration(labelText: '수령자 연락처'),
              keyboardType: TextInputType.phone,
              validator: _requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _zipController,
              decoration: const InputDecoration(labelText: '우편번호'),
              keyboardType: TextInputType.number,
              validator: _requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _address1Controller,
              decoration: InputDecoration(
                labelText: '주소',
                suffixIcon: IconButton(
                  tooltip: '수령자 주소 검색',
                  onPressed: _openDaumPostcodeSearch,
                  icon: const Icon(Icons.search),
                ),
              ),
              validator: _requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _address2Controller,
              decoration: const InputDecoration(labelText: '상세주소'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _shippingCostController,
              decoration: const InputDecoration(labelText: '배송비'),
              keyboardType: TextInputType.number,
              validator: _requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _shipMessageController,
              decoration: const InputDecoration(labelText: '배송메시지'),
            ),
            const SizedBox(height: 20),
            _sectionTitle('품목'),
            for (final line in widget.lines)
              Card(
                child: ListTile(
                  title: Text(line.name),
                  subtitle: Text([
                    '${_formatQty(line.qty)} ${line.unit}',
                    '${NumberFormat('#,##0').format(line.unitPrice)}원',
                    if ((_lineSkus[line.id] ?? '').isNotEmpty)
                      '찰스톡 SKU ${_lineSkus[line.id]}',
                  ].join(' · ')),
                  trailing:
                      Text(NumberFormat('#,##0').format(line.totalAmount)),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('플토 주문 생성'),
                ),
                OutlinedButton.icon(
                  onPressed: _openChalstockOrderPrint,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('주문서 보기/인쇄'),
                ),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              SelectableText(
                _result!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  String _formatQty(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
}

class _ChalstockOrderPrintDocument {
  const _ChalstockOrderPrintDocument({
    required this.orderDate,
    required this.orderNo,
    required this.shopName,
    required this.orderName,
    required this.orderPhone,
    required this.orderTel,
    required this.orderMobile,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverTel,
    required this.receiverMobile,
    required this.address,
    required this.shippingMethod,
    required this.shippingMessage,
    required this.totalQuantity,
    required this.totalAmount,
    required this.lines,
  });

  final String orderDate;
  final String orderNo;
  final String shopName;
  final String orderName;
  final String orderPhone;
  final String orderTel;
  final String orderMobile;
  final String receiverName;
  final String receiverPhone;
  final String receiverTel;
  final String receiverMobile;
  final String address;
  final String shippingMethod;
  final String shippingMessage;
  final int totalQuantity;
  final int totalAmount;
  final List<_ChalstockOrderPrintLine> lines;
}

class _ChalstockOrderPrintLine {
  const _ChalstockOrderPrintLine({
    required this.productName,
    required this.optionName,
    required this.quantity,
    required this.amount,
  });

  final String productName;
  final String optionName;
  final int quantity;
  final int amount;
}

class _ChalstockOrderPrintView extends StatelessWidget {
  const _ChalstockOrderPrintView({required this.document});

  final _ChalstockOrderPrintDocument document;

  @override
  Widget build(BuildContext context) {
    final captureKey = GlobalKey();
    return Scaffold(
      appBar: AppBar(
        title: const Text('주문서'),
        actions: [
          IconButton(
            tooltip: 'PDF 저장/인쇄',
            onPressed: () => _shareChalstockOrderPdf(
              context,
              captureKey: captureKey,
              document: document,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'JPG 내보내기',
            onPressed: () => _shareChalstockOrderJpg(
              context,
              captureKey: captureKey,
              document: document,
            ),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ColoredBox(
        color: Colors.grey.shade200,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: RepaintBoundary(
              key: captureKey,
              child: _ChalstockOrderPrintPage(document: document),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChalstockOrderPrintPage extends StatelessWidget {
  const _ChalstockOrderPrintPage({required this.document});

  final _ChalstockOrderPrintDocument document;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 390,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          height: 1.38,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '주문서',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            _orderMobileSection(
              title: '주문 내역',
              children: [
                _orderMobileInfoLine('주문일', document.orderDate),
                _orderMobileInfoLine('구매 쇼핑몰', document.shopName),
                _orderMobileInfoLine('주문번호', document.orderNo),
              ],
            ),
            const SizedBox(height: 14),
            _orderMobileSection(
              title: '배송 정보',
              children: [
                _orderMobileInfoLine('주문자', document.orderName),
                _orderMobileInfoLine('주문자 전화번호', document.orderTel),
                _orderMobileInfoLine('주문자 휴대폰번호', document.orderMobile),
                _orderMobileInfoLine('고객명', document.receiverName),
                _orderMobileInfoLine('고객 전화번호', document.receiverTel),
                _orderMobileInfoLine('고객 휴대폰번호', document.receiverMobile),
                _orderMobileInfoLine('주소', document.address),
                _orderMobileInfoLine('배송방법', document.shippingMethod),
                if (document.shippingMessage.trim().isNotEmpty)
                  _orderMobileInfoLine('배송메시지', document.shippingMessage),
              ],
            ),
            const SizedBox(height: 18),
            const Text('상품 내역', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (document.lines.isEmpty) _orderMobileEmptyBox('주문 상품이 없습니다.'),
            for (final line in document.lines)
              _orderMobileLineCard(
                productName: line.productName,
                optionName: line.optionName,
                quantity: line.quantity,
                unitPrice: line.quantity > 0
                    ? (line.amount / line.quantity).round()
                    : 0,
                amount: line.amount,
              ),
            const SizedBox(height: 8),
            _orderMobileTotalBox(
              children: [
                _orderMobileTextTotalLine(
                  '주문 총 수량',
                  '${document.totalQuantity}개',
                ),
                _orderMobileMoneyTotalLine(
                  '주문 총 금액',
                  document.totalAmount,
                  bold: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _printMoney(int value) => NumberFormat('#,##0').format(value);

Widget _orderMobileSection({
  required String title,
  required List<Widget> children,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 7),
      ...children,
    ],
  );
}

Widget _orderMobileInfoLine(String label, String value) {
  final display = value.trim().isEmpty ? '-' : value.trim();
  return Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Text(display)),
      ],
    ),
  );
}

Widget _orderMobileLineCard({
  required String productName,
  required String optionName,
  required int quantity,
  required int unitPrice,
  required int amount,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(border: Border.all(color: Colors.black38)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          productName.trim().isEmpty ? '상품명 없음' : productName.trim(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (optionName.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(optionName.trim(), style: const TextStyle(fontSize: 12.5)),
        ],
        const SizedBox(height: 10),
        _orderMobileAmountRow('수량', '$quantity개'),
        _orderMobileAmountRow(
          '단가',
          unitPrice > 0 ? '${_printMoney(unitPrice)} 원' : '-',
        ),
        _orderMobileAmountRow(
          '금액',
          amount > 0 ? '${_printMoney(amount)} 원' : '-',
          bold: true,
        ),
      ],
    ),
  );
}

Widget _orderMobileAmountRow(String label, String value, {bool bold = false}) {
  final style =
      TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, textAlign: TextAlign.right, style: style),
      ],
    ),
  );
}

Widget _orderMobileEmptyBox(String text) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
    child: Text(text, textAlign: TextAlign.center),
  );
}

Widget _orderMobileTotalBox({required List<Widget> children}) {
  return Container(
    decoration: BoxDecoration(border: Border.all(color: Colors.black87)),
    child: Column(children: children),
  );
}

Widget _orderMobileTextTotalLine(
  String label,
  String value, {
  bool bold = false,
}) {
  final style =
      TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.black26)),
    ),
    child: Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    ),
  );
}

Widget _orderMobileMoneyTotalLine(
  String label,
  int value, {
  bool bold = false,
}) {
  return _orderMobileTextTotalLine(
    label,
    '${_printMoney(value)} 원',
    bold: bold,
  );
}

Future<void> _shareChalstockOrderPdf(
  BuildContext context, {
  required GlobalKey captureKey,
  required _ChalstockOrderPrintDocument document,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    final pngBytes = await _captureChalstockOrderPng(captureKey);
    final subject = '주문서_${_safePrintFileName(document.orderNo)}';
    final pdfBytes = await _buildChalstockOrderPdf(
      pngBytes: pngBytes,
      subject: subject,
    );
    final tempDir = await getTemporaryDirectory();
    final outFile = File('${tempDir.path}/$subject.pdf');
    await outFile.writeAsBytes(pdfBytes, flush: true);
    await Share.shareXFiles(
      [XFile(outFile.path, mimeType: 'application/pdf', name: '$subject.pdf')],
      subject: subject,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('주문서 PDF 내보내기에 실패했습니다: $e')),
    );
  }
}

Future<void> _shareChalstockOrderJpg(
  BuildContext context, {
  required GlobalKey captureKey,
  required _ChalstockOrderPrintDocument document,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    final pngBytes = await _captureChalstockOrderPng(captureKey);
    final decoded = image_lib.decodePng(pngBytes);
    if (decoded == null) throw StateError('주문서 이미지 인코딩에 실패했습니다.');
    final jpgBytes = image_lib.encodeJpg(decoded, quality: 90);
    final tempDir = await getTemporaryDirectory();
    final subject = '주문서_${_safePrintFileName(document.orderNo)}';
    final outFile = File('${tempDir.path}/$subject.jpg');
    await outFile.writeAsBytes(jpgBytes, flush: true);
    await Share.shareXFiles(
      [XFile(outFile.path, mimeType: 'image/jpeg', name: '$subject.jpg')],
      subject: subject,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('주문서 JPG 내보내기에 실패했습니다: $e')),
    );
  }
}

Future<Uint8List> _captureChalstockOrderPng(GlobalKey captureKey) async {
  await WidgetsBinding.instance.endOfFrame;
  final boundary =
      captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw StateError('주문서 이미지를 만들 수 없습니다.');
  final captured = await boundary.toImage(pixelRatio: 3);
  final byteData = await captured.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData?.buffer.asUint8List();
  if (pngBytes == null) throw StateError('주문서 이미지 변환에 실패했습니다.');
  return pngBytes;
}

Future<Uint8List> _buildChalstockOrderPdf({
  required Uint8List pngBytes,
  required String subject,
}) async {
  final doc = pw.Document(title: subject);
  final image = pw.MemoryImage(pngBytes);
  final decoded = image_lib.decodePng(pngBytes);
  final aspectRatio =
      decoded == null ? 0.5 : decoded.width / math.max(1, decoded.height);
  const pageFormat = PdfPageFormat.a4;
  const margin = 36.0;
  const preferredImageWidth = 300.0;
  final maxImageHeight = pageFormat.height - (margin * 2);
  final imageWidth = math.min(
    preferredImageWidth,
    maxImageHeight * aspectRatio,
  );
  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(margin),
      build: (_) => pw.Align(
        alignment: pw.Alignment.topCenter,
        child: pw.Image(image, width: imageWidth, fit: pw.BoxFit.contain),
      ),
    ),
  );
  return doc.save();
}

String _safePrintFileName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return cleaned.isEmpty ? 'order' : cleaned;
}

class _PlayAutoOrderPreviewScreenState
    extends State<_PlayAutoOrderPreviewScreen> {
  static const _uuid = Uuid();
  final _scrollController = ScrollController();
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
  var _runningAction = false;
  var _cacheNotice = '캐시 조회는 저장된 주문을 먼저 보여주고, 동기화는 PlayAuto에서 새로 가져옵니다.';
  String? _selectedShopName;
  _PlayAutoFulfillmentStage _stage = _PlayAutoFulfillmentStage.all;

  @override
  void initState() {
    super.initState();
    _orders = widget.orders;
    _startDateController = TextEditingController(text: widget.startDate);
    _endDateController = TextEditingController(text: widget.endDate);
    _lengthController = TextEditingController(text: widget.length.toString());
    _loadMappings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _PlayAutoOrderNotificationService.showBadgeOnly(0);
      if (!mounted || _orders.isNotEmpty) return;
      _fetchOrders(forceRefresh: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PlayAutoOrderPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.orders, widget.orders)) {
      setState(() => _orders = widget.orders);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filteredOrders = _filteredOrders;
    final totalQty =
        filteredOrders.fold<int>(0, (sum, order) => sum + order.quantity);
    final shopNames = _shopNames;

    final body = CustomScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrderQueryPanel(
                  startDateController: _startDateController,
                  endDateController: _endDateController,
                  lengthController: _lengthController,
                  loading: _loadingOrders,
                  orderCount: filteredOrders.length,
                  totalQty: totalQty,
                  matchedCount: _matchedCount(filteredOrders),
                  needsMappingCount: _needsMappingCount(filteredOrders),
                  availableCount: _availableCount(filteredOrders),
                  shortageCount: _shortageCount(filteredOrders),
                  onPickStartDate: () => _pickDate(_startDateController),
                  onPickEndDate: () => _pickDate(_endDateController),
                  onFetch: () => _fetchOrders(forceRefresh: false),
                  onRefresh: () => _fetchOrders(forceRefresh: true),
                ),
                const SizedBox(height: 6),
                _PlayAutoSummaryBand(
                  fulfillmentMode: widget.fulfillmentMode,
                  selectedStage: _stage,
                  orders: _orders,
                  orderLinks: _orderLinks,
                  onStageSelected: (stage) => setState(() => _stage = stage),
                ),
                if (widget.fulfillmentMode) ...[
                  if (_runningAction) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                ],
                if (_loadingMappings) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    _cacheNotice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
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
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: scheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: scheme.primary, width: 1.4),
                    ),
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
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: scheme.outlineVariant),
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
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(color: scheme.outlineVariant),
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
                  onOpenOrCreateOrder: () => _openOrCreateChalstockOrder(order),
                  onOpenMatchedItem: () {
                    final itemId =
                        _mappings[_playAutoMappingKey(order)]?.itemId;
                    if (itemId != null) _openMatchedItem(itemId);
                  },
                  fulfillmentMode: widget.fulfillmentMode,
                  actionRunning: _runningAction,
                  onInstruction: () => _runFulfillmentAction(
                    label: '출고지시',
                    request: () => widget.onInstruction(order),
                    refreshOrder: order,
                  ),
                  onOpenPrintPreview: () => _openPrintPreview(order),
                  onRegisterInvoice: () => _openInvoiceDialog(order),
                  onSendInvoice: () => _sendInvoiceAfterSync(order),
                ),
              );
            },
          ),
      ],
    );

    final bodyWithScrollTop = Stack(
      children: [
        body,
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'play_auto_scroll_top',
            tooltip: '맨 위로',
            onPressed: _scrollToTop,
            child: const Icon(Icons.keyboard_arrow_up),
          ),
        ),
      ],
    );

    if (widget.embedded) return bodyWithScrollTop;

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
      body: bodyWithScrollTop,
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  List<_PlayAutoOrderPreview> get _filteredOrders {
    final normalizedQuery = _normalizeSearchText(_query);
    return _orders.where((order) {
      final shopMatches =
          _selectedShopName == null || order.shopName == _selectedShopName;
      if (!shopMatches) return false;
      if (widget.fulfillmentMode &&
          !_stage.matches(order, _orderLinks[_playAutoOrderGroupKey(order)])) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;
      return order.searchText.contains(normalizedQuery);
    }).toList();
  }

  Future<void> _runFulfillmentAction({
    required String label,
    required Future<_PlayAutoResponse> Function() request,
    bool refreshAfter = false,
    _PlayAutoOrderPreview? refreshOrder,
  }) async {
    setState(() => _runningAction = true);
    try {
      final response = await request();
      if (!mounted) return;
      final ok = _playAutoResponseSucceeded(response);
      debugPrint(
        [
          '[PlayAuto fulfillment]',
          label,
          ok ? 'success' : 'failed',
          if (response.statusCode != null) 'http=${response.statusCode}',
          'body=${_compactDebugText(response.body)}',
        ].join(' '),
      );
      _showSnack(_playAutoActionSnack(label, response, ok: ok));
      if (ok && refreshOrder != null) {
        await _refreshSingleOrder(refreshOrder);
      } else if (refreshAfter) {
        await _fetchOrders(forceRefresh: true);
      }
    } on _PlayAutoUserMessage catch (e) {
      if (!mounted) return;
      debugPrint('[PlayAuto fulfillment] $label user-message ${e.message}');
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[PlayAuto fulfillment] $label exception $e');
      _showSnack('$label 실패: $e');
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _refreshSingleOrder(_PlayAutoOrderPreview order) async {
    if (order.uniq.trim().isEmpty) {
      await _fetchOrders(forceRefresh: true);
      return;
    }

    await Future<void>.delayed(const Duration(seconds: 1));
    try {
      final latest = await widget.onFetchOrderDetail(order);
      if (!mounted || latest == null) return;
      setState(() {
        _orders = [
          for (final existing in _orders)
            if (_samePlayAutoOrder(existing, order)) latest else existing,
        ];
        _cacheNotice =
            '주문 1건 갱신 · ${_PlayAutoOrderFetchResult.formatNoticeTime(DateTime.now())}';
      });
    } catch (e) {
      debugPrint('[PlayAuto fulfillment] single order refresh failed $e');
    }
  }

  Future<void> _sendInvoiceAfterSync(_PlayAutoOrderPreview order) async {
    await _runFulfillmentAction(
      label: '송장전송',
      request: () async {
        debugPrint(
          '[PlayAuto SEND_INVOICE] sync-before-send '
          'current_target=${order.playAutoWorkTargetNo} '
          'order_no=${order.orderNo} status=${order.status}',
        );
        final syncedOrders = await _fetchOrders(
          forceRefresh: true,
          showLoading: false,
        );
        var latest = _findSyncedOrder(order, syncedOrders) ?? order;
        debugPrint(
          '[PlayAuto SEND_INVOICE] synced-target '
          'target=${latest.playAutoWorkTargetNo} '
          'bundle=${latest.bundleNo} uniq=${latest.uniq} '
          'order_no=${latest.orderNo} status=${latest.status} '
          'invoice=${latest.invoiceNo}',
        );
        final responses = <String>[];
        if (latest.status.contains('운송장출력')) {
          debugPrint(
            '[PlayAuto SEND_INVOICE] complete-before-send '
            'bundle=${latest.bundleNo} carrier=${latest.carrierCode} '
            'invoice=${latest.invoiceNo}',
          );
          final completeResponse = await widget.onCompleteInvoice(latest);
          responses.add(completeResponse.body);
          if (!_playAutoResponseSucceeded(completeResponse)) {
            return _PlayAutoResponse(
              statusCode: completeResponse.statusCode,
              body: [
                '송장전송 전 출고완료 처리 실패',
                '',
                completeResponse.body,
              ].join('\n'),
            );
          }
          final completedOrders = await _fetchOrders(
            forceRefresh: true,
            showLoading: false,
          );
          latest = _findSyncedOrder(latest, completedOrders) ?? latest;
          debugPrint(
            '[PlayAuto SEND_INVOICE] completed-target '
            'target=${latest.playAutoWorkTargetNo} '
            'bundle=${latest.bundleNo} uniq=${latest.uniq} '
            'status=${latest.status} invoice=${latest.invoiceNo}',
          );
        }
        final sendResponse = await widget.onSendInvoice(latest);
        if (responses.isEmpty) return sendResponse;
        return _PlayAutoResponse(
          statusCode: sendResponse.statusCode,
          body: [
            '송장전송 전 처리',
            responses.join('\n\n---\n\n'),
            '',
            '송장전송',
            sendResponse.body,
          ].join('\n'),
        );
      },
      refreshAfter: true,
    );
  }

  _PlayAutoOrderPreview? _findSyncedOrder(
    _PlayAutoOrderPreview original,
    List<_PlayAutoOrderPreview> syncedOrders,
  ) {
    final matched = _findMatchingOrderPreview(original, syncedOrders);
    if (matched != null) return matched;
    final originalGroup = _playAutoOrderGroupKey(original);
    for (final order in syncedOrders) {
      if (_playAutoOrderGroupKey(order) == originalGroup &&
          _normalizeSearchText(order.productName) ==
              _normalizeSearchText(original.productName) &&
          _normalizeSearchText(order.optionName) ==
              _normalizeSearchText(original.optionName)) {
        return order;
      }
    }
    return null;
  }

  String _compactDebugText(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 260) return compact;
    return '${compact.substring(0, 260)}...';
  }

  String _playAutoActionSnack(
    String label,
    _PlayAutoResponse response, {
    required bool ok,
  }) {
    final reason = _playAutoShortReason(response.body);
    if (ok) {
      if (reason.isEmpty || reason == '성공') return '$label 완료';
      return '$label 완료: $reason';
    }

    final fallback = response.statusCode == null
        ? '응답을 확인해주세요.'
        : 'HTTP ${response.statusCode}';
    return '$label 실패: ${reason.isEmpty ? fallback : reason}';
  }

  String _playAutoShortReason(String body) {
    final decoded = _tryDecodeJsonObject(body);
    final fromJson = _findPlayAutoReason(decoded);
    if (fromJson.isNotEmpty) return fromJson;

    for (final key in const [
      'results',
      'result',
      'message',
      'msg',
      'error',
      'error_message',
      'reason',
    ]) {
      final match = RegExp(
        '"$key"\\s*:\\s*"([^"]+)"',
        caseSensitive: false,
      ).firstMatch(body);
      if (match != null) return _shortenReason(match.group(1) ?? '');
    }

    if (body.contains('성공')) return '성공';
    if (body.contains('실패')) return _shortenReason(body);
    return '';
  }

  Object? _tryDecodeJsonObject(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      final start = body.indexOf('{');
      final end = body.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      try {
        return jsonDecode(body.substring(start, end + 1));
      } catch (_) {
        return null;
      }
    }
  }

  String _findPlayAutoReason(Object? node) {
    if (node is Map) {
      for (final key in const [
        'error_message',
        'error_msg',
        'message',
        'msg',
        'reason',
        'result',
        'results',
        'error',
      ]) {
        final value = node[key];
        if (value is String && value.trim().isNotEmpty) {
          return _shortenReason(value);
        }
      }
      for (final value in node.values) {
        final found = _findPlayAutoReason(value);
        if (found.isNotEmpty) return found;
      }
    }
    if (node is List) {
      for (final value in node) {
        final found = _findPlayAutoReason(value);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  String _shortenReason(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 80) return compact;
    return '${compact.substring(0, 80)}...';
  }

  bool _playAutoResponseSucceeded(_PlayAutoResponse response) {
    final statusOk = response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300;
    if (!statusOk) return false;
    try {
      return !_jsonContainsError(jsonDecode(response.body));
    } catch (_) {
      final lower = response.body.toLowerCase();
      return !lower.contains('"error"') && !lower.contains('error_code');
    }
  }

  bool _jsonContainsError(Object? node) {
    if (node is Map) {
      if (node.containsKey('error') || node.containsKey('error_code')) {
        return true;
      }
      final status = node['status']?.toString().trim();
      if (status == '실패' || status?.toLowerCase() == 'failed') return true;
      for (final value in node.values) {
        if (_jsonContainsError(value)) return true;
      }
    }
    if (node is List) {
      for (final value in node) {
        if (_jsonContainsError(value)) return true;
      }
    }
    return false;
  }

  Future<void> _openInvoiceDialog(_PlayAutoOrderPreview order) async {
    final input = await showDialog<_InvoiceRegistrationInput>(
      context: context,
      builder: (_) => _InvoiceRegistrationDialog(order: order),
    );
    if (input == null) return;
    await _runFulfillmentAction(
      label: '송장번호 입력',
      request: () => widget.onSetInvoice(
        order,
        input.carrierCode,
        input.invoiceNo,
      ),
      refreshAfter: true,
    );
  }

  void _openPrintPreview(_PlayAutoOrderPreview order) {
    final groupKey = _playAutoOrderGroupKey(order);
    final lines = _orders
        .where((candidate) => _playAutoOrderGroupKey(candidate) == groupKey)
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlayAutoOrderPrintPreviewScreen(
          order: order,
          lines: lines.isEmpty ? [order] : lines,
        ),
      ),
    );
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

    final planningService = OrderPlanningService(
      items: context.read<ItemRepo>(),
      orders: context.read<OrderRepo>(),
      works: context.read<WorkRepo>(),
      purchases: context.read<PurchaseOrderRepo>(),
      txns: context.read<TxnRepo>(),
    );
    await planningService.saveOrderAndAutoPlanShortage(
      chalstockOrder,
      preferWork: true,
      forceMake: false,
    );
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

  Future<List<_PlayAutoOrderPreview>> _fetchOrders({
    required bool forceRefresh,
    bool showLoading = true,
  }) async {
    final sdate = _startDateController.text.trim();
    final edate = _endDateController.text.trim();
    final length = int.tryParse(_lengthController.text.trim());
    if (length == null || length <= 0 || length > 3000) {
      _showSnack('조회 개수는 1~3000 사이로 입력해주세요.');
      return _orders;
    }
    final startDate = DateTime.tryParse(sdate);
    final endDate = DateTime.tryParse(edate);
    if (startDate == null || endDate == null) {
      _showSnack('조회 날짜는 YYYY-MM-DD 형식으로 선택해주세요.');
      return _orders;
    }
    if (startDate.isAfter(endDate)) {
      _showSnack('시작일은 종료일보다 늦을 수 없습니다.');
      return _orders;
    }

    if (showLoading) setState(() => _loadingOrders = true);
    try {
      final result = await widget.onFetchOrders(
        sdate: sdate,
        edate: edate,
        length: length,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return result.orders;
      setState(() {
        _orders = result.orders;
        _selectedShopName = null;
        _cacheNotice = result.notice;
      });
      await _loadMappings();
      return result.orders;
    } on _PlayAutoUserMessage catch (e) {
      if (!mounted) return _orders;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return _orders;
      _showSnack('주문 조회 실패: $e');
    } finally {
      if (mounted && showLoading) setState(() => _loadingOrders = false);
    }
    return _orders;
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
    required this.fulfillmentMode,
    required this.selectedStage,
    required this.orders,
    required this.orderLinks,
    required this.onStageSelected,
  });

  final bool fulfillmentMode;
  final _PlayAutoFulfillmentStage selectedStage;
  final List<_PlayAutoOrderPreview> orders;
  final Map<String, PlayAutoOrderLink> orderLinks;
  final ValueChanged<_PlayAutoFulfillmentStage> onStageSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            if (fulfillmentMode)
              for (final stage in _PlayAutoFulfillmentStage.values)
                _CompactFilterChip(
                  label: stage.label,
                  value: '${_stageCount(stage)}',
                  selected: selectedStage == stage,
                  onTap: () => onStageSelected(stage),
                ),
          ],
        ),
      ),
    );
  }

  int _stageCount(_PlayAutoFulfillmentStage stage) {
    return orders
        .where((order) =>
            stage.matches(order, orderLinks[_playAutoOrderGroupKey(order)]))
        .length;
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
        ),
      ],
    );
  }
}

class _CompactFilterChip extends StatelessWidget {
  const _CompactFilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected
        ? scheme.primaryContainer.withValues(alpha: 0.8)
        : scheme.surface.withValues(alpha: 0.92);
    final borderColor = selected
        ? scheme.primary.withValues(alpha: 0.72)
        : scheme.outlineVariant;
    final textColor = selected ? scheme.onPrimaryContainer : scheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: textColor),
              const SizedBox(width: 3),
            ],
            Text(
              '$label $value',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: textColor,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ],
        ),
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
    required this.orderCount,
    required this.totalQty,
    required this.matchedCount,
    required this.needsMappingCount,
    required this.availableCount,
    required this.shortageCount,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onFetch,
    required this.onRefresh,
  });

  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final TextEditingController lengthController;
  final bool loading;
  final int orderCount;
  final int totalQty;
  final int matchedCount;
  final int needsMappingCount;
  final int availableCount;
  final int shortageCount;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onFetch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 148,
                child: TextField(
                  controller: startDateController,
                  readOnly: true,
                  onTap: onPickStartDate,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.24),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    labelText: '주문수집 시작일',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 126,
                child: TextField(
                  controller: endDateController,
                  readOnly: true,
                  onTap: onPickEndDate,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.24),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    labelText: '종료일',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: TextField(
                  controller: lengthController,
                  keyboardType: TextInputType.number,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.24),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
                    labelText: '개수',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: loading ? null : onFetch,
                child: loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('캐시'),
              ),
              IconButton.filled(
                visualDensity: VisualDensity.compact,
                tooltip: '동기화',
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.sync_outlined),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                _SummaryValue(label: '주문', value: '$orderCount'),
                _SummaryValue(label: '수량', value: '$totalQty'),
                _SummaryValue(
                    label: '매칭', value: '$matchedCount/$needsMappingCount'),
                _SummaryValue(label: '출고', value: '$availableCount'),
                _SummaryValue(label: '부족', value: '$shortageCount'),
              ],
            ),
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
    required this.fulfillmentMode,
    required this.actionRunning,
    required this.onInstruction,
    required this.onOpenPrintPreview,
    required this.onRegisterInvoice,
    required this.onSendInvoice,
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
  final bool fulfillmentMode;
  final bool actionRunning;
  final VoidCallback onInstruction;
  final VoidCallback onOpenPrintPreview;
  final VoidCallback onRegisterInvoice;
  final VoidCallback onSendInvoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final linked = mapping?.isConfirmed == true;
    final needsAttention = _needsAttentionBeforeSent;
    final cardColor = needsAttention
        ? const Color(0xFFFFFBEA)
        : Theme.of(context).cardTheme.color;
    final borderColor =
        needsAttention ? const Color(0xFFE5D19B) : scheme.outlineVariant;

    return Card(
      margin: EdgeInsets.zero,
      elevation: needsAttention ? 0.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor),
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
                        vertical: 1,
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
                            const SizedBox(height: 5),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    order.optionName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: scheme.onSurfaceVariant),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _OrderQuantityBadge(quantity: order.quantity),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 5),
                            Align(
                              alignment: Alignment.centerLeft,
                              child:
                                  _OrderQuantityBadge(quantity: order.quantity),
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
                            scheme.primaryContainer.withValues(alpha: 0.24),
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
            if (fulfillmentMode) ...[
              const SizedBox(height: 10),
              _FulfillmentActionBar(
                order: order,
                mapping: mapping,
                actionRunning: actionRunning,
                onInstruction: onInstruction,
                onOpenPrintPreview: onOpenPrintPreview,
                onOpenOrCreateOrder: onOpenOrCreateOrder,
                onRegisterInvoice: onRegisterInvoice,
                onSendInvoice: onSendInvoice,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  text: order.orderDate,
                ),
                _InfoChip(
                  icon: Icons.storefront_outlined,
                  text: order.shopName,
                ),
                _InfoChip(icon: Icons.person_outline, text: order.customerName),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 10),
            if (order.invoiceNo.isNotEmpty) ...[
              _DeliveryTrackingRow(order: order),
              const SizedBox(height: 6),
            ],
            if (_displayTel.isNotEmpty) ...[
              _MutedLine(label: '전화번호', value: _displayTel),
              const SizedBox(height: 6),
            ],
            if (_displayMobile.isNotEmpty) ...[
              _MutedLine(label: '휴대폰번호', value: _displayMobile),
              const SizedBox(height: 6),
            ],
            if (order.address.isNotEmpty) ...[
              _MutedLine(label: '주소', value: order.address, maxLines: 2),
            ],
          ],
        ),
      ),
    );
  }

  String get _displayTel {
    for (final value in [order.receiverTel, order.ordererTel]) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  String get _displayMobile {
    for (final value in [order.receiverMobile, order.ordererMobile]) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  bool get _needsAttentionBeforeSent {
    final status = order.status;
    return !(status.contains('출고완료') ||
        status.contains('배송중') ||
        status.contains('배송완료') ||
        status.contains('구매결정'));
  }
}

enum _PlayAutoFulfillmentStage {
  all('전체'),
  fresh('신규'),
  ready('출고대기'),
  chalstock('작업등록'),
  invoice('운송장출력'),
  sent('전송완료'),
  shipping('배송중'),
  done('완료');

  const _PlayAutoFulfillmentStage(this.label);

  final String label;

  bool matches(
    _PlayAutoOrderPreview order,
    PlayAutoOrderLink? orderLink,
  ) {
    final status = order.status;
    return switch (this) {
      _PlayAutoFulfillmentStage.all => true,
      _PlayAutoFulfillmentStage.fresh =>
        status.contains('신규') || status.contains('결제완료'),
      _PlayAutoFulfillmentStage.ready =>
        status.contains('출고대기') || status.contains('출고보류'),
      _PlayAutoFulfillmentStage.chalstock => orderLink != null,
      _PlayAutoFulfillmentStage.invoice => status.contains('운송장출력'),
      _PlayAutoFulfillmentStage.sent => status.contains('출고완료'),
      _PlayAutoFulfillmentStage.shipping => status.contains('배송중'),
      _PlayAutoFulfillmentStage.done =>
        status.contains('배송완료') || status.contains('구매결정'),
    };
  }
}

class _FulfillmentActionBar extends StatelessWidget {
  const _FulfillmentActionBar({
    required this.order,
    required this.mapping,
    required this.actionRunning,
    required this.onInstruction,
    required this.onOpenPrintPreview,
    required this.onOpenOrCreateOrder,
    required this.onRegisterInvoice,
    required this.onSendInvoice,
  });

  final _PlayAutoOrderPreview order;
  final PlayAutoItemMapping? mapping;
  final bool actionRunning;
  final VoidCallback onInstruction;
  final VoidCallback onOpenPrintPreview;
  final VoidCallback onOpenOrCreateOrder;
  final VoidCallback onRegisterInvoice;
  final VoidCallback onSendInvoice;

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final isFresh = status.contains('신규') || status.contains('결제완료');
    final isReady = status.contains('출고대기') || status.contains('출고보류');
    final hasInvoice = order.invoiceNo.isNotEmpty || status.contains('운송장출력');
    final canCreateOrder = mapping?.isConfirmed == true;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (isFresh)
          _SmallActionChip(
            label: '출고지시',
            icon: Icons.outbox_outlined,
            disabled: actionRunning,
            onPressed: onInstruction,
          ),
        if (isReady || hasInvoice)
          _SmallActionChip(
            label: '주문서',
            icon: Icons.description_outlined,
            disabled: actionRunning,
            onPressed: onOpenPrintPreview,
          ),
        if (canCreateOrder)
          _SmallActionChip(
            label: '작업등록',
            icon: Icons.handyman_outlined,
            disabled: actionRunning,
            onPressed: onOpenOrCreateOrder,
          ),
        if (isReady || !hasInvoice)
          _SmallActionChip(
            label: '송장번호 입력',
            icon: Icons.edit_note_outlined,
            disabled: actionRunning,
            onPressed: onRegisterInvoice,
          ),
        if (hasInvoice)
          _SmallActionChip(
            label: '송장전송',
            icon: Icons.send_outlined,
            disabled: actionRunning,
            onPressed: onSendInvoice,
          ),
      ],
    );
  }
}

class _SmallActionChip extends StatelessWidget {
  const _SmallActionChip({
    required this.label,
    required this.icon,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      onPressed: disabled ? null : onPressed,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 5),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surface.withValues(alpha: 0.92),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: disabled ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, size: 17, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$carrier ${order.invoiceNo}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox.square(
            dimension: 28,
            child: IconButton.filledTonal(
              tooltip: '운송장 복사',
              onPressed: () => _copyInvoice(context),
              icon: const Icon(Icons.copy_outlined, size: 17),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          SizedBox.square(
            dimension: 28,
            child: IconButton.filled(
              tooltip: '배송조회',
              onPressed: () => _openTracking(context),
              icon: const Icon(Icons.open_in_new, size: 16),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
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

class _InvoiceRegistrationInput {
  const _InvoiceRegistrationInput({
    required this.carrierCode,
    required this.invoiceNo,
  });

  final String carrierCode;
  final String invoiceNo;
}

class _InvoiceRegistrationDialog extends StatefulWidget {
  const _InvoiceRegistrationDialog({required this.order});

  final _PlayAutoOrderPreview order;

  @override
  State<_InvoiceRegistrationDialog> createState() =>
      _InvoiceRegistrationDialogState();
}

class _InvoiceRegistrationDialogState
    extends State<_InvoiceRegistrationDialog> {
  late final TextEditingController _carrierCodeController;
  late final TextEditingController _invoiceNoController;

  @override
  void initState() {
    super.initState();
    _carrierCodeController = TextEditingController(
      text: widget.order.carrierCode,
    );
    _invoiceNoController = TextEditingController(text: widget.order.invoiceNo);
  }

  @override
  void dispose() {
    _carrierCodeController.dispose();
    _invoiceNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('송장번호 입력'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.order.playAutoBundleNo.isEmpty
                  ? widget.order.orderNo
                  : '묶음번호 ${widget.order.playAutoBundleNo}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _carrierCodeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '택배사 코드',
              hintText: '예: CJ대한통운 4, 한진 5',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _invoiceNoController,
            decoration: const InputDecoration(
              labelText: '송장번호',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final carrierCode = _carrierCodeController.text.trim();
            final invoiceNo = _invoiceNoController.text.trim();
            if (carrierCode.isEmpty || invoiceNo.isEmpty) return;
            Navigator.of(context).pop(
              _InvoiceRegistrationInput(
                carrierCode: carrierCode,
                invoiceNo: invoiceNo,
              ),
            );
          },
          child: const Text('등록'),
        ),
      ],
    );
  }
}

class _PlayAutoOrderPrintPreviewScreen extends StatelessWidget {
  const _PlayAutoOrderPrintPreviewScreen({
    required this.order,
    required this.lines,
  });

  final _PlayAutoOrderPreview order;
  final List<_PlayAutoOrderPreview> lines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalQty = lines.fold<int>(0, (sum, line) => sum + line.quantity);
    final totalAmount = lines.fold<int>(0, (sum, line) => sum + line.amount);
    final captureKey = GlobalKey();

    return Scaffold(
      appBar: AppBar(
        title: const Text('주문서'),
        actions: [
          IconButton(
            tooltip: 'PDF 저장/인쇄',
            onPressed: () => _sharePlayAutoOrderPreviewPdf(
              context,
              captureKey: captureKey,
              order: order,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: ColoredBox(
        color: Colors.grey.shade200,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: RepaintBoundary(
              key: captureKey,
              child: _PlayAutoOrderMobilePage(
                order: order,
                lines: lines,
                totalQuantity: totalQty,
                totalAmount: totalAmount,
                backgroundColor: scheme.surface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayAutoOrderMobilePage extends StatelessWidget {
  const _PlayAutoOrderMobilePage({
    required this.order,
    required this.lines,
    required this.totalQuantity,
    required this.totalAmount,
    required this.backgroundColor,
  });

  final _PlayAutoOrderPreview order;
  final List<_PlayAutoOrderPreview> lines;
  final int totalQuantity;
  final int totalAmount;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 390,
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          height: 1.38,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '주문서',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            _orderMobileSection(
              title: '주문 내역',
              children: [
                _orderMobileInfoLine('주문일', order.orderDate),
                _orderMobileInfoLine('구매 쇼핑몰', order.shopName),
                _orderMobileInfoLine('주문번호', order.orderNo),
              ],
            ),
            const SizedBox(height: 14),
            _orderMobileSection(
              title: '배송 정보',
              children: [
                _orderMobileInfoLine('주문자', order.ordererName),
                _orderMobileInfoLine('주문자 전화번호', order.ordererTel),
                _orderMobileInfoLine('주문자 휴대폰번호', order.ordererMobile),
                _orderMobileInfoLine('고객명', order.receiverName),
                _orderMobileInfoLine('고객 전화번호', order.receiverTel),
                _orderMobileInfoLine('고객 휴대폰번호', order.receiverMobile),
                _orderMobileInfoLine('주소', order.address),
                _orderMobileInfoLine(
                  '배송방법',
                  order.shippingMethod.isEmpty ? '선결제' : order.shippingMethod,
                ),
                if (order.shippingMessage.trim().isNotEmpty)
                  _orderMobileInfoLine('배송메시지', order.shippingMessage),
                if (order.otherMessage.trim().isNotEmpty)
                  _orderMobileInfoLine('기타메시지', order.otherMessage),
              ],
            ),
            const SizedBox(height: 18),
            const Text('상품 내역', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (lines.isEmpty) _orderMobileEmptyBox('주문 상품이 없습니다.'),
            for (final line in lines)
              _orderMobileLineCard(
                productName: line.productName,
                optionName: line.optionName,
                quantity: line.quantity,
                unitPrice: line.unitPrice,
                amount: line.amount,
              ),
            const SizedBox(height: 8),
            _orderMobileTotalBox(
              children: [
                _orderMobileTextTotalLine('주문 총 수량', '$totalQuantity개'),
                _orderMobileMoneyTotalLine(
                  '주문 총 금액',
                  totalAmount,
                  bold: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _sharePlayAutoOrderPreviewPdf(
  BuildContext context, {
  required GlobalKey captureKey,
  required _PlayAutoOrderPreview order,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    final pngBytes = await _captureChalstockOrderPng(captureKey);
    final subject = '주문서_${_safePrintFileName(order.orderNo)}';
    final pdfBytes = await _buildChalstockOrderPdf(
      pngBytes: pngBytes,
      subject: subject,
    );
    final tempDir = await getTemporaryDirectory();
    final outFile = File('${tempDir.path}/$subject.pdf');
    await outFile.writeAsBytes(pdfBytes, flush: true);
    await Share.shareXFiles(
      [XFile(outFile.path, mimeType: 'application/pdf', name: '$subject.pdf')],
      subject: subject,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('주문서 PDF 내보내기에 실패했습니다: $e')),
    );
  }
}

class _OrderQuantityBadge extends StatelessWidget {
  const _OrderQuantityBadge({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.36)),
      ),
      child: Text(
        '$quantity개',
        maxLines: 1,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          maxLines: maxLines,
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
    required this.uniq,
    required this.bundleNo,
    required this.status,
    required this.shopName,
    required this.ordererName,
    required this.ordererPhone,
    required this.ordererTel,
    required this.ordererMobile,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverTel,
    required this.receiverMobile,
    required this.customerName,
    required this.address,
    required this.phone,
    required this.productName,
    required this.optionName,
    required this.sku,
    required this.carrierCode,
    required this.carrierName,
    required this.shippingMethod,
    required this.invoiceNo,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.shippingMessage,
    required this.otherMessage,
    required this.orderDate,
    required this.sortDate,
  });

  final String orderNo;
  final String uniq;
  final String bundleNo;
  final String status;
  final String shopName;
  final String ordererName;
  final String ordererPhone;
  final String ordererTel;
  final String ordererMobile;
  final String receiverName;
  final String receiverPhone;
  final String receiverTel;
  final String receiverMobile;
  final String customerName;
  final String address;
  final String phone;
  final String productName;
  final String optionName;
  final String sku;
  final String carrierCode;
  final String carrierName;
  final String shippingMethod;
  final String invoiceNo;
  final int quantity;
  final int unitPrice;
  final int amount;
  final String shippingMessage;
  final String otherMessage;
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
    final unitPrice =
        amount > 0 && quantity > 0 ? (amount / quantity).round() : rawUnitPrice;

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
      fallback: ordererName,
    );
    final ordererMobile = _pickString(json, const [
      'order_htel',
      'order_mobile',
      'order_hp',
      'buyer_mobile',
      'buyer_hp',
      'buyer_htel',
      'from_htel',
    ]);
    final ordererTel = _pickString(json, const [
      'order_tel',
      'buyer_tel',
      'from_tel',
    ]);
    final ordererPhone = _joinUniqueNonEmpty([ordererTel, ordererMobile]);
    final receiverMobile = _pickString(json, const [
      'to_htel',
      'to_mobile',
      'receiver_mobile',
      'receiver_htel',
      'recipient_mobile',
      'recipient_htel',
      'customer_mobile',
      'customer_htel',
    ]);
    final receiverTel = _pickString(json, const [
      'to_tel',
      'receiver_tel',
      'recipient_tel',
      'customer_tel',
    ]);
    final receiverPhone = _joinUniqueNonEmpty([receiverTel, receiverMobile]);
    final zip = _pickString(json, const [
      'to_zipcd',
      'to_zip',
      'zip',
      'zipcode',
      'zip_code',
      'post_code',
      'zonecode',
    ]);
    final address = _formatAddress(
      zip: zip,
      address1: _pickString(json, const [
        'to_addr1',
        'addr1',
        'address1',
        'addr',
        'address',
        'to_addr',
        'receiver_addr',
        'recipient_addr',
        'delivery_addr',
        'ship_addr',
      ]),
      address2: _pickString(json, const [
        'to_addr2',
        'addr2',
        'address2',
        'addr_detail',
        'address_detail',
        'to_addr_detail',
        'receiver_addr_detail',
        'delivery_addr_detail',
        'ship_addr_detail',
      ]),
    );
    final phone = receiverPhone.isNotEmpty ? receiverPhone : ordererPhone;
    final customerName = receiverName.isNotEmpty
        ? receiverName
        : ordererName.isNotEmpty
            ? ordererName
            : '주문자 없음';

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
      uniq: _pickString(json, const [
        'uniq',
        'order_uniq',
      ]),
      bundleNo: _pickString(json, const [
        'bundle_no',
        'pa_bundle_no',
        'package_no',
        'bundle_code',
      ]),
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
      ordererName: ordererName.isNotEmpty ? ordererName : customerName,
      ordererPhone: ordererPhone.isNotEmpty ? ordererPhone : phone,
      ordererTel: ordererTel,
      ordererMobile: ordererMobile,
      receiverName: receiverName.isNotEmpty ? receiverName : customerName,
      receiverPhone: receiverPhone.isNotEmpty ? receiverPhone : phone,
      receiverTel: receiverTel,
      receiverMobile: receiverMobile,
      customerName: customerName,
      address: address,
      phone: phone,
      productName: productName.isEmpty ? '상품명 없음' : productName,
      optionName: optionName,
      sku: _pickString(json, const [
        'sku_cd',
        'c_sale_cd',
        'shop_sale_no',
        'shop_prod_no',
        'opt_custom_cd',
      ]),
      carrierCode: _pickString(json, const [
        'carr_no',
        'carrier_code',
        'delivery_company_code',
        'courier_code',
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
      shippingMethod: _pickString(json, const [
        'ship_method',
        'shipping_method',
        'delivery_method',
        'delivery_type',
        'ship_type',
        'delivery_pay_type',
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
      quantity: quantity,
      unitPrice: unitPrice,
      amount: amount,
      shippingMessage: _pickStringDeep(json, const [
        'delivery_msg',
        'delivery_message',
        'delivery_memo',
        'delivery_request',
        'delivery_request_msg',
        'delivery_request_message',
        'deliv_msg',
        'deliv_memo',
        'ship_msg',
        'ship_message',
        'ship_memo',
        'shipping_message',
        'shipping_memo',
        'shipping_request',
        'shipping_request_msg',
        'shipping_request_message',
        'recv_msg',
        'recv_memo',
        'receiver_msg',
        'receiver_memo',
        'to_msg',
        'to_memo',
        'buyer_msg',
        'buyer_memo',
        'order_msg',
        'order_message',
        'cs_msg',
        'delivery_remark',
        'memo',
        'ord_memo',
        'order_memo',
        'remark',
      ]),
      otherMessage: _pickStringDeep(json, const [
        'etc_msg',
        'etc_message',
        'etc_memo',
        'etc',
        'extra_msg',
        'extra_message',
        'extra_memo',
        'admin_msg',
        'admin_message',
        'admin_memo',
        'manager_msg',
        'manager_message',
        'manager_memo',
        'cs_msg',
        'cs_message',
        'cs_memo',
        'mall_msg',
        'mall_message',
        'mall_memo',
        'seller_msg',
        'seller_message',
        'seller_memo',
        'private_msg',
        'private_message',
        'private_memo',
        'internal_msg',
        'internal_message',
        'internal_memo',
        'work_msg',
        'work_message',
        'work_memo',
        'remark2',
        'memo2',
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

  static String _pickStringDeep(
    Object? node,
    List<String> keys, {
    String fallback = '',
  }) {
    if (node is Map) {
      final map = node.map((key, value) => MapEntry(key.toString(), value));
      for (final key in keys) {
        final value = map[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty && text != 'null') return text;
      }
      for (final value in map.values) {
        final found = _pickStringDeep(value, keys);
        if (found.isNotEmpty) return found;
      }
    }
    if (node is List) {
      for (final value in node) {
        final found = _pickStringDeep(value, keys);
        if (found.isNotEmpty) return found;
      }
    }
    return fallback;
  }

  String get searchText => _normalizeSearchText(
        [
          ordererName,
          ordererTel,
          ordererMobile,
          ordererPhone,
          receiverName,
          receiverTel,
          receiverMobile,
          receiverPhone,
          customerName,
          address,
          phone,
          shopName,
          orderNo,
          productName,
          optionName,
          sku,
          carrierCode,
          carrierName,
          invoiceNo,
          shippingMessage,
          otherMessage,
        ].join(' '),
      );

  String get playAutoBundleNo {
    final candidates = [
      bundleNo,
      uniq,
      if (orderNo != '-') orderNo,
    ];
    for (final value in candidates) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && trimmed != '-') return trimmed;
    }
    return '';
  }

  String get playAutoWorkTargetNo {
    final candidates = [
      bundleNo,
      uniq,
      if (orderNo != '-') orderNo,
    ];
    for (final value in candidates) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && trimmed != '-') return trimmed;
    }
    return '';
  }

  List<String> get playAutoSendInvoiceTargets {
    final seen = <String>{};
    final targets = <String>[];
    for (final value in [
      bundleNo,
      uniq,
      if (orderNo != '-') orderNo,
    ]) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == '-' || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      targets.add(trimmed);
    }
    return targets;
  }

  static String _joinNonEmpty(List<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
  }

  static String _joinUniqueNonEmpty(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      result.add(trimmed);
    }
    return result.join(' ');
  }

  static String _formatAddress({
    required String zip,
    required String address1,
    required String address2,
  }) {
    final parts = [
      if (zip.trim().isNotEmpty) '(${zip.trim()})',
      address1,
      address2,
    ];
    return _joinNonEmpty(parts);
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
    this.noticeOverride,
  });

  final List<_PlayAutoOrderPreview> orders;
  final int? statusCode;
  final String body;
  final bool fromCache;
  final DateTime? fetchedAt;
  final String? noticeOverride;

  String get notice {
    if (noticeOverride != null) return noticeOverride!;
    final time = fetchedAt == null ? '' : ' · ${formatNoticeTime(fetchedAt!)}';
    return fromCache ? '캐시 사용$time' : 'PlayAuto API 호출$time';
  }

  static String formatNoticeTime(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}

class _PlayAutoCollectionRunResult {
  const _PlayAutoCollectionRunResult({
    required this.statusCode,
    required this.body,
  });

  final int? statusCode;
  final String body;
}

class _PlayAutoWorkRegistrationResult {
  const _PlayAutoWorkRegistrationResult({
    required this.response,
    required this.workNos,
  });

  final _PlayAutoResponse response;
  final List<String> workNos;
}

class _PlayAutoQuoteOrderAddLog {
  const _PlayAutoQuoteOrderAddLog({
    required this.sentAt,
    required this.quoteId,
    required this.title,
    required this.statusCode,
    required this.success,
    required this.message,
  });

  final DateTime sentAt;
  final String quoteId;
  final String title;
  final int? statusCode;
  final bool success;
  final String message;

  factory _PlayAutoQuoteOrderAddLog.fromJson(Map<String, Object?> json) {
    return _PlayAutoQuoteOrderAddLog(
      sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      quoteId: json['quote_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '플토 주문',
      statusCode: json['status_code'] is int
          ? json['status_code'] as int
          : int.tryParse(json['status_code']?.toString() ?? ''),
      success: json['success'] == true || json['success']?.toString() == 'true',
      message: json['message']?.toString() ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'sent_at': sentAt.toIso8601String(),
      'quote_id': quoteId,
      'title': title,
      'status_code': statusCode,
      'success': success,
      'message': message,
    };
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
