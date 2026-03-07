#!/usr/bin/env python3
from pathlib import Path
import json
import yaml
from collections import defaultdict

manifest = yaml.safe_load(Path('docs/adr/manifest.yaml').read_text(encoding='utf-8'))
adrs = manifest.get('adrs', [])
nodes = []
links = []
adr_by_id = {}
for a in adrs:
    adr_by_id[a['id']] = a
    nodes.append({'id': a['id'], 'type': a.get('decision_type', 'domain'), 'status': a.get('decision_status', 'accepted')})
    for k in ('depends_on','supersedes','amends','read_next'):
        for tgt in a.get(k, []) or []:
            links.append({'source': a['id'], 'target': tgt, 'kind': k})

out_json = Path('docs/adr/_generated/graph.json')
out_json.parent.mkdir(parents=True, exist_ok=True)
out_json.write_text(json.dumps({'nodes': nodes, 'links': links}, indent=2) + '\n', encoding='utf-8')

lines = ['# Decision Map', '', '```mermaid', 'graph LR']
for l in links:
    lines.append(f"  {l['source']} -->|{l['kind']}| {l['target']}")
if not links:
    lines.append('  ADR028 --> ADR029')
lines.append('```')
Path('docs/adr/_generated/decision-map.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')

bundles_dir = Path('docs/adr/_generated/bundles')
bundles_dir.mkdir(parents=True, exist_ok=True)

bundle_defs = [
    ('00-foundations.md', 'Foundations Bundle', lambda a: a.get('decision_type') == 'foundation'),
    (
        '10-auth-and-tenancy.md',
        'Auth and Tenancy Bundle',
        lambda a: any(k in ' '.join((a.get('governs') or [])).lower() for k in ('auth', 'session', 'tenant', 'domain-boundary', 'oidc')),
    ),
    (
        '20-build-and-release.md',
        'Build and Release Bundle',
        lambda a: any(k in ' '.join((a.get('governs') or [])).lower() for k in ('build', 'release', 'deploy', 'gitops', 'control-plane')),
    ),
    (
        '30-frontend.md',
        'Frontend Bundle',
        lambda a: any(k in ' '.join((a.get('governs') or [])).lower() for k in ('frontend', 'mfe', 'branding', 'runtime-composition')),
    ),
    (
        '40-data-and-events.md',
        'Data and Events Bundle',
        lambda a: any(k in ' '.join((a.get('governs') or [])).lower() for k in ('data', 'pii', 'event', 'cache', 'async')),
    ),
    (
        '50-commerce.md',
        'Commerce Bundle',
        lambda a: any(k in ' '.join((a.get('governs') or [])).lower() for k in ('commerce', 'purchase', 'payment', 'reconciliation')),
    ),
]

for bundle_file, title, matcher in bundle_defs:
    selected = [a for a in adrs if matcher(a)]
    ordered = sorted(selected, key=lambda x: x['id'])
    lines = [f'# {title}', '', 'This file is generated from `docs/adr/manifest.yaml`.', '']
    if not ordered:
        lines.extend(['No ADRs currently matched this bundle rule.', ''])
    else:
        lines.extend(['## ADRs', ''])
        for a in ordered:
            path = a.get('path', '')
            governs = ', '.join(a.get('governs') or []) or 'n/a'
            lines.append(f"- `{a['id']}` [{a.get('title', a['id'])}](../../{path.replace('docs/adr/', '')})")
            lines.append(f"  - Governs: `{governs}`")
    (bundles_dir / bundle_file).write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f'ADR_GRAPH_OK nodes={len(nodes)} links={len(links)}')
