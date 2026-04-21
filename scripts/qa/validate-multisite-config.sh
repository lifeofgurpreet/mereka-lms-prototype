#!/usr/bin/env bash
# validate-multisite-config.sh
# Validates SITE_VARIANTS (in mereka_lms.py) and multisite YAML config files.
# Checks: YAML syntax, domain format, SITE_VARIANTS key/field coverage, no duplicates.
#
# Exit 0 = all checks pass
# Exit 1 = one or more checks failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${REPO_ROOT}/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

PASS=0
FAIL=0
PLUGIN_FILE=""
PLUGIN_BUNDLE=""

cleanup() {
  if [[ -n "${PLUGIN_BUNDLE:-}" && -f "${PLUGIN_BUNDLE}" ]]; then
    rm -f "${PLUGIN_BUNDLE}"
  fi
}
trap cleanup EXIT

pass() { echo "  PASS $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL $*" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# 1. YAML syntax validation for multisite config files
# ---------------------------------------------------------------------------
echo "=== 1. YAML syntax ==="

MULTISITE_YAML_FILES=(
  "${REPO_ROOT}/infrastructure/tutor/multisite-sites.yml"
  "${REPO_ROOT}/infrastructure/tutor/multisite-sites.dev.yml"
)

for yaml_file in "${MULTISITE_YAML_FILES[@]}"; do
  if [[ ! -f "$yaml_file" ]]; then
    fail "File not found: ${yaml_file}"
    continue
  fi

  rel="${yaml_file#${REPO_ROOT}/}"

  if python3 -c "import sys, yaml; yaml.safe_load(open('${yaml_file}'))" 2>/dev/null; then
    pass "YAML syntax OK: ${rel}"
  else
    fail "YAML syntax error: ${rel}"
    python3 -c "import sys, yaml; yaml.safe_load(open('${yaml_file}'))" 2>&1 | sed 's/^/    /' >&2
  fi
done

# ---------------------------------------------------------------------------
# 2. Required top-level keys: organizations + sites
# ---------------------------------------------------------------------------
echo ""
echo "=== 2. Required top-level keys ==="

for yaml_file in "${MULTISITE_YAML_FILES[@]}"; do
  [[ -f "$yaml_file" ]] || continue
  rel="${yaml_file#${REPO_ROOT}/}"

  result=$(python3 - "${yaml_file}" <<'PY'
import sys, yaml

path = sys.argv[1]
with open(path) as f:
    data = yaml.safe_load(f)

errors = []
for key in ("organizations", "sites"):
    if key not in data:
        errors.append(f"missing top-level key: '{key}'")
    elif not isinstance(data[key], list) or len(data[key]) == 0:
        errors.append(f"'{key}' must be a non-empty list")

print("\n".join(errors))
PY
)
  if [[ -z "$result" ]]; then
    pass "Required keys present: ${rel}"
  else
    while IFS= read -r line; do
      fail "${rel}: ${line}"
    done <<< "$result"
  fi
done

# ---------------------------------------------------------------------------
# 3. Site domain format (basic RFC-compliant regex)
# ---------------------------------------------------------------------------
echo ""
echo "=== 3. Domain format ==="

DOMAIN_RE='^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$'

for yaml_file in "${MULTISITE_YAML_FILES[@]}"; do
  [[ -f "$yaml_file" ]] || continue
  rel="${yaml_file#${REPO_ROOT}/}"

  bad_domains=$(python3 - "${yaml_file}" "${DOMAIN_RE}" <<'PY'
import sys, re, yaml

path = sys.argv[1]
pattern = sys.argv[2]
rx = re.compile(pattern)

with open(path) as f:
    data = yaml.safe_load(f)

bad = []
for site in data.get("sites", []):
    domain = site.get("domain", "")
    if not domain:
        bad.append(f"site missing 'domain' field (name={site.get('name', 'unknown')})")
    elif not rx.match(domain):
        bad.append(f"invalid domain format: '{domain}'")
    # Also validate domain inside site_values if present
    sv_domain = (site.get("site_values") or {}).get("domain", "")
    if sv_domain and not rx.match(sv_domain):
        bad.append(f"invalid site_values.domain: '{sv_domain}'")

print("\n".join(bad))
PY
)
  if [[ -z "$bad_domains" ]]; then
    pass "Domain formats OK: ${rel}"
  else
    while IFS= read -r line; do
      fail "${rel}: ${line}"
    done <<< "$bad_domains"
  fi
done

# ---------------------------------------------------------------------------
# 4. No duplicate site domain entries within each file
# ---------------------------------------------------------------------------
echo ""
echo "=== 4. Duplicate site entries ==="

for yaml_file in "${MULTISITE_YAML_FILES[@]}"; do
  [[ -f "$yaml_file" ]] || continue
  rel="${yaml_file#${REPO_ROOT}/}"

  dupes=$(python3 - "${yaml_file}" <<'PY'
import sys, yaml
from collections import Counter

path = sys.argv[1]
with open(path) as f:
    data = yaml.safe_load(f)

domains = [site.get("domain", "") for site in data.get("sites", [])]
counts = Counter(domains)
dupes = [d for d, c in counts.items() if c > 1]
print("\n".join(dupes))
PY
)
  if [[ -z "$dupes" ]]; then
    pass "No duplicate site entries: ${rel}"
  else
    while IFS= read -r dupe; do
      fail "${rel}: duplicate domain entry: '${dupe}'"
    done <<< "$dupes"
  fi
done

# ---------------------------------------------------------------------------
# 5. SITE_VARIANTS key coverage: every production site domain must appear
#    in the SITE_VARIANTS object in mereka_lms.py
# ---------------------------------------------------------------------------
echo ""
echo "=== 5. SITE_VARIANTS key coverage ==="

PROD_YAML="${REPO_ROOT}/infrastructure/tutor/multisite-sites.yml"

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp "${TMPDIR:-/tmp}/mereka-plugin-contract.XXXXXX.py")"
  while IFS= read -r plugin_src; do
    [[ -f "$plugin_src" ]] || continue
    cat "$plugin_src" >> "$PLUGIN_BUNDLE"
    printf "\n" >> "$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
  PLUGIN_FILE="$PLUGIN_BUNDLE"
fi

if [[ -z "$PLUGIN_FILE" || ! -f "$PLUGIN_FILE" ]]; then
  fail "Plugin contract sources not found (expected at least ${PLUGIN_MAIN})"
else
  # Extract SITE_VARIANTS keys from the JS literal embedded in plugin sources.
  # Supported shapes:
  #   'domain.tld': { ... }
  #   'domain.tld': _TENANT_CONSTANT
  site_variants_keys=$(python3 - "${PLUGIN_FILE}" <<'PY'
import re
import sys

content = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"const\s+(?:MEREKA_)?SITE_VARIANTS\s*=\s*\{(.+?)\n\s*\};", content, re.DOTALL)
if not match:
    sys.exit(0)

for key in re.findall(r"'([a-zA-Z0-9][a-zA-Z0-9.\-]+)'\s*:\s*(?:\{|_\w+)", match.group(1)):
    print(key)
PY
)

  if [[ -z "$site_variants_keys" ]]; then
    fail "Could not extract any SITE_VARIANTS keys from plugin contract sources"
  else
    # Convert to newline-separated for comparison
    mapfile -t sv_keys <<< "$site_variants_keys"

    # Get production domains from YAML
    prod_domains=$(python3 - "${PROD_YAML}" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
for site in data.get("sites", []):
    d = site.get("domain", "")
    if d:
        print(d)
PY
)
    all_missing=()
    while IFS= read -r domain; do
      found=0
      for key in "${sv_keys[@]}"; do
        if [[ "$key" == "$domain" ]]; then
          found=1
          break
        fi
      done
      if [[ $found -eq 0 ]]; then
        all_missing+=("$domain")
      fi
    done <<< "$prod_domains"

    if [[ ${#all_missing[@]} -eq 0 ]]; then
      pass "All production domains present in SITE_VARIANTS"
    else
      for missing in "${all_missing[@]}"; do
        fail "Domain '${missing}' from multisite-sites.yml not found in SITE_VARIANTS"
      done
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 6. SITE_VARIANTS required fields: each entry must have all mandatory fields
# ---------------------------------------------------------------------------
echo ""
echo "=== 6. SITE_VARIANTS required fields ==="

REQUIRED_FIELDS=(brand copyrightHolder whatsapp supportEmail helpUrl privacyUrl termsUrl cookiesUrl)

if [[ -f "$PLUGIN_FILE" ]]; then
  result=$(python3 - "${PLUGIN_FILE}" <<'PY'
import sys, re

path = sys.argv[1]
required = ["brand", "copyrightHolder", "whatsapp", "supportEmail",
            "helpUrl", "privacyUrl", "termsUrl", "cookiesUrl"]

with open(path) as f:
    content = f.read()

# Find the SITE_VARIANTS block: from "const SITE_VARIANTS = {" (or MEREKA_SITE_VARIANTS)
# to the closing "};".
match = re.search(r'const\s+(?:MEREKA_)?SITE_VARIANTS\s*=\s*\{(.+?)\n\s*\};', content, re.DOTALL)
if not match:
    print("ERROR: Could not locate (MEREKA_)SITE_VARIANTS block in plugin contract sources")
    sys.exit(0)

block = match.group(1)

# Resolve constant objects: extract fields from "const <NAME> = { ... };" blocks.
constant_fields = {}
for bm in re.finditer(r'const\s+(\w+)\s*=\s*\{([^}]+)\}', content):
    name = bm.group(1)
    body = bm.group(2)
    fields = {fm.group(1) for fm in re.finditer(r"(\w+)\s*:", body)}
    for spread in re.findall(r'\.\.\.\s*(\w+)', body):
        fields |= constant_fields.get(spread, set())
    constant_fields[name] = fields

# Find each tenant entry:
#   'domain': { ... }
#   'domain': _TENANT_CONSTANT
tenant_pattern = re.compile(r"'([^']+)':\s*(?:\{([^}]+)\}|(\w+))", re.DOTALL)
errors = []
for m in tenant_pattern.finditer(block):
    domain = m.group(1)
    body = m.group(2) or ""
    constant_name = m.group(3)
    if constant_name:
        tenant_fields = set(constant_fields.get(constant_name, set()))
        if not tenant_fields:
            errors.append(f"SITE_VARIANTS['{domain}'] references unknown constant '{constant_name}'")
            continue
    else:
        tenant_fields = {fm.group(1) for fm in re.finditer(r"(\w+)\s*:", body)}
        for spread in re.findall(r'\.\.\.\s*(\w+)', body):
            tenant_fields |= constant_fields.get(spread, set())
    for field in required:
        if field not in tenant_fields:
            errors.append(f"SITE_VARIANTS['{domain}'] missing field '{field}'")
print("\n".join(errors))
PY
)
  if [[ -z "$result" ]]; then
    pass "All SITE_VARIANTS entries have required fields"
  elif [[ "$result" == ERROR:* ]]; then
    fail "${result}"
  else
    while IFS= read -r line; do
      [[ -n "$line" ]] && fail "${line}"
    done <<< "$result"
  fi
fi

# ---------------------------------------------------------------------------
# 7. Organization short_name coverage: every org referenced by a site must
#    be declared in the organizations list
# ---------------------------------------------------------------------------
echo ""
echo "=== 7. Organization reference integrity ==="

for yaml_file in "${MULTISITE_YAML_FILES[@]}"; do
  [[ -f "$yaml_file" ]] || continue
  rel="${yaml_file#${REPO_ROOT}/}"

  result=$(python3 - "${yaml_file}" <<'PY'
import sys, yaml

path = sys.argv[1]
with open(path) as f:
    data = yaml.safe_load(f)

declared_orgs = {o["short_name"] for o in data.get("organizations", []) if o.get("short_name")}
errors = []
for site in data.get("sites", []):
    domain = site.get("domain", "?")
    for org in site.get("orgs", []):
        if org not in declared_orgs:
            errors.append(f"site '{domain}' references undeclared org '{org}'")
print("\n".join(errors))
PY
)
  if [[ -z "$result" ]]; then
    pass "Org references OK: ${rel}"
  else
    while IFS= read -r line; do
      [[ -n "$line" ]] && fail "${rel}: ${line}"
    done <<< "$result"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "==================================="
echo "Multisite config validation summary"
echo "==================================="
echo "  Passed: ${PASS}"
echo "  Failed: ${FAIL}"

if [[ $FAIL -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi

echo "RESULT: PASS"
exit 0
