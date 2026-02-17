#!/usr/bin/env bash
# @covers AC-TKPIPE-001, AC-TKPIPE-002, AC-TKPIPE-003
# @spec: design-tokens-system_spec.md
# Verify single-source token generation pipeline contract.
#
# Phase 1: Contract + drift detection (warnings, not failures)
# Phase 3: CI enforcement (fail on new drift)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONTRACT_DOC="$REPO_ROOT/docs/architecture/TOKEN_GENERATION_PIPELINE.md"
TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"
TOKENS_PROVENANCE="$REPO_ROOT/assets/branding/tokens.provenance.json"
SCSS_BRIDGE="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
RUNTIME_OVERRIDES="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"

PASS=0
FAIL=0
WARN=0

do_pass() {
  PASS=$((PASS + 1))
  echo "  PASS: $1"
}

do_fail() {
  FAIL=$((FAIL + 1))
  echo "  FAIL: $1"
}

do_warn() {
  WARN=$((WARN + 1))
  echo "  WARN: $1"
}

echo "=== Token Generation Pipeline Verification ==="
echo ""

# ==============================
# AC-TKPIPE-001: Contract document exists
# ==============================
echo "--- Contract & Files ---"
if [[ -f "$CONTRACT_DOC" ]]; then
  do_pass "Contract document exists at docs/architecture/TOKEN_GENERATION_PIPELINE.md"
else
  do_fail "Contract document missing: $CONTRACT_DOC"
fi

# Check canonical token file
if [[ -f "$TOKENS_CSS" ]]; then
  do_pass "Canonical token file exists (assets/branding/tokens.css)"
else
  do_fail "Canonical token file missing: $TOKENS_CSS"
fi

# Check provenance file
if [[ -f "$TOKENS_PROVENANCE" ]]; then
  do_pass "Provenance file exists (assets/branding/tokens.provenance.json)"
else
  do_fail "Provenance file missing: $TOKENS_PROVENANCE"
fi

# Check SCSS bridge
if [[ -f "$SCSS_BRIDGE" ]]; then
  do_pass "SCSS bridge file exists (infrastructure/tutor/themes/mereka/scss/_tokens.scss)"
else
  do_fail "SCSS bridge file missing: $SCSS_BRIDGE"
fi

# Check runtime overrides
if [[ -f "$RUNTIME_OVERRIDES" ]]; then
  do_pass "Runtime override file exists (infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css)"
else
  do_fail "Runtime override file missing: $RUNTIME_OVERRIDES"
fi

# ==============================
# Token Counts Sanity
# ==============================
echo ""
echo "--- Token Counts ---"

# Layer 1 token count (must have >= 100 properties)
L1_COUNT=0
if [[ -f "$TOKENS_CSS" ]]; then
  L1_COUNT=$(grep -cE '^\s*--[a-z0-9_-]+:' "$TOKENS_CSS" || true)
  if [[ $L1_COUNT -ge 100 ]]; then
    do_pass "Layer 1 has $L1_COUNT CSS custom properties (expected >= 100)"
  else
    do_fail "Layer 1 has only $L1_COUNT CSS custom properties (expected >= 100)"
  fi
fi

# Layer 2 SCSS variable count (must have >= 20 SCSS variables)
L2_SCSS_COUNT=0
if [[ -f "$SCSS_BRIDGE" ]]; then
  L2_SCSS_COUNT=$(grep -cE '^\$[a-z0-9_-]+:' "$SCSS_BRIDGE" || true)
  if [[ $L2_SCSS_COUNT -ge 20 ]]; then
    do_pass "Layer 2 has $L2_SCSS_COUNT SCSS variables (expected >= 20)"
  else
    do_fail "Layer 2 has only $L2_SCSS_COUNT SCSS variables (expected >= 20)"
  fi
fi

# ==============================
# AC-TKPIPE-002: Cross-layer drift detection
# ==============================
echo ""
echo "--- Cross-Layer Drift Detection ---"

# Use Python inline for hex parsing (robust, no external deps)
python3 - "$TOKENS_CSS" "$SCSS_BRIDGE" "$RUNTIME_OVERRIDES" "$TOKENS_PROVENANCE" <<'PYTHON'
import hashlib
import json
import re
import sys

tokens_path = sys.argv[1]
scss_path = sys.argv[2]
overrides_path = sys.argv[3]
provenance_path = sys.argv[4]

pass_count = 0
warn_count = 0
fail_count = 0

def parse_css_vars(content):
    """Parse CSS custom properties from :root blocks."""
    vars = {}
    root_blocks = re.findall(r':root\s*\{([^}]+)\}', content, re.DOTALL)
    for block in root_blocks:
        for match in re.finditer(r'(--[a-z0-9_-]+)\s*:\s*([^;]+);', block):
            key = match.group(1).strip()
            value = match.group(2).strip().lower()
            # Normalize: remove quotes, spaces, comments
            value = re.sub(r'["\']', '', value)
            value = re.sub(r'/\*.*?\*/', '', value)
            value = value.strip()
            vars[key] = value
    return vars

def parse_scss_vars(content):
    """Parse SCSS variables."""
    vars = {}
    for match in re.finditer(r'\$([a-z0-9_-]+)\s*:\s*([^;]+);', content):
        key = match.group(1).strip()
        value = match.group(2).strip().lower()
        # Normalize: remove quotes, spaces, comments, SCSS interpolation
        value = re.sub(r'["\']', '', value)
        value = re.sub(r'//.*$', '', value, flags=re.MULTILINE)
        value = re.sub(r'/\*.*?\*/', '', value, flags=re.DOTALL)
        value = value.strip()
        vars[key] = value
    return vars

def extract_hex(value):
    """Extract hex color from value (handles var() references)."""
    # If value is a hex color, return it
    hex_match = re.search(r'#([0-9a-f]{6}|[0-9a-f]{3})', value)
    if hex_match:
        return hex_match.group(0)
    return None

with open(tokens_path, 'r', encoding='utf-8') as f:
    tokens_content = f.read()
with open(scss_path, 'r', encoding='utf-8') as f:
    scss_content = f.read()
with open(overrides_path, 'r', encoding='utf-8') as f:
    overrides_content = f.read()
with open(provenance_path, 'r', encoding='utf-8') as f:
    provenance = json.load(f)

# Parse all layers
layer1_css = parse_css_vars(tokens_content)
layer2_css = parse_css_vars(scss_content)
layer2_scss = parse_scss_vars(scss_content)
layer3_css = parse_css_vars(overrides_content)

# Check specific known mappings for drift
mappings = [
    {
        'name': 'teal',
        'l1': '--color-teal',
        'l2_scss': 'color-teal',
        'l2_css': '--mereka-color-teal',
        'l3': '--mereka-color-teal',
    },
    {
        'name': 'magenta',
        'l1': '--color-magenta',
        'l2_scss': 'color-magenta',
        'l2_css': '--mereka-color-magenta',
        'l3': '--mereka-color-magenta',
    },
    {
        'name': 'blue',
        'l1': '--color-blue',
        'l2_scss': 'color-blue',
        'l2_css': '--mereka-color-blue',
        'l3': '--mereka-color-blue',
    },
    {
        'name': 'sky',
        'l1': '--color-sky',
        'l2_scss': 'color-sky',
        'l2_css': '--mereka-color-sky',
        'l3': '--mereka-color-sky',
    },
    {
        'name': 'black/ink-900',
        'l1': '--color-black',
        'l2_scss': 'color-ink-900',
        'l2_css': '--mereka-color-ink-900',
        'l3': '--mereka-color-ink-900',
    },
]

for mapping in mappings:
    name = mapping['name']
    l1_key = mapping['l1']
    l2_scss_key = mapping['l2_scss']
    l2_css_key = mapping['l2_css']
    l3_key = mapping['l3']

    l1_val = layer1_css.get(l1_key)
    l2_scss_val = layer2_scss.get(l2_scss_key)
    l2_css_val = layer2_css.get(l2_css_key)
    l3_val = layer3_css.get(l3_key)

    # Extract hex values
    l1_hex = extract_hex(l1_val) if l1_val else None
    l2_scss_hex = extract_hex(l2_scss_val) if l2_scss_val else None
    l2_css_hex = extract_hex(l2_css_val) if l2_css_val else None
    l3_hex = extract_hex(l3_val) if l3_val else None

    # Check for drift
    all_hexes = set(filter(None, [l1_hex, l2_scss_hex, l2_css_hex, l3_hex]))

    if len(all_hexes) == 0:
        # Token not found in any layer (may be missing)
        continue
    elif len(all_hexes) == 1:
        # All values match
        print(f"  PASS: {name} aligned across layers ({list(all_hexes)[0]})")
        pass_count += 1
    else:
        # Drift detected
        details = []
        if l1_hex:
            details.append(f"L1:{l1_hex}")
        if l2_scss_hex and l2_scss_hex != l1_hex:
            details.append(f"L2-SCSS:{l2_scss_hex}")
        if l2_css_hex and l2_css_hex != l1_hex:
            details.append(f"L2-CSS:{l2_css_hex}")
        if l3_hex and l3_hex != l1_hex:
            details.append(f"L3:{l3_hex}")
        print(f"  WARN: {name} drift — {', '.join(details)}")
        warn_count += 1

# Check for ink-500 drift (special case: not in Layer 1)
l2_ink500_scss = layer2_scss.get('color-ink-500')
l2_ink500_css = layer2_css.get('--mereka-color-ink-500')
l3_ink500 = layer3_css.get('--mereka-color-ink-500')

l2_ink500_scss_hex = extract_hex(l2_ink500_scss) if l2_ink500_scss else None
l2_ink500_css_hex = extract_hex(l2_ink500_css) if l2_ink500_css else None
l3_ink500_hex = extract_hex(l3_ink500) if l3_ink500 else None

ink500_hexes = set(filter(None, [l2_ink500_scss_hex, l2_ink500_css_hex, l3_ink500_hex]))
if len(ink500_hexes) > 1:
    details = []
    if l2_ink500_scss_hex:
        details.append(f"L2-SCSS:{l2_ink500_scss_hex}")
    if l2_ink500_css_hex and l2_ink500_css_hex != l2_ink500_scss_hex:
        details.append(f"L2-CSS:{l2_ink500_css_hex}")
    if l3_ink500_hex and l3_ink500_hex not in [l2_ink500_scss_hex, l2_ink500_css_hex]:
        details.append(f"L3:{l3_ink500_hex}")
    print(f"  WARN: ink-500 drift (Mereka-specific token) — {', '.join(details)}")
    warn_count += 1
elif len(ink500_hexes) == 1:
    print(f"  PASS: ink-500 aligned across Layer 2/3 ({list(ink500_hexes)[0]})")
    pass_count += 1

# ==============================
# Namespace coverage check
# ==============================
echo_namespace_check = True
if echo_namespace_check:
    # Check that tokens.css --color-* exist
    color_tokens_in_l1 = [k for k in layer1_css.keys() if k.startswith('--color-')]
    if len(color_tokens_in_l1) >= 5:
        print(f"  PASS: Layer 1 has {len(color_tokens_in_l1)} --color-* tokens")
        pass_count += 1
    else:
        print(f"  WARN: Layer 1 has only {len(color_tokens_in_l1)} --color-* tokens (expected >= 5)")
        warn_count += 1

# ==============================
# Provenance checks
# ==============================
provenance_checks = True
if provenance_checks:
    # Check provenance fields
    required_fields = ['source_repo', 'source_path', 'source_commit', 'source_sha256']
    missing = [f for f in required_fields if not provenance.get(f)]
    if missing:
        print(f"  FAIL: Provenance missing fields: {', '.join(missing)}")
        fail_count += 1
    else:
        print(f"  PASS: Provenance has all required fields")
        pass_count += 1

    # Check SHA256 match
    source_sha = provenance.get('source_sha256', '').lower()
    actual_sha = hashlib.sha256(tokens_content.encode('utf-8')).hexdigest()
    if source_sha and source_sha == actual_sha:
        print(f"  PASS: Provenance SHA256 matches tokens.css")
        pass_count += 1
    elif source_sha:
        print(f"  WARN: Provenance SHA256 drift (provenance={source_sha[:8]}..., actual={actual_sha[:8]}...)")
        warn_count += 1

# ==============================
# Check existing drift verifier exists
# ==============================
drift_verifier = sys.argv[0].replace('verify-token-generation-pipeline.sh', 'verify-token-drift.sh')
drift_verifier = drift_verifier.replace('/scripts/qa/', '/scripts/branding/')
import os
if os.path.isfile(drift_verifier):
    print(f"  PASS: Existing drift verifier exists (scripts/branding/verify-token-drift.sh)")
    pass_count += 1

# ==============================
# Summary
# ==============================
print("")
print(f"=== Results: {pass_count} PASS / {fail_count} FAIL / {warn_count} WARN ===")

# Exit code: 0 if no failures (warnings are acceptable in Phase 1)
sys.exit(1 if fail_count > 0 else 0)
PYTHON

exit $?
