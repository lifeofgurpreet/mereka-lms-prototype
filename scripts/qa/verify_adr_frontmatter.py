#!/usr/bin/env python3
from pathlib import Path

import yaml

MANIFEST = Path('docs/adr/manifest.yaml')
REQUIRED = [
    'id','title','decision_status','decision_type','rollout_state','owner','created','last_reviewed','review_due',
    'supersedes','amends','depends_on','read_next','governs','does_not_govern','related_oep','related_tutor_docs',
    'related_specs','related_runbooks','related_evidence','fitness_functions','expiry_date','removal_condition'
]

def parse_frontmatter(path: Path):
    text = path.read_text(encoding='utf-8', errors='ignore')
    if not text.startswith('---\n'):
        return None
    parts = text.split('\n---\n', 1)
    if len(parts) != 2:
        return None
    try:
        return yaml.safe_load(parts[0][4:]) or {}
    except Exception:
        return None


def main():
    data = yaml.safe_load(MANIFEST.read_text(encoding='utf-8'))
    errors = []
    checked = 0
    for adr in data.get('adrs', []):
        if not adr.get('frontmatter_required', False):
            continue
        checked += 1
        p = Path(adr['path'])
        fm = parse_frontmatter(p)
        if fm is None:
            errors.append(f'{p}: missing or invalid YAML frontmatter')
            continue
        for key in REQUIRED:
            if key not in fm:
                errors.append(f'{p}: missing frontmatter key `{key}`')
        if fm.get('id') != adr.get('id'):
            errors.append(f'{p}: id mismatch (frontmatter={fm.get("id")}, manifest={adr.get("id")})')
    if errors:
        print('ADR_FRONTMATTER_FAIL')
        for e in errors:
            print(f'- {e}')
        return 1
    print(f'ADR_FRONTMATTER_OK checked={checked}')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
