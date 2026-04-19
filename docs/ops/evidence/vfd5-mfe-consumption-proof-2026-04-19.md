---
title: "vfd5 — LEARNING_MICROFRONTEND_URL is NOT consumed by any MFE; bead closes as NEEDED=NO"
type: evidence-bundle
status: active
observed_at: 2026-04-19T14:28Z
owner: platform-release
bead: mereka-lms-vfd5
close_reason: NEEDED=NO
---

# vfd5 — LEARNING_MICROFRONTEND_URL is not consumed by any MFE

Bead `mereka-lms-vfd5` was filed after slice 64-65 retractions to
track the "correct path" for what #1875 was trying to do: expose
`LEARNING_MICROFRONTEND_URL` in the MFE config API response so
MFEs could discover the learning surface base URL from runtime config.

Slice 69 runtime proof shows this bead is **moot** — no MFE looks
for that key in the first place.

## Runtime verification

```bash
# 1. Check what the MFE config API currently returns
kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/lms -- \
  curl -s -H 'Host: academyv2.mereka.dev' http://localhost:8000/api/mfe_config/v1 \
  | tr ',' '\n' | grep -iE "learn|course"

# Output includes:
#   "LEARNING_BASE_URL": "https://apps.academyv2.mereka.dev/learning"      ← PRESENT
#   "LEARNER_HOME_MICROFRONTEND_URL": "https://apps.academyv2.mereka.dev/learner-dashboard/"
#   "COURSE_HOME_URL": "https://apps.academyv2.mereka.dev/learning/"
#   "LEARNER_DASHBOARD_URL": "https://apps.academyv2.mereka.dev/learner-dashboard/"
#   "COURSE_AUTHORING_MICROFRONTEND_URL": "https://apps.academyv2.mereka.dev/authoring"
#
# NOT in output:
#   LEARNING_MICROFRONTEND_URL (the key #1875 tried to add)

# 2. Check if any MFE bundle references LEARNING_MICROFRONTEND_URL
kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/mfe -- \
  sh -c 'grep -rln "LEARNING_MICROFRONTEND_URL" /openedx/dist/ 2>/dev/null'
# → (no output — zero matches)

# 3. Baseline comparison — confirm the grep methodology works
kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/mfe -- \
  sh -c 'grep -rln "LEARNING_BASE_URL" /openedx/dist/learning/ 2>/dev/null'
# → /openedx/dist/learning/76.308849641acf3aa90f09.js.map
# → /openedx/dist/learning/76.308849641acf3aa90f09.js
# (2 matches, confirming grep is finding things when they exist)
```

## Conclusion

`LEARNING_MICROFRONTEND_URL` is **not consumed** by any built MFE
bundle on dev. MFEs that need the learning surface URL use the already-
served `LEARNING_BASE_URL` key (which returns the same value).

**The "feature gap" that #1875 attempted to fix is not a real gap.**
Neither the original ship (app-repo shadow file, retracted via #1883)
nor a hypothetical bbi-infra overlay ship would change MFE behavior.

## Impact on bead graph

- `mereka-lms-vfd5` — **CLOSE as NEEDED=NO**. The Tutor-plugin /
  bbi-infra-overlay path to add this key is not needed because
  nothing consumes it.
- `mereka-lms-m0u5.10.1` (Learning MFE courseware/progress error
  boundaries) — this finding does NOT close m0u5.10.1. The D-03/
  D-04/D-05 routing defects remain stranded and need a browser-
  capable agent. But #1875's proposed fix was orthogonal — it
  wouldn't have helped even if it had reached runtime.

## Related
- PR #1875 (retracted via #1881/#1883) — original attempt
- PR #1885 (correction addendum, slice 67) — `vfd5` path re-scoped
- PR #1886 (source identified, slice 68) — authoritative path = bbi-infra overlay
- PR #1887 (180d audit result) — #1875 was the single uncaught no-op
- Parent bead (still open): `mereka-lms-m0u5.10.1`
