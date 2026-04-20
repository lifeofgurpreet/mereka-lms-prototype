---
title: Next Sprint Queue
type: rolling-plan
owner: platform-release
status: active
last_updated: 2026-04-20
---

# Next Sprint Queue

Ordered list of what to drive **after** the current cascade PRs land
(#1918, #1921, #1924, #1926, bbi-infrastructure#3418). Written so the
next operator can pick up without oral context.

Each row has:
- **Lane / bead**: which work stream it belongs to
- **Next action**: one concrete thing to do, not a description
- **Exit**: how we'll know it's done
- **Owner**: mereka-lms-team / bbi-infra-team / either / external

The queue is ordered by leverage, not by ease. Higher-leverage items
unblock larger classes of future failure even if they take longer.

## Tier 1 — Structural (highest leverage, closes repeat failure classes)

### 1. `mereka-lms-m88z` (OBS-001): MFE client-side Sentry SDK
- **Lane**: Observability
- **Next action**: Add a Tutor plugin hook that injects `@sentry/browser` into MFE shell's common.tsx with DSN from `MFE_CONFIG.SENTRY_DSN`. Wire DSNs per env (dev/staging/prod) via bbi-infra overlay env-var → MFE config API.
- **Exit**: curl-fetch an Authn bundle on each env, grep for `SENTRY_DSN.*[^"]` — non-empty. Manually trigger a JS error on dev, see it in Sentry within 2 min.
- **Why first**: would have caught #1906's `getMerekaShellCopy` crash automatically. Every future blank-MFE-shell failure stays silent until this ships.
- **Owner**: mereka-lms-team (Tutor plugin) + bbi-infra-team (DSN env plumbing)

### 2. `mereka-lms-5wx7` (auth-allowlist-03): populate `MEREKA_PLATFORM_ADMIN_EMAILS` runtime env
- **Lane**: Identity / #1919 Tranche 3
- **Next action**: Pending — **blocked on #1919 Tranche 3**, which is in flight by another agent on bbi-infra. Their `render-lms-admin-emails.sh` generator writes the env var value into overlay patches. Watch `bbi-infrastructure/identity/access/generators/` for the next PR and rebase dev/staging/prod overlays onto it.
- **Exit**: `kubectl -n $NS get deploy lms -o jsonpath='{...MEREKA_PLATFORM_ADMIN_EMAILS...}'` returns the 8-person baseline on all 3 envs. RC checklist row 19 flips `✅ auto`.
- **Owner**: bbi-infra-team (generator landing + overlay patch), mereka-lms-team (verify after)

### 3. SESSION_COOKIE_DOMAIN contract convergence
- **Lane**: Auth / runtime
- **Next action**: Research agent identified that the bundle placeholder `"MISSING_ENV_VAR".SESSION_COOKIE_DOMAIN` comes from MFE build-time env injection with no value present, while the MFE config API reads from `TenantSiteConfiguration.mfe_config` JSONField (which is empty). The Django runtime setting is correctly `.academyv2.mereka.dev` so actual cookie emission works. Propose: add `MFE_CONFIG["SESSION_COOKIE_DOMAIN"] = MEREKA_SESSION_COOKIE_DOMAIN` in `infrastructure/tutor/plugins/_mereka_lms/lms_settings.py` (around line 67 — verify current line before editing). Test: the MFE config API response for `?mfe=authn` should then include the key with the correct value.
- **Exit**: `curl -s 'https://apps.academyv2.mereka.dev/api/mfe_config/v1?mfe=authn' | jq .SESSION_COOKIE_DOMAIN` → `".academyv2.mereka.dev"`, bundle grep for `MISSING_ENV_VAR.SESSION_COOKIE_DOMAIN` returns zero hits in next MFE build.
- **Why tier 1**: this is a 3-plane contract drift (bundle placeholder / MFE config API / Django settings / live cookie) that will cause silent session bugs in the future. Fix is probably one line.
- **Owner**: mereka-lms-team

### 4. `mereka-lms-1k2s` (OBS-006): rename stale `environment: gke-production` labels
- **Lane**: Observability
- **Next action**: In bbi-infra overlay (wherever Promtail config lives), change `environment: gke-production` → `environment: rke2-production`. Search: `grep -rln 'gke-production' bbi-infrastructure/`.
- **Exit**: Grafana/alert routing queries filtering by `environment` label see the correct env.
- **Owner**: bbi-infra-team

## Tier 2 — Runtime proof (closes open red-gate + operator blind spots)

### 5. `mereka-lms-e09t` (OBS-003): browser synthetic on Authn MFE login
- **Lane**: Observability
- **Next action**: Take the existing `smoke-authn-mfe.yml` (currently `workflow_dispatch` only) and add a scheduled cron: `*/5 * * * *` against dev, `*/15 * * * *` against prod (requires `mereka-k8s-runners` capacity). Test must assert (a) `/authn/login` returns 200, (b) bundle downloads without 4xx/5xx, (c) a stable DOM testid like `[data-testid="sign-in-with-mereka"]` renders within 10s, (d) post-login `/learner-dashboard` test-id present.
- **Exit**: `gh run list --workflow=smoke-authn-mfe --limit 5` shows 5 green runs at 5-min cadence. A deliberate `getMerekaShellCopy`-class regression on dev would fail this within 5 min.
- **Owner**: mereka-lms-team

### 6. `mereka-lms-mx78` (OBS-004): Upptime prod LMS domains
- **Lane**: Observability
- **Next action**: Add `academyv2.mereka.io`, `studio.academyv2.mereka.io`, `apps.academyv2.mereka.io`, `staging.academyv2.mereka.io`, `staging.apps.academyv2.mereka.io` to `~/infrastructure/upptime/.upptimerc.yml`. Deploy (on mereka-coding VPS; user-gated per CLAUDE.md harness rule OR push to a separate fleet host).
- **Exit**: `status.mereka.dev` page shows green for all 5 prod/staging URLs; Upptime GitHub issues fire on outage. RC checklist row 20 flips to `✅`.
- **Owner**: mereka-lms-team (config) + user (authorize mereka-coding mutation)

### 7. `mereka-lms-bq6j` (OBS-005): Blackbox probe Authentik OIDC discovery
- **Lane**: Observability
- **Next action**: Add blackbox_exporter target in bbi-infra for `https://auth0.mereka.io/application/o/mereka-lms/.well-known/openid-configuration`. Use `http_2xx` module. Alert if response != 200 for >2 min.
- **Exit**: PromRule fires on Authentik downtime; verified by briefly stopping the discovery endpoint (in non-prod).
- **Owner**: bbi-infra-team

### 8. Full browser / auth / admin Playwright sweep
- **Lane**: Runtime proof
- **Next action**: Either (a) get agent-browser daemon working on mereka-coding VPS reliably (currently flaky per CLAUDE.md memory), OR (b) run `tests/e2e/tests/critical-path.spec.ts` against dev with real Google-SSO creds from Infisical (`SSO_CANARY_*`). Complete RC checklist rows 6–18 for dev. Then same for staging + prod.
- **Exit**: RC_CHECKLIST.md rows 6–18 all ticked green on all 3 envs. Evidence bundle under `docs/ops/evidence/rc-proof-<date>/`.
- **Owner**: mereka-lms-team

### 9. Fastlane bootstrap migration (week-review item #8 follow-up)
- **Lane**: Infra / operational reproducibility
- **Next action**: Update `/root/scripts/ci/bootstrap-fastlane-build-host.sh` on `vmi3220759` to read `cleanup.sh` from the versioned location `bbi-infrastructure/scripts/ops/fastlane/runner-cleanup/cleanup.sh` (after #3418 lands) instead of its local `/root/scripts/ci/fastlane-build-cleanup.sh`. Test: bring up a new host via bootstrap, confirm cleanup.sh matches the repo version.
- **Exit**: `diff /usr/local/lib/gha-fastlane/cleanup.sh bbi-infrastructure/scripts/ops/fastlane/runner-cleanup/cleanup.sh` is empty on every fastlane host.
- **Owner**: bbi-infra-team or infra-ops

## Tier 3 — Hygiene / cleanup (nice-to-have, doesn't unblock anything)

### 10. `mereka-lms-j4ry` (OBS-002): structured JSON logging in Django
- **Next action**: Tutor plugin hook installing `python-json-logger`, override `LOGGING_CONFIG` to emit JSON with `request_id`, `trace_id`, `user_id`. Verify Promtail JSON-extract pipeline correctly populates those labels.
- **Exit**: Grafana Loki query `{app="lms"} | json | line_format "{{.message}}"` returns parsed rows.
- **Owner**: mereka-lms-team

### 11. `mereka-lms-qe32` (auth-allowlist-07): `openedx-settings-lms-patched` → declarative kustomize
- **Lane**: Identity / operational reproducibility
- **Next action**: Replace the "MANUAL SETUP REQUIRED" note in `bbi-infrastructure/apps/mereka-lms/overlays/{dev,staging,prod}/patches/authentik-sso-settings.yaml` with a generated ConfigMap template driven by kustomize. So a pod restart cannot break OIDC.
- **Exit**: The ConfigMap survives a `kubectl delete configmap openedx-settings-lms-patched` → ArgoCD re-creates it within 3 min with correct content.
- **Owner**: bbi-infra-team

### 12. Deletion-wave consumer sweep guard (week-review item #6)
- **Lane**: Governance
- **Next action**: Add a CI check that errors on any PR which deletes a path under `deploy/k8s/overlays/` without an accompanying audit of all referring scripts/workflows. Pattern: scan `git diff --name-status main...HEAD`, for every `D` entry check `grep -rln <path>` across the repo; fail if any hits remain without an accompanying absence-tolerance fix.
- **Exit**: A test PR that deletes `deploy/k8s/overlays/local/kustomization.yaml` without updating 5+ consumer scripts fails the check.
- **Owner**: mereka-lms-team

### 13. Fold RC checklist into CI (automate the auto rows)
- **Next action**: For each ✅ row in `RC_CHECKLIST.md`, verify there's a CI job that runs it. If missing (e.g. row 4 pod-image match), add it.
- **Exit**: Running `./bin/lms-ops rc-check` or a new GitHub Actions workflow prints the 14 auto rows' status in one go.
- **Owner**: mereka-lms-team

## Not in this sprint

- Learning MFE m0u5.10.1 diagnosis resumption (blocked on operator browser-capable lane)
- ADR-031 Cilium soak + graduation (bbi-infra-team, separate cadence)
- Tutor 21.0.4 upgrade (when upstream releases)
- Aspects analytics reactivation (out of scope until current work closes)

## Owner key

| Lane | Primary owner | Notes |
|---|---|---|
| mereka-lms-team | App repo, Tutor plugins, e2e tests, ensure-platform-admins | |
| bbi-infra-team | Authentik, ArgoCD apps, overlays, platform-access registry, fastlane VPS provisioning, blackbox_exporter | |
| external | Cloudflare DNS (via `CLOUDFLARE_TOKEN_MEREKA_IO` in Infisical), Authentik UI admins | |

## Rebalancing signal

If a P0 user-facing incident hits dev or prod during this sprint, **stop the
queue** and reclassify. Do not treat the queue above as immutable; it
captures today's best read of leverage, not tomorrow's reality.

## Related

- `docs/reference/operations/RC_CHECKLIST.md` — the rubric this queue closes
- GitHub Issue #1919 — unified platform-access contract (driven by bbi-infra-team)
- PR #1917 — obs audit that filed OBS-001..006 as beads
- PR #1924 — state doc prune (makes this queue authoritative-enough to stand alone)
