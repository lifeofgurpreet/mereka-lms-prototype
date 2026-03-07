#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SUMMARY_JSON=""
FILES=()
INCLUDE_BASELINE=0
BASELINE_FILE="docs/qa/.doc-command-ref-baseline"

while (($# > 0)); do
  case "$1" in
    --summary-json)
      SUMMARY_JSON="${2-}"
      shift 2
      ;;
    --include-baseline)
      INCLUDE_BASELINE=1
      shift
      ;;
    --baseline-file)
      BASELINE_FILE="${2-}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage:
  verify-doc-command-refs.sh [--summary-json <path>] [--include-baseline] [--baseline-file <path>] [docs/...]

Options:
  --summary-json <path>   write JSON summary for CI/reporting
  --include-baseline      include baseline high-risk docs from --baseline-file
  --baseline-file <path>  baseline docs list (default: docs/qa/.doc-command-ref-baseline)
EOF
      exit 0
      ;;
    --)
      shift
      while (($# > 0)); do
        FILES+=("$1")
        shift
      done
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      FILES+=("$1")
      shift
      ;;
  esac
done

if ((${#FILES[@]} > 0)); then
  mapfile -t FILES < <(printf "%s\n" "${FILES[@]}")
else
  if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
    mapfile -t FILES < <(git diff --name-only HEAD~1...HEAD -- 'docs/**/*.md' 'docs/*.md')
  else
    mapfile -t FILES < <(git ls-files 'docs/**/*.md' 'docs/*.md')
  fi
fi

if [ "$INCLUDE_BASELINE" -eq 1 ]; then
  if [ ! -f "$BASELINE_FILE" ]; then
    echo "Baseline file not found: $BASELINE_FILE" >&2
    exit 1
  fi
  mapfile -t BASELINE_FILES < <(grep -v '^[[:space:]]*#' "$BASELINE_FILE" | sed '/^[[:space:]]*$/d')
  if ((${#BASELINE_FILES[@]} > 0)); then
    FILES+=("${BASELINE_FILES[@]}")
  fi
fi

if ((${#FILES[@]} > 0)); then
  mapfile -t FILES < <(printf "%s\n" "${FILES[@]}" | awk '!seen[$0]++')
fi

BASELINE_ENTRIES=0
if [ "$INCLUDE_BASELINE" -eq 1 ]; then
  BASELINE_ENTRIES=${#BASELINE_FILES[@]}
fi

if ((${#FILES[@]} == 0)); then
  echo "No docs files to validate."
  if [ -n "$SUMMARY_JSON" ]; then
    mkdir -p "$(dirname "$SUMMARY_JSON")"
    cat > "$SUMMARY_JSON" <<'EOF_JSON'
{
  "files_checked": 0,
  "baseline_enabled": false,
  "baseline_entries": 0,
  "total_candidates": 0,
  "missing_references": 0,
  "status": "pass",
  "missing": []
}
EOF_JSON
  fi
  exit 0
fi

DOCS_CMDREF_SUMMARY_PATH="$SUMMARY_JSON" \
DOCS_CMDREF_BASELINE_ENABLED="$INCLUDE_BASELINE" \
DOCS_CMDREF_BASELINE_ENTRIES="$BASELINE_ENTRIES" \
python3 - "$REPO_ROOT" "${FILES[@]}" <<'PY'
import re
import shlex
import sys
from pathlib import Path
import json
import os
import fnmatch

repo_root = Path(sys.argv[1])
summary_path = os.environ.get("DOCS_CMDREF_SUMMARY_PATH", "")
baseline_enabled = os.environ.get("DOCS_CMDREF_BASELINE_ENABLED", "0") == "1"
baseline_entries = int(os.environ.get("DOCS_CMDREF_BASELINE_ENTRIES", "0"))
SKIP_PATH_PREFIXES = (
    "docs/archive/",
)

files = [
    Path(p)
    for p in sys.argv[2:]
    if (repo_root / p).exists() and not str(p).startswith(SKIP_PATH_PREFIXES)
]

if not files:
    print("DOCS_CMDREF_OK (0 files to check)")
    raise SystemExit(0)

inline_code_re = re.compile(r"`([^`]+)`")
markdown_link_re = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
markdown_autolink_re = re.compile(r"<([^>\s]+)>")
markdown_ref_def_re = re.compile(r"^\s*\[[^\]]+\]:\s+(<[^>]+>|[^ ]+)")
fence_start_re = re.compile(r"^```(.*)$")

ALLOWED_PREFIXES = (
    "a/",
    "b/",
    "docs/",
    "scripts/",
    "deploy/",
    "services/",
    ".github/",
    "assets/",
    "infrastructure/",
    "infrastructure/tutor/",
    "infrastructure/k8s/",
    "infrastructure/monitoring/",
    "scripts/qa/",
    "scripts/infra/",
    "docs/qa/",
)

DEFAULT_ALLOWED_MISSING_PREFIXES = (
    "scripts/migrations/kajabi/output/",
    "scripts/migrations/mct/output/",
    "scripts/migrations/kajabi/logs/",
    "services/kajabi-webhook/outbox/",
)


def _load_allowlisted_prefixes():
    """Load optional path allowlist extensions for generated artifacts."""

    allowlist_path = os.environ.get(
        "DOC_COMMAND_REF_ALLOWLIST_FILE",
        "docs/qa/.doc-command-ref-allowlist",
    )

    path = Path(allowlist_path)
    if not path.is_absolute():
        path = repo_root / path

    if not path.exists():
        return DEFAULT_ALLOWED_MISSING_PREFIXES

    prefixes = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        token = raw.strip()
        if not token or token.startswith("#"):
            continue
        prefixes.append(token)

    return tuple(default for default in DEFAULT_ALLOWED_MISSING_PREFIXES) + tuple(prefixes)


ALLOWED_MISSING_PREFIXES = tuple(dict.fromkeys(_load_allowlisted_prefixes()))

VALID_EXTS = {
    ".sh",
    ".py",
    ".yml",
    ".yaml",
    ".json",
    ".md",
    ".mdx",
    ".js",
    ".ts",
    ".tsx",
    ".toml",
    ".tf",
    ".txt",
    ".ini",
    ".cfg",
    ".conf",
    ".sql",
    ".png",
    ".svg",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".pdf",
}


def sanitize(token: str) -> str:
    token = token.strip()
    token = token.lstrip("$")
    token = token.strip("`\"'")
    token = token.strip()
    for suffix in (";", ")", "(", "{", "}", "]", "[", "\\", ",", ":", "|", "&", "`"):
        token = token.rstrip(suffix)
    # Allow markdown/file references with optional line/column suffixes.
    token = re.sub(r"#L\d+(?:C\d+)?$", "", token)
    token = re.sub(r":\d+(?::\d+)?$", "", token)
    token = token.lstrip("./") if token.startswith("./") else token
    return token


def is_repo_path_candidate(token: str) -> bool:
    if not token:
        return False
    if " " in token:
        return False
    if token.startswith(("http://", "https://", "mailto:", "ftp://")):
        return False
    if token.startswith("/"):
        return False
    if token.startswith("#"):
        return False
    if token.startswith("$"):
        return False
    if any(ch in token for ch in ("*", "?", "<", ">", "[", "]", "{", "}", "@", ":")):
        return False
    if "..." in token:
        return False
    if "$(" in token or "${" in token:
        return False
    if ".." in token.split("/")[0]:
        return False
    if not any(token.startswith(prefix) for prefix in ALLOWED_PREFIXES):
        return False
    if token.endswith("/"):
        return True

    p = Path(token)
    if p.suffix:
        return p.suffix in VALID_EXTS

    # Directory-only references are allowed only with a trailing slash.
    return False


def candidate_exists(token: str) -> bool:
    token_path = token.strip()
    if not token_path:
        return False

    # Allow placeholder/template-style references used for generated docs.
    if re.search(r"(^|/)YYYY", token_path):
        return True
    if re.search(r"(^|/)Q[0-9xX]($|/)", token_path):
        return True
    if re.search(r"(^|/)YYYYMMDD($|/)", token_path):
        return True
    if re.search(r"\\{\\{.*\\}\\}", token_path):
        return True

    candidate_paths = [token_path]
    if token_path.startswith(("a/", "b/")):
        candidate_paths.append(token_path[2:])

    for candidate_path in candidate_paths:
        target = (repo_root / candidate_path).resolve()
        try:
            target.relative_to(repo_root)
        except ValueError:
            continue
        if target.is_file() or target.is_dir():
            return True

    for allowed_prefix in ALLOWED_MISSING_PREFIXES:
        if any(c in allowed_prefix for c in ("*", "?", "[")):
            if fnmatch.fnmatch(token_path, allowed_prefix):
                return True
        elif token_path.startswith(allowed_prefix):
            return True
    return False


all_missing = []
total_candidates = 0

for path in files:
    rel = path.as_posix()
    text = path.read_text(encoding="utf-8", errors="ignore")

    in_block = False
    block_lang = ""
    for idx, line in enumerate(text.splitlines(), start=1):
        raw = line.rstrip("\n")
        stripped = raw.strip()

        m = fence_start_re.match(stripped)
        if m:
            if in_block:
                in_block = False
                block_lang = ""
            else:
                in_block = True
                block_lang = (m.group(1) or "").strip().lower()
            continue

        if not in_block:
            for match in inline_code_re.finditer(raw):
                segment = match.group(1)
                if not segment:
                    continue
                for token in segment.replace("\n", " ").split():
                    token = sanitize(token)
                    if not is_repo_path_candidate(token):
                        continue
                    total_candidates += 1
                    if not candidate_exists(token):
                        all_missing.append(f"{rel}:{idx}: missing inline path reference `{token}`")
            for match in markdown_link_re.finditer(raw):
                target = (match.group(1) or "").strip()
                if not target:
                    continue
                token = sanitize(target.split()[0])
                if not is_repo_path_candidate(token):
                    continue
                total_candidates += 1
                if not candidate_exists(token):
                    all_missing.append(f"{rel}:{idx}: missing markdown-link path reference `{token}`")
            for match in markdown_autolink_re.finditer(raw):
                token = sanitize(match.group(1) or "")
                if not is_repo_path_candidate(token):
                    continue
                total_candidates += 1
                if not candidate_exists(token):
                    all_missing.append(f"{rel}:{idx}: missing markdown-autolink path reference `{token}`")
            ref_def_match = markdown_ref_def_re.match(raw)
            if ref_def_match:
                token = sanitize(ref_def_match.group(1))
                if is_repo_path_candidate(token):
                    total_candidates += 1
                    if not candidate_exists(token):
                        all_missing.append(f"{rel}:{idx}: missing markdown-refdef path reference `{token}`")
            continue

        # inside shell block
        if block_lang and block_lang not in {"", "bash", "sh", "shell", "zsh", "console", "powershell"}:
            continue

        if not stripped or stripped.startswith("#"):
            continue

        cleaned = stripped.lstrip()
        if cleaned.startswith("$"):
            cleaned = cleaned[1:].strip()

        try:
            tokens = shlex.split(cleaned)
        except ValueError:
            tokens = cleaned.replace("\\", " ").split()

        for token in tokens:
            token = sanitize(token)
            if not token:
                continue
            if token in {"cd", "source", "bash", "sh", "tutor", "kubectl", "git", "make", "npm", "yarn", "python", "python3", "node", "gh", "helm", "sed", "rg", "find", "docker", "helmfile", "terraform", "ansible", "apply_patch", "grep", "awk", "curl", "wget", "openssl", "jq"}:
                continue
            if not is_repo_path_candidate(token):
                continue
            total_candidates += 1
            if not candidate_exists(token):
                all_missing.append(f"{rel}:{idx}: missing shell path reference `{token}`")

# De-duplicate for readability.
all_missing = sorted(set(all_missing))

if all_missing:
    print(f"DOCS_CMDREF_ERRORS ({len(all_missing)}/{total_candidates} missing)")
    for item in all_missing:
        print(f"- {item}")
    if summary_path:
        Path(summary_path).parent.mkdir(parents=True, exist_ok=True)
        Path(summary_path).write_text(
            json.dumps(
                {
                    "files_checked": len(files),
                    "baseline_enabled": baseline_enabled,
                    "baseline_entries": baseline_entries,
                    "total_candidates": total_candidates,
                    "missing_references": len(all_missing),
                    "status": "fail",
                    "missing": all_missing,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
    raise SystemExit(1)

if summary_path:
    Path(summary_path).parent.mkdir(parents=True, exist_ok=True)
    Path(summary_path).write_text(
        json.dumps(
            {
                "files_checked": len(files),
                "baseline_enabled": baseline_enabled,
                "baseline_entries": baseline_entries,
                "total_candidates": total_candidates,
                "missing_references": len(all_missing),
                "status": "pass",
                "missing": [],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
print(f"DOCS_CMDREF_OK ({len(files)} files, 0 missing command references, {total_candidates} candidate path refs)")
PY
