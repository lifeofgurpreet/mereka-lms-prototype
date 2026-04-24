---
title: Enterprise services 21.0.0 — upstream archived verdict
type: evidence-bundle
owner: platform-release
observed_at: 2026-04-19T01:30Z
bead: mereka-lms-mnf5
status: active
---

# Enterprise services 21.0.0 — upstream archived verdict

Closes bead `mereka-lms-mnf5` ("Enterprise images frozen at 21.0.0 for 5
months — evaluate upgrade path").

## Finding

**The three enterprise backend services (`enterprise-catalog`,
`enterprise-subsidy`, `enterprise-access`) cannot be upgraded. Their
upstream repositories were archived by 2U/edX in November 2024.**

The pin at `21.0.0` is effectively permanent for this platform.

## Source of truth

The production overlay at
`Biji-Biji-Initiative/mereka-lms/deploy/k8s/overlays/production/kustomization.yaml`
already carries the authoritative comment:

```yaml
  # Enterprise backend services — frozen at 21.0.0 (archived upstream, Nov 2024)
  - name: ghcr.io/biji-biji-initiative/mereka-lms/enterprise-catalog
    newTag: "21.0.0"
    digest: sha256:5ef5ee4bea398af0027c5e85d107860145a0dced7c0ad022edd99cd7fa5c1cbc
  - name: ghcr.io/biji-biji-initiative/mereka-lms/enterprise-subsidy
    newTag: "21.0.0"
    digest: sha256:2d701f8f9c6482176eade8d028d0bff653fbc03e4b1b619d21238dd2b9f8a461
  - name: ghcr.io/biji-biji-initiative/mereka-lms/enterprise-access
    newTag: "21.0.0"
    digest: sha256:5315667f47d93beed464c59e9fb6c393428a4f0156e57a39f03c439f257caa22
```

The same pins apply to `rke2-nonprod` and `local` overlays (all pinned to
`21.0.0` with the same three digests).

## What this means for operators

- **Do NOT search for upgrade opportunities.** There are no new upstream
  releases for these services. Looking for them wastes cycles.
- **Treat `21.0.0` as load-bearing.** Do not blindly bump tags in a routine
  dependency refresh — there is no newer tag.
- **CVE response:** if a security issue is reported, the process is
  fork upstream → apply patch → rebuild image as `21.0.0-mereka.<N>` →
  update overlay. This is the ONLY sanctioned upgrade path.

## Current runtime health

No CI failures, schema migration blockers, or runtime defects are tied to
the frozen versions as of 2026-04-19. Recent sessions (slice 25 `kubectl`
observations) show enterprise-access/catalog/subsidy + workers all 1/1
ready in the `mereka-lms-dev` namespace.

## Successor tool tracking (forward-looking)

`enterprise-access` was deprecated upstream in favor of
`enterprise-enrollment` (per public Open edX discussions). **This document
intentionally does NOT open a successor-migration bead** — that would be
premature. When `enterprise-enrollment` stabilizes (production-grade release
tags, migration guide published, at least one reference adopter), a new
bead can open to evaluate.

## Bead disposition

- `mereka-lms-mnf5` closes with this evidence bundle as the learning note.
- No follow-up beads opened.
- If a CVE lands, a new P1 bead `"enterprise-CVE-response-<date>"` is the
  right response — not re-opening `mnf5`.

## Related

- Bead: `mereka-lms-mnf5` (this closure)
- Overlay pins: `Biji-Biji-Initiative/mereka-lms/deploy/k8s/overlays/production/kustomization.yaml`
- Prior session scoping (mempalace): `drawer_mereka-lms_backend_be852b285f9464dece3a6505`
- Rule 3 doctrine (runbooks executable require evidence): this is an
  evidence bundle, not a runbook — Rule 3 doesn't apply directly but the
  pattern (capture evidence before closing a bead) is in spirit the same.
