import 'package:flutter/material.dart';
// 경로는 프로젝트 구조에 맞춰 수정: ui/common → utils 로 올라가야 함
import '../../utils/debounce.dart';

class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const AppSearchField({
    super.key,
    required this.controller,
    this.hint = '검색',
    this.onChanged,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final Debouncer _deb = Debouncer(ms: 250);

  @override
  void dispose() {
    _deb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: (v) => _deb.run(() => widget.onChanged?.call(v)),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
