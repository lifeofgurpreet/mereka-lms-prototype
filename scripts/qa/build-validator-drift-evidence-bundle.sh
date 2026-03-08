#!/usr/bin/env bash
# Build a deterministic validator-drift evidence bundle (raw evidence first).
#
# Usage:
#   ./scripts/qa/build-validator-drift-evidence-bundle.sh
#   ./scripts/qa/build-validator-drift-evidence-bundle.sh --out-dir var/validator-drift/manual
#   ./scripts/qa/build-validator-drift-evidence-bundle.sh --run-seeded-defects
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="${OUT_DIR:-var/validator-drift/${STAMP}}"
RUN_SEEDED_DEFECTS=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/qa/build-validator-drift-evidence-bundle.sh [--out-dir PATH] [--run-seeded-defects]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --run-seeded-defects)
      RUN_SEEDED_DEFECTS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$OUT_DIR"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 2
  }
}

require_cmd git
require_cmd awk
require_cmd rg
require_cmd python3

run_capture() {
  local name="$1"
  shift
  local out="$OUT_DIR/$name"
  set +e
  "$@" >"$out" 2>&1
  local rc=$?
  set -e
  printf '%s\t%s\t%s\n' "$name" "$rc" "$out" >>"$OUT_DIR/command-status.tsv"
}

echo -e "name\texit_code\toutput_path" >"$OUT_DIR/command-status.tsv"

# 1) Scope
cat >"$OUT_DIR/01_scope.md" <<EOF
# Scope

- Reviewed surfaces:
  - \`scripts/qa/\`
  - \`scripts/infra/\`
  - \`scripts/branding/\`
  - \`.github/workflows/\`
  - \`verification/\`
  - \`docs/archive/reports/\`
- Explicit non-scope:
  - live cluster/runtime state (no kubectl calls in this bundle)
  - cloud-provider live configs
  - production data-plane behavior
EOF

# 2) Claims (machine-readable summary)
python3 - <<'PY' >"$OUT_DIR/02_claims.json"
from __future__ import annotations
import json
from pathlib import Path

root = Path(".")
scripts = sorted(root.glob("scripts/**/verify-*.sh"))
deprecated = [str(p) for p in scripts if "deprecated" in p.parts]
active = [str(p) for p in scripts if "deprecated" not in p.parts]

print(
    json.dumps(
        {
            "canonical_hypothesis": "ci_static entries in .github/ci-scripts-static.txt are canonical release-blocking validators",
            "counts": {
                "total_verify_scripts": len(scripts),
                "active_verify_scripts": len(active),
                "deprecated_path_verify_scripts": len(deprecated),
            },
            "notes": [
                "Use 03_catalog.csv + 05_ci_reachability.json to validate canonicality claim.",
                "Duplicates are reported in 04_duplicate_clusters.txt.",
            ],
        },
        indent=2,
    )
)
PY

# 3) Canonical script catalog snapshot
python3 - <<'PY' >"$OUT_DIR/03_catalog.csv"
from __future__ import annotations
import csv
import json
from pathlib import Path

catalog_path = Path("verification/catalogs/verification_catalog.json")
fields = [
    "path",
    "status",
    "tier",
    "kind",
    "mutability",
    "env_scope",
    "runtime_requires",
    "owner",
    "canonical",
    "ci_binding",
    "ci_entrypoints",
    "reference_count",
    "spec_ids",
    "ac_ids",
]

rows = []
if catalog_path.exists():
    payload = json.loads(catalog_path.read_text(encoding="utf-8"))
    rows = payload.get("scripts", [])

writer = csv.DictWriter(
    __import__("sys").stdout,
    fieldnames=fields,
    extrasaction="ignore",
)
writer.writeheader()
for row in rows:
    normalized = dict(row)
    for key in ("ci_binding", "ci_entrypoints", "spec_ids", "ac_ids"):
        val = normalized.get(key, [])
        if isinstance(val, list):
            normalized[key] = "|".join(str(v) for v in val)
    writer.writerow(normalized)
PY

# 4) Duplicate and overlap clusters
{
  echo "# Exact duplicate basenames"
  git ls-files "scripts/**/*.sh" | awk -F/ '{print $NF}' | sort | uniq -d || true
  echo
  echo "# Overlap hotspot references"
  rg -n 'post-deploy-verify|generate-sla-report|check-error-budget-gate|verify-branding-health|verify-token-drift|verify-secret(s)?-inventory' scripts .github docs || true
} >"$OUT_DIR/04_duplicate_clusters.txt"

# 5) CI/workflow reachability map
python3 - <<'PY' >"$OUT_DIR/05_ci_reachability.json"
from __future__ import annotations
from collections import deque
import json
import re
from pathlib import Path

root = Path(".")
pattern = re.compile(r"scripts/[A-Za-z0-9_./-]+\.sh")
scripts = sorted(str(p) for p in root.glob("scripts/**/verify-*.sh"))
all_shell_scripts = {str(p) for p in root.glob("scripts/**/*.sh")}
static = set()
static_file = root / ".github/ci-scripts-static.txt"
if static_file.exists():
    for raw in static_file.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        static.add(line.split(" #", 1)[0].strip().split()[0])

wf_refs: dict[str, list[str]] = {s: [] for s in scripts}
entrypoint_scripts: set[str] = set()
for wf in (root / ".github/workflows").glob("*.y*ml"):
    text = wf.read_text(encoding="utf-8", errors="ignore")
    found = sorted(set(pattern.findall(text)))
    for script in found:
        if script in all_shell_scripts:
            entrypoint_scripts.add(script)
        if script in wf_refs:
            wf_refs[script].append(str(wf))

for script in static:
    if script in all_shell_scripts:
        entrypoint_scripts.add(script)

manual_docs_refs: dict[str, set[str]] = {s: set() for s in scripts}
manual_sources: list[Path] = []
manual_sources.extend((root / "docs/ops/runbooks").glob("**/*.md"))
manual_sources.extend((root / "docs/guides").glob("**/*.md"))
manual_sources.extend((root / "docs/operations").glob("**/*.md"))
manual_sources.extend((root / "scripts").glob("**/README.md"))
readme = root / "README.md"
if readme.exists():
    manual_sources.append(readme)

for source in manual_sources:
    source_rel = str(source.relative_to(root))
    if source_rel.startswith("verification/"):
        continue
    text = source.read_text(encoding="utf-8", errors="ignore")
    for script in sorted(set(pattern.findall(text))):
        if script in manual_docs_refs and "/deprecated/" not in script:
            manual_docs_refs[script].add(source_rel)

invocation_graph: dict[str, set[str]] = {}
for script_path in sorted(all_shell_scripts):
    text = (root / script_path).read_text(encoding="utf-8", errors="ignore")
    refs = {
        ref
        for ref in pattern.findall(text)
        if ref in all_shell_scripts
    }
    invocation_graph[script_path] = refs

reachable_via_chain: set[str] = set()
queue: deque[str] = deque(sorted(entrypoint_scripts))
while queue:
    current = queue.popleft()
    if current in reachable_via_chain:
        continue
    reachable_via_chain.add(current)
    for nxt in sorted(invocation_graph.get(current, set())):
        if nxt not in reachable_via_chain:
            queue.append(nxt)

rows = []
for script in scripts:
    status = "deprecated" if "/deprecated/" in script else "active"
    via_chain = script in reachable_via_chain
    via_direct = bool(script in static or wf_refs.get(script))
    docs_refs = sorted(manual_docs_refs.get(script, set()))
    via_manual = bool(docs_refs)
    rows.append(
        {
            "path": script,
            "status": status,
            "in_ci_static": script in static,
            "workflow_refs": sorted(set(wf_refs.get(script, []))),
            "reachable_via_script_chain": via_chain,
            "manual_runbook_refs": docs_refs,
            "reachable": bool(via_direct or via_chain or via_manual),
        }
    )

print(json.dumps({"scripts": rows}, indent=2))
PY

# 6) Mutability and blast-radius scan
run_capture "06_mutability_scan.txt" rg -n '(kubectl apply|kubectl delete|helm upgrade|terraform apply|argocd app sync|rm -rf)' scripts/qa scripts/infra scripts/ops

# 7) Environment taxonomy report
run_capture "07_env_taxonomy.txt" rg -n '\b(dev|staging|prod|nonprod|preview)\b' scripts

# 8) Generated-artifact leakage report
run_capture "08_generated_artifact_leakage.txt" sh -lc "git ls-files | rg '(__pycache__/|\\.pyc$|/logs/|/output/|\\.tar\\.gz$|\\.png$|\\.jpg$|\\.webp$|^docs/archive/reports/.*\\.(csv|tsv|xlsx|xls|pdf)$)'"

# 9) Seeded defect results
{
  echo "# Seeded defect checks"
  echo "run_seeded_defects=${RUN_SEEDED_DEFECTS}"
} >"$OUT_DIR/09_seeded_defect_results.txt"

if [[ "$RUN_SEEDED_DEFECTS" -eq 1 ]]; then
  for script in \
    "./scripts/qa/test-verify-script-basename-overlap.sh" \
    "./scripts/qa/test-verify-verify-script-reachability.sh" \
    "./scripts/qa/test-verify-repo-hygiene-artifacts.sh" \
    "./scripts/qa/test-verify-no-mux-asset-ids.sh"
  do
    if [[ -x "$script" ]]; then
      {
        echo ""
        echo "## $script"
        set +e
        "$script"
        echo "exit_code=$?"
        set -e
      } >>"$OUT_DIR/09_seeded_defect_results.txt" 2>&1
    else
      echo "SKIP $script (missing)" >>"$OUT_DIR/09_seeded_defect_results.txt"
    fi
  done
fi

# 10) Docs truth scan
run_capture "10_docs_truth_scan.txt" rg -n 'qa/(deprecated|legacy-tests)|phase[0-9]|legacy|deprecated|verify-.*\.sh' docs/ README.md

# 11) Open risks (raw, minimal interpretation)
python3 - "$OUT_DIR/05_ci_reachability.json" <<'PY' >"$OUT_DIR/11_open_risks.md"
from __future__ import annotations
import json
from pathlib import Path

reachability_file = Path(__import__("sys").argv[1])
if reachability_file.is_file():
    data = json.loads(reachability_file.read_text(encoding="utf-8"))
else:
    data = {"scripts": []}

unreachable = [
    s["path"]
    for s in data.get("scripts", [])
    if s.get("status") != "deprecated" and not s.get("reachable")
]
deprecated_unreachable = [
    s["path"]
    for s in data.get("scripts", [])
    if s.get("status") == "deprecated" and not s.get("reachable")
]
print("# Open Risks")
if unreachable:
    print("- Unreachable validators (not in ci-scripts-static, workflow refs, script-invocation chain, or manual runbook refs):")
    for path in unreachable[:50]:
        print(f"  - `{path}`")
    if len(unreachable) > 50:
        print(f"  - ... {len(unreachable)-50} more")
else:
    print("- No unreachable verify scripts detected by static map.")
if deprecated_unreachable:
    print(f"- Deprecated unreachable validators ignored in risk list: {len(deprecated_unreachable)}")
print("- Review 06_mutability_scan.txt for mutating/destructive commands under qa surfaces.")
print("- Review 08_generated_artifact_leakage.txt for tracked generated artifacts.")
PY

# 12) Limits / what this does not prove
cat >"$OUT_DIR/12_limits.md" <<'EOF'
# What This Bundle Does Not Prove

- Does not prove runtime health of validators in a live cluster.
- Does not prove cloud/IAM/secret correctness at runtime.
- Does not prove CI job success history; it captures static reachability only.
- Does not prove semantic correctness of each validator assertion.
EOF

# Build index packet
cat >"$OUT_DIR/index.md" <<EOF
# Validator Drift Review Packet

Generated at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Git commit: $(git rev-parse --short HEAD)
Git branch: $(git branch --show-current)

## 1. Scope
- [01_scope.md](./01_scope.md)

## 2. Claims
- [02_claims.json](./02_claims.json)

## 3. Canonical script catalog
- [03_catalog.csv](./03_catalog.csv)

## 4. Duplicate and overlap clusters
- [04_duplicate_clusters.txt](./04_duplicate_clusters.txt)

## 5. CI/workflow reachability
- [05_ci_reachability.json](./05_ci_reachability.json)

## 6. Mutability and blast-radius audit
- [06_mutability_scan.txt](./06_mutability_scan.txt)

## 7. Environment taxonomy report
- [07_env_taxonomy.txt](./07_env_taxonomy.txt)

## 8. Generated-artifact leakage report
- [08_generated_artifact_leakage.txt](./08_generated_artifact_leakage.txt)

## 9. Seeded defect results
- [09_seeded_defect_results.txt](./09_seeded_defect_results.txt)

## 10. Docs truth scan
- [10_docs_truth_scan.txt](./10_docs_truth_scan.txt)

## 11. Open risks
- [11_open_risks.md](./11_open_risks.md)

## 12. Limits
- [12_limits.md](./12_limits.md)

## Command execution status
- [command-status.tsv](./command-status.tsv)
EOF

echo "Evidence bundle generated at: $OUT_DIR"
