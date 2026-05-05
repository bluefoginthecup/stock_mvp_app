import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/suppliers.dart';
import '../../repos/repo_interfaces.dart';

class SupplierFormScreen extends StatefulWidget {
  final String? supplierId;
  final String? initialName;
  const SupplierFormScreen({super.key, this.supplierId, this.initialName});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _contactC = TextEditingController();
  final _phoneC = TextEditingController();
  final _emailC = TextEditingController();
  final _addrC = TextEditingController();
  final _faxC = TextEditingController();
  final _memoC = TextEditingController();
  final _businessNumberC = TextEditingController();
  final _representativeC = TextEditingController();
  final _businessTypeC = TextEditingController();
  final _businessItemC = TextEditingController();
  final _uuid = const Uuid();

  String? _supplierId;
  bool _isActive = true;
  bool _loading = true;
  bool _detailExpanded = false;
  final List<_SupplierContactDraft> _contacts = [];
  final List<_SupplierAccountDraft> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadIfEdit();
  }

  Future<void> _loadIfEdit() async {
    final repo = context.read<SupplierRepo>();
    if (widget.supplierId != null) {
      final s = await repo.get(widget.supplierId!);
      if (s != null) {
        _supplierId = s.id;
        _nameC.text = s.name;
        _contactC.text = s.contactName ?? '';
        _phoneC.text = s.phone ?? '';
        _emailC.text = s.email ?? '';
        _addrC.text = s.addr ?? '';
        _faxC.text = s.fax ?? '';
        _memoC.text = s.memo ?? '';
        _businessNumberC.text = s.businessNumber ?? '';
        _representativeC.text = s.representative ?? '';
        _businessTypeC.text = s.businessType ?? '';
        _businessItemC.text = s.businessItem ?? '';
        _isActive = s.isActive;
      }

      final contacts = await repo.listContacts(widget.supplierId!);
      _contacts
        ..clear()
        ..addAll(contacts.map(_SupplierContactDraft.fromDomain));

      final accounts = await repo.listAccounts(widget.supplierId!);
      _accounts
        ..clear()
        ..addAll(accounts.map(_SupplierAccountDraft.fromDomain));
    } else if ((widget.initialName ?? '').trim().isNotEmpty) {
      _nameC.text = widget.initialName!.trim();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _contactC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _addrC.dispose();
    _faxC.dispose();
    _memoC.dispose();
    _businessNumberC.dispose();
    _representativeC.dispose();
    _businessTypeC.dispose();
    _businessItemC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.read<SupplierRepo>();
    final now = DateTime.now();

    final existingId = widget.supplierId;
    final supplierId = existingId ?? _uuid.v4();
    final supplier = Supplier(
      id: supplierId,
      name: _nameC.text.trim(),
      contactName: _nullIfBlank(_contactC.text),
      phone: _nullIfBlank(_phoneC.text),
      email: _nullIfBlank(_emailC.text),
      addr: _nullIfBlank(_addrC.text),
      fax: _nullIfBlank(_faxC.text),
      memo: _nullIfBlank(_memoC.text),
      businessNumber: _nullIfBlank(_businessNumberC.text),
      representative: _nullIfBlank(_representativeC.text),
      businessType: _nullIfBlank(_businessTypeC.text),
      businessItem: _nullIfBlank(_businessItemC.text),
      isActive: _isActive,
      createdAt: now,
      updatedAt: now,
    );

    final contacts = <SupplierContact>[];
    var primarySeen = false;
    for (var i = 0; i < _contacts.length; i++) {
      final c = _contacts[i];
      final name = c.name.trim();
      if (name.isEmpty) continue;
      final isPrimary = c.isPrimary && !primarySeen;
      if (isPrimary) primarySeen = true;
      contacts.add(c.copyWith(isPrimary: isPrimary).toDomain(supplierId, i));
    }

    final accounts = <SupplierAccount>[];
    var primaryAccountSeen = false;
    for (var i = 0; i < _accounts.length; i++) {
      final a = _accounts[i];
      final hasBank = a.bankName.trim().isNotEmpty;
      final hasNumber = a.accountNumber.trim().isNotEmpty;
      final hasAny = hasBank ||
          hasNumber ||
          a.accountHolder.trim().isNotEmpty ||
          a.memo.trim().isNotEmpty;

      if (!hasAny) continue;
      if (!hasBank || !hasNumber) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('계좌는 은행명과 계좌번호를 모두 입력하세요'),
          ),
        );
        return;
      }

      final isPrimary = a.isPrimary && !primaryAccountSeen;
      if (isPrimary) primaryAccountSeen = true;
      accounts.add(a.copyWith(isPrimary: isPrimary).toDomain(supplierId, i));
    }

    await repo.upsert(supplier);
    await repo.replaceAccounts(supplierId, accounts);
    await repo.replaceContacts(supplierId, contacts);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existingId == null ? '거래처가 등록되었어요' : '거래처가 저장되었어요'),
      ),
    );
    Navigator.pop(context, supplier);
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _hasExistingContactFields() {
    return [_nameC, _contactC, _phoneC, _emailC, _addrC]
        .any((c) => c.text.trim().isNotEmpty);
  }

  Future<bool> _confirmOverwriteContactFields() async {
    if (!_hasExistingContactFields()) return true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('연락처 정보 가져오기'),
        content: const Text(
          '기존에 입력된 거래처 정보가 있습니다. 연락처 정보로 덮어쓸까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('덮어쓰기'),
          ),
        ],
      ),
    );

    return ok == true;
  }

  Future<Contact?> _pickDeviceContact() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('연락처 가져오기는 iPhone/Android 앱에서 사용할 수 있습니다')),
      );
      return null;
    }

    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연락처 접근 권한이 필요합니다')),
      );
      return null;
    }

    final picked = await FlutterContacts.openExternalPick();
    if (picked == null) return null;

    final contact = await FlutterContacts.getContact(
      picked.id,
      withProperties: true,
    );
    if (!mounted) return null;
    return contact;
  }

  Future<void> _importFromContacts() async {
    final contact = await _pickDeviceContact();
    if (contact == null) return;

    final shouldOverwrite = await _confirmOverwriteContactFields();
    if (!shouldOverwrite) return;

    _applyContact(contact);
  }

  Future<void> _addContactFromDevice() async {
    final contact = await _pickDeviceContact();
    if (contact == null) return;

    setState(() {
      _contacts.add(_SupplierContactDraft.fromContact(
        contact,
        sortOrder: _contacts.length,
      ));
    });
  }

  void _applyContact(Contact contact) {
    final info = _ContactInfo.fromContact(contact);

    setState(() {
      _nameC.text = info.company.isNotEmpty ? info.company : info.name;
      _contactC.text = info.name;
      _phoneC.text = info.phone;
      _emailC.text = info.email;
      _addrC.text = info.address;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('연락처 정보를 가져왔습니다')),
    );
  }

  void _addEmptyContact() {
    setState(() {
      _contacts.add(
          _SupplierContactDraft(id: _uuid.v4(), sortOrder: _contacts.length));
    });
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
      _syncContactOrder();
    });
  }

  void _setPrimaryContact(int index, bool value) {
    setState(() {
      for (var i = 0; i < _contacts.length; i++) {
        _contacts[i] = _contacts[i].copyWith(isPrimary: value && i == index);
      }
    });
  }

  void _syncContactOrder() {
    for (var i = 0; i < _contacts.length; i++) {
      _contacts[i] = _contacts[i].copyWith(sortOrder: i);
    }
  }

  void _addEmptyAccount() {
    setState(() {
      _accounts.add(
          _SupplierAccountDraft(id: _uuid.v4(), sortOrder: _accounts.length));
    });
  }

  void _removeAccount(int index) {
    setState(() {
      _accounts.removeAt(index);
      _syncAccountOrder();
    });
  }

  void _setPrimaryAccount(int index, bool value) {
    setState(() {
      for (var i = 0; i < _accounts.length; i++) {
        _accounts[i] = _accounts[i].copyWith(isPrimary: value && i == index);
      }
    });
  }

  void _syncAccountOrder() {
    for (var i = 0; i < _accounts.length; i++) {
      _accounts[i] = _accounts[i].copyWith(sortOrder: i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplierId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '거래처 수정' : '거래처 등록'),
        actions: [
          IconButton(
            tooltip: '연락처에서 가져오기',
            onPressed: _importFromContacts,
            icon: const Icon(Icons.contacts),
          ),
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('기본 거래처 정보',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameC,
                    decoration: const InputDecoration(
                      labelText: '거래처명 *',
                      hintText: '예) 대원섬유',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '거래처명을 입력하세요' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactC,
                    decoration: const InputDecoration(labelText: '담당자'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneC,
                    decoration: const InputDecoration(labelText: '전화'),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _importFromContacts,
                    icon: const Icon(Icons.contacts),
                    label: const Text('연락처에서 가져오기'),
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    initiallyExpanded: _detailExpanded,
                    onExpansionChanged: (v) =>
                        setState(() => _detailExpanded = v),
                    title: const Text('상세정보'),
                    children: [
                      _buildAccountSection(),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addrC,
                        decoration: const InputDecoration(labelText: '주소'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailC,
                        decoration: const InputDecoration(labelText: '이메일'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _faxC,
                        decoration: const InputDecoration(labelText: '팩스'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _businessNumberC,
                        decoration: const InputDecoration(labelText: '사업자등록번호'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _representativeC,
                        decoration: const InputDecoration(labelText: '대표'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _businessTypeC,
                        decoration: const InputDecoration(labelText: '업태'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _businessItemC,
                        decoration: const InputDecoration(labelText: '종목'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _memoC,
                        decoration: const InputDecoration(labelText: '메모'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        title: const Text('활성 상태'),
                        subtitle: const Text('비활성 시 기본 선택 목록에서 제외'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildContactSection(),
                  if (isEdit && _supplierId != null) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('내부 ID'),
                      subtitle: SelectableText(_supplierId!),
                      trailing: IconButton(
                        tooltip: 'ID 복사',
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: _supplierId!),
                          );
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('거래처 ID를 복사했어요')),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: Text(isEdit ? '저장' : '등록'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '추가 연락처',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: '연락처에서 가져오기',
              onPressed: _addContactFromDevice,
              icon: const Icon(Icons.contacts),
            ),
            IconButton(
              tooltip: '연락처 추가',
              onPressed: _addEmptyContact,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_contacts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('추가 연락처가 없습니다'),
          )
        else
          ...List.generate(_contacts.length, (index) {
            return _SupplierContactCard(
              key: ValueKey(_contacts[index].id),
              contact: _contacts[index],
              onChanged: (next) => setState(() => _contacts[index] = next),
              onPrimaryChanged: (value) => _setPrimaryContact(index, value),
              onDelete: () => _removeContact(index),
            );
          }),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addEmptyContact,
                icon: const Icon(Icons.add),
                label: const Text('연락처 추가'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addContactFromDevice,
                icon: const Icon(Icons.contacts),
                label: const Text('연락처에서 가져오기'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '계좌',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: '계좌 추가',
              onPressed: _addEmptyAccount,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('등록된 계좌가 없습니다'),
          )
        else
          ...List.generate(_accounts.length, (index) {
            return _SupplierAccountCard(
              key: ValueKey(_accounts[index].id),
              account: _accounts[index],
              onChanged: (next) => setState(() => _accounts[index] = next),
              onPrimaryChanged: (value) => _setPrimaryAccount(index, value),
              onDelete: () => _removeAccount(index),
            );
          }),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addEmptyAccount,
            icon: const Icon(Icons.add),
            label: const Text('계좌 추가'),
          ),
        ),
      ],
    );
  }
}

class _SupplierAccountCard extends StatefulWidget {
  final _SupplierAccountDraft account;
  final ValueChanged<_SupplierAccountDraft> onChanged;
  final ValueChanged<bool> onPrimaryChanged;
  final VoidCallback onDelete;

  const _SupplierAccountCard({
    super.key,
    required this.account,
    required this.onChanged,
    required this.onPrimaryChanged,
    required this.onDelete,
  });

  @override
  State<_SupplierAccountCard> createState() => _SupplierAccountCardState();
}

class _SupplierAccountCardState extends State<_SupplierAccountCard> {
  bool _expanded = false;

  void _update(_SupplierAccountDraft next) {
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: a.isPrimary ? '대표 계좌' : '대표 계좌로 지정',
                  icon: Icon(
                    a.isPrimary ? Icons.star : Icons.star_border,
                    color: a.isPrimary ? Colors.amber.shade700 : null,
                  ),
                  onPressed: () => widget.onPrimaryChanged(!a.isPrimary),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: a.bankName,
                    decoration: const InputDecoration(labelText: '은행명'),
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => _update(a.copyWith(bankName: v)),
                  ),
                ),
                IconButton(
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: a.accountNumber,
              decoration: const InputDecoration(labelText: '계좌번호'),
              keyboardType: TextInputType.text,
              onChanged: (v) => _update(a.copyWith(accountNumber: v)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: a.accountHolder,
              decoration: const InputDecoration(labelText: '예금주'),
              onChanged: (v) => _update(a.copyWith(accountHolder: v)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? '상세정보 닫기' : '상세정보'),
              ),
            ),
            if (_expanded) ...[
              TextFormField(
                initialValue: a.memo,
                decoration: const InputDecoration(labelText: '메모'),
                maxLines: 2,
                onChanged: (v) => _update(a.copyWith(memo: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: a.isPrimary,
                onChanged: widget.onPrimaryChanged,
                title: const Text('대표 계좌'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupplierContactCard extends StatefulWidget {
  final _SupplierContactDraft contact;
  final ValueChanged<_SupplierContactDraft> onChanged;
  final ValueChanged<bool> onPrimaryChanged;
  final VoidCallback onDelete;

  const _SupplierContactCard({
    super.key,
    required this.contact,
    required this.onChanged,
    required this.onPrimaryChanged,
    required this.onDelete,
  });

  @override
  State<_SupplierContactCard> createState() => _SupplierContactCardState();
}

class _SupplierContactCardState extends State<_SupplierContactCard> {
  bool _expanded = false;

  void _update(_SupplierContactDraft next) {
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: c.isPrimary ? '대표 연락처' : '대표로 지정',
                  icon: Icon(
                    c.isPrimary ? Icons.star : Icons.star_border,
                    color: c.isPrimary ? Colors.amber.shade700 : null,
                  ),
                  onPressed: () => widget.onPrimaryChanged(!c.isPrimary),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: c.name,
                    decoration: const InputDecoration(labelText: '이름'),
                    onChanged: (v) => _update(c.copyWith(name: v)),
                  ),
                ),
                IconButton(
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: c.phone,
              decoration: const InputDecoration(labelText: '전화'),
              keyboardType: TextInputType.phone,
              onChanged: (v) => _update(c.copyWith(phone: v)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: c.email,
              decoration: const InputDecoration(labelText: '이메일'),
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) => _update(c.copyWith(email: v)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? '상세정보 닫기' : '상세정보'),
              ),
            ),
            if (_expanded) ...[
              TextFormField(
                initialValue: c.roleOrMemo,
                decoration: const InputDecoration(labelText: '역할/메모'),
                onChanged: (v) => _update(c.copyWith(roleOrMemo: v)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: c.fax,
                decoration: const InputDecoration(labelText: '팩스'),
                keyboardType: TextInputType.phone,
                onChanged: (v) => _update(c.copyWith(fax: v)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: c.address,
                decoration: const InputDecoration(labelText: '주소'),
                maxLines: 2,
                onChanged: (v) => _update(c.copyWith(address: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: c.isPrimary,
                onChanged: widget.onPrimaryChanged,
                title: const Text('대표 추가 연락처'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactInfo {
  final String company;
  final String name;
  final String phone;
  final String email;
  final String address;

  const _ContactInfo({
    required this.company,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
  });

  factory _ContactInfo.fromContact(Contact contact) {
    final company = contact.organizations.isNotEmpty
        ? contact.organizations.first.company.trim()
        : '';
    final name = contact.displayName.trim();
    return _ContactInfo(
      company: company,
      name: name,
      phone:
          contact.phones.isNotEmpty ? contact.phones.first.number.trim() : '',
      email:
          contact.emails.isNotEmpty ? contact.emails.first.address.trim() : '',
      address: contact.addresses.isNotEmpty
          ? contact.addresses.first.address.trim()
          : '',
    );
  }
}

class _SupplierContactDraft {
  final String id;
  final String name;
  final String roleOrMemo;
  final String phone;
  final String fax;
  final String email;
  final String address;
  final bool isPrimary;
  final int sortOrder;

  const _SupplierContactDraft({
    required this.id,
    this.name = '',
    this.roleOrMemo = '',
    this.phone = '',
    this.fax = '',
    this.email = '',
    this.address = '',
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  factory _SupplierContactDraft.fromDomain(SupplierContact c) {
    return _SupplierContactDraft(
      id: c.id,
      name: c.name,
      roleOrMemo: c.roleOrMemo ?? '',
      phone: c.phone ?? '',
      fax: c.fax ?? '',
      email: c.email ?? '',
      address: c.address ?? '',
      isPrimary: c.isPrimary,
      sortOrder: c.sortOrder,
    );
  }

  factory _SupplierContactDraft.fromContact(Contact contact,
      {required int sortOrder}) {
    final info = _ContactInfo.fromContact(contact);
    return _SupplierContactDraft(
      id: const Uuid().v4(),
      name: info.name.isNotEmpty ? info.name : info.company,
      phone: info.phone,
      email: info.email,
      address: info.address,
      sortOrder: sortOrder,
    );
  }

  _SupplierContactDraft copyWith({
    String? name,
    String? roleOrMemo,
    String? phone,
    String? fax,
    String? email,
    String? address,
    bool? isPrimary,
    int? sortOrder,
  }) =>
      _SupplierContactDraft(
        id: id,
        name: name ?? this.name,
        roleOrMemo: roleOrMemo ?? this.roleOrMemo,
        phone: phone ?? this.phone,
        fax: fax ?? this.fax,
        email: email ?? this.email,
        address: address ?? this.address,
        isPrimary: isPrimary ?? this.isPrimary,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  SupplierContact toDomain(String supplierId, int order) => SupplierContact(
        id: id,
        supplierId: supplierId,
        name: name.trim(),
        roleOrMemo: _blankToNull(roleOrMemo),
        phone: _blankToNull(phone),
        fax: _blankToNull(fax),
        email: _blankToNull(email),
        address: _blankToNull(address),
        isPrimary: isPrimary,
        sortOrder: order,
      );

  static String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _SupplierAccountDraft {
  final String id;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String memo;
  final bool isPrimary;
  final int sortOrder;

  const _SupplierAccountDraft({
    required this.id,
    this.bankName = '',
    this.accountNumber = '',
    this.accountHolder = '',
    this.memo = '',
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  factory _SupplierAccountDraft.fromDomain(SupplierAccount a) {
    return _SupplierAccountDraft(
      id: a.id,
      bankName: a.bankName,
      accountNumber: a.accountNumber,
      accountHolder: a.accountHolder ?? '',
      memo: a.memo ?? '',
      isPrimary: a.isPrimary,
      sortOrder: a.sortOrder,
    );
  }

  _SupplierAccountDraft copyWith({
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? memo,
    bool? isPrimary,
    int? sortOrder,
  }) =>
      _SupplierAccountDraft(
        id: id,
        bankName: bankName ?? this.bankName,
        accountNumber: accountNumber ?? this.accountNumber,
        accountHolder: accountHolder ?? this.accountHolder,
        memo: memo ?? this.memo,
        isPrimary: isPrimary ?? this.isPrimary,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  SupplierAccount toDomain(String supplierId, int order) => SupplierAccount(
        id: id,
        supplierId: supplierId,
        bankName: bankName.trim(),
        accountNumber: accountNumber.trim(),
        accountHolder: _blankToNull(accountHolder),
        memo: _blankToNull(memo),
        isPrimary: isPrimary,
        sortOrder: order,
      );

  static String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
