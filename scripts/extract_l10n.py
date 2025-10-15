#!/usr/bin/env python3
# See contents earlier – tool to scan lib/ and emit ARB/CSV of hardcoded strings.
# (full docstring and implementation included)

import os, re, sys, csv, hashlib, json
from pathlib import Path

UI_PATTERNS = [
    r'Text\s*\(\s*("|\')(?P<txt>[^"\']+)\1',
    r'labelText\s*:\s*("|\')(?P<txt>[^"\']+)\1',
    r'hintText\s*:\s*("|\')(?P<txt>[^"\']+)\1',
    r'tooltip\s*:\s*("|\')(?P<txt>[^"\']+)\1',
    r'SnackBar\s*\(\s*content:\s*Text\s*\(\s*("|\')(?P<txt>[^"\']+)\1',
    r'AlertDialog\s*\(.*?title:\s*Text\s*\(\s*("|\')(?P<txt>[^"\']+)\1',
    r'AlertDialog\s*\(.*?content:\s*Text\s*\(\s*("|\')(?P<txt>[^"\']+)\1',
]
COMPILED = [re.compile(p, re.DOTALL) for p in UI_PATTERNS]

def slug(s, maxlen=32):
    import unicodedata
    t = ''.join(ch if ch.isalnum() or ch in ' _-' else '_' for ch in s.strip())
    t = '_'.join(t.split())
    t = t.lower().strip('_')
    if not t: t = 'txt'
    if len(t) > maxlen: t = t[:maxlen]
    return t

def key_for(path_rel, txt):
    base = Path(path_rel).with_suffix('').name
    prefix = '_'.join(Path(path_rel).parts[-3:])
    s = slug(txt)
    h = hashlib.md5(txt.encode('utf-8')).hexdigest()[:6]
    key = f"{prefix}_{base}_{s}_{h}".lower()
    key = re.sub(r'[^a-z0-9_]+', '_', key)
    key = re.sub(r'__+', '_', key).strip('_')
    return key

def is_l10n_call(line):
    return ('.t.' in line) or ('L10n.of(' in line)

def main():
    proj = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.')
    lib = proj / 'lib'
    if not lib.exists():
        print("ERROR: lib/ not found. Run from project root or pass path.")
        sys.exit(1)

    outdir = proj / 'build'
    outdir.mkdir(exist_ok=True)

    rows = []
    arb = {}
    for p in lib.rglob('*.dart'):
        rel = p.relative_to(proj).as_posix()
        text = p.read_text(encoding='utf-8', errors='ignore')
        if 'generated' in rel or '/l10n/' in rel:
            continue
        for i, line in enumerate(text.splitlines(), start=1):
            if is_l10n_call(line):  # already localized
                continue
            for pat in COMPILED:
                for m in pat.finditer(line):
                    txt = m.group('txt').strip()
                    if len(txt) < 2: continue
                    if txt.startswith('http') or txt.startswith('package:'): continue
                    k = key_for(rel, txt)
                    if k not in arb:
                        arb[k] = txt
                        rows.append([rel, i, k, txt])

    with (outdir / 'app_l10n_review.csv').open('w', newline='', encoding='utf-8') as f:
        w = csv.writer(f); w.writerow(['file','line','key','text']); w.writerows(rows)
    with (outdir / 'app_l10n_todo.arb').open('w', encoding='utf-8') as f:
        json.dump(arb, f, ensure_ascii=False, indent=2)
    print(f"Wrote {len(rows)} entries\\n- build/app_l10n_review.csv\\n- build/app_l10n_todo.arb")

if __name__ == '__main__':
    main()
