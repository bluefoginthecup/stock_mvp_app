#!/usr/bin/env python3
import re, sys, json
from pathlib import Path

# 프로젝트 루트에서 실행
ROOT = Path(".")
LIB = ROOT / "lib"
MAP_PATH = ROOT / "scripts" / "l10n_replace_map.json"

# 정규식: Text("...") / '...' / labelText/hintText/tooltip/ SnackBar(content: Text("..."))
PATTERNS = [
    (re.compile(r'Text\(\s*"([^"]+)"\s*\)'), 'Text(context.t.{key})'),
    (re.compile(r"Text\(\s*'([^']+)'\s*\)"), 'Text(context.t.{key})'),
    (re.compile(r'(labelText|hintText|tooltip)\s*:\s*"([^"]+)"'), r'\1: context.t.{key}'),
    (re.compile(r"(labelText|hintText|tooltip)\s*:\s*'([^']+)'"), r'\1: context.t.{key}'),
    (re.compile(r'SnackBar\(\s*content:\s*Text\(\s*"([^"]+)"\s*\)\s*\)'), 'SnackBar(content: Text(context.t.{key}))'),
    (re.compile(r"SnackBar\(\s*content:\s*Text\(\s*'([^']+)'\s*\)\s*\)"), 'SnackBar(content: Text(context.t.{key}))'),
]

def load_map():
    if not MAP_PATH.exists():
        print(f"ERROR: mapping file not found: {MAP_PATH}")
        sys.exit(1)
    return json.loads(MAP_PATH.read_text(encoding="utf-8"))

def replace_in_text(text, mapping, dry=True):
    changed = False
    for rx, repl in PATTERNS:
        # 각 리터럴이 mapping에 있을 때만 치환
        def _sub(m):
            nonlocal changed
            literal = m.group(1) if 'Text(' in rx.pattern else m.group(2) if m.lastindex and m.lastindex >= 2 else m.group(1)
            key = mapping.get(literal)
            if not key:
                return m.group(0)
            changed = True
            return m.group(0).replace(m.group(1 if 'Text(' in rx.pattern else 2), f'context.t.{key}') if 'labelText' in rx.pattern or 'hintText' in rx.pattern or 'tooltip' in rx.pattern else repl.format(key=key)
        text = rx.sub(_sub, text)
    return text, changed

def main():
    mapping = load_map()  # {"대시보드": "dashboard_title", ...}
    dry = "--apply" not in sys.argv
    modified_files = 0
    for p in LIB.rglob("*.dart"):
        if "/l10n/" in str(p) or p.name.endswith(".g.dart"):
            continue
        src = p.read_text(encoding="utf-8", errors="ignore")
        new, changed = replace_in_text(src, mapping, dry=dry)
        if changed:
            modified_files += 1
            if dry:
                print(f"[DRY] would change: {p}")
            else:
                p.write_text(new, encoding="utf-8")
                print(f"[OK ] changed: {p}")
    if dry:
        print("\nRun with --apply to write changes.")
    print(f"Files touched: {modified_files}")

if __name__ == "__main__":
    main()
