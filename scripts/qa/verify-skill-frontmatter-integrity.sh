#!/usr/bin/env bash
# @covers AC-SKILL-001
# @spec: cross-cutting-requirements_spec.md
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT_FILE="$REPO_ROOT/config/skill-roots.yaml"
PROFILE="repo_only"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }

echo "=== Skill Frontmatter Integrity Verification ==="
echo "Repo root: $REPO_ROOT"
echo "Profile: $PROFILE"

echo "--- Check 1: contract exists and is valid YAML ---"
if [[ -f "$CONTRACT_FILE" ]]; then
  pass "$CONTRACT_FILE exists"
else
  fail "$CONTRACT_FILE missing"
fi
if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$CONTRACT_FILE" 2>/dev/null; then
  pass "$CONTRACT_FILE is valid YAML"
else
  fail "$CONTRACT_FILE is not valid YAML"
fi

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "=== Summary ==="
  echo "PASS: $passes | FAIL: $failures"
  exit 1
fi

echo "--- Check 2: selected roots have valid frontmatter and stable names ---"
if python3 - "$REPO_ROOT" "$CONTRACT_FILE" "$PROFILE" <<'PY'
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

import yaml

repo_root = Path(sys.argv[1])
contract_file = Path(sys.argv[2])
profile = sys.argv[3]
contract = yaml.safe_load(contract_file.read_text())
scan_profiles = contract.get("scan_profiles", {})
if profile not in scan_profiles:
    raise SystemExit(f"Unknown scan profile: {profile}")

repositories = contract.get("repositories", {})
checkouts = {}

for repo_id, repo_cfg in repositories.items():
    local_path = repo_cfg.get("local_path")
    if not local_path:
        continue
    candidate = Path(local_path)
    if not candidate.is_absolute():
        candidate = repo_root / candidate
    if candidate.exists():
        checkouts[repo_id] = candidate.resolve()
        continue
    if repo_id != "self" and profile == "shared" and repo_cfg.get("git_url"):
        tmpdir = Path(tempfile.mkdtemp(prefix=f"skill-roots-{repo_id}-"))
        subprocess.run(
            [
                "git",
                "clone",
                "--depth",
                "1",
                "--branch",
                repo_cfg.get("ref", "main"),
                repo_cfg["git_url"],
                str(tmpdir),
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        checkouts[repo_id] = tmpdir.resolve()

root_map = {row["id"]: row for row in contract.get("roots", [])}
selected_roots = [root_map[root_id] for root_id in scan_profiles[profile]]

frontmatter_cfg = contract["frontmatter"]
required_fields = frontmatter_cfg.get("required_fields", [])
nonempty_fields = set(frontmatter_cfg.get("nonempty_fields", []))
string_or_list_fields = set(frontmatter_cfg.get("string_or_list_fields", []))
allowed_name_mismatch_directories = set(frontmatter_cfg.get("allowed_name_mismatch_directories", []))

for forbidden in contract.get("forbidden_canonical_roots", []):
    if any(root.get("subpath") == forbidden for root in selected_roots if root.get("canonical", False)):
        raise SystemExit(f"Forbidden canonical root declared: {forbidden}")

entries = []
issues = []
notes = []
frontmatter_re = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)

for root in selected_roots:
    repo_id = root["repository"]
    if repo_id not in checkouts:
        issues.append(f"Root {root['id']} could not resolve repository '{repo_id}'")
        continue
    base_dir = (checkouts[repo_id] / root["subpath"]).resolve()
    if not base_dir.exists():
        issues.append(f"Root {root['id']} missing: {base_dir}")
        continue
    found = 0
    for skill_dir in sorted(base_dir.iterdir()):
        if not skill_dir.is_dir():
            continue
        skill_file = skill_dir / "SKILL.md"
        if not skill_file.exists():
            continue
        found += 1
        text = skill_file.read_text(encoding="utf-8")
        match = frontmatter_re.match(text)
        if not match:
            issues.append(f"{skill_file}: missing YAML frontmatter")
            continue
        try:
            frontmatter = yaml.safe_load(match.group(1)) or {}
        except Exception as exc:
            issues.append(f"{skill_file}: invalid YAML frontmatter ({exc})")
            continue
        for field in required_fields:
            if field not in frontmatter:
                issues.append(f"{skill_file}: missing required frontmatter field '{field}'")
        for field in nonempty_fields:
            value = frontmatter.get(field)
            if not isinstance(value, str) or not value.strip():
                issues.append(f"{skill_file}: frontmatter field '{field}' must be a non-empty string")
        for field in string_or_list_fields:
            if field not in frontmatter:
                continue
            value = frontmatter[field]
            if isinstance(value, str):
                pass
            elif isinstance(value, list) and all(isinstance(item, str) for item in value):
                pass
            else:
                issues.append(f"{skill_file}: field '{field}' must be a string or list of strings")
        if frontmatter_cfg.get("require_name_matches_directory", False):
            if (
                frontmatter.get("name") != skill_dir.name
                and skill_dir.name not in allowed_name_mismatch_directories
            ):
                issues.append(
                    f"{skill_file}: frontmatter name '{frontmatter.get('name')}' must match directory '{skill_dir.name}'"
                )
        entries.append(
            {
                "skill_name": frontmatter.get("name"),
                "root_id": root["id"],
                "priority": int(root.get("priority", 0)),
                "allow_alias_shadow": bool(root.get("allow_alias_shadow", False)),
                "skill_file": skill_file,
                "realpath": skill_file.resolve(),
            }
        )
    if found == 0 and root.get("required", False):
        issues.append(f"Root {root['id']} contains no SKILL.md files: {base_dir}")

by_name = defaultdict(list)
for entry in entries:
    by_name[entry["skill_name"]].append(entry)

for skill_name, items in sorted(by_name.items()):
    if len(items) == 1:
        continue
    realpaths = {str(item["realpath"]) for item in items}
    if len(realpaths) == 1:
        canonical = sorted(items, key=lambda item: (-item["priority"], item["root_id"]))[0]
        shadowers = [item for item in items if item is not canonical]
        if all(item["allow_alias_shadow"] for item in shadowers):
            notes.append(
                "alias-shadow preserved for {}: canonical {} / shadows {}".format(
                    skill_name,
                    canonical["root_id"],
                    [item["root_id"] for item in shadowers],
                )
            )
        else:
            issues.append(f"Skill name '{skill_name}' is shadowed across roots without allow_alias_shadow")
    else:
        issues.append(
            "Skill name '{}' resolves to multiple different files: {}".format(
                skill_name,
                [f"{item['root_id']}:{item['skill_file']}" for item in items],
            )
        )

for note in notes:
    print(f"NOTE: {note}")
if issues:
    for issue in issues:
        print(issue)
    raise SystemExit(1)

print(f"Scanned {len(entries)} skills across {len(selected_roots)} roots")
PY
then
  pass "skill frontmatter integrity checks passed for profile $PROFILE"
else
  fail "skill frontmatter integrity checks failed for profile $PROFILE"
fi

echo
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Skill frontmatter integrity checks pass."
