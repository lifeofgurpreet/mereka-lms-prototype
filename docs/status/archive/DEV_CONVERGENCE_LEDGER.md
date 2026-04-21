# DEV Convergence Ledger
_Audience: Operators and reviewers • Owner: Platform Team • Last verified: 2026-03-20 • Status: active_

This is the single canonical convergence ledger for the current DEV-only lane. Use it with:

- `docs/status/active/DEV_CONVERGENCE_PARKED_ISSUES.md`
- `docs/status/active/DEV_CONVERGENCE_RESUME.md`
- `docs/ops/runbooks/DEV_CONVERGENCE_PROOF_CHECKLIST.md`
- `deploy/k8s/RUNTIME_AUTHORITY_MAP.md`

## Reality Snapshot

| Surface | Current verified state | Verified on |
|---|---|---|
| ArgoCD | `mereka-lms-dev` is `Synced` / `Healthy` | 2026-03-20 |
| Live GitOps source | ArgoCD renders `bbi-infrastructure/apps/mereka-lms/overlays/profiles/dev` into `mereka-lms-dev` | 2026-03-20 |
| Namespace | `mereka-lms-dev` workloads are broadly `1/1` healthy; no core app deployment was down during this check | 2026-03-20 |
| Ingress | 15 app hosts are live in DEV | 2026-03-20 |
| 9 tenant-pattern domains | All 9 return `200` HTML | 2026-03-20 |
| Enterprise portals | `admin` and `learner` DEV hosts return `200` HTML | 2026-03-20 |
| Notes host | `notes.academyv2.mereka.dev` still returns `400`; live Notes logs show `DisallowedHost` for that host | 2026-03-20 |
| Notes live env | Live `Deployment/notes` has no `MEREKA_LMS_DOMAIN` or `NOTES_DOMAIN` env override | 2026-03-20 |
| App-owned canonical registry | Needed repair: DEV tenant-pattern domains for Biji-Biji and SkillOurFuture were missing before this batch | 2026-03-20 |

## Verified Facts

- `deploy/k8s/tenancy/tenant-registry.yaml` is the app-owned canonical tenant/domain registry.
- Live DEV runtime is realized from `bbi-infrastructure/apps/mereka-lms/overlays/profiles/dev`, not directly from app-repo `deploy/k8s/overlays/rke2-nonprod`.
- Live DEV ingress exposes the full 9-domain tenant pattern:
  - `academyv2.mereka.dev`, `studio.academyv2.mereka.dev`, `apps.academyv2.mereka.dev`
  - `biji-biji.academyv2.mereka.dev`, `studio.biji-biji.academyv2.mereka.dev`, `apps.biji-biji.academyv2.mereka.dev`
  - `skillourfuture.academyv2.mereka.dev`, `studio.skillourfuture.academyv2.mereka.dev`, `apps.skillourfuture.academyv2.mereka.dev`
- The DEV database contains `Site` rows for the three tenant-pattern DEV LMS domains and also retains legacy production-site rows.
- `SiteConfiguration.site_values.course_org_filter` is present for the three DEV tenant-pattern LMS sites.
- `EnterpriseCustomer` rows exist and are active for `mereka`, `biji-biji`, and `skillourfuture`.
- `enterprise-admin-portal` and `enterprise-learner-portal` are live in DEV and return HTML over their public hosts.
- Live Notes traffic reaches Caddy and the Notes pod; the public `400` is the Notes app rejecting `notes.academyv2.mereka.dev`, not an ingress-only routing miss.
- Live Notes pod logs show `django.core.exceptions.DisallowedHost` for `notes.academyv2.mereka.dev`.
- Live `Deployment/notes` does not inject `MEREKA_LMS_DOMAIN` or `NOTES_DOMAIN`, while the live `notes-settings-*` ConfigMap defaults `MEREKA_LMS_DOMAIN` to `academyv2.mereka.io` and derives `NOTES_DOMAIN` from that fallback.
- The DEV infra consumer now includes a Notes env patch in `bbi-infrastructure/apps/mereka-lms/overlays/dev/patches/satellite-services-domain.yaml`; live runtime has not applied that source correction yet.
- No Aspects, ClickHouse, or Superset workload is deployed in `mereka-lms-dev`.
- The live namespace mounts staging-derived ConfigMap names because the infra repo intentionally renders them that way; this is source-owned `TEMP_BRIDGE` debt, not ad-hoc runtime drift.
- `argocd/applicationsets/mereka-lms-dev.yaml` uses `IgnoreExtraneous`, `Prune=false`, and ignores ConfigMap `/data`, so ArgoCD `Synced` / `Healthy` is not sufficient proof of effective ConfigMap correctness.

## Disproved Claims

- `docs/reference/operations/DOMAIN_MATRIX.md` claiming DEV subsites were production-only was disproved by live ingress and DB state on 2026-03-20.
- The same matrix claiming DEV enterprise admin was `503` and learner had no ingress was disproved by direct HTTPS probes on 2026-03-20.
- The local `DEV_CONVERGENCE_CONTROL.md` note claiming “all 11 DEV domains responding” was disproved by live ingress shape:
  - 15 app hosts are exposed.
  - `notes.academyv2.mereka.dev` returned `400`.
- Treating `scripts/shared/config.sh` as the canonical domain registry is disproved by the repo’s own authority chain:
  - the canonical registry is `deploy/k8s/tenancy/tenant-registry.yaml`
  - `config.sh` is a derived helper surface
- Treating the Notes `400` as an unproven ingress or Caddy issue is disproved by direct probe plus pod logs:
  - Caddy access logs show the request reaches Notes through the expected public host.
  - Notes pod logs show `DisallowedHost` for `notes.academyv2.mereka.dev`.

## Working Hypotheses

- Legacy production `Site` rows in the DEV database are probably harmless residue, not active routing truth.
  - Confirm or kill by tracing active host resolution and credentials/discovery lookups against those rows.
- After the DEV Notes env patch is merged and applied by GitOps, `notes.academyv2.mereka.dev` should stop failing with `DisallowedHost`.
  - Confirm or kill by reproving the public host, live `Deployment/notes` env, and Notes pod logs after ArgoCD applies the new render.

## Canonical Source Map

### Canonical sources

- `deploy/k8s/tenancy/tenant-registry.yaml`
- `deploy/k8s/RUNTIME_AUTHORITY_MAP.md`
- `deploy/k8s/contract.json`
- `deploy/k8s/CONTRACTS.md`
- `bin/lms-ops`
- `docs/ops/runbooks/DEV_CONVERGENCE_PROOF_CHECKLIST.md`
- live `Application` / `ApplicationSet` objects for `mereka-lms-dev`
- `bbi-infrastructure/apps/mereka-lms/overlays/dev/patches/satellite-services-domain.yaml`
- `bbi-infrastructure/scripts/qa/verify-overlay-authority.sh`

### Derivative sources

- `scripts/shared/config.sh`
- `docs/reference/operations/DOMAIN_MATRIX.md`
- `scripts/qa/verify-domain-url-invariants.sh`
- live probe output and pod logs captured during this run

### Stale or conflicting sources

- Any local or untracked control doc outside the committed docs roots
- Pre-2026-03-20 copies of `docs/reference/operations/DOMAIN_MATRIX.md`
- Any operator claim that says DEV subsites are “prod only”
- Any operator claim that treats the live Notes `400` as a routing hypothesis without pod-log proof

## Drift Register

| Item | Owner | Current impact | Action |
|---|---|---|---|
| DEV tenant-pattern domains missing from canonical registry | app repo | Source truth lagged live reality and seeding/apply paths | Formalized in this batch |
| `config.sh` missing DEV subsite defaults | app repo | Helper scripts could not express the live DEV tenant pattern | Formalized in this batch |
| Staging-derived ConfigMap names mounted in DEV | infra repo + runtime | Name semantics imply staging even though active values are DEV-specific | Formalize as `TEMP_BRIDGE`; remove only with a contract-cleanup batch |
| ArgoCD dev app ignores ConfigMap `/data` and disables prune | infra repo + runtime | `Synced` / `Healthy` can overstate config correctness and stale hashed ConfigMaps accumulate | Keep visible; require direct mounted-config proof |
| Notes DEV host returns `400` because live Notes env still falls back to prod-domain defaults | infra realization + runtime | Live host is not user-ready; root cause is proven | Source correction prepared in this batch; keep parked until merge, Argo apply, and reprobe |
| Legacy prod `Site` rows present in DEV DB | app/runtime | Confusing during read-only inspection | Parked until cleanup lane |

## Chosen Batch

`D3 Notes service-domain parity correction`

Why this batch won:

- It closes a live user-facing `400` from hypothesis to proven owner layer with the smallest possible repo-owned correction.
- It keeps the fix in the infra consumer where the live DEV realization actually happens.
- It adds a reusable guard so future agents do not confuse a host-allowlist failure with ingress drift.

## Proof Pointers

- Runtime proof inputs for this batch are recorded in:
  - `docs/reference/operations/DOMAIN_MATRIX.md`
  - `docs/status/active/DEV_CONVERGENCE_PARKED_ISSUES.md`
- Static proof commands for this batch are listed in:
  - `docs/ops/runbooks/DEV_CONVERGENCE_PROOF_CHECKLIST.md`
- GitOps consumer proof for this batch additionally depends on:
  - live `Application` / `ApplicationSet` objects in ArgoCD
  - `bbi-infrastructure/apps/mereka-lms/overlays/profiles/dev`
  - `bbi-infrastructure/apps/mereka-lms/overlays/dev/patches/satellite-services-domain.yaml`
  - `bbi-infrastructure/scripts/qa/verify-overlay-authority.sh`
