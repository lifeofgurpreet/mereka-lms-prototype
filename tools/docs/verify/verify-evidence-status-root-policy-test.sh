#!/usr/bin/env bash
set -euo pipefail

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p \
  "$TMP_ROOT/docs/evidence/operations" \
  "$TMP_ROOT/docs/status/active" \
  "$TMP_ROOT/docs/status/incidents" \
  "$TMP_ROOT/docs/status/weekly" \
  "$TMP_ROOT/evidence" \
  "$TMP_ROOT/reports/2026/status"

cat > "$TMP_ROOT/docs/evidence/operations/OK_EVIDENCE.md" <<'EOF_DOC'
# Evidence
EOF_DOC

cat > "$TMP_ROOT/docs/status/active/OK_STATUS.md" <<'EOF_DOC'
# Status
EOF_DOC

cat > "$TMP_ROOT/docs/status/incidents/OK_INCIDENT.md" <<'EOF_DOC'
# Incident
EOF_DOC

cat > "$TMP_ROOT/docs/status/weekly/OK_WEEKLY.md" <<'EOF_DOC'
# Weekly
EOF_DOC

python3 tools/docs/verify/verify-evidence-status-root-policy.py \
  --root "$TMP_ROOT" \
  docs/evidence/INDEX.md \
  docs/evidence/operations/OK_EVIDENCE.md \
  docs/status/INDEX.md \
  docs/status/active/OK_STATUS.md \
  docs/status/incidents/OK_INCIDENT.md \
  docs/status/weekly/OK_WEEKLY.md >/tmp/evidence_status_root_ok.out

grep -q "EVIDENCE_STATUS_ROOT_POLICY_OK" /tmp/evidence_status_root_ok.out

cat > "$TMP_ROOT/docs/evidence/BAD.md" <<'EOF_DOC'
# Bad
EOF_DOC

if python3 tools/docs/verify/verify-evidence-status-root-policy.py \
  --root "$TMP_ROOT" \
  docs/evidence/BAD.md >/tmp/evidence_status_root_bad_evidence.out 2>&1; then
  echo "expected active evidence root violation"
  cat /tmp/evidence_status_root_bad_evidence.out
  exit 1
fi

grep -q "docs/evidence/BAD.md: active evidence docs must live under docs/evidence/<domain>/" /tmp/evidence_status_root_bad_evidence.out

cat > "$TMP_ROOT/reports/2026/status/LEGACY.md" <<'EOF_DOC'
# Not stubbed
EOF_DOC

if python3 tools/docs/verify/verify-evidence-status-root-policy.py \
  --root "$TMP_ROOT" \
  reports/2026/status/LEGACY.md >/tmp/evidence_status_root_bad_legacy.out 2>&1; then
  echo "expected losing-root violation"
  cat /tmp/evidence_status_root_bad_legacy.out
  exit 1
fi

grep -q "reports/2026/status/LEGACY.md: losing-root markdown doc must remain a superseded stub" /tmp/evidence_status_root_bad_legacy.out

cat > "$TMP_ROOT/reports/2026/status/SUPERSEDED.md" <<'EOF_DOC'
---
status: superseded
superseded_by: docs/status/active/OK_STATUS.md
---
EOF_DOC

python3 tools/docs/verify/verify-evidence-status-root-policy.py \
  --root "$TMP_ROOT" \
  reports/2026/status/SUPERSEDED.md >/tmp/evidence_status_root_stub_ok.out

grep -q "EVIDENCE_STATUS_ROOT_POLICY_OK" /tmp/evidence_status_root_stub_ok.out

echo "verify-evidence-status-root-policy self-test: OK"
