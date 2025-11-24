import 'package:flutter/material.dart';

typedef GoPageFn = void Function(BuildContext context);

/// 공통 스낵바: message + actionText + action → 페이지 이동
void showGoSnack(
    BuildContext context, {
      required String message,
      required String actionText,
      required GoPageFn onAction,
      Duration duration = const Duration(seconds: 4),
    }) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      action: SnackBarAction(
        label: actionText,
        onPressed: () => onAction(context),
      ),
    ),
  );
}
