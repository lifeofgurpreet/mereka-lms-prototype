---
id: RELEASE-UNIT-SCHEMA-001
status: draft
created: 2026-04-16
epic: mereka-lms-jj97
bead: mereka-lms-jj97.9
rfc: docs/rfcs/RFC-BUILD-AUTHORITY-001.md
---

# Release Unit Schema

> Canonical data model for `release_unit_id` — the single join key that connects
> build → promotion → realization → runtime proof without human reconstruction.

---

## 1. Why This Exists

Without a shared ID, answering "did release X make it to runtime?" requires a human
to manually correlate four separate surfaces:

1. A GitHub Actions workflow run (identified by `run_id`)
2. A promotion PR in bbi-infrastructure (identified by PR number and commit SHA)
3. An ArgoCD sync event (identified by `targetRevision`)
4. A runtime proof result (identified by timestamp or lane)

None of these surfaces share a native key. The build run ID is not in the ArgoCD
revision. The ArgoCD revision is not in the runtime proof. A developer or alert
system must reconstruct the chain by hand — a process that takes minutes, is
error-prone under incident conditions, and cannot be expressed as a single Prometheus
or Grafana query.

With `release_unit_id` carried by every surface, the same question becomes:

```promql
# Did release abc123... reach runtime?
ci_build_outcome_total{release_unit_id="abc123...", conclusion="success"}
# + ci_promotion_duration_seconds{release_unit_id="abc123..."}
# + ci_realization_duration_seconds{release_unit_id="abc123..."}
# + runtime_proof_result{release_unit_id="abc123..."}
```

One query. No reconstruction.

---

## 2. The ID

```
release_unit_id = source_sha
```

Where `source_sha` is the **full 40-character lowercase hex git commit SHA** of
the commit that triggered the build on `main`. This is `github.sha` in a GitHub
Actions `push` event.

**Format**: lowercase hex, exactly 40 characters.

```
abc123def456abc123def456abc123def456abc123
```

**Never use**:
- Short SHA (7–9 chars) as the canonical `release_unit_id`. Short form may appear
  as a display alias only (see Section 7, cardinality note).
- An uppercase SHA.
- A constructed or synthetic ID derived from timestamps or build numbers.

---

## 3. Why `source_sha` and Not Something Else

Three alternatives were considered and rejected:

### `build_workflow_run_id` (GitHub Actions `run.id`)

Rejected because: a single source SHA can be rebuilt multiple times
(via `workflow_dispatch` or a re-run). Each rebuild gets a new `run_id`
but the source is identical. Using `run_id` as the join key would treat
two builds of the same source as unrelated releases, breaking rebuild
idempotency and making "how many builds did release X require?" impossible
to answer.

`build_workflow_run_id` is a **secondary** key used only to link directly
to the GitHub Actions UI. See Section 8.

### `image_digest` (OCI manifest SHA256)

Rejected because: the image digest does not exist until after the build
completes. There is no image digest at queue time, at build-start, or at
the moment the webhook event fires for `workflow_run: requested`. Using
image digest as the join key would leave the queue and build phases
unlabeled — exactly the phases where cache misses and P95 breaches occur.

Image digests are carried in `ci_release_unit_info` as payload, not as
the join key.

### `release_tag` (e.g. `v2026.04.16`)

Rejected because: not all builds produce a tag. Main-branch builds
(the dominant case) do not tag every commit. Restricting the join key
to tagged releases would exclude the majority of build events from the
correlation chain.

### `source_sha` wins because

1. **Present from the first event.** It is known at `git push` time,
   before any build job starts, before any queue wait.
2. **Stable across rebuilds.** A `workflow_dispatch` re-run of the same
   commit produces the same `source_sha`.
3. **Naturally joins to git history.** `git show`, `git log`, and every
   GitHub UI link already understands this SHA.
4. **Already carried by every existing surface.** The workflow
   (`github.sha`), the release object (`app_commit_sha`), the dispatch
   envelope (`build_provenance.build_commit_sha`), and ArgoCD
   (`spec.source.targetRevision`) all already contain the commit SHA.
   No new plumbing is required; only consistent naming is needed.

---

## 4. Surfaces That Emit It

The following surfaces already carry the commit SHA in some form.
Each surface's current field name is documented alongside the conformance
requirement. No schema changes to existing surfaces are required in Phase 1;
aliasing is sufficient.

| Surface | Current field | Required alias / action | Reference |
|---------|---------------|------------------------|-----------|
| `build-tutor-images.yml` workflow | `github.sha` env var; set as `RELEASE_UNIT_ID=${{ github.sha }}` in build step env | Set `release_unit_id` label on every emitted metric | RFC-BUILD-AUTHORITY-001 §Release-Unit Data Model |
| `build-metrics-<image-family>.json` artifact (`emit-build-metrics.sh`) | `release_unit_id`, `workflow_run_id`, `image_family` | Repo-owned raw build-fact artifact. Keep `release_unit_id` full 40-char SHA; receiver enriches later. | `scripts/ci/emit-build-metrics.sh`, `docs/ops/ci-cd/CI_METRICS.md` |
| `ci-metrics-receiver` webhook service | `release_unit_id` JSON field on every ingested event | Already correct field name; enforce full 40-char SHA in receiver-side storage, labels, and examples | CI_METRICS.md §5.2 |
| `release_object` envelope (`generate_release_object.py`) | `app_commit_sha` | No rename required; add `"release_unit_id": app_commit_sha` as an alias field in Phase 3 | `scripts/release/generate_release_object.py` line 72 |
| `build_provenance` block in dispatch envelope | `build_commit_sha` (inside `build_provenance` dict) | No rename required; receiver already validates this field. Document mapping: `release_unit_id == build_provenance.build_commit_sha` | memory: `reference-dispatch-envelope-contract.md` |
| ArgoCD Application | `spec.source.targetRevision` (the deployed git SHA) | Read-only surface; no change. Query by matching `targetRevision` to `release_unit_id` in Grafana | ArgoCD application CR |
| Runtime proof envelope (`emit-proof-envelope.sh`) | `commit_sha` (field in emitted JSON, set from `git rev-parse HEAD`) | Add `release_unit_id` field alongside `commit_sha` in Phase 3. Until then, map via: `release_unit_id == commit_sha` | `scripts/release/emit-proof-envelope.sh` line 103 |

### Field Name Divergence Summary

The SHA is present everywhere but under six different field names:

```
github.sha                            (GitHub Actions context)
release_unit_id                       (ci-metrics-receiver — already canonical)
app_commit_sha                        (release_object)
build_commit_sha                      (dispatch build_provenance)
spec.source.targetRevision            (ArgoCD)
commit_sha                            (proof envelope)
```

The goal of the rollout (Section 10) is to make `release_unit_id` the canonical
name that all surfaces expose, while retaining existing field names as aliases.

---

## 5. Surfaces That Consume It

| Consumer | How it uses `release_unit_id` | Dependency |
|----------|-------------------------------|------------|
| Prometheus / Pushgateway | Label on every `ci_*` metric series; enables per-release filtering and join | `ci_release_unit_info` info metric carries full context |
| Grafana `ci-build-overview` dashboard | Panel variable `$release_unit_id`; filter any row to a single release | Dashboard bead `jj97.4` |
| Alert rules (`ci_build_alerts.yml`) | `CIPromotionStuck`, `CIRealizationStuck` match on same `release_unit_id` having build success but no downstream observation | Alert bead `jj97.3` |
| Loki log queries | `{job="ci-metrics-receiver"} | json | release_unit_id="abc123..."` correlates log lines to a specific release | Requires structured logging in receiver |
| `generate_truth_ledger.py` | Already ingests `app_commit_sha` from release object; will use as join key in ledger rows | `scripts/release/generate_truth_ledger.py` |

---

## 6. Schema (JSON)

The following is the canonical shape of a fully-resolved release unit record.
This object is assembled by the `ci-metrics-receiver` after all build jobs
complete. It is not emitted by any single surface; it is the join product.

```json
{
  "release_unit_id": "abc123def456abc123def456abc123def456abc123",
  "source_sha": "abc123def456abc123def456abc123def456abc123",
  "source_ref": "refs/heads/main",
  "image_digests": {
    "openedx": "sha256:dfbe7ef31806abc123...",
    "mfe": "sha256:5e68fd69af068e7c..."
  },
  "build_workflow_run_id": "24491141960",
  "build_started_at": "2026-04-16T15:00:00Z",
  "build_completed_at": "2026-04-16T15:08:00Z",
  "promotion_pr_number": 2640,
  "argocd_application": "mereka-lms-dev",
  "realization_revision": "abc123def456abc123def456abc123def456abc123"
}
```

### Field definitions

| Field | Type | Set by | Notes |
|-------|------|--------|-------|
| `release_unit_id` | string (40-char hex) | ci-metrics-receiver on first `workflow_run` event | Primary join key. Identical to `source_sha`. |
| `source_sha` | string (40-char hex) | Same | Alias for backwards compatibility. Always identical to `release_unit_id`. |
| `source_ref` | string | `github.ref` from workflow event | e.g. `refs/heads/main`. Identifies which branch triggered the build. |
| `image_digests.openedx` | string (`sha256:...`) | buildx metadata file after build completes | OCI manifest digest. Absent until build finishes. |
| `image_digests.mfe` | string (`sha256:...`) | buildx metadata file | OCI manifest digest. Absent until MFE build finishes. |
| `build_workflow_run_id` | string | GitHub Actions `run.id` | Secondary key. Changes on rebuild. Use for UI deep-links, not joins. |
| `build_started_at` | ISO 8601 UTC | `workflow_run.run_started_at` from webhook | |
| `build_completed_at` | ISO 8601 UTC | `workflow_run.updated_at` on `completed` event | |
| `promotion_pr_number` | integer | bbi-infrastructure dispatch receiver after PR opens | Absent until promotion PR is created. |
| `argocd_application` | string | bbi-infrastructure side, from promotion PR body | e.g. `mereka-lms-dev`, `mereka-lms-prod`. |
| `realization_revision` | string | ArgoCD sync event | The git SHA that ArgoCD realized; should equal `release_unit_id` for green deployments. |

---

## 7. Join Queries

### "How long did release X take to build?"

```promql
ci_build_duration_seconds{release_unit_id="abc123def456abc123def456abc123def456abc123"}
```

Or across all recent releases, grouped by family:

```promql
histogram_quantile(0.95,
  sum(rate(ci_build_duration_seconds_bucket[24h])) by (le, image_family, runner_class)
)
```

### "Did it reach runtime?"

Full chain join via `ci_release_unit_info`:

```promql
# Step 1: confirm build succeeded
ci_build_outcome_total{release_unit_id="abc123...", conclusion="success"} > 0

# Step 2: confirm promotion happened (non-zero observation for this release_unit_id)
ci_promotion_duration_seconds_count{release_unit_id="abc123..."} > 0

# Step 3: confirm realization happened
ci_realization_duration_seconds_count{release_unit_id="abc123..."} > 0
```

In Grafana, a single panel with `$release_unit_id` as a variable filters all
three rows simultaneously via the shared label.

### "Which release units failed cache import?"

```promql
# Identify builds where the registry cache was not found
ci_cache_source_found{source="registry"} == 0
```

Group by `release_unit_id` (via `ci_release_unit_info` join) to see which
source SHAs were affected:

```promql
ci_cache_source_found{source="registry"} == 0
  * on(release_unit_id) group_left(source_ref)
  ci_release_unit_info
```

### "How long from build complete to runtime proof passing?"

```promql
# End-to-end wall clock (queue + build + promotion + realization)
(
  ci_queue_duration_seconds_sum{release_unit_id="abc123..."}
  + ci_build_duration_seconds_sum{release_unit_id="abc123..."}
  + ci_promotion_duration_seconds_sum{release_unit_id="abc123..."}
  + ci_realization_duration_seconds_sum{release_unit_id="abc123..."}
)
```

### Loki: correlate build logs to a specific release

```logql
{job="ci-metrics-receiver"} | json | release_unit_id="abc123..."
```

---

## 8. Idempotency Rules

### Rebuild idempotency

A developer or workflow may trigger multiple builds of the same commit SHA
(e.g. via `workflow_dispatch` to re-run after a transient failure). Each
rebuild produces:

- The **same** `release_unit_id` (same `source_sha`)
- A **different** `build_workflow_run_id` (new GitHub Actions run ID)

The Prometheus model handles this correctly: multiple observations for the
same `release_unit_id` label value are valid histogram entries. The
latest build result is the authoritative one for that release unit.

### Promotion idempotency

The same `source_sha` may be promoted multiple times (e.g. a pin re-apply
after a GitOps drift fix). Each promotion produces:

- The **same** `release_unit_id`
- A new `promotion_pr_number`

The promotion record should carry `(release_unit_id, promotion_attempt_n)`
where `n` is a monotonically increasing integer within that release unit.
Recording rules should use `max` over `promotion_attempt_n` to find the
latest state.

### Runtime proof deduplication

Runtime proof results should be deduplicated by `(release_unit_id, env)`.
Only the newest proof result matters. Older proofs from previous promotion
attempts of the same source SHA are superseded.

```promql
# Latest runtime proof status for this release unit in dev
last_over_time(runtime_proof_result{release_unit_id="abc123...", env="dev"}[1h])
```

---

## 9. What This ID Is NOT

Misusing the ID creates phantom joins. Do not substitute it for:

| Not a substitute for | Use instead |
|----------------------|-------------|
| A build ID | `build_workflow_run_id` (GitHub Actions `run.id`) |
| An image ID | `image_digests.openedx` or `image_digests.mfe` (OCI manifest SHA256) |
| A deployment ID | ArgoCD sync operation ID or `realization_revision` |
| A tenant ID | Tenant identifiers are orthogonal; see `tenant-registry.yaml` |
| A release name / version tag | Tags are optional and not always present on main builds |
| A short display SHA | Short SHAs (7–9 chars) may collide at scale. Use full 40-char SHA as the metric label value. Display may abbreviate. |

---

## 10. Conformance Requirements

Each emitting surface must satisfy the following to be considered conformant:

1. **Field name**: Emit `release_unit_id` as the exact field name (or include
   it as an alias alongside the existing field; do not rename existing fields
   in Phase 1).

2. **Value**: Lowercase full 40-character hex SHA. No short SHAs as the
   canonical value in metric labels or JSON records.

3. **Timing**: Set `release_unit_id` on the **first event**, not
   retroactively. For the webhook receiver, this means the `workflow_run:
   requested` event must carry it. For the proof envelope, the first write
   of the envelope file must include it.

4. **No derivation**: The value is read directly from `github.sha` (or its
   equivalent). It is never computed, hashed, or truncated for use as the
   canonical label.

---

## 11. Rollout

### Phase 1 — Workflows and webhook receiver emit it (current sprint)

- `build-tutor-images.yml`: set `RELEASE_UNIT_ID=${{ github.sha }}` in build
  step env block; pass as label to emitted metrics.
- `ci-metrics-receiver` and any downstream dashboards/alerts: keep
  `release_unit_id` as a full 40-char SHA in storage, labels, and examples.
  Any short-form display must remain an alias only.
- Deliverable: every `ci_*` metric has `release_unit_id` label with full SHA.

### Phase 2 — Dashboards and alerts query by it

- Grafana `ci-build-overview`: add `$release_unit_id` variable to all rows.
- Alert rules: `CIPromotionStuck`, `CIRealizationStuck` use `release_unit_id`
  as the correlation key.
- Deliverable: single-release drill-down works end to end in Grafana.

### Phase 3 — Existing surfaces add `release_unit_id` alias

- `generate_release_object.py`: add `"release_unit_id": app_commit_sha`
  alongside existing `app_commit_sha`. Existing field is not removed.
- `emit-proof-envelope.sh`: add `release_unit_id` field alongside existing
  `commit_sha`. Existing field is not removed.
- `build_provenance` block: document the mapping
  `release_unit_id == build_commit_sha` in the dispatch envelope schema.
- Deliverable: all four surfaces agree on the field name; no consumer needs
  to know the mapping table in Section 4.

### Phase 4 — Deprecate `source_sha` in new surfaces

New surfaces introduced after Phase 3 completes must use `release_unit_id`
as the primary field name. Alias fields (`app_commit_sha`, `commit_sha`,
`build_commit_sha`) are retained indefinitely for backwards compatibility
with existing consumers of those surfaces. They are never removed.

---

## 12. Open Gaps

The following could not be fully specified because the upstream data is not
yet available. These are not blockers for Phase 1.

| # | Gap | Blocking |
|---|-----|---------|
| OG-1 | `ci_realization_duration_seconds` source is undefined. The exact Argo webhook endpoint or conveyor metric that would emit this with a `release_unit_id` label is not documented in bbi-infrastructure. The join query in Section 7 assumes this metric exists; until it does, the "Did it reach runtime?" chain query is incomplete at the realization step. | Blocks Phase 2 `CIRealizationStuck` alert PromQL. |
| OG-2 | Runtime proof (`emit-proof-envelope.sh`) currently emits `commit_sha` set from `git rev-parse HEAD` at proof execution time. If the proof runs from a worktree or detached HEAD that does not match the originally-built SHA, `commit_sha != release_unit_id`. The Phase 3 alias must verify the value equals the build SHA, not just the current HEAD. | Phase 3 aliasing work. |
| OG-3 | Historical short-SHA examples have been corrected in the app-repo docs, but any downstream dashboard, alert, or receiver consumer still assuming short-form `release_unit_id` must be inventoried before a receiver-side rollout is called complete. | Phase 1 upgrade coordination. |

---

## 13. References

| Document | Location | Relationship |
|----------|----------|--------------|
| RFC-BUILD-AUTHORITY-001 | `docs/rfcs/RFC-BUILD-AUTHORITY-001.md` | Authoritative design — §"Release-Unit Data Model" defines `release_unit_id = source_sha` |
| CI Metrics Catalog | `docs/ops/ci-cd/CI_METRICS.md` | Defines all `ci_*` metric names and the four required labels including `release_unit_id` |
| Cache Authority Runbook | `docs/ops/ci-cd/CACHE_AUTHORITY.md` | Cache ref naming and write policy; cache metrics carry `release_unit_id` |
| Dispatch Envelope Contract | memory: `reference-dispatch-envelope-contract.md` | Sender+receiver contract; `build_commit_sha` inside `build_provenance` maps to `release_unit_id` |
| Release Identity Chain Map | `docs/status/active/RELEASE_IDENTITY_CHAIN_MAP_2026-04-10.md` | Current proven chain for `bundle_id` / `release_id`; this schema sits alongside that chain as the observability join key |
| Build Authority Spec | `specs/build-authority-deterministic-builds_spec.md` | R1–R7 requirements; R2 requires one ID to join all pipeline stages |
| Epic | `mereka-lms-jj97` (run `br show mereka-lms-jj97`) | Full dependency tree and acceptance criteria |
