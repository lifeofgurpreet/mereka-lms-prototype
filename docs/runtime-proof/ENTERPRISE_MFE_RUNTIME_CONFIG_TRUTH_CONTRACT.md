# Enterprise MFE Runtime Config Truth Contract

_Audience: Platform Engineering + Frontend + QA • Owner: Platform Team • Status: canonical • Last updated: 2026-03-11_  
_Machine-readable fixture: `docs/runtime-proof/enterprise-mfe-runtime-config-contract.v1.yaml`_

## Purpose

Define the truth sources, ownership boundaries, precedence rules, and verifier
semantics for enterprise admin and learner portal runtime configuration.

This contract exists because enterprise portal truth is split. A verifier can
overstate confidence if it reads only the base `enterprise-mfe-env.js` defaults
while the actual lane or runtime truth lives elsewhere.

## Scope

In scope:

- enterprise admin portal
- enterprise learner portal
- `env.config.js` / `window.ENV_CONFIG`
- LMS `/api/mfe_config/v1`
- LMS global `MFE_CONFIG`
- per-site `SiteConfiguration.site_values["MFE_CONFIG"]`
- repo-only versus infra-owned versus runtime-only proof semantics

Out of scope:

- live cluster mutation
- `bbi-infrastructure` overlay implementation
- browser proof of deep enterprise routes
- enterprise backend service deployment health

## Truth Sources

| Source ID | Location | Ownership | What it can prove | Repo-only proof possible |
|-----------|----------|-----------|-------------------|--------------------------|
| `base_env_defaults` | `deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js` | `mereka-lms` | App-owned default shell values and key presence | Yes |
| `lane_env_realization` | `bbi-infrastructure/apps/mereka-lms/overlays/{dev,staging,prod}/...` | `bbi-infrastructure` | Authoritative lane-specific `env.config.js` for non-local lanes | No |
| `legacy_reference_overlay` | `deploy/k8s/overlays/{rke2-nonprod,staging}/enterprise-mfe-env.js` | historical reference in `mereka-lms` | Reference-only intent; not authoritative for ArgoCD lanes | Only as reference |
| `lms_global_mfe_config` | `infrastructure/tutor/plugins/_mereka_lms/lms_settings.py` | `mereka-lms` | LMS global defaults returned by `/api/mfe_config/v1` | Yes |
| `site_configuration_mfe_config` | Django `SiteConfiguration.site_values["MFE_CONFIG"]` | live runtime state | Per-site runtime overrides | No |
| `live_mfe_config_api` | `GET /api/mfe_config/v1` | live runtime state | Effective API-visible config after LMS + site merge | No |

## Ownership Boundary

- `mereka-lms` owns base manifests, default enterprise portal shell config,
  LMS settings logic, and verifier behavior.
- `bbi-infrastructure` owns authoritative `dev`, `staging`, and `prod` lane
  overlays and any lane-specific `env.config.js` realization outside `local`.
- Live runtime owns `SiteConfiguration.site_values["MFE_CONFIG"]` and the final
  `/api/mfe_config/v1` result.

No verifier in this repo may claim a non-local lane `PASS` by inspecting only
`base_env_defaults`.

## Precedence Rules

### 1. Shell bootstrap values

These values must exist before the portal can make authenticated API calls:

- `LMS_BASE_URL`
- `STUDIO_BASE_URL`
- `LOGIN_URL`
- `LOGOUT_URL`
- `REFRESH_ACCESS_TOKEN_ENDPOINT`
- `ACCESS_TOKEN_COOKIE_NAME`
- `CSRF_TOKEN_API_PATH`
- `ENTERPRISE_CATALOG_API_BASE_URL`
- `ENTERPRISE_ACCESS_BASE_URL`
- `LICENSE_MANAGER_URL`
- `ENTERPRISE_SUBSIDY_BASE_URL`

Precedence:

1. `lane_env_realization` for `dev` / `staging` / `prod`
2. `base_env_defaults` for `local` and app-owned fallback packaging

Repo-only semantics:

- `local`: `PASS` is possible from repo-only evidence.
- `dev` / `staging` / `prod`: if the verifier cannot inspect the authoritative
  infra-owned lane overlay, result must be `INDETERMINATE_INFRA_OWNED`.

### 2. Branding and legal/support display values

These values may exist in shell config, LMS defaults, and per-site runtime overrides:

- `SITE_NAME`
- `LOGO_URL`
- `LOGO_WHITE_URL`
- `LOGO_TRADEMARK_URL`
- `FAVICON_URL`
- `MARKETING_SITE_BASE_URL`
- `TERMS_OF_SERVICE_URL`
- `PRIVACY_POLICY_URL`
- `SUPPORT_EMAIL`
- `ENABLE_ACCESSIBILITY_PAGE`

Precedence for effective runtime truth:

1. `site_configuration_mfe_config`
2. `lms_global_mfe_config`
3. `lane_env_realization`
4. `base_env_defaults`

Repo-only semantics:

- Presence in app-owned defaults can be checked.
- Final lane/runtime correctness for non-local lanes is
  `INDETERMINATE_RUNTIME_ONLY` unless proven from live `/api/mfe_config/v1`
  or runtime database state.

### 3. Theme truth

Theme truth is split across two mechanisms:

- portal shell `window.PARAGON_THEME` from `env.config.js`
- LMS `MFE_CONFIG["PARAGON_THEME_URLS"]` returned by `/api/mfe_config/v1`

Precedence for effective runtime theme behavior:

1. `site_configuration_mfe_config` if it overrides `PARAGON_THEME_URLS`
2. `lms_global_mfe_config`
3. `lane_env_realization` / `base_env_defaults` shell theme config

Repo-only semantics:

- repo can validate that app-owned sources define theme inputs
- repo cannot claim runtime theme correctness for non-local lanes without live proof

## Required Keys By Class

### Required shell bootstrap keys

- `LMS_BASE_URL`
- `STUDIO_BASE_URL`
- `LOGIN_URL`
- `LOGOUT_URL`
- `REFRESH_ACCESS_TOKEN_ENDPOINT`
- `ACCESS_TOKEN_COOKIE_NAME`
- `CSRF_TOKEN_API_PATH`
- `ENTERPRISE_CATALOG_API_BASE_URL`
- `ENTERPRISE_ACCESS_BASE_URL`
- `LICENSE_MANAGER_URL`
- `ENTERPRISE_SUBSIDY_BASE_URL`

Missing any required shell bootstrap key is a `FAIL`.

### Required branding/runtime-visible keys

- `SITE_NAME`
- `LOGO_URL`
- `FAVICON_URL`
- `SUPPORT_EMAIL`

Missing app-owned defaults for these keys is a `FAIL`.
Missing effective runtime proof for these keys on non-local lanes is
`INDETERMINATE_RUNTIME_ONLY`, not `PASS`.

### Required theme keys

At least one of the following must be provable in the applicable source:

- `window.PARAGON_THEME`
- `MFE_CONFIG["PARAGON_THEME_URLS"]`

If neither theme path is present in the app-owned contract, result is `FAIL`.
If only the base/default path is visible but lane/runtime realization is not
provable, result is `INDETERMINATE_INFRA_OWNED` or
`INDETERMINATE_RUNTIME_ONLY` depending on which source is missing.

## Result Classes

| Result | Meaning | When to use |
|--------|---------|-------------|
| `PASS` | The verifier checked the authoritative source for the target scope and all required keys are present and semantically valid | Local repo-owned scope, or non-local lane with authoritative source available |
| `FAIL` | Required contract data is missing, contradictory, or semantically invalid | Missing required keys, wrong precedence behavior, or verifier reading the wrong source |
| `INDETERMINATE_INFRA_OWNED` | The target truth exists, but the authoritative lane source is owned outside this repo | `dev` / `staging` / `prod` lane env realization is required but unavailable in `mereka-lms` |
| `INDETERMINATE_RUNTIME_ONLY` | The target truth exists only in live runtime state and cannot be proven from repo sources | `SiteConfiguration.site_values["MFE_CONFIG"]` or live `/api/mfe_config/v1` needed |

## Verifier Rules

Verifiers that consume this contract MUST:

1. identify the target lane and config class before checking files
2. refuse to treat `base_env_defaults` as authoritative for `dev`, `staging`, or `prod`
3. emit `INDETERMINATE_INFRA_OWNED` when the lane-owned env realization is not in this repo
4. emit `INDETERMINATE_RUNTIME_ONLY` when final truth depends on live `SiteConfiguration` or `/api/mfe_config/v1`
5. fail closed when required app-owned keys are missing
6. fail closed when a script would otherwise pass by checking only base defaults for a non-local lane

## Existing Script Implications

This contract is the implementation target for:

- `#837` `scripts/qa/verify-enterprise-ui-review.sh`
- `#838` staging-aware enterprise runtime verification
- `#839` fail-closed runtime proof semantics for enterprise MFE config

Until those issues land, existing verifiers may still overstate confidence by
reading the wrong source. This contract exists to stop that from being treated
as acceptable behavior.

## External Dependencies

The following are intentionally external to this repo and must be recorded as
such in issue comments or verifier output:

- authoritative non-local overlays in `bbi-infrastructure`
- live `SiteConfiguration.site_values["MFE_CONFIG"]`
- live `/api/mfe_config/v1` responses

Do not work around those dependencies by silently downgrading scope and still
returning `PASS`.
