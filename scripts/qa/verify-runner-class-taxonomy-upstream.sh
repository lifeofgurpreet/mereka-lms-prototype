#!/usr/bin/env bash
# Verify every `runs-on:` label in this repo's .github/workflows/*.{yml,yaml}
# maps to an entry in the UPSTREAM runner-class taxonomy that lives in
# bbi-infrastructure/config/runner-class-taxonomy.yaml.
#
# Per ADR-025 §1 + mereka-lms-5dwe.4. Platform taxonomy is the single source
# of truth; this mereka-lms-side drift gate fails CI if a workflow here
# introduces a runner label that upstream doesn't know about yet.
#
# How it works:
#   1. Fetch the upstream YAML via raw.githubusercontent.com (public repo;
#      no auth required). Cache it in var/ci/ for the run.
#   2. Extract every `runs-on:` value (string or list form) from each workflow.
#   3. Match each label against the upstream taxonomy's label_globs.
#   4. Honor inline exemption comments (`# ci:allow-github-hosted` or
#      `# ci:runner-exempt <reason>`) — same convention as upstream.
#   5. Exit 1 on any unmatched uncommented label; print a clear diagnosis.
#
# Running locally:
#   bash scripts/qa/verify-runner-class-taxonomy-upstream.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

UPSTREAM_REPO="${UPSTREAM_REPO:-Biji-Biji-Initiative/bbi-infrastructure}"
UPSTREAM_PATH="${UPSTREAM_PATH:-config/runner-class-taxonomy.yaml}"
UPSTREAM_REF="${UPSTREAM_REF:-main}"
CACHE_DIR="${CACHE_DIR:-var/ci}"
WORKFLOWS_DIR=".github/workflows"
LOCAL_TAXONOMY_FALLBACK="${LOCAL_TAXONOMY_FALLBACK:-config/runner-class-taxonomy.snapshot.yaml}"

mkdir -p "$CACHE_DIR"
TAXONOMY_FILE="$CACHE_DIR/runner-class-taxonomy.yaml"

# Fetch via gh api. Locally, gh uses the operator's auth and cross-repo reads
# work. In CI the default GITHUB_TOKEN can be scoped to this repo only. When
# upstream cannot be read, the verifier falls back to the source-controlled
# taxonomy snapshot instead of silently skipping the gate.
echo "Fetching upstream taxonomy: $UPSTREAM_REPO:$UPSTREAM_PATH@$UPSTREAM_REF"
fetch_ok=0
if gh api "repos/$UPSTREAM_REPO/contents/$UPSTREAM_PATH?ref=$UPSTREAM_REF" \
     --jq '.content' 2>/dev/null | base64 -d > "$TAXONOMY_FILE" 2>/dev/null; then
  [[ -s "$TAXONOMY_FILE" ]] && fetch_ok=1
fi

if [[ "$fetch_ok" -ne 1 ]]; then
  if [[ -f "$LOCAL_TAXONOMY_FALLBACK" ]]; then
    echo "WARN: could not fetch upstream taxonomy from $UPSTREAM_REPO; using source-controlled fallback $LOCAL_TAXONOMY_FALLBACK" >&2
    cp "$LOCAL_TAXONOMY_FALLBACK" "$TAXONOMY_FILE"
  elif [[ "${ALLOW_DEGRADED_TAXONOMY:-0}" == "1" ]]; then
    echo "WARN: could not fetch upstream taxonomy from $UPSTREAM_REPO." >&2
    echo "      ALLOW_DEGRADED_TAXONOMY=1 set; skipping check." >&2
    echo "PASS (degraded): upstream taxonomy unreachable; drift check skipped."
    exit 0
  else
    echo "FAIL: could not fetch upstream taxonomy and no local fallback exists." >&2
    echo "  Expected upstream: $UPSTREAM_REPO / $UPSTREAM_PATH @ $UPSTREAM_REF" >&2
    echo "  Expected fallback: $LOCAL_TAXONOMY_FALLBACK" >&2
    exit 1
  fi
fi

python3 - "$TAXONOMY_FILE" "$WORKFLOWS_DIR" <<'PY'
import sys, os, re, fnmatch, glob
try:
    import yaml
except ImportError:
    sys.stderr.write("FAIL: PyYAML not installed (pip install pyyaml)\n")
    sys.exit(2)

taxonomy_path, workflows_dir = sys.argv[1], sys.argv[2]
with open(taxonomy_path) as f:
    taxonomy = yaml.safe_load(f)

if not isinstance(taxonomy, dict) or "runner_classes" not in taxonomy:
    sys.stderr.write("FAIL: taxonomy YAML malformed (missing runner_classes)\n")
    sys.exit(2)

globs = []
for rc in taxonomy["runner_classes"]:
    for g in rc.get("label_globs", []):
        globs.append((g, rc["name"]))

rejected = set(taxonomy.get("known_typos_to_reject", []))

def classify(label):
    if label in rejected:
        return None, "rejected-typo"
    for g, name in globs:
        if fnmatch.fnmatchcase(label, g):
            return name, g
    return None, None

# Extract runs-on labels (with line numbers) from each workflow file.
label_pat = re.compile(r'^\s*runs-on:\s*(.+?)\s*$')
list_pat = re.compile(r'^\s*-\s*(.+?)\s*$')

def extract_labels(path):
    """Yield (label, line_no, exempt_comment) for each runs-on entry."""
    labels = []
    with open(path) as f:
        lines = f.readlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        m = label_pat.match(line)
        if not m:
            i += 1
            continue
        val = m.group(1).strip()
        # Check inline comment on this line
        inline = ""
        for sep in (" #", "\t#"):
            if sep in val:
                val, inline = val.split(sep, 1)
                val, inline = val.strip(), inline.strip()
                break
        # Check previous line for comment (same-column directive-style)
        prev_comment = ""
        if i > 0:
            prev = lines[i-1].strip()
            if prev.startswith("#"):
                prev_comment = prev.lstrip("# ").strip()
        exempt = inline or prev_comment
        # Handle list form: runs-on: \n  - label1 \n  - label2
        if val in ("", "[", "|", ">"):
            j = i + 1
            while j < len(lines):
                lm = list_pat.match(lines[j])
                if not lm:
                    break
                item = lm.group(1).strip().strip("'\"")
                if item:
                    labels.append((item, j+1, path, exempt))
                j += 1
            i = j
            continue
        # Handle flow-style list: [a, b, c]
        if val.startswith("[") and val.endswith("]"):
            for part in val.strip("[]").split(","):
                part = part.strip().strip("'\"")
                if part:
                    labels.append((part, i+1, path, exempt))
            i += 1
            continue
        # Scalar
        val = val.strip("'\"")
        # Skip expression values like ${{ ... }}
        if val.startswith("${{") and val.endswith("}}"):
            i += 1
            continue
        labels.append((val, i+1, path, exempt))
        i += 1
    return labels

workflow_files = sorted(
    glob.glob(os.path.join(workflows_dir, "*.yml"))
    + glob.glob(os.path.join(workflows_dir, "*.yaml"))
)

all_labels = []
for wf in workflow_files:
    all_labels.extend(extract_labels(wf))

unmatched = []
matched = {}
exempted = []

for label, lineno, path, exempt in all_labels:
    name, _ = classify(label)
    is_exempt = (
        "ci:allow-github-hosted" in exempt
        or "ci:runner-exempt" in exempt
    )
    if name is not None:
        matched.setdefault(name, []).append((label, path, lineno))
    elif is_exempt:
        exempted.append((label, path, lineno, exempt))
    else:
        unmatched.append((label, path, lineno))

print(f"Workflows scanned: {len(workflow_files)}")
print(f"runs-on entries:  {len(all_labels)}")
print(f"Matched:          {sum(len(v) for v in matched.values())}")
print(f"Exempted:         {len(exempted)}")
print(f"Unmatched:        {len(unmatched)}")
print()

for name, entries in sorted(matched.items()):
    print(f"  {name}: {len(entries)}")

if exempted:
    print()
    print("Exempted labels (carry inline comment):")
    for label, path, lineno, comment in exempted:
        rel = os.path.relpath(path)
        print(f"  {rel}:{lineno} {label!r} ({comment})")

if unmatched:
    print()
    print("FAIL: the following runner labels are not in the upstream taxonomy:")
    for label, path, lineno in unmatched:
        rel = os.path.relpath(path)
        print(f"  {rel}:{lineno} {label!r}")
    print()
    print("Fix options:")
    print("  (a) Add the label to bbi-infrastructure/config/runner-class-taxonomy.yaml")
    print("      under an existing or new runner_classes entry's label_globs.")
    print("  (b) If this is a deliberate GitHub-hosted exemption, add a comment on")
    print("      the previous line: # ci:allow-github-hosted")
    print("  (c) If exempt for another reason, add: # ci:runner-exempt <one-line reason>")
    sys.exit(1)

print()
print("PASS: all runs-on labels match the upstream taxonomy.")
PY
