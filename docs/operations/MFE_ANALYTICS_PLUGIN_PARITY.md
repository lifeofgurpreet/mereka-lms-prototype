# MFE Analytics + Plugin Parity

> **Bead**: mereka-lms-115d.28
> **Last updated**: 2026-02-18
> **Covers**: AC-AN-001, AC-AN-002, AC-AN-003, AC-AN-004

This document describes the analytics key validation architecture, MFE customization
policy, and evidence package format for the Mereka LMS frontend.

---

## Analytics Configuration Architecture

### Key Validation and Sentinel Guards

Segment.io analytics are intentionally disabled by default. The key is sourced exclusively
from an environment variable and validated before any Segment script is emitted.

**Canonical key source** (`infrastructure/tutor/plugins/mereka_lms.py`):

```python
# ── Segment analytics ──────────────────────────────────────────────────
# Canonical key source for Segment.io analytics.
# Set MEREKA_SEGMENT_KEY in environment/secrets to enable.
# When empty or unset, Segment includes are skipped in footer template.
SEGMENT_KEY = os.environ.get("MEREKA_SEGMENT_KEY", "")
```

**Rules**:
- `SEGMENT_KEY` is always read from `MEREKA_SEGMENT_KEY` environment variable.
- Default value is `""` (empty string). An unset variable disables analytics silently.
- Never hardcode a Segment write key in source code or templates.

### Footer Sentinel Guard

The LMS footer template (`infrastructure/tutor/themes/mereka/lms/templates/footer.html`)
wraps all Segment script emission in a guard that:

1. Checks `segment_key` is non-empty.
2. Lowercases and compares against known placeholder/sentinel values.
3. Only emits the Segment `<script>` block when both conditions pass.

**Sentinel values rejected by the guard**:

| Value | Reason |
|---|---|
| `undefined` | JavaScript undefined coerced to string |
| `none` | Python None coerced to string |
| `null` | JSON null coerced to string |
| `undefined_license_key` | Historic Segment placeholder value |
| `your_segment_key_here` | Common documentation placeholder |
| `change_me` | Generic secret placeholder |

If `MEREKA_SEGMENT_KEY` is unset or set to any of these values, no analytics script
is injected and no calls are made. This ensures AC-AN-001 compliance.

### Enabling Analytics

To enable Segment analytics in an environment:

1. Set `MEREKA_SEGMENT_KEY` to the real Segment write key in Infisical (prod env, root path).
2. Sync to GCP Secret Manager and ExternalSecrets as `MEREKA_LMS_MEREKA_SEGMENT_KEY`.
3. Restart LMS pods. The footer template picks up the new key on next render.

---

## Known Invalid Call Patterns

### Detection

Run the static verifier to check for invalid call patterns:

```bash
./scripts/qa/verify-mfe-analytics-plugin-parity.sh
```

For live smoke checks (requires cluster access):

```bash
ANALYTICS_LIVE=1 LMS_URL=https://academyv2.mereka.io \
  ./scripts/qa/verify-mfe-analytics-plugin-parity.sh
```

The `smoke-test-analytics.sh` script provides broader live coverage.

### Anti-Patterns (Banned)

| Pattern | Reason |
|---|---|
| `SEGMENT_KEY = "writeKey123"` | Hardcoded key — use env var |
| `analytics.track(undefined)` | Undefined event name causes 400 errors |
| `SEGMENT_KEY = "null"` or `"undefined"` | Sentinel string — treated as disabled |
| Direct `<script>segment.io</script>` outside guard | Bypasses key validation |
| `ANALYTICS_SEGMENT_KEY` or `EDXAPP_SEGMENT_KEY` | Non-canonical key sources |

### Verifying No Sentinel Leakage

```bash
# Check footer.html sentinel guard
grep 'segment_key.*lower.*not in' \
  infrastructure/tutor/themes/mereka/lms/templates/footer.html

# Verify SEGMENT_KEY source
grep 'SEGMENT_KEY' infrastructure/tutor/plugins/mereka_lms.py
```

---

## MFE Plugin Entry Point Inventory

All MFE customizations must use documented plugin entry points. Direct DOM manipulation
is forbidden. See `docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md` for the
full migration register.

### Approved Entry Points

| Entry Point | Hook / Mechanism | Status |
|---|---|---|
| Footer component | `tutormfe.hooks.PLUGIN_SLOTS` + `mfe-env-config` fallback | Active |
| Theme SCSS | `mfe-env-config` import | Active |
| LMS/CMS Django settings | `openedx-lms-production-settings` patch | Active |
| MFE build toolchain | `mfe-dockerfile-post-python-requirements` | Active |

### Canonical Hook Pattern

MFE customizations are registered via Tutor's `ENV_PATCHES` filter using the
`mfe-env-config` hook. This is the approved entry point for injecting React components
and CSS imports into the MFE bundle:

```python
hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-env-config",
        """
// Import Mereka theme SCSS
import './mereka/mereka.scss';

// Register custom footer component
const MerekaFooter = () => { ... };
""",
    )
)
```

### Plugin Slot First Policy

All component-level overrides must use the Frontend Plugin Framework (FPF) slot system
when a slot is available upstream. See `docs/adr/014-mfe-plugin-slot-first.md`.

```python
# Forward-compatible slot registration (mereka_lms.py)
try:
    from tutormfe.hooks import PLUGIN_SLOTS
    PLUGIN_SLOTS.add_item(("footer_slot", { ... }))
    _PLUGIN_SLOTS_AVAILABLE = True
except ImportError:
    _PLUGIN_SLOTS_AVAILABLE = False
    # Fall back to apply-patches.sh string replacement
```

### Exception Register

The following non-slot customizations are explicitly approved with justification:

| Override | Location | Justification | Expiry |
|---|---|---|---|
| RenderWidget string replacement | `apply-patches.sh` | Fallback for Tutor versions without `PLUGIN_SLOTS`; removed when FPF slot is stable upstream | When `PLUGIN_SLOTS` available in tutor-mfe release |
| SCSS import in `mfe-env-config` | `mereka_lms.py` | No FPF slot for global CSS injection exists | Permanent (approved pattern) |
| Caddyfile multi-domain patch | `apply-patches.sh` | Infrastructure routing, not a UI override | Permanent |

Any new exception must be documented here before merging.

---

## Evidence Package Format

### What to Collect

For each release or audit, the following artifacts confirm analytics and plugin parity:

| Artifact | Source | Path |
|---|---|---|
| Script run log | `verify-mfe-analytics-plugin-parity.sh` | `var/analytics-parity/TIMESTAMP/verify-mfe-analytics-plugin-parity.log` |
| DOM override check | `verify-no-dom-overrides.sh` | `var/analytics-parity/TIMESTAMP/verify-no-dom-overrides.log` |
| Plugin slot migration check | `verify-plugin-slot-migration-register.sh` | `var/analytics-parity/TIMESTAMP/verify-plugin-slot-migration-register.log` |
| Analytics key injection check | `verify-analytics-key.sh` | `var/analytics-parity/TIMESTAMP/verify-analytics-key.log` |
| Live smoke (optional) | `smoke-test-analytics.sh` | `var/analytics-parity/TIMESTAMP/smoke-test-analytics.log` |

### Generating the Evidence Bundle

```bash
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="var/analytics-parity/${STAMP}"
mkdir -p "$OUT"

bash scripts/qa/verify-mfe-analytics-plugin-parity.sh \
  2>&1 | tee "$OUT/verify-mfe-analytics-plugin-parity.log"

bash scripts/qa/verify-no-dom-overrides.sh \
  2>&1 | tee "$OUT/verify-no-dom-overrides.log"

bash scripts/qa/verify-plugin-slot-migration-register.sh \
  2>&1 | tee "$OUT/verify-plugin-slot-migration-register.log"

bash scripts/qa/verify-analytics-key.sh \
  2>&1 | tee "$OUT/verify-analytics-key.log"

echo "Evidence bundle at: $OUT"
```

### CI Artifact Capture

The `mfe-analytics-plugin-parity` CI job uploads the run log as a GitHub Actions artifact
named `mfe-analytics-parity-gate`. Artifacts are retained for 30 days.

To retrieve from a PR:
1. Open the Actions run for the PR.
2. Click **mfe-analytics-plugin-parity** in the job list.
3. Download the `mfe-analytics-parity-gate` artifact.

---

## Troubleshooting

### Segment Not Firing (Expected)

Symptom: No Segment network calls visible in browser DevTools.

Diagnosis:
1. Check `MEREKA_SEGMENT_KEY` is set in Infisical and synced to the pod.
2. Confirm the value is not one of the sentinel strings listed above.
3. Check the rendered `footer.html` source — if the Segment `<script>` block is absent,
   the key guard is rejecting the value.

```bash
# Check pod environment
kubectl exec -n mereka-lms deploy/lms -- env | grep SEGMENT

# Check rendered footer in LMS
curl -s https://academyv2.mereka.io/ | grep -i "segment"
```

### Segment Firing on All Routes (Unexpected)

Symptom: Segment calls appear for anonymous users on every page load.

This is expected behavior when a valid key is set — Segment's `page()` call fires on
load. To disable for a specific tenant, set `SEGMENT_KEY = ""` for that site via
`SiteConfiguration`.

### analytics.identify Called with Undefined User

Symptom: `POST https://api.segment.io/v1/i` returns 400 or contains `"userId":null`.

Cause: Analytics `identify` called before user session is established.

Fix: Ensure `analytics.identify` is guarded by an authenticated session check. Check
`infrastructure/tutor/themes/mereka/lms/templates/` for `window.analytics` calls.

### Plugin Slot Not Activating

Symptom: MerekaFooter not rendered; default Open edX footer appears.

Diagnosis:
1. Check `_PLUGIN_SLOTS_AVAILABLE` in LMS logs.
2. If `False`, `apply-patches.sh` fallback is active — verify `RenderWidget: <MerekaFooter />`
   appears in the rendered MFE bundle.
3. Run `./scripts/qa/verify-mfe-footer-slot.sh` for detailed diagnostics.

---

## Related Documents

- `docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md` — full migration inventory
- `docs/operations/MFE_PLUGIN_SLOT_MATRIX.md` — slot availability by MFE
- `docs/adr/014-mfe-plugin-slot-first.md` — plugin-slot-first architecture decision
- `docs/branding/BRANDING_OPERATING_MODEL.md` — No DOM Override Policy
- `scripts/qa/verify-analytics-key.sh` — analytics key injection safety check
- `scripts/qa/verify-no-dom-overrides.sh` — DOM override policy enforcement
- `scripts/qa/smoke-test-analytics.sh` — live analytics smoke test
