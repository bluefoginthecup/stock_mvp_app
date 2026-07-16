import 'package:flutter/material.dart';

import 'daily_gift_box_screen.dart';
import 'daily_gift_service.dart';

Future<void> showDailyGiftDialog(
  BuildContext context,
  DailyGift gift, {
  bool allowOpenBox = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;

      return AlertDialog(
        icon: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: const Icon(Icons.card_giftcard_rounded),
        ),
        title: Text(gift.hasGift ? '찰떡이의 오늘 배달' : '찰떡이의 일기'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gift.title,
                style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              Text(gift.description),
            ],
          ),
        ),
        actions: [
          if (allowOpenBox)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DailyGiftBoxScreen(),
                  ),
                );
              },
              child: const Text('보관함 보기'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(gift.hasGift ? '보관함에 넣기' : '일기장에 넣기'),
          ),
        ],
      );
    },
  );
}
