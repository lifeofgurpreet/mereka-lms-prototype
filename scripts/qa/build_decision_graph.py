#!/usr/bin/env python3
import json
from pathlib import Path

import yaml

manifest = yaml.safe_load(Path('docs/adr/manifest.yaml').read_text(encoding='utf-8'))
bundle_rules = yaml.safe_load(Path('docs/architecture/bundle-rules.yaml').read_text(encoding='utf-8'))
BANNER = '> Generated file. Do not hand-edit. Regenerate from the ADR source inputs.'
adrs = manifest.get('adrs', [])
accepted_adrs = [a for a in adrs if (a.get('decision_status') or '').lower() != 'proposed']
nodes = []
links = []
adr_by_id = {}
for a in adrs:
    adr_by_id[a['id']] = a
    nodes.append({'id': a['id'], 'type': a.get('decision_type', 'domain'), 'status': a.get('decision_status', 'accepted')})
    for k in ('depends_on','supersedes','amends','read_next'):
        for tgt in a.get(k, []) or []:
            links.append({'source': a['id'], 'target': tgt, 'kind': k})

out_json = Path('generated/graphs/adr-graph.json')
out_json.parent.mkdir(parents=True, exist_ok=True)
out_json.write_text(json.dumps({'nodes': nodes, 'links': links}, indent=2) + '\n', encoding='utf-8')

lines = ['# Decision Map', '', BANNER, '', '```mermaid', 'graph LR']
for link in links:
    lines.append(f"  {link['source']} -->|{link['kind']}| {link['target']}")
if not links:
    lines.append('  ADR028 --> ADR029')
lines.append('```')
Path('generated/decision-maps/adr-decision-map.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')

bundles_dir = Path('generated/adr-bundles')
bundles_dir.mkdir(parents=True, exist_ok=True)

for bundle in bundle_rules.get('bundles', []):
    bundle_id = bundle['id']
    bundle_file = f"{bundle_id}.md"
    title = f"{bundle.get('title', bundle_id)} Bundle"
    include_tokens = set(bundle.get('include_tokens') or [])
    selected = [
        a for a in accepted_adrs
        if a.get('decision_type') == 'foundation' and bundle_id == '00-foundations'
        or bool(set(a.get('governs') or []) & include_tokens)
    ]
    ordered = sorted(selected, key=lambda x: x['id'])
    lines = [f'# {title}', '', BANNER, '', 'This file is generated from `docs/adr/manifest.yaml`.', '']
    if not ordered:
        lines.extend(['No ADRs currently matched this bundle rule.', ''])
    else:
        lines.extend(['## ADRs', ''])
        for a in ordered:
            path = a.get('path', '')
            governs = ', '.join(a.get('governs') or []) or 'n/a'
            lines.append(f"- `{a['id']}` [{a.get('title', a['id'])}](../../{path})")
            lines.append(f"  - Governs: `{governs}`")
    (bundles_dir / bundle_file).write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f'ADR_GRAPH_OK nodes={len(nodes)} links={len(links)}')
