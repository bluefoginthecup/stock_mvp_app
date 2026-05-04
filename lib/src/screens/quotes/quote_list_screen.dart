import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../models/quote.dart';
import '../../models/quote_line.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/buyer_profile_service.dart';
import 'quote_detail_screen.dart';

class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key});

  @override
  State<QuoteListScreen> createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends State<QuoteListScreen> {
  final _searchC = TextEditingController();
  String _query = '';
  Timer? _debounce;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() => _query = _searchC.text.trim().toLowerCase());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _createQuote() async {
    if (_creating) return;
    setState(() => _creating = true);
    final repo = context.read<QuoteRepo>();
    final profileService = BuyerProfileService(context.read<AppDatabase>());
    final id = const Uuid().v4();
    final now = DateTime.now();
    final supplierProfile = await profileService.defaultProfile();
    final quote = Quote(
      id: id,
      customerName: '',
      quoteDate: now,
      validUntil: now.add(const Duration(days: 14)),
      createdAt: now,
      updatedAt: now,
    ).copyWithSupplierProfile(supplierProfile);

    try {
      await repo.createQuote(quote);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuoteDetailScreen(quoteId: id)),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _deleteQuote(Quote quote) async {
    await context.read<QuoteRepo>().softDeleteQuote(quote.id);
  }

  String _statusText(QuoteStatus status) {
    switch (status) {
      case QuoteStatus.draft:
        return '임시저장';
      case QuoteStatus.sent:
        return '발송';
      case QuoteStatus.accepted:
        return '승인';
      case QuoteStatus.canceled:
        return '취소';
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<QuoteRepo>();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchC,
          decoration: InputDecoration(
            hintText: '거래처 / 품목 검색',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _searchC.clear,
                  ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: _creating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('견적'),
        onPressed: _creating ? null : _createQuote,
      ),
      body: FutureBuilder<Map<String, List<QuoteLine>>>(
        future: repo.getQuoteLinesMap(),
        builder: (context, linesSnap) {
          final linesMap = linesSnap.data ?? const <String, List<QuoteLine>>{};
          return StreamBuilder<List<Quote>>(
            stream: repo.watchAllQuotes(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final quotes = snap.data!.where((quote) {
                if (_query.isEmpty) return true;
                final lines = linesMap[quote.id] ?? const <QuoteLine>[];
                final itemText = lines.map((line) => line.name).join(' ');
                return '${quote.customerName} $itemText'
                    .toLowerCase()
                    .contains(_query);
              }).toList();

              if (quotes.isEmpty) {
                return const Center(child: Text('견적서가 없습니다.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                itemCount: quotes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final quote = quotes[index];
                  final lines = linesMap[quote.id] ?? const <QuoteLine>[];
                  final subtotal =
                      lines.fold<double>(0, (sum, line) => sum + line.amount);
                  final totals = QuoteTotals.from(
                    quote: quote,
                    linesSubtotal: subtotal,
                  );
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.request_quote_outlined),
                      title: Text(
                        quote.customerName.trim().isEmpty
                            ? '거래처 미지정'
                            : quote.customerName,
                      ),
                      subtitle: Text(
                        '${DateFormat('yyyy.MM.dd').format(quote.quoteDate)} · '
                        '${_statusText(quote.status)} · ${lines.length}개 품목',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(NumberFormat('#,##0').format(totals.total)),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') _deleteQuote(quote);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('삭제'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuoteDetailScreen(quoteId: quote.id),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
