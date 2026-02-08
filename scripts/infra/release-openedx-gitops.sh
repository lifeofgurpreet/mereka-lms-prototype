#!/usr/bin/env bash
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
APP_SHA_OVERRIDE=""
TARGET_ENV="production"
UPDATE_BASE_REF_MODE="auto" # auto|1|0

APPLY=0
COMMIT=0
PUSH=0
VERIFY_RUNTIME=0

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGO_APP="${ARGO_APP:-mereka-lms-local}"
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

  --k8s-context NAME    Kubernetes context for runtime verification.
  --argocd-namespace NS ArgoCD namespace (default: argocd).
  --argocd-app NAME     ArgoCD application name (default: mereka-lms-local).
  --namespace NS        App namespace for deployment checks (default: mereka-lms).
  --wait-seconds N      Max wait for runtime verification (default: 600).
  -h, --help            Show this help.

Examples:
  # Dry-run preview
  ./scripts/infra/release-openedx-gitops.sh --openedx-tag 20260208-openedx-a --mfe-tag 20260208-mfe-b

  # Apply + commit production rollout
  ./scripts/infra/release-openedx-gitops.sh --openedx-tag 20260208-openedx-a --mfe-tag 20260208-mfe-b \
    --apply --commit

  # Full production automation (apply, commit, push, runtime verify)
  ./scripts/infra/release-openedx-gitops.sh --openedx-tag 20260208-openedx-a --mfe-tag 20260208-mfe-b \
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
    --target-env)
      TARGET_ENV="${2:-}"
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
  local apply="$4"
  local required_names_csv="$5"

  python3 - "$file" "$openedx_tag" "$mfe_tag" "$apply" "$required_names_csv" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
openedx_tag = sys.argv[2]
mfe_tag = sys.argv[3]
apply = sys.argv[4] == "1"
required_names = [name for name in sys.argv[5].split(",") if name]

if not path.exists():
    raise SystemExit(f"missing file: {path}")

targets = {
    "docker.io/overhangio/openedx": openedx_tag,
    "docker.io/overhangio/openedx-mfe": mfe_tag,
    "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe": mfe_tag,
}

raw = path.read_text(encoding="utf-8")
lines = raw.splitlines(keepends=True)
current_name = None
seen_names = set()
updates = []

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

missing = [name for name in required_names if name not in seen_names]
if missing:
    raise SystemExit(f"{path}: missing expected image entries: {', '.join(missing)}")

if not updates:
    print(f"= {path}: image tags already up-to-date")
    raise SystemExit(0)

print(f"~ {path}: {len(updates)} tag update(s)")
for line_no, image_name, before, after in updates:
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

detect_infra_repo
require_git_repo "$APP_REPO"
require_git_repo "$INFRA_REPO"

TARGET_ENV="$(normalize_target_env "$TARGET_ENV")"
UPDATE_APP_BASE=0
UPDATE_BASE_REF_DEFAULT=0
APP_OVERLAY_REL="$APP_PROD_REL"
INFRA_OVERLAY_REL="$INFRA_PROD_REL"
APP_REQUIRED_NAMES="docker.io/overhangio/openedx,docker.io/overhangio/openedx-mfe,asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe"
INFRA_REQUIRED_NAMES="$APP_REQUIRED_NAMES"

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
echo "Update app base tags: $([[ "$UPDATE_APP_BASE" -eq 1 ]] && echo yes || echo no)"
echo "Update GitOps base ref: $([[ "$UPDATE_BASE_REF" -eq 1 ]] && echo yes || echo no)"
echo "Mode: $([[ "$APPLY" -eq 1 ]] && echo apply || echo dry-run)"

if [[ "$UPDATE_APP_BASE" -eq 1 ]]; then
  update_image_tags_file \
    "$APP_BASE_FILE" "$OPENEDX_TAG" "$MFE_TAG" "$APPLY" \
    "docker.io/overhangio/openedx,docker.io/overhangio/openedx-mfe"
else
  echo "= skipping app base tag update for target env '$TARGET_ENV'"
fi

update_image_tags_file \
  "$APP_OVERLAY_FILE" "$OPENEDX_TAG" "$MFE_TAG" "$APPLY" \
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
  echo "App SHA for GitOps base ref: $APP_SHA"
  update_gitops_base_ref "$INFRA_BASE_FILE" "$APP_SHA" "$APPLY"
else
  echo "= skipping GitOps base ref update for target env '$TARGET_ENV'"
fi

update_image_tags_file \
  "$INFRA_OVERLAY_FILE" "$OPENEDX_TAG" "$MFE_TAG" "$APPLY" \
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

echo "Done."
