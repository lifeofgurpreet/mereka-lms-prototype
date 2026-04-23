# Bead Singleton Audit — 2026-04-23

Auditor: Beads Planning Specialist (claude-sonnet-4-6)
Scope: All open beads NOT in epics 0z5g, 9pnu, b7nl, zy7k, or 1kwf.1
Date: 2026-04-23
Method: `br show` read on every bead body; no speculative clustering from titles alone.

---

## Section 1 — Proposed Clusters

| Cluster | Members | Rationale | New parent epic? |
|---|---|---|---|
| Atlas/MongoDB incident chain | tuk6, gwt4, ba0p | tuk6 is root cause; ba0p is the verification bead once tuk6 is fixed; gwt4 is the credential rotation hygiene triggered by ba0p investigation. All three must close in sequence to clear the nonprod crashloop incident. | No — they are already sequenced via `blocks` dep. tuk6 → ba0p; gwt4 is parallel hygiene. No epic needed; three beads are the right granularity. |
| DR proof program | v5vj, 6p07 | v5vj is the partial drill (backup-pipeline proven, data-integrity NOT proven); 6p07 is the cross-cluster restore drill explicitly filed as follow-up to v5vj. Body of v5vj names 6p07 as the companion. These belong under a shared parent. | Yes, P1. File a `dr-readiness` parent epic. v5vj and 6p07 become children. |
| MERGE_POLICY series | cp16, k3nm | cp16 is Stage 2 (rulesets + merge queue); k3nm is Stage 3 (retire --auto). k3nm body says explicitly "after Stage 2 is proven." Clean linear dependency. | Yes, P1. File a `merge-policy-completion` parent epic or use an existing MERGE_POLICY tracking bead if one exists. cp16 → k3nm dep is already needed regardless. |
| OBS runtime observability | e09t, mx78, 9ib2, jdsx | e09t (OBS-003 synthetic), mx78 (OBS-004 Upptime), 9ib2 (OBS-001 phase 2 Sentry wiring), jdsx (MFE_CONFIG keys surfaced by e09t synthetic). All carry OBS-00X tracking IDs from the same observability program. jdsx was filed because e09t found the gap. 9ib2 is unblocked once its phase 2 prerequisite lands. | Yes, P2. File an `obs-runtime` parent epic. Saves mental load when triaging which OBS gap is active. |
| Deploy-contract hygiene | pjam, 9o0o, rq9k, vw47 | All four address silent-failure classes in the deploy/runtime layer: pjam (ArgoCD stale-render), 9o0o (production.py three-writer drift), rq9k (unpinned images block rollouts), vw47 (stuck CronJob Jobs invisible for 12d). Different surfaces but the same failure mode: "operator believes state is correct; cluster disagrees silently." Consider grouping. | Consider — cluster is coherent but members span bbi-infrastructure (rq9k, pjam) and app-repo (9o0o, vw47). A lightweight parent bead is reasonable if we want a deploy-hygiene kanban lane. Otherwise leave as singletons with cross-links. |

---

## Section 2 — Proposed Bead Graph Changes

```bash
# --- DR readiness parent epic ---
# Create parent epic for DR proof program
br create -t epic -p P1 "DR readiness: prove backup-restore end-to-end"

# Link v5vj and 6p07 as children (replace <dr-epic-id> with new id)
br update mereka-lms-v5vj --parent <dr-epic-id>
br update mereka-lms-6p07 --parent <dr-epic-id>

# Explicit ordering: 6p07 can only run after v5vj identifies BSL/Longhorn prereqs
br dep add mereka-lms-6p07 mereka-lms-v5vj


# --- MERGE_POLICY parent epic ---
# Create parent epic for MERGE_POLICY completion
br create -t epic -p P1 "MERGE_POLICY completion: rulesets + merge queue + retire --auto"

# Link cp16 and k3nm as children (replace <mp-epic-id> with new id)
br update mereka-lms-cp16 --parent <mp-epic-id>
br update mereka-lms-k3nm --parent <mp-epic-id>

# Explicit ordering: k3nm requires cp16 to be proven first
br dep add mereka-lms-k3nm mereka-lms-cp16


# --- OBS runtime observability parent epic ---
# Create parent epic for observability program
br create -t epic -p P2 "OBS runtime observability: Sentry + Upptime + synthetic + MFE_CONFIG gaps"

# Link members as children (replace <obs-epic-id> with new id)
br update mereka-lms-9ib2 --parent <obs-epic-id>
br update mereka-lms-e09t --parent <obs-epic-id>
br update mereka-lms-mx78 --parent <obs-epic-id>
br update mereka-lms-jdsx --parent <obs-epic-id>

# jdsx was found by e09t; wire dependency (jdsx can be fixed while e09t cron runs, but evidence comes from e09t)
br dep add mereka-lms-jdsx mereka-lms-e09t


# --- Atlas chain: add explicit gwt4 note ---
# gwt4 and ba0p are already sequenced via tuk6 -> ba0p dep.
# gwt4 is parallel hygiene, no new dep needed.
# No new epic needed for a three-bead incident chain.


# --- Deploy-contract hygiene (OPTIONAL — review before filing) ---
# Only file if we want a tracked lane; otherwise leave as singletons.
# br create -t epic -p P2 "Deploy-contract hygiene: silent failure surface reduction"
# br update mereka-lms-pjam --parent <dc-epic-id>
# br update mereka-lms-9o0o --parent <dc-epic-id>
# br update mereka-lms-rq9k --parent <dc-epic-id>
# br update mereka-lms-vw47 --parent <dc-epic-id>
```

---

## Section 3 — Findings Table

| ID | Current title (shortened) | Finding | Proposed action |
|---|---|---|---|
| cm9c | Studio tenant SSO redirect — wrong authn page | Clean. P0 bug with full investigation checklist and clear DONE-WHEN. No duplicate found. | No change. |
| rq9k | Audit prod Deployments for unpinned images | Clean. Dense body, specific ACs, companion PRs cited. Clusters with deploy-contract hygiene group (pjam, 9o0o, vw47). | Optional: parent under deploy-contract epic. |
| 6p07 | DR drill: cross-cluster restore | Clean. Filed as explicit follow-up to v5vj. Clear DONE-WHEN. | Add to DR readiness epic as child; add dep on v5vj. |
| ba0p | Dev LMS/CMS crashloop — "liveness probe timeout" | MISFRAMED title. Body proves root cause is Atlas IP allowlist, not probe timeout. Title still says "liveness probe timeout or startup failure." | Retitle: "Dev LMS/CMS crashloop — Atlas IP allowlist missing for wk-04/wk-05 egress (unblock after tuk6)". |
| cp16 | MERGE_POLICY Stage 2 | Clean. Detailed exit criteria. Explicitly staged. | Add to MERGE_POLICY parent epic; add dep k3nm → cp16. |
| v5vj | Verify DR: audit-velero.sh | Clean. Body updated 2026-04-22 with partial-drill evidence and honest "NOT PROVEN" markers. Narrowed scope post-drill. | Add to DR readiness epic as child. |
| jj97.11 | Raw build telemetry schema | OUT OF LANE. Parent jj97 is CLOSED build-authority epic. jj97.11 is WS-B (build telemetry) work — fastlane/ARC/CI pipeline scope. | Flag for build-authority agent. Do not absorb. |
| aza7 | RKE2 operational hardening and deployment pipeline | STALE. Created 2026-02-19, last updated 2026-02-19 (63 days). Body contains rendered kubectl --help output (artifact of a broken `br show` at write time). Two of three declared blockers are now CLOSED (20eb CLOSED 2026-02-20, 5ngf.2 CLOSED 2026-04-17); third blocker 288f is IN_PROGRESS from 2026-02-19 with no update. ACs are vague ("AC-RKE2-101: kubectl controls the cluster"). | Flag as stale; request re-scope. Accept criteria need rewriting. The work that was blocking it (20eb, 5ngf.2) is done — the bead itself may already be superseded by the current rke2-nonprod operational state. |
| 1li5 | cms/lms-worker readinessProbe timeout | NEAR-DUPLICATE of 9pnu / 9pnu.1. Body comment (2026-04-22) explicitly says "Same root cause as 9pnu; 9pnu.1 expected to resolve this bead too." Already linked as dependent on 9pnu.1. | No new action; dependency is wired. Confirm 9pnu.1 close also closes 1li5. |
| tuk6 | Atlas IP allowlist missing for wk-04/wk-05 | Clean. Filed 2026-04-22. Clear root cause, clear action. Correct framing as blocker for ba0p. | No change. Cluster with gwt4 + ba0p for tracking. |
| gwt4 | Rotate MONGODB_PASSWORD (leaked in transcript) | Clean. Hygiene task with clear scope. Parallel to tuk6 (doesn't block or depend). | No change. |
| vw47 | Alert: CronJob Job running > activeDeadlineSeconds | Clean. Specific ACs, test plan, companion beads cited. Clusters with deploy-contract hygiene group. | Optional: parent under deploy-contract epic. |
| pjam | ArgoCD stale-render trap: Synced lies | Clean. Good root-cause analysis. Three concrete desired-end-state items. Clusters with deploy-contract hygiene. | Optional: parent under deploy-contract epic. |
| 9o0o | ADR + CI guard: three-layer production.py writer trap | Clean. Dense body, concrete desired end state. Clusters with deploy-contract hygiene. | Optional: parent under deploy-contract epic. |
| ano7 | BLOCKED: bootstrap-fastlane-build-host.sh | OUT OF LANE. Body: "re-run once bbi-infrastructure#3418 is MERGED." Pure fastlane/build-host work. | Flag for build-authority agent. |
| 9ib2 | Wire Sentry DSN into bbi-infra overlays (OBS-001 ph2) | Clean. Clear ACs, exit criteria, dependency on OBS-001 phase 2. | Add to OBS parent epic. |
| k3nm | MERGE_POLICY Stage 3: retire --auto | Clean. Explicit "after Stage 2 proven." | Add to MERGE_POLICY parent epic; dep on cp16. |
| jdsx | LOGIN_ISSUE_SUPPORT_LINK + SESSION_COOKIE_DOMAIN | Clean. Surfaced by e09t synthetic. DONE-WHEN is testable. | Add to OBS parent epic; dep on e09t. |
| mx78 | OBS-004 Upptime external uptime | SPARSE body. Two sentences, no ACs, no DONE-WHEN. Evidence link to observability-audit doc but no acceptance criteria. | Flag for re-scope: add DONE-WHEN (e.g. "prod LMS domains appear in upptime status page with green badge for 48h"). |
| e09t | OBS-003 browser synthetic on Authn MFE | SPARSE body. Two sentences. No explicit DONE-WHEN, no test plan for "confirm it fires." | Flag for re-scope: add ACs mirroring the pattern in vw47 (deliberate test scenario, confirm detection window). |
| mnf5 | Enterprise images frozen 5 months | SPARSE body. Three sentences. No ACs, no owner, no next action beyond "Upgrade plan documented or rebuild pipeline established." 63 days since last update but filed 2026-04-17 (6 days). | Flag for re-scope: needs explicit next action (e.g. "check upstream release for 21.x; evaluate to minor bump; produce upgrade plan doc"). |
| crre | Doc: canonical 5-guard registration matrix | Clean. Rich body with full guard matrix table and pre-flight commands. P3, no urgency. | No change. |

---

## Section 4 — Out-of-Lane Flags

These beads touch fastlane, ARC runners, build telemetry, or image-build CI. They should NOT be absorbed by the mereka-lms app/runtime agent.

| ID | Why out of lane |
|---|---|
| jj97.11 | Child of CLOSED build-authority epic jj97. Work is WS-B: build telemetry schema, `emit-build-metrics.sh`, CI metrics receiver. Pure build-infrastructure scope. |
| ano7 | Body is entirely about `bootstrap-fastlane-build-host.sh` on vmi3220759 and a path fix blocked on bbi-infrastructure#3418. No LMS app semantics. |

Note: aza7 is borderline. Its original framing was RKE2 platform hardening (infra-lane) but its ACs include LMS smoke tests, tenant routing, and branding gates — which are app-lane concerns. Given it is 63 days stale with superseded blockers and garbled body content, re-scoping is needed before lane assignment can be confirmed.

---

## Section 5 — Open Questions

1. **aza7 disposition**: Two of three declared blockers are CLOSED; the third (288f) is IN_PROGRESS from 2026-02-19 with no update. Is aza7 superseded by the work already done to get rke2-nonprod operational? If so, close it with a learning. If not, it needs a full body rewrite — the current ACs contain kubectl --help output rendered into the body (formatting artifact) and are not independently actionable.

2. **mx78 and e09t ACs**: Both bodies are two-sentence stubs with no DONE-WHEN. Before adding them to an OBS epic, they need ACs. Who is responsible for fleshing these out — the person who files the epic, or the person who picks up the bead?

3. **Deploy-contract hygiene epic**: The four beads (pjam, 9o0o, rq9k, vw47) span both repos (mereka-lms and bbi-infrastructure). An epic in mereka-lms would only own the app-repo side. Is a cross-repo tracking bead the right tool, or should each bead remain standalone with cross-references?

4. **1li5 and 9pnu.1 overlap**: The 2026-04-22 comment on 1li5 says 9pnu.1 is "expected to resolve this bead too." That is a prediction, not a guarantee. If 9pnu.1 closes (remove liveness probes from enterprise workers + lms-worker) and 1li5 is not explicitly verified post-fix, it could stay open indefinitely. Who confirms 1li5 is closed as a consequence of 9pnu.1?

5. **gwt4 urgency**: Credential rotation for a leaked MongoDB password should be high-urgency. gwt4 is currently P1 and OPEN with no owner activity since creation (2026-04-22). Is someone actively working this, or is it in the queue?
