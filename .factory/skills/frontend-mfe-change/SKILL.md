---
name: frontend-mfe-change
description: Change MFE appearance, behavior, or configuration safely. Use when modifying micro-frontends, plugin slots, MFE branding, or frontend build configuration in Mereka LMS.
---

# Frontend / MFE Change

## Layer Ownership

Source → Build/render → Promotion → Realization → Runtime proof

## Where to Make Changes

| Change type | Correct location | Wrong location |
|---|---|---|
| Plugin slot configuration | `infrastructure/tutor/plugins/mereka_lms.py` | `tutor_env/` (generated, will be lost) |
| MFE env.config | `infrastructure/tutor/plugins/mereka_lms.py` | Dockerfile-level `env.config.jsx` |
| Brand/theme tokens | `assets/brand/` + `@edx/brand` package | Inline CSS in MFE source |
| Footer component | Plugin slots (migrating from legacy patcher) | `infrastructure/tutor/patches/footer-component.sh` (debt) |
| MFE Node/build config | `infrastructure/tutor/plugins/mereka_lms.py` | `infrastructure/tutor/patches/mfe-node.sh` (debt) |

## Steps

1. Verify worktree is clean: `git status`
2. Make source change in the correct location above
3. Apply patches: `./infrastructure/tutor/apply-patches.sh`
4. Verify rendered artifact: `./scripts/infra/verify-tutor-config.sh`
5. Build locally: `tutor images build mfe` (needs 12GB+ RAM)
6. Test locally: `curl -I http://apps.localhost/authn/login`
7. Commit, push, get CI green
8. Promote via release object (not manual SHA join)
9. Verify realization: check Argo sync + live image hash
10. **Verify served asset**: confirm the actual JS/CSS bundle served to browser matches the build
11. Run browser canary only AFTER live asset gate passes

## Verification

```bash
# Rendered artifact check
./scripts/infra/verify-tutor-config.sh

# Build artifact check
tutor images build mfe 2>&1 | tail -20

# Live asset verification (after deployment)
curl -sI https://apps.academyv2.mereka.io/authn/login | head -5

# Browser canary (only after asset verified)
./scripts/qa/verify-authenticated-sso-canary.sh
```

## Never Do

- Edit files under `tutor_env/` directly (lost on next `tutor config save`)
- Trust build success as proof of served asset
- Rerun browser canary while live asset gate is red
- Patch generated Dockerfile without fixing generator (`mereka_lms.py`)
- Use `master` or `main` branch of edx-platform (must use release tag `open-release/ulmo.1`)

## Rollback

```bash
git revert HEAD --no-edit && git push
# Then promote the reverted build
```

## Required Companions

> Source: `config/skills-graph.yaml`

- **Requires**: `layer-triage`, `runtime-proof`
- **Recommended**: `gitops-promotion`, `cross-repo-authority`

## References

- [FRONTEND_MFE_CHANGE.md](docs/ops/playbooks/FRONTEND_MFE_CHANGE.md)
- [ADR-021](docs/adr/021-openedx-tutor-methodology.md)
