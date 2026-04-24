#!/usr/bin/env bash
# test-discovery-init-task-contract.sh - fixture tests for Discovery init authority.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d -t discovery-init-contract.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/tutor"
cat >"$TMP_DIR/tutor/__init__.py" <<'PY'
PY
cat >"$TMP_DIR/tutor/hooks.py" <<'PY'
class _Filter:
    def add(self, priority=None):
        def decorator(func):
            return func
        return decorator


class Filters:
    CLI_DO_INIT_TASKS = _Filter()


class priorities:
    LOW = 100
PY

export REPO_ROOT
PYTHONPATH="$TMP_DIR:$REPO_ROOT/infrastructure/tutor/plugins${PYTHONPATH:+:$PYTHONPATH}" python3 - <<'PY'
from __future__ import annotations

import os
import sys
from importlib import util
from pathlib import Path

repo_root = Path(os.environ["REPO_ROOT"])
module_path = repo_root / "infrastructure/tutor/plugins/_mereka_lms/discovery_init.py"
spec = util.spec_from_file_location("mereka_discovery_init", module_path)
if spec is None or spec.loader is None:
    raise RuntimeError(f"failed to load Discovery init module spec from {module_path}")
module = util.module_from_spec(spec)
sys.modules["mereka_discovery_init"] = module
spec.loader.exec_module(module)

_DISCOVERY_INIT_TASK = module._DISCOVERY_INIT_TASK
replace_discovery_init_tasks = module.replace_discovery_init_tasks

passes = 0
failures = 0


def pass_(name: str) -> None:
    global passes
    print(f"PASS {name}")
    passes += 1


def fail(name: str, detail: str) -> None:
    global failures
    print(f"FAIL {name}: {detail}", file=sys.stderr)
    failures += 1


def check(name: str, condition: bool, detail: str) -> None:
    if condition:
        pass_(name)
    else:
        fail(name, detail)


def expect_runtime_error(name: str, tasks: list[tuple[str, str]], snippet: str) -> None:
    try:
        replace_discovery_init_tasks(tasks)
    except RuntimeError as exc:
        message = str(exc)
        check(name, snippet in message, f"expected {snippet!r} in {message!r}")
        return
    fail(name, "expected RuntimeError")


upstream_task = """
make migrate

./manage.py create_or_update_partner \
  --site-id 1 \
  --site-domain {{ DISCOVERY_HOST }}:8381 \
  --code dev \
  --name "Open edX - development" \
  --lms-url="http://{{ LMS_HOST }}:8000" \
  --studio-url="http://{{ CMS_HOST }}:8000" \
  --courses-api-url "http://{{ LMS_HOST }}:8000/api/courses/v1/" \
  --organizations-api-url "http://{{ LMS_HOST }}:8000/api/organizations/v1/"

./manage.py refresh_course_metadata --partner_code=$DEFAULT_PARTNER_CODE
./manage.py update_index --disable-change-limit
"""

tasks = [
    ("mysql", "echo mysql"),
    ("discovery", upstream_task),
    ("lms", "echo lms"),
]
replaced = replace_discovery_init_tasks(tasks)

check(
    "replaces exactly one Discovery init task",
    len(replaced) == len(tasks)
    and replaced[1] == ("discovery", _DISCOVERY_INIT_TASK)
    and sum(1 for service, task in replaced if service == "discovery" and task == _DISCOVERY_INIT_TASK) == 1,
    "canonical Discovery init task was not installed exactly once",
)
check(
    "replaced Discovery init uses container DNS API URLs",
    "http://lms:8000/api/courses/v1/" in replaced[1][1]
    and "http://lms:8000/api/organizations/v1/" in replaced[1][1],
    "container DNS API URLs are missing",
)
check(
    "replaced Discovery init removes browser-facing API URLs",
    "{{ LMS_HOST }}" not in replaced[1][1] and "http://localhost" not in replaced[1][1],
    "browser-facing LMS URL markers remain in canonical task",
)
check(
    "Discovery init replacement is idempotent",
    replace_discovery_init_tasks(replaced) == replaced,
    "second replacement pass changed the task list",
)
check(
    "Discovery disabled task lists are left unchanged",
    replace_discovery_init_tasks([("lms", "echo lms")]) == [("lms", "echo lms")],
    "non-Discovery init tasks should not be modified",
)

drift_task = upstream_task.replace(
    "./manage.py refresh_course_metadata --partner_code=$DEFAULT_PARTNER_CODE\n",
    "",
)
expect_runtime_error(
    "selector drift fails loudly when upstream command shape changes",
    [("discovery", drift_task)],
    "Discovery init task selector drift",
)
expect_runtime_error(
    "duplicate Discovery init candidates fail closed",
    [("discovery", upstream_task), ("discovery", upstream_task)],
    "expected exactly one supported upstream Discovery init partner task",
)
expect_runtime_error(
    "unmatched browser-facing Discovery API URLs fail closed",
    [
        ("discovery", upstream_task),
        ("discovery", 'curl "http://{{ LMS_HOST }}:8000/api/courses/v1/"'),
    ],
    "browser-facing LMS API URLs remain after replacement",
)

print(f"Summary: PASS={passes} FAIL={failures}")
sys.exit(1 if failures else 0)
PY
