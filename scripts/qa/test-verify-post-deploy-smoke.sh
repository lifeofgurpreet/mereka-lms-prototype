#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-post-deploy-smoke.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_BIN="$TMP_DIR/fake-bin"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

url="${@: -1}"

status_for_url() {
  case "$1" in
    https://studio.academyv2.mereka.io/) echo "302" ;;
    https://studio.academyv2.mereka.io/*) echo "200" ;;
    https://academyv2.mereka.io/*|https://academy.biji-biji.com/*|https://skillourfuture.academy.mereka.io/*|https://apps.academyv2.mereka.io/*) echo "200" ;;
    *) echo "000" ;;
  esac
}

config_for_url() {
  case "$1" in
    https://academyv2.mereka.io/api/mfe_config/v1) echo '{"SITE_NAME":"Mereka Academy"}' ;;
    https://academy.biji-biji.com/api/mfe_config/v1) echo '{"SITE_NAME":"Biji-Biji Academy"}' ;;
    https://skillourfuture.academy.mereka.io/api/mfe_config/v1) echo '{"SITE_NAME":"Skill Our Future"}' ;;
    *) echo '' ;;
  esac
}

if [[ " $* " == *" %{http_code} "* ]]; then
  printf '%s' "$(status_for_url "$url")"
  exit 0
fi

printf '%s' "$(config_for_url "$url")"
EOF
chmod 0755 "$FAKE_BIN/curl"

cat >"$FAKE_BIN/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

deploy=""
jsonpath=""
for arg in "$@"; do
  case "$arg" in
    lms|cms|mfe) deploy="$arg" ;;
    jsonpath=*) jsonpath="${arg#jsonpath=}" ;;
  esac
done

if [[ -z "$deploy" || -z "$jsonpath" ]]; then
  exit 1
fi

case "$jsonpath" in
  "'{.status.readyReplicas}'") printf '1' ;;
  "'{.status.replicas}'") printf '1' ;;
  "'{.spec.template.spec.containers[0].image}'") printf 'ghcr.io/biji-biji-initiative/mereka-lms/%s:test@sha256:deadbeef' "$deploy" ;;
  *) exit 1 ;;
esac
EOF
chmod 0755 "$FAKE_BIN/kubectl"

OUTPUT="$TMP_DIR/output.log"
PATH="$FAKE_BIN:$PATH" "$VERIFY" --env prod >"$OUTPUT"

grep -q "PASS: Studio homepage → HTTP 302 (https://studio.academyv2.mereka.io/)" "$OUTPUT"
grep -q "RESULT: PASS — rollout may proceed" "$OUTPUT"

echo "verify-post-deploy-smoke accepts studio 302 redirect"
