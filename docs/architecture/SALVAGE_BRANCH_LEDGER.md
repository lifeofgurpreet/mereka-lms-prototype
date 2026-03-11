# Salvage Branch Ledger

> Classification of every commit on `fix/enterprise-mfe-theme-config` (salvage branch)
> that is not on `main`.
>
> **Purpose**: Determine what to keep, port, or discard after the runtime lane lands.
>
> **Active runtime branch**: `fix/enterprise-mfe-build-config` (2 commits: cd5daa88, e388a846)
> — handles enterprise MFE build-time config. Do NOT collide with this.

## Branch Info

- **Branch**: `fix/enterprise-mfe-theme-config`
- **Commits unique to branch (vs main)**: 14
- **Last commit**: `c0cb5ea5` (fix sed domain rewrite ordering bug)
- **Base**: Diverged from main after doc cleanup commits

## Commit Classification

### SUPERSEDED (4 commits)

These are replaced by the active runtime branch's approach (environment-neutral base + overlay replacement).

| SHA | Message | Why superseded | Collides with runtime? |
|-----|---------|---------------|----------------------|
| `c0cb5ea5` | fix(enterprise-mfe): fix sed domain rewrite ordering bug | Sed-based domain rewrite is being replaced by overlay configMapGenerator replacement in `fix/enterprise-mfe-build-config`. | **Yes** — touches same deployment YAMLs |
| `c101938f` | fix(enterprise-mfe): runtime domain rewrite for non-production environments | Same: sed-based rewrite approach superseded by env-neutral base + overlay replace. | **Yes** — touches deployment YAMLs + domain-env.yaml |
| `9ce13f3e` | fix(enterprise-mfe): PARAGON_THEME, env.config.js, and head-extra mount path | Partially superseded: env.config.js approach replaced by configMapGenerator replace. Head-extra mount may still be valid (see NEEDS_REWORK below). | **Partially** — deployment YAMLs overlap |

### KEEP (6 commits)

These fix real issues independent of the enterprise MFE build/config approach.

| SHA | Message | Why keep | Belongs in | Collides with runtime? | Future PR scope |
|-----|---------|---------|-----------|----------------------|----------------|
| `a126cd7d` | fix(caddy): route all MFE API calls through Caddy to LMS | Fixes enterprise admin portal BFF routing — API calls to enterprise services must go through Caddy, not directly to LMS. Real fix. | mereka-lms | No — touches Caddyfile only | Port as standalone PR: `fix/caddy-enterprise-api-routing` |
| `2b58db40` | fix(mfe): route enterprise LMS API proxy with correct Host header | Caddy needs `Host` header when proxying to LMS. Without it, LMS can't resolve the tenant. | mereka-lms | No — touches Caddyfile only | Combine with `a126cd7d` in same PR |
| `3830cbad` | fix(mfe): wrap profile API proxy in handle block for correct Caddy ordering | Caddy route ordering fix. Profile API proxy must be in a `handle` block. | mereka-lms | No — touches MFE Caddyfile only | Port as `fix/caddy-mfe-route-ordering` |
| `fe0d769f` | fix(mfe): route all MFE ingress traffic through Caddy | Fixes hostNetwork ingress issue (PR #1519 pattern). MFE ingress must not split paths to services on control-plane nodes. | mereka-lms | No — touches ingress YAML + MFE Caddyfile | Port as `fix/mfe-ingress-caddy-routing` |
| `548b7fb6` | fix(lms): derive JWT public key from private key at startup | Prevents JWT public/private key drift. Critical auth fix. | mereka-lms | No — touches LMS production.py | Port as `fix/jwt-key-derivation` |
| `0149a137` | fix(ci): handle no_new_privs flag blocking sudo on ARC runners | CI fix for ARC runner security context. | mereka-lms | No — touches CI action YAML | Port as `fix/arc-runner-security-context` |

### KEEP (branding, 4 commits)

These fix real branding/theme issues.

| SHA | Message | Why keep | Future PR scope |
|-----|---------|---------|----------------|
| `d722dcda` | fix(branding): sync CMS overrides CSS with common copy | CMS theme CSS out of sync with common. | `fix/theme-css-sync` |
| `d066b22e` | fix(branding): sync common overrides CSS with LMS copy | Common theme CSS out of sync with LMS. | Combine with above |
| `ceab0da4` | fix(authn): align hero logo with text and fix tab divider overlap | Authn page visual fix. | `fix/authn-branding` |
| `393810da` | fix(theme): complete Paragon CSS + course about/search fixes | Paragon theme CSS completeness fix. | `fix/paragon-css-completion` |

### NEEDS_REWORK (1 commit)

| SHA | Message | Issue | Rework needed |
|-----|---------|-------|--------------|
| `79975d41` | fix(mfe): replace PLUGIN_OPERATIONS.Replace with Hide+Insert | Plugin slot operations changed from Replace to Hide+Insert. Likely correct but needs testing against current MFE build. | Test against current MFE image, then port as `fix/mfe-plugin-slot-operations` |

## Summary

| Classification | Count | Action |
|---------------|-------|--------|
| SUPERSEDED | 3 (+ partial overlap from 9ce13f3e) | Do not port. Active runtime branch replaces this approach. |
| KEEP | 10 | Port as 5-6 small PRs after runtime branch merges |
| NEEDS_REWORK | 1 | Test first, then port |

## Recommended Port Order (after runtime branch merges)

1. `fix/jwt-key-derivation` (548b7fb6) — auth-critical, no dependencies
2. `fix/caddy-enterprise-api-routing` (a126cd7d + 2b58db40) — enterprise portal functionality
3. `fix/mfe-ingress-caddy-routing` (fe0d769f + 3830cbad) — ingress correctness
4. `fix/theme-css-sync` (d722dcda + d066b22e + 393810da + ceab0da4) — visual polish
5. `fix/arc-runner-security-context` (0149a137) — CI fix
6. `fix/mfe-plugin-slot-operations` (79975d41) — needs testing first

## Files Touched (collision check)

Files touched by KEEP commits that do NOT collide with the active runtime branch (`fix/enterprise-mfe-build-config`):

```
deploy/k8s/base/apps/caddy/Caddyfile                    → Caddy routing fixes
deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile           → MFE Caddyfile
deploy/k8s/overlays/rke2-nonprod/ingress-openedx-mfe.yaml → Ingress fix
deploy/k8s/overlays/staging/ingress-openedx-mfe.yaml      → Ingress fix
deploy/k8s/base/apps/openedx/settings/lms/production.py   → JWT fix
infrastructure/tutor/themes/mereka/**                      → CSS fixes
infrastructure/tutor/plugins/mereka_lms_mfe_slots.py       → Plugin slot fix
.github/actions/setup-python-env/action.yml                → CI fix
```

Active runtime branch files (do NOT touch):
```
.dockerignore
infrastructure/docker/enterprise-mfe-clean/Dockerfile.admin-portal
infrastructure/docker/enterprise-mfe-clean/Dockerfile.learner-portal
infrastructure/docker/enterprise-mfe-clean/patch-missing-env.sh
infrastructure/docker/enterprise-mfe-clean/verify-no-baked-urls.sh
```

**No file overlap between KEEP commits and active runtime branch.**
