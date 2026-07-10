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

  Future<void> _runRequest(
    Future<_PlayAutoResponse> Function() request,
  ) async {
    setState(() {
      _loading = true;
      _statusCode = null;
      _result = null;
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

class _PlayAutoResponse {
  const _PlayAutoResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}
