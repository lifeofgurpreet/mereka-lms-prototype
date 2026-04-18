# OG-03 Promote-Dev-Image Reliability Verdict — 2026-04-18

## Question

OG-03 audit in `OG-03-PROMOTE-AUDIT.md` showed a 45% success rate (9/20) on `promote-dev-image.yml` with 6 failure classes. Has the situation improved, and what's the highest-ROI action now?

## Current State (last 20 runs on main)

```
success: 9
failure: 11
```

Same 45% success rate in a sliding window. BUT:

**The last 5 runs are ALL success** (2026-04-17T02:57Z → 2026-04-18T03:05Z). The failure cluster happened earlier in the window (2026-04-10 through 2026-04-17T00:41Z).

## What Changed

`bbi-infrastructure` merged three reliability fixes in mid-April:

- **#2900** `fix(ci): dispatch promotion validations via actions api` — replaced brittle `curl` calls with `gh api`
- **#2935** `fix(ci): grant actions:write to workflow_dispatch callers` — GitHub App permission fix (OG-03's highest-ROI recommendation)
- **#2946** `refactor(ci): migrate promote-dev-image from peter-evans to app-token PR creation`

The 11 failures are all dated BEFORE 2026-04-17T02:57Z, which is when the fixes took full effect. Every run since has been green.

## Verdict

**OG-03's highest-ROI fix was already merged on bbi-infrastructure.** The reliability problem is resolved. Current evidence:

- 5/5 recent runs green
- Zero failures since 2026-04-17T02:57Z
- Failure classes A.2/B/C from the audit are no longer surfacing

## Next Action

**None required this cycle.** Close bead `mereka-lms-1kd9` after one more week of green runs. If a new failure class emerges, re-audit — don't chase historical classes.

## Spot-Check Suggestion (Non-Blocking)

The `peter-evans/create-pull-request` → app-token migration (#2946) changed the whole PR-creation path. If a future operator sees a "Create promotion PR" failure pattern return, investigate the new app-token code path first, not the old `peter-evans` code path.

## Related

- Bead `mereka-lms-1kd9` (P2) — pending close after stability window
- `docs/status/active/evidence/rc02-102a56a07d/OG-03-PROMOTE-AUDIT.md`
- bbi-infrastructure PRs #2900, #2935, #2946
