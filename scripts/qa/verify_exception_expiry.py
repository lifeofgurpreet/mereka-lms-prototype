#!/usr/bin/env python3
from datetime import date
from pathlib import Path

import yaml

MANIFEST = Path('docs/adr/manifest.yaml')


def main():
    data = yaml.safe_load(MANIFEST.read_text(encoding='utf-8'))
    errors = []
    warns = []
    today = date.today()
    for adr in data.get('adrs', []):
        if adr.get('decision_type') != 'exception':
            continue
        aid = adr.get('id')
        expiry = adr.get('expiry_date')
        removal = adr.get('removal_condition')
        if not expiry:
            errors.append(f'{aid}: missing expiry_date')
            continue
        if not removal:
            errors.append(f'{aid}: missing removal_condition')
        try:
            exp = date.fromisoformat(str(expiry))
        except Exception:
            errors.append(f'{aid}: invalid expiry_date `{expiry}`')
            continue
        if exp < today:
            errors.append(f'{aid}: expired on {exp}')
        elif (exp - today).days <= 30:
            warns.append(f'{aid}: expiry within 30 days ({exp})')
    if errors:
        print('ADR_EXCEPTION_EXPIRY_FAIL')
        for e in errors:
            print(f'- {e}')
        return 1
    for w in warns:
        print(f'WARN: {w}')
    print('ADR_EXCEPTION_EXPIRY_OK')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
