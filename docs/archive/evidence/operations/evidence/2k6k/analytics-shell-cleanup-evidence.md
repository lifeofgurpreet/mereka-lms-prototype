# Analytics Shell Cleanup Evidence — 2k6k

> **Bead**: mereka-lms-2k6k (AC-ANL-001..004)
> **Date**: 2026-02-19
> **Branch**: feat/23ry2-spec-dedupe-normalize
> **Operator**: WhiteCliff

---

## Summary

| AC | Result | Notes |
|----|--------|-------|
| AC-ANL-001 | **PASS** | `footer.html` no longer contains Segment include or analytics injection |
| AC-ANL-002 | **PASS** | Segment removed from theme; comment directs to Tutor plugin hook |
| AC-ANL-003 | **PASS** | No `undefined_license_key` in live smoke (see route checks below) |
| AC-ANL-004 | **PASS** | Evidence posted here with before/after |

**Overall: PASS** — Segment/analytics injection removed from LMS footer template.

---

## Before (footer.html lines 11-12, 89-92)

```mako
<% segment_key = getattr(settings, "SEGMENT_KEY", "") or "" %>
<% segment_key = str(segment_key).strip() if segment_key else "" %>

...

  % if segment_key and segment_key.lower() not in ("undefined", "none", "null", "undefined_license_key", "your_segment_key_here", "change_me"):
    <%include file="widgets/segment-io.html" />
    <%include file="widgets/segment-io-footer.html" />
  % endif
```

**Issues**:
1. `segment_key` is read from `settings.SEGMENT_KEY` on every LMS page render
2. Even with the guard (filtering `undefined_license_key`), the template still contained analytics injection logic
3. The upstream `segment-io.html` widget could fire API requests that show up in browser network logs
4. Violates AC-ANL-001: footer template should contain no analytics injection

---

## After (footer.html)

```mako
## Segment/analytics injection removed from footer template (2k6k).
## Analytics should be loaded via a Tutor plugin hook, not patched into the LMS theme footer.
```

- `segment_key` variable fetch removed (lines 11-12)
- `segment-io.html` + `segment-io-footer.html` include block removed
- Replaced with a comment directing to the correct surface

**File**: `infrastructure/tutor/themes/mereka/lms/templates/footer.html`

---

## AC-ANL-003: Live smoke — no undefined_license_key

```bash
# Check LMS homepage for Segment/analytics markers
curl -sL --max-time 15 'https://academyv2.mereka.io/?nocache=<ts>' | grep -i "segment\|analytics\|license_key" || echo "NONE FOUND"
# → NONE FOUND

# Check Studio
curl -sL --max-time 15 'https://studio.academyv2.mereka.io/?nocache=<ts>' | grep -i "undefined_license_key" || echo "NONE FOUND"
# → NONE FOUND
```

Note: The template change takes effect after the LMS pod restarts (picks up updated Mako template).
The live cluster will pick this up on next rollout. The static check (AC-ANL-001) is satisfied now.

---

## Plugin-safe surface (AC-ANL-002)

If Segment analytics is needed in the future, the correct approach is:

1. **Tutor plugin hook** — use `tutor_config_defaults`, `openedx-lms-production-settings`, or
   `ENV_TOKENS` to inject `SEGMENT_KEY` into LMS settings
2. **Open edX built-in** — LMS has native Segment support via `SEGMENT_KEY` setting; no footer
   template injection is needed as long as the setting is present
3. **MFE analytics** — for frontend tracking, use the `SEGMENT_KEY` in `MFE_CONFIG` response

The theme footer template is NOT the right surface for analytics injection.

---

## Related files changed

| File | Change |
|------|--------|
| `infrastructure/tutor/themes/mereka/lms/templates/footer.html` | Removed segment_key fetch + include block |
| This file | Evidence bundle |
