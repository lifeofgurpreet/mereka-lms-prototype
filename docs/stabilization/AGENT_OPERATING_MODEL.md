# Agent Operating Model

> Stabilization document — how agents operate in the mereka-lms repository.
> Date: 2026-03-11

---

## Lane System

Each agent is assigned a lane. Lanes partition the repository's concern space. An agent must not
perform writes outside its lane without explicit escalation.

| Lane | Owner Role | Scope |
|---|---|---|
| F | Repo/CI stabilization | `.github/`, `scripts/qa/`, `Makefile`, `docs/stabilization/`, CI config |
| A | Runtime / app semantics | `deploy/k8s/`, `infrastructure/tutor/`, LMS/CMS/MFE configs |
| E | Docs and specs | `docs/`, `specs/`, `AGENTS.md`, `CLAUDE.md` |
| S | Security and secrets | `deploy/k8s/base/secrets/`, Infisical mappings, `.githooks/` |
| B | Build / image pipeline | `infrastructure/tutor/plugins/`, Dockerfile patches, image tags |

**Cross-lane writes require justification** in the PR description. State which lane you are in,
which lane you are crossing into, and why it cannot wait for the lane owner.

---

## Turn Discipline

Every agent turn must end with a concrete artifact. "Still investigating" is not a valid end state.

| Valid end state | Example |
|---|---|
| Commit on feature branch | `git commit -m "fix: add shebang to scripts"` |
| PR raised | `gh pr create ...` |
| PR merged (after CI) | `gh pr merge --squash` |
| Verifier script run with output | `bash scripts/qa/verify-arc-contract.sh > var/arc-verify.txt` |
| Proof artifact written | `docs/stabilization/FAILURE_TAXONOMY.md` created |
| Blocker documented with next action | Write to `docs/stabilization/` or open a bead |

An agent that ends its turn with only prose and no artifact has accomplished nothing durable.

---

## Worktree Isolation

Use git worktrees for parallel work. Do not share a working directory between two simultaneous
agent sessions.

```bash
# Spawn a worktree for a parallel task
git worktree add ../mereka-lms-fix-arc fix/arc-runner-contract

# List active worktrees
git worktree list

# Remove when done
git worktree remove ../mereka-lms-fix-arc
```

Each worktree has its own branch. Two agents working in the same worktree will produce
conflicts and dirty-tree confusion.

---

## Branch Naming

| Prefix | Use case |
|---|---|
| `stabilization/` | CI stability, infrastructure fixes, lint debt |
| `fix/` | Bug fixes in code or config |
| `feat/` | New features |
| `docs/` | Documentation and spec changes only |
| `chore/` | Dependency updates, tooling changes |

Branch names use kebab-case: `fix/arc-xz-utils-workaround`, not `fix/ARC_XZ_Utils`.

---

## PR Hygiene

**Small and focused**: One concern per PR. If you find a second issue while fixing the first,
open a second PR.

**PR description must include**:
- What changed and why (not just what).
- Which lane this PR belongs to.
- How to verify the fix (command to run, expected output).
- Any cross-lane writes and justification.

**PR title**: Conventional Commits format — `fix(ci): add xz-utils workaround for ARC runners`.

**Do not** include unrelated formatting changes, dead code removal, or refactors in a fix PR.
These obscure the actual change and make review harder.

---

## Merge Policy

| PR type | Merge authority |
|---|---|
| Repo/CI only (Lane F) | Lane F agent may self-merge when CI passes |
| Runtime changes (Lane A) | Requires human or Opus reviewer sign-off |
| Spec changes (Lane E) | Requires spec-writer or architect review |
| Security changes (Lane S) | Requires security-reviewer (Opus) sign-off |
| Image build changes (Lane B) | Requires build-validator run + human approval |

Self-merge means: CI is green on the feature branch, the PR is scoped to Lane F, and no other
lane's files are touched.

---

## Context Verification Protocol

At the start of every session, before any mutation:

```bash
# 1. Confirm repository
git remote -v
# Expected: origin  git@github.com:Biji-Biji-Initiative/mereka-lms.git

# 2. Confirm worktree root
git rev-parse --show-toplevel
# Expected: /home/gurpreet/projects/k8s/mereka-lms (or worktree equivalent)

# 3. Confirm branch
git branch --show-current
# Expected: anything except "main"

# 4. Confirm clean tree
git status
# Expected: "nothing to commit, working tree clean" OR only your own staged changes
```

If any of these checks fails, resolve the context issue before proceeding.

---

## Escalation Path

If an agent encounters a blocker outside its lane:

1. Document the blocker in `docs/stabilization/` or as a bead (`br new`).
2. Send a message to the appropriate lane owner via agent mail (`ntm mail send`).
3. End the turn with the blocker documented — do not proceed across lane boundaries without a response.

---

## What Agents Must Not Do

- Commit directly to `main` (see EXECUTION_INVARIANTS.md Invariant 1).
- Mutate ArgoCD-managed resources directly (see `.claude/rules/gitops-enforcement.md`).
- Downgrade package versions to resolve build failures.
- Push experimental "let's try this" commits to shared branches.
- Merge a PR when CI is red on the feature branch.
- Perform kubectl mutations on prod without a corresponding git commit.
