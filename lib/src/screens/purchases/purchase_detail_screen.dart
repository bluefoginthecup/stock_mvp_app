import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../models/extensions/payment_status_ext.dart';
import '../../models/extensions/vat_invoice_status_ext.dart';
import '../../models/purchase_line.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_receipt.dart';
import '../../models/suppliers.dart';
import '../../models/types.dart';
import '../../repos/repo_interfaces.dart';
import '../../services/app_path_service.dart';
import '../../services/inventory_service.dart';
import '../../ui/common/delete_more_menu.dart';
import '../../ui/common/supplier_picker_sheet.dart';
import '../../ui/common/ui.dart';
import 'purchase_line_full_edit_screen.dart';
import 'widgets/purchase_print_action.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final PurchaseOrderRepo repo;
  final String orderId;

  const PurchaseDetailScreen({
    super.key,
    required this.repo,
    required this.orderId,
  });

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  PurchaseOrder? _po;
  List<PurchaseLine> _lines = const [];
  List<PurchaseReceipt> _receipts = const [];
  final Set<String> _collapsedReceiptIds = <String>{};
  bool _loading = true;
  bool _addingReceipt = false;
  final _uuid = const Uuid();
  final _paths = const AppPathService();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
    });

    try {
      final po = await widget.repo.getPurchaseOrderById(widget.orderId);
      final lines = await widget.repo.getLines(widget.orderId);
      final receipts = await _repairReceiptFilePaths(
        await widget.repo.getPurchaseReceipts(widget.orderId),
      );

      if (!mounted) return;
      final receiptIds = receipts.map((receipt) => receipt.id).toSet();

      setState(() {
        _po = po;
        _lines = lines;
        _receipts = receipts;
        _collapsedReceiptIds.removeWhere((id) => !receiptIds.contains(id));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<List<PurchaseReceipt>> _repairReceiptFilePaths(
    List<PurchaseReceipt> receipts,
  ) async {
    final repaired = <PurchaseReceipt>[];

    for (final receipt in receipts) {
      final resolved = await _resolveReceiptFile(receipt);
      if (resolved != null) {
        final normalized = await _paths.normalizeToRelativePath(resolved.path);
        if (normalized != receipt.filePath) {
          final updated = receipt.copyWith(filePath: normalized);
          await widget.repo.addPurchaseReceipt(updated);
          repaired.add(updated);
          continue;
        }
      }

      final normalized = await _paths.normalizeToRelativePath(receipt.filePath);
      if (normalized != receipt.filePath) {
        final updated = receipt.copyWith(filePath: normalized);
        await widget.repo.addPurchaseReceipt(updated);
        repaired.add(updated);
      } else {
        repaired.add(receipt);
      }
    }

    return repaired;
  }

  Future<File?> _resolveReceiptFile(PurchaseReceipt receipt) async {
    return _paths.resolveExistingPurchaseReceiptFile(
      purchaseOrderId: receipt.purchaseOrderId,
      storedPath: receipt.filePath,
    );
  }

  String _statusLabel(PurchaseOrderStatus s) {
    switch (s) {
      case PurchaseOrderStatus.draft:
        return '임시저장';
      case PurchaseOrderStatus.ordered:
        return '발주완료';
      case PurchaseOrderStatus.received:
        return '입고완료';
      case PurchaseOrderStatus.canceled:
        return '발주취소';
    }
  }

  String _fmt(num v) => v.toStringAsFixed(0);

  String _mimeFor(String fileName, {String? explicit}) {
    if (explicit != null && explicit.trim().isNotEmpty) return explicit;
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String _safeFileName(String name) {
    final trimmed = name.trim().isEmpty ? 'receipt' : name.trim();
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  bool _isImageFile(String fileName, {String? mimeType}) {
    if (mimeType != null && mimeType.startsWith('image/')) return true;
    final ext = p.extension(fileName).toLowerCase();
    return const {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
      '.bmp',
    }.contains(ext);
  }

  Future<_StoredReceiptFile> _copyReceiptFileToInternal({
    required String sourcePath,
    required String fileName,
    required Directory receiptDir,
    String? mimeType,
  }) async {
    final safeName = _safeFileName(fileName);
    if (_isImageFile(safeName, mimeType: mimeType)) {
      return _copyOptimizedImageToInternal(
        sourcePath: sourcePath,
        safeName: safeName,
        receiptDir: receiptDir,
        fallbackMimeType: _mimeFor(safeName, explicit: mimeType),
      );
    }

    return _copyOriginalFileToInternal(
      sourcePath: sourcePath,
      safeName: safeName,
      receiptDir: receiptDir,
      mimeType: _mimeFor(safeName, explicit: mimeType),
    );
  }

  Future<_StoredReceiptFile> _copyOptimizedImageToInternal({
    required String sourcePath,
    required String safeName,
    required Directory receiptDir,
    required String fallbackMimeType,
  }) async {
    final baseName = p.basenameWithoutExtension(safeName);
    final destName =
        '${DateTime.now().microsecondsSinceEpoch}_${_uuid.v4()}_$baseName.jpg';
    final destPath = p.join(receiptDir.path, destName);

    try {
      final sourceBytes = await File(sourcePath).readAsBytes();
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) {
        throw const FormatException('Unsupported image format');
      }

      final oriented = img.bakeOrientation(decoded);
      final longSide =
          oriented.width > oriented.height ? oriented.width : oriented.height;
      final resized = longSide > 1600
          ? img.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? 1600 : null,
              height: oriented.height > oriented.width ? 1600 : null,
              interpolation: img.Interpolation.average,
            )
          : oriented;

      final jpgBytes = img.encodeJpg(resized, quality: 75);
      await File(destPath).writeAsBytes(jpgBytes, flush: true);

      return _StoredReceiptFile(
        fileName: '$baseName.jpg',
        filePath: destPath,
        mimeType: 'image/jpeg',
      );
    } catch (_) {
      return _copyOriginalFileToInternal(
        sourcePath: sourcePath,
        safeName: safeName,
        receiptDir: receiptDir,
        mimeType: fallbackMimeType,
      );
    }
  }

  Future<_StoredReceiptFile> _copyOriginalFileToInternal({
    required String sourcePath,
    required String safeName,
    required Directory receiptDir,
    required String mimeType,
  }) async {
    final destName =
        '${DateTime.now().microsecondsSinceEpoch}_${_uuid.v4()}_$safeName';
    final destPath = p.join(receiptDir.path, destName);
    await File(sourcePath).copy(destPath);

    return _StoredReceiptFile(
      fileName: safeName,
      filePath: destPath,
      mimeType: mimeType,
    );
  }

  Future<String?> _editMemo({String initial = ''}) {
    return _editText(title: '첨부 메모', initial: initial);
  }

  Future<void> _addReceiptFromFile({
    required String sourcePath,
    required String fileName,
    String? mimeType,
  }) async {
    final po = _po;
    if (po == null) return;

    final receiptDir = await _paths.purchaseReceiptOrderDirectory(po.id);
    if (!await receiptDir.exists()) {
      await receiptDir.create(recursive: true);
    }

    final stored = await _copyReceiptFileToInternal(
      sourcePath: sourcePath,
      fileName: fileName,
      receiptDir: receiptDir,
      mimeType: mimeType,
    );

    final memo = await _editMemo();
    if (memo == null) {
      try {
        final copied = File(stored.filePath);
        if (await copied.exists()) {
          await copied.delete();
        }
      } catch (_) {
        // 사용자가 첨부를 취소한 경우의 복사본 정리 실패는 화면 흐름을 막지 않는다.
      }
      return;
    }

    final storedPath = await _paths.normalizeToRelativePath(stored.filePath);

    await widget.repo.addPurchaseReceipt(
      PurchaseReceipt(
        id: _uuid.v4(),
        purchaseOrderId: po.id,
        fileName: stored.fileName,
        filePath: storedPath,
        mimeType: stored.mimeType,
        createdAt: DateTime.now(),
        memo: memo.trim().isEmpty ? null : memo.trim(),
      ),
    );

    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('첨부파일을 저장했습니다')),
    );
  }

  Future<void> _pickReceipt() async {
    if (_addingReceipt) return;

    final action = await showModalBottomSheet<_ReceiptPickAction>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(context, _ReceiptPickAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('사진 선택'),
              onTap: () => Navigator.pop(context, _ReceiptPickAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('파일 선택'),
              onTap: () => Navigator.pop(context, _ReceiptPickAction.file),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;

    setState(() => _addingReceipt = true);
    try {
      if (action == _ReceiptPickAction.file) {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          withData: false,
        );
        final file = result?.files.single;
        final path = file?.path;
        if (file == null || path == null) return;

        await _addReceiptFromFile(
          sourcePath: path,
          fileName: file.name,
        );
      } else {
        final image = await ImagePicker().pickImage(
          source: action == _ReceiptPickAction.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 75,
        );
        if (image == null) return;

        await _addReceiptFromFile(
          sourcePath: image.path,
          fileName: image.name,
          mimeType: image.mimeType,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('첨부파일 저장에 실패했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _addingReceipt = false);
    }
  }

  Future<void> _openReceipt(PurchaseReceipt receipt) async {
    final file = await _resolveReceiptFile(receipt);
    if (file == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('첨부파일을 찾을 수 없습니다.')),
      );
      return;
    }

    final normalized = await _paths.normalizeToRelativePath(file.path);
    if (normalized != receipt.filePath) {
      await widget.repo
          .addPurchaseReceipt(receipt.copyWith(filePath: normalized));
      await _reload();
    }

    if (receipt.canPreviewInApp) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('이미지를 열 수 없습니다.'),
              ),
            ),
          ),
        ),
      );
      return;
    }

    await Share.shareXFiles(
      [XFile(file.path, mimeType: receipt.mimeType, name: receipt.fileName)],
      text: receipt.fileName,
    );
  }

  Future<void> _deleteReceipt(PurchaseReceipt receipt) async {
    final confirmed = await confirmDelete(
      context,
      title: '첨부파일 삭제',
      message: '${receipt.fileName} 파일을 삭제할까요?',
      confirmLabel: '삭제',
    );
    if (!confirmed) return;

    await widget.repo.deletePurchaseReceipt(receipt.id);
    try {
      final file = await _resolveReceiptFile(receipt);
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 파일 정리 실패는 DB 삭제를 되돌리지 않는다.
    }

    await _reload();
  }

  Future<void> _editReceiptMemo(PurchaseReceipt receipt) async {
    final memo = await _editMemo(initial: receipt.memo ?? '');
    if (memo == null) return;

    await widget.repo.addPurchaseReceipt(
      receipt.copyWith(memo: memo.trim().isEmpty ? null : memo.trim()),
    );
    await _reload();
  }

  Widget _buildReceiptsSection() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '영수증 / 거래명세서',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '첨부 추가',
                  onPressed: _addingReceipt ? null : _pickReceipt,
                  icon: _addingReceipt
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_receipts.isEmpty)
              Text(
                '첨부된 파일이 없습니다.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Column(
                children: _receipts.map((receipt) {
                  final collapsed = _collapsedReceiptIds.contains(receipt.id);
                  return FutureBuilder<File?>(
                    future: receipt.canPreviewInApp
                        ? _resolveReceiptFile(receipt)
                        : Future<File?>.value(),
                    builder: (context, snapshot) {
                      return _ReceiptTile(
                        receipt: receipt,
                        previewFile: snapshot.data,
                        collapsed: collapsed,
                        onOpen: () => _openReceipt(receipt),
                        onEditMemo: () => _editReceiptMemo(receipt),
                        onDelete: () => _deleteReceipt(receipt),
                        onToggleCollapsed: receipt.canPreviewInApp
                            ? () {
                                setState(() {
                                  if (collapsed) {
                                    _collapsedReceiptIds.remove(receipt.id);
                                  } else {
                                    _collapsedReceiptIds.add(receipt.id);
                                  }
                                });
                              }
                            : null,
                      );
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<Supplier?> _supplierFor(PurchaseOrder po) async {
    final supplierId = po.supplierId;
    if (supplierId == null || supplierId.isEmpty) return null;
    return context.read<SupplierRepo>().get(supplierId);
  }

  String _fallbackSupplierName(PurchaseOrder po) {
    final name = po.supplierName.trim();
    return name.isEmpty ? '(거래처 미지정)' : name;
  }

  Future<void> _changeSupplier() async {
    final po = _po;
    if (po == null) return;

    final selected = await showSupplierPickerSheet(
      context,
      initialQuery: po.supplierName.trim(),
      title: '발주 거래처 연결',
    );
    if (selected == null) return;

    await widget.repo.updatePurchaseOrder(
      po.copyWith(
        supplierId: selected.id,
        supplierName: selected.name,
        updatedAt: DateTime.now(),
      ),
    );

    await _reload();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selected.name} 거래처로 연결되었습니다')),
    );
  }

  Future<String?> _editText({
    required String title,
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                TextField(controller: controller),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, controller.text.trim());
                  },
                  child: const Text('저장'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDateTap(int index) async {
    final po = _po;
    if (po == null) return;

    DateTime initialDate;
    switch (index) {
      case 0:
        initialDate = po.createdAt;
        break;
      case 1:
        initialDate = po.receivedAt ?? po.eta ?? DateTime.now();
        break;
      case 2:
        initialDate = po.paidAt ?? po.paymentDueAt ?? DateTime.now();
        break;
      case 3:
        initialDate =
            po.vatInvoiceIssuedAt ?? po.vatInvoiceDueAt ?? DateTime.now();
        break;
      default:
        initialDate = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    PurchaseOrder updated;
    switch (index) {
      case 0:
        updated = po.copyWith(
          createdAt: picked,
          updatedAt: DateTime.now(),
        );
        break;
      case 1:
        if (po.status == PurchaseOrderStatus.received) {
          // 입고완료 상태 → receivedAt
          updated = po.copyWith(
            receivedAt: picked,
            updatedAt: DateTime.now(),
          );
        } else {
          // 입고예정 상태 → eta
          updated = po.copyWith(
            eta: picked,
            updatedAt: DateTime.now(),
          );
        }
        break;
      case 2:
        if (po.paymentStatusEnum == PaymentStatus.paid) {
          updated = po.copyWith(
            paidAt: picked,
            updatedAt: DateTime.now(),
          );
        } else {
          updated = po.copyWith(
            paymentDueAt: picked,
            updatedAt: DateTime.now(),
          );
        }
        break;
      case 3:
        if (po.vatInvoiceStatusEnum == VatInvoiceStatus.issued) {
          updated = po.copyWith(
            vatInvoiceIssuedAt: picked,
            updatedAt: DateTime.now(),
          );
        } else {
          updated = po.copyWith(
            vatInvoiceDueAt: picked,
            updatedAt: DateTime.now(),
          );
        }
        break;
      default:
        return;
    }

    await widget.repo.updatePurchaseOrder(updated);
    await _reload();
  }

  Future<void> _addLineFull() async {
    final po = _po;
    if (po == null) return;

    final saved = await Navigator.push<PurchaseLine?>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseLineFullEditScreen(
          repo: widget.repo,
          orderId: po.id,
          initial: null,
        ),
      ),
    );

    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추가되었습니다')),
      );
      await _reload();
    }
  }

  Future<void> _openLineFull(PurchaseLine line) async {
    final po = _po;
    if (po == null) return;

    final saved = await Navigator.push<PurchaseLine?>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseLineFullEditScreen(
          repo: widget.repo,
          orderId: po.id,
          initial: line,
        ),
      ),
    );

    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장되었습니다')),
      );
      await _reload();
    }
  }

  Future<void> _handleTimelineTap(int index) async {
    final po = _po;
    if (po == null) return;

    switch (index) {
      case 0:
        final result = await showModalBottomSheet<PurchaseOrderStatus>(
          context: context,
          builder: (_) {
            final options = PurchaseOrderStatus.values
                .where((s) => s != PurchaseOrderStatus.received)
                .toList();

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((s) {
                  return ListTile(
                    title: Text(_statusLabel(s)),
                    trailing: s == po.status ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, s),
                  );
                }).toList(),
              ),
            );
          },
        );

        if (result == null) return;

        await widget.repo.updatePurchaseOrder(
          po.copyWith(
            status: result,
            updatedAt: DateTime.now(),
          ),
        );
        await _reload();
        break;

      case 1:
        final result = await showModalBottomSheet<bool>(
          context: context,
          builder: (_) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('입고완료'),
                    onTap: () => Navigator.pop(context, true),
                  ),
                  ListTile(
                    title: const Text('입고예정'),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            );
          },
        );

        if (result == null) return;

        if (result == false) {
          final picked = await showDatePicker(
            context: context,
            initialDate: po.eta ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );

          if (picked == null) return;

          await context.read<InventoryService>().rollbackReceivePurchase(
                po.id,
                eta: picked,
              );
          await _reload();
          return;
        }

        final receivedDate = await showDatePicker(
          context: context,
          initialDate: po.receivedAt ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (receivedDate == null) return;

        await context.read<InventoryService>().receivePurchase(po.id);

        final newPo = await widget.repo.getPurchaseOrderById(po.id);
        if (newPo != null) {
          await widget.repo.updatePurchaseOrder(
            newPo.copyWith(
              receivedAt: receivedDate,
              updatedAt: DateTime.now(),
            ),
          );
        }

        await _reload();
        break;

      case 2:
        if (po.status != PurchaseOrderStatus.received) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('입고완료 후 결제 처리할 수 있습니다.')),
          );
          return;
        }

        final result = await showModalBottomSheet<bool>(
          context: context,
          builder: (_) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('결제완료'),
                    onTap: () => Navigator.pop(context, true),
                  ),
                  ListTile(
                    title: const Text('결제예정'),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            );
          },
        );

        if (result == null) return;

        if (result == false) {
          final picked = await showDatePicker(
            context: context,
            initialDate: po.paymentDueAt ?? _endOfMonth(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );

          if (picked == null) return;

          await widget.repo.updatePurchaseOrder(
            po.copyWith(
              paymentStatus: PaymentStatus.unpaid.value,
              paidAt: null,
              paymentDueAt: picked,
              updatedAt: DateTime.now(),
            ),
          );
          await _reload();
          return;
        }

        final paidDate = await showDatePicker(
          context: context,
          initialDate: po.paidAt ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (paidDate == null) return;

        await widget.repo.updatePurchaseOrder(
          po.copyWith(
            paymentStatus: PaymentStatus.paid.value,
            paidAt: paidDate,
            updatedAt: DateTime.now(),
          ),
        );
        await _reload();
        break;

      case 3:
        final result = await showModalBottomSheet<bool>(
          context: context,
          builder: (_) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('세금계산서 발행완료'),
                    onTap: () => Navigator.pop(context, true),
                  ),
                  ListTile(
                    title: const Text('세금계산서 발행예정'),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            );
          },
        );

        if (result == null) return;

        if (result == false) {
          final picked = await showDatePicker(
            context: context,
            initialDate: po.vatInvoiceDueAt ?? _endOfMonth(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );

          if (picked == null) return;

          await widget.repo.updatePurchaseOrder(
            po.copyWith(
              vatInvoiceStatus: VatInvoiceStatus.pending.value,
              vatInvoiceIssuedAt: null,
              vatInvoiceDueAt: picked,
              updatedAt: DateTime.now(),
            ),
          );
          await _reload();
          return;
        }

        final issuedDate = await showDatePicker(
          context: context,
          initialDate: po.vatInvoiceIssuedAt ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (issuedDate == null) return;

        await widget.repo.updatePurchaseOrder(
          po.copyWith(
            vatInvoiceStatus: VatInvoiceStatus.issued.value,
            vatInvoiceIssuedAt: issuedDate,
            updatedAt: DateTime.now(),
          ),
        );
        await _reload();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final po = _po;
    if (po == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('발주상세')),
        body: const Center(
          child: Text('발주 정보를 불러오지 못했습니다.'),
        ),
      );
    }

    final itemsTotal = _lines.fold<double>(
      0,
      (sum, l) => sum + (l.qty * l.unitPrice),
    );

    final vat = switch (po.vatType) {
      VatType.exempt => 0.0,
      VatType.inclusive => itemsTotal / 11,
      VatType.exclusive => itemsTotal * 0.1,
    };

    final shipping = po.shippingCost ?? 0.0;
    final extra = po.extraCost ?? 0.0;

    final total = po.vatType == VatType.inclusive
        ? itemsTotal + shipping + extra
        : itemsTotal + vat + shipping + extra;

    return Scaffold(
      appBar: AppBar(
        title: Text('발주상세'),
        actions: [
          DeleteMoreMenu<PurchaseOrder>(
            entity: po,
            onChanged: () {
              if (!mounted) return;
              Navigator.of(context).maybePop();
            },
          ),
          PurchasePrintAction(poId: widget.orderId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLineFull,
        icon: const Icon(Icons.add),
        label: Text('추가'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FutureBuilder<Supplier?>(
                            future: _supplierFor(po),
                            builder: (context, supplierSnap) {
                              final supplier = supplierSnap.data;
                              final isLinked = po.supplierId != null &&
                                  po.supplierId!.isNotEmpty &&
                                  supplier != null;
                              final name =
                                  supplier?.name ?? _fallbackSupplierName(po);

                              return InkWell(
                                onTap: _changeSupplier,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                      if (!isLinked)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            '거래처 연결 필요',
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Chip(
                          label: Text(_statusLabel(po.status)),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PurchaseTimeline(
                      po: po,
                      onStepTap: _handleTimelineTap,
                      onDateTap: _handleDateTap,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('메모'),
                      subtitle: Text(
                        (po.memo ?? '').isEmpty ? '(없음)' : po.memo!,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await _editText(
                          title: '메모',
                          initial: po.memo ?? '',
                        );

                        if (result == null) return;

                        await widget.repo.updatePurchaseOrder(
                          po.copyWith(
                            memo: result.isEmpty ? null : result,
                            updatedAt: DateTime.now(),
                          ),
                        );
                        await _reload();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _lines.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('발주 품목이 없습니다.'),
                    ),
                  )
                : Card(
                    child: Column(
                      children: _lines.map((ln) {
                        final lineTotal = ln.qty * ln.unitPrice;
                        final name =
                            ln.name.trim().isEmpty ? ln.itemId : ln.name;

                        return ListTile(
                          title: Text('$name × ${ln.qty}'),
                          subtitle: Text(
                            '단가 ${_fmt(ln.unitPrice)} / 합계 ${_fmt(lineTotal)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openLineFull(ln),
                        );
                      }).toList(),
                    ),
                  ),
            const SizedBox(height: 8),
            _buildReceiptsSection(),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₩ ${_fmt(total)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _calcItem('상품', itemsTotal),
                        _calcItem('세금', vat),
                        _calcItem('기타', shipping + extra),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class PurchaseTimeline extends StatelessWidget {
  final PurchaseOrder po;
  final void Function(int index) onStepTap;
  final void Function(int index)? onDateTap;

  const PurchaseTimeline({
    super.key,
    required this.po,
    required this.onStepTap,
    this.onDateTap,
  });

  bool get isOrdered =>
      po.status == PurchaseOrderStatus.ordered ||
      po.status == PurchaseOrderStatus.received;

  bool get isReceived => po.status == PurchaseOrderStatus.received;

  bool get isPaid => po.paymentStatusEnum == PaymentStatus.paid;

  bool get isVatIssued => po.vatInvoiceStatusEnum == VatInvoiceStatus.issued;

  Widget _segmentBox({required bool active}) {
    return Expanded(
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: active ? Colors.green : Colors.grey.shade300,
          border: Border.all(
            color: Colors.grey.shade400,
            width: 1,
          ),
        ),
      ),
    );
  }

  String _orderLabel() {
    switch (po.status) {
      case PurchaseOrderStatus.draft:
        return '임시저장';
      case PurchaseOrderStatus.ordered:
      case PurchaseOrderStatus.received:
        return '발주완료';
      case PurchaseOrderStatus.canceled:
        return '발주취소';
    }
  }

  String _receiveLabel() => isReceived ? '입고완료' : '입고예정';

  String _paymentLabel() => isPaid ? '결제완료' : '결제예정';

  String _vatLabel() => isVatIssued ? '세금계산서 발행완료' : '세금계산서 발행예정';

  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step(_orderLabel(), isOrdered, po.createdAt),
      _Step(
        _receiveLabel(),
        isReceived,
        isReceived ? po.receivedAt : po.eta,
      ),
      _Step(
        _paymentLabel(),
        isPaid,
        isPaid ? po.paidAt : po.paymentDueAt,
      ),
      _Step(
        _vatLabel(),
        isVatIssued,
        isVatIssued ? po.vatInvoiceIssuedAt : po.vatInvoiceDueAt,
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 20,
          child: Row(
            children: [
              _segmentBox(active: isOrdered),
              _segmentBox(active: isOrdered && isReceived),
              _segmentBox(active: isOrdered && isReceived && isPaid),
              _segmentBox(
                active: isOrdered && isReceived && isPaid && isVatIssued,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: steps.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;

            return Expanded(
              child: GestureDetector(
                onTap: () => onStepTap(i),
                child: Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: s.done ? Colors.green : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Row(
          children: steps.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;

            return Expanded(
              child: GestureDetector(
                onTap: onDateTap == null ? null : () => onDateTap!(i),
                child: Center(
                  child: Text(
                    s.date != null ? '${s.date!.month}/${s.date!.day}' : '',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Step {
  final String label;
  final bool done;
  final DateTime? date;

  _Step(this.label, this.done, this.date);
}

enum _ReceiptPickAction { camera, gallery, file }

class _StoredReceiptFile {
  final String fileName;
  final String filePath;
  final String mimeType;

  const _StoredReceiptFile({
    required this.fileName,
    required this.filePath,
    required this.mimeType,
  });
}

class _ReceiptTile extends StatelessWidget {
  final PurchaseReceipt receipt;
  final File? previewFile;
  final bool collapsed;
  final VoidCallback onOpen;
  final VoidCallback onEditMemo;
  final VoidCallback onDelete;
  final VoidCallback? onToggleCollapsed;

  const _ReceiptTile({
    required this.receipt,
    required this.previewFile,
    required this.collapsed,
    required this.onOpen,
    required this.onEditMemo,
    required this.onDelete,
    this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    if (receipt.canPreviewInApp && !collapsed) {
      return _ExpandedImageReceiptTile(
        receipt: receipt,
        previewFile: previewFile,
        onOpen: onOpen,
        onEditMemo: onEditMemo,
        onDelete: onDelete,
        onCollapse: onToggleCollapsed,
      );
    }

    final created = receipt.createdAt;
    final memo = receipt.memo?.trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: receipt.canPreviewInApp && previewFile != null
              ? Image.file(
                  previewFile!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fileIcon(),
                )
              : _fileIcon(),
        ),
      ),
      title: Text(
        receipt.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          '${created.year}.${created.month}.${created.day}',
          if (memo != null && memo.isNotEmpty) memo,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onOpen,
      trailing: receipt.canPreviewInApp
          ? TextButton.icon(
              onPressed: onToggleCollapsed,
              icon: const Icon(Icons.unfold_more),
              label: const Text('펼치기'),
            )
          : _ReceiptActionMenu(
              onOpen: onOpen,
              onEditMemo: onEditMemo,
              onDelete: onDelete,
            ),
    );
  }

  Widget _fileIcon() {
    final icon = receipt.mimeType == 'application/pdf'
        ? Icons.picture_as_pdf_outlined
        : Icons.insert_drive_file_outlined;
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Icon(icon, color: Colors.grey.shade700),
    );
  }
}

class _ExpandedImageReceiptTile extends StatelessWidget {
  final PurchaseReceipt receipt;
  final File? previewFile;
  final VoidCallback onOpen;
  final VoidCallback onEditMemo;
  final VoidCallback onDelete;
  final VoidCallback? onCollapse;

  const _ExpandedImageReceiptTile({
    required this.receipt,
    required this.previewFile,
    required this.onOpen,
    required this.onEditMemo,
    required this.onDelete,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final created = receipt.createdAt;
    final memo = receipt.memo?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${created.year}.${created.month}.${created.day}',
                        if (memo != null && memo.isNotEmpty) memo,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onCollapse,
                icon: const Icon(Icons.unfold_less),
                label: const Text('접기'),
              ),
              _ReceiptActionMenu(
                onOpen: onOpen,
                onEditMemo: onEditMemo,
                onDelete: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: previewFile == null
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('첨부파일을 찾을 수 없습니다.')),
                        )
                      : Image.file(
                          previewFile!,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('이미지를 열 수 없습니다.')),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptActionMenu extends StatelessWidget {
  final VoidCallback onOpen;
  final VoidCallback onEditMemo;
  final VoidCallback onDelete;

  const _ReceiptActionMenu({
    required this.onOpen,
    required this.onEditMemo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ReceiptAction>(
      tooltip: '첨부 메뉴',
      onSelected: (action) {
        switch (action) {
          case _ReceiptAction.open:
            onOpen();
            break;
          case _ReceiptAction.memo:
            onEditMemo();
            break;
          case _ReceiptAction.delete:
            onDelete();
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ReceiptAction.open,
          child: ListTile(
            leading: Icon(Icons.open_in_new),
            title: Text('보기'),
          ),
        ),
        PopupMenuItem(
          value: _ReceiptAction.memo,
          child: ListTile(
            leading: Icon(Icons.edit_note),
            title: Text('메모 수정'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _ReceiptAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('삭제'),
          ),
        ),
      ],
    );
  }
}

enum _ReceiptAction { open, memo, delete }

Widget _calcItem(String label, double value) {
  return Column(
    children: [
      Text(value.toStringAsFixed(0)),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    ],
  );
}

DateTime _endOfMonth([DateTime? base]) {
  final now = base ?? DateTime.now();
  return DateTime(now.year, now.month + 1, 0);
}
