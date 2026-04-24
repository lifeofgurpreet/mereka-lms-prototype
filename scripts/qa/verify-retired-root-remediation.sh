#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

required_files=(
  "docs/stabilization/RETIRED_ROOT_REMEDIATION_LEDGER.md"
  "docs/stabilization/retired-root-remediation-ledger.v1.yaml"
  "docs/stabilization/DOCS_ROOT_AUTHORITY_CONTRACT.md"
  "docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md"
  "var/proofs/retired-root-remediation.md"
)

for path in "${required_files[@]}"; do
  [[ -f "$path" ]] || { echo "MISSING_REQUIRED_FILE $path" >&2; exit 1; }
done

python3 - <<'PY'
from pathlib import Path
import sys

try:
    import yaml
except Exception as exc:  # pragma: no cover - verifier guard
    print(f"YAML_IMPORT_FAIL {exc}", file=sys.stderr)
    raise SystemExit(1)

path = Path("docs/stabilization/retired-root-remediation-ledger.v1.yaml")
data = yaml.safe_load(path.read_text(encoding="utf-8"))
if not isinstance(data, dict):
    print("LEDGER_FORMAT_FAIL top-level must be a mapping", file=sys.stderr)
    raise SystemExit(1)

entries = data.get("entries")
if not isinstance(entries, list) or len(entries) < 12:
    print("LEDGER_FORMAT_FAIL expected at least 12 remediation entries", file=sys.stderr)
    raise SystemExit(1)

allowed = set(data.get("allowed_classifications", []))
required = {"ACTIVE", "SUPERSEDED", "DUPLICATE", "TOMBSTONE_CANDIDATE", "REFERENCE_ONLY"}
if allowed != required:
    print(f"LEDGER_FORMAT_FAIL allowed_classifications mismatch: {sorted(allowed)}", file=sys.stderr)
    raise SystemExit(1)

seen = set()
for entry in entries:
    retired_path = entry.get("retired_path")
    classification = entry.get("classification")
    destination = entry.get("canonical_destination")
    if not retired_path or not classification or not destination:
        print(f"LEDGER_ENTRY_FAIL missing required fields in {entry}", file=sys.stderr)
        raise SystemExit(1)
    seen.add(retired_path)
    if classification not in required:
        print(f"LEDGER_ENTRY_FAIL invalid classification for {retired_path}: {classification}", file=sys.stderr)
        raise SystemExit(1)

expected = {
    "docs/architecture/ADMIN_SURFACES_AND_ENTRYPOINTS.md",
    "docs/architecture/ENTERPRISE_TENANT_VARIANTS.md",
    "docs/architecture/SALVAGE_BRANCH_LEDGER.md",
    "docs/architecture/STABLE_CONFIG_ROLLOUT_DEBT.md",
    "docs/architecture/TENANT_DOMAIN_AUTHORITY_MATRIX.md",
    "docs/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md",
    "docs/architecture/TENANT_MODEL_RECOMMENDATION.md",
    "docs/architecture/README.md",
    "docs/operations/ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK.md",
    "docs/operations/ENTERPRISE_DATA_AUDIT.md",
    "docs/operations/ENTERPRISE_DATA_MODEL_AUDIT.md",
    "docs/operations/README.md",
}
missing = sorted(expected - seen)
if missing:
    print(f"LEDGER_ENTRY_FAIL missing retired-root entries: {missing}", file=sys.stderr)
    raise SystemExit(1)
PY

grep -q 'scripts/qa/verify-retired-root-remediation.sh' docs/stabilization/DOCS_ROOT_AUTHORITY_CONTRACT.md
grep -q 'docs/stabilization/DOCS_ROOT_AUTHORITY_CONTRACT.md' docs/stabilization/RETIRED_ROOT_REMEDIATION_LEDGER.md
grep -q 'docs/stabilization/retired-root-remediation-ledger.v1.yaml' var/proofs/retired-root-remediation.md
grep -q 'docs/reference/architecture/ENTERPRISE_TENANT_VARIANTS.md' docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md
grep -q 'docs/ops/runbooks/ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK.md' docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md

python3 tools/docs/verify/verify_legacy_architecture_root.py --repo-root .
python3 tools/docs/verify/verify_legacy_operations_root.py --repo-root .

echo "RETIRED_ROOT_REMEDIATION_OK"
