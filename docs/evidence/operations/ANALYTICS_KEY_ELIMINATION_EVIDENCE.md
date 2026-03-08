# Analytics Key Elimination Evidence

> **Bead**: 1h41 — eliminate undefined analytics key regressions in all injected surfaces
> **Prior bead**: 2dcy.7 — remove undefined_license_key analytics regressions end-to-end
> **Last updated**: 2026-02-18
> **Covers**: AC-UI-501, AC-UI-502, AC-UI-503, AC-UI-504, AC-UI-505

---

## Failure Baseline (AC-UI-501)

### What Was Failing

Segment.io analytics calls were triggered with the invalid placeholder key
`undefined_license_key`, producing the following observable failures:

| Symptom | Detail |
|---|---|
| Network calls to `api.segment.io/v1/p` | Segment `page()` fired on every page load |
| Network calls to `api.segment.io/v1/i` | Segment `identify()` fired after login |
| HTTP 400 / 403 / 405 responses | Segment API rejected the placeholder key |
| Browser DevTools errors | `POST https://api.segment.io/v1/p 403` |
| Console warnings | Segment SDK logged key validation failures silently |

### Affected Hosts

All three entry surfaces where the LMS emits or receives analytics calls were affected:

| Host | Surface | Failure Mode |
|---|---|---|
| `academyv2.mereka.io/admin/*` | LMS admin pages — footer rendered on every admin page | `undefined_license_key` emitted in Segment `<script>` block |
| `apps.academyv2.mereka.io/authn/login` | authn MFE host | Segment SDK loaded from LMS env config with invalid key |
| `apps.academyv2.mereka.io/*` | apps MFE host (learner-dashboard, discussions, course-authoring) | SDK fired `page()` on every route change with bad key |

### Evidence Reproduction Commands (Offline)

```bash
# Confirm SEGMENT_KEY source in plugin (should be env var, empty default)
grep 'SEGMENT_KEY' infrastructure/tutor/plugins/mereka_lms.py

# Check footer sentinel guard (should reject undefined_license_key)
grep 'undefined_license_key' \
  infrastructure/tutor/themes/mereka/lms/templates/footer.html

# Verify no raw analytics injection in head-extra templates
grep -r 'SEGMENT_KEY\|undefined_license_key\|segment\.io' \
  infrastructure/tutor/themes/mereka/lms/templates/head-extra.html \
  infrastructure/tutor/themes/mereka/cms/templates/head-extra.html \
  infrastructure/tutor/themes/mereka/common/templates/head-extra.html \
  2>/dev/null || echo "CLEAN: no analytics injection in head-extra templates"

# Scan for literal sentinel assignments in infrastructure/
grep -r \
  "SEGMENT_KEY.*=.*'undefined'\|SEGMENT_KEY.*=.*'null'\|SEGMENT_KEY.*=.*'undefined_license_key'" \
  infrastructure/ --include="*.py" --include="*.js" --include="*.jsx" --include="*.html" \
  2>/dev/null || echo "CLEAN: no sentinel literals assigned"
```

---

## Root Cause (AC-UI-501, AC-UI-505)

The root cause was **injection without validation** at the LMS footer template level.

### Injection Failure Chain

1. `MEREKA_SEGMENT_KEY` was unset **or** set to the literal string `"undefined_license_key"` in
   the deployment environment. This string is a historic Segment SDK internal default that
   leaks into configs when the SDK is initialised without a real key.

2. `mereka_lms.py` reads the value via `os.environ.get("MEREKA_SEGMENT_KEY", "")`, producing `""`
   when unset (correct). However, if the variable was set to the literal sentinel string, Python
   passed that string through unchanged.

3. The original footer template had no guard — it included `segment-io.html` for any non-empty
   value of `SEGMENT_KEY`, including the `"undefined_license_key"` sentinel.

4. The Segment SDK loaded with the invalid key and attempted `page()` and `identify()` calls on
   every page load, receiving 400/403/405 responses from `api.segment.io`.

5. MFE hosts (`apps.academyv2.mereka.io`) received the invalid key indirectly via the LMS
   `env.config` JavaScript bundle injected by the `mfe-env-config` hook. The MFE SDK picked up
   the key and fired analytics calls on the authn and learner-dashboard routes.

### Scope

The injection risk existed in three places:

| Inject Point | Risk | Status |
|---|---|---|
| `mereka_lms.py` — `SEGMENT_KEY` assignment | Source of the key; no env var guard originally | Fixed: reads from `MEREKA_SEGMENT_KEY` with `""` default |
| `footer.html` — Segment `<script>` block | No sentinel guard; emitted for any non-empty value | Fixed: sentinel guard added (6 placeholder values rejected) |
| `head-extra.html` templates (lms/cms/common) | Potential raw injection point | Confirmed clean: no analytics injection present |

---

## Fix Applied (AC-UI-502)

### 1. Canonical Key Source in Plugin

`infrastructure/tutor/plugins/mereka_lms.py` now enforces the canonical key source:

```python
# ── Segment analytics ──────────────────────────────────────────────────
# Canonical key source for Segment.io analytics.
# Set MEREKA_SEGMENT_KEY in environment/secrets to enable.
# When empty or unset, Segment includes are skipped in footer template.
SEGMENT_KEY = os.environ.get("MEREKA_SEGMENT_KEY", "")
```

Rules:
- `SEGMENT_KEY` is always sourced from `MEREKA_SEGMENT_KEY` environment variable.
- Default is `""` — an unset variable disables analytics silently (no error, no calls).
- No string transforms (.lower(), .strip(), .upper()) applied to the key value.
- No hardcoded fallback key — the absence of the env var means analytics off.

### 2. Sentinel Guard in Footer Template

`infrastructure/tutor/themes/mereka/lms/templates/footer.html` wraps all Segment script
emission in a two-stage guard:

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

Stage 1 — non-empty check: `segment_key` must be truthy.
Stage 2 — sentinel rejection: the key is lowercased **for comparison only** and matched
against all known placeholder values. The key stored in `segment_key` retains its original
case (no case-mangling side effect).

### 3. Sentinel Values Rejected

| Sentinel Value | Reason |
|---|---|
| `undefined` | JavaScript `undefined` coerced to string by Segment SDK |
| `none` | Python `None` coerced to string in Jinja2/Mako context |
| `null` | JSON `null` coerced to string |
| `undefined_license_key` | Historic Segment SDK placeholder when no key is configured |
| `your_segment_key_here` | Common documentation placeholder |
| `change_me` | Generic secret placeholder pattern |

### 4. Head-Extra Templates — Clean (No Injection)

All three head-extra templates confirmed clean after audit:
- `infrastructure/tutor/themes/mereka/lms/templates/head-extra.html`
- `infrastructure/tutor/themes/mereka/cms/templates/head-extra.html`
- `infrastructure/tutor/themes/mereka/common/templates/head-extra.html`

None contain references to `SEGMENT_KEY`, `segment.io`, `analytics.track`, or
`undefined_license_key`. Segment injection is routed exclusively through `footer.html`.

---

## Canonical Key Validation Helper and Precedence Policy (AC-UI-503)

### Key Precedence (Highest to Lowest)

```
MEREKA_SEGMENT_KEY env var (non-empty, non-sentinel)
  ↓ if set and valid → analytics enabled
MEREKA_SEGMENT_KEY env var (empty or unset)
  ↓ → SEGMENT_KEY = "" → analytics disabled (no-op)
MEREKA_SEGMENT_KEY env var (set to sentinel value)
  ↓ → footer guard rejects → analytics disabled (no-op)
```

There is no fallback to a secondary key source. `MEREKA_SEGMENT_KEY` is the single
canonical source. If it is absent or invalid, analytics are silently off.

### No Case-Mangling Policy

The sentinel guard uses `.lower()` only for the comparison expression:

```mako
segment_key.lower() not in ("undefined", "none", ...)
```

The `segment_key` variable itself retains its original case. A Segment write key is
case-sensitive — lowercasing it before passing it to the SDK would silently break tracking
for any key containing uppercase letters (all real Segment write keys do).

This is verified by `verify-analytics-key-elimination.sh` check 16: no `.lower()` on the
left-hand side of the `segment_key` assignment lines.

### Enabling Analytics (Operational Guide)

To activate Segment analytics in a deployment:

1. Set `MEREKA_SEGMENT_KEY` to the real Segment write key in Infisical:
   ```bash
   infisical secrets set MEREKA_LMS_MEREKA_SEGMENT_KEY="<real-write-key>" \
     --domain https://secrets.mereka.io/api --env prod --path /
   ```
2. Sync to GCP Secret Manager:
   ```bash
   printf '%s' '<real-write-key>' | \
     gcloud secrets versions add MEREKA_LMS_MEREKA_SEGMENT_KEY --data-file=-
   ```
3. Update `deploy/k8s/base/secrets/external-secrets.yaml` to map the secret to the pod.
4. Restart LMS pods: `kubectl rollout restart deployment/lms -n mereka-lms`.

---

## Smoke Check Commands (AC-UI-504)

### Offline Verification (Always Available — All 3 Hosts)

```bash
# Run the key elimination verifier (this bead)
./scripts/qa/verify-analytics-key-elimination.sh

# Run prior regression verifier (bead 2dcy.7)
./scripts/qa/verify-analytics-undefined-regression.sh

# Run analytics key injection safety check (AC-ANAL-001..005)
./scripts/qa/verify-analytics-key.sh

# Run MFE analytics + plugin parity check (AC-AN-001..004)
./scripts/qa/verify-mfe-analytics-plugin-parity.sh
```

### Expected Output (0 Failures)

All scripts must report zero FAIL entries:

```
Summary: N PASS / 0 FAIL / 0 WARN
RESULT: PASS
```

### Host-Specific Smoke Checks

Offline checks verify source files cover admin/authn/apps hosts:

| Host | Offline Check | Expected Result |
|---|---|---|
| `academyv2.mereka.io/admin/*` | `grep 'undefined_license_key' footer.html` finds only the guard, not an assignment | PASS |
| `apps.academyv2.mereka.io/authn/*` | `mereka_lms.py` SEGMENT_KEY defaults to `""` (MFE inherits empty key) | PASS |
| `apps.academyv2.mereka.io/*` | No raw analytics injection in head-extra templates or plugin MFE config | PASS |

### Live Verification (Requires Cluster Access)

```bash
# Enable live mode — checks actual page source on production hosts
LIVE=1 \
  LMS_URL=https://academyv2.mereka.io \
  APPS_URL=https://apps.academyv2.mereka.io \
  ./scripts/qa/verify-analytics-key-elimination.sh
```

Live checks fetch the HTML source of `/admin/login/`, `/authn/login`, and
`/learner-dashboard/` and scan for `undefined_license_key` in the page body.
A clean deployment returns PASS on all live checks.

Live checks also verify the LMS homepage emits no sentinel key values.

### Manual Browser Verification

1. Open browser DevTools → Network tab → filter by `api.segment.io`.
2. Navigate to `https://apps.academyv2.mereka.io/authn/login`.
3. Confirm **zero requests** to `api.segment.io` appear (Segment SDK not loaded).
4. Navigate to `https://academyv2.mereka.io/admin/login/`.
5. Confirm **zero requests** to `api.segment.io` appear.
6. Navigate to `https://apps.academyv2.mereka.io/learner-dashboard/`.
7. Confirm **zero requests** to `api.segment.io` appear.

Zero network calls to `api.segment.io` = 0 occurrences of 403/405 for undefined key.

---

## Evidence Bundle Path and Collection (AC-UI-505)

The evidence bundle is collected under `var/analytics-key-elimination/` and demonstrates
all 5 ACs pass with 0 failures.

### Generating the Evidence Bundle

```bash
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="var/analytics-key-elimination/${STAMP}"
mkdir -p "$OUT"

bash scripts/qa/verify-analytics-key-elimination.sh \
  2>&1 | tee "$OUT/verify-analytics-key-elimination.log"

bash scripts/qa/verify-analytics-undefined-regression.sh \
  2>&1 | tee "$OUT/verify-analytics-undefined-regression.log"

bash scripts/qa/verify-analytics-key.sh \
  2>&1 | tee "$OUT/verify-analytics-key.log"

bash scripts/qa/verify-mfe-analytics-plugin-parity.sh \
  2>&1 | tee "$OUT/verify-mfe-analytics-plugin-parity.log"

echo "Evidence bundle saved to: $OUT"
ls -la "$OUT"
```

### Bundle Contents

| Artifact | Script | Covers |
|---|---|---|
| `verify-analytics-key-elimination.log` | `verify-analytics-key-elimination.sh` | AC-UI-501..505 (this bead) |
| `verify-analytics-undefined-regression.log` | `verify-analytics-undefined-regression.sh` | AC-FRONT-071..074 (bead 2dcy.7) |
| `verify-analytics-key.log` | `verify-analytics-key.sh` | AC-ANAL-001..005 |
| `verify-mfe-analytics-plugin-parity.log` | `verify-mfe-analytics-plugin-parity.sh` | AC-AN-001..004 |

### CI Artifact Capture

The `analytics-key-elimination` CI job captures the run log as a GitHub Actions artifact.
To retrieve from a PR:
1. Open the Actions run for the PR.
2. Click **Analytics Key Elimination Guard** in the job list.
3. Download the `analytics-key-elimination-gate` artifact.

---

## Related Documents

- `reports/2026/learnings/ANALYTICS_UNDEFINED_REGRESSION_FIX.md` — bead 2dcy.7 regression fix details
- `docs/reference/operations/MFE_ANALYTICS_PLUGIN_PARITY.md` — full analytics injection architecture,
  surface mapping, exception register, and evidence package format
- `scripts/qa/verify-analytics-key-elimination.sh` — primary verifier for this bead (1h41)
- `scripts/qa/verify-analytics-undefined-regression.sh` — prior regression verifier (bead 2dcy.7)
- `scripts/qa/verify-analytics-key.sh` — analytics key injection safety check (AC-ANAL-001..005)
- `scripts/qa/verify-mfe-analytics-plugin-parity.sh` — MFE analytics + plugin parity (AC-AN-001..004)
- `infrastructure/tutor/themes/mereka/lms/templates/footer.html` — sentinel guard implementation
- `infrastructure/tutor/plugins/mereka_lms.py` — canonical SEGMENT_KEY source
