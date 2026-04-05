#!/usr/bin/env bash
# Canonical acceptance front door for the identity-session lane.
#
# Proves tenant cookie domain, session behavior, auth redirect chains,
# and Studio SSO flows independently from routing-core.
#
# Depends on: live cluster access (kubectl) for pod-level checks.
# Ordering: run AFTER runtime-routing acceptance passes (Layer 1 → Layer 2).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ENVIRONMENT="dev"
TENANT_FILTER=""
OUTPUT_DIR=""
DRY_RUN=0
SKIP_COOKIE_PROOF=0
SKIP_AUTH_REDIRECT=0
SKIP_STUDIO_SSO=0

usage() {
  cat <<'EOF'
Usage: scripts/acceptance/identity-session.sh [OPTIONS]

Options:
  --env <production|staging|dev>  Environment to verify
  --tenant <slug>                 Restrict to one tenant
  --output-dir <path>             Override proof bundle path
  --dry-run                       Emit the plan without executing checks
  --skip-cookie-proof             Skip cookie domain verification
  --skip-auth-redirect            Skip auth redirect chain verification
  --skip-studio-sso               Skip Studio SSO flow verification
  -h, --help                      Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENVIRONMENT="${2:?--env requires a value}"; shift 2 ;;
    --tenant) TENANT_FILTER="${2:?--tenant requires a value}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:?--output-dir requires a value}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --skip-cookie-proof) SKIP_COOKIE_PROOF=1; shift ;;
    --skip-auth-redirect) SKIP_AUTH_REDIRECT=1; shift ;;
    --skip-studio-sso) SKIP_STUDIO_SSO=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$ENVIRONMENT" in
  prod) ENVIRONMENT="production" ;;
  production|staging|dev) ;;
  *)
    echo "Invalid --env: $ENVIRONMENT" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$REPO_ROOT/var/acceptance/identity-session/${ENVIRONMENT}/$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$OUTPUT_DIR"

SUMMARY_TSV="$OUTPUT_DIR/checks.tsv"
SUMMARY_JSON="$OUTPUT_DIR/summary.json"
GENERATED_AT_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FAILURES=0
: >"$SUMMARY_TSV"

# ── Load tenant matrix ─────────────────────────────────────────────────
# Reuse the runtime-routing matrix generator for tenant/host information.
MATRIX_PATH="$OUTPUT_DIR/matrix.json"
python3 "$REPO_ROOT/scripts/acceptance/generate_runtime_routing_matrix.py" \
  --env "$ENVIRONMENT" \
  ${TENANT_FILTER:+--tenant "$TENANT_FILTER"} \
  --output "$MATRIX_PATH" >/dev/null

# ── Load env constants ─────────────────────────────────────────────────
ENV_FILE=""
case "$ENVIRONMENT" in
  dev)        ENV_FILE="$REPO_ROOT/scripts/tenants/env/dev.env" ;;
  staging)    ENV_FILE="$REPO_ROOT/scripts/tenants/env/staging.env" ;;
  production) ENV_FILE="$REPO_ROOT/scripts/tenants/env/prod.env" ;;
esac

NAMESPACE=""
PRIMARY_COOKIE_DOMAIN=""
TENANT_COOKIE_MAP=""
if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
  # Source env file in a subshell to extract values safely
  NAMESPACE="$(bash -c "source '$ENV_FILE' 2>/dev/null; echo \"\$NAMESPACE\"")"
  PRIMARY_COOKIE_DOMAIN="$(bash -c "source '$ENV_FILE' 2>/dev/null; echo \"\$PRIMARY_COOKIE_DOMAIN\"")"
  # Extract slug:cookie_domain pairs from TENANTS array
  TENANT_COOKIE_MAP="$(bash -c "
    source '$ENV_FILE' 2>/dev/null
    for t in \"\${TENANTS[@]}\"; do
      IFS=: read -r slug lms studio mfe cookie <<< \"\$t\"
      echo \"\${slug}=\${cookie}\"
    done
  " 2>/dev/null || true)"
fi

record_check() {
  local name="$1" status="$2" rc="$3" log_path="$4"
  printf "%s\t%s\t%s\t%s\n" "$name" "$status" "$rc" "$log_path" >>"$SUMMARY_TSV"
}

# ── Run identity/session proof per tenant ──────────────────────────────
python3 - "$MATRIX_PATH" "$OUTPUT_DIR" "$SKIP_COOKIE_PROOF" "$SKIP_AUTH_REDIRECT" "$SKIP_STUDIO_SSO" "$DRY_RUN" "$SUMMARY_TSV" "$REPO_ROOT" "$NAMESPACE" "$PRIMARY_COOKIE_DOMAIN" "$TENANT_COOKIE_MAP" <<'PY'
import json
import pathlib
import subprocess
import sys
from urllib.parse import urljoin, urlparse

matrix_path = pathlib.Path(sys.argv[1])
output_dir = pathlib.Path(sys.argv[2])
skip_cookie = sys.argv[3] == "1"
skip_auth_redirect = sys.argv[4] == "1"
skip_studio_sso = sys.argv[5] == "1"
dry_run = sys.argv[6] == "1"
summary_tsv = pathlib.Path(sys.argv[7])
repo_root = pathlib.Path(sys.argv[8])
namespace = sys.argv[9]
primary_cookie_domain = sys.argv[10]
tenant_cookie_map_raw = sys.argv[11] if len(sys.argv) > 11 else ""

# Parse slug=cookie_domain pairs from env file
tenant_cookie_domains: dict[str, str] = {}
for line in tenant_cookie_map_raw.strip().splitlines():
    if "=" in line:
        slug, domain = line.split("=", 1)
        tenant_cookie_domains[slug.strip()] = domain.strip()

payload = json.loads(matrix_path.read_text(encoding="utf-8"))
failures = 0


def record(name: str, status: str, rc: int, log_path: pathlib.Path) -> None:
    with summary_tsv.open("a", encoding="utf-8") as handle:
        handle.write(f"{name}\t{status}\t{rc}\t{log_path}\n")


def check_cookie_domain(tenant_slug: str, lms_host: str, expected_cookie_domain: str, log_path: pathlib.Path) -> None:
    """Prove CSRF cookie domain matches tenant expectation."""
    global failures
    import requests

    results = []
    url = f"https://{lms_host}/csrf/api/v1/token"
    try:
        resp = requests.get(url, timeout=15, allow_redirects=False,
                            headers={"User-Agent": "identity-session-accept/1.0"})
        cookies_raw = resp.headers.get("Set-Cookie", "")
        results.append(f"URL: {url}")
        results.append(f"Status: {resp.status_code}")
        results.append(f"Set-Cookie: {cookies_raw}")

        # Extract domain from csrftoken cookie
        cookie_domain = ""
        for part in cookies_raw.split(";"):
            part = part.strip()
            if part.lower().startswith("domain="):
                cookie_domain = part.split("=", 1)[1].strip()
                break

        results.append(f"Extracted cookie domain: {cookie_domain}")
        results.append(f"Expected cookie domain: {expected_cookie_domain}")

        if not expected_cookie_domain:
            results.append("SKIP: no expected cookie domain configured")
            log_path.write_text("\n".join(results) + "\n", encoding="utf-8")
            record(f"cookie-domain:{tenant_slug}", "skip", 0, log_path)
            return

        if cookie_domain == expected_cookie_domain:
            results.append("PASS: cookie domain matches")
            log_path.write_text("\n".join(results) + "\n", encoding="utf-8")
            record(f"cookie-domain:{tenant_slug}", "pass", 0, log_path)
        elif primary_cookie_domain and cookie_domain == primary_cookie_domain and tenant_slug != "mereka":
            results.append(f"FAIL: cookie domain {cookie_domain} is PRIMARY tenant domain (cross-contamination)")
            log_path.write_text("\n".join(results) + "\n", encoding="utf-8")
            record(f"cookie-domain:{tenant_slug}", "fail", 1, log_path)
            failures += 1
        else:
            results.append(f"FAIL: cookie domain {cookie_domain} does not match expected {expected_cookie_domain}")
            log_path.write_text("\n".join(results) + "\n", encoding="utf-8")
            record(f"cookie-domain:{tenant_slug}", "fail", 1, log_path)
            failures += 1
    except Exception as exc:
        results.append(f"ERROR: {exc}")
        log_path.write_text("\n".join(results) + "\n", encoding="utf-8")
        record(f"cookie-domain:{tenant_slug}", "fail", 1, log_path)
        failures += 1


def check_auth_redirect(tenant_slug: str, lms_host: str, expected_mfe_host: str, log_path: pathlib.Path) -> None:
    """Prove /login redirects to the tenant's own MFE authn host."""
    global failures
    import requests

    results = []
    url = f"https://{lms_host}/login"
    try:
        resp = requests.get(url, timeout=20, allow_redirects=False,
                            headers={"User-Agent": "identity-session-accept/1.0"})
        location = resp.headers.get("Location", "")
        results.append(f"URL: {url}")
        results.append(f"Status: {resp.status_code}")
        results.append(f"Location: {location}")
        results.append(f"Expected MFE host: {expected_mfe_host}")

        if not location:
            results.append("FAIL: no Location header on /login")
            log_path.write_text("\n".join(results) + "\n", encoding="utf-8")
            record(f"auth-redirect:{tenant_slug}", "fail", 1, log_path)
            failures += 1
            return

        parsed = urlparse(location if location.startswith("http") else urljoin(url, location))
        redirect_host = parsed.hostname or ""
        redirect_path = parsed.path or ""

        if expected_mfe_host in redirect_host and "/authn" in redirect_path:
            results.append(f"PASS: redirects to {redirect_host}{redirect_path}")
            log_path.write_text("\n".join(results) + "\n", encoding="utf-8")
            record(f"auth-redirect:{tenant_slug}", "pass", 0, log_path)
        else:
            results.append(f"FAIL: redirects to {redirect_host}{redirect_path} (expected {expected_mfe_host}/authn)")
            log_path.write_text("\n".join(results) + "\n", encoding="utf-8")
            record(f"auth-redirect:{tenant_slug}", "fail", 1, log_path)
            failures += 1
    except Exception as exc:
        results.append(f"ERROR: {exc}")
        log_path.write_text("\n".join(results) + "\n", encoding="utf-8")
        record(f"auth-redirect:{tenant_slug}", "fail", 1, log_path)
        failures += 1


def check_studio_sso(tenant_slug: str, lms_host: str, expected_apps_host: str, log_path: pathlib.Path) -> None:
    """Prove Studio SSO /login redirects through LMS to tenant authn."""
    global failures

    sso_script = repo_root / "scripts" / "qa" / "verify-studio-sso-flow.sh"
    if not sso_script.exists():
        log_path.write_text("SKIP: verify-studio-sso-flow.sh not found\n", encoding="utf-8")
        record(f"studio-sso:{tenant_slug}", "skip", 0, log_path)
        return

    result = subprocess.run(
        ["bash", str(sso_script), lms_host, expected_apps_host],
        cwd=repo_root,
        capture_output=True, text=True, timeout=30,
    )
    log_path.write_text(result.stdout + result.stderr, encoding="utf-8")
    if result.returncode == 0:
        record(f"studio-sso:{tenant_slug}", "pass", 0, log_path)
    else:
        record(f"studio-sso:{tenant_slug}", "fail", result.returncode, log_path)
        failures += 1


# ── Process each tenant ────────────────────────────────────────────────
tenants = payload.get("tenants", [])
env_contract = payload.get("environment_contract", {})

for tenant in tenants:
    slug = tenant["tenant"]
    hosts = tenant.get("hosts", {})
    lms_host = hosts.get("primary", "")
    mfe_host = hosts.get("mfe", "")
    studio_host = hosts.get("studio", "")

    # Use env file's TENANTS cookie domain (correct for staging where parent domain is shared).
    # Fall back to ".{lms_host}" if env file doesn't have this tenant.
    expected_cookie_domain = tenant_cookie_domains.get(slug, f".{lms_host}" if lms_host else "")

    tenant_dir = output_dir / slug
    tenant_dir.mkdir(parents=True, exist_ok=True)

    if dry_run:
        checks = []
        if not skip_cookie:
            checks.append(f"cookie-domain:{slug} → https://{lms_host}/csrf/api/v1/token")
        if not skip_auth_redirect:
            checks.append(f"auth-redirect:{slug} → https://{lms_host}/login → {mfe_host}/authn")
        if not skip_studio_sso:
            checks.append(f"studio-sso:{slug} → {lms_host} → {mfe_host}")
        (tenant_dir / "plan.txt").write_text(
            "DRY RUN identity-session\n" + "\n".join(checks) + "\n",
            encoding="utf-8",
        )
        for check_name in checks:
            name = check_name.split(" →")[0]
            record(name, "planned", 0, tenant_dir / "plan.txt")
        continue

    # Cookie domain proof
    if not skip_cookie:
        check_cookie_domain(slug, lms_host, expected_cookie_domain, tenant_dir / "cookie-domain.log")

    # Auth redirect proof
    if not skip_auth_redirect:
        check_auth_redirect(slug, lms_host, mfe_host, tenant_dir / "auth-redirect.log")

    # Studio SSO proof
    if not skip_studio_sso:
        check_studio_sso(slug, lms_host, mfe_host, tenant_dir / "studio-sso.log")

sys.exit(failures)
PY
rc=$?
FAILURES=$((FAILURES + rc))

# ── Emit summary ───────────────────────────────────────────────────────
PASS_COUNT=$(awk -F'\t' '$2=="pass"' "$SUMMARY_TSV" | wc -l)
FAIL_COUNT=$(awk -F'\t' '$2=="fail"' "$SUMMARY_TSV" | wc -l)
SKIP_COUNT=$(awk -F'\t' '$2=="skip"' "$SUMMARY_TSV" | wc -l)
PLAN_COUNT=$(awk -F'\t' '$2=="planned"' "$SUMMARY_TSV" | wc -l)

MODE="execute"
[[ "$DRY_RUN" == "1" ]] && MODE="dry-run"

VERDICT="pass"
[[ "$FAIL_COUNT" -gt 0 ]] && VERDICT="fail"

python3 - "$SUMMARY_JSON" "$VERDICT" "$FAIL_COUNT" "$PASS_COUNT" "$SKIP_COUNT" "$PLAN_COUNT" \
  "$ENVIRONMENT" "$MODE" "$GENERATED_AT_UTC" "$MATRIX_PATH" "$OUTPUT_DIR" "$SUMMARY_TSV" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
verdict = sys.argv[2]
fail_count = int(sys.argv[3])
pass_count = int(sys.argv[4])
skip_count = int(sys.argv[5])
plan_count = int(sys.argv[6])
environment = sys.argv[7]
mode = sys.argv[8]
generated_at = sys.argv[9]
matrix_path = sys.argv[10]
output_dir = sys.argv[11]
tsv_path = sys.argv[12]

checks = []
for line in Path(tsv_path).read_text(encoding="utf-8").strip().splitlines():
    parts = line.split("\t")
    if len(parts) >= 4:
        checks.append({
            "name": parts[0],
            "status": parts[1],
            "exit_code": int(parts[2]),
            "log": parts[3],
        })

summary = {
    "schema_version": "identity-session-proof/v1",
    "generated_at_utc": generated_at,
    "lane": "identity-session",
    "environment": environment,
    "mode": mode,
    "verdict": {
        "status": verdict,
        "failed_checks": fail_count,
        "passed_checks": pass_count,
        "skipped_checks": skip_count,
    },
    "artifacts": {
        "output_dir": output_dir,
        "matrix": matrix_path,
        "checks_tsv": tsv_path,
        "summary_json": str(summary_path),
    },
    "checks": checks,
}

summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
PY

echo "$SUMMARY_JSON"
