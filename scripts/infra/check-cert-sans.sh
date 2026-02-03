#!/usr/bin/env bash
# Verify TLS cert SANs and detect fake ingress certificates
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

HOSTS=(
  "$LMS_DOMAIN"
  "studio.${LMS_DOMAIN}"
  "apps.${LMS_DOMAIN}"
  "discovery.${LMS_DOMAIN}"
  "ecommerce.${LMS_DOMAIN}"
  "notes.${LMS_DOMAIN}"
  "$SKILLOURFUTURE_DOMAIN"
  "$BIJI_DOMAIN"
)

failures=0

check_host() {
  local host=$1
  local cert_info subject sans

  cert_info=$(echo | openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null | openssl x509 -noout -subject -issuer -ext subjectAltName 2>/dev/null || true)
  if [[ -z "$cert_info" ]]; then
    echo "✗ $host: failed to fetch certificate" >&2
    failures=$((failures + 1))
    return
  fi

  subject=$(echo "$cert_info" | sed -n 's/^subject=//p')
  if echo "$subject" | grep -qi "Kubernetes Ingress Controller Fake Certificate"; then
    echo "✗ $host: fake ingress certificate detected" >&2
    failures=$((failures + 1))
    return
  fi

  sans=$(echo "$cert_info" | awk '/Subject Alternative Name/{flag=1;next}/X509v3/{flag=0}flag' | tr -d ' ')
  if echo "$sans" | grep -q "DNS:${host}"; then
    echo "✓ $host: SAN OK"
    return
  fi

  local wildcard_suffix="${host#*.}"
  if [[ "$host" != "$wildcard_suffix" ]] && echo "$sans" | grep -q "DNS:\\*\\.${wildcard_suffix}"; then
    echo "✓ $host: SAN OK (wildcard)"
    return
  fi

  echo "✗ $host: SAN missing" >&2
  echo "  SANs: ${sans}" >&2
  failures=$((failures + 1))
}

for host in "${HOSTS[@]}"; do
  check_host "$host"
done

if [[ $failures -gt 0 ]]; then
  echo "${failures} certificate checks failed." >&2
  exit 1
fi

echo "All certificate checks passed."
