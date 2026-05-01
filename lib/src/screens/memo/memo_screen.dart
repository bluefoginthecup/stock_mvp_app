import 'dart:async';
import 'package:flutter/material.dart';
import '../../repos/modules/memo_repo.dart';

class MemoScreen extends StatefulWidget {
  const MemoScreen({super.key});

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  final _controller = TextEditingController();
  final _repo = MemoRepo();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    // 🔥 추가 (붙여넣기 대응)
    _controller.addListener(() {
      _onChanged(_controller.text);
    });
  }

  Future<void> _load() async {
    final text = await _repo.load();
    _controller.text = text;
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _repo.save(text);
    });
  }


  @override
  void dispose() {
    _debounce?.cancel();

    // 🔥 마지막 저장
    _repo.save(_controller.text);

    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메모')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            hintText: '자유롭게 메모하세요...',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
    );
  }
}