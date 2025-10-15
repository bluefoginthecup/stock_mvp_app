#!/usr/bin/env python3
import sys, re, subprocess, pathlib
PAT = re.compile(r'(Text\(|labelText:|hintText:|tooltip:).+("([^"]{2,})")')
ALLOW = 'l10n:ignore'
def main():
    res = subprocess.run(['git','diff','--cached','--name-only'], capture_output=True, text=True)
    files = [f for f in res.stdout.splitlines() if f.endswith('.dart') and '/l10n/' not in f]
    bad = []
    for f in files:
        text = pathlib.Path(f).read_text(encoding='utf-8', errors='ignore')
        for i, line in enumerate(text.splitlines(), 1):
            if 'L10n.of(' in line or '.t.' in line: 
                continue
            m = PAT.search(line)
            if m and ALLOW not in line:
                bad.append((f,i,line.strip()))
    if bad:
        print('❌ i18n check failed: hardcoded strings detected.\\n')
        for f,i,line in bad[:100]:
            print(f'{f}:{i}: {line}')
        print('\\nAdd // l10n:ignore to suppress a specific line.')
        sys.exit(1)
    print('✅ i18n check passed.')
if __name__ == '__main__':
    sys.exit(main())
