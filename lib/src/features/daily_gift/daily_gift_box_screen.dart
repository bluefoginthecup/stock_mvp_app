import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    await _service.grantTodayIfDue();
    return _service.loadGifts(grantIfDue: false);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('선물 보관함')),
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
                  Icon(Icons.inventory_2_outlined, size: 56),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      '아직 받은 선물이 없어요.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text('선물 시간을 켜두면 하루에 한 번 카드가 쌓입니다.'),
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
                return _GiftCard(gift: gifts[index]);
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

  const _GiftCard({required this.gift});

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
                const Icon(Icons.card_giftcard_rounded),
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
            Text(
              '$sourceDate의 선물 · $date 받음',
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
