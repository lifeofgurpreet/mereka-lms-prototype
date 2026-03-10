#!/usr/bin/env python3
from datetime import date
from pathlib import Path

import yaml

MANIFEST = Path('docs/adr/manifest.yaml')
GLOSSARY = Path('docs/concepts/architecture/glossary.yaml')
ALLOWED_DOC_DOMAINS = ('https://docs.openedx.org', 'https://docs.tutor.edly.io')
ALLOWED_STATUSES = {'proposed', 'accepted', 'deprecated', 'superseded', 'deferred', 'rejected'}
ALLOWED_TYPES = {'foundation', 'domain', 'migration', 'exception'}

def parse_iso_date(value):
    if value in (None, ''):
        return None
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value))

def main():
    data = yaml.safe_load(MANIFEST.read_text(encoding='utf-8'))
    glossary = yaml.safe_load(GLOSSARY.read_text(encoding='utf-8'))
    allowed_governs = {
        token
        for tokens in (glossary.get('domains') or {}).values()
        for token in (tokens or [])
    }
    adrs = data.get('adrs', [])
    errors = []
    seen_ids = set()
    seen_paths = set()
    for adr in adrs:
        aid = adr.get('id')
        path = adr.get('path')
        if not aid or not path:
            errors.append('manifest entry missing id/path')
            continue
        if aid in seen_ids:
            errors.append(f'duplicate id: {aid}')
        seen_ids.add(aid)
        if path in seen_paths:
            errors.append(f'duplicate path: {path}')
        seen_paths.add(path)
        if not Path(path).exists():
            errors.append(f'missing file for {aid}: {path}')
    for dep_key in ('supersedes','amends','depends_on','read_next'):
        for adr in adrs:
            for target in adr.get(dep_key, []) or []:
                if target not in seen_ids:
                    errors.append(f"{adr.get('id')}: {dep_key} target not found: {target}")
    for adr in adrs:
        for ref in adr.get('related_tutor_docs', []) or []:
            if not any(ref.startswith(prefix) for prefix in ALLOWED_DOC_DOMAINS):
                errors.append(f"{adr.get('id')}: non-allowlisted Open edX/Tutor source `{ref}`")
    for adr in adrs:
        aid = adr.get('id', '')
        try:
            num = int(aid.split('-')[1])
        except Exception:
            errors.append(f'{aid}: invalid ADR id format')
            continue
        status = adr.get('decision_status')
        dtype = adr.get('decision_type')
        if status not in ALLOWED_STATUSES:
            errors.append(f'{aid}: invalid decision_status `{status}`')
        if dtype not in ALLOWED_TYPES:
            errors.append(f'{aid}: invalid decision_type `{dtype}`')
        created = reviewed = due = expiry = None
        try:
            created = parse_iso_date(adr.get('created'))
        except Exception:
            errors.append(f'{aid}: invalid created date `{adr.get("created")}`')
        try:
            reviewed = parse_iso_date(adr.get('last_reviewed'))
        except Exception:
            errors.append(f'{aid}: invalid last_reviewed date `{adr.get("last_reviewed")}`')
        try:
            due = parse_iso_date(adr.get('review_due'))
        except Exception:
            errors.append(f'{aid}: invalid review_due date `{adr.get("review_due")}`')
        try:
            expiry = parse_iso_date(adr.get('expiry_date'))
        except Exception:
            errors.append(f'{aid}: invalid expiry_date `{adr.get("expiry_date")}`')
        if created and reviewed and created > reviewed:
            errors.append(f'{aid}: created must be <= last_reviewed')
        if reviewed and due and reviewed > due:
            errors.append(f'{aid}: last_reviewed must be <= review_due')
        if num >= 28 and not adr.get('frontmatter_required', False):
            errors.append(f'{aid}: ADR-028+ must set frontmatter_required=true')
        if num >= 28 and not (adr.get('governs') or []):
            errors.append(f'{aid}: ADR-028+ must declare non-empty governs')
        if num >= 28:
            for governs_token in adr.get('governs') or []:
                if governs_token not in allowed_governs:
                    errors.append(f'{aid}: governs token not in glossary `{governs_token}`')
        if adr.get('frontmatter_required', False):
            title = str(adr.get('title', '')).strip()
            if not title or title == '---':
                errors.append(f'{aid}: frontmatter_required ADR must not use placeholder title')
            if not adr.get('owner'):
                errors.append(f'{aid}: frontmatter_required ADR must set owner')
            if not adr.get('last_reviewed'):
                errors.append(f'{aid}: frontmatter_required ADR must set last_reviewed')
            if not adr.get('review_due'):
                errors.append(f'{aid}: frontmatter_required ADR must set review_due')
        if dtype == 'foundation' and status == 'accepted' and not (adr.get('fitness_functions') or []):
            errors.append(f'{aid}: accepted foundation ADR must declare at least one fitness_function')
        if num >= 34 and dtype == 'domain' and status in ('proposed', 'accepted') and not (adr.get('fitness_functions') or []):
            errors.append(f'{aid}: ADR-034+ domain ADR must declare at least one fitness_function')
        if dtype == 'exception' and status == 'accepted':
            if not adr.get('expiry_date'):
                errors.append(f'{aid}: accepted exception ADR must set expiry_date')
            if not adr.get('removal_condition'):
                errors.append(f'{aid}: accepted exception ADR must set removal_condition')
            if reviewed and expiry and expiry <= reviewed:
                errors.append(f'{aid}: exception expiry_date must be after last_reviewed')
    if errors:
        print('ADR_MANIFEST_FAIL')
        for e in errors:
            print(f'- {e}')
        return 1
    print(f'ADR_MANIFEST_OK entries={len(adrs)}')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
