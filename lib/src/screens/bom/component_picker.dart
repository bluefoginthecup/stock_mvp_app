
// lib/src/screens/bom/component_picker.dart
import 'package:flutter/material.dart';

class ComponentPicker extends StatefulWidget {
  const ComponentPicker({super.key});

  @override
  State<ComponentPicker> createState() => _ComponentPickerState();
}

class _ComponentPickerState extends State<ComponentPicker> {
  final _items = <String>['it-001', 'it-002', 'it-003']; // TODO: 실제 검색 데이터로 교체
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final shown = _items.where((e) => e.contains(_q)).toList();

    return AlertDialog(
      title: const Text('구성품 선택'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '검색'),
            onChanged: (v) => setState(() => _q = v.trim()),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 360,
            height: 320,
            child: ListView.separated(
              itemCount: shown.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final id = shown[i];
                return ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(id),
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }
}
