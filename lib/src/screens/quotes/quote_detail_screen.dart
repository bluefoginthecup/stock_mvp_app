import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../db/app_database.dart';
import '../../models/buyer_profile.dart';
import '../../models/purchase_order.dart';
import '../../models/quote.dart';
import '../../models/quote_line.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/buyer_profile_service.dart';
import '../../ui/common/supplier_picker_sheet.dart';
import '../integrations/playauto_order_import_screen.dart';
import '../stock/stock_item_detail_screen.dart';
import 'quote_line_edit_screen.dart';
import 'quote_print_view.dart';

class QuoteDetailScreen extends StatefulWidget {
  final String quoteId;

  const QuoteDetailScreen({super.key, required this.quoteId});

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  Quote? _quote;
  List<QuoteLine> _lines = const [];
  bool _loading = true;
  late final TextEditingController _customerC;
  late final TextEditingController _memoC;
  late final TextEditingController _discountC;
  late final TextEditingController _shippingC;

  @override
  void initState() {
    super.initState();
    _customerC = TextEditingController();
    _memoC = TextEditingController();
    _discountC = TextEditingController();
    _shippingC = TextEditingController();
    _reload();
  }

  @override
  void dispose() {
    _customerC.dispose();
    _memoC.dispose();
    _discountC.dispose();
    _shippingC.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final repo = context.read<QuoteRepo>();
    final quote = await repo.getQuoteById(widget.quoteId);
    final lines = await repo.getQuoteLines(widget.quoteId);
    if (!mounted) return;
    setState(() {
      _quote = quote;
      _lines = lines;
      _loading = false;
      _customerC.text = quote?.customerName ?? '';
      _memoC.text = quote?.memo ?? '';
      _discountC.text = (quote?.discountAmount ?? 0).toStringAsFixed(0);
      _shippingC.text = (quote?.shippingCost ?? 0).toStringAsFixed(0);
    });
  }

  Future<void> _saveHeader() async {
    final quote = _quote;
    if (quote == null) return;
    final updated = quote.copyWith(
      customerName: _customerC.text.trim(),
      memo: _memoC.text.trim().isEmpty ? null : _memoC.text.trim(),
      discountAmount: double.tryParse(_discountC.text.trim()) ?? 0,
      shippingCost: double.tryParse(_shippingC.text.trim()) ?? 0,
    );
    await context.read<QuoteRepo>().updateQuote(updated);
    if (!mounted) return;
    setState(() => _quote = updated);
  }

  Future<void> _pickCustomer() async {
    final supplier = await showSupplierPickerSheet(
      context,
      initialQuery: _customerC.text.trim(),
      title: '견적 거래처 선택',
    );
    if (supplier == null) return;
    setState(() {
      _customerC.text = supplier.name;
      _quote = _quote?.copyWith(
        customerName: supplier.name,
        customerId: supplier.id,
      );
    });
    await _saveHeader();
  }

  Future<void> _pickDate({required bool validUntil}) async {
    final quote = _quote;
    if (quote == null) return;
    final repo = context.read<QuoteRepo>();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: validUntil
          ? (quote.validUntil ?? quote.quoteDate.add(const Duration(days: 14)))
          : quote.quoteDate,
    );
    if (picked == null) return;
    final updated = validUntil
        ? quote.copyWith(validUntil: picked)
        : quote.copyWith(quoteDate: picked);
    await repo.updateQuote(updated);
    if (!mounted) return;
    setState(() => _quote = updated);
  }

  Future<void> _changeStatus(QuoteStatus status) async {
    final quote = _quote;
    if (quote == null) return;
    final updated = quote.copyWith(status: status);
    await context.read<QuoteRepo>().updateQuote(updated);
    if (!mounted) return;
    setState(() => _quote = updated);
  }

  Future<void> _changeVatType(QuoteVatType vatType) async {
    final quote = _quote;
    if (quote == null) return;
    final updated = quote.copyWith(vatType: vatType);
    await context.read<QuoteRepo>().updateQuote(updated);
    if (!mounted) return;
    setState(() => _quote = updated);
  }

  String _supplierSummary(Quote quote) {
    final supplier = quote.supplierSnapshotProfile;
    final parts = [
      supplier.companyName.trim(),
      supplier.businessNumber.trim(),
      supplier.representative.trim(),
    ].where((value) => value.isNotEmpty);
    return parts.isEmpty ? '공급자 정보 미설정' : parts.join(' / ');
  }

  Future<void> _changeSupplierProfile(Quote quote) async {
    final repo = context.read<QuoteRepo>();
    final service = BuyerProfileService(context.read<AppDatabase>());
    final profiles = await service.listProfiles();
    final configured =
        profiles.where((profile) => profile.isConfigured).toList();
    final options = [
      ...configured,
      if (configured.isEmpty) BuyerProfile.fallback(),
    ];

    if (!mounted) return;
    final selected = await showModalBottomSheet<BuyerProfile>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('공급자 선택'),
                subtitle: Text('계정 프로필 정보가 이 견적서에 스냅샷으로 저장됩니다.'),
              ),
              for (final profile in options)
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(profile.displayName),
                  subtitle: Text([
                    if (profile.companyName.trim().isNotEmpty)
                      profile.companyName.trim(),
                    if (profile.businessNumber.trim().isNotEmpty)
                      profile.businessNumber.trim(),
                    if (profile.representative.trim().isNotEmpty)
                      profile.representative.trim(),
                  ].join(' / ')),
                  trailing: profile.id == quote.supplierProfileId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(profile),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;

    final updated = quote.copyWithSupplierProfile(selected);
    await repo.updateQuote(updated);
    if (!mounted) return;
    setState(() => _quote = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selected.displayName} 정보가 견적서에 저장되었습니다')),
    );
  }

  Future<void> _editLine([QuoteLine? line]) async {
    final repo = context.read<QuoteRepo>();
    final saved = await Navigator.push<QuoteLine>(
      context,
      MaterialPageRoute(
        builder: (_) => QuoteLineEditScreen(
          quoteId: widget.quoteId,
          initial: line,
        ),
      ),
    );
    if (saved == null) return;
    final lines = [..._lines];
    final index = lines.indexWhere((item) => item.id == saved.id);
    if (index >= 0) {
      lines[index] = saved;
    } else {
      lines.add(saved);
    }
    await repo.upsertQuoteLines(widget.quoteId, lines);
    if (!mounted) return;
    setState(() => _lines = lines);
  }

  Future<void> _deleteLine(QuoteLine line) async {
    final lines = _lines.where((item) => item.id != line.id).toList();
    await context.read<QuoteRepo>().upsertQuoteLines(widget.quoteId, lines);
    if (!mounted) return;
    setState(() => _lines = lines);
  }

  Future<void> _openLineItemDetail(QuoteLine line) async {
    final itemId = line.itemId.trim();
    if (itemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결된 아이템이 없습니다.')),
      );
      return;
    }
    final item = await context.read<ItemRepo>().getItem(itemId);
    if (!mounted) return;
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이템을 찾을 수 없습니다.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockItemDetailScreen(itemId: itemId)),
    );
    if (mounted) await _reload();
  }

  Future<void> _openPrint({required bool mobile}) async {
    await _saveHeader();
    if (!mounted || _quote == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => mobile
            ? QuotePrintViewMobile(quote: _quote!, lines: _lines)
            : QuotePrintView(quote: _quote!, lines: _lines),
      ),
    );
  }

  Future<void> _openPlayAutoOrderAdd() async {
    await _saveHeader();
    if (!mounted || _quote == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayAutoQuoteOrderAddScreen(
          quote: _quote!,
          lines: _lines,
        ),
      ),
    );
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

  String _vatText(QuoteVatType type) {
    switch (type) {
      case QuoteVatType.exclusive:
        return '부가세 별도';
      case QuoteVatType.inclusive:
        return '부가세 포함';
      case QuoteVatType.exempt:
        return '면세';
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (quote == null) {
      return const Scaffold(body: Center(child: Text('견적서를 찾을 수 없습니다.')));
    }

    final dateFmt = DateFormat('yyyy.MM.dd');
    final totals = QuoteTotals.fromLines(quote: quote, lines: _lines);

    return Scaffold(
      appBar: AppBar(
        title: const Text('견적 상세'),
        actions: [
          TextButton.icon(
            onPressed: _openPlayAutoOrderAdd,
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('플토 주문'),
          ),
          PopupMenuButton<String>(
            tooltip: '견적서 보기',
            icon: const Icon(Icons.article_outlined),
            onSelected: (value) => _openPrint(mobile: value == 'mobile'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'a4', child: Text('A4 견적서 보기')),
              PopupMenuItem(value: 'mobile', child: Text('모바일용 견적서 보기')),
            ],
          ),
          PopupMenuButton<QuoteStatus>(
            tooltip: '상태 변경',
            onSelected: _changeStatus,
            itemBuilder: (_) => QuoteStatus.values
                .map((status) => PopupMenuItem(
                      value: status,
                      child: Text(_statusText(status)),
                    ))
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('품목'),
        onPressed: () => _editLine(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _customerC,
            decoration: InputDecoration(
              labelText: '거래처',
              suffixIcon: IconButton(
                tooltip: '거래처 선택',
                icon: const Icon(Icons.business),
                onPressed: _pickCustomer,
              ),
            ),
            onSubmitted: (_) => _saveHeader(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.calendar_today, size: 18),
                label: Text('견적일 ${dateFmt.format(quote.quoteDate)}'),
                onPressed: () => _pickDate(validUntil: false),
              ),
              ActionChip(
                avatar: const Icon(Icons.event_available, size: 18),
                label: Text(
                  quote.validUntil == null
                      ? '유효기간 설정'
                      : '유효기간 ${dateFmt.format(quote.validUntil!)}',
                ),
                onPressed: () => _pickDate(validUntil: true),
              ),
              Chip(label: Text(_statusText(quote.status))),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('공급자'),
            subtitle: Text(_supplierSummary(quote)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changeSupplierProfile(quote),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<QuoteVatType>(
            value: quote.vatType,
            decoration: const InputDecoration(labelText: '부가세'),
            items: QuoteVatType.values
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(_vatText(type)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) _changeVatType(value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '할인'),
                  onSubmitted: (_) => _saveHeader(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _shippingC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '배송/기타'),
                  onSubmitted: (_) => _saveHeader(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoC,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '메모'),
            onSubmitted: (_) => _saveHeader(),
          ),
          const SizedBox(height: 20),
          Text('품목', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('견적 품목이 없습니다.')),
            )
          else
            ..._lines.map(
              (line) => Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _editLine(line),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => _openLineItemDetail(line),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    line.name,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_num(line.qty)} ${line.unit} x ${_money(line.unitPrice)} · '
                                '${_lineVatText(line.vatType)} / '
                                '공급 ${_money(line.supplyAmount)} · '
                                '부가세 ${_money(line.vatAmount)} · '
                                '합계 ${_money(line.totalAmount)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _money(line.totalAmount),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        IconButton(
                          tooltip: '견적라인 편집',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _editLine(line),
                        ),
                        IconButton(
                          tooltip: '삭제',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteLine(line),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _totalLine('공급가', totals.subtotal),
                  if (totals.discount > 0) _totalLine('할인', -totals.discount),
                  if (totals.shipping > 0) _totalLine('배송/기타', totals.shipping),
                  _totalLine('부가세', totals.vat),
                  const Divider(),
                  _totalLine('합계', totals.total, bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

Widget _totalLine(String label, double value, {bool bold = false}) {
  final style =
      TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(_money(value), style: style),
      ],
    ),
  );
}

String _num(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
String _money(double value) => NumberFormat('#,##0').format(value);

String _lineVatText(VatType type) => switch (type) {
      VatType.exclusive => '별도',
      VatType.inclusive => '포함',
      VatType.exempt => '면세',
    };
