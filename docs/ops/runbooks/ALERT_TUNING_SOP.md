# Alert Tuning SOP
_Audience: SRE + Platform • Last updated: 2026-02-06_

This SOP reduces noisy alerts without losing incident coverage.

## Weekly Cadence

1. Export last 7 days of alert incidents from Monitoring.
2. Group by alert policy and classify:
   - true positive
   - actionable but low urgency
   - false positive/noise
3. For noisy alerts, update one knob at a time:
   - threshold value
   - alignment period
   - duration
   - trigger count
4. Apply changes via template JSON in `infrastructure/monitoring/alerts/`.
5. Re-apply with `./scripts/infra/apply-monitoring-configs.sh apply`.
6. Record rationale in PR description.

## Hard Rules

- Never tune directly in console without updating template JSON.
- Never silence (`snooze`) permanently as a substitute for threshold fixes.
- Any alert tied to data-risk (storage, Velero restore/verification) requires explicit reviewer approval before reducing sensitivity.

## Rollback

If tuning causes missed incidents:
1. Revert JSON template commit.
2. Re-apply monitoring configs.
3. Add a postmortem note to the related bead.
