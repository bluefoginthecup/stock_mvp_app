-- Core tables for SQLite version (future switch)
CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  sku TEXT NOT NULL,
  unit TEXT NOT NULL,
  folder TEXT NOT NULL,
  subfolder TEXT,
  min_qty INTEGER NOT NULL DEFAULT 0,
  qty INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  customer TEXT NOT NULL,
  memo TEXT,
  status TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS order_lines (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  item_id TEXT NOT NULL REFERENCES items(id),
  qty INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS bom (
  id TEXT PRIMARY KEY,
  parent_item_id TEXT NOT NULL REFERENCES items(id),
  material_item_id TEXT NOT NULL REFERENCES items(id),
  qty_per REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS txns (
  id TEXT PRIMARY KEY,
  ts TEXT NOT NULL,
  type TEXT NOT NULL, -- INBOUND / OUTBOUND / ADJUST
  item_id TEXT NOT NULL REFERENCES items(id),
  qty INTEGER NOT NULL,
  ref_type TEXT,
  ref_id TEXT,
  note TEXT
);

CREATE INDEX IF NOT EXISTS idx_items_folder ON items(folder);
CREATE INDEX IF NOT EXISTS idx_txns_item ON txns(item_id);
