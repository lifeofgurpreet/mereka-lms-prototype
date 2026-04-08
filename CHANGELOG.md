# Changelog

All notable changes to the Mereka Academy LMS platform.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [1.5.0] - 2026-04-08

### Added
- Release identity enforcement for production promotion (B-012) (#1443)
- Environment progression warning for promotion (B-015) (#1448)
- Auto-sync vendored settings at promotion time (B-019) (#1447)
- GitOps Integrity System — machine-checkable invariants + enforcement (#1425)
- Deterministic cross-repo verifiers via git-show against pinned refs (#1430)
- Executable route resolver for agent skill routing (#1430)
- Workflow gate enforcement verifier — 12 structural checks (#1430)
- Proof lineage chain verifier — 21-link end-to-end chain (#1430)
- Negative test pack — 6 seeded violations caught (#1430)
- Skill routing contract — 10 incident→skill bundle routes (#1430)
- Expanded blind-agent acceptance harness — 10 scenarios, 31 checks (#1430)
- Discussions MFE feature flag enabled (#1434)
- Studio SSO OAuth2 durable bootstrap (#1436)
- Source-owned user provisioning for test fixtures (#1442)

### Fixed
- CRLF line-ending false positives in vendored settings drift (#1430)
- Oscar deprecation printf crash from pipefail (#1430)
- Failing CronJobs and Discussions backend (#1437)
- MFE learner-record Node 18 compatibility (#1440, #1444, #1446)
- PII filtering script reclassified from static to runtime inventory (#1449)

### Security
- Branch protection contract v2.0 with live-audited GitHub settings (#1430)
- Truth ledger validates release identity when release object provided (#1443)

## [1.4.0] - 2026-04-07

### Added
- Learner-home MFE redirect via waffle flag (#1418)
- Staging/prod enterprise specs + CMS-SSO OAuth bootstrap (#1415)
- Repository dispatch for automated dev promotion (#1423)

### Fixed
- Decommissioned GKE context replaced with rke2-prod (#1398)
- Stale ecommerce URLs removed from MFE_CONFIG (#1416)

