from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PYTHON_ACTION = REPO_ROOT / ".github" / "actions" / "setup-python-playwright" / "action.yml"
NODE_ACTION = REPO_ROOT / ".github" / "actions" / "setup-playwright" / "action.yml"
SMOKE_UNAUTHENTICATED_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "smoke-unauthenticated.yml"
SMOKE_AUTHENTICATED_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "smoke-authenticated.yml"
OPERATIONS_GATES_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "operations-gates-runtime.yml"


def test_python_playwright_setup_action_caches_and_repairs_browsers() -> None:
    action_text = PYTHON_ACTION.read_text(encoding="utf-8")

    assert "Set up Python Playwright" in action_text
    assert "uses: ./.github/actions/setup-python-env" in action_text
    assert "path: ~/.cache/ms-playwright" in action_text
    assert "key: playwright-py-${{ inputs.playwright-version }}-${{ runner.os }}" in action_text
    assert 'python -m playwright install "${args[@]}"' in action_text
    assert 'with sync_playwright() as playwright:' in action_text
    assert 'if [[ "${{ inputs.install-system-deps }}" == "true" ]]; then' in action_text


def test_unauthenticated_smoke_uses_shared_playwright_setup_action() -> None:
    workflow_text = SMOKE_UNAUTHENTICATED_WORKFLOW.read_text(encoding="utf-8")

    assert "uses: ./.github/actions/setup-playwright" in workflow_text
    assert "npm-cache-dependency-path: tests/e2e/package-lock.json" in workflow_text
    assert "run: npm ci" in workflow_text
    assert "npx playwright install --with-deps chromium" not in workflow_text


def test_python_canary_workflows_use_shared_python_playwright_setup_action() -> None:
    smoke_workflow_text = SMOKE_AUTHENTICATED_WORKFLOW.read_text(encoding="utf-8")
    operations_workflow_text = OPERATIONS_GATES_WORKFLOW.read_text(encoding="utf-8")

    assert "uses: ./.github/actions/setup-python-playwright" in smoke_workflow_text
    assert "playwright-version: '1.50.0'" in smoke_workflow_text
    assert "python -m playwright install chromium" not in smoke_workflow_text
    assert "path: ~/.cache/ms-playwright" not in smoke_workflow_text

    assert "uses: ./.github/actions/setup-python-playwright" in operations_workflow_text
    assert "install-system-deps: 'true'" in operations_workflow_text
    assert "python -m playwright install --with-deps chromium" not in operations_workflow_text


def test_workflow_playwright_bootstrap_surfaces_route_through_shared_actions() -> None:
    combined_text = "\n".join(
        [
            NODE_ACTION.read_text(encoding="utf-8"),
            PYTHON_ACTION.read_text(encoding="utf-8"),
            SMOKE_UNAUTHENTICATED_WORKFLOW.read_text(encoding="utf-8"),
            SMOKE_AUTHENTICATED_WORKFLOW.read_text(encoding="utf-8"),
            OPERATIONS_GATES_WORKFLOW.read_text(encoding="utf-8"),
        ]
    )

    assert "npx playwright install --with-deps chromium" not in combined_text
    assert "python -m playwright install --with-deps chromium" not in combined_text
