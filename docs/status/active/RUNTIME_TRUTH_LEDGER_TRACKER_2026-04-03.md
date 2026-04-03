# Runtime Truth Ledger Tracker - 2026-04-03

Audience: Operators and reviewers
Owner: Platform Team
Last verified: 2026-04-03
Status: active

## Current Verified State

- `repo_truth`: `mereka-lms#1302` is open on head
  `55c932f75d4144cba8d5a6789aa7ab0fa8dd426a`; the active CI rerun is
  attached to that head.
- `infra_truth`: `bbi-infrastructure#2388` merged as
  `cefd938f4058a9f63cb1f1b78d31acb34ce3c9d0`.
- `runtime_truth`: direct Biji-Biji `apps` routes still leak on live dev until
  the app-side Caddy authority fix is merged, built, promoted, and re-proven.
- `acceptance_truth`: `bin/accept runtime-routing ...` now emits both
  `summary.json` and `truth-ledger.json`, even on failure.

## What We Achieved Already

- Added a versioned truth-join generator at
  [`scripts/release/generate_truth_ledger.py`](../../../scripts/release/generate_truth_ledger.py).
- Added a schema at
  [`schemas/truth-ledger.schema.json`](../../../schemas/truth-ledger.schema.json).
- Wired
  [`scripts/acceptance/runtime-routing.sh`](../../../scripts/acceptance/runtime-routing.sh)
  to emit `truth-ledger.json` beside the lane proof bundle.
- Added tests proving:
  - the ledger builds from an acceptance summary
  - digest drift is classified as a failure
  - `bin/accept runtime-routing --dry-run` emits the ledger artifact

## Current Control Point

The active blocker is still app-lane merge and realization, not ledger
generation.

- If `#1302` goes green: merge the lane tranche, wait for images, promote the
  new release object into dev, rerun runtime-routing proof.
- If `#1302` fails again: classify the failure as branch defect, baseline
  drift, or CI weather before taking any other action.

## Exact Commands

Generate a dry-run runtime-routing bundle plus truth ledger:

```bash
bin/accept runtime-routing --env dev --tenant biji-biji --dry-run --output-dir /tmp/runtime-routing-ledger
```

Generate a ledger from an existing summary with extra release/infra context:

```bash
python3 scripts/release/generate_truth_ledger.py \
  --summary-json /tmp/runtime-routing-ledger/summary.json \
  --output /tmp/runtime-routing-ledger/truth-ledger.json \
  --app-sha <app-sha> \
  --infra-commit-sha <infra-sha> \
  --argo-app mereka-lms-dev \
  --namespace mereka-lms-dev \
  --release-openedx-image \
    ghcr.io/biji-biji-initiative/mereka-lms/openedx:<tag>@<digest> \
  --release-mfe-image ghcr.io/biji-biji-initiative/mereka-lms/mfe:<tag>@<digest>
```

## Do Not Claim Closed Unless

- the ledger shows one joined record for the active lane/env
- acceptance verdict is green
- Argo is `Synced` / `Healthy`
- live tracked image digests match the release object
- browser/runtime proof no longer shows forbidden-host leakage on tenant
  `apps` routes
