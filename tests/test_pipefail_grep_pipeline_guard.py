from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "scripts" / "qa" / "spec-tools" / "check_pipefail_grep_pipelines.py"


spec = importlib.util.spec_from_file_location("check_pipefail_grep_pipelines", SCRIPT_PATH)
assert spec is not None and spec.loader is not None
_mod = importlib.util.module_from_spec(spec)
sys.modules["check_pipefail_grep_pipelines"] = _mod
spec.loader.exec_module(_mod)  # type: ignore[union-attr]


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def test_detects_active_static_echo_quiet_grep_pipeline(tmp_path: Path) -> None:
    write(tmp_path / ".github" / "ci-scripts-static.txt", "scripts/qa/bad.sh\n")
    write(
        tmp_path / "scripts" / "qa" / "bad.sh",
        """#!/usr/bin/env bash
set -euo pipefail
if echo "$body" | grep -q foo; then
  true
fi
""",
    )

    findings = _mod.scan_repo(tmp_path)

    assert len(findings) == 1
    assert findings[0].classification == "active_static_gate"
    assert findings[0].path == "scripts/qa/bad.sh"


def test_ignores_here_strings_and_comments(tmp_path: Path) -> None:
    write(
        tmp_path / "scripts" / "qa" / "safe.sh",
        """#!/usr/bin/env bash
set -euo pipefail
# echo "$body" | grep -q foo
if grep -q foo <<<"$body"; then
  true
fi
""",
    )

    assert _mod.scan_repo(tmp_path) == []


def test_classifies_runtime_inventory_separately(tmp_path: Path) -> None:
    write(tmp_path / ".github" / "ci-scripts-runtime.txt", "scripts/qa/runtime.sh  # LIVE_CLUSTER\n")
    write(
        tmp_path / "scripts" / "qa" / "runtime.sh",
        """#!/usr/bin/env bash
set -euo pipefail
printf '%s' "$status" | grep -qE '^(200|302)$'
""",
    )

    findings = _mod.scan_repo(tmp_path)

    assert len(findings) == 1
    assert findings[0].classification == "active_runtime_gate"


def test_allowlist_suppresses_static_gate_blocker(tmp_path: Path) -> None:
    write(tmp_path / ".github" / "ci-scripts-static.txt", "scripts/qa/allowed.sh\n")
    write(
        tmp_path / "scripts" / "qa" / "allowed.sh",
        """#!/usr/bin/env bash
set -euo pipefail
if echo "$body" | grep -q allowed; then
  true
fi
""",
    )
    allowlist = tmp_path / "allow.json"
    allowlist.write_text(
        json.dumps(
            [
                {
                    "path": "scripts/qa/allowed.sh",
                    "classification": "active_static_gate",
                    "match": 'echo "$body" | grep -q allowed',
                    "reason": "fixture",
                    "bead": "mereka-lms-0z5g.6",
                }
            ]
        ),
        encoding="utf-8",
    )

    result = subprocess.run(
        [sys.executable, str(SCRIPT_PATH), "--repo-root", str(tmp_path), "--allowlist", str(allowlist)],
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS: no unreviewed pipefail-prone quiet grep pipelines" in result.stdout
