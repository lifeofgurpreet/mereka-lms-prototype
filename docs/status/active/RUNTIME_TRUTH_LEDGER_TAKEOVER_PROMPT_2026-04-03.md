# Runtime Truth Ledger Takeover Prompt — 2026-04-03

Read first:

1. [`docs/status/active/RUNTIME_TRUTH_LEDGER_TRACKER_2026-04-03.md`](RUNTIME_TRUTH_LEDGER_TRACKER_2026-04-03.md)
2. [`docs/ops/EXECUTION_DOCTRINE.md`](../../ops/EXECUTION_DOCTRINE.md)
3. [`scripts/acceptance/runtime-routing.sh`](../../../scripts/acceptance/runtime-routing.sh)
4. [`scripts/release/generate_truth_ledger.py`](../../../scripts/release/generate_truth_ledger.py)

Immediate first task:

- Check whether `mereka-lms#1302` cleared on head
  `55c932f75d4144cba8d5a6789aa7ab0fa8dd426a`.
- If yes, merge and move directly into image-build and dev-promotion truth.
- If no, classify the failure before editing anything.

Non-negotiable rules:

- Do not claim runtime closure from PR merge alone.
- Do not claim live truth from Argo sync alone.
- Do not hand-join repo, infra, Argo, and runtime state in chat when the
  ledger can record it.
- Keep `bin/accept` as the human front door.

Current branch/worktree:

- app follow-on branch: `feat/runtime-truth-ledger`
- worktree: `/tmp/mereka-truth-ledger`

Minimum acceptable success before stopping:

- runtime-routing proof bundle emits both `summary.json` and `truth-ledger.json`
- truth ledger is schema-stable and test-covered
- the active lane is either merged and moving through promotion, or blocked
  with one explicit failing gate and one next action
