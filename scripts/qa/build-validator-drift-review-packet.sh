#!/usr/bin/env bash
# Build an evidence-first validator drift review packet (12 sections).
# Output is written under var/evidence/validator-drift/<timestamp>/ by default.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR=""
RUN_SEEDED_DEFECTS=0

usage() {
  cat <<'EOF'
Usage: scripts/qa/build-validator-drift-review-packet.sh [--out-dir <path>]

Options:
  --out-dir <path>   Override output directory.
  --run-seeded-defects  Execute seeded-defect self-tests for section 9.
EOF
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
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$REPO_ROOT/var/evidence/validator-drift/$(date -u +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR"

cat >"$OUT_DIR/01_scope.md" <<'EOF'
# Scope
- Reviewed paths:
  - `scripts/qa/`
  - `scripts/infra/`
  - `scripts/branding/`
  - `scripts/ops/`
  - `scripts/migrations/`
  - `.github/workflows/`
  - `.github/ci-scripts-static.txt`
  - `verification/`
- Reviewed script types:
  - `*.sh`
  - `*.py`

# Explicit Non-Scope
- Runtime cluster state validation
- Cloud account state validation
- External app/toolkit API execution
- Secrets value verification
EOF

python3 - "$REPO_ROOT" "$OUT_DIR" <<'PY'
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

repo_root = Path(sys.argv[1])
out_dir = Path(sys.argv[2])

SCRIPT_RE = re.compile(r"scripts/[A-Za-z0-9_./-]+\.(?:sh|py)")
SPEC_RE = re.compile(r"AC-[A-Z0-9-]+")
ENV_TOKENS = ("dev", "staging", "prod", "nonprod", "preview")
MUTATING_PREFIXES = (
    "fix-",
    "repair-",
    "cleanup-",
    "prune-",
    "retire-",
    "park-",
    "unpark-",
    "sync-",
    "apply-",
    "create-",
    "provision-",
    "bootstrap-",
    "rollback-",
    "load-",
)


def read_json(path: Path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


ci_static_paths: set[str] = set()
ci_static_file = repo_root / ".github/ci-scripts-static.txt"
if ci_static_file.exists():
    for raw in ci_static_file.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        ci_static_paths.add(line.split()[0])

workflow_refs: set[str] = set()
workflow_ref_map: dict[str, set[str]] = defaultdict(set)
for wf in (repo_root / ".github/workflows").glob("*.y*ml"):
    text = wf.read_text(encoding="utf-8", errors="ignore")
    for script in SCRIPT_RE.findall(text):
        workflow_refs.add(script)
        workflow_ref_map[script].add(str(wf.relative_to(repo_root)))

manual_ref_map: dict[str, set[str]] = defaultdict(set)
for docs_root in [repo_root / "docs", repo_root / "README.md"]:
    if docs_root.is_file():
        candidates = [docs_root]
    elif docs_root.is_dir():
        candidates = [p for p in docs_root.rglob("*") if p.is_file() and p.suffix.lower() in {".md", ".txt", ".yaml", ".yml"}]
    else:
        candidates = []
    for candidate in candidates:
        text = candidate.read_text(encoding="utf-8", errors="ignore")
        for script in SCRIPT_RE.findall(text):
            manual_ref_map[script].add(str(candidate.relative_to(repo_root)))

deprecated_manifest = read_json(
    repo_root / "verification/manifests/deprecated_verify_scripts.json",
    {"scripts": []},
)
deprecated_map: dict[str, str] = {}
for entry in deprecated_manifest.get("scripts", []):
    if not isinstance(entry, dict):
        continue
    path = entry.get("path")
    replacement = entry.get("replacement_entrypoint")
    if isinstance(path, str) and path:
        deprecated_map[path] = replacement if isinstance(replacement, str) else ""

overlap_allowlist = read_json(
    repo_root / "scripts/qa/fixtures/script-basename-overlap-allowlist.json",
    {"overlaps": []},
)
overlap_by_basename: dict[str, dict] = {}
for entry in overlap_allowlist.get("overlaps", []):
    if isinstance(entry, dict) and isinstance(entry.get("basename"), str):
        overlap_by_basename[entry["basename"]] = entry

qa_mutation_allow = read_json(
    repo_root / "scripts/qa/fixtures/qa-mutating-scripts-allowlist.json",
    {"allowed_scripts": []},
)
qa_mutation_allow_paths = {
    item["path"]
    for item in qa_mutation_allow.get("allowed_scripts", [])
    if isinstance(item, dict) and isinstance(item.get("path"), str)
}

all_scripts: list[str] = []
for path in (repo_root / "scripts").rglob("*"):
    if not path.is_file():
        continue
    if path.suffix not in {".sh", ".py"}:
        continue
    relative_path = path.relative_to(repo_root)
    if any(part.startswith("tmp-") or part.startswith(".tmp-") for part in relative_path.parts):
        continue
    all_scripts.append(str(relative_path))
all_scripts.sort()
script_contents: dict[str, str] = {}
stable_scripts: list[str] = []
for script in all_scripts:
    script_path = repo_root / script
    try:
        script_contents[script] = script_path.read_text(encoding="utf-8", errors="ignore")
    except FileNotFoundError:
        continue
    stable_scripts.append(script)
all_scripts = stable_scripts
all_script_set = set(all_scripts)

script_call_graph: dict[str, set[str]] = {script: set() for script in all_scripts}
for script, content in script_contents.items():
    for ref in SCRIPT_RE.findall(content):
        if ref in all_script_set and ref != script:
            script_call_graph[script].add(ref)

clusters: dict[str, list[str]] = defaultdict(list)
for script in all_scripts:
    clusters[Path(script).name].append(script)
duplicate_clusters = {
    basename: sorted(paths) for basename, paths in clusters.items() if len(paths) > 1
}

run_release_gate_text = (
    (repo_root / "scripts/qa/run-release-verification-gates.sh").read_text(encoding="utf-8", errors="ignore")
    if (repo_root / "scripts/qa/run-release-verification-gates.sh").exists()
    else ""
)
run_ops_gate_text = (
    (repo_root / "scripts/qa/run-operations-gates.sh").read_text(encoding="utf-8", errors="ignore")
    if (repo_root / "scripts/qa/run-operations-gates.sh").exists()
    else ""
)
run_multisite_gate_text = (
    (repo_root / "scripts/qa/run-multisite-governance-gates.sh").read_text(encoding="utf-8", errors="ignore")
    if (repo_root / "scripts/qa/run-multisite-governance-gates.sh").exists()
    else ""
)

reachability_seeds = {
    script
    for script in all_scripts
    if (
        script in ci_static_paths
        or script in workflow_refs
        or script in {
            "scripts/qa/run-release-verification-gates.sh",
            "scripts/qa/run-operations-gates.sh",
            "scripts/qa/run-multisite-governance-gates.sh",
        }
    )
}
reachable_via_script_chain: set[str] = set()
frontier = list(sorted(reachability_seeds))
while frontier:
    current = frontier.pop()
    if current in reachable_via_script_chain:
        continue
    reachable_via_script_chain.add(current)
    for nxt in sorted(script_call_graph.get(current, set())):
        if nxt not in reachable_via_script_chain:
            frontier.append(nxt)


def classify_kind(path: str) -> str:
    name = Path(path).name
    for prefix in (
        "verify-",
        "audit-",
        "check-",
        "run-",
        "build-",
        "generate-",
        "test-",
        "fix-",
        "sync-",
        "load-",
    ):
        if name.startswith(prefix):
            return prefix[:-1]
    return "script"


def classify_status(path: str) -> str:
    if path in deprecated_map or "/deprecated/" in path:
        return "deprecated"
    if "/fixtures/" in path:
        return "fixture"
    if "/legacy-tests/" in path:
        return "legacy"
    return "active"


def classify_mutability(path: str, content: str) -> str:
    name = Path(path).name
    if any(name.startswith(prefix) for prefix in MUTATING_PREFIXES):
        return "mutating"
    if re.search(r"\b(kubectl\s+(apply|delete|patch|replace)|terraform\s+apply|helm\s+upgrade|argocd\s+app\s+sync)\b", content):
        return "destructive"
    if re.search(r"\brm\s+-rf\b", content):
        return "mutating"
    return "read-only"


def classify_runtime_requires(content: str) -> list[str]:
    req: list[str] = []
    if re.search(r"\bkubectl\b", content):
        req.append("cluster")
    if re.search(r"\b(gcloud|aws|az)\b", content):
        req.append("cloud")
    if re.search(r"\b(infisical|stripe|sentry|argocd)\b", content):
        req.append("vendor")
    if not req:
        req.append("none")
    return req


def classify_owner(path: str) -> str:
    joined = path.lower()
    if "/branding/" in joined or "token" in joined:
        return "frontend-platform"
    if "tenant" in joined or "multisite" in joined or "enterprise" in joined:
        return "multisite-governance"
    if "/infra/" in joined or "k8s" in joined or "gitops" in joined:
        return "platform-infra"
    if "auth" in joined or "oidc" in joined or "sso" in joined:
        return "identity-access"
    if "/migrations/" in joined or "kajabi" in joined or "mct" in joined:
        return "migration-platform"
    if "observability" in joined or "sentry" in joined or "alert" in joined:
        return "sre-security"
    return "platform-core"


catalog: list[dict] = []
reachability: list[dict] = []
mutability_audit: list[dict] = []

for script in all_scripts:
    content = script_contents.get(script, "")
    kind = classify_kind(script)
    status = classify_status(script)
    mutability = classify_mutability(script, content)
    runtime_requires = classify_runtime_requires(content)
    env_scope = sorted({tok for tok in ENV_TOKENS if re.search(rf"\b{tok}\b", content)})
    if not env_scope:
        env_scope = ["global"]
    ci_entrypoints: list[str] = []
    if script in ci_static_paths:
        ci_entrypoints.append("ci_static")
    if script in workflow_refs:
        ci_entrypoints.append("workflow_direct")
    if script in run_release_gate_text:
        ci_entrypoints.append("release_gate")
    if script in run_ops_gate_text:
        ci_entrypoints.append("operations_gate")
    ci_entrypoints = sorted(set(ci_entrypoints))
    spec_ids = sorted(set(SPEC_RE.findall(content)))
    overlap_entry = overlap_by_basename.get(Path(script).name)
    canonical = True
    replaced_by = deprecated_map.get(script, "")
    if overlap_entry and overlap_entry.get("contract_type") == "wrapper":
        canonical = overlap_entry.get("canonical") == script
    elif overlap_entry and overlap_entry.get("contract_type") == "peer_set":
        canonical = False
    entry = {
        "path": script,
        "status": status,
        "kind": kind,
        "mutability": mutability,
        "env_scope": env_scope,
        "owner": classify_owner(script),
        "spec_ids": spec_ids,
        "ci_entrypoints": ci_entrypoints,
        "runtime_dependencies": runtime_requires,
        "canonical": canonical,
        "replaced_by": replaced_by,
    }
    catalog.append(entry)

    if script.startswith("scripts/qa/"):
        mutability_audit.append(
            {
                "path": script,
                "mutability": mutability,
                "allowlisted_mutating_prefix_script": script in qa_mutation_allow_paths,
            }
        )

    if script.startswith("scripts/qa/verify-"):
        workflow_direct_refs = sorted(workflow_ref_map.get(script, set()))
        manual_runbook_refs = sorted(manual_ref_map.get(script, set()))
        reachability_flags = {
            "in_ci_static": script in ci_static_paths,
            "workflow_direct": bool(workflow_direct_refs),
            "release_gate": script in run_release_gate_text,
            "operations_gate": script in run_ops_gate_text,
            "multisite_gate": script in run_multisite_gate_text,
            "manual_runbook_refs": bool(manual_runbook_refs),
            "reachable_via_script_chain": script in reachable_via_script_chain,
        }
        reachability.append(
            {
                "path": script,
                "status": status,
                "in_ci_static": reachability_flags["in_ci_static"],
                "workflow_direct": reachability_flags["workflow_direct"],
                "workflow_refs": workflow_direct_refs,
                "release_gate": reachability_flags["release_gate"],
                "operations_gate": reachability_flags["operations_gate"],
                "multisite_gate": reachability_flags["multisite_gate"],
                "manual_runbook_refs": manual_runbook_refs,
                "reachable_via_script_chain": reachability_flags["reachable_via_script_chain"],
                "reachable_any": any(reachability_flags.values()),
            }
        )

duplicate_report: list[dict] = []
uncontrolled_duplicates: list[str] = []
for basename, paths in sorted(duplicate_clusters.items()):
    allow = overlap_by_basename.get(basename)
    if not allow:
        uncontrolled_duplicates.append(basename)
    duplicate_report.append(
        {
            "basename": basename,
            "paths": paths,
            "allowlisted": bool(allow),
            "contract_type": allow.get("contract_type") if allow else "",
            "canonical": allow.get("canonical", "") if allow else "",
        }
    )

claims = {
    "canonical": sorted(
        [entry["path"] for entry in catalog if entry["canonical"]]
        + [
            "scripts/qa/run-release-verification-gates.sh",
            "scripts/qa/run-operations-gates.sh",
            "scripts/qa/run-multisite-governance-gates.sh",
        ]
    ),
    "duplicate": duplicate_report,
    "deprecated": sorted(deprecated_map),
    "generated_output_only": [
        "var/**",
        "exports/**",
        "scripts/migrations/*/output/**",
        "scripts/migrations/*/logs/**",
        "migrations/*/output/**",
        "migrations/*/logs/**",
    ],
}

unreachable_verify = [
    item["path"]
    for item in reachability
    if item.get("status") == "active" and not item.get("reachable_any")
]
qa_mutating_unallowlisted = [
    item["path"]
    for item in mutability_audit
    if item["mutability"] != "read-only" and not item["allowlisted_mutating_prefix_script"]
]

open_risks = {
    "uncontrolled_duplicate_basenames": uncontrolled_duplicates,
    "unreachable_verify_scripts": unreachable_verify,
    "qa_mutating_unallowlisted": qa_mutating_unallowlisted,
    "notes": [
        "Reachability map is static-reference based; runtime schedulers are not inspected.",
        "Mutability classification is heuristic and command-pattern based.",
    ],
}

(out_dir / "02_claims.json").write_text(json.dumps(claims, indent=2), encoding="utf-8")
(out_dir / "03_canonical_script_catalog.json").write_text(
    json.dumps({"scripts": catalog}, indent=2), encoding="utf-8"
)
(out_dir / "04_duplicate_overlap_clusters.json").write_text(
    json.dumps({"clusters": duplicate_report}, indent=2), encoding="utf-8"
)
(out_dir / "05_ci_reachability.json").write_text(
    json.dumps({"verify_scripts": reachability}, indent=2), encoding="utf-8"
)
(out_dir / "06_mutability_blast_radius.json").write_text(
    json.dumps({"qa_scripts": mutability_audit}, indent=2), encoding="utf-8"
)
(out_dir / "11_open_risks.json").write_text(json.dumps(open_risks, indent=2), encoding="utf-8")
PY

if command -v rg >/dev/null 2>&1; then
  rg -n '\b(dev|staging|prod|nonprod|preview)\b' "$REPO_ROOT/scripts" \
    --glob '*.sh' --glob '*.py' >"$OUT_DIR/07_environment_taxonomy.txt" || true
else
  grep -RInE '\b(dev|staging|prod|nonprod|preview)\b' "$REPO_ROOT/scripts" >"$OUT_DIR/07_environment_taxonomy.txt" || true
fi

{
  echo "# Generated Artifact Leakage"
  echo
  echo "## tracked caches/output-like files under scripts/"
  git -C "$REPO_ROOT" ls-files scripts | rg '(__pycache__/|\.pyc$|/logs/|/output/|\.tar\.gz$|\.png$|\.jpg$|\.webp$)' || true
  echo
  echo "## tracked migration output/log surfaces"
  git -C "$REPO_ROOT" ls-files | rg '^(scripts/migrations/.*/(output|logs)/|migrations/.*/(output|logs)/)' || true
} >"$OUT_DIR/08_generated_artifact_leakage.txt"

{
  echo "# Seeded Defect Results"
  echo
  echo "- Run timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- run_seeded_defects=$RUN_SEEDED_DEFECTS"
  echo
  if [[ "$RUN_SEEDED_DEFECTS" -ne 1 ]]; then
    echo "SKIP seeded-defect execution (enable with --run-seeded-defects)."
  else
    seeded_tests=(
      "scripts/qa/test-verify-script-basename-overlap.sh"
      "scripts/qa/test-verify-verify-script-reachability.sh"
      "scripts/qa/test-verify-repo-hygiene-artifacts.sh"
      "scripts/qa/test-verify-no-mux-asset-ids.sh"
    )
    found=0
    seeded_tmp_log="$(mktemp)"
    trap 'rm -f "$seeded_tmp_log"' EXIT
    for rel in "${seeded_tests[@]}"; do
      test_path="$REPO_ROOT/$rel"
      echo "## $rel"
      if [[ ! -x "$test_path" ]]; then
        echo "SKIP missing"
        echo
        continue
      fi
      found=1
      if bash "$test_path" >"$seeded_tmp_log" 2>&1; then
        echo "PASS"
      else
        echo "FAIL"
      fi
      sed -n '1,80p' "$seeded_tmp_log" || true
      echo
    done
    if [[ "$found" -eq 0 ]]; then
      echo "No seeded defect tests were executable."
    fi
  fi
} >"$OUT_DIR/09_seeded_defect_results.txt"

python3 - "$REPO_ROOT" "$OUT_DIR/10_docs_truth_scan.txt" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
out_path = Path(sys.argv[2])
script_re = re.compile(r"scripts/[A-Za-z0-9_./-]+\.(?:sh|py)")

refs: dict[str, set[str]] = {}
for root in [repo_root / "docs", repo_root / ".github"]:
    if not root.exists():
        continue
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in {".md", ".yml", ".yaml"}:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for ref in script_re.findall(text):
            refs.setdefault(ref, set()).add(str(path.relative_to(repo_root)))

lines = ["# Docs Truth Scan", ""]
missing = []
for ref, sources in sorted(refs.items()):
    if not (repo_root / ref).exists():
        missing.append((ref, sorted(sources)))

def is_non_actionable_source(path: str) -> bool:
    normalized = path.replace("\\", "/")
    if normalized.startswith("docs/archive/"):
        return True
    if "DOCS_CMDREF_BACKLOG_" in normalized:
        return True
    return False

actionable: list[tuple[str, list[str]]] = []
non_actionable: list[tuple[str, list[str]]] = []
for ref, sources in missing:
    if any(not is_non_actionable_source(src) for src in sources):
        actionable.append((ref, sources))
    else:
        non_actionable.append((ref, sources))

if not missing:
    lines.append("No broken script-path references found in docs/.github markdown/yaml surfaces.")
else:
    lines.append(f"Broken references (total): {len(missing)}")
    lines.append(f"Actionable broken references: {len(actionable)}")
    lines.append(f"Non-actionable broken references (archive/backlog only): {len(non_actionable)}")
    lines.append("")
    lines.append("## Actionable")
    if actionable:
        for ref, sources in actionable:
            lines.append(f"- {ref}")
            for src in sources:
                lines.append(f"  - {src}")
    else:
        lines.append("- none")
    lines.append("")
    lines.append("## Non-actionable (archive/backlog only)")
    if non_actionable:
        for ref, sources in non_actionable:
            lines.append(f"- {ref}")
            for src in sources:
                lines.append(f"  - {src}")
    else:
        lines.append("- none")

out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

cat >"$OUT_DIR/12_what_this_review_does_not_prove.md" <<'EOF'
# What This Review Does Not Prove
- Runtime correctness of validators on live clusters
- CI job enablement/status in external systems
- Secret values, cloud IAM posture, or external service health
- End-to-end deploy safety across all environments
- That every validator has complete false-positive/false-negative calibration
EOF

cat >"$OUT_DIR/README.md" <<EOF
# Validator Drift Review Packet
- Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Repo: $REPO_ROOT

## Artifacts
1. \`01_scope.md\`
2. \`02_claims.json\`
3. \`03_canonical_script_catalog.json\`
4. \`04_duplicate_overlap_clusters.json\`
5. \`05_ci_reachability.json\`
6. \`06_mutability_blast_radius.json\`
7. \`07_environment_taxonomy.txt\`
8. \`08_generated_artifact_leakage.txt\`
9. \`09_seeded_defect_results.txt\`
10. \`10_docs_truth_scan.txt\`
11. \`11_open_risks.json\`
12. \`12_what_this_review_does_not_prove.md\`
EOF

echo "Validator drift review packet created: $OUT_DIR"
