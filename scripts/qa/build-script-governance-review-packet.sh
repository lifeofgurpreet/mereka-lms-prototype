#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GENERATOR="${SCRIPT_DIR}/generate-script-governance-catalog.py"
OUT_DIR="${REPO_ROOT}/var/evidence/script-governance/latest"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--out-dir <path>]" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$OUT_DIR"

CATALOG_JSON="${OUT_DIR}/script_governance_catalog.json"
SUMMARY_MD="${OUT_DIR}/summary.md"
ORPHANS_TXT="${OUT_DIR}/orphan_candidates.txt"
DANGEROUS_TXT="${OUT_DIR}/dangerous_scripts.txt"
CLAIMS_MD="${OUT_DIR}/claims.md"
SCOPE_MD="${OUT_DIR}/scope.md"

python3 "$GENERATOR" --repo-root "$REPO_ROOT" --out "$CATALOG_JSON" --summary-out "$SUMMARY_MD"

python3 - <<'PY' "$CATALOG_JSON" "$ORPHANS_TXT" "$DANGEROUS_TXT" "$CLAIMS_MD"
import json
import sys
from pathlib import Path

catalog = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
orphans = Path(sys.argv[2])
dangerous = Path(sys.argv[3])
claims = Path(sys.argv[4])

orphans.write_text("\n".join(catalog.get("orphan_candidates", [])) + "\n", encoding="utf-8")
dangerous.write_text("\n".join(catalog.get("dangerous_scripts", [])) + "\n", encoding="utf-8")

summary = catalog.get("summary", {})
lines = [
    "# Claims",
    "",
    f"- total_scripts: {summary.get('total_scripts', 0)}",
    f"- statuses: {summary.get('statuses', {})}",
    f"- mutability: {summary.get('mutability', {})}",
    f"- risks: {summary.get('risks', {})}",
    f"- orphan_candidates: {summary.get('orphan_candidates', 0)}",
    f"- dangerous_scripts: {summary.get('dangerous_scripts', 0)}",
]
claims.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

cat > "$SCOPE_MD" <<EOF
# Scope

- Included: tracked \`.sh\` and \`.py\` files under \`scripts/\`
- Caller tracing surfaces: \`.github/\`, \`docs/\`, \`scripts/\`, \`deploy/\`, \`infrastructure/\`, \`Makefile\`
- Excluded: runtime cluster state, cron schedules outside repository, external infra repositories
EOF

echo "Wrote review packet:"
echo "  - ${SCOPE_MD}"
echo "  - ${CLAIMS_MD}"
echo "  - ${CATALOG_JSON}"
echo "  - ${SUMMARY_MD}"
echo "  - ${ORPHANS_TXT}"
echo "  - ${DANGEROUS_TXT}"
