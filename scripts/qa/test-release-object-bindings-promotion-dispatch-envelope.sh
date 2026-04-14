#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cat >"$TMPDIR/release-bundle.json" <<'EOF'
{
  "bundle_id": "rb-aaaaaaaa-20260414T120000Z",
  "created_at": "2026-04-14T12:00:00Z",
  "contract_ref": "Biji-Biji-Initiative/platform-control-plane@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}
EOF

cat >"$TMPDIR/release-object.json" <<'EOF'
{
  "release_id": "ro-rb-aaaaaaaa-20260414T120000Z",
  "service_id": "mereka-lms",
  "app_commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "images": {
    "openedx": {"digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111"},
    "mfe": {"digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222"}
  },
  "build": {
    "release_bundle_id": "rb-aaaaaaaa-20260414T120000Z"
  }
}
EOF

cat >"$TMPDIR/build-provenance.json" <<'EOF'
{
  "schema_version": "1.0.0",
  "repository": "Biji-Biji-Initiative/mereka-lms"
}
EOF

cat >"$TMPDIR/release-gate-envelope.json" <<'EOF'
{
  "concern": "release-gate",
  "result": "pass",
  "details": {
    "gates_pass": 8,
    "gates_fail": 0
  }
}
EOF

python3 "$REPO_ROOT/scripts/release/release_object_bindings.py" \
  promotion-dispatch-envelope \
  --release-bundle-json "$TMPDIR/release-bundle.json" \
  --release-object-json "$TMPDIR/release-object.json" \
  --build-provenance-json "$TMPDIR/build-provenance.json" \
  --proof-envelope-json "$TMPDIR/release-gate-envelope.json" \
  --repository "Biji-Biji-Initiative/mereka-lms" \
  --run-id "123456789" \
  --server-url "https://github.com" \
  --contract-family "promotion_dispatch_envelope_schema" \
  --contract-version "1.0" \
  --contract-ref "Biji-Biji-Initiative/platform-control-plane@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
  --output "$TMPDIR/promotion-dispatch-envelope.json"

jq -e '.lane == "mereka-lms"' "$TMPDIR/promotion-dispatch-envelope.json" >/dev/null
jq -e '.delivery_lane == "dev"' "$TMPDIR/promotion-dispatch-envelope.json" >/dev/null
jq -e '.dispatch_event_type == "promote-mereka-lms-dev"' "$TMPDIR/promotion-dispatch-envelope.json" >/dev/null
jq -e '.structured_evidence.checks | length == 7' "$TMPDIR/promotion-dispatch-envelope.json" >/dev/null
jq -e '.structured_evidence.checks[] | select(.type == "release_gate_result" and .status == "passed")' \
  "$TMPDIR/promotion-dispatch-envelope.json" >/dev/null

echo "PASS: promotion dispatch envelope generator emits canonical structured evidence"
