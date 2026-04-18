# RC-02 Reproducibility Verdict — 2026-04-18

## Question

Can a fresh operator on `ssh mereka` re-verify the RC-02 evidence packet at `docs/status/active/evidence/rc02-102a56a07d/` without hidden setup?

## Answer

**NO, not today.** `scripts/qa/verify-release-object.sh` defaults to searching for `platform-control-plane` contract root at these paths:

```bash
DEFAULT_PLATFORM_ROOTS=(
  "$REPO_ROOT/var/ci/platform-control-plane"
  "$REPO_ROOT/../platform-control-plane"
  "$REPO_ROOT/../../platform-control-plane"
  "$HOME/projects/k8s/platform-control-plane"
  "$HOME/projects/platform-control-plane"
)
```

On `ssh mereka` at 2026-04-18T05:35Z the discovered `platform-control-plane` checkout has a `contracts/` dir but the version it holds does not include `release-object-projection-schema.yaml`. The schema was merged upstream in `platform-control-plane#81` (2026-04-10T17:45Z, SHA `ea93de7`) but the local checkouts are behind that SHA.

Live reproduction attempt:

```
$ bash scripts/qa/verify-release-object.sh \
    docs/status/active/evidence/rc02-102a56a07d/release-object.json
FAIL: platform-control-plane release-object projection schema unavailable
Looked for: /contracts/release-object-projection-schema.yaml
```

## Three Options

### Option A — Verifier accepts saved schema from evidence packet (PREFERRED)

The RC-02 evidence packet at `docs/status/active/evidence/rc02-102a56a07d/release-object-projection-schema.yaml` **already contains** the schema (extracted from `platform-control-plane@fa5065b`). Make the verifier prefer a sibling `release-object-projection-schema.yaml` in the same directory as the release object.

Pros:
- Evidence packet becomes self-contained: copy the directory anywhere, re-verify without external dependencies.
- No infrastructure change, no new checkout to maintain.
- Matches the normal expectation for evidence bundles: they carry their own verifier inputs.

Cons:
- Introduces a new precedence rule: "sibling schema wins over `platform-control-plane` discovery". Must be explicit and documented.
- If the sibling schema is tampered with, verification passes falsely. Mitigate by requiring a `sha256sum` in an accompanying `release-object-projection-schema.sha256` file, authored by the build workflow when it emits the packet.

**Recommendation: ship this option. Ship the checksum alongside.**

### Option B — Document sibling `platform-control-plane` checkout

Keep verifier behavior unchanged. Document on the VPS (README or preflight) that operators must:
```bash
cd /home/gurpreet/projects/k8s
git clone https://github.com/Biji-Biji-Initiative/platform-control-plane
# or: git pull if already present
```

Pros:
- No code change.

Cons:
- The VPS checkouts drift (proven today: local is behind `origin/main` by 23 commits). Documenting "clone it" is insufficient.
- Requires another canonical checkout to maintain, adding to operator burden.
- Evidence packet is NOT self-contained — it requires an external live-clone to re-verify.

**Not recommended.** This adds to the problem, not the solution.

### Option C — Ship schema with checksum in a sibling CI artifact

Similar to A but the schema lives in a separate artifact (not in the evidence packet). Operator downloads both.

Pros:
- Evidence packet stays lean.

Cons:
- Two artifacts to keep in sync is worse than one self-contained bundle.
- Operator workflow requires `gh run download ... --name schema` before verifying.

**Not recommended.**

## Verdict

**Implement Option A:**
1. Modify `scripts/qa/verify-release-object.sh` to prefer a sibling `release-object-projection-schema.yaml` in the same directory as the release object.
2. Add the corresponding `.sha256` checksum file during build workflow `emit-proof-envelope` step.
3. Update the verifier to validate the checksum before using the schema.
4. Document the precedence rule in the script's help output.

## Work Items

- `mereka-lms-j2cj` (P2): this verdict is the plan. Next step: implement the code change in a new PR that also lands the checksum emission in the build workflow.

## Appendix: Current workaround

Until Option A ships, operators re-verify via:

```bash
cd /home/gurpreet/projects/k8s/mereka-lms
RELEASE_OBJECT_SCHEMA_PATH="docs/status/active/evidence/rc02-102a56a07d/release-object-projection-schema.yaml" \
  bash scripts/qa/verify-release-object.sh \
  docs/status/active/evidence/rc02-102a56a07d/release-object.json
```

This was the workaround used in this sprint's RC-02 verification. It works but requires operators to know the trick.
