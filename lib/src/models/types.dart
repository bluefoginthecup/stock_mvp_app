// lib/models/types.dart
// Shared enums for inventory and order flow. No external dependencies.

/// Reference source type for a transaction (what produced this stock movement).
enum RefType { order, work, purchase }

/// Transaction type: inbound (stock increases) or outbound (stock decreases).
enum TxnType { in_, out_ }

/// Production (work) status lifecycle.
enum WorkStatus { planned, inProgress, done, canceled }

/// Purchase status lifecycle.
enum PurchaseStatus { planned, ordered, received, canceled }
