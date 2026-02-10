#!/usr/bin/env python3
"""
Add missing AC descriptions to testmaps by extracting from parent specs.

Usage:
    python add_ac_descriptions.py

Processes three testmaps:
- data-migrations-kajabi-mct_testmap.yaml
- slo-sla-service-level-management_testmap.yaml
- video-pipeline-delivery_testmap.yaml
"""

import re
import sys
from pathlib import Path
from typing import Dict

import yaml


def extract_ac_descriptions(spec_path: Path) -> Dict[str, str]:
    """
    Extract AC IDs and descriptions from a spec file.

    Returns dict of {ac_id: description}
    """
    ac_pattern = re.compile(r'- \[ \] (AC-\d+): (.+)')

    acs = {}
    content = spec_path.read_text()

    for match in ac_pattern.finditer(content):
        ac_id = match.group(1)
        description = match.group(2).strip()
        acs[ac_id] = description

    return acs


def add_descriptions_to_testmap(testmap_path: Path, spec_path: Path) -> int:
    """
    Add missing descriptions to testmap from spec.

    Returns count of descriptions added.
    """
    # Extract AC descriptions from spec
    ac_descriptions = extract_ac_descriptions(spec_path)

    print(f"\nProcessing {testmap_path.name}:")
    print(f"  Found {len(ac_descriptions)} ACs in spec")

    # Load testmap
    with open(testmap_path) as f:
        testmap = yaml.safe_load(f)

    # Add missing descriptions
    added_count = 0
    for ac in testmap.get('acceptance_criteria', []):
        ac_id = ac.get('id')
        if not ac_id:
            continue

        # Skip if already has description
        if 'description' in ac:
            continue

        # Add description from spec
        if ac_id in ac_descriptions:
            ac['description'] = ac_descriptions[ac_id]
            added_count += 1
            print(f"  ✓ Added description for {ac_id}")
        else:
            print(f"  ✗ Warning: {ac_id} not found in spec")

    # Write back with preserved formatting
    with open(testmap_path, 'w') as f:
        # Write header comment lines
        f.write(f"# Testmap: {testmap_path.stem.replace('_testmap', '').replace('-', ' ').title()}\n")
        f.write(f"# Source Spec: {testmap['spec']}\n")
        if testmap_path.name == "data-migrations-kajabi-mct_testmap.yaml":
            f.write("\n")
        else:
            f.write("# Generated: 2026-02-10\n\n")

        # Write YAML with preserved key order
        yaml.dump(
            testmap,
            f,
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
            width=120
        )

    print(f"  → Added {added_count} descriptions")
    return added_count


def main():
    """Main entry point."""
    repo_root = Path(__file__).parent.parent.parent.parent
    specs_dir = repo_root / "specs"
    testmaps_dir = specs_dir / "testmaps"

    # Files to process
    files = [
        ("data-migrations-kajabi-mct_spec.md", "data-migrations-kajabi-mct_testmap.yaml"),
        ("slo-sla-service-level-management_spec.md", "slo-sla-service-level-management_testmap.yaml"),
        ("video-pipeline-delivery_spec.md", "video-pipeline-delivery_testmap.yaml"),
    ]

    total_added = 0

    for spec_file, testmap_file in files:
        spec_path = specs_dir / spec_file
        testmap_path = testmaps_dir / testmap_file

        if not spec_path.exists():
            print(f"Error: Spec not found: {spec_path}")
            sys.exit(1)

        if not testmap_path.exists():
            print(f"Error: Testmap not found: {testmap_path}")
            sys.exit(1)

        added = add_descriptions_to_testmap(testmap_path, spec_path)
        total_added += added

    print(f"\n{'='*60}")
    print(f"Total descriptions added: {total_added}")
    print(f"{'='*60}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
