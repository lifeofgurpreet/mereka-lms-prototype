#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

tmpdir="$(mktemp -d -t lms-ops-proof-passthrough.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/scripts/lib" "$tmpdir/scripts/release"
cp "$ROOT_DIR/bin/lms-ops" "$tmpdir/bin/lms-ops"
chmod +x "$tmpdir/bin/lms-ops"

cat >"$tmpdir/scripts/lib/lane-normalize.sh" <<'EOF'
#!/usr/bin/env bash
normalize_lane_to_canonical() {
  case "$1" in
    dev|development) echo "dev" ;;
    staging) echo "staging" ;;
    prod|production) echo "prod" ;;
    *) echo "$1" ;;
  esac
}

normalize_lane_to_namespace() {
  case "$1" in
    dev) echo "mereka-lms-dev" ;;
    staging) echo "stg-mereka-lms" ;;
    prod) echo "mereka-lms" ;;
    *) return 1 ;;
  esac
}

normalize_lane_to_overlay() {
  case "$1" in
    dev) echo "rke2-nonprod" ;;
    staging) echo "rke2-staging" ;;
    prod) echo "rke2-prod" ;;
    *) return 1 ;;
  esac
}
EOF
chmod +x "$tmpdir/scripts/lib/lane-normalize.sh"

cat >"$tmpdir/scripts/release/emit-proof-envelope.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@"
EOF
chmod +x "$tmpdir/scripts/release/emit-proof-envelope.sh"

output="$(
  cd "$tmpdir"
  ./bin/lms-ops proof \
    --concern release-gate \
    --lane dev \
    --release-object-json /tmp/release-object.json \
    --ci-failure-baseline-json /tmp/ci-baseline.json \
    --output-dir /tmp/proof-out \
    --ci-run-id 24398181031 \
    --domain apps.academyv2.mereka.dev \
    --skip-cluster
)"

assert_contains() {
  local needle="$1"
  if [[ "$output" != *"$needle"* ]]; then
    echo "Expected output to contain: $needle" >&2
    echo "--- output ---" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
}

assert_contains "--concern"
assert_contains "release-gate"
assert_contains "--lane"
assert_contains "dev"
assert_contains "--release-object-json"
assert_contains "/tmp/release-object.json"
assert_contains "--ci-failure-baseline-json"
assert_contains "/tmp/ci-baseline.json"
assert_contains "--output-dir"
assert_contains "/tmp/proof-out"
assert_contains "--ci-run-id"
assert_contains "24398181031"
assert_contains "--domain"
assert_contains "apps.academyv2.mereka.dev"
assert_contains "--skip-cluster"

echo "OK"
