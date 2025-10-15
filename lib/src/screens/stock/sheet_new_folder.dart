// lib/src/screens/stock/sheet_new_folder.dart
import 'package:flutter/material.dart';

enum FolderMenu { rename, delete }

Future<String?> showNewFolderSheet(BuildContext context, {String? initial}) async {
  final c = TextEditingController(text: initial ?? '');
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(initial == null ? '새 폴더' : '폴더 이름 변경', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: '폴더 이름', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('확인')),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<FolderMenu?> showFolderContextMenu(BuildContext context, Object node) async {
  return showModalBottomSheet<FolderMenu>(
    context: context,
    builder: (_) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.drive_file_rename_outline),
          title: const Text('이름 변경'),
          onTap: () => Navigator.pop(context, FolderMenu.rename),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('삭제'),
          onTap: () => Navigator.pop(context, FolderMenu.delete),
        ),
      ]),
    ),
  );
}
