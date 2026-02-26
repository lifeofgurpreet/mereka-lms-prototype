# Alert Noise False-Positive Classification Feed Contract

Date: 2026-02-25

## Purpose

Standardize manual/operator false-positive overrides for alert-noise runtime audits.

The feed is consumed by:
- `scripts/qa/build-alert-noise-runtime-sample.sh` via `ALERT_NOISE_FP_CLASSIFICATION_FEED`
- `scripts/qa/audit-alert-noise-baseline.sh` for schema validation in runtime mode

## Required Input

- `ALERT_NOISE_FP_CLASSIFICATION_FEED` points to a JSON file.
- Each file entry should define:
  - `fingerprint` (string): exact alert fingerprint to match
  - `classification` (string): either `false_positive` or `suppress`
  - `owner` (optional): service owner or team
  - `reason` (optional): human-readable reason
  - `expires_at` (optional): RFC3339 datetime if the override is temporary
  - `source` (optional): provenance of the override (`manual`, `operator`, `oncall`, etc.)

## Canonical Schema

```json
{
  "schema_version": "1.0.0",
  "entries": [
    {
      "fingerprint": "f34e31ce...",
      "classification": "false_positive",
      "owner": "platform-oncall",
      "reason": "Scheduled platform maintenance window",
      "expires_at": "2026-03-01T00:00:00Z",
      "source": "manual"
    }
  ]
}
```

## Operational Notes

- `build-alert-noise-runtime-sample.sh` merges feed-based false-positive marks with label/annotation-based marks.
- In strict mode (`STRICT_RUNTIME=1`), malformed feeds fail the build.
- Audit only treats `false_positive` and `suppress` as FP classifications.
- The generated runtime sample includes:
  - `false_positive_summary.label_matches`
  - `false_positive_summary.feed_matches`
  - `classification_feed.entries_total`
  - `classification_feed.entries_accepted`
  - `classification_feed.entries_rejected`

## Example Export

```bash
ALERT_NOISE_FP_CLASSIFICATION_FEED=docs/operations/alert-noise-manual-fp-feed.json \
  STRICT_RUNTIME=1 ./scripts/qa/build-alert-noise-runtime-sample.sh --out var/ci/alert-noise-runtime-sample.json
```

```json
// var/ci/alert-noise-runtime-sample.json
{
  "false_positive_summary": { "label_matches": 3, "feed_matches": 2 },
  "classification_feed": {
    "path": "docs/operations/alert-noise-classification-feed.json",
    "entries_total": 7,
    "entries_accepted": 6,
    "entries_rejected": 1
  }
}
```

## Storage and Governance

- Keep active feeds version-controlled with operator rationale and expiry.
- Remove expired entries after maintenance windows.
- Include this document in PR links when changing feed formats.
