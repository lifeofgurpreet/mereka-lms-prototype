from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CODEQL_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "codeql.yml"


def test_codeql_scope_job_emits_dynamic_matrix() -> None:
    workflow_text = CODEQL_WORKFLOW.read_text(encoding="utf-8")

    assert "should_run: ${{ steps.scope.outputs.should_run }}" in workflow_text
    assert "language_matrix: ${{ steps.scope.outputs.language_matrix }}" in workflow_text
    assert "language_matrix={\"language\":[%s]}" in workflow_text
    assert "matrix: ${{ fromJSON(needs.change-scope.outputs.language_matrix) }}" in workflow_text


def test_codeql_analyze_job_does_not_gate_on_matrix_before_expansion() -> None:
    workflow_text = CODEQL_WORKFLOW.read_text(encoding="utf-8")

    assert "if: needs.change-scope.outputs.should_run == 'true'" in workflow_text
    assert "(matrix.language == 'python'" not in workflow_text
    assert "(matrix.language == 'javascript-typescript'" not in workflow_text
