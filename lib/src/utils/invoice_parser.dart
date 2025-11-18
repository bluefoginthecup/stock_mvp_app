class ParsedInvoiceLine {
  final String nameRaw;     // 품명(규격 제외 설명)
  final String? spec;       // 규격(40×120 등)
  final String? color;      // 색상
  final double? qty;        // 수량
  final int? unitPrice;     // 단가
  ParsedInvoiceLine({required this.nameRaw, this.spec, this.color, this.qty, this.unitPrice});

  @override
  String toString() =>
      'ParsedInvoiceLine(nameRaw="$nameRaw", spec=$spec, color=$color, qty=$qty, unitPrice=$unitPrice)';
}

final _reNumber = RegExp(r'(?:(?:\d{1,3}(?:,\d{3})+)|\d+)(?:\.\d+)?');
final _reSize = RegExp(
  r'(\d+)\s*[x×*]\s*(\d+)|(\d+)\s*~\s*(\d+)|(\d+)\s*[×x*]\s*(\d+)',
  caseSensitive: false,
);
final _reDash = RegExp(r'\s*[-–—]\s*');
final _colorLex = [
  '그레이','베이지','핑크','네이비','화이트','블루','옐로우','브라운','그린','블랙','아이보리','코코아','커피',
  'gray','grey','beige','pink','navy','white','blue','yellow','brown','green','black','ivory','coffee',
];

ParsedInvoiceLine? parseInvoiceTextLine(String rawLine) {
  final l = rawLine.trim();
  if (l.isEmpty) return null;
  if (RegExp(r'^(=|-|─|―|＿|_{3,}).*$').hasMatch(l)) return null;
  if (RegExp(r'(합계|소계|VAT|총계)').hasMatch(l)) return null;

  // 오른쪽 두 숫자: [수량][단가] (대부분의 명세서 규칙)
  final nums = _reNumber.allMatches(l).map((m) => m.group(0)!).toList();

  int? price; double? qty;
  if (nums.isNotEmpty) {
    price = int.tryParse(nums.last.replaceAll(',', ''));
  }
  if (nums.length >= 2) {
    qty = double.tryParse(nums[nums.length - 2].replaceAll(',', ''));
  }

  String leftText = l;
  leftText = _removeLastNumberToken(leftText);           // 단가 제거
  if (nums.length >= 2) leftText = _removeLastNumberToken(leftText); // 수량 제거
  leftText = leftText.trim();

  String nameRaw = leftText; String? spec;
  if (_reDash.hasMatch(leftText)) {
    final parts = leftText.split(_reDash);
    if (parts.length >= 2) {
      nameRaw = parts.first.trim();
      spec = parts.sublist(1).join(' - ').trim();
    }
  }
  spec ??= _reSize.firstMatch(leftText)?.group(0);

  String? color; int bestIdx = -1;
  for (final c in _colorLex) {
    final i = leftText.toLowerCase().lastIndexOf(c.toLowerCase());
    if (i > bestIdx) { bestIdx = i; if (i >= 0) color = c; }
  }
  return ParsedInvoiceLine(nameRaw: nameRaw.isEmpty ? leftText : nameRaw, spec: spec, color: color, qty: qty, unitPrice: price);
}

String _removeLastNumberToken(String s) {
  final matches = _reNumber.allMatches(s).toList();
  if (matches.isEmpty) return s;
  final m = matches.last;
  return (s.substring(0, m.start) + s.substring(m.end)).trim();
}
