#!/usr/bin/env bash
set -euo pipefail

# Load test for Content Libraries v2 (AC-LIB-020)
# AC-NEG-LIB-010: Uses SYNTHETIC libraries only — never production data

LIBRARIES=${1:-500}
COMPONENTS_PER_LIB=${2:-100}
TOTAL_COMPONENTS=$((LIBRARIES * COMPONENTS_PER_LIB))

echo "=== Libraries Load Test ==="
echo "Libraries: $LIBRARIES"
echo "Components per library: $COMPONENTS_PER_LIB"
echo "Total components: $TOTAL_COMPONENTS"
echo ""
echo "⚠ AC-NEG-LIB-010: Synthetic data only — NOT production"
echo ""

# Generate Python script to create synthetic data
cat << PYEOF
# Run inside Django shell:
# python manage.py lms shell < load-test-libraries.py

import time
import uuid
from openedx_content_libraries.models import LibraryMetadata, LibraryComponent

LIBRARIES = $LIBRARIES
COMPONENTS_PER_LIB = $COMPONENTS_PER_LIB
PREFIX = "loadtest-"

print(f"Creating {LIBRARIES} synthetic libraries with {COMPONENTS_PER_LIB} components each...")

start = time.monotonic()

for i in range(LIBRARIES):
    lib_key = f"lib:LoadTest:synthetic-{i:04d}"
    lib, _ = LibraryMetadata.objects.get_or_create(
        library_key=lib_key,
        defaults={
            'org': 'LoadTest',
            'title': f'Synthetic Library {i:04d}',
            'description': f'Load test library {i} — python basics, math, science topics',
        },
    )

    for j in range(COMPONENTS_PER_LIB):
        usage_key = f"lb:{lib_key}:component+type@html+block@{PREFIX}{j:05d}"
        LibraryComponent.objects.get_or_create(
            usage_key=usage_key,
            defaults={
                'library': lib,
                'block_type': 'html',
                'display_name': f'Component {j} - python basics topic {j % 50}',
                'has_unpublished_changes': False,
            },
        )

    if (i + 1) % 50 == 0:
        elapsed = time.monotonic() - start
        print(f"  Created {i + 1}/{LIBRARIES} libraries ({elapsed:.1f}s)")

elapsed = time.monotonic() - start
total = LibraryMetadata.objects.filter(org='LoadTest').count()
comps = LibraryComponent.objects.filter(library__org='LoadTest').count()
print(f"\nDone: {total} libraries, {comps} components ({elapsed:.1f}s)")

# Cleanup function
def cleanup():
    LibraryComponent.objects.filter(library__org='LoadTest').delete()
    LibraryMetadata.objects.filter(org='LoadTest').delete()
    print("Synthetic data cleaned up")
PYEOF

echo ""
echo "To run: copy the Python script above and execute in Django shell"
echo "To cleanup: call cleanup() function after test"
