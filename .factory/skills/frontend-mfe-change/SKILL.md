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
| Footer component | Plugin slots + repo-owned MFE theme source | `infrastructure/tutor/patches/footer-component.sh` |
| MFE Node/build config | `infrastructure/tutor/plugins/mereka_lms.py` + build helpers | `infrastructure/tutor/patches/mfe-node.sh` |

## Steps

1. Verify worktree is clean: `git status`
2. Make source change in the correct location above
3. Render via governed wrapper: `./scripts/infra/tutor-config-save.sh`
4. Prepare/verify rendered artifact: `./scripts/infra/prepare-tutor-build-context.sh --target mfe && ./scripts/infra/verify-tutor-config.sh`
5. Build locally: `./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast`
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
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast

# Live asset verification (after deployment)
curl -sI https://apps.academyv2.mereka.io/authn/login | head -5

# Browser canary (only after asset verified)
./scripts/qa/verify-authenticated-sso-canary.sh
```

## Never Do

- Edit files under `tutor_env/` directly (lost on next `tutor config save`)
- Use raw `tutor images build` or the low-level patch runner as the normal build path
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
