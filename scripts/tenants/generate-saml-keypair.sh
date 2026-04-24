#!/usr/bin/env bash
# @covers AC-005
# @spec: auth-sso-enterprise_spec.md
# Generate SAML SP certificate and private key for enterprise SSO.
#
# Output: PEM-encoded certificate and key, printed to stdout or written to files.
# The generated cert/key should be stored in Infisical as:
#   MEREKA_LMS_SAML_SP_PUBLIC_CERT
#   MEREKA_LMS_SAML_SP_PRIVATE_KEY
#
# Usage:
#   ./scripts/tenants/generate-saml-keypair.sh [--output-dir DIR]
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

OUTPUT_DIR=""
SUBJECT="/CN=academyv2.mereka.io/O=Mereka Academy/C=MY"
VALIDITY_DAYS=1825  # 5 years

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --subject) SUBJECT="$2"; shift 2 ;;
    --validity) VALIDITY_DAYS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--output-dir DIR] [--subject SUBJECT] [--validity DAYS]"
      echo ""
      echo "Options:"
      echo "  --output-dir   Directory to write cert/key files (default: stdout)"
      echo "  --subject      X.509 subject (default: $SUBJECT)"
      echo "  --validity     Certificate validity in days (default: $VALIDITY_DAYS)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if ! command -v openssl &>/dev/null; then
  echo -e "${RED}ERROR${NC}: openssl not found. Install it first."
  exit 1
fi

echo "=== SAML SP Key Pair Generation ==="
echo ""
echo "  Subject:  $SUBJECT"
echo "  Validity: $VALIDITY_DAYS days"
echo ""

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Generate RSA private key (2048 bits)
openssl genrsa -out "$TMPDIR/sp-key.pem" 2048 2>/dev/null

# Generate self-signed certificate
openssl req -new -x509 \
  -key "$TMPDIR/sp-key.pem" \
  -out "$TMPDIR/sp-cert.pem" \
  -days "$VALIDITY_DAYS" \
  -subj "$SUBJECT" \
  2>/dev/null

if [[ -n "$OUTPUT_DIR" ]]; then
  mkdir -p "$OUTPUT_DIR"
  cp "$TMPDIR/sp-cert.pem" "$OUTPUT_DIR/saml-sp-cert.pem"
  cp "$TMPDIR/sp-key.pem" "$OUTPUT_DIR/saml-sp-key.pem"
  chmod 600 "$OUTPUT_DIR/saml-sp-key.pem"
  echo -e "${GREEN}Certificate${NC}: $OUTPUT_DIR/saml-sp-cert.pem"
  echo -e "${GREEN}Private Key${NC}: $OUTPUT_DIR/saml-sp-key.pem"
else
  echo "--- SAML_SP_PUBLIC_CERT ---"
  cat "$TMPDIR/sp-cert.pem"
  echo ""
  echo "--- SAML_SP_PRIVATE_KEY ---"
  cat "$TMPDIR/sp-key.pem"
fi

echo ""
echo -e "${GREEN}=== Key Pair Generated ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Store cert in Infisical: MEREKA_LMS_SAML_SP_PUBLIC_CERT"
echo "  2. Store key in Infisical: MEREKA_LMS_SAML_SP_PRIVATE_KEY"
echo "  3. Sync to GCP SM: gcloud secrets create MEREKA_LMS_SAML_SP_PUBLIC_CERT --data-file=sp-cert.pem"
echo "  4. Sync to GCP SM: gcloud secrets create MEREKA_LMS_SAML_SP_PRIVATE_KEY --data-file=sp-key.pem"
echo "  5. ExternalSecrets will auto-sync to K8s (enterprise-sso-secrets)"
echo "  6. Redeploy LMS to pick up the new SAML SP credentials"
