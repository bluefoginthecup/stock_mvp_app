#!/usr/bin/env python3
import argparse
import csv
import datetime as dt
import json
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path


DEFAULT_MDB = Path("/Users/bluefog/Downloads/drmdb/DR.mdb")
LEGACY_FOLDER = "경영박사"
LEGACY_SUBFOLDER = "발주이관"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Import DR.mdb BALJU rows into the Chalstock SQLite DB."
    )
    parser.add_argument("--db", required=True, help="Path to stockapp.db")
    parser.add_argument("--mdb", default=str(DEFAULT_MDB), help="Path to DR.mdb")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    db_path = Path(args.db)
    mdb_path = Path(args.mdb)
    if not db_path.exists():
        print(f"DB not found: {db_path}", file=sys.stderr)
        return 66
    if not mdb_path.exists():
        print(f"MDB not found: {mdb_path}", file=sys.stderr)
        return 66

    with tempfile.TemporaryDirectory(prefix="dr-balju-import-") as tmp:
        tmp_dir = Path(tmp)
        balju_rows = export_table(mdb_path, "BALJU", tmp_dir)
        item_rows = export_table(mdb_path, "ITEM", tmp_dir)
        gurae_rows = export_table(mdb_path, "GURAE", tmp_dir)

    items_by_code = {as_int(row.get("CODE")): row for row in item_rows}
    suppliers_by_code = {as_int(row.get("CODE")): row for row in gurae_rows}
    orders = group_by_purchase_no(balju_rows)
    missing_items = sum(
        1 for row in balju_rows if as_int(row.get("ITEMCODE")) not in items_by_code
    )
    missing_suppliers = sum(
        1 for row in balju_rows if as_int(row.get("CUST")) not in suppliers_by_code
    )

    print(f"DR BALJU rows: {len(balju_rows)}")
    print(f"DR purchase orders: {len(orders)}")
    print(f"DR items: {len(item_rows)}")
    print(f"DR suppliers: {len(gurae_rows)}")
    print(f"Missing item joins: {missing_items}")
    print(f"Missing supplier joins: {missing_suppliers}")

    if args.dry_run:
        print("Dry run only. No DB changes were made.")
        return 0

    backup_path = backup_db(db_path)
    print(f"Backup created: {backup_path}")

    conn = sqlite3.connect(db_path)
    try:
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("BEGIN IMMEDIATE")
        ensure_legacy_folders(conn)
        upsert_legacy_items(conn, item_rows, suppliers_by_code)
        upsert_legacy_purchase_orders(conn, orders, items_by_code, suppliers_by_code)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    conn = sqlite3.connect(db_path)
    try:
        imported_items = conn.execute(
            "SELECT COUNT(*) FROM items WHERE id LIKE 'dr_item_%'"
        ).fetchone()[0]
        imported_orders = conn.execute(
            "SELECT COUNT(*) FROM purchase_orders WHERE id LIKE 'dr_po_%'"
        ).fetchone()[0]
        imported_lines = conn.execute(
            "SELECT COUNT(*) FROM purchase_lines WHERE id LIKE 'dr_balju_%'"
        ).fetchone()[0]
    finally:
        conn.close()

    print(f"Imported legacy items in app DB: {imported_items}")
    print(f"Imported legacy purchase orders in app DB: {imported_orders}")
    print(f"Imported legacy purchase lines in app DB: {imported_lines}")
    return 0


def export_table(mdb_path: Path, table: str, tmp_dir: Path) -> list[dict[str, str]]:
    result = subprocess.run(
        ["mdb-export", str(mdb_path), table],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"mdb-export {table} failed: {result.stderr}")
    csv_path = tmp_dir / f"{table}.csv"
    csv_path.write_text(result.stdout, encoding="utf-8")
    with csv_path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def group_by_purchase_no(rows: list[dict[str, str]]) -> dict[str, list[dict[str, str]]]:
    grouped: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        purchase_no = clean(row.get("BALJUNO"))
        if purchase_no:
            grouped.setdefault(purchase_no, []).append(row)
    return grouped


def backup_db(db_path: Path) -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%dT%H%M%S")
    backup_path = db_path.with_name(f"{db_path.name}.before_dr_balju_{stamp}")
    shutil.copy2(db_path, backup_path)
    for suffix in ("-wal", "-shm"):
        sidecar = Path(f"{db_path}{suffix}")
        if sidecar.exists():
            shutil.copy2(sidecar, Path(f"{backup_path}{suffix}"))
    return backup_path


def ensure_legacy_folders(conn: sqlite3.Connection) -> None:
    now = dt.datetime.now().isoformat()
    conn.execute(
        """
        INSERT OR IGNORE INTO folders
          (id, name, parent_id, depth, "order", search_normalized,
           search_initials, is_deleted)
        VALUES (?, ?, NULL, 1, 9000, ?, ?, 0)
        """,
        ("dr_folder_root", LEGACY_FOLDER, LEGACY_FOLDER, "ㄱㅇㅂㅅ"),
    )
    conn.execute(
        """
        INSERT OR IGNORE INTO folders
          (id, name, parent_id, depth, "order", search_normalized,
           search_initials, is_deleted)
        VALUES (?, ?, ?, 2, 0, ?, ?, 0)
        """,
        (
            "dr_folder_balju",
            LEGACY_SUBFOLDER,
            "dr_folder_root",
            LEGACY_SUBFOLDER,
            "ㅂㅈㅇㄱ",
        ),
    )
    conn.execute(
        """
        UPDATE folders
        SET is_deleted = 0, deleted_at = NULL, extra = COALESCE(extra, ?)
        WHERE id IN ('dr_folder_root', 'dr_folder_balju')
        """,
        (json.dumps({"source": "drmdb", "updatedAt": now}, ensure_ascii=False),),
    )


def upsert_legacy_items(
    conn: sqlite3.Connection,
    item_rows: list[dict[str, str]],
    suppliers_by_code: dict[int, dict[str, str]],
) -> None:
    sql = """
        INSERT INTO items
          (id, name, display_name, sku, unit, search_normalized,
           search_initials, search_full_normalized, folder, subfolder, subsubfolder,
           min_qty, qty, kind, attrs_json, unit_in, unit_out, conversion_rate,
           conversion_mode, stock_hints_json, supplier_name, default_supplier_id,
           default_supplier_uid, default_price, default_purchase_price,
           default_sale_price, reorder_interval_days, last_ordered_at,
           next_reorder_date, reorder_reminder_enabled,
           reorder_reminder_days_before, is_favorite, is_deleted, deleted_at, extra)
        VALUES
          (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL,
           0, 0, ?, ?, ?, ?, 1.0,
           'fixed', NULL, ?, NULL,
           ?, ?, ?, ?, NULL, NULL,
           NULL, 0,
           0, 0, 0, NULL, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          display_name = excluded.display_name,
          sku = excluded.sku,
          unit = excluded.unit,
          search_normalized = excluded.search_normalized,
          search_full_normalized = excluded.search_full_normalized,
          folder = excluded.folder,
          subfolder = excluded.subfolder,
          kind = excluded.kind,
          attrs_json = excluded.attrs_json,
          unit_in = excluded.unit_in,
          unit_out = excluded.unit_out,
          supplier_name = excluded.supplier_name,
          default_supplier_uid = excluded.default_supplier_uid,
          default_price = excluded.default_price,
          default_purchase_price = excluded.default_purchase_price,
          default_sale_price = excluded.default_sale_price,
          is_deleted = 0,
          deleted_at = NULL,
          extra = excluded.extra
    """
    path_sql = """
        INSERT INTO item_paths (item_id, l1_id, l2_id, l3_id)
        VALUES (?, 'dr_folder_root', 'dr_folder_balju', NULL)
        ON CONFLICT(item_id) DO UPDATE SET
          l1_id = excluded.l1_id,
          l2_id = excluded.l2_id,
          l3_id = excluded.l3_id
    """
    for row in item_rows:
        code = as_int(row.get("CODE"))
        if not code:
            continue
        name = clean(row.get("ITEM")) or f"경영박사 품목 {code}"
        spec = clean(row.get("GYU"))
        unit = clean(row.get("DANWI")) or "EA"
        supplier = suppliers_by_code.get(as_int(row.get("MAEIB_CUST")))
        supplier_name = clean(supplier.get("NAME")) if supplier else None
        supplier_name = supplier_name or None
        display_name = name if not spec else f"{name} / {spec}"
        attrs = {
            "source": "drmdb",
            "legacyTable": "ITEM",
            "legacyCode": code,
        }
        if clean(row.get("CODE2")):
            attrs["legacyCode2"] = clean(row.get("CODE2"))
        if spec:
            attrs["규격"] = spec
        if clean(row.get("BIGO")):
            attrs["비고"] = clean(row.get("BIGO"))
        if clean(row.get("BIGO2")):
            attrs["비고2"] = clean(row.get("BIGO2"))

        in_price = as_float(row.get("INPR"))
        out_price = as_float(row.get("OUTPR"))
        conn.execute(
            sql,
            (
                f"dr_item_{code}",
                name,
                display_name,
                clean(row.get("CODE2")) or f"DR-{code}",
                unit,
                display_name,
                "",
                display_name,
                LEGACY_FOLDER,
                LEGACY_SUBFOLDER,
                "raw",
                json.dumps(attrs, ensure_ascii=False),
                unit,
                unit,
                supplier_name,
                f"dr_supplier_{as_int(supplier.get('CODE'))}" if supplier else None,
                in_price or None,
                in_price or None,
                out_price or None,
                json.dumps({"source": "drmdb", "legacyCode": code}, ensure_ascii=False),
            ),
        )
        conn.execute(path_sql, (f"dr_item_{code}",))


def upsert_legacy_purchase_orders(
    conn: sqlite3.Connection,
    orders: dict[str, list[dict[str, str]]],
    items_by_code: dict[int, dict[str, str]],
    suppliers_by_code: dict[int, dict[str, str]],
) -> None:
    order_sql = """
        INSERT INTO purchase_orders
          (id, supplier_name, supplier_id, shipping_cost, extra_cost, vat,
           payment_status, paid_at, payment_due_at, vat_invoice_status,
           vat_invoice_issued_at, vat_invoice_due_at, vat_included, vat_type,
           eta, status, created_at, updated_at, is_deleted, memo,
           delivery_name, delivery_address, delivery_phone, delivery_memo,
           show_delivery_on_print, shipping_destination_id, buyer_profile_id,
           buyer_profile_name, buyer_business_number, buyer_company_name,
           buyer_representative, buyer_address, buyer_business_type,
           buyer_business_item, buyer_phone_fax, deleted_at, order_id, received_at)
        VALUES
          (?, ?, NULL, 0, 0, 0,
           'unpaid', NULL, NULL, 'pending',
           NULL, NULL, 0, 2,
           ?, 'received', ?, ?, 0, ?,
           NULL, NULL, NULL, NULL,
           0, NULL, NULL,
           NULL, NULL, NULL,
           NULL, NULL, NULL,
           NULL, NULL, NULL, NULL, ?)
        ON CONFLICT(id) DO UPDATE SET
          supplier_name = excluded.supplier_name,
          supplier_id = excluded.supplier_id,
          eta = excluded.eta,
          status = excluded.status,
          created_at = excluded.created_at,
          updated_at = excluded.updated_at,
          is_deleted = 0,
          memo = excluded.memo,
          received_at = excluded.received_at
    """
    delete_lines_sql = "DELETE FROM purchase_lines WHERE order_id = ? AND id LIKE 'dr_balju_%'"
    line_sql = """
        INSERT INTO purchase_lines
          (id, order_id, item_id, name, unit, qty, unit_price, vat_type,
           supply_amount, vat_amount, total_amount, amount_edited, note, memo,
           color_no, print_attrs_json, is_deleted, deleted_at)
        VALUES
          (?, ?, ?, ?, ?, ?, ?, 2,
           ?, 0, ?, 1, ?, ?, NULL, ?, 0, NULL)
        ON CONFLICT(id) DO UPDATE SET
          order_id = excluded.order_id,
          item_id = excluded.item_id,
          name = excluded.name,
          unit = excluded.unit,
          qty = excluded.qty,
          unit_price = excluded.unit_price,
          vat_type = excluded.vat_type,
          supply_amount = excluded.supply_amount,
          vat_amount = excluded.vat_amount,
          total_amount = excluded.total_amount,
          amount_edited = excluded.amount_edited,
          note = excluded.note,
          memo = excluded.memo,
          print_attrs_json = excluded.print_attrs_json,
          is_deleted = 0,
          deleted_at = NULL
    """
    for purchase_no, rows in orders.items():
        rows.sort(key=lambda row: as_int(row.get("AUTOKEY")))
        first = rows[0]
        supplier = suppliers_by_code.get(as_int(first.get("CUST")))
        supplier_name = clean(supplier.get("NAME")) if supplier else ""
        if not supplier_name:
            supplier_name = f"경영박사 거래처 {clean(first.get('CUST'))}"
        order_date = parse_legacy_date(clean(first.get("dDATE"))) or dt.datetime.now()
        eta = first_date(rows, ("DATE2", "NABDATE")) or order_date
        received_at = first_date(rows, ("NABDATE", "DATE2"))
        po_id = f"dr_po_{purchase_no}"
        memo = f"경영박사 발주번호: {purchase_no}"

        conn.execute(
            order_sql,
            (
                po_id,
                supplier_name,
                eta.isoformat(),
                order_date.isoformat(),
                dt.datetime.now().isoformat(),
                memo,
                received_at.isoformat() if received_at else None,
            ),
        )
        conn.execute(delete_lines_sql, (po_id,))

        for row in rows:
            legacy_item_code = as_int(row.get("ITEMCODE"))
            item = items_by_code.get(legacy_item_code)
            item_name = clean(item.get("ITEM")) if item else ""
            item_name = item_name or f"경영박사 품목 {legacy_item_code}"
            spec = clean(item.get("GYU")) if item else ""
            unit = clean(item.get("DANWI")) if item else ""
            unit = unit or "EA"
            qty = as_float(row.get("EA"))
            unit_price = as_float(row.get("PRICE"))
            amount = qty * unit_price
            attrs = [
                {
                    "key": "legacyPurchaseNo",
                    "label": "경영박사 발주번호",
                    "value": purchase_no,
                },
                {
                    "key": "legacyLineNo",
                    "label": "경영박사 라인번호",
                    "value": str(as_int(row.get("AUTOKEY"))),
                },
            ]
            if spec:
                attrs.append({"key": "spec", "label": "규격", "value": spec})
            conn.execute(
                line_sql,
                (
                    f"dr_balju_{as_int(row.get('AUTOKEY'))}",
                    po_id,
                    f"dr_item_{legacy_item_code}",
                    item_name if not spec else f"{item_name} / {spec}",
                    unit,
                    qty,
                    unit_price,
                    amount,
                    amount,
                    purchase_no,
                    clean(row.get("FOJANG")) or None,
                    json.dumps(attrs, ensure_ascii=False),
                ),
            )


def first_date(rows: list[dict[str, str]], keys: tuple[str, ...]) -> dt.datetime | None:
    for row in rows:
        for key in keys:
            parsed = parse_legacy_date(clean(row.get(key)))
            if parsed:
                return parsed
    return None


def parse_legacy_date(value: str) -> dt.datetime | None:
    parts = value.split(".")
    if len(parts) != 3 or not all(part.isdigit() for part in parts):
        return None
    year_part, month, day = (int(part) for part in parts)
    year = (
        year_part
        if year_part >= 1000
        else 1900 + year_part
        if year_part >= 70
        else 2000 + year_part
    )
    return dt.datetime(year, month, day)


def clean(value) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    return "" if text.lower() == "null" else text


def as_int(value) -> int:
    text = clean(value)
    if not text:
        return 0
    try:
        return round(float(text))
    except ValueError:
        return 0


def as_float(value) -> float:
    text = clean(value)
    if not text:
        return 0.0
    try:
        return float(text)
    except ValueError:
        return 0.0


if __name__ == "__main__":
    raise SystemExit(main())
