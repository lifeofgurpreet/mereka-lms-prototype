# Legacy Courseware Audit

## Background

Open edX has two distinct learning experiences:

**Legacy courseware** (server-rendered, XModule-based):
- Django views under `lms/djangoapps/courseware/`
- URL pattern: `/courses/<course-key>/courseware/<chapter>/<section>/`
- Rendered server-side using XModule/XBlock rendering pipeline
- Controlled by `FEATURES["ENABLE_COURSEWARE_MICROFRONTEND"] = False`

**Learning MFE** (React, replaces legacy courseware):
- MFE served at `<MFE_BASE_URL>/learning/`
- URL pattern: `/learning/course/<course-key>/...`
- Enabled via `FEATURES["ENABLE_COURSEWARE_MICROFRONTEND"] = True` and `LEARNING_MICROFRONTEND_URL`
- The canonical learner experience in Tutor v19+ (Redwood) and all Ulmo (v21) deployments

Ulmo deprecates the legacy server-rendered courseware tab. Operators are expected to enable the Learning MFE and redirect old `/courses/*/courseware/*` URLs to it.

## Audit Findings

### Feature Flags

| Location | Setting | Value | Notes |
|----------|---------|-------|-------|
| `deploy/k8s/base/apps/openedx/settings/lms/development.py:360` | `FEATURES["ENABLE_COURSEWARE_MICROFRONTEND"]` | `False` | **Legacy mode active in dev** |
| `deploy/k8s/base/apps/openedx/settings/lms/production.py` | `FEATURES["ENABLE_COURSEWARE_MICROFRONTEND"]` | _(not set, inherits upstream default)_ | Upstream Ulmo default is `True` |

The development settings explicitly disable the Learning MFE (`False`). Production settings do not override the flag, relying on the upstream `lms/envs/production.py` default. In Tutor Ulmo (v21) the upstream default is `True`, which means production correctly uses the Learning MFE.

### LEARNING_MICROFRONTEND_URL

`deploy/k8s/base/apps/openedx/settings/lms/production.py` sets:

```python
LEARNING_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/learning"
MFE_CONFIG["LEARNING_BASE_URL"] = f"{MEREKA_MFE_BASE_URL}/learning"
```

This is correctly wired. The LMS uses `LEARNING_MICROFRONTEND_URL` to construct redirect URLs when the feature flag is enabled.

### Caddyfile

`deploy/k8s/base/apps/caddy/Caddyfile` contains no explicit `/courseware/` routes or redirects. Old courseware URLs are handled by the LMS Django application, which redirects them to the Learning MFE when `ENABLE_COURSEWARE_MICROFRONTEND` is `True`.

No Caddy-level redirect is currently in place for legacy `/courses/*/courseware/*` URLs.

### coursewarehistoryextended

`deploy/k8s/base/apps/openedx/settings/lms/production.py` explicitly removes the legacy CSMH database app:

```python
# Get rid completely of coursewarehistoryextended, as we do not use the CSMH database
INSTALLED_APPS.remove("lms.djangoapps.coursewarehistoryextended")
DATABASE_ROUTERS.remove(
    "openedx.core.lib.django_courseware_routers.StudentModuleHistoryExtendedRouter"
)
```

This is correct. The CSMH (courseware student module history extended) database is a legacy performance optimisation that is no longer needed when using the Learning MFE and is explicitly removed.

### xmodule References

`xmodule` remains required in Ulmo. It is not a legacy dependency to remove:

- `from xmodule.modulestore.modulestore_settings import update_module_store_settings` — required for MongoDB modulestore configuration
- `"ENGINE": "xmodule.contentstore.mongo.MongoContentStore"` — required for content storage

These are internal Open edX APIs used by both LMS and CMS regardless of which learning experience is active.

### Theme CSS (.courseware selectors)

`infrastructure/tutor/themes/mereka/` contains `.courseware` CSS selectors in:
- `lms/static/css/mereka-overrides.css`
- `cms/static/css/mereka-overrides.css`
- `common/static/css/mereka-overrides.css`
- `scss/theme.scss`

These selectors style the XBlock rendering container. When the Learning MFE is active, the LMS still renders XBlocks in certain contexts (Studio preview, ORA2, inline problem responses). These selectors are not dead code, but they apply to the legacy rendering path. If full XBlock rendering migrates to the MFE (Learning MFE v2 / Blockstore), these can be removed.

### Custom App References

- `infrastructure/tutor/custom-apps/openedx_timed_exams/middleware.py`: references `/api/courseware/` (the Courseware REST API, not the legacy view URL — this API is present in both modes)
- `infrastructure/tutor/custom-apps/openedx_assessment_bulk/middleware.py`: references `/courses/.+/courseware/.+` pattern for exam start detection — this uses the **legacy URL pattern** and should be updated when legacy courseware is fully removed

### CSP header

`deploy/k8s/base/apps/openedx/settings/lms/production.py`:

```python
"'unsafe-inline'",  # Required by Open edX legacy courseware
```

This comment is partially accurate. `unsafe-inline` is also required by XBlocks rendered by the MFE (inline problem scripts). It cannot be removed until XBlocks are fully sandboxed in the Learning MFE. The comment should not lead to premature removal.

## Migration Status

| Item | Status | Action Required |
|------|--------|-----------------|
| `LEARNING_MICROFRONTEND_URL` configured | Done | None |
| `coursewarehistoryextended` removed | Done | None |
| `FEATURES["ENABLE_COURSEWARE_MICROFRONTEND"]` in production | Done (upstream default = True in Ulmo) | Confirm by running `verify-legacy-courseware.sh` |
| `ENABLE_COURSEWARE_MICROFRONTEND = False` in development.py | In progress | Change to `True` or remove when dev environment is ready |
| Caddy redirect `/courses/*/courseware/*` → Learning MFE | Not done | Add redirect when development.py flag is flipped |
| `.courseware` CSS selectors in theme | Deferred | Remove when XBlock rendering fully moves to MFE |
| `openedx_assessment_bulk` middleware pattern | Deferred | Update `/courses/.+/courseware/.+` regex when legacy URLs are retired |

## Redirect Requirements

When `ENABLE_COURSEWARE_MICROFRONTEND = True` the LMS redirects at the Django level. No Caddy-level redirect is strictly required for production.

If a Caddy-level redirect is desired (for cases where users have bookmarked old URLs and the LMS Django process is bypassed or slow), add to the LMS vhost block in `Caddyfile`:

```caddy
# Redirect legacy courseware URLs to Learning MFE
# Pattern: /courses/<org>+<course>+<run>/courseware[/...]
@legacy_courseware path_regexp /courses/[^/]+/courseware.*
redir @legacy_courseware https://apps.academyv2.mereka.io/learning/course/{http.regexp.1}/... 302
```

**Note**: Constructing the exact Learning MFE URL from a legacy courseware URL requires course key normalisation that Caddy cannot perform. The Django-level redirect (built into Open edX when the flag is enabled) is more accurate. A Caddy redirect is only needed if the LMS is unreachable.

## Feature Flags Involved

| Flag | Scope | Effect |
|------|-------|--------|
| `FEATURES["ENABLE_COURSEWARE_MICROFRONTEND"]` | LMS Django | When `True`, redirects `/courses/*/courseware/*` to Learning MFE |
| `LEARNING_MICROFRONTEND_URL` | LMS Django | Base URL for the Learning MFE; used to construct redirect targets |
| `MFE_CONFIG["LEARNING_BASE_URL"]` | MFE config API | Passed to MFE shell as runtime config |

## Recommended Next Steps

1. Set `FEATURES["ENABLE_COURSEWARE_MICROFRONTEND"] = True` in `development.py` (or remove the line to inherit the Ulmo default) once the local dev environment consistently uses the MFE.
2. Run `scripts/qa/verify-legacy-courseware.sh` to confirm production state.
3. Update the `openedx_assessment_bulk` middleware to detect exam start via the Learning MFE URL pattern (`/learning/course/*/...`) rather than the legacy courseware pattern.
4. After step 3, schedule removal of `.courseware` CSS blocks from the Mereka theme.
