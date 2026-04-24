---
title: "Authn MFE post-#1906 follow-ups — runner python3.12-venv + SESSION_COOKIE_DOMAIN contract"
type: evidence-bundle
status: active
observed_at: 2026-04-20T00:20Z
owner: platform-release
triggered_by: PR #1906 merge (Authn MFE login crash fix) + 3rd-party-operator handoff
bead_status: TRACKER CORRUPTED — beads would normally be filed but `br` SQLite DB has page anomalies; using evidence doc until dedicated tracker repair session
---

# Authn MFE post-#1906 follow-ups

## Context

PR #1906 merged 2026-04-19T23:13Z (commit `9bbb5bfb6`). Fixes the Authn MFE login-page crash (`ReferenceError: Can't find variable: getMerekaShellCopy`) by restoring the tenant runtime helper contract in `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution-runtime.js`.

Two follow-ups need tracking. The `br` tracker is currently corrupted (`br doctor` reports `database disk image is malformed: page 959 is never used` + dozens of `invalid page number` errors on tree pages). Per `TRACKER-HYGIENE-RECOVERY-PLAN.md`, tracker surgery is NOT an autonomous task; it requires a dedicated operator session. These follow-ups are filed as evidence-doc until the tracker is repaired and real beads can be created.

---

## Follow-up 1 — CI runner missing python3.12-venv

**Severity**: P2 (infrastructure tech debt; bypassable via admin-merge)

**Symptom**: `Render Contract Preflight` CI job fails on every app-repo PR that installs Tutor into a fresh venv. Error:

```
The virtual environment was not created successfully because ensurepip is not
available.  On Debian/Ubuntu systems, you need to install the python3-venv
package using the following command.

    apt install python3.12-venv
```

**Runner**: `github-runner-mereka-lms-fastlane-ci-3` (and presumably all ARC fastlane runners).

**Impact**: #1906 (P0 Authn MFE login fix) required admin-merge to bypass this gate. Every future Tutor-rendering PR will hit the same block.

**Correct fix**: update the ARC runner image base in `bbi-infrastructure` to include `python3.12-venv`. See `arc-runner-images` and `arc-runner-ops` skills. This is an ARC runner image bake + promote, not an app-repo change.

**Done when**:
- ARC runner image rebuilt with `python3.12-venv`
- Runner image promoted to fastlane scale set
- Next Tutor-rendering PR passes Render Contract Preflight without admin-bypass

---

## Follow-up 2 — Authn MFE SESSION_COOKIE_DOMAIN build/runtime contract

**Severity**: P1 (cross-subdomain session reliability; not blocking login directly after #1906)

**Symptom**: `SESSION_COOKIE_DOMAIN` is required by `ProcessEnvConfigService` in the Authn MFE, but the live bundle/config path is not receiving it correctly. LMS has the cookie domain set (confirmed via earlier runtime probes); the issue is in how the MFE build pipeline or runtime config loader propagates the value.

**Constraint**: Do NOT hardcode `.academyv2.mereka.dev` or any tenant-specific string anywhere. The env-scoped MFE build/runtime contract must work across dev/staging/prod without tenant-specific build-time strings.

**Investigation path** (4-signal pattern from slice 63-64):

1. LMS settings (runtime):
   ```bash
   kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/lms -- \
     python manage.py lms shell -c \
     "from django.conf import settings; print('SESSION_COOKIE_DOMAIN=', settings.SESSION_COOKIE_DOMAIN)"
   ```
2. MFE config API (runtime):
   ```bash
   kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/lms -- \
     curl -s http://localhost:8000/api/mfe_config/v1 | python3 -m json.tool | grep -i cookie
   ```
3. Authn MFE bundle (build artifact):
   ```bash
   kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/mfe -- \
     sh -c 'grep -rln "SESSION_COOKIE_DOMAIN" /openedx/dist/authn/ 2>/dev/null'
   ```
4. MFE runtime env (live):
   ```bash
   kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/mfe -- \
     sh -c 'grep -rln "SESSION_COOKIE_DOMAIN" /openedx/*.json /openedx/env.config.* 2>/dev/null'
   ```

The layer where the value goes missing IS the layer to fix.

**Likely correct surface**: bbi-infrastructure MFE build or env-config generator, NOT app-repo shadow settings (per slice-68 shadow-settings-source-identified evidence).

**Historical note**: An earlier attempt left a title-only bead `mereka-lms-18ta` in the JSONL. 3rd-party operator removed it because the tracker write was incomplete. Recreating properly (here, as evidence-doc; later, as real bead once tracker is repaired).

**Done when**:
- SESSION_COOKIE_DOMAIN reaches the Authn MFE runtime correctly in dev/staging/prod
- No tenant-specific hardcoding in the fix
- Cross-subdomain session test passes for at least one tenant
- Runtime-verified via browser-capable agent (authn login → redirect → dashboard access preserved across subdomains)

---

## Follow-up 3 — Tracker (`br`) corruption

**Severity**: P2 (blocks clean bead creation; work can still be tracked via evidence docs)

**Symptom**: `br doctor` reports:
- `database disk image is malformed: page 959 is never used`
- Dozens of `Tree N page N cell N: invalid page number` errors
- `blocked_issues_cache is marked stale and needs rebuild`
- DB vs JSONL counts differ
- `UNIQUE constraint failed: export_hashes.issue_id` on new bead creation

**Do NOT autonomously repair**. Per `TRACKER-HYGIENE-RECOVERY-PLAN.md`, this requires a dedicated operator session with care not to corrupt export hashes further.

**Symptoms observed today**:
- 3rd-party operator observed a zero-byte `.beads/.write.lock` + a title-only bead `mereka-lms-18ta` (since removed)
- My slice-77 attempt to `br create` two follow-ups returned `UNIQUE constraint failed`

**Recovery notes**:
- JSONL is authoritative; rebuild DB from JSONL via `br sync` (with care)
- `br doctor` output above has full diagnostic state for the next operator
- `br` DB is a SQLite page-level corruption — probably needs `sqlite3 .beads/*.db ".recover"` plus rebuild, not just reimport

---

## Related PRs

- **#1906** (MERGED) — fix(mfe): restore tenant runtime helper contract for authn login
- **#1907** (MERGED earlier in slice 76) — fix(qa): 6 pre-existing static-validation FAILs closed
- **#1894** (OPEN) — docs(status): current MFE execution plan after shadow-settings retractions

## Related evidence

- `docs/ops/evidence/shadow-settings-source-identified-2026-04-19.md` — slice 68, naming the correct authoritative path for Django settings
- `docs/ops/evidence/shadow-settings-180d-audit-result-2026-04-19.md` — slice 68, zero-uncaught-no-ops finding
- `docs/ops/evidence/vfd5-mfe-consumption-proof-2026-04-19.md` — slice 69, MFE bundle-grep pattern used in Follow-up 2
