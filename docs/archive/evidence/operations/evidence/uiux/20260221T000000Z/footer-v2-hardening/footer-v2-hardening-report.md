# Footer v2 Fidelity + Plugin-First Tenant Branding Hardening

Generated: 2026-02-21T00:05Z
Branch: feat/23ry2-spec-dedupe-normalize
Commit: b3e84f8
Assignment: msg 3332 "[ASSIGNMENT][4h] UI lane: footer-v2 fidelity + plugin-first tenant branding hardening"

---

## Summary

Source integrity: **38/0/1 PASS/FAIL/WARN** (gate: PASS)
Live content check: **45/7/1 PASS/FAIL/WARN** — all 7 failures are deployment gaps (old image)

**No source-level bugs found.** All 3 deliverables complete.

---

## Deliverables

### 1. Live Footer Content Gate (AC-FTPAR-007) — DONE

Added `--live` flag to `scripts/qa/verify-footer-parity.sh`:
- **3 domains checked**: academyv2.mereka.io, academy.biji-biji.com, skillourfuture.academy.mereka.io
- **Per domain**: `mereka-footer` class, no "Powered by Open edX", copyright/brand line
- **LMS structural sections**: Future of Work, Creative Tech, Explore, Support, Partners
- Default mode (no flag): AC-FTPAR-007 skipped with hint message
- Source-only mode still passes: 38/0/1/1

**New script usage:**
```bash
./scripts/qa/verify-footer-parity.sh           # source-only (CI — no network)
./scripts/qa/verify-footer-parity.sh --live    # source + live content checks
```

### 2. Plugin-vs-Theme Decision Table — DONE

Added comprehensive decision table to `docs/guides/branding/BRANDING_OPERATOR_GUIDE.md`:
- By-surface table: 10 rows covering MFE, LMS, CMS, Django settings, Dockerfile, K8s manifests
- Decision tree flowchart
- `apply-patches.sh` rule with explicit "last resort" context

### 3. Per-Tenant Footer Content Override Workflow — DONE

Expanded `BRANDING_OPERATOR_GUIDE.md`:
- SITE_VARIANTS field reference table (brand, copyrightHolder, whatsapp + extendable fields)
- How to extend SITE_VARIANTS with `supportEmail`, `helpUrl` for new tenants
- Updated Tenant Branding Override Workflow: Steps 1–5 with explicit rebuild requirements
- Documents LMS footer link current state (global, shared) and migration path to bead 2rcf

---

## Live Check Results (2026-02-21T00:05Z)

Source verifier: **38 PASS / 0 FAIL / 1 WARN / 1 SKIP**

Live verifier (`--live`): **45 PASS / 7 FAIL / 1 WARN / 0 SKIP**

| Live check | Result | Root cause |
|-----------|--------|-----------|
| academyv2.mereka.io: mereka-footer class | PASS | ✅ deployed |
| academyv2.mereka.io: "Powered by Open edX" absent | FAIL | Old LMS image (deployment gap) |
| academyv2.mereka.io: copyright/brand line | FAIL | Old LMS image (deploy gap) — copyright not in expected format |
| academy.biji-biji.com: mereka-footer class | PASS | ✅ deployed |
| academy.biji-biji.com: "Powered by Open edX" absent | FAIL | Old LMS image (deployment gap) |
| academy.biji-biji.com: copyright/brand line | PASS | ✅ "Biji-Biji" present |
| skillourfuture: mereka-footer class | PASS | ✅ deployed |
| skillourfuture: "Powered by Open edX" absent | FAIL | Old LMS image (deployment gap) |
| skillourfuture: copyright/brand line | PASS | ✅ present |
| LMS section: Future of Work | PASS | ✅ deployed |
| LMS section: Creative Tech | FAIL | Old LMS image (deployment gap) |
| LMS section: Explore | FAIL | Old LMS image (deployment gap) |
| LMS section: Support | FAIL | Old LMS image (deployment gap) |
| LMS section: Partners | PASS | ✅ deployed |

**All 7 failures = deployment gaps (old LMS image predates latest footer.html).**
Fix: LMS image rebuild (WhiteCliff lane) — same as documented in `branding-deployment-gap-report.md`.

Expected live result after image rebuild: **52+ PASS / 0 FAIL / 1 WARN / 0 SKIP**

---

## Files Changed

| File | Change |
|------|--------|
| `scripts/qa/verify-footer-parity.sh` | Added `--live` flag, AC-FTPAR-007 live checks, SKIP counter, updated summary |
| `docs/guides/branding/BRANDING_OPERATOR_GUIDE.md` | Added plugin-vs-theme decision table + per-tenant footer content section |

---

## WhiteCliff Handoff

After LMS image rebuild:
```bash
./scripts/qa/verify-footer-parity.sh --live
# Expected: 52+ PASS / 0 FAIL / 1 WARN / 0 SKIP
```

Zero live failures is the post-deploy acceptance criterion.
