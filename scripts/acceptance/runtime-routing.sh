#!/usr/bin/env bash
# Canonical acceptance front door for the runtime-routing lane.
#
# Wraps the existing real oracles:
# - env-specific runtime proof script from tenant-registry.yaml
# - Playwright unauthenticated/branding/selector checks
# - Studio SSO redirect verification
# - Footer parity live verification
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ENVIRONMENT="dev"
TENANT_FILTER=""
OUTPUT_DIR=""
DRY_RUN=0
SKIP_RUNTIME_PROOF=0
SKIP_PLAYWRIGHT=0
SKIP_STUDIO_SSO=0
SKIP_FOOTER=0

usage() {
  cat <<'EOF'
Usage: scripts/acceptance/runtime-routing.sh [OPTIONS]

Options:
  --env <production|staging|dev|profiles-dev|local>  Environment contract to verify
  --tenant <slug>                                    Restrict to one tenant
  --output-dir <path>                                Override proof bundle path
  --dry-run                                          Emit the plan without executing checks
  --skip-runtime-proof                               Skip env runtime-proof script
  --skip-playwright                                  Skip Playwright browser checks
  --skip-studio-sso                                  Skip Studio SSO redirect check
  --skip-footer                                      Skip footer parity live check
  -h, --help                                         Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENVIRONMENT="${2:?--env requires a value}"; shift 2 ;;
    --tenant) TENANT_FILTER="${2:?--tenant requires a value}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:?--output-dir requires a value}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --skip-runtime-proof) SKIP_RUNTIME_PROOF=1; shift ;;
    --skip-playwright) SKIP_PLAYWRIGHT=1; shift ;;
    --skip-studio-sso) SKIP_STUDIO_SSO=1; shift ;;
    --skip-footer) SKIP_FOOTER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$ENVIRONMENT" in
  prod) ENVIRONMENT="production" ;;
  production|staging|dev|profiles-dev|local) ;;
  *)
    echo "Invalid --env: $ENVIRONMENT" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$REPO_ROOT/var/acceptance/runtime-routing/${ENVIRONMENT}/$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$OUTPUT_DIR"

MATRIX_PATH="$OUTPUT_DIR/browser-matrix.json"
SUMMARY_TSV="$OUTPUT_DIR/checks.tsv"
SUMMARY_JSON="$OUTPUT_DIR/summary.json"
TRUTH_LEDGER_JSON="$OUTPUT_DIR/truth-ledger.json"
CANONICAL_TRUTH_LEDGER_JSON="$REPO_ROOT/generated/truth-ledger/runtime-routing/${ENVIRONMENT}/${TENANT_FILTER:-all}.json"
GENERATED_AT_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FAILURES=0
: >"$SUMMARY_TSV"

python3 "$REPO_ROOT/scripts/acceptance/generate_runtime_routing_matrix.py" \
  --env "$ENVIRONMENT" \
  ${TENANT_FILTER:+--tenant "$TENANT_FILTER"} \
  --output "$MATRIX_PATH" >/dev/null

run_check() {
  local name="$1"
  local log_path="$2"
  shift 2

  if [[ "$DRY_RUN" == "1" ]]; then
    {
      printf "DRY RUN: %s\n" "$name"
      printf "CMD: "
      printf "%q " "$@"
      printf "\n"
    } >"$log_path"
    printf "%s\tplanned\t0\t%s\n" "$name" "$log_path" >>"$SUMMARY_TSV"
    return 0
  fi

  if "$@" >"$log_path" 2>&1; then
    printf "%s\tpass\t0\t%s\n" "$name" "$log_path" >>"$SUMMARY_TSV"
  else
    local rc=$?
    printf "%s\tfail\t%s\t%s\n" "$name" "$rc" "$log_path" >>"$SUMMARY_TSV"
    return "$rc"
  fi
}

RUNTIME_PROOF_SCRIPT="$(
  python3 - "$MATRIX_PATH" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(payload["environment_contract"].get("runtime_proof_script", ""))
PY
)"

if [[ "$SKIP_RUNTIME_PROOF" == "0" && -n "$RUNTIME_PROOF_SCRIPT" ]]; then
  run_check \
    "runtime-proof:${ENVIRONMENT}" \
    "$OUTPUT_DIR/runtime-proof.log" \
    bash "$REPO_ROOT/$RUNTIME_PROOF_SCRIPT" --output-dir "$OUTPUT_DIR/runtime-proof" || FAILURES=$((FAILURES + 1))
fi

if python3 - "$MATRIX_PATH" "$OUTPUT_DIR" "$SKIP_PLAYWRIGHT" "$SKIP_STUDIO_SSO" "$SKIP_FOOTER" "$DRY_RUN" "$SUMMARY_TSV" "$REPO_ROOT" <<'PY'
import json
import pathlib
import subprocess
import sys
from urllib.parse import urljoin, urlparse

matrix_path = pathlib.Path(sys.argv[1])
output_dir = pathlib.Path(sys.argv[2])
skip_playwright = sys.argv[3] == "1"
skip_studio_sso = sys.argv[4] == "1"
skip_footer = sys.argv[5] == "1"
dry_run = sys.argv[6] == "1"
summary_tsv = pathlib.Path(sys.argv[7])
repo_root = pathlib.Path(sys.argv[8])

payload = json.loads(matrix_path.read_text(encoding="utf-8"))
failures = 0
playwright_bootstrapped = False

def record(name: str, status: str, rc: int, log_path: pathlib.Path) -> None:
    with summary_tsv.open("a", encoding="utf-8") as handle:
        handle.write(f"{name}\t{status}\t{rc}\t{log_path}\n")

def execute(name: str, command: list[str], log_path: pathlib.Path) -> None:
    global failures
    if dry_run:
      log_path.write_text(
          "DRY RUN: " + name + "\nCMD: " + " ".join(command) + "\n",
          encoding="utf-8",
      )
      record(name, "planned", 0, log_path)
      return
    with log_path.open("w", encoding="utf-8") as handle:
      result = subprocess.run(command, cwd=repo_root, stdout=handle, stderr=subprocess.STDOUT, text=True, check=False)
    record(name, "pass" if result.returncode == 0 else "fail", result.returncode, log_path)
    if result.returncode != 0:
      failures += 1

def final_host_for(url: str) -> str:
    import requests

    session = requests.Session()
    response = session.get(
        url,
        allow_redirects=True,
        timeout=20,
        headers={"User-Agent": "runtime-routing-accept/1.0"},
    )
    return urlparse(response.url).hostname or ""

def redirect_hosts_for(url: str) -> list[str]:
    import requests

    session = requests.Session()
    response = session.get(
        url,
        allow_redirects=True,
        timeout=20,
        headers={"User-Agent": "runtime-routing-accept/1.0"},
    )
    hosts: list[str] = []
    current_url = url
    for hop in list(response.history) + [response]:
        parsed = urlparse(hop.url or current_url)
        host = parsed.hostname or ""
        if host:
            hosts.append(host)
        location = hop.headers.get("location")
        if location:
            current_url = urljoin(hop.url or current_url, location)
    return hosts

def run_contract_assertions(tenant: dict, log_path: pathlib.Path) -> None:
    global failures

    if dry_run:
        log_path.write_text(
            "DRY RUN: contract assertions\n"
            + "\n".join(
                f"{assertion['id']} {assertion['kind']} {assertion['url']}"
                for assertion in tenant.get("assertions", [])
            )
            + "\n",
            encoding="utf-8",
        )
        record(f"contract:{tenant['tenant']}", "planned", 0, log_path)
        return

    lines: list[str] = []
    tenant_failures = 0

    for assertion in tenant.get("assertions", []):
        assertion_id = assertion["id"]
        url = assertion["url"]
        kind = assertion["kind"]
        try:
            hosts = redirect_hosts_for(url)
            final_host = final_host_for(url)
        except Exception as exc:
            tenant_failures += 1
            lines.append(f"FAIL {assertion_id}: request error for {url}: {exc}")
            continue

        if kind == "redirect-contract":
            expected = assertion["expect_final_host"]
            forbidden = set(assertion.get("forbid_hosts", []))
            bad_hosts = [host for host in hosts if host in forbidden]
            if final_host == expected and not bad_hosts:
                lines.append(f"PASS {assertion_id}: final_host={final_host} chain={hosts}")
            else:
                tenant_failures += 1
                lines.append(
                    f"FAIL {assertion_id}: expected final_host={expected}, got {final_host}; forbidden_seen={bad_hosts}; chain={hosts}"
                )
        elif kind == "host-stability":
            expected = assertion["expect_host"]
            forbidden = set(assertion.get("forbid_redirect_hosts", []))
            bad_hosts = [host for host in hosts if host in forbidden]
            if final_host == expected and not bad_hosts:
                lines.append(f"PASS {assertion_id}: final_host={final_host} chain={hosts}")
            else:
                tenant_failures += 1
                lines.append(
                    f"FAIL {assertion_id}: expected final_host={expected}, got {final_host}; forbidden_seen={bad_hosts}; chain={hosts}"
                )
        elif kind == "sso-contract":
            expected = assertion["expect_apps_host"]
            forbidden = set(assertion.get("forbid_hosts", []))
            bad_hosts = [host for host in hosts if host in forbidden]
            if final_host == expected and not bad_hosts:
                lines.append(f"PASS {assertion_id}: final_host={final_host} chain={hosts}")
            else:
                tenant_failures += 1
                lines.append(
                    f"FAIL {assertion_id}: expected final_host={expected}, got {final_host}; forbidden_seen={bad_hosts}; chain={hosts}"
                )
        else:
            lines.append(f"SKIP {assertion_id}: unsupported assertion kind {kind}")

    log_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    record(
        f"contract:{tenant['tenant']}",
        "pass" if tenant_failures == 0 else "fail",
        tenant_failures,
        log_path,
    )
    if tenant_failures:
        failures += tenant_failures

for tenant in payload["tenants"]:
    slug = tenant["tenant"]
    base_url = tenant.get("playwright_base_url")
    lms_host = tenant.get("studio_sso_entry_domain")
    footer = tenant.get("footer_probe", {})
    selector_routes = tenant.get("playwright_selector_audit_routes", [])
    tenant_dir = output_dir / slug
    tenant_dir.mkdir(parents=True, exist_ok=True)

    run_contract_assertions(tenant, tenant_dir / "contract.log")

    if not skip_playwright and base_url:
        env = {
            **dict(__import__("os").environ),
            "BASE_URL": base_url,
            "SELECTOR_AUDIT_ROUTES": ",".join(selector_routes),
        }
        e2e_dir = repo_root / "tests" / "e2e"
        playwright_pkg = e2e_dir / "node_modules" / "@playwright" / "test"
        if dry_run:
            (tenant_dir / "playwright.log").write_text(
                "DRY RUN: playwright:" + slug + "\n"
                + f"BASE_URL={base_url}\n"
                + "SELECTOR_AUDIT_ROUTES=" + ",".join(selector_routes) + "\n"
                + "CMD: (cd tests/e2e && npx playwright test tests/smoke-unauthenticated.spec.ts "
                  "tests/branding-smoke.spec.ts tests/selector-dom-audit.spec.ts --config playwright.config.ts)\n",
                encoding="utf-8",
            )
            record(f"playwright:{slug}", "planned", 0, tenant_dir / "playwright.log")
        else:
            if not playwright_pkg.exists() and not playwright_bootstrapped:
                bootstrap_log = output_dir / "playwright-bootstrap.log"
                with bootstrap_log.open("w", encoding="utf-8") as handle:
                    bootstrap = subprocess.run(
                        ["npm", "ci"],
                        cwd=e2e_dir,
                        stdout=handle,
                        stderr=subprocess.STDOUT,
                        text=True,
                        check=False,
                    )
                record(
                    "playwright-bootstrap",
                    "pass" if bootstrap.returncode == 0 else "fail",
                    bootstrap.returncode,
                    bootstrap_log,
                )
                if bootstrap.returncode != 0:
                    failures += 1
                    playwright_bootstrapped = True
                    continue
                playwright_bootstrapped = True
            with (tenant_dir / "playwright.log").open("w", encoding="utf-8") as handle:
                result = subprocess.run(
                    [
                        "npx",
                        "playwright",
                        "test",
                        "tests/smoke-unauthenticated.spec.ts",
                        "tests/branding-smoke.spec.ts",
                        "tests/selector-dom-audit.spec.ts",
                        "--config",
                        "playwright.config.ts",
                    ],
                    cwd=e2e_dir,
                    env=env,
                    stdout=handle,
                    stderr=subprocess.STDOUT,
                    text=True,
                    check=False,
                )
            record(f"playwright:{slug}", "pass" if result.returncode == 0 else "fail", result.returncode, tenant_dir / "playwright.log")
            if result.returncode != 0:
                failures += 1

    if not skip_studio_sso and lms_host:
        execute(
            f"studio-sso:{slug}",
            ["bash", "scripts/qa/verify-studio-sso-flow.sh", lms_host],
            tenant_dir / "studio-sso.log",
        )

    lms_url = footer.get("lms_url")
    mfe_url = footer.get("mfe_url")
    if not skip_footer and lms_url and mfe_url:
        execute(
            f"footer:{slug}",
            ["bash", "scripts/qa/verify-footer-parity.sh", "--live", "--lms-url", lms_url, "--mfe-url", mfe_url],
            tenant_dir / "footer.log",
        )

raise SystemExit(failures)
PY
then
  PYTHON_RC=0
else
  PYTHON_RC=$?
fi
if [[ "$PYTHON_RC" -ne 0 ]]; then
  FAILURES=$((FAILURES + PYTHON_RC))
fi

python3 - "$MATRIX_PATH" "$SUMMARY_TSV" "$SUMMARY_JSON" "$ENVIRONMENT" "$TENANT_FILTER" "$DRY_RUN" "$FAILURES" "$GENERATED_AT_UTC" "$OUTPUT_DIR" "$CANONICAL_TRUTH_LEDGER_JSON" <<'PY'
import json
import sys
from pathlib import Path

matrix_path = Path(sys.argv[1])
summary_tsv = Path(sys.argv[2])
summary_json = Path(sys.argv[3])
environment = sys.argv[4]
tenant_filter = sys.argv[5] or None
dry_run = sys.argv[6] == "1"
failures = int(sys.argv[7])
generated_at_utc = sys.argv[8]
output_dir = Path(sys.argv[9])
canonical_truth_ledger_json = Path(sys.argv[10])
matrix = json.loads(matrix_path.read_text(encoding="utf-8"))

checks = []
for line in summary_tsv.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    name, status, exit_code, log_path = line.split("\t", 3)
    checks.append(
        {
            "name": name,
            "status": status,
            "exit_code": int(exit_code),
            "log": log_path,
        }
    )

payload = {
    "schema_version": "runtime-routing-proof/v1",
    "generated_at_utc": generated_at_utc,
    "lane": "runtime-routing",
    "environment": environment,
    "tenant_filter": tenant_filter,
    "mode": "dry-run" if dry_run else "execute",
    "verdict": {
        "status": "pass" if failures == 0 else "fail",
        "failed_checks": failures,
    },
    "contract": {
        "matrix_path": str(matrix_path),
        "source": matrix.get("source"),
        "source_version": matrix.get("source_version"),
        "schema_version": matrix.get("schema_version"),
    },
    "artifacts": {
        "output_dir": str(output_dir),
        "matrix": str(matrix_path),
        "checks_tsv": str(summary_tsv),
        "summary_json": str(summary_json),
        "truth_ledger_json": str(output_dir / "truth-ledger.json"),
        "canonical_truth_ledger_json": str(canonical_truth_ledger_json),
    },
    "matrix": matrix,
    "checks": checks,
}
summary_json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

ARGO_APP=""
TARGET_NAMESPACE=""
case "$ENVIRONMENT" in
  dev|profiles-dev)
    ARGO_APP="mereka-lms-dev"
    TARGET_NAMESPACE="mereka-lms-dev"
    ;;
  staging)
    ARGO_APP="mereka-lms-staging"
    TARGET_NAMESPACE="mereka-lms-staging"
    ;;
  production)
    ARGO_APP="mereka-lms"
    TARGET_NAMESPACE="mereka-lms"
    ;;
esac

LEDGER_ARGS=(
  --summary-json "$SUMMARY_JSON"
  --output "$CANONICAL_TRUTH_LEDGER_JSON"
)
if APP_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"; then
  LEDGER_ARGS+=(--app-sha "$APP_SHA")
fi
[[ -n "${TRUTH_LEDGER_INFRA_COMMIT_SHA:-}" ]] && LEDGER_ARGS+=(--infra-commit-sha "$TRUTH_LEDGER_INFRA_COMMIT_SHA")
[[ -n "${TRUTH_LEDGER_RELEASE_OPENEDX_IMAGE:-}" ]] && LEDGER_ARGS+=(--release-openedx-image "$TRUTH_LEDGER_RELEASE_OPENEDX_IMAGE")
[[ -n "${TRUTH_LEDGER_RELEASE_MFE_IMAGE:-}" ]] && LEDGER_ARGS+=(--release-mfe-image "$TRUTH_LEDGER_RELEASE_MFE_IMAGE")
[[ -n "$ARGO_APP" ]] && LEDGER_ARGS+=(--argo-app "$ARGO_APP")
[[ -n "$TARGET_NAMESPACE" ]] && LEDGER_ARGS+=(--namespace "$TARGET_NAMESPACE")
python3 "$REPO_ROOT/scripts/release/generate_truth_ledger.py" "${LEDGER_ARGS[@]}" >/dev/null
cp "$CANONICAL_TRUTH_LEDGER_JSON" "$TRUTH_LEDGER_JSON"

echo "$SUMMARY_JSON"
if [[ "$FAILURES" -ne 0 ]]; then
  exit 1
fi
