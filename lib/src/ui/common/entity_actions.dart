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
    builder: (sheetContext) => SafeArea(
      child: Wrap(children: [
        if (enableRename)
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: Text(renameLabel ?? '이름 변경'),
            onTap: () {
              final nav = Navigator.maybeOf(sheetContext)
                  ?? Navigator.of(context, rootNavigator: true);
              nav.pop(EntityAction.rename);
            },
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
  onTap: () {
  final nav = Navigator.maybeOf(sheetContext)
  ?? Navigator.of(context, rootNavigator: true);
  nav.pop(EntityAction.delete);
  },
          )

  ]),
    ),
  );
}


Future<bool?> showDeleteConfirm(
    BuildContext rootContext, {
      String title = '삭제하시겠어요?',
      String message = '이 작업은 되돌릴 수 없습니다.',
      String cancelText = '취소',
      String okText = '삭제',
    }) {
  return showDialog<bool>(
    context: rootContext, // ✅ 반드시 화면(페이지)의 context 사용
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              final nav = Navigator.maybeOf(dialogContext)
                  ?? Navigator.of(rootContext, rootNavigator: true);
              nav.pop(false);
            },
            child: Text(cancelText),
          ),
          FilledButton.tonal(
            onPressed: () {
              final nav = Navigator.maybeOf(dialogContext)
                  ?? Navigator.of(rootContext, rootNavigator: true);
              nav.pop(true);
            },
            child: Text(okText),
          ),
        ],
      );
    },
  );
}
