import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'daily_gift_dialog.dart';
import 'daily_gift_service.dart';

class DailyGiftBoxScreen extends StatefulWidget {
  const DailyGiftBoxScreen({super.key});

  @override
  State<DailyGiftBoxScreen> createState() => _DailyGiftBoxScreenState();
}

class _DailyGiftBoxScreenState extends State<DailyGiftBoxScreen> {
  final _service = DailyGiftService();
  late Future<List<DailyGift>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DailyGift>> _load() async {
    final gift = await _service.grantTodayIfDue();
    if (gift != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showDailyGiftDialog(context, gift, allowOpenBox: false);
      });
    }
    return _service.loadGifts(grantIfDue: false);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('찰떡이의 일기장')),
      body: FutureBuilder<List<DailyGift>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final gifts = snapshot.data ?? const [];
          if (gifts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.menu_book_outlined, size: 56),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      '아직 도착한 일기가 없어요.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text('일기 시간을 켜두면 하루에 한 번 카드가 쌓입니다.'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: gifts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _GiftCard(
                  gift: gifts[index],
                  onCommentSaved: _refresh,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  final DailyGift gift;
  final Future<void> Function() onCommentSaved;

  const _GiftCard({
    required this.gift,
    required this.onCommentSaved,
  });

  Future<void> _editComment(BuildContext context) async {
    final controller = TextEditingController(text: gift.userComment);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('나의 한마디'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '오늘 이 일기에 남기고 싶은 말을 적어보세요.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('비우기'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) return;

    await DailyGiftService().saveUserComment(gift.id, result);
    await onCommentSaved();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('나의 한마디를 저장했어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy.MM.dd HH:mm').format(gift.unlockedAt);
    final sourceDate = DateFormat('yyyy.MM.dd').format(gift.sourceDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  gift.hasGift
                      ? Icons.card_giftcard_rounded
                      : Icons.menu_book_rounded,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    gift.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(gift.description),
            const SizedBox(height: 12),
            _UserCommentBox(
              comment: gift.userComment,
              onTap: () => _editComment(context),
            ),
            const SizedBox(height: 12),
            Text(
              gift.hasGift
                  ? '$sourceDate의 배달 · $date 받음'
                  : '$sourceDate의 일기 · $date 도착',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.62),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCommentBox extends StatelessWidget {
  final String comment;
  final VoidCallback onTap;

  const _UserCommentBox({
    required this.comment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasComment = comment.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasComment
                    ? Icons.mode_comment_rounded
                    : Icons.add_comment_outlined,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '나의 한마디',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasComment ? comment.trim() : '이 일기에 한마디 남기기',
                      style: TextStyle(
                        color: hasComment
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_rounded, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
