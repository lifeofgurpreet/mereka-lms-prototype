# UI Runtime Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-26 • Status: active_

This tracker records the truthful operator path for the authenticated browser-proof lane. It only claims what was actually re-verified in the current clean worktree.

## Current verified signal

- The clean worktree used for the browser-proof lane is isolated from the dirty local checkout:
  - path: `/home/gurpreet/projects/_worktrees/mereka-lms-docs-refresh`
  - branch: `docs/staging-truth-refresh`
  - base commit: `813b94f4034ade621faea5962836b749161a4c20`
- Canonical tracked proof runs are green:
  - `23584121291` succeeded end to end
  - `23583848535` succeeded end to end
  - `23583950807` failed only at authenticated smoke step 5; visual/auth artifacts still completed
- The tracked browser/auth lane is therefore current, but live staging still needs promotion to match merged app truth:
  - Argo revision `d9bd9537af4ece908df3094d759ae977864f468f`
  - runtime still serves the older app image `d7f015d2...`

## What is now true

| Dimension | Current state | Why |
|---|---|---|
| Clean checkout bootstrap | closed | the browser-proof lane is running from a clean worktree off `origin/main` |
| Browser cache / harness setup | closed | the lane has already been exercised through the canonical tracked runs |
| Authenticated browser proof | closed for the tracked proof lane | the canonical main rerun and clean branch rerun both completed successfully |
| Live UI runtime promotion | open | staging is still on the older app image until the deployment path catches up |
| Tracker truth | open | the tracker is current for proof, but live runtime remains behind merged app truth |

## Immediate next steps

- Re-run tracked staging proof after the runtime promotion lands
- Keep the live blockers explicit until the staging image and MFE contract catch up
- Do not promote any older browser-state notes back into canonical truth
