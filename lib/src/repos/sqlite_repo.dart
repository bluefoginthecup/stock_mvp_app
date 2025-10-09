// Optional: switch to this repo when you are ready to use sqflite.
// Keep as a stub for now so app compiles without extra deps.
/*
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/item.dart';
import '../models/order.dart';
import '../models/txn.dart';
import '../models/bom.dart';
import 'repo_interfaces.dart';

class SqliteRepo implements ItemRepo, OrderRepo, TxnRepo, BomRepo {
  Database? _db;

  Future<void> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'stockapp.db');
    _db = await openDatabase(dbPath, version: 1, onCreate: (db, v) async {
      // Execute schema.sql content programmatically if not using assets.
    });
  }

  // TODO: Implement all methods mapping to tables.
}
*/
