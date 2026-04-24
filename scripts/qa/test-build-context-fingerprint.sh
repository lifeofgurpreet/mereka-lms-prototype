#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d -t test-build-context-fingerprint.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

# shellcheck source=../infra/build-context-fingerprint.sh
source "$ROOT_DIR/scripts/infra/build-context-fingerprint.sh"

mkdir -p "$tmpdir/context/.git"
cat >"$tmpdir/context/Dockerfile" <<'EOF'
FROM scratch
EOF
cat >"$tmpdir/context/app.txt" <<'EOF'
one
EOF
cat >"$tmpdir/context/.git/ignored" <<'EOF'
ignored-a
EOF

first="$(mereka_build_context_fingerprint "$tmpdir/context")"
second="$(mereka_build_context_fingerprint "$tmpdir/context")"

if [[ -z "$first" || "$first" != "$second" ]]; then
  echo "FAIL build-context fingerprint is not stable" >&2
  exit 1
fi

cat >"$tmpdir/context/.git/ignored" <<'EOF'
ignored-b
EOF
git_only_change="$(mereka_build_context_fingerprint "$tmpdir/context")"

if [[ "$git_only_change" != "$first" ]]; then
  echo "FAIL build-context fingerprint should ignore .git changes" >&2
  exit 1
fi

cat >"$tmpdir/context/app.txt" <<'EOF'
two
EOF
content_change="$(mereka_build_context_fingerprint "$tmpdir/context")"

if [[ "$content_change" == "$first" ]]; then
  echo "FAIL build-context fingerprint did not change after context content changed" >&2
  exit 1
fi

echo "PASS test-build-context-fingerprint"
