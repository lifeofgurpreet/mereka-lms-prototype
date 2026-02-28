#!/usr/bin/env bash
# @covers AC-007, AC-011
# @spec: branding-system_spec.md
# Refresh assets/branding/tokens.provenance.json from the upstream branding repo.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UPSTREAM_REPO="${BRAND_ASSETS_REPO:-/home/gurpreet/projects/bbbi-mereka-brand-assets}"
UPSTREAM_PATH="${UPSTREAM_TOKEN_PATH:-brands/mereka/tokens/tokens.css}"
PROVENANCE_PATH="$REPO_ROOT/assets/branding/tokens.provenance.json"
TARGET_TOKENS="$REPO_ROOT/assets/branding/tokens.css"
SYNC_FILE="${SYNC_FILE:-0}"

if [[ ! -d "$UPSTREAM_REPO/.git" ]]; then
  echo "Upstream repo not found: $UPSTREAM_REPO" >&2
  exit 1
fi
if [[ ! -f "$UPSTREAM_REPO/$UPSTREAM_PATH" ]]; then
  echo "Upstream tokens file not found: $UPSTREAM_REPO/$UPSTREAM_PATH" >&2
  exit 1
fi

commit="$(git -C "$UPSTREAM_REPO" rev-parse HEAD)"
branch="$(git -C "$UPSTREAM_REPO" rev-parse --abbrev-ref HEAD)"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ "$SYNC_FILE" == "1" ]]; then
  cp "$UPSTREAM_REPO/$UPSTREAM_PATH" "$TARGET_TOKENS"
  echo "Synced tokens.css from upstream."
fi

# Always hash the canonical file used by runtime checks in this repo.
# This keeps provenance in sync even after intentional local token updates.
sha="$(sha256sum "$TARGET_TOKENS" | awk '{print $1}')"

python3 - "$PROVENANCE_PATH" "$commit" "$branch" "$sha" "$UPSTREAM_PATH" "$ts" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
commit = sys.argv[2]
branch = sys.argv[3]
sha = sys.argv[4]
source_path = sys.argv[5]
synced_at = sys.argv[6]

payload = {}
if path.exists():
    payload = json.loads(path.read_text(encoding="utf-8"))

payload.update(
    {
        "source_repo": "https://github.com/Biji-Biji-Initiative/bbbi-mereka-brand-assets",
        "source_path": source_path,
        "source_branch": branch,
        "source_commit": commit,
        "source_sha256": sha,
        "synced_at_utc": synced_at,
    }
)

path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
print(f"Updated {path}")
PY

echo "Done."
