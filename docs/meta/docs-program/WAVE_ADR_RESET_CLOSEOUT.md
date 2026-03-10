# Wave ADR Reset Closeout

## Outcome

`docs/adr/` now behaves as a decision ledger instead of a mixed dump:
- `docs/adr/*.md` contains current accepted ADRs only
- `docs/adr/historical/*.md` contains historical ADRs
- `docs/adr/rfc/*.md` contains proposals only
- moved program/governance docs no longer live in ADR space
- `docs/adr/README.md` and `docs/adr/_generated/*` are generated from ADR frontmatter

## Current-law set

- ADR-006
- ADR-013
- ADR-018
- ADR-019
- ADR-021
- ADR-022
- ADR-024
- ADR-025
- ADR-028
- ADR-029
- ADR-030
- ADR-031
- ADR-032
- ADR-033

## Historical set

- ADR-001
- ADR-002
- ADR-003
- ADR-004
- ADR-005
- ADR-007
- ADR-008
- ADR-009
- ADR-010
- ADR-012
- ADR-023
- ADR-026

## RFC set

- ADR-027
- ADR-034
- ADR-035
- ADR-036
- ADR-037
- ADR-038
- ADR-039
- ADR-040
- ADR-041
- RFC-claim-based-role-sync
- RFC-learning-slot-expansion-proposal

## Moved out of ADR space

- `docs/guides/standards/SPEC_VERIFICATION_METHOD.md`
- `docs/programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md`
- `docs/programs/mobile/PUSH_NOTIFICATION_PROVIDER_DECISION.md`
- `docs/programs/mobile/ANDROID_SUPPORT_DECISION.md`
- `docs/programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md`
- `docs/programs/observability/TRACING_PILOT_DECISION.md`
- `docs/meta/docs-program/ADR_CONTRADICTIONS_REGISTER.md`

## Generated surfaces

- `docs/adr/README.md`
- `docs/adr/rfc/README.md`
- `docs/adr/_generated/decision-index.json`
- `docs/adr/_generated/hot-path.md`
- `docs/adr/_generated/history-map.md`
- `docs/adr/manifest.yaml`
- `docs/adr/classification-map.yaml`
- `docs/adr/status-map.yaml`

## Validation

```bash
python3 tools/docs/build_adr_ledger.py
python3 tools/docs/verify/verify_adr_frontmatter.py --repo-root .
python3 tools/docs/verify/verify_adr_ledger_integrity.py --repo-root .
python3 tools/docs/verify/verify_adr_hot_path.py
python3 tools/docs/verify/build-doc-catalog.py --root .
bash scripts/qa/run-adr-gates.sh
```

## Remaining risks

- ADR-006, ADR-021, and ADR-024 still carry more implementation detail than an ideal tight-law ADR and may benefit from a second trimming pass.
- Legacy compatibility scripts that still read generated ADR maps remain in the repo; they no longer define truth, but they should be retired over time if they stop being consumed.
