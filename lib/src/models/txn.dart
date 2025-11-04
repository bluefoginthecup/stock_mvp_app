// lib/models/txn.dart
// Transaction record model to track stock movements and their origins.
import 'types.dart';

class Txn {
  final String id;        // unique id
  final DateTime ts;      // timestamp (UTC recommended)
  final TxnType type;     // in_ (inbound) / out_ (outbound)
  final TxnStatus status;   // ★ planned / actual
  final String itemId;    // target item id
  final int qty;          // positive quantity
  final RefType refType;  // origin kind: order/work/purchase
  final String refId;     // origin id
  final String? note;
  final String? sourceKey; // optional memo

  final String? memo;

  const Txn({
    required this.id,
    required this.ts,
    required this.type,
    this.status = TxnStatus.actual, // ★ 기본값: actual (레거시 호환)
    required this.itemId,
    required this.qty,
    required this.refType,
    required this.refId,
    this.sourceKey,
    this.note,
    this.memo,
  }) : assert(qty > 0, 'qty must be > 0');

  Txn copyWith({
    String? id,
    DateTime? ts,
    TxnType? type,
    TxnStatus? status,
    String? itemId,
    int? qty,
    RefType? refType,
    String? refId,
    String? note,
    String? sourceKey,
    String? memo,
  }) {
    return Txn(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      type: type ?? this.type,
      status: status ?? this.status,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
      refType: refType ?? this.refType,
      refId: refId ?? this.refId,
      note: note ?? this.note,
      sourceKey: sourceKey ?? this.sourceKey,
      memo: memo ?? this.memo,
    );
  }

  // ── JSON (de)serialization ─────────────────────────────────────────────────

  factory Txn.fromJson(Map<String, dynamic> json) {
    return Txn(
      id: json['id'] as String,
      ts: DateTime.parse(json['ts'] as String),
      type: TxnType.values.firstWhere((e) => e.name == (json['type'] as String)),
        // ★ status 없던 예전 데이터는 actual로 기본값 처리 (레거시 호환)
              status: (json['status'] == null)
              ? TxnStatus.actual
              : TxnStatus.values.firstWhere((e) => e.name == (json['status'] as String)),

    itemId: json['itemId'] as String,
      qty: (json['qty'] as num).toInt(),
      refType: RefType.values.firstWhere((e) => e.name == (json['refType'] as String)),
      refId: json['refId'] as String,
      note: json['note'] as String?,
      memo: json['memo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts.toIso8601String(),
        'type': type.name,
    'status': status.name, // ★ 직렬화 추가
        'itemId': itemId,
        'qty': qty,
        'refType': refType.name,
        'refId': refId,
        'note': note,
    if (memo != null && memo!.isNotEmpty) 'memo': memo, // ✅ 추가
      };

  @override
  String toString() =>
      'Txn(id: $id, ts: ${ts.toIso8601String()}, type: ${type.name}, status: ${status.name}, itemId: $itemId, qty: $qty, ref: ${refType.name}/$refId)';

    // 편의 getter
    bool get isPlanned => status == TxnStatus.planned;
    bool get isActual  => status == TxnStatus.actual;
    bool get isIn      => type == TxnType.in_;
    bool get isOut     => type == TxnType.out_;
// class Txn { ... } 내부에 추가
  factory Txn.in_({
    required String id,
    required String itemId,
    required int qty,
    required RefType refType,
    required String refId,
    String? note,
    DateTime? ts,
    TxnStatus status = TxnStatus.actual, // ★ 기본값 actual
    String? memo,
    String? sourceKey,

  }) {
    return Txn(
      id: id,
      ts: ts ?? DateTime.now(),
      type: TxnType.in_,
      status: status,
      itemId: itemId,
      qty: qty,
      refType: refType,
      refId: refId,
      note: note,
      memo: memo,
      sourceKey: sourceKey,


    );
  }

  factory Txn.out_({
    required String id,
    required String itemId,
    required int qty,
    required RefType refType,
    required String refId,
    String? note,
    DateTime? ts,
    TxnStatus status = TxnStatus.actual, // ★ 기본값 actual
    String? memo,
    String? sourceKey,

  }) {
    return Txn(
      id: id,
      ts: ts ?? DateTime.now(),
      type: TxnType.out_,
      status: status,
      itemId: itemId,
      qty: qty,
      refType: refType,
      refId: refId,
      note: note,
      memo: memo,
      sourceKey: sourceKey,
    );
  }

}
