# Tenant Experience Contract Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-04-05T12:15:00Z • Status: active_

This tracker is the active execution board for converging tenant-branding,
authn-shell selection, and host-driven multitenant runtime truth into one
canonical tenant experience contract.

Use this with:

- [`ACTIVE_SURFACE_RUNTIME_MATRIX_2026-04-04.md`](./ACTIVE_SURFACE_RUNTIME_MATRIX_2026-04-04.md)
- [`FINISH_LINE_MASTER_TRACKER_2026-04-03.md`](./FINISH_LINE_MASTER_TRACKER_2026-04-03.md)
- [`TENANT_OPERATING_SYSTEM_BLUEPRINT_2026-04-03.md`](./TENANT_OPERATING_SYSTEM_BLUEPRINT_2026-04-03.md)
- issue [`#1346`](https://github.com/Biji-Biji-Initiative/mereka-lms/issues/1346)

## Current verified state

### repo_truth

- PR [`#1345`](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1345) keeps the immediate fix narrow:
  - tenant homepage Sign in/Register links derive the authn host from the request host
  - tenant-auth runtime/browser proof is upgraded
- Tenant truth is still duplicated across multiple consumers:
  - `infrastructure/tutor/multisite-sites.yml`
  - `infrastructure/tutor/multisite-sites.dev.yml`
  - `infrastructure/tutor/multisite-sites.staging.yml`
  - `infrastructure/tutor/tenant-branding-schema.yml`
  - `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`
  - `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution.js`
- The active finish-line board now records that `biji-biji/dev` and `skillourfuture/dev` are `blocked`, not merely `partial` or `unproved`.

### runtime_truth

- The tenant authn pages already exist and already render distinct tenant copy/logo/hero:
  - `apps.biji-biji.academyv2.mereka.dev/authn/login`
  - `apps.skillourfuture.academyv2.mereka.dev/authn/login`
- The tenant LMS homepage bug is real in `dev`:
  - `biji-biji.academyv2.mereka.dev/` homepage Sign in/Register still point to `apps.academyv2.mereka.dev`
  - `skillourfuture.academyv2.mereka.dev/` homepage Sign in/Register still point to `apps.academyv2.mereka.dev`
- The tenant apps/authn shell is still not finish-line clean in `dev`:
  - `tests/e2e/tests/branding-smoke.spec.ts`
  - exact failure: tenant palette bridge missing on both non-primary tenant authn pages (`--tenant-color-primary` empty)
- Studio SSO contract is stronger than the old board claimed:
  - `bash scripts/qa/verify-studio-sso-flow.sh biji-biji.academyv2.mereka.dev apps.biji-biji.academyv2.mereka.dev`
  - `bash scripts/qa/verify-studio-sso-flow.sh skillourfuture.academyv2.mereka.dev apps.skillourfuture.academyv2.mereka.dev`
  - both pass, so `studio` is at least `partial` for those tenant/dev units

### proof_truth

- Narrow contract/routing proof passes for `biji-biji/dev` and `skillourfuture/dev`:
  - `bash scripts/acceptance/runtime-routing.sh --env dev --tenant biji-biji`
  - `bash scripts/acceptance/runtime-routing.sh --env dev --tenant skillourfuture`
- Those acceptance bundles prove host routing and authn target agreement, not full tenant experience closure.
- Finish-line proof still fails for tenant apps in `dev` because browser-level theme/token proof is red.

## What we achieved already

- The board now distinguishes:
  - narrow routing/runtime proof
  - browser-level tenant experience proof
  - finish-line operational closure
- We stopped overstating `biji-biji/dev` and `skillourfuture/dev` as merely `partial`.
- The permanent lane is now explicit instead of living only in PR comments and chat.

## Current control point

Do not broaden [`#1345`](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1345).

The immediate homepage auth-link fix and the permanent multitenancy fix are now
separate lanes:

1. merge and deploy `#1345`
2. build one canonical tenant experience contract
3. move every consumer to the host-driven resolver backed by that contract
4. fail browser proof unless one tenant shell per host is rendered

## Execution board

| ID | Priority | Owner | Outcome | Current state |
|---|---|---|---|---|
| TEC-01 | P0 | app repo | Keep `#1345` narrow and land the homepage auth-link fix | in flight |
| TEC-02 | P0 | app repo | Create one canonical tenant experience contract artifact for tenant/env/surface runtime selection | open |
| TEC-03 | P0 | app repo | Drive LMS homepage auth links, `/api/mfe_config/v1`, authn shell selection, and plugin selection from the same host resolver | open |
| TEC-04 | P0 | app repo | Eliminate silent fallback to `apps.academyv2.mereka.dev` on non-primary tenant hosts | open |
| TEC-05 | P1 | app repo | Isolate one tenant shell per authn host; multi-bundle exposure becomes fail, not warn | open |
| TEC-06 | P1 | app repo | Freeze tenant-specific hero/header/theme/copy into the canonical contract with browser proof expectations | open |
| TEC-07 | P1 | app repo | Add `tenant-branding` acceptance front door and schema-valid proof bundle per tenant/env/surface | open |
| TEC-08 | P2 | docs | Retire duplicate tenant maps/docs once the canonical contract is live | open |

## Candidate canonical contract inputs

These are the strongest current inputs. They should converge into one contract, not remain peer authorities.

- `infrastructure/tutor/multisite-sites.yml`
- `infrastructure/tutor/multisite-sites.dev.yml`
- `infrastructure/tutor/multisite-sites.staging.yml`
- `infrastructure/tutor/tenant-branding-schema.yml`
- `infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json`
- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`
- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution.js`

## Exact verification commands

### Homepage/authn host agreement

- `bash scripts/qa/verify-tenant-auth-runtime.sh`
- `python3 - <<'PY'`
  `import requests`
  `from bs4 import BeautifulSoup`
  `for host in ('https://biji-biji.academyv2.mereka.dev/','https://skillourfuture.academyv2.mereka.dev/'):`
  `    soup=BeautifulSoup(requests.get(host,timeout=20).text,'html.parser')`
  `    print(host, soup.select_one('a[href*=\"/authn/login\"]')['href'])`
  `PY`

### Browser-level tenant branding proof

- `bash scripts/qa/verify-tenant-visual-contract.sh --env dev`
- `cd tests/e2e && BASE_URL=https://biji-biji.academyv2.mereka.dev npx playwright test tests/smoke-unauthenticated.spec.ts --config playwright.config.ts --grep "authn/login exposes tenant-specific authn branding copy"`
- `cd tests/e2e && BASE_URL=https://skillourfuture.academyv2.mereka.dev npx playwright test tests/smoke-unauthenticated.spec.ts --config playwright.config.ts --grep "authn/login exposes tenant-specific authn branding copy"`
- `cd tests/e2e && BASE_URL=https://biji-biji.academyv2.mereka.dev npx playwright test tests/branding-smoke.spec.ts --config playwright.config.ts --grep "theme assets \\+ token bridge present on authn-login"`
- `cd tests/e2e && BASE_URL=https://skillourfuture.academyv2.mereka.dev npx playwright test tests/branding-smoke.spec.ts --config playwright.config.ts --grep "theme assets \\+ token bridge present on authn-login"`

### Studio SSO contract

- `bash scripts/qa/verify-studio-sso-flow.sh biji-biji.academyv2.mereka.dev apps.biji-biji.academyv2.mereka.dev`
- `bash scripts/qa/verify-studio-sso-flow.sh skillourfuture.academyv2.mereka.dev apps.skillourfuture.academyv2.mereka.dev`

## Ownership boundary

- Canonical tenant experience contract: app repo
- Environment realization of declared hosts: infra repo
- DNS/TLS realization of declared hosts: control-plane / infra
- Live tenant experience proof: browser/runtime scripts and artifacts

No consumer should become a second canonical tenant map.

## Do not claim this lane closed unless

1. A single canonical tenant experience contract exists for each tenant/env.
2. Homepage auth links, `/login`, `/register`, `/api/mfe_config/v1`, authn shell, and plugin selection all resolve from the same host-driven contract.
3. Non-primary tenant hosts no longer fall back to the shared apps host.
4. Authn pages render exactly one tenant shell per host.
5. Tenant-specific hero/header/theme/copy are browser-proved for each active tenant/env/surface.
6. The proof bundle is schema-valid and tied to the deployed revision.
7. Duplicate tenant truth surfaces are retired or explicitly derivative-only.
