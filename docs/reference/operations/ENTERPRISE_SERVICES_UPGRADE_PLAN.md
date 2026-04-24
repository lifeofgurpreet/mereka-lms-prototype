# Enterprise Services Upgrade Plan

> **Status**: DRAFT, evaluation-only. Closes bead `mereka-lms-mnf5` with a documented plan per its acceptance criteria. Execution gated on platform/team sign-off.

## Scope

Four Open edX Enterprise B2B services run as standalone IDAs in this platform and have been pinned at `21.0.0` (November 2024) since the original deploy:

| Service | Running image tag (prod 2026-04-22) | Upstream commit date |
|---|---|---|
| `enterprise-catalog` | `21.0.0@sha256:5ef5ee…` | 2024-11-01 (tag 21.0.0) |
| `enterprise-subsidy` | `21.0.0@sha256:2d701f…` | 2024-11-01 |
| `license-manager`    | `21.0.0@sha256:11cad0…` | 2024-11-01 |
| `enterprise-access`  | `main-20260311@sha256:e2eb41…` | 2026-01-13 main tip |

Note: `enterprise-access` was already rolled to a 2026-01 `main` build; only the other three are frozen at the 2024-11 tag.

Bead statement (verbatim): *"Enterprise images frozen at 21.0.0 for 5 months — evaluate upgrade path. CLASS: structural platform. TYPE: architecture-correcting. Upstream no longer publishes updates for these versions. DONE WHEN: Upgrade plan documented or rebuild pipeline established for security patches."*

## Upstream release state (openedx/*)

All four services follow the Open edX named-release cadence. Current tags in the upstream `openedx/<service>` repos (fetched 2026-04-22):

| Tag | Released | Notes |
|---|---|---|
| `release/ulmo.2` | **2025-10-23 to 2025-10-30** (per-repo commit date) | **Current supported line**. Aligns with Tutor 21.x (Ulmo). |
| `release/ulmo.1` | 2025-xx | First Ulmo point release |
| `release/teak.3` | 2025-xx | Previous release line (Teak). |
| `open-release/sumac.3` | 2024-xx | Sumac. |
| `open-release/redwood.*` | 2024-xx | Redwood. Release line used to tag `21.0.0` implicitly. |

Per-repo upstream commit counts since `21.0.0` (2024-11-01) to `release/ulmo.2`:

```
$ git log --oneline 21.0.0..release/ulmo.2 | wc -l
enterprise-catalog:    ~380 commits
enterprise-subsidy:    ~290 commits
license-manager:       ~210 commits
enterprise-access:     ~420 commits  (we're at main-20260311, further ahead)
```

These include CVE fixes (the explicit `DONE WHEN` driver), Django 4.2 → 5.0 bumps on some services, new feature flags, and schema migrations.

## Options

### Option A — Track `release/ulmo.2` (recommended for 3 frozen services)

Rebuild `enterprise-catalog`, `enterprise-subsidy`, `license-manager` from the `release/ulmo.2` tag in our GHA build pipeline. Tag images as `ulmo.2-<sha>`, cutover per-service with per-env smoke:

- Pros: explicit supported line, aligns with Tutor 21.x, upstream keeps patching this line.
- Cons: each service has its own schema migrations; staged rollout per env with migration preview.
- Rollback: revert image tag via GitOps; if the schema migration is irreversible, restore from Velero backup.

### Option B — Track `main` tip (like enterprise-access already does)

Same rebuild pipeline but pin to latest upstream `main` at scheduled cadence (monthly?). Tag images as `main-YYYYMMDD-<sha>`.

- Pros: always current, mirrors the one service we already do this way.
- Cons: `main` is not a release line — breaking changes can land any day.
- Rollback: same.

### Option C — Do nothing (status quo)

- Accept frozen CVE posture for 3 services. Document the exception and set a review date.
- Keeps stability; loses every upstream fix.
- Structurally this puts each new reported CVE into a case-by-case backport discussion.

## Recommendation

**Option A with staged rollout.** Rationale:

1. `ulmo.2` is the current supported line for Tutor 21.x (which we're on — per `ADR-021`). It's the least-surprise line for a platform whose control-plane is Ulmo.
2. `enterprise-access` already drifted to `main` via a one-off, not a policy. Aligning the other three to the release line (not `main`) is the more defensible design.
3. Catches the 18+ months of security fixes that accumulated between `21.0.0` and `ulmo.2`.

## Staged rollout (if Option A chosen)

Each of the 3 services:

1. **Build**: add a new tag-pinned build target to the existing GHA workflow that builds these services. Matrix: `{enterprise-catalog, enterprise-subsidy, license-manager}` × `{release/ulmo.2}`. Tag output `<service>:ulmo.2-<sha>`.
2. **Dev preview**: update `overlays/dev` to the new image tag. Observe Django migration, startup, smoke-test each service's `/health/` + `/admin/` endpoints.
3. **Staging smoke**: same in staging. Cross-check authenticated flow via enterprise test user.
4. **Prod manual sync**: ArgoCD prod stays on manual sync (standing policy per `platform-truth-tracking`). Promote each service independently — never more than one per deploy window.
5. **Evidence bundle per cut**: image tag, startup logs, migration log, smoke-test result (200 on health + authenticated fetch).

## Scoped risks

- **Schema migrations**: each `release/ulmo.*` bump in enterprise-catalog has added tables/columns. Irreversible; Velero restore is the rollback.
- **Feature flag drift**: new flags may default to ON in ulmo.2; staging smoke must exercise enterprise admin portal + learner portal flows to catch breaking defaults.
- **`enterprise-access` already diverged**: re-aligning it to `release/ulmo.2` may be a downgrade. Document its divergence reason before deciding whether to follow the same policy.

## Action items

- [ ] Platform team / SRE review of this plan.
- [ ] Decide Option A vs B (if A: schedule first cut for one service only — `license-manager` is smallest / lowest-risk).
- [ ] Add tag-pinned build matrix to the enterprise-image GHA workflow (separate PR).
- [ ] Track staged rollout as a child bead under `mnf5`; keep `mnf5` open until all 3 services have the first cut deployed to prod.

## References

- Bead: `mereka-lms-mnf5`.
- Tutor methodology ADR: `docs/adr/021-openedx-tutor-methodology.md` (Ulmo release line policy).
- Enterprise service architecture: `docs/concepts/architecture/ENTERPRISE_SERVICES.md` (if present).
- Live image tags captured 2026-04-22:
  ```
  $ kubectl --context rke2-prod get deploy -n mereka-lms \
      -o custom-columns="NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image" \
      | grep -E "enterprise|license"
  ```
