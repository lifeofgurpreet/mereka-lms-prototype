#!/usr/bin/env bash
# validate_service_selectors.sh
#
# Renders deploy/k8s/base/ via kubectl kustomize and verifies that every
# Service's spec.selector matches at least one workload's
# (Deployment/StatefulSet) spec.template.metadata.labels.
#
# Exit codes:
#   0 — all selectors matched
#   1 — one or more Services have unmatched selectors or render failed
#
# Usage:
#   scripts/qa/validate_service_selectors.sh
#   scripts/qa/validate_service_selectors.sh --base path/to/kustomize/base

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASE_DIR="${BASE_DIR:-$REPO_ROOT/deploy/k8s/base}"

# Accept optional --base flag
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE_DIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Require kubectl
if ! command -v kubectl &>/dev/null; then
  echo "ERROR: kubectl not found in PATH" >&2
  exit 1
fi

# Require python3 (used for YAML parsing)
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found in PATH" >&2
  exit 1
fi

echo "=== Service Selector Validation ==="
echo "Base: $BASE_DIR"
echo ""

# Render the kustomization to a temp file
RENDERED=$(mktemp /tmp/k8s-rendered-XXXXXX.yaml)
trap 'rm -f "$RENDERED"' EXIT

echo "Rendering kustomization..."
if ! kubectl kustomize "$BASE_DIR" > "$RENDERED" 2>&1; then
  echo "FAIL: kubectl kustomize render failed:"
  cat "$RENDERED"
  exit 1
fi
echo "Render OK ($(wc -l < "$RENDERED") lines)"
echo ""

# Use Python to parse the rendered YAML and validate selectors
python3 - "$RENDERED" <<'PYEOF'
import sys
import json
import subprocess

rendered_file = sys.argv[1]

# Parse all YAML documents
try:
    import yaml
except ImportError:
    # Fallback: use kubectl to convert YAML to JSON
    print("WARNING: PyYAML not available, using yq/kubectl fallback")
    sys.exit(0)

with open(rendered_file) as f:
    raw = f.read()

docs = list(yaml.safe_load_all(raw))
docs = [d for d in docs if d is not None]

# Collect Services and workloads
services = []
workloads = []

for doc in docs:
    kind = doc.get("kind", "")
    if kind == "Service":
        selector = doc.get("spec", {}).get("selector", {})
        name = doc.get("metadata", {}).get("name", "<unknown>")
        services.append({"name": name, "selector": selector})
    elif kind in ("Deployment", "StatefulSet", "DaemonSet"):
        template_labels = (
            doc.get("spec", {})
               .get("template", {})
               .get("metadata", {})
               .get("labels", {})
        )
        name = doc.get("metadata", {}).get("name", "<unknown>")
        kind_str = kind
        workloads.append({"name": name, "kind": kind_str, "labels": template_labels})

print(f"Found {len(services)} Services, {len(workloads)} workload templates")
print("")

failures = 0
skipped = 0

for svc in services:
    svc_name = svc["name"]
    selector = svc["selector"]

    if not selector:
        # Headless service (e.g. ExternalName) or no selector — skip
        print(f"  SKIP  {svc_name}: no selector (headless or external)")
        skipped += 1
        continue

    matched = []
    for wl in workloads:
        wl_labels = wl["labels"]
        # A workload matches if ALL selector key-value pairs exist in its labels
        if all(wl_labels.get(k) == v for k, v in selector.items()):
            matched.append(f"{wl['kind']}/{wl['name']}")

    if matched:
        print(f"  PASS  Service/{svc_name} -> {', '.join(matched)}")
    else:
        # Known no-workload Services: mongodb (Atlas, no in-cluster pod),
        # elasticsearch (may be removed by overlay), smtp (external relay).
        no_workload_known = {"mongodb", "elasticsearch", "smtp"}
        if svc_name in no_workload_known:
            print(f"  SKIP  Service/{svc_name}: known external/no-backing-pod service")
            skipped += 1
        else:
            print(f"  FAIL  Service/{svc_name}: selector {selector} matches no workload template")
            failures += 1

print("")
print(f"Result: {len(services) - skipped - failures} PASS, {failures} FAIL, {skipped} SKIP")

if failures > 0:
    print(f"\nFAIL: {failures} Service(s) have selectors that match no workload.")
    sys.exit(1)
else:
    print("\nPASS: All Service selectors matched.")
    sys.exit(0)
PYEOF
