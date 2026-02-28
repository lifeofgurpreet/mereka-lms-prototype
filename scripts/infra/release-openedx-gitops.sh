#!/usr/bin/env bash
# @covers AC-014, AC-021
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP_BASE_REL="deploy/k8s/base/kustomization.yaml"
APP_PROD_REL="deploy/k8s/overlays/production/kustomization.yaml"
APP_STAGING_REL="deploy/k8s/overlays/staging/kustomization.yaml"
INFRA_BASE_REL="apps/mereka-lms/base/kustomization.yaml"
INFRA_PROD_REL="apps/mereka-lms/overlays/prod/kustomization.yaml"
INFRA_STAGING_REL="apps/mereka-lms/overlays/staging/kustomization.yaml"

APP_REPO="${APP_REPO:-$REPO_ROOT}"
INFRA_REPO="${INFRA_REPO:-}"
OPENEDX_TAG=""
MFE_TAG=""
OPENEDX_DIGEST=""
MFE_DIGEST=""
REQUIRE_DIGESTS=0
APP_SHA_OVERRIDE=""
TARGET_ENV="production"
TARGET_ENV_SET=0
UPDATE_BASE_REF_MODE="auto" # auto|1|0

APPLY=0
COMMIT=0
PUSH=0
VERIFY_RUNTIME=0
ENFORCE_ENTERPRISE_SITE_MAPPING_GUARD="${ENFORCE_ENTERPRISE_SITE_MAPPING_GUARD:-1}"
RUN_ENTERPRISE_READINESS_INTEGRITY_GUARD="${RUN_ENTERPRISE_READINESS_INTEGRITY_GUARD:-1}"
RUN_ENTERPRISE_SSO_RUNTIME_GUARD="${RUN_ENTERPRISE_SSO_RUNTIME_GUARD:-1}"
RUN_ENTERPRISE_SCHEMA_GUARD="${RUN_ENTERPRISE_SCHEMA_GUARD:-1}"
RUN_ENTERPRISE_RUNTIME_APP_GUARD="${RUN_ENTERPRISE_RUNTIME_APP_GUARD:-1}"
RUN_BRANDING_RUNTIME_GUARD="${RUN_BRANDING_RUNTIME_GUARD:-1}"
RUN_PARAGON_RUNTIME_GUARD="${RUN_PARAGON_RUNTIME_GUARD:-1}"
RUN_BRANDING_SURFACE_AUDIT="${RUN_BRANDING_SURFACE_AUDIT:-1}"
RUN_FOOTER_RUNTIME_GUARD="${RUN_FOOTER_RUNTIME_GUARD:-1}"
RUN_MFE_ROUTE_RUNTIME_GUARD="${RUN_MFE_ROUTE_RUNTIME_GUARD:-1}"
RUN_MFE_ROUTE_SMOKE_GUARD="${RUN_MFE_ROUTE_SMOKE_GUARD:-1}"
RUN_FRONTEND_CACHE_PURGE="${RUN_FRONTEND_CACHE_PURGE:-0}"
FRONTEND_CACHE_PURGE_EVERYTHING="${FRONTEND_CACHE_PURGE_EVERYTHING:-0}"
FRONTEND_CACHE_ENV="${FRONTEND_CACHE_ENV:-auto}"
ENTERPRISE_READINESS_TENANT="${ENTERPRISE_READINESS_TENANT:-mereka}"
PARAGON_RUNTIME_URL="${PARAGON_RUNTIME_URL:-}"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGO_APP="${ARGO_APP:-auto}"
APP_NAMESPACE="${APP_NAMESPACE:-mereka-lms}"
WAIT_SECONDS="${WAIT_SECONDS:-600}"

usage() {
  cat <<'EOF'
Usage:
  scripts/infra/release-openedx-gitops.sh --openedx-tag TAG --mfe-tag TAG [options]

Purpose:
  Canonical one-command release orchestration for Open edX images:
  1) Update app repo image tags (overlay for target env, plus base for production)
  2) Update GitOps repo (overlay for target env, plus optional base ref bump)
  3) Verify image override contract (production mode enforces cross-repo contract)
  4) Optionally commit/push both repos and verify runtime convergence

Options:
  --openedx-tag TAG     Required. openedx image tag.
  --mfe-tag TAG         Required. openedx-mfe image tag.
  --openedx-digest DIGEST Optional image digest (sha256:...) for openedx.
  --mfe-digest DIGEST   Optional image digest (sha256:...) for openedx-mfe.
  --require-digests     Fail unless both openedx/mfe digests are provided.
  --target-env ENV      Target environment: production|staging (default: production).
  --app-repo PATH       Override app repo path (default: current repo root).
  --infra-repo PATH     Override GitOps repo path.
  --app-sha SHA         Override app SHA to pin in GitOps base ref.
  --update-base-ref     Force update GitOps base ref to app SHA.
  --skip-base-ref       Skip GitOps base ref update.
                       Default: update for production, skip for staging.

  --apply               Write file changes (default: dry-run).
  --commit              Commit changed files in app + GitOps repos (requires --apply).
  --push                Push app + GitOps repos (requires --commit).
  --verify-runtime      Poll Argo + deployment image until target tag is live.
  --skip-enterprise-site-mapping-guard
                       Skip STRICT multisite enterprise UUID runtime preflight.
  --skip-enterprise-readiness-integrity-guard
                       Skip static enterprise readiness integrity preflight.
  --skip-enterprise-sso-runtime-guard
                       Skip enterprise SSO runtime readiness preflight.
  --skip-enterprise-runtime-app-guard
                       Skip enterprise runtime app wiring preflight.
  --skip-enterprise-schema-guard
                       Skip enterprise schema integrity preflight.
  --skip-branding-runtime-guard
                       Skip post-rollout runtime branding verification guard.
  --skip-paragon-runtime-guard
                       Skip strict runtime PARAGON_THEME_URLS verification guard.
  --skip-branding-surface-audit
                       Skip strict branding surface audit after runtime branding verification.
  --skip-footer-runtime-guard
                       Skip live footer parity runtime verification guard.
  --skip-mfe-route-runtime-guard
                       Skip strict runtime MFE route contract verification guard.
  --skip-mfe-route-smoke-guard
                       Skip runtime MFE route HTTP smoke guard.
  --purge-frontend-cache
                       Run frontend/theme cache purge helper after rollout checks.
                       Uses dry-run unless --apply is set.
  --purge-frontend-cache-everything
                       Purge entire Cloudflare zone cache (high impact).
                       Implies --purge-frontend-cache.
  --frontend-cache-env ENV
                       Cache purge environment: auto|prod|dev (default: auto).
                       auto maps production->prod, staging->dev.
  --enterprise-readiness-tenant SLUG
                       Tenant slug used for enterprise SSO runtime readiness preflight.
  --paragon-runtime-url URL
                       Override runtime PARAGON theme origin for post-rollout validation
                       (default: https://apps.academyv2.mereka.io in production).

  --k8s-context NAME    Kubernetes context for runtime verification.
  --argocd-namespace NS ArgoCD namespace (default: argocd).
  --argocd-app NAME     ArgoCD application name (default: auto; production prefers mereka-lms-prod then mereka-lms-local).
  --namespace NS        App namespace for deployment checks (default: mereka-lms).
  --wait-seconds N      Max wait for runtime verification (default: 600).
  -h, --help            Show this help.

Examples:
  # Dry-run preview
  ./scripts/infra/release-openedx-gitops.sh --openedx-tag 20260208-openedx-a --mfe-tag 20260208-mfe-b

  # Apply + commit production rollout (with required runtime verification guards)
  ./scripts/infra/release-openedx-gitops.sh --openedx-tag 20260208-openedx-a --mfe-tag 20260208-mfe-b \
    --apply --commit --verify-runtime

  # Full production automation (apply, commit, push, runtime verify)
  ./scripts/infra/release-openedx-gitops.sh --openedx-tag 20260208-openedx-a --mfe-tag 20260208-mfe-b \
    --apply --commit --push --verify-runtime

  # Production with immutable digests
  ./scripts/infra/release-openedx-gitops.sh --openedx-tag 20260208-openedx-a --mfe-tag 20260208-mfe-b \
    --openedx-digest sha256:<openedx_digest> --mfe-digest sha256:<mfe_digest> \
    --apply --commit --push --verify-runtime

  # Staging-only tag update (no base-ref bump by default)
  ./scripts/infra/release-openedx-gitops.sh --target-env staging \
    --openedx-tag 20260208-openedx-a --mfe-tag 20260208-mfe-b \
    --apply --commit --push
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openedx-tag)
      OPENEDX_TAG="${2:-}"
      shift 2
      ;;
    --mfe-tag)
      MFE_TAG="${2:-}"
      shift 2
      ;;
    --openedx-digest)
      OPENEDX_DIGEST="${2:-}"
      shift 2
      ;;
    --mfe-digest)
      MFE_DIGEST="${2:-}"
      shift 2
      ;;
    --require-digests)
      REQUIRE_DIGESTS=1
      shift
      ;;
    --target-env)
      TARGET_ENV="${2:-}"
      TARGET_ENV_SET=1
      shift 2
      ;;
    --app-repo)
      APP_REPO="${2:-}"
      shift 2
      ;;
    --infra-repo)
      INFRA_REPO="${2:-}"
      shift 2
      ;;
    --app-sha)
      APP_SHA_OVERRIDE="${2:-}"
      shift 2
      ;;
    --update-base-ref)
      UPDATE_BASE_REF_MODE="1"
      shift
      ;;
    --skip-base-ref)
      UPDATE_BASE_REF_MODE="0"
      shift
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    --commit)
      COMMIT=1
      shift
      ;;
    --push)
      PUSH=1
      shift
      ;;
    --verify-runtime)
      VERIFY_RUNTIME=1
      shift
      ;;
    --skip-enterprise-site-mapping-guard)
      ENFORCE_ENTERPRISE_SITE_MAPPING_GUARD=0
      shift
      ;;
    --skip-enterprise-readiness-integrity-guard)
      RUN_ENTERPRISE_READINESS_INTEGRITY_GUARD=0
      shift
      ;;
    --skip-enterprise-sso-runtime-guard)
      RUN_ENTERPRISE_SSO_RUNTIME_GUARD=0
      shift
      ;;
    --skip-enterprise-runtime-app-guard)
      RUN_ENTERPRISE_RUNTIME_APP_GUARD=0
      shift
      ;;
    --skip-enterprise-schema-guard)
      RUN_ENTERPRISE_SCHEMA_GUARD=0
      shift
      ;;
    --skip-branding-runtime-guard)
      RUN_BRANDING_RUNTIME_GUARD=0
      shift
      ;;
    --skip-paragon-runtime-guard)
      RUN_PARAGON_RUNTIME_GUARD=0
      shift
      ;;
    --skip-branding-surface-audit)
      RUN_BRANDING_SURFACE_AUDIT=0
      shift
      ;;
    --skip-footer-runtime-guard)
      RUN_FOOTER_RUNTIME_GUARD=0
      shift
      ;;
    --skip-mfe-route-runtime-guard)
      RUN_MFE_ROUTE_RUNTIME_GUARD=0
      shift
      ;;
    --skip-mfe-route-smoke-guard)
      RUN_MFE_ROUTE_SMOKE_GUARD=0
      shift
      ;;
    --purge-frontend-cache)
      RUN_FRONTEND_CACHE_PURGE=1
      shift
      ;;
    --purge-frontend-cache-everything)
      RUN_FRONTEND_CACHE_PURGE=1
      FRONTEND_CACHE_PURGE_EVERYTHING=1
      shift
      ;;
    --frontend-cache-env)
      FRONTEND_CACHE_ENV="${2:-}"
      shift 2
      ;;
    --enterprise-readiness-tenant)
      ENTERPRISE_READINESS_TENANT="${2:-}"
      shift 2
      ;;
    --paragon-runtime-url)
      PARAGON_RUNTIME_URL="${2:-}"
      shift 2
      ;;
    --k8s-context)
      K8S_CONTEXT="${2:-}"
      shift 2
      ;;
    --argocd-namespace)
      ARGOCD_NAMESPACE="${2:-}"
      shift 2
      ;;
    --argocd-app)
      ARGO_APP="${2:-}"
      shift 2
      ;;
    --namespace)
      APP_NAMESPACE="${2:-}"
      shift 2
      ;;
    --wait-seconds)
      WAIT_SECONDS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$OPENEDX_TAG" || -z "$MFE_TAG" ]]; then
  echo "Both --openedx-tag and --mfe-tag are required." >&2
  usage
  exit 1
fi

validate_digest() {
  local digest="$1"
  local label="$2"
  if [[ -z "$digest" ]]; then
    return 0
  fi
  if [[ ! "$digest" =~ ^sha256:[0-9a-fA-F]{64}$ ]]; then
    echo "Invalid $label digest format: $digest (expected sha256:<64-hex>)" >&2
    exit 1
  fi
}

validate_digest "$OPENEDX_DIGEST" "openedx"
validate_digest "$MFE_DIGEST" "openedx-mfe"

if [[ "$REQUIRE_DIGESTS" -eq 1 && ( -z "$OPENEDX_DIGEST" || -z "$MFE_DIGEST" ) ]]; then
  echo "--require-digests requires both --openedx-digest and --mfe-digest." >&2
  exit 1
fi

if [[ "$COMMIT" -eq 1 && "$APPLY" -ne 1 ]]; then
  echo "--commit requires --apply." >&2
  exit 1
fi

if [[ "$PUSH" -eq 1 && "$COMMIT" -ne 1 ]]; then
  echo "--push requires --commit." >&2
  exit 1
fi

normalize_target_env() {
  local env_lc
  env_lc="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  case "$env_lc" in
    prod|production)
      echo "production"
      ;;
    stage|staging)
      echo "staging"
      ;;
    *)
      echo "Unsupported --target-env: $1 (expected production|staging)" >&2
      exit 1
      ;;
  esac
}

detect_infra_repo() {
  if [[ -n "$INFRA_REPO" ]]; then
    return
  fi
  for candidate in \
    /home/gurpreet/projects/k8s/infrastructure \
    /home/gurpreet/projects/k8s/bbi-infrastructure; do
    if [[ -f "$candidate/$INFRA_BASE_REL" && -f "$candidate/$INFRA_PROD_REL" ]]; then
      INFRA_REPO="$candidate"
      return
    fi
  done
  echo "Unable to detect GitOps repo. Pass --infra-repo PATH." >&2
  exit 1
}

require_git_repo() {
  local repo="$1"
  if [[ ! -d "$repo/.git" ]]; then
    echo "Not a git repo: $repo" >&2
    exit 1
  fi
}

update_image_tags_file() {
  local file="$1"
  local openedx_tag="$2"
  local mfe_tag="$3"
  local openedx_digest="$4"
  local mfe_digest="$5"
  local apply="$6"
  local required_names_csv="$7"

  python3 - "$file" "$openedx_tag" "$mfe_tag" "$openedx_digest" "$mfe_digest" "$apply" "$required_names_csv" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
openedx_tag = sys.argv[2]
mfe_tag = sys.argv[3]
openedx_digest = sys.argv[4]
mfe_digest = sys.argv[5]
apply = sys.argv[6] == "1"
required_names = [name for name in sys.argv[7].split(",") if name]

if not path.exists():
    raise SystemExit(f"missing file: {path}")

targets = {
    "docker.io/overhangio/openedx": openedx_tag,
    "docker.io/overhangio/openedx-mfe": mfe_tag,
    "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx": openedx_tag,
    "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe": mfe_tag,
}
digest_targets = {
    "docker.io/overhangio/openedx": openedx_digest,
    "docker.io/overhangio/openedx-mfe": mfe_digest,
    "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx": openedx_digest,
    "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe": mfe_digest,
}

raw = path.read_text(encoding="utf-8")
lines = raw.splitlines(keepends=True)
current_name = None
seen_names = set()
updates = []
digest_updates = []

name_indices = []
for idx, line in enumerate(lines):
    line_no_eol = line.rstrip("\r\n")
    name_match = re.match(r"^(\s*-\s*name:\s*)(\S+)(\s*)$", line_no_eol)
    if name_match:
        name_indices.append((idx, name_match.group(2), name_match.group(1)))

block_ranges = []
for pos, (start_idx, image_name, name_prefix) in enumerate(name_indices):
    end_idx = len(lines) - 1 if pos == len(name_indices) - 1 else name_indices[pos + 1][0] - 1
    block_ranges.append((start_idx, end_idx, image_name, name_prefix))

for idx, line in enumerate(lines):
    line_no_eol = line.rstrip("\r\n")
    eol = line[len(line_no_eol):]

    name_match = re.match(r"^(\s*-\s*name:\s*)(\S+)(\s*)$", line_no_eol)
    if name_match:
        current_name = name_match.group(2)
        continue

    tag_match = re.match(r"^(\s*newTag:\s*)(\S+)(\s*)$", line_no_eol)
    if not tag_match or not current_name:
        continue

    if current_name not in targets:
        continue

    seen_names.add(current_name)
    current_tag = tag_match.group(2)
    wanted_tag = targets[current_name]
    if current_tag == wanted_tag:
        continue

    updated_line = f"{tag_match.group(1)}{wanted_tag}{tag_match.group(3)}{eol}"
    updates.append((idx + 1, current_name, current_tag, wanted_tag))
    lines[idx] = updated_line

for start_idx, end_idx, image_name, name_prefix in block_ranges:
    wanted_digest = digest_targets.get(image_name, "")
    if not wanted_digest:
        continue

    digest_idx = None
    digest_indent = "    "
    insert_after_idx = start_idx

    for idx in range(start_idx + 1, end_idx + 1):
        line_no_eol = lines[idx].rstrip("\r\n")
        digest_match = re.match(r"^(\s*digest:\s*)(\S+)(\s*)$", line_no_eol)
        if digest_match:
            digest_idx = idx
            digest_indent = re.match(r"^(\s*)", line_no_eol).group(1)
            current_digest = digest_match.group(2)
            if current_digest != wanted_digest:
                eol = lines[idx][len(line_no_eol):]
                lines[idx] = f"{digest_match.group(1)}{wanted_digest}{digest_match.group(3)}{eol}"
                digest_updates.append((idx + 1, image_name, current_digest, wanted_digest))
            break

        if re.match(r"^\s*(newTag|newName):\s*\S+", line_no_eol):
            insert_after_idx = idx
            digest_indent = re.match(r"^(\s*)", line_no_eol).group(1)

    if digest_idx is None:
        insert_line = f"{digest_indent}digest: {wanted_digest}\n"
        lines.insert(insert_after_idx + 1, insert_line)
        digest_updates.append((insert_after_idx + 2, image_name, "<missing>", wanted_digest))
        for i, (s_idx, e_idx, n, pref) in enumerate(block_ranges):
            if s_idx > insert_after_idx:
                block_ranges[i] = (s_idx + 1, e_idx + 1, n, pref)
            elif i >= 0 and s_idx == start_idx:
                block_ranges[i] = (s_idx, e_idx + 1, n, pref)

missing = [name for name in required_names if name not in seen_names]
if missing:
    raise SystemExit(f"{path}: missing expected image entries: {', '.join(missing)}")

if not updates:
    if not digest_updates:
        print(f"= {path}: image tags/digests already up-to-date")
        raise SystemExit(0)
else:
    print(f"~ {path}: {len(updates)} tag update(s)")
    for line_no, image_name, before, after in updates:
        print(f"    L{line_no} {image_name}: {before} -> {after}")

if digest_updates:
    print(f"~ {path}: {len(digest_updates)} digest update(s)")
    for line_no, image_name, before, after in digest_updates:
        print(f"    L{line_no} {image_name}: {before} -> {after}")

if apply:
    path.write_text("".join(lines), encoding="utf-8")
    print(f"  applied: {path}")
else:
    print(f"  dry-run: {path}")
PY
}

update_gitops_base_ref() {
  local file="$1"
  local app_sha="$2"
  local apply="$3"

  python3 - "$file" "$app_sha" "$apply" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
new_sha = sys.argv[2].strip()
apply = sys.argv[3] == "1"

if not path.exists():
    raise SystemExit(f"missing file: {path}")

content = path.read_text(encoding="utf-8")
pat = re.compile(
    r"(https://github\.com/Biji-Biji-Initiative/mereka-lms\.git//deploy/k8s/base\?ref=)([0-9a-fA-F]{7,40})"
)
match = pat.search(content)
if not match:
    vendored_pat = re.compile(r"^\s*-\s*deploy/k8s/base\s*$", re.MULTILINE)
    if vendored_pat.search(content):
        print(f"= {path}: vendored base mode detected (resources: deploy/k8s/base); skipping base ref bump")
        raise SystemExit(0)
    raise SystemExit(f"{path}: could not locate mereka-lms base ref URL")

old_sha = match.group(2)
if old_sha == new_sha:
    print(f"= {path}: base ref already {new_sha}")
    raise SystemExit(0)

updated = pat.sub(lambda m: f"{m.group(1)}{new_sha}", content, count=1)
print(f"~ {path}: base ref {old_sha} -> {new_sha}")
if apply:
    path.write_text(updated, encoding="utf-8")
    print(f"  applied: {path}")
else:
    print(f"  dry-run: {path}")
PY
}

commit_if_needed() {
  local repo="$1"
  local message="$2"
  shift 2
  local paths=("$@")
  git -C "$repo" add "${paths[@]}"
  if git -C "$repo" diff --cached --quiet; then
    echo "= $repo: no staged changes for commit"
    return
  fi
  git -C "$repo" commit -m "$message"
}

push_with_rebase_if_needed() {
  local repo="$1"
  if git -C "$repo" push; then
    return
  fi
  git -C "$repo" pull --rebase
  git -C "$repo" push
}

verify_runtime_convergence() {
  local mfe_tag="$1"
  local wait_seconds="$2"
  local interval=10
  local attempts=$(( wait_seconds / interval ))
  if [[ "$attempts" -lt 1 ]]; then
    attempts=1
  fi

  if ! resolve_argocd_app; then
    return 1
  fi

  echo "Polling runtime convergence (context=$K8S_CONTEXT app=$ARGO_APP namespace=$APP_NAMESPACE)..."
  for ((i=1; i<=attempts; i++)); do
    local app_line
    app_line="$(kubectl --context "$K8S_CONTEXT" -n "$ARGOCD_NAMESPACE" \
      get applications.argoproj.io "$ARGO_APP" \
      -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}' 2>/dev/null || true)"
    local deploy_image
    deploy_image="$(kubectl --context "$K8S_CONTEXT" -n "$APP_NAMESPACE" \
      get deploy mfe -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"

    echo "  [$i/$attempts] app=[$app_line] mfe=[$deploy_image]"
    if [[ "$deploy_image" == *":$mfe_tag" ]]; then
      echo "✓ Runtime convergence verified."
      return 0
    fi
    sleep "$interval"
  done
  echo "Runtime verification timed out waiting for mfe:$mfe_tag" >&2
  return 1
}

resolve_argocd_app() {
  # Respect explicit override.
  if [[ -n "$ARGO_APP" && "$ARGO_APP" != "auto" ]]; then
    return 0
  fi

  local candidates=()
  if [[ "$TARGET_ENV" == "production" ]]; then
    candidates=(mereka-lms-prod mereka-lms-local)
  else
    candidates=(mereka-lms-staging mereka-lms-local mereka-lms-prod)
  fi

  local app
  for app in "${candidates[@]}"; do
    if kubectl --context "$K8S_CONTEXT" -n "$ARGOCD_NAMESPACE" \
      get applications.argoproj.io "$app" >/dev/null 2>&1; then
      ARGO_APP="$app"
      echo "Auto-detected ArgoCD app: $ARGO_APP"
      return 0
    fi
  done

  echo "Unable to auto-detect ArgoCD app in namespace '$ARGOCD_NAMESPACE' for context '$K8S_CONTEXT'." >&2
  echo "Pass --argocd-app <name> explicitly." >&2
  return 1
}

detect_infra_repo
require_git_repo "$APP_REPO"
require_git_repo "$INFRA_REPO"

TARGET_ENV="$(normalize_target_env "$TARGET_ENV")"

if [[ "${CI:-}" == "true" && "$TARGET_ENV_SET" -ne 1 ]]; then
  echo "Error: CI mode requires explicit --target-env (production|staging)." >&2
  usage
  exit 1
fi

if [[ "${CI:-}" == "true" && "$TARGET_ENV" == "production" && "$APPLY" -eq 1 && ( -z "$OPENEDX_DIGEST" || -z "$MFE_DIGEST" ) ]]; then
  echo "Error: CI production apply requires both --openedx-digest and --mfe-digest." >&2
  exit 1
fi

if [[ "$TARGET_ENV" == "production" && "$APPLY" -eq 1 && "$RUN_BRANDING_RUNTIME_GUARD" -eq 1 && "$VERIFY_RUNTIME" -ne 1 ]]; then
  echo "Error: production apply with runtime branding guard enabled requires --verify-runtime." >&2
  echo "Use --skip-branding-runtime-guard only for controlled emergency releases." >&2
  exit 1
fi

if [[ "$TARGET_ENV" == "production" && "$APPLY" -eq 1 && "$RUN_PARAGON_RUNTIME_GUARD" -eq 1 && "$VERIFY_RUNTIME" -ne 1 ]]; then
  echo "Error: production apply with PARAGON runtime guard enabled requires --verify-runtime." >&2
  echo "Use --skip-paragon-runtime-guard only for controlled emergency releases." >&2
  exit 1
fi

if [[ "$TARGET_ENV" == "production" && "$APPLY" -eq 1 && "$RUN_FOOTER_RUNTIME_GUARD" -eq 1 && "$VERIFY_RUNTIME" -ne 1 ]]; then
  echo "Error: production apply with footer runtime guard enabled requires --verify-runtime." >&2
  echo "Use --skip-footer-runtime-guard only for controlled emergency releases." >&2
  exit 1
fi

if [[ "$TARGET_ENV" == "production" && "$APPLY" -eq 1 ]]; then
  openedx_tag_lc="$(echo "$OPENEDX_TAG" | tr '[:upper:]' '[:lower:]')"
  mfe_tag_lc="$(echo "$MFE_TAG" | tr '[:upper:]' '[:lower:]')"
  if [[ "$openedx_tag_lc" == "latest" || "$mfe_tag_lc" == "latest" ]]; then
    echo "Error: production apply forbids mutable 'latest' tags." >&2
    echo "Use immutable release tags for --openedx-tag and --mfe-tag." >&2
    exit 1
  fi
fi

case "$FRONTEND_CACHE_ENV" in
  auto|prod|dev) ;;
  *)
    echo "Error: --frontend-cache-env must be auto, prod, or dev (got: $FRONTEND_CACHE_ENV)." >&2
    exit 1
    ;;
esac

if [[ "$TARGET_ENV" == "production" && "$APPLY" -eq 1 && "$RUN_FRONTEND_CACHE_PURGE" -eq 1 && "$VERIFY_RUNTIME" -ne 1 ]]; then
  echo "Error: production apply with cache purge enabled requires --verify-runtime." >&2
  echo "Run with --verify-runtime or skip --purge-frontend-cache." >&2
  exit 1
fi

UPDATE_APP_BASE=0
UPDATE_BASE_REF_DEFAULT=0
APP_OVERLAY_REL="$APP_PROD_REL"
INFRA_OVERLAY_REL="$INFRA_PROD_REL"
APP_REQUIRED_NAMES="docker.io/overhangio/openedx,docker.io/overhangio/openedx-mfe,asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe"
# bbi-infrastructure overlay has an extra "double-override" entry for the already-transformed
# openedx image name (added to prevent kustomize base-image drift, ref fc34418)
INFRA_REQUIRED_NAMES="$APP_REQUIRED_NAMES,asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx"

if [[ "$TARGET_ENV" == "production" ]]; then
  UPDATE_APP_BASE=1
  UPDATE_BASE_REF_DEFAULT=1
  APP_OVERLAY_REL="$APP_PROD_REL"
  INFRA_OVERLAY_REL="$INFRA_PROD_REL"
elif [[ "$TARGET_ENV" == "staging" ]]; then
  UPDATE_APP_BASE=0
  UPDATE_BASE_REF_DEFAULT=0
  APP_OVERLAY_REL="$APP_STAGING_REL"
  INFRA_OVERLAY_REL="$INFRA_STAGING_REL"
  # Staging overlay may not include the production-only double-override image entry.
  INFRA_REQUIRED_NAMES="$APP_REQUIRED_NAMES"
fi

UPDATE_BASE_REF="$UPDATE_BASE_REF_DEFAULT"
if [[ "$UPDATE_BASE_REF_MODE" == "1" ]]; then
  UPDATE_BASE_REF=1
elif [[ "$UPDATE_BASE_REF_MODE" == "0" ]]; then
  UPDATE_BASE_REF=0
fi

APP_BASE_FILE="$APP_REPO/$APP_BASE_REL"
APP_OVERLAY_FILE="$APP_REPO/$APP_OVERLAY_REL"
INFRA_BASE_FILE="$INFRA_REPO/$INFRA_BASE_REL"
INFRA_OVERLAY_FILE="$INFRA_REPO/$INFRA_OVERLAY_REL"

echo "App repo:   $APP_REPO"
echo "Infra repo: $INFRA_REPO"
echo "Target env: $TARGET_ENV"
echo "OpenedX tag: $OPENEDX_TAG"
echo "MFE tag:     $MFE_TAG"
echo "OpenedX digest: ${OPENEDX_DIGEST:-<unchanged>}"
echo "MFE digest:     ${MFE_DIGEST:-<unchanged>}"
echo "Require digests: $([[ "$REQUIRE_DIGESTS" -eq 1 ]] && echo yes || echo no)"
echo "Update app base image overrides: $([[ "$UPDATE_APP_BASE" -eq 1 ]] && echo yes || echo no)"
echo "Update GitOps base ref: $([[ "$UPDATE_BASE_REF" -eq 1 ]] && echo yes || echo no)"
echo "Mode: $([[ "$APPLY" -eq 1 ]] && echo apply || echo dry-run)"
echo "Enterprise site mapping guard: $([[ "$ENFORCE_ENTERPRISE_SITE_MAPPING_GUARD" -eq 1 ]] && echo enabled || echo skipped)"
echo "Enterprise readiness integrity guard: $([[ "$RUN_ENTERPRISE_READINESS_INTEGRITY_GUARD" -eq 1 ]] && echo enabled || echo skipped)"
echo "Enterprise SSO runtime guard: $([[ "$RUN_ENTERPRISE_SSO_RUNTIME_GUARD" -eq 1 ]] && echo enabled || echo skipped)"
echo "Enterprise runtime app guard: $([[ "$RUN_ENTERPRISE_RUNTIME_APP_GUARD" -eq 1 ]] && echo enabled || echo skipped)"
echo "Enterprise schema guard: $([[ "$RUN_ENTERPRISE_SCHEMA_GUARD" -eq 1 ]] && echo enabled || echo skipped)"
echo "Branding runtime guard: $([[ "$RUN_BRANDING_RUNTIME_GUARD" -eq 1 ]] && echo enabled || echo skipped)"
echo "PARAGON runtime guard: $([[ "$RUN_PARAGON_RUNTIME_GUARD" -eq 1 ]] && echo enabled || echo skipped)"
echo "Branding surface audit: $([[ "$RUN_BRANDING_SURFACE_AUDIT" -eq 1 ]] && echo enabled || echo skipped)"
echo "Footer runtime guard: $([[ "$RUN_FOOTER_RUNTIME_GUARD" -eq 1 ]] && echo enabled || echo skipped)"
echo "MFE route runtime guard: $([[ "$RUN_MFE_ROUTE_RUNTIME_GUARD" -eq 1 ]] && echo enabled || echo skipped)"
echo "MFE route smoke guard: $([[ "$RUN_MFE_ROUTE_SMOKE_GUARD" -eq 1 ]] && echo enabled || echo skipped)"
echo "Frontend cache purge: $([[ "$RUN_FRONTEND_CACHE_PURGE" -eq 1 ]] && echo enabled || echo skipped)"
echo "Frontend cache purge env: $FRONTEND_CACHE_ENV"
echo "Frontend cache purge everything: $([[ "$FRONTEND_CACHE_PURGE_EVERYTHING" -eq 1 ]] && echo enabled || echo disabled)"
echo "Enterprise readiness tenant: $ENTERPRISE_READINESS_TENANT"

run_enterprise_release_preflights() {
  if [[ "$TARGET_ENV" != "production" || "$APPLY" -ne 1 ]]; then
    return 0
  fi

  echo "Running production enterprise preflight guards..."
  if [[ "$RUN_ENTERPRISE_READINESS_INTEGRITY_GUARD" -eq 1 ]]; then
    "$REPO_ROOT/scripts/qa/verify-enterprise-readiness-integrity.sh"
  else
    echo "= skipped static integrity guard (--skip-enterprise-readiness-integrity-guard)"
  fi

  if [[ "$ENFORCE_ENTERPRISE_SITE_MAPPING_GUARD" -eq 1 ]]; then
    STRICT=1 REQUIRE_ENTERPRISE_SITE_MAPPING=1 \
      "$REPO_ROOT/scripts/qa/verify-multisite-config.sh" prod
  else
    echo "= skipped enterprise site mapping runtime guard (--skip-enterprise-site-mapping-guard)"
  fi

  if [[ "$RUN_ENTERPRISE_SCHEMA_GUARD" -eq 1 ]]; then
    "$REPO_ROOT/scripts/tenants/repair-enterprise-schema.sh" --env prod
  else
    echo "= skipped enterprise schema guard (--skip-enterprise-schema-guard)"
  fi

  if [[ "$RUN_ENTERPRISE_RUNTIME_APP_GUARD" -eq 1 ]]; then
    "$REPO_ROOT/scripts/qa/verify-enterprise-runtime-app-wiring.sh" \
      --env prod --context "$K8S_CONTEXT" --strict
  else
    echo "= skipped enterprise runtime app wiring guard (--skip-enterprise-runtime-app-guard)"
  fi

  if [[ "$RUN_ENTERPRISE_SSO_RUNTIME_GUARD" -eq 1 ]]; then
    "$REPO_ROOT/scripts/qa/verify-enterprise-sso-readiness.sh" \
      --env prod --mode cluster --tenant "$ENTERPRISE_READINESS_TENANT"
  else
    echo "= skipped enterprise SSO runtime guard (--skip-enterprise-sso-runtime-guard)"
  fi
}

run_enterprise_release_preflights

run_branding_release_postflights() {
  if [[ "$TARGET_ENV" != "production" || "$APPLY" -ne 1 ]]; then
    return 0
  fi

  local paragon_runtime_url="${PARAGON_RUNTIME_URL:-https://apps.academyv2.mereka.io}"

  if [[ "$RUN_PARAGON_RUNTIME_GUARD" -eq 1 ]]; then
    echo "Running production PARAGON runtime verification..."
    "$REPO_ROOT/scripts/qa/verify-paragon-runtime.sh" \
      --runtime-url "$paragon_runtime_url" \
      --require-runtime
  else
    echo "= skipped PARAGON runtime guard (--skip-paragon-runtime-guard)"
  fi

  if [[ "$RUN_BRANDING_RUNTIME_GUARD" -eq 1 ]]; then
    echo "Running production branding runtime verification..."
    STRICT_MFE_BRANDING_REV=1 STRICT_PROXY_AUTHN_BRANDING=1 \
      "$REPO_ROOT/scripts/qa/verify-public-branding.sh" prod
  else
    echo "= skipped branding runtime guard (--skip-branding-runtime-guard)"
  fi

  if [[ "$RUN_FOOTER_RUNTIME_GUARD" -eq 1 ]]; then
    echo "Running production footer runtime verification..."
    "$REPO_ROOT/scripts/qa/verify-footer-parity.sh" --live
  else
    echo "= skipped footer runtime guard (--skip-footer-runtime-guard)"
  fi

  if [[ "$RUN_BRANDING_RUNTIME_GUARD" -eq 1 && "$RUN_BRANDING_SURFACE_AUDIT" -eq 1 ]]; then
    echo "Running production branding surface audit (strict)..."
    STRICT_PROXY_AUTHN_BRANDING=1 \
      "$REPO_ROOT/scripts/qa/audit-branding-surfaces.sh" prod --strict
  elif [[ "$RUN_BRANDING_SURFACE_AUDIT" -eq 0 ]]; then
    echo "= skipped branding surface audit (--skip-branding-surface-audit)"
  fi

  if [[ "$RUN_MFE_ROUTE_RUNTIME_GUARD" -eq 1 ]]; then
    echo "Running production MFE route runtime contract verification..."
    "$REPO_ROOT/scripts/qa/verify-mfe-route-contract.sh" \
      --context "$K8S_CONTEXT" --namespace "$APP_NAMESPACE" --strict-runtime
  else
    echo "= skipped MFE route runtime guard (--skip-mfe-route-runtime-guard)"
  fi

  if [[ "$RUN_MFE_ROUTE_SMOKE_GUARD" -eq 1 ]]; then
    echo "Running production MFE route smoke verification..."
    "$REPO_ROOT/scripts/qa/verify-mfe-route-smoke.sh" --env prod
  else
    echo "= skipped MFE route smoke guard (--skip-mfe-route-smoke-guard)"
  fi
}

run_frontend_cache_purge() {
  if [[ "$RUN_FRONTEND_CACHE_PURGE" -ne 1 ]]; then
    return 0
  fi

  local purge_env="$FRONTEND_CACHE_ENV"
  if [[ "$purge_env" == "auto" ]]; then
    if [[ "$TARGET_ENV" == "production" ]]; then
      purge_env="prod"
    else
      purge_env="dev"
    fi
  fi

  local -a purge_cmd=("$REPO_ROOT/scripts/infra/purge-frontend-theme-cache.sh" "--env" "$purge_env")
  if [[ "$APPLY" -eq 1 ]]; then
    purge_cmd+=("--apply")
  fi
  if [[ "$FRONTEND_CACHE_PURGE_EVERYTHING" -eq 1 ]]; then
    purge_cmd+=("--purge-everything")
  fi

  echo "Running frontend cache purge helper..."
  "${purge_cmd[@]}"
}

if [[ "$UPDATE_APP_BASE" -eq 1 ]]; then
  update_image_tags_file \
    "$APP_BASE_FILE" "$OPENEDX_TAG" "$MFE_TAG" "$OPENEDX_DIGEST" "$MFE_DIGEST" "$APPLY" \
    "docker.io/overhangio/openedx,docker.io/overhangio/openedx-mfe"
else
  echo "= skipping app base tag update for target env '$TARGET_ENV'"
fi

update_image_tags_file \
  "$APP_OVERLAY_FILE" "$OPENEDX_TAG" "$MFE_TAG" "$OPENEDX_DIGEST" "$MFE_DIGEST" "$APPLY" \
  "$APP_REQUIRED_NAMES"

if [[ "$COMMIT" -eq 1 ]]; then
  APP_COMMIT_PATHS=("$APP_OVERLAY_REL")
  if [[ "$UPDATE_APP_BASE" -eq 1 ]]; then
    APP_COMMIT_PATHS=("$APP_BASE_REL" "$APP_OVERLAY_REL")
  fi
  commit_if_needed "$APP_REPO" \
    "chore: release openedx tags $OPENEDX_TAG/$MFE_TAG ($TARGET_ENV)" \
    "${APP_COMMIT_PATHS[@]}"
fi

if [[ "$UPDATE_BASE_REF" -eq 1 ]]; then
  APP_SHA="$APP_SHA_OVERRIDE"
  if [[ -z "$APP_SHA" ]]; then
    APP_SHA="$(git -C "$APP_REPO" rev-parse HEAD)"
  fi
  # Guardrail: ArgoCD/kustomize fetches by SHA and will fail with "not our ref" if the SHA
  # isn't a real commit reachable from the app repo. Validate locally before writing it into GitOps.
  if ! git -C "$APP_REPO" cat-file -e "${APP_SHA}^{commit}" 2>/dev/null; then
    echo "Invalid --app-sha (or app repo HEAD is not a commit): $APP_SHA" >&2
    echo "Tip: use the exact output of: git -C \"$APP_REPO\" rev-parse HEAD" >&2
    exit 1
  fi
  echo "App SHA for GitOps base ref: $APP_SHA"
  update_gitops_base_ref "$INFRA_BASE_FILE" "$APP_SHA" "$APPLY"
else
  echo "= skipping GitOps base ref update for target env '$TARGET_ENV'"
fi

update_image_tags_file \
  "$INFRA_OVERLAY_FILE" "$OPENEDX_TAG" "$MFE_TAG" "$OPENEDX_DIGEST" "$MFE_DIGEST" "$APPLY" \
  "$INFRA_REQUIRED_NAMES"

if [[ "$APPLY" -eq 1 ]]; then
  if [[ "$TARGET_ENV" == "production" ]]; then
    INFRA_PROD_OVERLAY="$INFRA_OVERLAY_FILE" \
    APP_BASE="$APP_BASE_FILE" \
    APP_PROD_OVERLAY="$APP_OVERLAY_FILE" \
      "$REPO_ROOT/scripts/qa/verify-gitops-image-overrides.sh" --check-infra
  else
    echo "= skipping production-only cross-repo image contract check for staging target"
  fi
fi

if [[ "$COMMIT" -eq 1 ]]; then
  INFRA_COMMIT_PATHS=("$INFRA_OVERLAY_REL")
  if [[ "$UPDATE_BASE_REF" -eq 1 ]]; then
    INFRA_COMMIT_PATHS=("$INFRA_BASE_REL" "$INFRA_OVERLAY_REL")
  fi
  commit_if_needed "$INFRA_REPO" \
    "chore: rollout openedx tags $OPENEDX_TAG/$MFE_TAG ($TARGET_ENV)" \
    "${INFRA_COMMIT_PATHS[@]}"
fi

if [[ "$PUSH" -eq 1 ]]; then
  push_with_rebase_if_needed "$APP_REPO"
  push_with_rebase_if_needed "$INFRA_REPO"
fi

if [[ "$VERIFY_RUNTIME" -eq 1 ]]; then
  verify_runtime_convergence "$MFE_TAG" "$WAIT_SECONDS"
fi

run_branding_release_postflights
run_frontend_cache_purge

echo "Done."
