import '../models/app_schedule.dart';
import 'korean_search.dart';

class ActiveHashTagFragment {
  final int start;
  final int end;
  final String query;

  const ActiveHashTagFragment({
    required this.start,
    required this.end,
    required this.query,
  });
}

String normalizeTag(String tag) {
  final value = tag.trim();
  if (value.startsWith('#')) {
    return value.substring(1).trim();
  }
  return value;
}

List<String> extractHashTags(String text) {
  final tags = <String>[];
  final seen = <String>{};
  final buffer = StringBuffer();

  var readingTag = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    final previous = i == 0 ? null : text[i - 1];

    if (!readingTag) {
      if (char == '#' && (previous == null || _isWhitespace(previous))) {
        readingTag = true;
        buffer.clear();
      }
      continue;
    }

    if (_isTagChar(char)) {
      buffer.write(char);
      continue;
    }

    _addBufferedTag(buffer, tags, seen);
    readingTag = false;
  }

  if (readingTag) {
    _addBufferedTag(buffer, tags, seen);
  }

  return tags;
}

List<String> extractHashTagsFromSchedule({
  String? title,
  String? body,
}) {
  final tags = <String>[];
  final seen = <String>{};

  for (final tag in [
    ...extractHashTags(title ?? ''),
    ...extractHashTags(body ?? ''),
  ]) {
    if (seen.add(tag)) tags.add(tag);
  }

  return tags;
}

List<String> collectTagsFromSchedules(Iterable<AppSchedule> schedules) {
  final tags = <String>[];
  final seen = <String>{};

  for (final schedule in schedules) {
    for (final tag in schedule.tags) {
      final normalized = normalizeTag(tag);
      if (normalized.isEmpty) continue;
      if (seen.add(normalized)) tags.add(normalized);
    }
  }

  tags.sort((a, b) => a.compareTo(b));
  return tags;
}

ActiveHashTagFragment? findActiveHashTagFragment({
  required String text,
  required int cursorOffset,
}) {
  if (cursorOffset < 0 || cursorOffset > text.length) return null;
  final beforeCursor = text.substring(0, cursorOffset);
  final hashIndex = beforeCursor.lastIndexOf('#');
  if (hashIndex < 0) return null;
  if (hashIndex > 0 && !_isWhitespace(text[hashIndex - 1])) return null;

  final query = beforeCursor.substring(hashIndex + 1);
  if (query.contains(RegExp(r'\s'))) return null;
  if (query.isEmpty) {
    return ActiveHashTagFragment(
        start: hashIndex, end: cursorOffset, query: '');
  }
  if (query.runes.any((rune) => !_isTagRune(rune))) return null;

  return ActiveHashTagFragment(
    start: hashIndex,
    end: cursorOffset,
    query: query,
  );
}

List<String> suggestHashTags({
  required String query,
  required Iterable<String> candidates,
  int limit = 6,
}) {
  final normalizedQuery = normalizeTag(query).toLowerCase();
  final queryInitials = toChosungString(normalizedQuery);
  if (normalizedQuery.isEmpty) {
    return _uniqueSortedTags(candidates).take(limit).toList(growable: false);
  }

  final direct = <String>[];
  final initial = <String>[];
  final seen = <String>{};

  for (final candidate in _uniqueSortedTags(candidates)) {
    final normalized = normalizeTag(candidate);
    if (normalized.isEmpty || !seen.add(normalized)) continue;

    final lower = normalized.toLowerCase();
    if (lower.startsWith(normalizedQuery)) {
      direct.add(normalized);
      continue;
    }

    if (queryInitials.isNotEmpty &&
        toChosungString(normalized).startsWith(queryInitials)) {
      initial.add(normalized);
    }
  }

  return [...direct, ...initial].take(limit).toList(growable: false);
}

String replaceHashTagFragment({
  required String text,
  required ActiveHashTagFragment fragment,
  required String tag,
}) {
  final normalized = normalizeTag(tag);
  return text.replaceRange(fragment.start, fragment.end, '#$normalized');
}

void _addBufferedTag(
  StringBuffer buffer,
  List<String> tags,
  Set<String> seen,
) {
  final tag = normalizeTag(buffer.toString());
  if (tag.isEmpty) return;
  if (tag.runes.any(_isChosungJamoRune)) return;
  if (seen.add(tag)) tags.add(tag);
}

bool _isWhitespace(String char) => char.trim().isEmpty;

bool _isTagChar(String char) {
  return _isTagRune(char.codeUnitAt(0));
}

bool _isTagRune(int code) {
  final isNumber = code >= 0x30 && code <= 0x39;
  final isUpper = code >= 0x41 && code <= 0x5A;
  final isLower = code >= 0x61 && code <= 0x7A;
  final isHangul = code >= 0xAC00 && code <= 0xD7A3;
  final isChosung = _isChosungJamoRune(code);
  return isNumber ||
      isUpper ||
      isLower ||
      isHangul ||
      isChosung ||
      code == 0x5F;
}

bool _isChosungJamoRune(int code) => code >= 0x3131 && code <= 0x314E;

List<String> _uniqueSortedTags(Iterable<String> tags) {
  final seen = <String>{};
  final result = <String>[];
  for (final tag in tags) {
    final normalized = normalizeTag(tag);
    if (normalized.isEmpty) continue;
    if (seen.add(normalized)) result.add(normalized);
  }
  result.sort((a, b) => a.compareTo(b));
  return result;
}
