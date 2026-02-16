const _chosung = [
  'ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ','ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'
];

bool _isHangulSyllable(int code) => code >= 0xAC00 && code <= 0xD7A3;
bool _isChosungJamo(int code) => code >= 0x3131 && code <= 0x314E;

/// 공백/특수문자 제거 + 소문자(영문)
String normalizeForSearch(String s) {
  final lower = s.toLowerCase();
  final reg = RegExp(r'[^0-9a-z가-힣]+');
  return lower.replaceAll(reg, '');
}

/// "자수물 루앙..." -> "ㅈㅅㅁㄹㅇㄱㄹㅇㅇㄱㅎㄷㄱㅇ"
String toChosungString(String s) {
  final buf = StringBuffer();
  for (final rune in s.runes) {
    final code = rune;
    if (_isHangulSyllable(code)) {
      final idx = ((code - 0xAC00) ~/ 588);
      buf.write(_chosung[idx]);
    } else if (_isChosungJamo(code)) {
      buf.write(String.fromCharCode(code));
    }
  }
  return buf.toString();
}

/// 쿼리가 초성검색 의도인지 (공백 허용)
/// - 공백/구두점은 판정에서 제외
/// - 초성 자모 비율이 일정 이상이면 true
bool looksLikeChosungQuery(String q) {
  final t = q.trim();
  if (t.isEmpty) return false;

  int jamo = 0;
  int considered = 0;

  for (final r in t.runes) {
    // 공백은 완전히 무시
    if (r == 0x20 || r == 0x09 || r == 0x0A || r == 0x0D) continue;

    // 초성 자모는 카운트
    if (_isChosungJamo(r)) {
      jamo++;
      considered++;
      continue;
    }

    // 한글 음절(가-힣)은 "검색 의도 판단"에 포함 (선택)
    if (_isHangulSyllable(r)) {
      considered++;
      continue;
    }

    // 영숫자는 포함(혼합 입력 방지용)
    if ((r >= 0x30 && r <= 0x39) || (r >= 0x61 && r <= 0x7A)) {
      considered++;
      continue;
    }

    // 기타 특수문자/기호는 제외
  }

  if (considered == 0) return false;
  return jamo > 0 && (jamo / considered) >= 0.6;
}
