---
title: VPS session preflight
type: runbook
status: active
owner: platform-release
---

# VPS session preflight

Every `ssh mereka` session — human or agent — starts with a checkout
preflight so that "what's the current image?", "what's the overlay?",
and "what's the promotion state?" have unambiguous answers grounded in
the checkout state actually in use.

Closes half of bead `mereka-lms-p74m` (VPS checkouts are not canonical).
The other half (restoring / documenting the platform-control-plane
checkout) is a separate follow-up.

## What the preflight shows

`scripts/infra/preflight-checkouts.sh` prints for each canonical
checkout:

- **branch** — the branch currently checked out
- **HEAD** — short sha + one-line subject of the working tip
- **origin/main** — short sha of the remote main at last fetch
- **ahead / behind** — commit counts vs origin/main
- **mods / untracked** — dirty state (staged + unstaged modifications,
  untracked files)
- **fetched** — time since last `git fetch`

## Which checkouts

The canonical checkouts today are:

- `~/projects/k8s/mereka-lms` — this app repo (LMS app, Tutor,
  deploy/k8s/base + overlays/local).
- `~/projects/k8s/bbi-infrastructure` — platform GitOps repo (overlays
  consumed by ArgoCD, ARC runner set, vendored charts).

If `platform-control-plane` or another repo becomes canonical for
release proof, add it to the `CHECKOUTS` array in
`scripts/infra/preflight-checkouts.sh`.

## Usage

```bash
# Default: iterates $HOME/projects/k8s/{mereka-lms,bbi-infrastructure}
bash scripts/infra/preflight-checkouts.sh

# Override the root (for non-standard layouts):
CHECKOUT_ROOT=/srv/checkouts bash scripts/infra/preflight-checkouts.sh

# Skip the banner (for chaining into other output):
bash scripts/infra/preflight-checkouts.sh --quiet
```

Sample output:

```
=== VPS Checkout Preflight ===
CHECKOUT_ROOT=/home/gurpreet/projects/k8s
timestamp=2026-04-19T08:13:15Z
---
mereka-lms             branch=main                HEAD=ad8bb06e9 (docs(evidence): Tier-A scorecard)
                       origin/main=ad8bb06e9 ahead=0 behind=0 mods=0 untracked=0 fetched=3m ago
bbi-infrastructure     branch=main                HEAD=4aaa4066 (beads: add fastlane observability)
                       origin/main=4aaa4066 ahead=0 behind=0 mods=0 untracked=0 fetched=12m ago
```

## When to run it

- **Start of every `ssh mereka` session.** The landing-state is
  load-bearing; don't assume.
- **Before claiming a repo is up-to-date.** Every `git status` on a
  single checkout tells half the story. The preflight gives the cross-
  repo picture.
- **After long-running sessions.** A checkout you rebased three hours
  ago may have diverged from origin/main in the meantime; preflight
  tells you whether the divergence matters for the task ahead.

## When NOT to trust it

- **`fetched` is not "now".** The script does NOT call `git fetch`
  itself — it reports staleness of the last fetch. If an accurate
  `origin/main` matters for the decision about to be made, `git fetch
  --quiet origin main` in each checkout first, then re-run preflight.
- **Dirty state is raw.** Untracked files include legitimate work-in-
  progress `/tmp` artifacts. `mods` includes generator outputs that
  haven't been staged. Interpret in context.

## Invariants preserved

1. **Read-only.** The preflight never mutates working tree, refs, or
   remote state. Exits 0 unconditionally.
2. **No secrets leak.** Output is branch/sha/count/timestamp only. No
   diff content, no file paths beyond the checkout root.
3. **Cluster-independent.** Does not touch `kubectl`. Checkout truth is
   a separate layer from cluster truth.

## Related

- Bead: `mereka-lms-p74m`
- Evidence (context): `docs/status/active/OPENEDX_INDEPENDENT_REMOTE_AUDIT_2026-04-18.md`
- Plan: `docs/status/active/OPENEDX_NEXT_PHASE_PLAN_2026-04-18.md` (Phase 1)
- Complementary: cluster preflight uses `kubectl --context rke2-nonprod
  -n argocd get application mereka-lms-dev -o jsonpath=...` (AGENTS.md
  ambient-context rule).
