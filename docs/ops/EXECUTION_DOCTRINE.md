# Execution Doctrine

> Effective: 2026-03-07. Binding on all coding agents operating in this repo.

## Five Operating Laws

Every coding agent works under these five laws:

1. **One owner per scope.**
   App logic lives in the app repo. Environment realization lives in
   GitOps. Global safety rules live in control-plane/governance.

2. **One canonical path per critical action.**
   One release path. One migration path. One promotion path. One runtime
   validation path.

3. **One contract per producer-consumer boundary.**
   LMS publishes a versioned deploy contract. GitOps consumes it.
   Governance validates it.

4. **One proof bundle per release or promotion.**
   No "looks good." Every critical change emits machine-readable evidence.

5. **No green without runtime proof.**
   `repo_complete` is not `runtime_validated`.

## Status Taxonomy

| Status | Meaning |
| ------ | ------- |
| `repo_complete` | CI passes, manifests render, contracts valid |
| `runtime_pending` | Deployed but not yet proven |
| `runtime_validated` | Migrations complete, zero pending, smoke pass |
| `operationally_closed` | All environments promoted, no open incidents |

## Global Execution Standard

We are moving from many helpful scripts to a few canonical control surfaces.

### Rules

1. No agent may create a new release-critical path without updating:
   - the registry (`scripts/governance/script-registry.yaml`)
   - the contract/version surface (`deploy/k8s/contract.json`, `deploy/k8s/VERSION`)
   - the proof harness

2. No agent may say "complete" without machine-readable runtime evidence.

3. Every PR affecting release, deploy, migrate, promote, secrets,
   image publication, or runtime validation must include:
   - purpose
   - boundary impacted
   - files changed
   - contract impact
   - validators added/updated
   - proof commands
   - proof artifact paths
   - rollback note
   - blockers/dependencies

4. **Forbidden:**
   - warn-only release-critical checks
   - `continue-on-error` on release-critical checks
   - new hidden migration/release/deploy scripts
   - new runtime Python in GitOps
   - new full app Caddyfiles in GitOps
   - new env-specific logic in LMS base
   - new positional critical patching
   - unpinned third-party GitHub Actions
   - workflow tool downloads without checksum/provenance verification

5. **Required proof artifact pattern:**

   ```text
   var/proof/<scope>/<timestamp>/
   ```

   With JSON outputs for: contract, preflight, migration status,
   smoke, release gate, runtime validation.

6. **Canonical lane taxonomy is fixed.**
   Only these lane names are public and operator-facing:
   - `runtime-routing`
   - `identity-session`
   - `tenant-branding`
   - `infra-realization`
   - `seed-bootstrap`

7. **One human-facing acceptance front door.**
   Human operators use `bin/accept <lane> ...`. Lower-level scripts and
   `bin/lms-ops accept ...` exist for control-plane composition, not for
   day-to-day operator discoverability.

## Three-Repo Contract

- **mereka-lms** (app)
  Owns: runtime code, config, tests, base manifests, migration registry,
  and the release gate.
  Publishes: `deploy/k8s/contract.json`, `deploy/k8s/VERSION`.
- **bbi-infrastructure** (GitOps)
  Owns: environment overlays, cluster realization, image pins, ingress/TLS,
  and secret-store wiring.
  Publishes: topology catalog and build provenance.
- **platform-control-plane**
  Owns: cluster infra, global policies, and shared operators.
  Publishes: safety contracts and policy enforcement.

## Priority Layers

### Layer 1 — Stop-the-Line Safety (Immediate)

- No new unpinned third-party GitHub Actions
- No broad default workflow permissions
- No workflow tool downloads without checksum/provenance verification
- No warn-only or continue-on-error on release-critical checks
- No new hidden migration/release/deploy entrypoints
- No more runtime Python or full app Caddyfiles added to GitOps
- No new env-specific behavior in LMS base

### Layer 2 — First-Class Migration and Release Truth

- Canonical migration registry
- Canonical migration jobs
- Runtime-parity preflight
- Zero-pending proof
- Smoke proof
- Release gate
- Environment audit matrix
- Machine-readable evidence output

### Layer 3 — Topology and Boundary Cleanup (GitOps)

- Scope model for every service
- Pure env workload lanes
- Zero namespace exceptions
- No app-runtime logic in GitOps
- GitOps consumes LMS contract rather than re-implementing LMS behavior

### Layer 4 — Governance and Portfolio Maturity

- Script registry and canonical entrypoints
- Final review harness
- SSDF control mapping
- Docs contract and trust campaign
- Risk-based coverage gates
- OTel-based observability standard
- Infra backlog reset

## Definition of Done

For LMS and GitOps, done is not "the overlays render." It is:

- One versioned LMS contract
- One migration registry
- One canonical migration path
- One canonical release gate
- Migration jobs that see the same world as runtime
- Zero-pending proof
- Smoke proof
- GitOps consuming the app contract instead of redefining app logic
- One active owner for each cluster-scoped operator
- No namespace exceptions
- No hidden release-critical scripts
- Machine-readable proof attached to every release/promotion
- Status language used honestly
