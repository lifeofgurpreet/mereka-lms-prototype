# Analytics Undefined Regression Fix

> **Bead**: 2dcy.7 — remove undefined_license_key analytics regressions end-to-end
> **Last updated**: 2026-02-18
> **Covers**: AC-FRONT-071, AC-FRONT-072, AC-FRONT-073, AC-FRONT-074

---

## Failure Baseline (AC-FRONT-071)

### What Was Happening

Before this fix, Segment.io analytics calls were being triggered with an invalid
`undefined_license_key` write key. This produced the following observable failures:

| Symptom | Detail |
|---|---|
| Network calls to `api.segment.io/v1/p` | Segment `page()` fired on every page load |
| Network calls to `api.segment.io/v1/i` | Segment `identify()` fired after login |
| HTTP 400 / 403 / 405 responses | Segment rejected the placeholder key |
| Browser DevTools errors | `POST https://api.segment.io/v1/p 400 Bad Request` |
| Console warnings | Segment SDK logged key validation failures |

### Affected Hosts

All three entry surfaces where the LMS emits or receives analytics calls were affected:

| Host | Surface | Failure Mode |
|---|---|---|
| `academyv2.mereka.io/admin/*` | LMS admin host — footer rendered on admin pages | `undefined_license_key` emitted in Segment `<script>` block |
| `apps.academyv2.mereka.io/authn/login` | authn MFE host | Segment SDK loaded from LMS `env.config` with invalid key |
| `apps.academyv2.mereka.io/*` | apps MFE host (learner-dashboard, discussions, etc.) | Same as authn — SDK called `page()` on every route change |

### Evidence Commands (Offline Reproduction)

These commands reproduce the failure baseline using source inspection only:

```bash
# Check for undefined_license_key in footer template
grep 'undefined_license_key' \
  infrastructure/tutor/themes/mereka/lms/templates/footer.html

# Confirm SEGMENT_KEY source in plugin
grep 'SEGMENT_KEY' infrastructure/tutor/plugins/mereka_lms.py

# List all analytics-related verification scripts
ls scripts/qa/verify-analytics*.sh
```

---

## Root Cause

The root cause was **injection without validation**: the Segment analytics script
was included in the LMS footer template regardless of whether the key was a real
write key or a placeholder sentinel value.

The specific failure chain:

1. `MEREKA_SEGMENT_KEY` was unset or set to `"undefined_license_key"` in the deployment
   environment (a historic Segment SDK default when no key is configured).
2. `mereka_lms.py` read the value via `os.environ.get("MEREKA_SEGMENT_KEY", "")` — this
   part was correct, producing `""` when unset.
3. However, if the environment variable was set to the literal string `"undefined_license_key"`
   (a common default from Segment's own SDK fallback), the Tutor Jinja2 template rendered
   the key into the footer HTML.
4. The original footer template had no guard — it included `segment-io.html` unconditionally,
   meaning any non-empty value (including `"undefined_license_key"`) was treated as valid.
5. The Segment SDK loaded with the invalid key and attempted `page()` + `identify()` calls,
   receiving 400/403/405 responses from `api.segment.io`.

### Why MFE Hosts Were Also Affected

The MFE hosts (`apps.academyv2.mereka.io`) receive the Segment key indirectly via the
LMS `env.config` JavaScript bundle injected by `mfe-env-config` hook. When the LMS
emitted an invalid key in the env config payload, the MFE SDK picked it up and fired
analytics calls on the authn and learner-dashboard routes.

---

## Fix Applied

### Sentinel Guard Pattern

The LMS footer template (`infrastructure/tutor/themes/mereka/lms/templates/footer.html`)
was patched to add a sentinel guard before emitting any Segment script:

```mako
<%
  segment_key = getattr(settings, "SEGMENT_KEY", "") or ""
  segment_key = str(segment_key).strip() if segment_key else ""
%>

% if segment_key and segment_key.lower() not in (
    "undefined", "none", "null", "undefined_license_key",
    "your_segment_key_here", "change_me"
):
  <%include file="widgets/segment-io.html" />
  <%include file="widgets/segment-io-footer.html" />
% endif
```

The guard does two things:

1. **Non-empty check**: `segment_key` must be truthy (not `""`, `None`, or whitespace-only).
2. **Sentinel rejection**: The key is lowercased and compared against all known placeholder
   values before any `<script>` block is rendered.

### Key Validation Before Injection

`infrastructure/tutor/plugins/mereka_lms.py` enforces the canonical key source:

```python
# ── Segment analytics ──────────────────────────────────────────────────
# Canonical key source for Segment.io analytics.
# Set MEREKA_SEGMENT_KEY in environment/secrets to enable.
# When empty or unset, Segment includes are skipped in footer template.
SEGMENT_KEY = os.environ.get("MEREKA_SEGMENT_KEY", "")
```

Rules enforced:
- `SEGMENT_KEY` is always read from `MEREKA_SEGMENT_KEY` environment variable.
- Default is `""` — an unset variable **disables analytics silently** (fallback policy).
- Never hardcode a Segment write key in source code or templates.

### Sentinel Values Rejected

| Sentinel Value | Reason |
|---|---|
| `undefined` | JavaScript `undefined` coerced to string by Segment SDK |
| `none` | Python `None` coerced to string in template context |
| `null` | JSON `null` coerced to string |
| `undefined_license_key` | Historic Segment SDK placeholder when no key is configured |
| `your_segment_key_here` | Common documentation placeholder |
| `change_me` | Generic secret placeholder pattern |

---

## Surface Mapping

All files that participate in Segment analytics injection:

| File | Role | Guard Present |
|---|---|---|
| `infrastructure/tutor/plugins/mereka_lms.py` | Sets `SEGMENT_KEY` from `MEREKA_SEGMENT_KEY` env var; empty default | Yes (empty string default) |
| `infrastructure/tutor/themes/mereka/lms/templates/footer.html` | Emits Segment `<script>` block; reads `settings.SEGMENT_KEY` | Yes (sentinel guard) |
| `tutor_env/env/plugins/mfe/build/mfe/env.config.jsx` | Generated MFE config; does not directly emit Segment key | Not applicable (LMS-only) |

The MFE surfaces (`apps.*`, authn) do not have their own Segment injection path — they
inherit from the LMS `SEGMENT_KEY` setting. If `SEGMENT_KEY` is empty or rejected by the
footer guard, no Segment SDK is loaded and no calls are made from MFE routes.

---

## Fallback Exception Policy

When `MEREKA_SEGMENT_KEY` is absent or set to a sentinel value:

1. **`SEGMENT_KEY` is set to `""`** in `mereka_lms.py` (via empty default).
2. **Footer guard evaluates to false** — `segment_key` is falsy or matches a sentinel.
3. **No `<script>` block is emitted** — Segment SDK is not loaded at all.
4. **No analytics calls are made** — `page()`, `identify()`, and `track()` are never invoked.
5. **No network errors** — `api.segment.io` receives zero requests.

This is the correct silent no-op behavior. The fallback is analytics-off, not analytics-
with-broken-key.

Exceptions that deviate from this policy must be documented in
`docs/reference/operations/MFE_ANALYTICS_PLUGIN_PARITY.md` under the Exception Register before merging.

---

## Smoke Check Commands

### Offline Verification (Always Available)

```bash
# Run the full regression verification script
./scripts/qa/verify-analytics-undefined-regression.sh

# Run the analytics key injection safety check
./scripts/qa/verify-analytics-key.sh

# Run the MFE analytics + plugin parity check
./scripts/qa/verify-mfe-analytics-plugin-parity.sh
```

### Expected Output

All three scripts should report zero failures:

```
RESULT: PASS
Summary: N PASS / 0 FAIL / 0 WARN
```

### Live Verification (Requires Cluster Access)

```bash
# Enable live mode — checks actual page source on production hosts
ANALYTICS_SMOKE_LIVE=1 \
  LMS_URL=https://academyv2.mereka.io \
  APPS_URL=https://apps.academyv2.mereka.io \
  ./scripts/qa/verify-analytics-undefined-regression.sh
```

Live checks fetch the HTML source of `/admin/login/`, `/authn/login`, and
`/learner-dashboard/` and scan for `undefined_license_key` in the page body.
A clean deployment returns PASS for all three live checks.

### Manual Browser Verification

1. Open browser DevTools → Network tab → filter by `api.segment.io`.
2. Navigate to `https://apps.academyv2.mereka.io/authn/login`.
3. Confirm **no requests** to `api.segment.io` appear (Segment SDK not loaded).
4. Navigate to `https://academyv2.mereka.io/admin/login/`.
5. Confirm **no requests** to `api.segment.io` appear.

If `MEREKA_SEGMENT_KEY` is set to a valid key in production, Segment calls will appear —
this is expected and correct behavior. Verify the key is not `undefined_license_key`.

---

## Evidence Bundle Format

For audit or incident response, collect the evidence bundle:

```bash
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="var/analytics-undefined-regression/${STAMP}"
mkdir -p "$OUT"

bash scripts/qa/verify-analytics-undefined-regression.sh \
  2>&1 | tee "$OUT/verify-analytics-undefined-regression.log"

bash scripts/qa/verify-analytics-key.sh \
  2>&1 | tee "$OUT/verify-analytics-key.log"

bash scripts/qa/verify-mfe-analytics-plugin-parity.sh \
  2>&1 | tee "$OUT/verify-mfe-analytics-plugin-parity.log"

echo "Evidence bundle saved to: $OUT"
ls -la "$OUT"
```

The evidence bundle demonstrates:
- All AC-FRONT-071 through AC-FRONT-074 pass.
- No sentinel values in injection paths.
- Smoke coverage exists for admin/authn/apps hosts.
- Surface mapping and fallback exception policy are documented.

---

## Related Documents

- `docs/reference/operations/MFE_ANALYTICS_PLUGIN_PARITY.md` — full analytics injection architecture,
  surface mapping, exception register, and evidence package format
- `scripts/qa/verify-analytics-undefined-regression.sh` — primary regression verifier (this bead)
- `scripts/qa/verify-analytics-key.sh` — analytics key injection safety check (AC-ANAL-001..005)
- `scripts/qa/verify-mfe-analytics-plugin-parity.sh` — MFE analytics + plugin parity (AC-AN-001..004)
- `infrastructure/tutor/themes/mereka/lms/templates/footer.html` — sentinel guard implementation
- `infrastructure/tutor/plugins/mereka_lms.py` — canonical SEGMENT_KEY source
