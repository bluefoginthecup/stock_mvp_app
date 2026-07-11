#!/usr/bin/env python3
"""Create a Chalstock import ZIP from a Doctor/경영박사 DR.mdb file.

This is the converter-side tool for the recommended Windows .exe path.
It does not modify the Chalstock app database. It only reads DR.mdb and writes
chalstock_dr_import.zip, which the app can import after preview.
"""

import argparse
import csv
import datetime as dt
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


IMPORT_FORMAT = "chalstock.dr_mdb.v1"
DEFAULT_OUTPUT_NAME = "chalstock_dr_import.zip"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert 경영박사 DR.mdb into a Chalstock import ZIP."
    )
    parser.add_argument("--mdb", required=True, help="Path to DR.mdb")
    parser.add_argument(
        "--out",
        default=DEFAULT_OUTPUT_NAME,
        help=f"Output ZIP path. Defaults to {DEFAULT_OUTPUT_NAME}",
    )
    args = parser.parse_args()

    mdb_path = Path(args.mdb)
    out_path = Path(args.out)
    if not mdb_path.exists():
        print(f"DR.mdb not found: {mdb_path}", file=sys.stderr)
        return 66

    raw = read_dr_tables(mdb_path)
    package = build_import_package(raw)
    write_import_zip(out_path, package)

    manifest = package["manifest"]
    print(f"Output: {out_path.resolve()}")
    print(f"Items: {manifest['counts']['items']}")
    print(f"Suppliers: {manifest['counts']['suppliers']}")
    print(f"Purchase orders: {manifest['counts']['purchaseOrders']}")
    print(f"Purchase lines: {manifest['counts']['purchaseLines']}")
    print(f"Missing item joins: {manifest['validation']['missingItemJoins']}")
    print(f"Missing supplier joins: {manifest['validation']['missingSupplierJoins']}")
    return 0


def read_dr_tables(mdb_path: Path) -> dict[str, list[dict[str, str]]]:
    if shutil.which("mdb-export"):
        return {
            "BALJU": export_table_with_mdbtools(mdb_path, "BALJU"),
            "ITEM": export_table_with_mdbtools(mdb_path, "ITEM"),
            "GURAE": export_table_with_mdbtools(mdb_path, "GURAE"),
        }

    if os.name == "nt":
        return read_tables_with_pyodbc(mdb_path)

    raise RuntimeError(
        "No MDB reader found. Install mdbtools, or run on Windows with "
        "Microsoft Access Database Engine and pyodbc bundled."
    )


def export_table_with_mdbtools(mdb_path: Path, table: str) -> list[dict[str, str]]:
    result = subprocess.run(
        ["mdb-export", str(mdb_path), table],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"mdb-export {table} failed: {result.stderr}")
    return list(csv.DictReader(io.StringIO(result.stdout)))


def read_tables_with_pyodbc(mdb_path: Path) -> dict[str, list[dict[str, str]]]:
    try:
        import pyodbc  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "pyodbc is required on Windows when mdbtools is not bundled."
        ) from exc

    candidates = [
        "Microsoft Access Driver (*.mdb, *.accdb)",
        "Microsoft Access Driver (*.mdb)",
    ]
    last_error: Exception | None = None
    for driver in candidates:
        conn_str = f"DRIVER={{{driver}}};DBQ={mdb_path};"
        try:
            with pyodbc.connect(conn_str, autocommit=True) as conn:
                return {
                    "BALJU": read_table_with_odbc(conn, "BALJU"),
                    "ITEM": read_table_with_odbc(conn, "ITEM"),
                    "GURAE": read_table_with_odbc(conn, "GURAE"),
                }
        except Exception as exc:  # pragma: no cover - Windows runtime path
            last_error = exc
    raise RuntimeError(
        "Could not open DR.mdb. Install Microsoft Access Database Engine "
        "2016 Redistributable, then retry."
    ) from last_error


def read_table_with_odbc(conn, table: str) -> list[dict[str, str]]:
    cursor = conn.cursor()
    cursor.execute(f"SELECT * FROM [{table}]")
    columns = [column[0] for column in cursor.description]
    result: list[dict[str, str]] = []
    for row in cursor.fetchall():
        result.append(
            {
                columns[index]: "" if value is None else str(value)
                for index, value in enumerate(row)
            }
        )
    return result


def build_import_package(raw: dict[str, list[dict[str, str]]]) -> dict[str, object]:
    balju_rows = raw["BALJU"]
    item_rows = raw["ITEM"]
    gurae_rows = raw["GURAE"]
    items_by_code = {as_int(row.get("CODE")): row for row in item_rows}
    suppliers_by_code = {as_int(row.get("CODE")): row for row in gurae_rows}
    grouped = group_by_purchase_no(balju_rows)

    items = normalize_items(item_rows, suppliers_by_code)
    suppliers = normalize_suppliers(gurae_rows)
    purchase_orders = normalize_purchase_orders(grouped, suppliers_by_code)
    purchase_lines = normalize_purchase_lines(grouped, items_by_code)

    missing_items = sum(
        1 for row in balju_rows if as_int(row.get("ITEMCODE")) not in items_by_code
    )
    missing_suppliers = sum(
        1 for row in balju_rows if as_int(row.get("CUST")) not in suppliers_by_code
    )
    now = dt.datetime.now().isoformat(timespec="seconds")
    manifest = {
        "format": IMPORT_FORMAT,
        "formatVersion": 1,
        "createdAt": now,
        "source": {
            "system": "경영박사",
            "database": "DR.mdb",
            "tables": ["BALJU", "ITEM", "GURAE"],
        },
        "importPolicy": {
            "stockQtyPolicy": "zero",
            "createInventoryTransactions": False,
            "purchaseStatus": "received",
            "idPrefix": "dr_",
        },
        "files": {
            "items": "items.csv",
            "suppliers": "suppliers.csv",
            "purchaseOrders": "purchase_orders.csv",
            "purchaseLines": "purchase_lines.csv",
        },
        "counts": {
            "items": len(items),
            "suppliers": len(suppliers),
            "purchaseOrders": len(purchase_orders),
            "purchaseLines": len(purchase_lines),
        },
        "validation": {
            "missingItemJoins": missing_items,
            "missingSupplierJoins": missing_suppliers,
        },
    }
    return {
        "manifest": manifest,
        "items": items,
        "suppliers": suppliers,
        "purchase_orders": purchase_orders,
        "purchase_lines": purchase_lines,
    }


def normalize_suppliers(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for row in rows:
        code = as_int(row.get("CODE"))
        if not code:
            continue
        result.append(
            {
                "supplier_id": f"dr_supplier_{code}",
                "legacy_code": code,
                "name": clean(row.get("NAME")) or f"경영박사 거래처 {code}",
                "contact_name": clean(row.get("MAN")),
                "phone": clean(row.get("TEL")),
                "fax": clean(row.get("FAX")),
                "address": clean(row.get("JUSO")),
                "memo": clean(row.get("BIGO1")),
            }
        )
    return result


def normalize_items(
    rows: list[dict[str, str]],
    suppliers_by_code: dict[int, dict[str, str]],
) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for row in rows:
        code = as_int(row.get("CODE"))
        if not code:
            continue
        name = clean(row.get("ITEM")) or f"경영박사 품목 {code}"
        spec = clean(row.get("GYU"))
        unit = clean(row.get("DANWI")) or "EA"
        supplier = suppliers_by_code.get(as_int(row.get("MAEIB_CUST")))
        result.append(
            {
                "item_id": f"dr_item_{code}",
                "legacy_code": code,
                "legacy_code2": clean(row.get("CODE2")),
                "name": name,
                "display_name": name if not spec else f"{name} / {spec}",
                "spec": spec,
                "unit": unit,
                "folder": "경영박사",
                "subfolder": "발주이관",
                "kind": "raw",
                "qty": 0,
                "supplier_id": f"dr_supplier_{as_int(supplier.get('CODE'))}"
                if supplier
                else "",
                "supplier_name": clean(supplier.get("NAME")) if supplier else "",
                "default_purchase_price": as_float(row.get("INPR")) or "",
                "default_sale_price": as_float(row.get("OUTPR")) or "",
                "memo": clean(row.get("BIGO")),
                "memo2": clean(row.get("BIGO2")),
            }
        )
    return result


def normalize_purchase_orders(
    grouped: dict[str, list[dict[str, str]]],
    suppliers_by_code: dict[int, dict[str, str]],
) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for purchase_no, rows in sorted(grouped.items()):
        rows.sort(key=lambda row: as_int(row.get("AUTOKEY")))
        first = rows[0]
        supplier = suppliers_by_code.get(as_int(first.get("CUST")))
        supplier_name = clean(supplier.get("NAME")) if supplier else ""
        if not supplier_name:
            supplier_name = f"경영박사 거래처 {clean(first.get('CUST'))}"
        order_date = first_date(rows, ("dDATE",)) or dt.datetime.now()
        eta = first_date(rows, ("DATE2", "NABDATE")) or order_date
        received_at = first_date(rows, ("NABDATE", "DATE2"))
        result.append(
            {
                "purchase_order_id": f"dr_po_{purchase_no}",
                "purchase_no": purchase_no,
                "supplier_id": f"dr_supplier_{as_int(supplier.get('CODE'))}"
                if supplier
                else "",
                "supplier_name": supplier_name,
                "order_date": order_date.date().isoformat(),
                "eta": eta.date().isoformat(),
                "received_at": received_at.date().isoformat() if received_at else "",
                "status": "received",
                "memo": f"경영박사 발주번호: {purchase_no}",
            }
        )
    return result


def normalize_purchase_lines(
    grouped: dict[str, list[dict[str, str]]],
    items_by_code: dict[int, dict[str, str]],
) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for purchase_no, rows in sorted(grouped.items()):
        rows.sort(key=lambda row: as_int(row.get("AUTOKEY")))
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
            result.append(
                {
                    "purchase_line_id": f"dr_balju_{as_int(row.get('AUTOKEY'))}",
                    "purchase_order_id": f"dr_po_{purchase_no}",
                    "purchase_no": purchase_no,
                    "legacy_line_no": as_int(row.get("AUTOKEY")),
                    "item_id": f"dr_item_{legacy_item_code}",
                    "legacy_item_code": legacy_item_code,
                    "name": item_name if not spec else f"{item_name} / {spec}",
                    "spec": spec,
                    "unit": unit,
                    "qty": qty,
                    "unit_price": unit_price,
                    "supply_amount": qty * unit_price,
                    "vat_amount": 0,
                    "total_amount": qty * unit_price,
                    "memo": clean(row.get("FOJANG")),
                }
            )
    return result


def write_import_zip(out_path: Path, package: dict[str, object]) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="chalstock-dr-import-") as tmp:
        tmp_dir = Path(tmp)
        write_json(tmp_dir / "manifest.json", package["manifest"])
        write_csv(tmp_dir / "items.csv", package["items"])
        write_csv(tmp_dir / "suppliers.csv", package["suppliers"])
        write_csv(tmp_dir / "purchase_orders.csv", package["purchase_orders"])
        write_csv(tmp_dir / "purchase_lines.csv", package["purchase_lines"])

        with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for file_name in (
                "manifest.json",
                "items.csv",
                "suppliers.csv",
                "purchase_orders.csv",
                "purchase_lines.csv",
            ):
                zf.write(tmp_dir / file_name, file_name)


def write_json(path: Path, payload: object) -> None:
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def write_csv(path: Path, rows: object) -> None:
    typed_rows = rows if isinstance(rows, list) else []
    if not typed_rows:
        path.write_text("", encoding="utf-8")
        return
    headers = list(typed_rows[0].keys())
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(typed_rows)


def group_by_purchase_no(rows: list[dict[str, str]]) -> dict[str, list[dict[str, str]]]:
    grouped: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        purchase_no = clean(row.get("BALJUNO"))
        if purchase_no:
            grouped.setdefault(purchase_no, []).append(row)
    return grouped


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
    yy, month, day = (int(part) for part in parts)
    year = 1900 + yy if yy >= 70 else 2000 + yy
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
