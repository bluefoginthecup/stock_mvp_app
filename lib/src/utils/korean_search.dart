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

/// 쿼리가 초성검색 의도인지
bool looksLikeChosungQuery(String q) {
  final t = q.trim();
  if (t.isEmpty) return false;
  int jamo = 0;
  int total = 0;
  for (final r in t.runes) {
    total++;
    if (_isChosungJamo(r)) jamo++;
  }
  return jamo > 0 && (jamo / total) >= 0.6;
}
