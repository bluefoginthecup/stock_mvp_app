import 'package:flutter/material.dart';

/// 엔터티 공통 액션
enum EntityAction { rename, move, delete }

/// 하단 액션 시트: 필요한 버튼만 보여주기
Future<EntityAction?> showEntityActionsSheet(
    BuildContext context, {
      bool enableRename = true,
      bool enableMove = true,
      bool enableDelete = true,
      String? renameLabel,
      String? moveLabel,
      String? deleteLabel,
    }) {
  return showModalBottomSheet<EntityAction>(
    context: context,
    builder: (_) => SafeArea(
      child: Wrap(children: [
        if (enableRename)
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: Text(renameLabel ?? '이름 변경'),
            onTap: () => Navigator.pop(context, EntityAction.rename),
          ),
        if (enableMove)
          ListTile(
            leading: const Icon(Icons.drive_file_move),
            title: Text(moveLabel ?? '이동'),
            onTap: () => Navigator.pop(context, EntityAction.move),
          ),
        if (enableDelete)
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(deleteLabel ?? '삭제'),
            onTap: () => Navigator.pop(context, EntityAction.delete),
          ),
      ]),
    ),
  );
}

/// 공통: 이름 입력 다이얼로그 (rename)
Future<String?> showRenameDialog(
    BuildContext context, {
      String title = '이름 변경',
      String? initial,
      String hint = '새 이름 입력',
    }) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(context, c.text.trim()),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

/// 공통: 삭제 확인
Future<bool> showDeleteConfirm(
    BuildContext context, {
      String title = '삭제',
      required String message,
    }) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('삭제', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}
