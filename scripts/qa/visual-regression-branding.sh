#!/usr/bin/env bash
# Compare branding screenshots against a baseline using ImageMagick RMSE.
#
# This script is intentionally deterministic and CI-friendly:
# - Compares PNG files by name between baseline and candidate directories.
# - Emits per-file normalized RMSE in [0,1].
# - Writes diff images to var/screenshots-diff/<env>/<timestamp>/.
#
# Usage:
#   ./scripts/qa/visual-regression-branding.sh prod
#   ./scripts/qa/visual-regression-branding.sh dev --threshold 0.08
#   ./scripts/qa/visual-regression-branding.sh prod --baseline <dir> --candidate <dir>
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/qa/visual-regression-branding.sh [prod|dev] [options]

Options:
  --baseline <dir>        Baseline screenshot directory.
  --candidate <dir>       Candidate screenshot directory.
  --threshold <float>     Normalized RMSE threshold per image (default: 0.06).
  --exclude-regex <expr>  Skip matching filenames (e.g. 'forum|notes').
  --allow-bootstrap       Exit 0 when fewer than two screenshot runs exist.
  --strict                Fail if baseline/candidate file sets differ.
  --json                  Emit machine-readable summary JSON.
  -h, --help              Show help.
EOF
}

ENVIRONMENT="${1:-}"
if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  usage >&2
  exit 2
fi
shift || true

BASELINE_DIR=""
CANDIDATE_DIR=""
THRESHOLD="${THRESHOLD:-0.06}"
EXCLUDE_REGEX="${EXCLUDE_REGEX:-}"
ALLOW_BOOTSTRAP=0
STRICT=0
JSON=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline) BASELINE_DIR="${2:-}"; shift 2 ;;
    --candidate) CANDIDATE_DIR="${2:-}"; shift 2 ;;
    --threshold) THRESHOLD="${2:-}"; shift 2 ;;
    --exclude-regex) EXCLUDE_REGEX="${2:-}"; shift 2 ;;
    --allow-bootstrap) ALLOW_BOOTSTRAP=1; shift ;;
    --strict) STRICT=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! command -v compare >/dev/null 2>&1; then
  echo "ImageMagick 'compare' is required." >&2
  exit 2
fi

if ! [[ "$THRESHOLD" =~ ^[0-9]*\.?[0-9]+$ ]]; then
  echo "Invalid --threshold: $THRESHOLD" >&2
  exit 2
fi

ROOT="$REPO_ROOT/var/screenshots/$ENVIRONMENT"
if [[ -z "$BASELINE_DIR" || -z "$CANDIDATE_DIR" ]]; then
  if [[ ! -d "$ROOT" ]]; then
    if [[ "$ALLOW_BOOTSTRAP" -eq 1 ]]; then
      if [[ "$JSON" -eq 1 ]]; then
        printf '{"env":"%s","bootstrap":true,"reason":"screenshot root missing","screenshot_root":"%s"}\n' \
          "$ENVIRONMENT" "$ROOT"
      else
        echo "Visual regression bootstrap mode: screenshot root missing: $ROOT"
      fi
      exit 0
    fi
    echo "No screenshot root found: $ROOT" >&2
    exit 2
  fi
  mapfile -t runs < <(find "$ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  if [[ "${#runs[@]}" -lt 2 ]]; then
    if [[ "$ALLOW_BOOTSTRAP" -eq 1 ]]; then
      if [[ "$JSON" -eq 1 ]]; then
        printf '{"env":"%s","bootstrap":true,"reason":"need at least two screenshot runs","screenshot_root":"%s"}\n' \
          "$ENVIRONMENT" "$ROOT"
      else
        echo "Visual regression bootstrap mode: need at least two screenshot runs under $ROOT"
      fi
      exit 0
    fi
    echo "Need at least two screenshot runs under $ROOT" >&2
    exit 2
  fi
  if [[ -z "$BASELINE_DIR" ]]; then
    BASELINE_DIR="$ROOT/${runs[-2]}"
  fi
  if [[ -z "$CANDIDATE_DIR" ]]; then
    CANDIDATE_DIR="$ROOT/${runs[-1]}"
  fi
fi

if [[ ! -d "$BASELINE_DIR" ]]; then
  echo "Baseline directory not found: $BASELINE_DIR" >&2
  exit 2
fi
if [[ ! -d "$CANDIDATE_DIR" ]]; then
  echo "Candidate directory not found: $CANDIDATE_DIR" >&2
  exit 2
fi

DIFF_DIR="$REPO_ROOT/var/screenshots-diff/$ENVIRONMENT/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$DIFF_DIR"

mapfile -t baseline_files < <(find "$BASELINE_DIR" -maxdepth 1 -type f -name '*.png' -printf '%f\n' | sort)
mapfile -t candidate_files < <(find "$CANDIDATE_DIR" -maxdepth 1 -type f -name '*.png' -printf '%f\n' | sort)

declare -A baseline_set
declare -A candidate_set
for f in "${baseline_files[@]}"; do baseline_set["$f"]=1; done
for f in "${candidate_files[@]}"; do candidate_set["$f"]=1; done

missing_in_candidate=()
missing_in_baseline=()
for f in "${baseline_files[@]}"; do
  if [[ -z "${candidate_set[$f]:-}" ]]; then
    missing_in_candidate+=("$f")
  fi
done
for f in "${candidate_files[@]}"; do
  if [[ -z "${baseline_set[$f]:-}" ]]; then
    missing_in_baseline+=("$f")
  fi
done

total=0
failed=0
compared=0
skipped=0
results_json=()

for f in "${candidate_files[@]}"; do
  if [[ -n "$EXCLUDE_REGEX" ]] && [[ "$f" =~ $EXCLUDE_REGEX ]]; then
    skipped=$((skipped + 1))
    continue
  fi
  if [[ -z "${baseline_set[$f]:-}" ]]; then
    continue
  fi

  total=$((total + 1))
  compared=$((compared + 1))
  base="$BASELINE_DIR/$f"
  cand="$CANDIDATE_DIR/$f"
  diff="$DIFF_DIR/$f"

  metric_raw="$(compare -metric RMSE "$base" "$cand" "$diff" 2>&1 || true)"
  norm="$(sed -nE 's/.*\(([0-9.]+)\).*/\1/p' <<<"$metric_raw" | head -n 1)"
  if [[ -z "$norm" ]]; then
    norm="1.0"
  fi

  over="$(awk -v n="$norm" -v t="$THRESHOLD" 'BEGIN{print (n>t)?1:0}')"
  if [[ "$over" == "1" ]]; then
    failed=$((failed + 1))
  fi
  results_json+=("{\"file\":\"$f\",\"rmse\":$norm,\"threshold\":$THRESHOLD,\"over_threshold\":$over}")
done

if [[ "$JSON" -eq 1 ]]; then
  printf '{'
  printf '"env":"%s",' "$ENVIRONMENT"
  printf '"baseline":"%s",' "$BASELINE_DIR"
  printf '"candidate":"%s",' "$CANDIDATE_DIR"
  printf '"diff_dir":"%s",' "$DIFF_DIR"
  printf '"threshold":%s,' "$THRESHOLD"
  printf '"compared":%d,' "$compared"
  printf '"skipped":%d,' "$skipped"
  printf '"failed":%d,' "$failed"
  printf '"missing_in_candidate":['
  for i in "${!missing_in_candidate[@]}"; do
    [[ $i -gt 0 ]] && printf ','
    printf '"%s"' "${missing_in_candidate[$i]}"
  done
  printf '],'
  printf '"missing_in_baseline":['
  for i in "${!missing_in_baseline[@]}"; do
    [[ $i -gt 0 ]] && printf ','
    printf '"%s"' "${missing_in_baseline[$i]}"
  done
  printf '],'
  printf '"results":['
  for i in "${!results_json[@]}"; do
    [[ $i -gt 0 ]] && printf ','
    printf '%s' "${results_json[$i]}"
  done
  printf ']'
  printf '}\n'
else
  echo "Branding visual regression"
  echo "  env: $ENVIRONMENT"
  echo "  baseline: $BASELINE_DIR"
  echo "  candidate: $CANDIDATE_DIR"
  echo "  diff_dir: $DIFF_DIR"
  echo "  threshold: $THRESHOLD"
  echo "  compared: $compared"
  echo "  skipped: $skipped"
  echo "  failed: $failed"
  if [[ "${#missing_in_candidate[@]}" -gt 0 ]]; then
    echo "  missing_in_candidate: ${missing_in_candidate[*]}"
  fi
  if [[ "${#missing_in_baseline[@]}" -gt 0 ]]; then
    echo "  missing_in_baseline: ${missing_in_baseline[*]}"
  fi
fi

if [[ "$STRICT" -eq 1 ]] && { [[ "${#missing_in_candidate[@]}" -gt 0 ]] || [[ "${#missing_in_baseline[@]}" -gt 0 ]]; }; then
  exit 1
fi

if [[ "$failed" -gt 0 ]]; then
  exit 1
fi

exit 0
