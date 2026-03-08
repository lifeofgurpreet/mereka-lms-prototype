#!/usr/bin/env python3
import re
from pathlib import Path

ADR_DIR = Path('docs/adr')
link_re = re.compile(r'\[[^\]]+\]\(([^)]+)\)')

def resolve(base: Path, target: str) -> Path:
    target = target.split('#', 1)[0]
    if target.startswith('http://') or target.startswith('https://') or target.startswith('mailto:'):
        return None
    p = (base.parent / target).resolve() if not target.startswith('/') else Path(target)
    return p


def main():
    errors = []
    checked = 0
    for p in sorted(ADR_DIR.glob('*.md')):
        if p.name == 'README.md':
            continue
        txt = p.read_text(encoding='utf-8', errors='ignore')
        checked += 1
        for m in link_re.finditer(txt):
            raw = m.group(1).strip()
            rp = resolve(p, raw)
            if rp is None:
                continue
            if not rp.exists():
                errors.append(f'{p}:{raw}')
    if errors:
        print('ADR_LINKS_FAIL')
        for e in errors:
            print(f'- {e}')
        return 1
    print(f'ADR_LINKS_OK files={checked}')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
