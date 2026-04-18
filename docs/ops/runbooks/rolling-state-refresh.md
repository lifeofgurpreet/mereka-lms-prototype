---
title: Rolling State Refresh — Operator Runbook
type: runbook
owner: platform-release
observed_at: 2026-04-18
status: active
bead: mereka-lms-q69f.2
---

# Rolling State Refresh — Operator Runbook

## Purpose

Regenerate `docs/status/active/CURRENT-OPERATOR-STATE.md` from live sources so the next operator, agent, or reviewer is reading truth, not narrative. This runbook covers: when to run, how to invoke, what a healthy output looks like, and how to diagnose common failure modes.

## Audience

- Platform operators on `ssh mereka` starting or ending a working session.
- Agents beginning a cron-triggered slice (`/loop`).
- Reviewers inspecting the current PR queue / cluster state before signing off on work.

## Governing doctrine

This runbook enforces **Truth Repair Doctrine Rule 1** (`docs/meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md`): *canonical state is generated, not written*. `CURRENT-OPERATOR-STATE.md` is the rolling authority file for the four truth surfaces (live cluster, PR queue, tracker, repo) — and the only trustworthy version is one freshly emitted from those sources.

## When to run

Run the generator when:

1. **Starting an operator slice** (autonomous or manual). Read the file, then regenerate before trusting any prose section in it.
2. **Ending an operator slice** — update the "Next Exact Move" block with a specific instruction for the next iteration, then regenerate the dynamic sections from live state.
3. **Investigating a PR or cluster anomaly** — compare what the rolling file said vs live. If they disagree, trust live and regenerate.
4. **After a significant merge to `main`** — multiple PRs landing in quick succession makes the prior rolling file stale.
5. **When you're about to hand off to another operator / agent** — they deserve fresh truth, not whatever was captured when you started.

## Invocation

From the repo root:

```bash
bash scripts/governance/generate-current-operator-state.sh
```

**Flags**:

| Flag | Default | Purpose |
|---|---|---|
| `--file PATH` | `docs/status/active/CURRENT-OPERATOR-STATE.md` | Edit a different file (e.g. dry run to a scratch path). |
| `--no-cluster` | off | Skip kubectl live-cluster section — useful in CI where cluster is unreachable; all other sections still update. |
| `--dry-run` | off | Print updated file to stdout; do not touch disk. Use when previewing changes. |
| `-h` / `--help` | — | Show inline help and exit. |

## What a healthy run looks like

```
$ bash scripts/governance/generate-current-operator-state.sh
updated /home/gurpreet/projects/k8s/mereka-lms/docs/status/active/CURRENT-OPERATOR-STATE.md at 2026-04-18T17:17Z
```

One line of stderr output, no errors, no warnings. The file's three dynamic sections are rewritten:

- `## Current Live Truth` — Argo app state + deployment readiness summary, context-pinned `rke2-nonprod`.
- `## Current Queue Truth` — open + recently-merged PRs for both repos, `br` ready queue.
- `## Next Exact Move` — HEAD SHA + branch + default next-move template + any `### Pointed next move` block you already wrote.

The stable skeleton (Purpose, Operating Rules, Refresh Procedure, Standing Priorities, Known Durable Workstreams) is preserved verbatim. Hand-edits to the stable sections ARE authority. Hand-edits to the dynamic sections are drafts — re-run to reset.

## Dependencies

- `gh` (GitHub CLI) — authenticated against `Biji-Biji-Initiative/` org
- `jq` — JSON parsing
- `git` — repo introspection
- `br` — beads tracker CLI (CLI must be on `$PATH`)
- `python3` — regex-based section replacement in the output file
- `kubectl` — only if `--no-cluster` is NOT passed; context `rke2-nonprod` must be known to your kubeconfig

If any are missing, the script exits with error code 1 naming the missing command.

## Common failure modes

### 1. GitHub API rate limit

**Symptom**: `gh pr list` returns `GraphQL: API rate limit already exceeded` or `HTTP 403`. Dynamic queue section shows stale data or empty PR list.

**Diagnose**:

```bash
gh api rate_limit | python3 -c 'import sys,json; d=json.load(sys.stdin); [print(k,v["remaining"],"reset_in_min",(v["reset"]-__import__("time").time())/60) for k,v in d["resources"].items() if k in ("core","graphql","search")]'
```

**Fix**: wait for reset. Minutes-scale. If urgent, use `--no-cluster` and skip the PR section, OR manually edit the "Pointed next move" block to record whatever you know and accept the stale queue snapshot until rate limit clears.

**Prevention**: the script does not batch gh calls into GraphQL. A known follow-up is to consolidate PR queries into a single GraphQL call; tracked under `q69f` if it recurs often.

### 2. Ambient kubectl context is wrong

**Symptom**: `Current Live Truth` table shows `ambient kubectl context at generation: rke2-prod` (or something other than `rke2-nonprod`).

Note: the script **pins `--context rke2-nonprod` explicitly** on every kubectl command inside it, so the Argo / deployment data is STILL correct. But the "ambient" field surfaces that your shell's context is drifted — a foot-gun for subsequent manual commands.

**Fix**:

```bash
kubectl config use-context rke2-nonprod
kubectl config current-context  # must print: rke2-nonprod
```

Then regenerate.

### 3. Catalog drift after main advance

**Symptom**: script exits cleanly, but your PR branch then fails CI with `verify-verification-catalog` FAIL.

**Diagnose**: `main` advanced while you were editing; the catalog on your branch is stale.

**Fix**:

```bash
git fetch origin main --quiet
git rebase origin/main
bash scripts/qa/regen-verification-catalog.sh
git add verification/catalogs/
git commit -m "chore(governance): regen catalog after rebase on main"
git push
```

This is an adjacent concern to the rolling state file; the generator does not touch the catalog.

### 4. `br sync --flush-only` reports "Nothing to export"

Not a failure. The beads database has no unflushed writes since the last sync. The generator will still read `br ready` correctly.

### 5. `br ready` returns no output but exits 0

**Symptom**: `Ready work from \`br ready\`` section in the regenerated file shows `(no rows)`.

**Diagnose**: either the tracker is empty (genuinely), the beads DB is in a degraded state (see `docs/status/active/TRACKER-HYGIENE-RECOVERY-PLAN.md`), or the `br` CLI is not on `$PATH`.

**Fix**: run `br doctor` and follow its repair output. If `br doctor` surfaces sqlite corruption, run `br doctor --repair` to rebuild the DB from JSONL.

### 6. Generator output section has placeholder `—`

**Symptom**: `revision: \`—\`` or `health: \`—\`` appears instead of real values.

**Diagnose**: kubectl could not reach `rke2-nonprod`, OR the `mereka-lms-dev` ArgoCD Application does not exist at the expected path.

**Fix**: `kubectl --context rke2-nonprod -n argocd get application mereka-lms-dev` should return the app. If it doesn't, your kubeconfig is missing the `rke2-nonprod` context; re-sync it from the infra repo's kubeconfig distribution.

## The "Next Exact Move" block

The generator emits a default block; do NOT rely on the default. Before ending an operator slice, **replace the default with a specific instruction** for the next iteration. Examples of good blocks:

- *"Slice N+1 should: rebase #1825 and #1828, then close y69t.2 bead when #1825 lands. If CI is still blocked, read shard-03 log and check for catalog drift."*
- *"If you see dev rev stuck > 30 min past a promotion PR merge, check argocd application sync-state and audit the `ArgoAppSelfHealStuck` runbook."*

Bad blocks:

- *"Keep working the queue."* — no specific action, next reader has to re-derive.
- *"Fix any CI fails."* — no specific PR, no specific fail class.

The default block is a floor, not a plan. Overwrite it.

## Do NOT

- Do NOT hand-edit `## Current Live Truth`, `## Current Queue Truth`, or `## Next Exact Move` as drafts that persist. These are rewritten every generator run. Edit the "Pointed next move" block within "Next Exact Move" if you need a human-authored instruction — that's preserved because it's appended INSIDE the section after the default text.
- Do NOT edit the stable skeleton sections (Purpose, Operating Rules, etc.) unless the operating doctrine has changed. Those edits survive regeneration, but they change how every future reader interprets the file.
- Do NOT set `status: canonical` on status docs under `docs/status/active/` — `verify-process-invariants.sh` Gate 4 blocks that. Use `rolling`, `active`, `reusable`, or `draft`.
- Do NOT add workstation-specific paths (e.g. `/home/gurpreet/...`) to any status doc — `verify-docs-authority-invariants.sh` rejects these. Use `Biji-Biji-Initiative/<repo>` slugs.

## Related

- Bead: `mereka-lms-q69f.2` (this runbook)
- Parent bead: `mereka-lms-q69f` (Script First-Class Program)
- Script: `scripts/governance/generate-current-operator-state.sh` (the generator)
- Rolling file: `docs/status/active/CURRENT-OPERATOR-STATE.md`
- Doctrine: `docs/meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md` Rule 1
- Tracker hygiene reference: `docs/status/active/TRACKER-HYGIENE-RECOVERY-PLAN.md`
