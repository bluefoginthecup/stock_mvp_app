import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class WindowsGoogleOAuthResult {
  const WindowsGoogleOAuthResult({
    required this.idToken,
    this.accessToken,
  });

  final String idToken;
  final String? accessToken;
}

class WindowsGoogleOAuth {
  static const _clientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue:
        '101861330698-s5r9c8rlm4jf99thqb0cth6co3v7854a.apps.googleusercontent.com',
  );
  static const _tokenExchangeEndpoint = String.fromEnvironment(
    'GOOGLE_OAUTH_TOKEN_EXCHANGE_URL',
    defaultValue:
        'https://asia-northeast3-chalstock.cloudfunctions.net/exchangeGoogleOAuthCode',
  );

  Future<WindowsGoogleOAuthResult> signIn() async {
    if (_clientId.isEmpty || _tokenExchangeEndpoint.isEmpty) {
      throw const WindowsGoogleOAuthConfigurationException();
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}';
    final state = _randomUrlSafeString(32);
    final verifier = _randomUrlSafeString(64);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');

    final authorizationUri = Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'prompt': 'select_account',
      },
    );

    try {
      final opened = await launchUrl(
        authorizationUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw StateError('Google 로그인 페이지를 열지 못했습니다.');
      }

      final request = await server.first.timeout(const Duration(minutes: 5));
      final params = request.uri.queryParameters;
      await _sendBrowserResponse(request.response, params['error'] == null);

      if (params['state'] != state) {
        throw StateError('Google 로그인 응답의 보안 검증에 실패했습니다.');
      }
      if (params['error'] != null) {
        throw StateError(
          params['error'] == 'access_denied'
              ? 'Google 로그인이 취소되었습니다.'
              : 'Google 로그인 실패: ${params['error']}',
        );
      }

      final code = params['code'];
      if (code == null || code.isEmpty) {
        throw StateError('Google에서 인증 코드를 받지 못했습니다.');
      }

      final tokenResponse = await http.post(
        Uri.parse(_tokenExchangeEndpoint),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'codeVerifier': verifier,
          'redirectUri': redirectUri,
        }),
      );
      final payload = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      if (tokenResponse.statusCode != 200) {
        throw StateError(
          'Google 토큰 교환 실패: ${payload['error_description'] ?? payload['error']}',
        );
      }

      final idToken = payload['id_token'] as String?;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google ID 토큰을 받지 못했습니다.');
      }
      return WindowsGoogleOAuthResult(
        idToken: idToken,
        accessToken: payload['access_token'] as String?,
      );
    } finally {
      await server.close(force: true);
    }
  }

  static String _randomUrlSafeString(int byteCount) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Future<void> _sendBrowserResponse(
    HttpResponse response,
    bool success,
  ) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.html;
    response.write('''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><title>찰스톡 로그인</title></head>
<body style="font-family:sans-serif;text-align:center;padding:48px">
<h2>${success ? '로그인이 완료되었습니다' : '로그인을 완료하지 못했습니다'}</h2>
<p>${success ? '이 창을 닫고 찰스톡 앱으로 돌아가세요.' : '이 창을 닫고 앱에서 다시 시도하세요.'}</p>
</body></html>''');
    await response.close();
  }
}

class WindowsGoogleOAuthConfigurationException implements Exception {
  const WindowsGoogleOAuthConfigurationException();

  @override
  String toString() => 'Windows Google OAuth 클라이언트 ID가 없습니다. '
      'GOOGLE_OAUTH_CLIENT_ID를 설정해 다시 실행해 주세요.';
}
