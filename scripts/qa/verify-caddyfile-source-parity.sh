#!/usr/bin/env bash
# verify-caddyfile-source-parity.sh
#
# Gate: the Caddyfile in this repo (app-repo source of truth,
# deploy/k8s/base/apps/caddy/Caddyfile) MUST parse to the same canonical
# JSON as the vendored copy in the bbi-infrastructure GitOps repo
# (apps/mereka-lms/base/deploy/k8s/base/apps/caddy/Caddyfile).
#
# Why this exists
# ---------------
# Bead mereka-lms-9o0o tracks the three-layer duplicate writer trap:
#   1. app-repo deploy/k8s/base/...                    — source of truth
#   2. bbi-infra apps/mereka-lms/base/deploy/k8s/base/ — vendored copy
#   3. bbi-infra overlays/{dev,staging,prod}/patches/  — per-env overrides
#
# Vendor-sync PRs copy (1) into (2). Two recent incidents showed that fixes
# land on (2) only and (1) silently drifts until the next sync re-drops
# them (see mereka-lms#2023 which backported GitOps #3733 into the
# app-repo after the drift caused a sign-in regression).
#
# This gate asserts (1) and (2) produce byte-identical canonical Caddy
# JSON when parsed with the same env-var dictionary. Comment formatting
# (en-dash vs --, ellipsis vs ..., provenance comments) is ignored —
# those are cosmetic and survive parse without semantic effect.
#
# How
# ---
# 1. Locate vendored copy:
#    - ${BBI_INFRA_REPO} env var, OR
#    - ../bbi-infrastructure (canonical dev layout), OR
#    - $HOME/projects/k8s/bbi-infrastructure (VPS layout).
#    If not found locally, GITOPS_REF can be a git URL to fetch.
# 2. Run `caddy adapt --adapter caddyfile` on each, feeding the same
#    env-var dictionary so placeholders resolve identically.
# 3. Pass both through `jq -cS .` to canonicalize, md5sum them, compare.
#
# Exit codes
#   0 — parses match byte-for-byte.
#   1 — drift detected (prints the first 30 lines of jq diff).
#   2 — environment / tool error (caddy not found, vendored copy not reachable).
#
# Bead: mereka-lms-9o0o.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

APP_CADDYFILE="deploy/k8s/base/apps/caddy/Caddyfile"
BBI_REL_CADDYFILE="apps/mereka-lms/base/deploy/k8s/base/apps/caddy/Caddyfile"

if ! command -v caddy >/dev/null 2>&1; then
  echo "error: caddy CLI not in PATH — install Caddy locally or skip this gate" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq not in PATH" >&2
  exit 2
fi

# Locate the vendored Caddyfile.
BBI_CADDYFILE=""
if [[ -n "${BBI_INFRA_REPO:-}" && -f "${BBI_INFRA_REPO}/${BBI_REL_CADDYFILE}" ]]; then
  BBI_CADDYFILE="${BBI_INFRA_REPO}/${BBI_REL_CADDYFILE}"
elif [[ -f "../bbi-infrastructure/${BBI_REL_CADDYFILE}" ]]; then
  BBI_CADDYFILE="../bbi-infrastructure/${BBI_REL_CADDYFILE}"
elif [[ -f "${HOME}/projects/k8s/bbi-infrastructure/${BBI_REL_CADDYFILE}" ]]; then
  BBI_CADDYFILE="${HOME}/projects/k8s/bbi-infrastructure/${BBI_REL_CADDYFILE}"
fi

if [[ -z "${BBI_CADDYFILE}" ]]; then
  # Try `gh api` to fetch a single file when GITHUB_TOKEN is available.
  # This lets the gate run in scheduled CI jobs with repo:read access.
  if command -v gh >/dev/null 2>&1 && [[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" || -f "${HOME}/.config/gh/hosts.yml" ]]; then
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    mkdir -p "${tmpdir}/$(dirname "${BBI_REL_CADDYFILE}")"
    if gh api "repos/Biji-Biji-Initiative/bbi-infrastructure/contents/${BBI_REL_CADDYFILE}" \
         --jq .content 2>/dev/null | base64 -d > "${tmpdir}/${BBI_REL_CADDYFILE}" && \
       [[ -s "${tmpdir}/${BBI_REL_CADDYFILE}" ]]; then
      BBI_CADDYFILE="${tmpdir}/${BBI_REL_CADDYFILE}"
    fi
  fi
fi

if [[ -z "${BBI_CADDYFILE}" ]]; then
  # In CI without credentials (e.g. PR-level static validation shard), skip
  # with a warning rather than gating. The canonical place for this gate is
  # a scheduled job where `gh api` has repo read. A warn-and-skip keeps PR
  # CI boring while still catching drift in the scheduled lane.
  if [[ "${CI:-}" = "true" || -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "SKIP: bbi-infrastructure vendored Caddyfile not reachable (no cross-repo token). This gate runs in the scheduled lane."
    exit 0
  fi

  cat >&2 <<EOF
error: bbi-infrastructure vendored Caddyfile not found.

Looked for:
  \${BBI_INFRA_REPO}/${BBI_REL_CADDYFILE}
  ../bbi-infrastructure/${BBI_REL_CADDYFILE}
  \${HOME}/projects/k8s/bbi-infrastructure/${BBI_REL_CADDYFILE}
  gh api fetch (requires GITHUB_TOKEN with bbi-infrastructure repo:read)

Either clone bbi-infrastructure into one of those paths, set BBI_INFRA_REPO,
or ensure \`gh auth status\` shows an authenticated host with bbi-infrastructure
visibility.
EOF
  exit 2
fi

# Common env dictionary — any hostname is fine; they just need to be consistent.
ADAPT_ENV=(
  LMS_HOST=parity.example
  LMS_HOST_PREVIEW=preview.parity.example
  STUDIO_HOST=studio.parity.example
  MFE_HOST=apps.parity.example
  DISCOVERY_HOST=discovery.parity.example
  NOTES_HOST=notes.parity.example
  CREDENTIALS_HOST=credentials.parity.example
  ENTERPRISE_ADMIN_HOST=admin.parity.example
  ENTERPRISE_LEARNER_HOST=learner.parity.example
  default_site_port=":8080"
)

canonicalize() {
  local f="$1"
  env "${ADAPT_ENV[@]}" caddy adapt --config "$f" --adapter caddyfile 2>/dev/null \
    | jq -cS .
}

app_json=$(canonicalize "${APP_CADDYFILE}")
bbi_json=$(canonicalize "${BBI_CADDYFILE}")

if [[ -z "${app_json}" ]]; then
  echo "error: canonicalizing ${APP_CADDYFILE} produced no output — does Caddy accept this file?" >&2
  exit 2
fi
if [[ -z "${bbi_json}" ]]; then
  echo "error: canonicalizing ${BBI_CADDYFILE} produced no output — does Caddy accept this file?" >&2
  exit 2
fi

app_md5=$(echo "${app_json}" | md5sum | awk '{print $1}')
bbi_md5=$(echo "${bbi_json}" | md5sum | awk '{print $1}')

if [[ "${app_md5}" = "${bbi_md5}" ]]; then
  printf 'PASS: Caddyfile source parity — app-repo and bbi-infrastructure vendored copy match (md5=%s).\n' "${app_md5}"
  exit 0
fi

{
  echo "FAIL: Caddyfile source-of-truth drift detected."
  echo "  app-repo   : ${APP_CADDYFILE}  md5=${app_md5}"
  echo "  vendored   : ${BBI_CADDYFILE}  md5=${bbi_md5}"
  echo
  echo "First 30 lines of canonical-JSON diff:"
  diff <(echo "${app_json}" | jq -S . 2>/dev/null || true) <(echo "${bbi_json}" | jq -S . 2>/dev/null || true) | head -30
  echo
  echo "Resolution — three-layer duplicate writer trap (bead mereka-lms-9o0o):"
  echo "  If the vendored copy has the fix: backport to the app-repo source and"
  echo "  open a PR against mereka-lms."
  echo "  If the app-repo has the fix: open a vendor-sync PR against"
  echo "  bbi-infrastructure."
  echo "  Do NOT 'fix' this gate by editing only one side again."
} >&2

exit 1
